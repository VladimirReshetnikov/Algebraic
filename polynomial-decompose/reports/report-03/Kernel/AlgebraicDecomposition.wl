(* ::Package:: *)
(* AlgebraicDecomposition 1.0.0 -- exact characteristic-zero functional
   decomposition over algebraic numbers. See article/article.pdf.
   No Factor, Decompose, Solve, approximate zero test, or radical denesting
   is used by the decomposition algorithm. SPDX-License-Identifier: MIT *)

BeginPackage["AlgebraicDecomposition`"];

AlgebraicDecompose::usage =
  "AlgebraicDecompose[p,x] returns one complete composition chain, outermost first. It chooses the smallest successful right degree at each step. All components except the first are monic with zero constant term. Exact algebraic coefficients are required.";
AlgebraicDecompositions::usage =
  "AlgebraicDecompositions[p,x] returns all complete normalized composition chains, modulo affine changes at internal interfaces. Enumeration may have large output.";
AlgebraicDecompositionPairs::usage =
  "AlgebraicDecompositionPairs[p,x] returns all normalized nontrivial pairs {f,g} with p=f(g(x)), ordered by increasing degree of g.";
AlgebraicRightDecompose::usage =
  "AlgebraicRightDecompose[p,x,d] returns the unique pair {f,g} with degree(g)=d, g monic and g(0)=0, or Missing[\"NotDecomposable\",d]. An invalid degree or input returns Failure.";
AlgebraicDecompositionData::usage =
  "AlgebraicDecompositionData[p,x,d] gives an exact fixed-degree test, including the forced inner candidate, its base-g digits and an obstruction. AlgebraicDecompositionData[p,x] gives tests for every proper divisor of degree(p).";
VerifyAlgebraicDecompositionData::usage =
  "VerifyAlgebraicDecompositionData[p,data,x] verifies fixed-degree or exhaustive data by leading-coefficient congruence, digit reconstruction, and exact coefficient arithmetic; it does not rerun the candidate recurrence or the division search. Returns False for malformed data and Failure for invalid polynomial input.";
ComposeDecomposition::usage =
  "ComposeDecomposition[parts,x] composes an outermost-first list of exact algebraic polynomials. The empty list represents x.";
VerifyAlgebraicDecomposition::usage =
  "VerifyAlgebraicDecomposition[p,parts,x] checks the exact polynomial identity p=ComposeDecomposition[parts,x]. It checks identity, not completeness or normalization.";

Begin["`Private`"];

$failureTag = Unique["AlgebraicDecompositionFailure"];
fail[tag_String, message_String] :=
  Throw[Failure[tag, <|"MessageTemplate" -> message|>], $failureTag];
invalid[] := Failure["InvalidArguments", <|"MessageTemplate" ->
  "Use a documented argument sequence and an unassigned polynomial variable."|>];

(* This is the only algebraic-number normalization boundary. In particular,
   RootReduce is applied to scalars, never to a polynomial containing x. *)
red[z_] := Module[{r},
  If[MatchQ[z, _Integer | _Rational], Return[z]];
  r = Quiet[Check[RootReduce[z], $Failed]];
  If[r === $Failed || !FreeQ[r, _Real] ||
     !TrueQ[NumericQ[r]] || !TrueQ[Element[r, Algebraics]],
    fail["AlgebraicArithmetic", "Exact algebraic-number reduction failed."]];
  r
];

(* Ascending dense coefficient vectors. Zero is always {0}. *)
trim[v_List] := Module[{w = v},
  If[w === {}, Return[{0}]];
  While[Length[w] > 1 && Last[w] === 0, w = Most[w]];
  w
];
zeroQ[v_List] := v === {0};
vectorDegree[v_List] := If[zeroQ[v], -Infinity, Length[v] - 1];

