(* ::Package:: *)
(* SystematicRadicals 1.0.0. MIT license. See article and README for guarantees.
   Native fast paths require only Wolfram Language. The general construction
   uses the bundled Python 3 + SymPy 1.14.0 backend, through a data-only JSON AST.
   No Root index is transferred between Wolfram Language and Python. *)

BeginPackage["SystematicRadicals`"];

Radicalize::usage = "Radicalize[a] returns an exactly verified radical expression for the exact algebraic number a, or Failure. Method -> \"Galois\" forces the general Python construction.";
RadicalReport::usage = "RadicalReport[a] returns an association containing the radical expression, minimal polynomial, method and diagnostics, or Failure.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] tests the strict grammar of rational constants, I, sums, products and rational powers. Root, trigonometric functions and approximate numbers are excluded.";
VerifyRadical::usage = "VerifyRadical[a,e] accepts only if e is a radical expression and RootReduce[e-a] is exactly zero. A timeout returns False, not a proof of inequality.";

Options[RadicalReport] = {
  Method -> Automatic,
  "PythonExecutable" -> Automatic,
  "TimeLimit" -> 120,
  "VerificationTimeLimit" -> 30,
  "MaxFieldDegree" -> 48,
  "VerifyCertificate" -> True
};
Options[Radicalize] = Options[RadicalReport];
Options[VerifyRadical] = {"TimeLimit" -> 30};

Begin["`Private`"];
$packageDirectory = DirectoryName[$InputFileName];
$backend = FileNameJoin[{$packageDirectory, "python", "systematic_radicals.py"}];
$decodeTag = Unique["decode"];

rationalQ[e_] := IntegerQ[e] || Head[e] === Rational;
RadicalExpressionQ[e_] := Which[
  rationalQ[e], True,
  Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
  Head[e] === Plus || Head[e] === Times,
    And @@ (RadicalExpressionQ /@ (List @@ e)),
  Head[e] === Power,
    rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False
];

VerifyRadical[a_, e_, OptionsPattern[]] := If[!RadicalExpressionQ[e], False,
  TimeConstrained[
    Quiet[Check[RootReduce[e - a] === 0, False]],
    OptionValue["TimeLimit"], False]
];

failure[tag_, message_, extra_: <||>] :=
  Failure[tag, Join[<|"MessageTemplate" -> message|>, extra]];

(* D_n(u+a/u,a) = u^n+(a/u)^n. *)
dickson[n_Integer, t_, a_] := Module[{u = 2, v = t, w, k},
  If[n == 0, Return[2]];
  Do[w = Expand[t v - a u]; u = v; v = w, {k, 2, n}]; v
];

rationalPowerCandidates[q_, k_Integer] := Module[{r},
  If[q < 0 && EvenQ[k], Return[{}]];
  r = Surd[q, k];
  If[!rationalQ[r], Return[{}]];
  If[EvenQ[k] && r != 0, {r, -r}, {r}]
];

(* This routine recognizes exact polynomial identities; it does not guess
   algebraic relations from approximate numbers. The caller enforces a budget. *)
