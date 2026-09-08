(* ::Package:: *)
(* AlgebraicDecomposition 1.0.0 -- exact characteristic-zero decomposition.
   Original implementation supplied with the accompanying article.
   All coefficient arrays are in ASCENDING order. No Factor, Solve,
   numerical zero tests, or calls to the built-in Decompose are used. *)

BeginPackage["AlgebraicDecomposition`"];

AlgebraicDecompose::usage =
 "AlgebraicDecompose[p,x] returns one complete decomposition {f1,...,fr}, outermost first, with exact algebraic coefficients. All factors except the first are monic with zero constant term. Constants and linear inputs return {p}.";
AlgebraicDecompositions::usage =
 "AlgebraicDecompositions[p,x] returns all complete decompositions modulo insertion of affine maps, in normalized form. Option \"MaxDecompositions\" (default 1000) is a positive integer or Infinity. A limit failure contains partial output, never an assertion of completeness.";
AlgebraicRightDecompositions::usage =
 "AlgebraicRightDecompositions[p,x] returns every proper pair {g,h} with p=g(h), h monic and h[0]=0, sorted by degree of h. An empty list proves indecomposability when Degree[p]>=2.";
AlgebraicDecompositionAttempt::usage =
 "AlgebraicDecompositionAttempt[p,x,d] returns the unique normalized candidate of proper right degree d, its recovered outer polynomial, and an exact residual certificate. Invalid degrees return Failure.";
ComposeAlgebraicPolynomials::usage =
 "ComposeAlgebraicPolynomials[{f1,...,fr},x] computes f1[f2[...fr[x]...]] by exact coefficient arithmetic. The input list must be nonempty.";
VerifyAlgebraicDecomposition::usage =
 "VerifyAlgebraicDecomposition[p,{f1,...,fr},x] independently recomposes the factors and returns exact identity, normalization, and indecomposability checks. Constants and linear polynomials are handled as singleton conventions, not as indecomposable nonlinear factors.";

Options[AlgebraicDecompositions] = {"MaxDecompositions" -> 1000};

Begin["`Private`"];

(* A package-private catch tag does not intercept unrelated user Throws. *)
fail[tag_String, text_String, extra_: <||>] :=
 Throw[Failure[tag, Join[<|"MessageTemplate" -> text|>, extra]], adFailureTag];

(* Cheap rational cases avoid algebraic-number conversion overhead. *)
rr[z_Integer] := z;
rr[z_Rational] := z;
rr[z_] := Module[{r},
 r = Quiet[Check[RootReduce[z], $Failed]];
 If[r === $Failed || !FreeQ[r, _RootReduce],
  fail["AlgebraicArithmetic", "Exact coefficient reduction did not complete.",
   <|"Expression" -> z|>]];
 r
];

trim[v_List] := Module[{w = v},
 If[w === {}, Return[{0}]];
 While[Length[w] > 1 && Last[w] === 0, w = Most[w]];
 w
];

deg[v_List] := If[v === {0}, -Infinity, Length[v] - 1];

(* Validation takes place AFTER coefficient reduction and BEFORE degree tests.
   In particular, a high-degree coefficient may be algebraically zero. *)
