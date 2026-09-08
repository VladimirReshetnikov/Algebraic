(* ::Package:: *)
(* SystematicRadicals 0.1.0. See README for test status and limits.
   Only documented WL operations are used. The complete reference constructor
   runs in the supplied Python backend; native WL paths are certified shortcuts.
   No externally supplied program text is evaluated. *)

BeginPackage["SystematicRadicals`"];
SystematicToRadicals::usage = "SystematicToRadicals[a,opts] converts an exact algebraic number to a verified radical expression, or returns a Failure with a specific status.";
RadicalData::usage = "RadicalData[a,opts] returns an Association containing the radical expression, method, and verification data, or Failure. Only NotSolvable is a mathematical negative answer.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] tests the strict grammar: exact rationals, I, addition, multiplication, and rational powers. Root, AlgebraicNumber, trigonometric functions and approximate numbers are excluded.";
ExactRadicalEqualQ::usage = "ExactRadicalEqualQ[a,b] returns True only when RootReduce[a-b] is exactly 0.";
PairSumResolvent::usage = "PairSumResolvent[f,x,y] gives the monic polynomial whose roots are the sums of unordered pairs of distinct indexed roots of square-free rational f. Repeated pair sums retain their multiplicities.";

Options[RadicalData] = {Method -> Automatic, TimeConstraint -> 300,
  "PythonCommand" -> {"python"}, "BackendScript" -> Automatic,
  "MaxFieldDegree" -> 96, "PairSumMaxDegree" -> 10,
  "MaxExtensionDegree" -> 6, "ReplayCertificate" -> True};
Options[SystematicToRadicals] = Options[RadicalData];

Begin["`Private`"];
$packageDirectory = DirectoryName[$InputFileName];
fail[tag_, text_, extra_: <||>] := Failure[tag, Join[<|"MessageTemplate" -> text|>, extra]];
ratQ[e_] := IntegerQ[e] || Head[e] === Rational;
RadicalExpressionQ[e_] := Which[
  ratQ[e], True,
  Head[e] === Complex, ratQ[Re[e]] && ratQ[Im[e]],
  Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, RadicalExpressionQ],
  Head[e] === Power, ratQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];
ExactRadicalEqualQ[a_, b_] := TrueQ[Quiet[Check[RootReduce[a - b], $Failed]] === 0];

success[e_, a_, method_, extra_: <||>] := If[
  RadicalExpressionQ[e] && ExactRadicalEqualQ[e, a],
  Join[<|"Status" -> "Success", "Expression" -> e, "Method" -> method,
    "Verified" -> True, "Verification" -> "RootReduce[expression-input] === 0"|>, extra],
  None];

