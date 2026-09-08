(* RadicalRoots 1.0 -- Wolfram Language front end for the bundled Python engine.
   The Python implementation was executed in development; this front end was
   statically reviewed but no Wolfram kernel was available. See VALIDATION.md.
   No shell command strings or executable text imported from JSON are used. *)

BeginPackage["RadicalRoots`"];
RootToRadicals::usage =
 "RootToRadicals[a] returns an exactly verified radical expression for an exact algebraic number a, or a Failure. The bundled Python/SymPy engine supplies the general algorithm.";
RadicalRepresentation::usage =
 "RadicalRepresentation[a] returns an association containing a radical expression, exact verification, and a backend audit trace, or a Failure.";
RadicalExpressionQ::usage =
 "RadicalExpressionQ[e] tests whether e uses only rational constants, I, arithmetic, and rational powers.";
ReadRadicalJSON::usage =
 "ReadRadicalJSON[file,a] reads a JSON result from the bundled Python program, decodes its non-executable radical DAG, and verifies equality to a with RootReduce.";

Options[RadicalRepresentation] = {
 Method -> "Automatic", TimeConstraint -> 300,
 "PythonExecutable" -> Automatic, "BackendPath" -> Automatic,
 "MaxFieldDegree" -> 128, "NativeAttempt" -> True,
 "VerificationTimeConstraint" -> 60, "IsolationTimeConstraint" -> 30
};
Options[RootToRadicals] = Options[RadicalRepresentation];
Options[ReadRadicalJSON] = {"VerificationTimeConstraint" -> 60};

Begin["`Private`"];
$backendPath = ExpandFileName@FileNameJoin[
 {DirectoryName[$InputFileName], "..", "python", "radical_roots.py"}];
$decodeTag = Unique["radicalDecode"];

RadicalExpressionQ[e_Integer | e_Rational] := True;
RadicalExpressionQ[e_Complex] :=
 MatchQ[Re[e], _Integer | _Rational] && MatchQ[Im[e], _Integer | _Rational];
RadicalExpressionQ[e_Plus | e_Times] := And @@ (RadicalExpressionQ /@ (List @@ e));
RadicalExpressionQ[Power[b_, q_Integer | q_Rational]] := RadicalExpressionQ[b];
RadicalExpressionQ[_] := False;

failure[tag_, msg_, details_: <||>] :=
 Failure[tag, Join[<|"MessageTemplate" -> msg|>, details]];
ratString[q_Integer | q_Rational] :=
 ToString[Numerator[q], InputForm] <> "/" <> ToString[Denominator[q], InputForm];

parseInteger[s_String] := Module[{negative},
 If[!StringMatchQ[s, RegularExpression["-?[0-9]+"]],
  Throw[failure["InvalidDAG", "Invalid integer literal."], $decodeTag]];
 negative = StringStartsQ[s, "-"];
 If[negative, -FromDigits[StringDrop[s, 1]], FromDigits[s]]
];
parseInteger[_] := Throw[failure["InvalidDAG", "Expected an integer string."], $decodeTag];
parseRational[a_, b_] := Module[{n = parseInteger[a], d = parseInteger[b]},
 If[d <= 0, Throw[failure["InvalidDAG", "Nonpositive denominator."], $decodeTag]];
 n/d
];