coefficients[p_, x_Symbol] := Module[{q, c, r},
 If[!FreeQ[p, _?InexactNumberQ],
  fail["InexactInput", "Approximate numbers are not accepted; provide exact algebraic coefficients."]];
 q = Quiet[Check[Expand[p], $Failed]];
 If[q === $Failed || !TrueQ[PolynomialQ[q, x]],
  fail["NotPolynomial", "The input must be a univariate polynomial in the specified symbol."]];
 c = CoefficientList[q, x];
 If[c === {}, c = {0}];
 r = rr /@ c;
 If[!And @@ (TrueQ[Element[#, Algebraics]] & /@ r),
  fail["NonAlgebraicCoefficient", "Every coefficient must be a recognized exact algebraic number; free parameters are not supported.",
   <|"Coefficients" -> r|>]];
 trim[r]
];

poly[v_List, x_Symbol] := Total[MapIndexed[#1 x^(First[#2] - 1) &, v]];

add[a_List, b_List] := trim[MapThread[rr[#1 + #2] &,
 {PadRight[a, Max[Length[a], Length[b]]],
  PadRight[b, Max[Length[a], Length[b]]]}]];

mul[a_List, b_List] := Module[{na, nb},
 If[a === {0} || b === {0}, Return[{0}]];
 na = Length[a] - 1; nb = Length[b] - 1;
 trim[Table[rr[Total[Table[a[[i + 1]] b[[k - i + 1]],
   {i, Max[0, k - nb], Min[k, na]}]]], {k, 0, na + nb}]]
];

(* Horner composition is separate from the candidate/recovery code. *)
compose[a_List, b_List] := Module[{r = {Last[a]}},
 Do[r = add[mul[r, b], {a[[j]]}], {j, Length[a] - 1, 1, -1}];
 r
];

composeChain[cs_List] := Fold[compose, First[cs], Rest[cs]];
properDegrees[n_] := If[!IntegerQ[n] || n < 4, {},
 Select[Divisors[n], 1 < # < n &]];

(* If n=m d and B(t)=p(1/t)t^n/lc(p), compute U=B^(1/m) mod t^d.
   From B U'=(1/m) U B':
   u_j = (1/j) Sum[((1+1/m)i-j) b_i u_(j-i), {i,1,j}].
   The constant coefficient of h is FIXED at zero, not taken from U. *)
candidate[c_List, d_Integer] := Module[{n, m, b, u},
 n = Length[c] - 1; m = Quotient[n, d];
 b = Table[rr[c[[n - i + 1]]/Last[c]], {i, 1, d - 1}];
 u = ConstantArray[0, d]; u[[1]] = 1;
 Do[u[[j + 1]] = rr[Total[Table[
    ((1 + 1/m) i - j) b[[i]] u[[j - i + 1]],
    {i, 1, j}]]/j], {j, 1, d - 1}];
 Prepend[Reverse[u], 0]
];

(* Build h^0,...,h^m once. Descending subtraction extracts the only
   possible g. A nonzero residual is a proof of nonexistence for this d. *)
attempt[c_List, d_Integer] := Module[{n, m, h, powers, r, g, a},
 n = Length[c] - 1; m = Quotient[n, d];
 h = candidate[c, d];
 powers = NestList[mul[#, h] &, {1}, m];
 r = c; g = ConstantArray[0, m + 1];
 Do[
  a = r[[k d + 1]]; g[[k + 1]] = a;
  If[a =!= 0,
   r = MapThread[rr[#1 - a #2] &,
     {r, PadRight[powers[[k + 1]], n + 1]}]],
  {k, m, 0, -1}];
 {trim[g], h, trim[r]}
];

(* Minimal successful right degree implies an indecomposable right factor. *)
firstSplit[c_List] := Module[{r},
 Do[r = attempt[c, d]; If[r[[3]] === {0}, Return[Take[r, 2]]],
  {d, properDegrees[deg[c]]}];
 None
];

oneChain[c_List] := Module[{s = firstSplit[c]},
 If[s === None, {c}, Append[oneChain[s[[1]]], s[[2]]]]
];

rightPairs[c_List] := Module[{ans = {}, r},
 Do[r = attempt[c, d];
  If[r[[3]] === {0}, AppendTo[ans, Take[r, 2]]],
  {d, properDegrees[deg[c]]}];
 ans
];

attemptRecord[c_List, d_Integer, x_Symbol] := Module[{a, w, r},
 a = attempt[c, d]; r = a[[3]];
 w = If[r === {0}, Missing["NotApplicable"],
  <|"Exponent" -> deg[r], "Coefficient" -> Last[r]|>];
 <|"InputDegree" -> deg[c], "RightDegree" -> d,
   "OuterDegree" -> Quotient[deg[c], d],
   "Decomposable" -> (r === {0}),
   "Outer" -> poly[a[[1]], x], "Inner" -> poly[a[[2]], x],
   "Residual" -> poly[r, x], "NonzeroWitness" -> w|>
];

AlgebraicDecompose[p_, x_Symbol] := Catch[Module[{c},
 c = coefficients[p, x]; poly[#, x] & /@ oneChain[c]
], adFailureTag];

AlgebraicRightDecompositions[p_, x_Symbol] := Catch[Module[{c},
 c = coefficients[p, x]; Map[poly[#, x] &, rightPairs[c], {2}]
], adFailureTag];

AlgebraicDecompositionAttempt[p_, x_Symbol, d_Integer] := Catch[Module[{c},
 c = coefficients[p, x];
 If[!MemberQ[properDegrees[deg[c]], d],
  fail["InvalidRightDegree", "The right degree must be a proper divisor of the reduced input degree, strictly between 1 and that degree.",
   <|"InputDegree" -> deg[c], "RightDegree" -> d|>]];
 attemptRecord[c, d, x]
], adFailureTag];

AlgebraicDecompositions[p_, x_Symbol, OptionsPattern[]] := Catch[
 Module[{c, limit = OptionValue["MaxDecompositions"], all, indec, result},
  If[!(limit === Infinity || (IntegerQ[limit] && limit > 0)),
   fail["InvalidLimit", "MaxDecompositions must be a positive integer or Infinity."]];
  c = coefficients[p, x];
  (* Memoization is local to this call. Returning at most limit+1 items
     suffices to detect truncation, including in recursive subproblems. *)
  indec[v_List] := indec[v] = (firstSplit[v] === None);
  all[v_List] := all[v] = Module[{pairs, resultHere = {}, tailChains},
   pairs = rightPairs[v];
   If[pairs === {}, Return[{{v}}]];
   Do[If[indec[pair[[2]]],
     tailChains = all[pair[[1]]];
     Do[
      AppendTo[resultHere, Append[ch, pair[[2]]]];
      If[Length[resultHere] > limit, Return[resultHere]],
      {ch, tailChains}]],
    {pair, pairs}];
   resultHere
  ];
  result = all[c];
  If[Length[result] > limit,
   fail["EnumerationLimit", "The requested enumeration limit was exceeded. PartialDecompositions is not an exhaustive list.",
    <|"Limit" -> limit, "Complete" -> False,
      "PartialDecompositions" -> Map[poly[#, x] &, Take[result, limit], {2}]|>]];
  Map[poly[#, x] &, result, {2}]
 ], adFailureTag];

ComposeAlgebraicPolynomials[ps_List, x_Symbol] := Catch[Module[{cs},
 If[ps === {}, fail["EmptyChain", "The composition list must be nonempty."]];
 cs = coefficients[#, x] & /@ ps;
 poly[composeChain[cs], x]
], adFailureTag];

VerifyAlgebraicDecomposition[p_, ps_List, x_Symbol] := Catch[
 Module[{c, cs, residual, identity, normalized, nonlinear, primeFactors,
   convention},
  If[ps === {}, fail["EmptyChain", "The composition list must be nonempty."]];
  c = coefficients[p, x]; cs = coefficients[#, x] & /@ ps;
  residual = add[c, -composeChain[cs]];
  identity = (residual === {0});
  normalized = And @@ ((Last[#] === 1 && First[#] === 0) & /@ Rest[cs]);
  nonlinear = And @@ (deg[#] >= 2 & /@ cs);
  primeFactors = nonlinear && And @@ (firstSplit[#] === None & /@ cs);
  convention = deg[c] < 2 && Length[cs] == 1 && identity;
  <|"IdentityVerified" -> identity, "Residual" -> poly[residual, x],
    "Normalized" -> normalized,
    "AllFactorsIndecomposable" -> primeFactors,
    "ValidCompleteDecomposition" -> (identity && primeFactors),
    "ValidConstantOrLinearConvention" -> convention,
    "Degrees" -> (deg /@ cs)|>
 ], adFailureTag];

(* Fallbacks make invalid calling forms explicit rather than unevaluated. *)
AlgebraicDecompose[___] := Failure["Arguments", <|"MessageTemplate" -> "Use AlgebraicDecompose[p,x] with an unassigned symbol x."|>];
AlgebraicRightDecompositions[___] := Failure["Arguments", <|"MessageTemplate" -> "Use AlgebraicRightDecompositions[p,x]."|>];
AlgebraicDecompositionAttempt[___] := Failure["Arguments", <|"MessageTemplate" -> "Use AlgebraicDecompositionAttempt[p,x,d] with an integer d."|>];
AlgebraicDecompositions[___] := Failure["Arguments", <|"MessageTemplate" -> "Use AlgebraicDecompositions[p,x,options]."|>];
ComposeAlgebraicPolynomials[___] := Failure["Arguments", <|"MessageTemplate" -> "Use ComposeAlgebraicPolynomials[nonemptyList,x]."|>];
VerifyAlgebraicDecomposition[___] := Failure["Arguments", <|"MessageTemplate" -> "Use VerifyAlgebraicDecomposition[p,nonemptyList,x]."|>];

End[];
EndPackage[];