PairSumResolvent[f_, x_Symbol, y_Symbol] := Module[
  {p, n, res, diag, qr, fs},
  If[!PolynomialQ[f, x] || !AllTrue[CoefficientList[f, x], ratQ],
    Return[fail["InvalidInput", "A rational polynomial is required."]]];
  p = Expand[f/Coefficient[f, x, Exponent[f, x]]];
  n = Exponent[p, x];
  If[n < 2 || Exponent[PolynomialGCD[p, D[p, x]], x] > 0,
    Return[fail["InvalidInput", "A square-free polynomial of degree at least two is required."]]];
  res = Resultant[p, p /. x -> y - x, x];
  diag = Expand[2^n (p /. x -> y/2)];
  qr = PolynomialQuotientRemainder[res, diag, y];
  If[Last[qr] =!= 0, Return[fail["VerificationFailure", "Pair-sum diagonal division failed."]]];
  fs = FactorList[First[qr]];
  If[First[fs] =!= {1, 1} || !AllTrue[Rest[fs], EvenQ[Last[#]] &],
    Return[fail["VerificationFailure", "Pair-sum quotient is not a monic square."]]];
  Expand[Times @@ (#[[1]]^(#[[2]]/2) & /@ Rest[fs])]
];

(* A local implementation avoids depending on the naming of a special-function package. *)
dickson[n_Integer, x_, a_] := Module[{d0 = 2, d1 = x, t, j},
  If[n === 0, Return[d0]];
  Do[t = Expand[x d1 - a d0]; d0 = d1; d1 = t, {j, 2, n}]; d1];

dicksonCandidates[f_, x_] := Module[{n, p, shift, q, a, c, t, u},
  n = Exponent[f, x]; If[n < 2, Return[{}]];
  p = Expand[f/Coefficient[f, x, Exponent[f, x]]];
  shift = Coefficient[p, x, n - 1]/n;
  q = Expand[p /. x -> x - shift];
  a = -Coefficient[q, x, n - 2]/n;
  c = Coefficient[q, x, 0] - Coefficient[dickson[n, x, a], x, 0];
  If[Expand[q - dickson[n, x, a] - c] =!= 0, Return[{}]];
  t = (-c + Sqrt[c^2 - 4 a^n])/2;
  If[ExactRadicalEqualQ[t, 0], t = (-c - Sqrt[c^2 - 4 a^n])/2];
  If[ExactRadicalEqualQ[t, 0], Return[{}]];
  u = t^(1/n);
  Table[With[{v = (-1)^(2 k/n) u}, v + a/v - shift], {k, 0, n - 1}]
];

rootList[p_, x_] := With[{body = p /. x -> Slot[1], n = Exponent[p, x]},
  Table[Root[Function[body], j], {j, n}]];

nativeSearch[a_, f_, x_, pairBound_, extensionBound_] := Module[
  {e, result, candidates, r, y, q, b, fac, coeff, A, B, C, qfactors, ffactors},
  e = Quiet[Check[ToRadicals[a], $Failed]];
  result = success[e, a, "ToRadicals"];
  If[AssociationQ[result], Return[result]];
  candidates = dicksonCandidates[f, x];
  Do[result = success[e, a, "Dickson"]; If[AssociationQ[result], Return[result]], {e, candidates}];
  If[Exponent[f, x] > pairBound, Return[None]];
  r = PairSumResolvent[f, x, y];
  If[FailureQ[r], Return[None]];
  qfactors = Rest[FactorList[r]];
  Do[
    q = item[[1]];
    (* The native path limits auxiliary coefficients to degree <= 4. The
       Python path also recognizes higher-degree Dickson auxiliary fields. *)
    If[Exponent[q, y] > Min[4, extensionBound], Continue[]];
    Do[
      ffactors = Quiet[Check[Rest[FactorList[f, Extension -> b]], {}]];
      Do[
        fac = item2[[1]];
        If[!MemberQ[{1, 2}, Exponent[fac, x]], Continue[]];
        coeff = (Quiet[Check[ToRadicals[RootReduce[#]], $Failed]] &) /@ CoefficientList[fac, x];
        If[!AllTrue[coeff, RadicalExpressionQ], Continue[]];
        candidates = If[Length[coeff] === 2, {-coeff[[1]]/coeff[[2]]},
          {C, B, A} = coeff; {(-B + Sqrt[B^2 - 4 A C])/(2 A), (-B - Sqrt[B^2 - 4 A C])/(2 A)}];
        Do[result = success[e, a, "PairSum", <|"AuxiliaryPolynomial" -> q|>];
          If[AssociationQ[result], Return[result]], {e, candidates}],
        {item2, ffactors}],
      {b, rootList[q, y]}],
    {item, qfactors}];
  None
];

(* Strict JSON expression decoder: no ToExpression, Get or ReleaseHold on
   backend-provided content. The only accepted leaves are signed integers. *)
parseInteger[s_String] := Module[{negative, digits},
  If[!StringMatchQ[s, RegularExpression["[+-]?[0-9]+"]], Throw[$Failed, "BadAST"]];
  negative = StringStartsQ[s, "-"];
  digits = If[StringStartsQ[s, "+"] || negative, StringDrop[s, 1], s];
  If[negative, -1, 1] FromDigits[digits]
];
parseInteger[_] := Throw[$Failed, "BadAST"];
decodeAST[a_] := Module[{tag, base, exponent, den},
  If[!ListQ[a] || Length[a] < 1, Throw[$Failed, "BadAST"]];
  tag = First[a];
  Switch[tag,
    "Q", If[Length[a] =!= 3, Throw[$Failed, "BadAST"]];
      den = parseInteger[a[[3]]]; If[den <= 0, Throw[$Failed, "BadAST"]]; parseInteger[a[[2]]]/den,
    "A", Plus @@ (decodeAST /@ Rest[a]),
    "M", Times @@ (decodeAST /@ Rest[a]),
    "P", If[Length[a] =!= 3, Throw[$Failed, "BadAST"]];
      base = decodeAST[a[[2]]]; exponent = decodeAST[a[[3]]];
      If[!ratQ[exponent], Throw[$Failed, "BadAST"]]; base^exponent,
    _, Throw[$Failed, "BadAST"]]
];

pythonSearch[a_, f_, x_, method_, seconds_, python_, script_, maxDegree_, pairBound_, extensionBound_, replay_] :=
 Module[{cmd, path, request, process, response, candidates, result, status, backendMethod},
  cmd = If[StringQ[python], {python}, python];
  If[!ListQ[cmd] || Length[cmd] === 0 || !AllTrue[cmd, StringQ],
    Return[fail["InvalidInput", "PythonCommand must be an executable string or argument list."]]];
  path = If[script === Automatic, FileNameJoin[{$packageDirectory, "..", "python", "radical_roots", "cli.py"}], script];
  If[!StringQ[path] || !FileExistsQ[path],
    Return[fail["DependencyFailure", "Cannot locate the supplied Python backend.", <|"BackendScript" -> path|>]]];
  backendMethod = Switch[method, "Galois", "galois", "PythonFast", "fast", _, "auto"];
  request = <|"coefficients" -> (StringDelete[ToString[#, InputForm], Whitespace] & /@ CoefficientList[f, x]),
    "method" -> backendMethod, "seconds" -> If[seconds === Infinity, Null, seconds],
    "max_field_degree" -> If[maxDegree === Infinity, Null, maxDegree],
    "pair_sum_max_degree" -> pairBound, "max_extension_degree" -> extensionBound,
    "verify" -> TrueQ[replay]|>;
  process = Quiet[Check[RunProcess[Join[cmd, {path}], All, ExportString[request, "RawJSON"]], $Failed]];
  If[!AssociationQ[process], Return[fail["DependencyFailure", "Python could not be started. Check PythonCommand and install requirements.txt."]]];
  response = Quiet[Check[ImportString[Lookup[process, "StandardOutput", ""], "RawJSON"], $Failed]];
  If[!AssociationQ[response], Return[fail["BackendError", "Python did not return JSON.",
    <|"StandardError" -> Lookup[process, "StandardError", ""]|>]]];
  status = Lookup[response, "status", "BackendError"];
  If[status =!= "Success", Return[fail[status, Lookup[response, "message", "Backend failure."], <|"BackendData" -> response|>]]];
  candidates = Catch[decodeAST /@ Lookup[response, "expressions", {}], "BadAST"];
  If[!ListQ[candidates], Return[fail["VerificationFailure", "Invalid backend expression grammar."]]];
  (* No cross-system index assumption. RootReduce chooses the original WL conjugate. *)
  Do[result = success[e, a, "Python/" <> Lookup[Lookup[response, "metadata", <||>], "method", "unknown"],
      <|"BackendData" -> response|>];
    If[AssociationQ[result], Return[result]], {e, candidates}];
  fail["VerificationFailure", "No returned radical expression exactly matches the requested algebraic number."]
];

run[a_, method_, seconds_, python_, script_, maxDegree_, pairBound_, extensionBound_, replay_] := Module[
  {r, f, x, result, nativeSeconds, start = AbsoluteTime[], remaining},
  If[!FreeQ[a, _Real], Return[fail["InvalidInput", "An exact algebraic number is required; approximate numbers are not accepted."]]];
  r = Quiet[Check[RootReduce[a], $Failed]];
  If[ratQ[r], Return[success[r, a, "Rational"]]];
  f = Quiet[Check[MinimalPolynomial[r, x], $Failed]];
  If[f === $Failed || !PolynomialQ[f, x] || Exponent[f, x] < 1 ||
    !AllTrue[CoefficientList[f, x], ratQ],
    Return[fail["InvalidInput", "The input must be a parameter-free algebraic number over the rationals."]]];
  If[MemberQ[{Automatic, "Native"}, method],
    nativeSeconds = If[method === "Native" || seconds === Infinity, seconds, Min[30, seconds/4]];
    result = TimeConstrained[nativeSearch[r, f, x, pairBound, extensionBound], nativeSeconds, $TimedOut];
    If[AssociationQ[result], Return[result]];
    If[method === "Native", Return[If[result === $TimedOut,
      fail["ResourceLimit", "Native search time limit reached; solvability is undetermined."],
      fail["SearchExhausted", "Native shortcuts exhausted; solvability is undetermined."]]]]];
  remaining = If[seconds === Infinity, Infinity, Max[0.01, seconds - (AbsoluteTime[] - start)]];
  pythonSearch[r, f, x, method, remaining, python, script, maxDegree, pairBound, extensionBound, replay]
];

RadicalData[a_, OptionsPattern[]] := Module[{method = OptionValue[Method], seconds = OptionValue[TimeConstraint]},
  If[!MemberQ[{Automatic, "Native", "Python", "PythonFast", "Galois"}, method],
    Return[fail["InvalidInput", "Unknown method."]]];
  If[seconds =!= Infinity && !(NumberQ[seconds] && TrueQ[seconds > 0]),
    Return[fail["InvalidInput", "TimeConstraint must be positive or Infinity."]]];
  TimeConstrained[
    run[a, method, seconds, OptionValue["PythonCommand"], OptionValue["BackendScript"],
      OptionValue["MaxFieldDegree"], OptionValue["PairSumMaxDegree"],
      OptionValue["MaxExtensionDegree"], OptionValue["ReplayCertificate"]],
    seconds, fail["ResourceLimit", "Overall time limit reached; solvability is undetermined."]]
];
SystematicToRadicals[a_, opts : OptionsPattern[]] := Module[{data = RadicalData[a, opts]},
  If[AssociationQ[data], data["Expression"], data]];

End[];
EndPackage[];