prepare[p_, x_Symbol] := Module[{q, c},
  q = Quiet[Check[Expand[p], $Failed]];
  If[q === $Failed || !TrueQ[PolynomialQ[q, x]],
    fail["NotPolynomial", "The input must be a univariate polynomial."]];
  c = CoefficientList[q, x];
  If[c === {}, c = {0}];
  If[!FreeQ[c, _Real],
    fail["InexactCoefficient", "Approximate coefficients are not accepted."]];
  If[!(And @@ (TrueQ[NumericQ[#]] & /@ c)),
    fail["NonAlgebraicCoefficient", "Every coefficient must be an explicit exact algebraic number; symbolic parameters are not accepted."]];
  trim[red /@ c]
];

expression[v_List, x_] := Expand[Fold[#1 x + #2 &, 0, Reverse[v]]];
properDegrees[n_Integer] := If[n < 4, {}, Select[Divisors[n], 1 < # < n &]];

add[a_List, b_List] := trim[red /@
  (PadRight[a, Max[Length[a], Length[b]]] +
   PadRight[b, Max[Length[a], Length[b]]])];
subtract[a_List, b_List] := add[a, -b];
multiply[a_List, b_List] := Module[{r, i, j},
  If[zeroQ[a] || zeroQ[b], Return[{0}]];
  r = ConstantArray[0, Length[a] + Length[b] - 1];
  Do[If[a[[i]] =!= 0,
    Do[If[b[[j]] =!= 0,
      r[[i + j - 1]] = r[[i + j - 1]] + a[[i]] b[[j]]],
      {j, Length[b]}]], {i, Length[a]}];
  trim[red /@ r]
];
compose[a_List, b_List] := Fold[add[multiply[#1, b], {#2}] &,
  {0}, Reverse[a]];
digitCompose[digits_List, h_List] :=
  Fold[add[multiply[#1, h], #2] &, {0}, Reverse[digits]];

(* Coefficients u_k of (1+s_1 t+...)^(1/m), truncated before t^d.
   m S U' = U S' gives the O(d^2) recurrence used here. *)
rightCandidate[c_List, d_Integer] := Module[{n, m, s, u, k, i},
  n = Length[c] - 1; m = Quotient[n, d];
  s = Table[red[c[[n - k + 1]]/Last[c]], {k, 0, d - 1}];
  u = ConstantArray[0, d]; u[[1]] = 1;
  Do[u[[k + 1]] = red[Total[Table[
      (((1 + 1/m) i - k) s[[i + 1]] u[[k - i + 1]]),
      {i, 1, k}]]/k], {k, 1, d - 1}];
  Prepend[Reverse[u], 0]
];

(* Exact monic long division. The top coefficient is canceled by assignment;
   lower positions are reduced immediately, keeping zero recognition exact. *)
monicDivide[a_List, h_List] := Module[{r = a, q, d, n, k, j, t},
  d = Length[h] - 1; n = Length[a] - 1;
  If[n < d, Return[{{0}, a}]];
  q = ConstantArray[0, n - d + 1];
  Do[t = r[[k + d + 1]]; q[[k + 1]] = t;
    If[t =!= 0,
      Do[r[[k + j + 1]] = red[r[[k + j + 1]] - t h[[j + 1]]],
        {j, 0, d - 1}]];
    r[[k + d + 1]] = 0,
    {k, n - d, 0, -1}];
  {trim[q], trim[Take[r, d]]}
];

baseDigits[c_List, h_List] := Module[{q = c, qr, out = {}},
  While[!zeroQ[q],
    qr = monicDivide[q, h];
    AppendTo[out, qr[[2]]]; q = qr[[1]]];
  If[out === {}, {{0}}, out]
];

(* Obstruction indices are mathematical, zero-based digit/power indices. *)
obstruction[digits_List] := Module[{j, k, tag},
  (* Tagged Throw leaves both loops; Return would leave only the inner Do. *)
  Catch[
    Do[Do[If[digits[[j, k]] =!= 0,
        Throw[<|"DigitIndex" -> j - 1, "Power" -> k - 1,
          "Coefficient" -> digits[[j, k]]|>, tag]],
        {k, 2, Length[digits[[j]]]}], {j, Length[digits]}];
    None, tag]
];

(* Internal records keep vectors, not expressions in a public variable. *)
testDegree[c_List, d_Integer] := Module[{h, digits, obs},
  h = rightCandidate[c, d]; digits = baseDigits[c, h];
  obs = obstruction[digits];
  <|"RightDegree" -> d, "OuterDegree" -> Quotient[Length[c] - 1, d],
    "InnerVector" -> h, "OuterVector" -> (First /@ digits),
    "DigitVectors" -> digits, "Decomposable" -> (obs === None),
    "Obstruction" -> obs|>
];

publicTest[c_List, t_Association, x_] := <|
  "Type" -> "DegreeTest", "RightDegree" -> t["RightDegree"],
  "OuterDegree" -> t["OuterDegree"],
  "Inner" -> expression[t["InnerVector"], x],
  "OuterCandidate" -> expression[t["OuterVector"], x],
  "Digits" -> (expression[#, x] & /@ t["DigitVectors"]),
  "Decomposable" -> t["Decomposable"], "Obstruction" -> t["Obstruction"],
  "Residual" -> expression[subtract[c,
    compose[t["OuterVector"], t["InnerVector"]]], x]|>;

checkDegree[c_List, d_] := If[!IntegerQ[d] || d < 2 ||
    d >= Length[c] - 1 || Mod[Length[c] - 1, d] =!= 0,
  fail["InvalidRightDegree", "The right degree must be a proper divisor d of the polynomial degree with 1<d<n."]];

firstPair[c_List] := Module[{t, d, result = None},
  Do[t = testDegree[c, d];
    If[TrueQ[t["Decomposable"]],
      result = {t["OuterVector"], t["InnerVector"]}; Break[]],
    {d, properDegrees[Length[c] - 1]}];
  result
];
allPairs[c_List] := Module[{out = {}, t, d},
  Do[t = testDegree[c, d];
    If[TrueQ[t["Decomposable"]],
      AppendTo[out, {t["OuterVector"], t["InnerVector"]}]],
    {d, properDegrees[Length[c] - 1]}];
  out
];

oneChain[c_List] := Module[{v = c, out = {}, pair},
  pair = firstPair[v];
  While[pair =!= None,
    (* Minimal successful right degree implies an indecomposable inner factor. *)
    PrependTo[out, pair[[2]]]; v = pair[[1]];
    pair = firstPair[v]];
  Prepend[out, v]
];

allChains[c_List] := Module[{pairs, walk},
  pairs[v_List] := pairs[v] = allPairs[v];
  walk[v_List] := walk[v] = Module[{ps, out = {}, pr, tails},
    ps = pairs[v];
    If[ps === {}, {{v}},
      Do[If[pairs[pr[[2]]] === {},
        tails = walk[pr[[1]]];
        out = Join[out, (Append[#, pr[[2]]] & /@ tails)]], {pr, ps}];
      out]];
  walk[c]
];

AlgebraicDecompose[p_, x_Symbol] := Catch[
  expression[#, x] & /@ oneChain[prepare[p, x]], $failureTag];
AlgebraicDecompositions[p_, x_Symbol] := Catch[
  Map[expression[#, x] &, allChains[prepare[p, x]], {2}], $failureTag];
AlgebraicDecompositionPairs[p_, x_Symbol] := Catch[
  Map[expression[#, x] &, allPairs[prepare[p, x]], {2}], $failureTag];
AlgebraicRightDecompose[p_, x_Symbol, d_] := Catch[Module[{c, t},
  c = prepare[p, x]; checkDegree[c, d]; t = testDegree[c, d];
  If[TrueQ[t["Decomposable"]],
    {expression[t["OuterVector"], x], expression[t["InnerVector"], x]},
    Missing["NotDecomposable", d]]], $failureTag];

AlgebraicDecompositionData[p_, x_Symbol, d_] := Catch[Module[{c},
  c = prepare[p, x]; checkDegree[c, d]; publicTest[c, testDegree[c, d], x]],
  $failureTag];
AlgebraicDecompositionData[p_, x_Symbol] := Catch[Module[{c, ds, ts, good},
  c = prepare[p, x]; ds = properDegrees[Length[c] - 1];
  ts = publicTest[c, testDegree[c, #], x] & /@ ds;
  good = (#["RightDegree"] & /@ Select[ts, TrueQ[#["Decomposable"]] &]);
  <|"Type" -> "AllDegreeTests", "InputDegree" -> vectorDegree[c],
    "TestedRightDegrees" -> ds, "AcceptedRightDegrees" -> good,
    "Indecomposable" -> If[Length[c] < 3,
      Missing["NotApplicable", "DegreeBelowTwo"], good === {}],
    "Tests" -> ts|>], $failureTag];

ComposeDecomposition[parts_List, x_Symbol] := Catch[Module[{vs},
  vs = prepare[#, x] & /@ parts;
  expression[Fold[compose[#2, #1] &, {0, 1}, Reverse[vs]], x]], $failureTag];
VerifyAlgebraicDecomposition[p_, parts_List, x_Symbol] := Catch[
  Module[{c, vs, v}, c = prepare[p, x]; vs = prepare[#, x] & /@ parts;
    v = Fold[compose[#2, #1] &, {0, 1}, Reverse[vs]];
    zeroQ[subtract[c, v]]], $failureTag];

(* A deliberately different checker: no rightCandidate, monicDivide,
   baseDigits, firstPair, or allPairs call occurs below. *)
verifyTest[c_List, t_, x_] := Module[
  {keys, d, n, m, h, f, digits, obs, hm, k, res},
  If[!AssociationQ[t], Return[False]];
  keys = {"Type", "RightDegree", "OuterDegree", "Inner", "OuterCandidate",
    "Digits", "Decomposable", "Obstruction", "Residual"};
  If[!(And @@ (KeyExistsQ[t, #] & /@ keys)), Return[False]];
  If[t["Type"] =!= "DegreeTest", Return[False]];
  n = Length[c] - 1; d = t["RightDegree"];
  If[!MemberQ[properDegrees[n], d], Return[False]];
  m = Quotient[n, d]; If[t["OuterDegree"] =!= m, Return[False]];
  If[!ListQ[t["Digits"]] || Length[t["Digits"]] =!= m + 1,
    Return[False]];
  h = prepare[t["Inner"], x]; f = prepare[t["OuterCandidate"], x];
  digits = prepare[#, x] & /@ t["Digits"];
  If[Length[h] =!= d + 1 || First[h] =!= 0 || Last[h] =!= 1,
    Return[False]];
  If[!(And @@ (Length[#] <= d & /@ digits)), Return[False]];
  hm = Nest[multiply[#, h] &, {1}, m];
  If[!(And @@ Table[
      red[c[[n - k + 1]]/Last[c] - hm[[n - k + 1]]] === 0,
      {k, 1, d - 1}]), Return[False]];
  If[!zeroQ[subtract[c, digitCompose[digits, h]]], Return[False]];
  If[!zeroQ[subtract[f, trim[First /@ digits]]], Return[False]];
  obs = obstruction[digits];
  If[t["Decomposable"] =!= (obs === None), Return[False]];
  If[obs === None,
    If[t["Obstruction"] =!= None, Return[False]],
    If[!AssociationQ[t["Obstruction"]], Return[False]];
    If[Lookup[t["Obstruction"], "DigitIndex", -1] =!= obs["DigitIndex"] ||
       Lookup[t["Obstruction"], "Power", -1] =!= obs["Power"], Return[False]];
    If[red[Lookup[t["Obstruction"], "Coefficient", Indeterminate] -
        obs["Coefficient"]] =!= 0, Return[False]]];
  res = prepare[t["Residual"], x];
  zeroQ[subtract[res, subtract[c, compose[f, h]]]]
];

verifyData[c_List, data_, x_] := Module[{ds, ts, good, status, keys},
  If[!AssociationQ[data] || !KeyExistsQ[data, "Type"], Return[False]];
  If[data["Type"] === "DegreeTest", Return[verifyTest[c, data, x]]];
  If[data["Type"] =!= "AllDegreeTests", Return[False]];
  keys = {"InputDegree", "TestedRightDegrees", "AcceptedRightDegrees",
    "Indecomposable", "Tests"};
  If[!(And @@ (KeyExistsQ[data, #] & /@ keys)), Return[False]];
  ds = properDegrees[Length[c] - 1]; ts = data["Tests"];
  If[data["InputDegree"] =!= vectorDegree[c] ||
      data["TestedRightDegrees"] =!= ds || !ListQ[ts] ||
      Length[ts] =!= Length[ds], Return[False]];
  If[!(And @@ (verifyTest[c, #, x] & /@ ts)), Return[False]];
  If[(#["RightDegree"] & /@ ts) =!= ds, Return[False]];
  good = (#["RightDegree"] & /@ Select[ts, TrueQ[#["Decomposable"]] &]);
  status = If[Length[c] < 3, Missing["NotApplicable", "DegreeBelowTwo"],
    good === {}];
  data["AcceptedRightDegrees"] === good && data["Indecomposable"] === status
];

VerifyAlgebraicDecompositionData[p_, data_, x_Symbol] := Catch[
  Module[{c, result}, c = prepare[p, x];
    result = Quiet[Check[Catch[verifyData[c, data, x], $failureTag], False]];
    TrueQ[result]], $failureTag];

AlgebraicDecompose[___] := invalid[];
AlgebraicDecompositions[___] := invalid[];
AlgebraicDecompositionPairs[___] := invalid[];
AlgebraicRightDecompose[___] := invalid[];
AlgebraicDecompositionData[___] := invalid[];
VerifyAlgebraicDecompositionData[___] := invalid[];
ComposeDecomposition[___] := invalid[];
VerifyAlgebraicDecomposition[___] := invalid[];

End[];
EndPackage[];