nativeRoots[p0_, x_, depth_: 0] := Module[
  {p, n, c, q, exps, m, g, ans, z, a, b, u, rem, sols,
   v, off, hi, lo, candidates, pair, k, j},
  If[depth > 32, Return[$Failed]];
  n = Exponent[p0, x];
  p = Expand[p0/Coefficient[p0, x, n]];
  If[n <= 4,
    sols = Quiet[Check[x /. Solve[p == 0, x, Cubics -> True, Quartics -> True], $Failed]];
    If[ListQ[sols] && Length[sols] == n && And @@ (RadicalExpressionQ /@ sols),
      Return[<|"Roots" -> sols, "Method" -> "DegreeAtMostFour"|>]]
  ];
  c = -Coefficient[p, x, n - 1]/n;
  q = Expand[p /. x -> x + c];
  exps = Select[Range[n], Coefficient[q, x, #] != 0 &];
  m = Apply[GCD, exps];
  If[m > 1,
    g = Total[Table[Coefficient[q, x, m j] x^j, {j, 0, n/m}]];
    ans = nativeRoots[g, x, depth + 1];
    If[AssociationQ[ans],
      z = (-1)^(2/m);
      Return[<|"Roots" -> Flatten[Table[c + z^k u^(1/m),
          {u, ans["Roots"]}, {k, 0, m - 1}]],
        "Method" -> "PowerComposition/" <> ans["Method"]|>]]
  ];
  If[n >= 3,
    a = -Coefficient[q, x, n - 2]/n;
    rem = Expand[q - dickson[n, x, a]];
    If[FreeQ[rem, x],
      b = rem; z = (-b + Sqrt[b^2 - 4 a^n])/2;
      If[z === 0, z = (-b - Sqrt[b^2 - 4 a^n])/2];
      If[z =!= 0,
        u = z^(1/n);
        Return[<|"Roots" -> Table[
          c + (-1)^(2 k/n) u + a/((-1)^(2 k/n) u), {k, 0, n - 1}],
          "Method" -> "Dickson"|>]]]
  ];
  If[EvenQ[n],
    m = n/2;
    Do[
      v = pair[[1]]; off = pair[[2]];
      If[Coefficient[v, x, 0] === 0, Continue[]];
      candidates = {};
      Do[
        hi = Coefficient[v, x, m + k]; lo = Coefficient[v, x, m - k];
        If[hi =!= 0,
          candidates = rationalPowerCandidates[lo/hi, k]; Break[]], {k, 1, m}];
      Do[
        If[a === 0 || !(And @@ Table[
            Coefficient[v, x, m - k] === a^k Coefficient[v, x, m + k], {k, 1, m}]),
          Continue[]];
        g = Expand[Coefficient[v, x, m] + Total[Table[
          Coefficient[v, x, m + k] dickson[k, x, a], {k, 1, m}]]];
        ans = nativeRoots[g, x, depth + 1];
        If[AssociationQ[ans],
          Return[<|"Roots" -> Flatten[Table[
            off + (u + j Sqrt[u^2 - 4 a])/2, {u, ans["Roots"]}, {j, {1, -1}}]],
            "Method" -> "Reciprocal/" <> ans["Method"]|>]], {a, candidates}],
      {pair, {{p, 0}, {q, c}}}]
  ];
  $Failed
];

(* Read only validated integer text. Never evaluate strings from a subprocess. *)
integerText[t_] := Module[{neg},
  If[!StringQ[t] || !StringMatchQ[t, RegularExpression["-?(0|[1-9][0-9]*)"]],
    Throw[failure["ProtocolError", "Invalid integer text in backend response."], $decodeTag]];
  neg = StringStartsQ[t, "-"];
  If[neg, -FromDigits[StringDrop[t, 1]], FromDigits[t]]
];

rationalText[a_, b_] := Module[{num = integerText[a], den = integerText[b]},
  If[den <= 0, Throw[failure["ProtocolError", "Nonpositive denominator."], $decodeTag]];
  num/den
];

decodeNode[node_, env_List] := Module[{tag, k},
  If[!ListQ[node] || Length[node] < 1,
    Throw[failure["ProtocolError", "Invalid radical syntax tree."], $decodeTag]];
  tag = First[node];
  If[(tag === "Q" && Length[node] != 3) || (tag === "Pow" && Length[node] != 4),
    Throw[failure["ProtocolError", "Invalid node arity."], $decodeTag]];
  Switch[tag,
    "Q", rationalText[node[[2]], node[[3]]],
    "Ref", If[Length[node] == 2 && IntegerQ[node[[2]]] &&
        0 <= node[[2]] < Length[env], env[[node[[2]] + 1]],
      Throw[failure["ProtocolError", "Invalid or forward radical reference."], $decodeTag]],
    "Add", Plus @@ (decodeNode[#, env] & /@ Rest[node]),
    "Mul", Times @@ (decodeNode[#, env] & /@ Rest[node]),
    "Pow", If[Length[node] == 4,
      decodeNode[node[[2]], env]^rationalText[node[[3]], node[[4]]]],
    _, Throw[failure["ProtocolError", "Unsupported radical syntax tag."], $decodeTag]
  ]
];

decodeResponse[data_Association] := Catch[Module[{env = {}, roots, node},
  If[!ListQ[Lookup[data, "assignments", None]] || !ListQ[Lookup[data, "roots", None]],
    Throw[failure["ProtocolError", "Missing radical assignments or roots."], $decodeTag]];
  Do[AppendTo[env, decodeNode[node, env]], {node, data["assignments"]}];
  roots = decodeNode[#, env] & /@ data["roots"];
  If[!(And @@ (RadicalExpressionQ /@ roots)),
    Throw[failure["ProtocolError", "Response contains a nonradical expression."], $decodeTag]];
  roots
], $decodeTag];

RadicalReport[input_, OptionsPattern[]] := Module[
  {a, x, p, cs, method, limit, verifyLimit, maxDegree, py, start,
   remaining, choose, report, ans, candidates, chosen, request, process, data, nativeBudget},
  method = OptionValue[Method]; limit = OptionValue["TimeLimit"];
  verifyLimit = OptionValue["VerificationTimeLimit"];
  maxDegree = OptionValue["MaxFieldDegree"];
  If[!MemberQ[{Automatic, "Native", "Python", "Galois"}, method],
    Return[failure["InvalidInput", "Unknown Method option."]]];
  If[!(limit === Infinity || (NumberQ[limit] && TrueQ[limit > 0])) ||
     !(verifyLimit === Infinity || (NumberQ[verifyLimit] && TrueQ[verifyLimit > 0])) ||
     !(maxDegree === Infinity || (IntegerQ[maxDegree] && maxDegree > 0)),
    Return[failure["InvalidInput", "Budgets must be positive, or Infinity."]]];
  start = AbsoluteTime[];
  remaining[] := If[limit === Infinity, Infinity, Max[0.001, limit - (AbsoluteTime[] - start)]];
  If[!FreeQ[input, _Real], Return[failure["InvalidInput", "Approximate input is not supported."]]];
  a = TimeConstrained[Quiet[Check[RootReduce[input], $Failed]], remaining[], $Failed];
  If[a === $Failed, Return[failure["InvalidInput", "Could not normalize the algebraic input."]]];
  x = Unique["x"];
  p = TimeConstrained[Quiet[Check[MinimalPolynomial[a, x], $Failed]], remaining[], $Failed];
  If[p === $Failed || !PolynomialQ[p, x] || Exponent[p, x] < 1,
    Return[failure["InvalidInput", "Input must be an exact number algebraic over the rationals."]]];
  cs = CoefficientList[p, x];
  If[!(And @@ (rationalQ /@ cs)),
    Return[failure["InvalidInput", "Minimal-polynomial coefficients must be rational."]]];
  p = Expand[p/Last[cs]];
  report[e_, m_, d_: <||>] := <|"Status" -> "Success", "Expression" -> e,
    "MinimalPolynomial" -> Function[Evaluate[p /. x -> Slot[1]]],
    "Method" -> m, "Verified" -> True, "Diagnostics" -> d|>;
  If[RadicalExpressionQ[input], Return[report[input, "AlreadyRadical"]]];
  choose[rr_List] := Module[{order, i},
    order = Ordering[Quiet[Check[Abs[N[# - a, 40]], Infinity]] & /@ rr];
    Do[
      If[limit =!= Infinity && AbsoluteTime[] - start >= limit, Return[$Failed]];
      If[VerifyRadical[a, rr[[i]], "TimeLimit" -> Min[verifyLimit, remaining[]]],
        Return[rr[[i]]]], {i, order}];
    $Failed
  ];
  If[MemberQ[{Automatic, "Native"}, method],
    (* Reserve half of a finite total budget for later stages. *)
    nativeBudget = If[limit === Infinity, Infinity, remaining[]/2];
    ans = TimeConstrained[Quiet[Check[ToRadicals[a], $Failed]], nativeBudget, $Failed];
    If[ans =!= $Failed && RadicalExpressionQ[ans],
      chosen = choose[{ans}]; If[chosen =!= $Failed, Return[report[chosen, "ToRadicals"]]]];
    ans = TimeConstrained[nativeRoots[p, x], Min[nativeBudget, remaining[]], $Failed];
    If[AssociationQ[ans],
      chosen = choose[ans["Roots"]];
      If[chosen =!= $Failed, Return[report[chosen, ans["Method"]]]]];
  ];
  If[method === "Native",
    Return[failure["NotFound", "No exactly verified native result was obtained; this is not a nonsolvability proof."]]];
  If[limit =!= Infinity && AbsoluteTime[] - start >= limit,
    Return[failure["ResourceLimit", "Time budget exhausted before the general backend."]]];
  If[!FileExistsQ[$backend],
    Return[failure["BackendUnavailable", "Bundled Python backend was not found.", <|"Path" -> $backend|>]]];
  py = Replace[OptionValue["PythonExecutable"],
    Automatic :> If[$OperatingSystem === "Windows", "python", "python3"]];
  If[!StringQ[py], Return[failure["InvalidInput", "PythonExecutable must be an executable path string."]]];
  cs = Reverse[CoefficientList[p, x]];
  request = <|"coefficients" -> ({ToString[Numerator[#], InputForm],
        ToString[Denominator[#], InputForm]} & /@ cs),
    "method" -> If[method === "Galois", "galois", "auto"],
    "max_field_degree" -> Replace[maxDegree, Infinity -> Null],
    "max_seconds" -> If[limit === Infinity, Null, N[remaining[]]],
    "verify" -> TrueQ[OptionValue["VerifyCertificate"]], "certificate" -> False|>;
  process = Quiet[Check[RunProcess[{py, $backend, "--json"}, All,
    ExportString[request, "RawJSON"]], $Failed]];
  If[!AssociationQ[process],
    Return[failure["BackendUnavailable", "Python could not be started. Set PythonExecutable to its full path."]]];
  data = Quiet[Check[ImportString[Lookup[process, "StandardOutput", ""], "RawJSON"], $Failed]];
  If[!AssociationQ[data],
    Return[failure["BackendError", "Backend returned no valid JSON response.",
      <|"StandardError" -> Lookup[process, "StandardError", ""]|>]]];
  If[Lookup[data, "status", "BackendError"] =!= "Success",
    Return[failure[Lookup[data, "status", "BackendError"],
      Lookup[data, "message", "Backend did not return a result."],
      <|"Details" -> Lookup[data, "details", <||>]|>]]];
  candidates = decodeResponse[data];
  If[FailureQ[candidates], Return[candidates]];
  chosen = choose[candidates];
  If[chosen === $Failed,
    Return[failure["VerificationFailed", "No candidate was exactly matched to the requested Root within the verification budget.",
      <|"BackendMethod" -> Lookup[data, "method", "Unknown"]|>]]];
  report[chosen, Lookup[data, "method", "Python"], Lookup[data, "diagnostics", <||>]]
];

Radicalize[a_, opts : OptionsPattern[]] := Module[{r = RadicalReport[a, opts]},
  If[AssociationQ[r], r["Expression"], r]
];

End[];
EndPackage[];