decode[node_List, env_Association] := Module[{tag},
 If[Length[node] == 0,
  Throw[failure["InvalidDAG", "Empty arithmetic node."], $decodeTag]];
 tag = First[node];
 Switch[tag,
  "Q", If[Length[node] != 3, Throw[failure["InvalidDAG", "Invalid rational node."], $decodeTag]];
   parseRational[node[[2]], node[[3]]],
  "I", If[Length[node] != 1, Throw[failure["InvalidDAG", "Invalid imaginary unit."], $decodeTag]]; I,
  "Var", If[Length[node] != 2 || !KeyExistsQ[env, node[[2]]],
    Throw[failure["InvalidDAG", "Undefined or forward variable reference."], $decodeTag]];
   env[node[[2]]],
  "Add", Plus @@ (decode[#, env] & /@ Rest[node]),
  "Mul", Times @@ (decode[#, env] & /@ Rest[node]),
  "Pow", If[Length[node] != 4, Throw[failure["InvalidDAG", "Invalid power node."], $decodeTag]];
   decode[node[[2]], env]^parseRational[node[[3]], node[[4]]],
  _, Throw[failure["InvalidDAG", "Unknown arithmetic node."], $decodeTag]
 ]
];
decode[_, _] := Throw[failure["InvalidDAG", "Invalid arithmetic tree."], $decodeTag];

decodeDAG[dag_Association] := Catch[Module[{env = <||>, assignments, name},
 assignments = Lookup[dag, "assignments", $Failed];
 If[!ListQ[assignments], Throw[failure["InvalidDAG", "Missing assignments."], $decodeTag]];
 Do[
  If[!MatchQ[a, {_String, _List}],
   Throw[failure["InvalidDAG", "Invalid assignment."], $decodeTag]];
  name = a[[1]];
  If[!StringMatchQ[name, RegularExpression["rrz|rru[1-9][0-9]*"]] || KeyExistsQ[env, name],
   Throw[failure["InvalidDAG", "Invalid or duplicate local name."], $decodeTag]];
  AssociateTo[env, name -> decode[a[[2]], env]],
  {a, assignments}];
 decode[Lookup[dag, "result", $Failed], env]
], $decodeTag];
decodeDAG[_] := failure["InvalidDAG", "Missing radical DAG."];

finish[data_Association, a_, verificationLimit_] := Module[{status, e, verified},
 status = Lookup[data, "status", "BackendFailure"];
 If[status =!= "Success",
  Return[failure[status, Lookup[data, "message", "The backend did not return a radical expression."],
   <|"Backend" -> data|>]]];
 e = Quiet@Check[decodeDAG[Lookup[data, "radical_dag", $Failed]], $Failed];
 If[e === $Failed || FailureQ[e] || !TrueQ[RadicalExpressionQ[e]],
  Return[failure["InvalidDAG", "The backend output is not a valid radical expression."]]];
 verified = TimeConstrained[TrueQ[RootReduce[e - a] === 0], verificationLimit, $Aborted];
 If[verified === $Aborted,
  Return[failure["ResourceLimit", "Exact Wolfram equality verification exceeded its time limit."]]];
 If[!TrueQ[verified],
  Return[failure["VerificationFailed", "The radical expression was not proved equal to the selected input."]]];
 <|"Status" -> "Success", "Expression" -> e, "Verified" -> True,
   "Method" -> Lookup[data, "method", "Python"], "Backend" -> data|>
];
finish[_, _, _] := failure["BackendFailure", "The backend response is not a JSON object."];

(* Numerical approximations propose a dyadic box. Exact algebraic inequalities
   and CountRoots certify it; no Mathematica/SymPy complex-index convention is
   assumed. The Python side independently checks the isolating rectangle. *)
isolatingRectangle[p_, x_, a_] := Module[
 {ar = RootReduce[Re[a]], ai = RootReduce[Im[a]], bits, scale, approx, center, box, lo, hi},
 Do[
  bits = 16*2^j; scale = 2^bits;
  approx = N[{ar, ai}, Ceiling[bits Log[10, 2]] + 30];
  center = Round[scale approx]/scale;
  box = {center[[1]] - 2/scale, center[[1]] + 2/scale,
         center[[2]] - 2/scale, center[[2]] + 2/scale};
  lo = box[[1]] + I box[[3]]; hi = box[[2]] + I box[[4]];
  If[TrueQ[box[[1]] < ar < box[[2]]] && TrueQ[box[[3]] < ai < box[[4]]] &&
     TrueQ[CountRoots[p, {x, lo, hi}] == 1], Return[box]],
  {j, 0, 15}];
 failure["ResourceLimit", "Could not certify an isolating rectangle within the refinement limit."]
];

RadicalRepresentation[a_, OptionsPattern[]] := Module[
 {r, x, p, coeff, native, method, py, path, bound, limit, box, args, process, data, verification},
 method = Replace[OptionValue[Method], Automatic -> "Automatic"];
 If[!MemberQ[{"Automatic", "Fast", "Galois"}, method],
  Return[failure["InvalidInput", "Method must be Automatic, Fast, or Galois (strings)."]]];
 bound = OptionValue["MaxFieldDegree"]; limit = OptionValue[TimeConstraint];
 verification = OptionValue["VerificationTimeConstraint"];
 If[!(bound === Infinity || (IntegerQ[bound] && bound > 0)),
  Return[failure["InvalidInput", "MaxFieldDegree must be a positive integer or Infinity."]]];
 If[!(limit === Infinity || (NumericQ[limit] && TrueQ[limit > 0])),
  Return[failure["InvalidInput", "TimeConstraint must be positive or Infinity."]]];
 If[!FreeQ[a, _Real], Return[failure["InvalidInput", "Inexact numbers are not accepted."]]];
 r = Quiet@Check[RootReduce[a], $Failed];
 If[r === $Failed, Return[failure["InvalidInput", "The input is not an exact algebraic number."]]];
 If[RadicalExpressionQ[r],
  Return[<|"Status" -> "Success", "Expression" -> r, "Verified" -> True, "Method" -> "AlreadyRadical"|>]];
 x = Unique["x"];
 p = Quiet@Check[MinimalPolynomial[r, x], $Failed];
 If[p === $Failed || !PolynomialQ[p, x],
  Return[failure["InvalidInput", "A rational minimal polynomial could not be obtained."]]];
 coeff = CoefficientList[p, x];
 If[!(And @@ (MatchQ[#, _Integer | _Rational] & /@ coeff)),
  Return[failure["InvalidInput", "The minimal polynomial must have rational coefficients."]]];
 If[TrueQ[OptionValue["NativeAttempt"]] && method =!= "Galois",
  native = TimeConstrained[Quiet@Check[ToRadicals[r], $Failed], Min[10, limit], $Failed];
  If[native =!= $Failed && RadicalExpressionQ[native] &&
     TrueQ[TimeConstrained[RootReduce[native - r] === 0, verification, False]],
   Return[<|"Status" -> "Success", "Expression" -> native,
    "Verified" -> True, "Method" -> "ToRadicals"|>]]];
 path = Replace[OptionValue["BackendPath"], Automatic -> $backendPath];
 py = Replace[OptionValue["PythonExecutable"],
  Automatic :> If[$OperatingSystem === "Windows", "python", "python3"]];
 If[!StringQ[path] || !FileExistsQ[path] || !StringQ[py],
  Return[failure["Configuration", "The Python executable or backend path is invalid."]]];
 box = TimeConstrained[isolatingRectangle[p, x, r],
  OptionValue["IsolationTimeConstraint"], $Aborted];
 If[box === $Aborted, Return[failure["ResourceLimit", "Root isolation exceeded its time limit."]]];
 If[FailureQ[box], Return[box]];
 args = {py, path,
  "--coefficients", ExportString[ratString /@ Reverse[coeff], "RawJSON"],
  "--rectangle", ExportString[ratString /@ box, "RawJSON"],
  "--method", Switch[method, "Automatic", "auto", "Fast", "fast", _, "galois"],
  "--max-degree", ToString[If[bound === Infinity, 0, bound], InputForm],
  "--timeout", ToString[If[limit === Infinity, 0, Ceiling[limit]], InputForm]};
 process = Quiet@Check[RunProcess[args], $Failed];
 If[process === $Failed || !AssociationQ[process],
  Return[failure["Configuration", "Python could not be started. Set PythonExecutable to its full path."]]];
 data = Quiet@Check[ImportString[Lookup[process, "StandardOutput", ""], "RawJSON"], $Failed];
 If[data === $Failed || !AssociationQ[data],
  Return[failure["BackendFailure", "Python returned no readable JSON result.",
   <|"StandardError" -> Lookup[process, "StandardError", ""]|>]]];
 finish[data, r, verification]
];

RootToRadicals[a_, opts : OptionsPattern[]] := Module[{r},
 r = RadicalRepresentation[a, opts];
 If[AssociationQ[r], r["Expression"], r]
];
ReadRadicalJSON[file_String, a_, OptionsPattern[]] := Module[{data},
 data = Quiet@Check[Import[file, "RawJSON"], $Failed];
 finish[data, a, OptionValue["VerificationTimeConstraint"]]
];
End[];
EndPackage[];
