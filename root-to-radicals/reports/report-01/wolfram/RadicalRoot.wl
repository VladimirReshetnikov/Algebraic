(* RadicalRoot 1.0.0 -- exact algebraic-number to radical conversion.
   Python/SymPy backend plus a native ToRadicals fast path.
   The Wolfram adapter was source-reviewed but could not be runtime-tested
   in the delivery environment. See README.md and tests/RadicalRoot.wlt. *)
BeginPackage["RadicalRoot`"];
RadicalRoot::usage = "RadicalRoot[a] expresses the exact algebraic number a in arithmetic radicals when a verified construction succeeds. A Failure distinguishes non-solvability from resource exhaustion.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] tests whether e contains only rational numbers, I, arithmetic operations, and rational powers.";
Begin["`Private`"];
$BackendFile = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", "python", "cli.py"}]];

Clear[radicalQ];
radicalQ[e_Integer] := True;
radicalQ[e_Rational] := True;
radicalQ[Complex[a_, b_]] := radicalQ[a] && radicalQ[b];
radicalQ[e_Plus] := And @@ (radicalQ /@ (List @@ e));
radicalQ[e_Times] := And @@ (radicalQ /@ (List @@ e));
radicalQ[Power[a_, b_]] := radicalQ[a] && (IntegerQ[b] || Head[b] === Rational);
radicalQ[_] := False;
RadicalExpressionQ[e_] := TrueQ[radicalQ[e]];

Clear[decode];
decode[node_, env_Association] := Module[{tag},
  If[!ListQ[node] || Length[node] < 1 || !StringQ[First[node]], Throw[Failure["MalformedAST", <||>], "AST"]];
  tag = First[node];
  Switch[tag,
    "q", If[Length[node] != 3 || !IntegerQ[node[[2]]] || !IntegerQ[node[[3]]] || node[[3]] <= 0,
      Throw[Failure["MalformedRational", <||>], "AST"]]; node[[2]]/node[[3]],
    "ref", If[Length[node] != 2 || !StringQ[node[[2]]] || !KeyExistsQ[env, node[[2]]],
      Throw[Failure["UnknownReference", <||>], "AST"]]; env[node[[2]]],
    "add", Plus @@ (decode[#, env] & /@ Rest[node]),
    "mul", Times @@ (decode[#, env] & /@ Rest[node]),
    "pow", If[Length[node] != 4 || !IntegerQ[node[[3]]] || !IntegerQ[node[[4]]] || node[[4]] <= 0,
      Throw[Failure["MalformedPower", <||>], "AST"]]; decode[node[[2]], env]^(node[[3]]/node[[4]]),
    _, Throw[Failure["UnknownASTOperation", <|"Operation" -> tag|>], "AST"]
  ]
];

Options[RadicalRoot] = {
  "PythonExecutable" -> "python", "BackendFile" -> Automatic,
  "Method" -> "Automatic", "UseNative" -> True, "NativeTimeLimit" -> 5,
  "TimeLimit" -> 120, "VerificationTimeLimit" -> 120,
  "MaximumFieldDegree" -> 128, "MaximumCandidates" -> 1000000,
  "Return" -> "Expression"
};

RadicalRoot[a_, OptionsPattern[]] := Module[
  {rr, x, f, cs, candidate, native, check, req, raw, data, env = <||>, defs, roots,
   exprs, name, value, answer, backend, method, tim, vtim, ret, index, verified},
  tim = OptionValue["TimeLimit"]; vtim = OptionValue["VerificationTimeLimit"];
  ret = OptionValue["Return"];
  If[!MemberQ[{"Expression", "Data"}, ret], Return[Failure["InvalidReturnOption", <||>]]];
  If[!FreeQ[a, _Real], Return[Failure["InexactInput", <|"MessageTemplate" -> "Exact coefficients and an exact algebraic number are required."|>]]];
  rr = Quiet[Check[RootReduce[a], $Failed]];
  f = Quiet[Check[MinimalPolynomial[rr, x], $Failed]];
  If[f === $Failed || !PolynomialQ[f, x], Return[Failure["UnsupportedInput", <|"Input" -> a|>]]];
  cs = CoefficientList[f, x];
  If[Length[cs] < 2 || !And @@ (MatchQ[#, _Integer | _Rational] & /@ cs),
    Return[Failure["UnsupportedBaseField", <|"MessageTemplate" -> "A numerical algebraic number over the rationals is required; parameter-dependent roots are not supported."|>]]];
  check[e_] := TimeConstrained[Quiet[Check[RootReduce[e - rr] === 0, False]], vtim, $Aborted];
  If[TrueQ[OptionValue["UseNative"]],
    native = TimeConstrained[Quiet[Check[ToRadicals[rr], $Failed]], OptionValue["NativeTimeLimit"], $Failed];
    If[native =!= $Failed && RadicalExpressionQ[native] && TrueQ[check[native]],
      Return[If[ret === "Expression", native,
        <|"Expression" -> native, "Method" -> "NativeToRadicals", "WolframVerified" -> True|>]]]
  ];
  backend = Replace[OptionValue["BackendFile"], Automatic -> $BackendFile];
  If[!StringQ[backend] || !FileExistsQ[backend], Return[Failure["MissingBackend", <|"Path" -> backend|>]]];
  method = Switch[OptionValue["Method"], "Automatic", "auto", "General", "general", "Structural", "structural", _, $Failed];
  If[method === $Failed, Return[Failure["InvalidMethod", <||>]]];
  req = <|"action" -> "all", "coefficients" -> (ToString[#, InputForm] & /@ Reverse[cs]),
    "method" -> method, "verify" -> True,
    "timeout" -> Replace[tim, Infinity -> Null],
    "max_field_degree" -> Replace[OptionValue["MaximumFieldDegree"], Infinity -> Null],
    "max_candidates" -> Replace[OptionValue["MaximumCandidates"], Infinity -> Null]|>;
  raw = Quiet[Check[RunProcess[{OptionValue["PythonExecutable"], backend, "--json"}, All,
      ExportString[req, "RawJSON"]], $Failed]];
  If[raw === $Failed || !AssociationQ[raw], Return[Failure["BackendLaunch", <|"PythonExecutable" -> OptionValue["PythonExecutable"]|>]]];
  data = Quiet[Check[ImportString[raw["StandardOutput"], "RawJSON"], $Failed]];
  If[!AssociationQ[data], Return[Failure["BackendProtocol", <|"Process" -> raw|>]]];
  If[MemberQ[{"Success", "NotSolvable"}, Lookup[data, "status", "Error"]] && !TrueQ[Lookup[data, "verified", False]],
    Return[Failure["UnverifiedBackendResult", <|"Backend" -> data|>]]];
  Switch[Lookup[data, "status", "Error"],
    "NotSolvable", Return[Failure["NotSolvableByRadicals", <|"Backend" -> data|>]],
    "Unknown", Return[Failure["Undetermined", <|"Backend" -> data|>]],
    "Success", Null,
    _, Return[Failure["BackendError", <|"Backend" -> data, "StandardError" -> raw["StandardError"]|>]]
  ];
  If[!TrueQ[Lookup[data, "verified", False]], Return[Failure["UnverifiedBackendResult", <|"Backend" -> data|>]]];
  defs = Lookup[data, "definitions", {}]; roots = Lookup[data, "roots", {}];
  exprs = Catch[
    Do[
      name = def["name"];
      If[!StringQ[name] || KeyExistsQ[env, name], Throw[Failure["DuplicateDefinition", <||>], "AST"]];
      value = decode[def["expression"], env]; AssociateTo[env, name -> value],
      {def, defs}];
    decode[#["expression"], env] & /@ roots,
    "AST"
  ];
  If[FailureQ[exprs], Return[exprs]];
  If[!ListQ[exprs] || !And @@ (RadicalExpressionQ /@ exprs), Return[Failure["NonRadicalOutput", <||>]]];
  (* Never assume Python's and Wolfram's complex root index conventions agree. *)
  answer = Missing["NotMatched"]; index = Missing["NotMatched"];
  Do[
    verified = check[exprs[[j]]];
    If[TrueQ[verified], answer = exprs[[j]]; index = roots[[j]]["index"]; Break[]],
    {j, Length[exprs]}];
  If[MissingQ[answer], Return[Failure["EmbeddingNotCertified", <|"Backend" -> data|>]]];
  If[ret === "Expression", answer,
    <|"Expression" -> answer, "WolframVerified" -> True, "BackendRootIndex" -> index, "Backend" -> data|>]
];

End[];
EndPackage[];
