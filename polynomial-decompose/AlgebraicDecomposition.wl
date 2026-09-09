(* ::Package:: *)
(* AlgebraicDecomposition -- exact characteristic-zero functional
   decomposition over algebraic numbers. Unified implementation based on
   reports/report-03, with bounded enumeration and short-circuit decisions.
   Copyright (c) 2026 OpenAI. MIT; see reports/report-03/LICENSE.
   No Factor, Decompose, Solve, approximate zero test, or radical denesting
   is used by the decomposition algorithm. SPDX-License-Identifier: MIT *)

BeginPackage["AlgebraicDecomposition`"];

AlgebraicDecompose::usage =
  "AlgebraicDecompose[p,x] returns one complete composition chain, outermost first. It chooses the smallest successful right degree at each step. All components except the first are monic with zero constant term. Exact algebraic coefficients are required.";
AlgebraicDecompositions::usage =
  "AlgebraicDecompositions[p,x] returns all complete normalized composition chains, modulo affine changes at internal interfaces. With \"MaxDecompositions\" -> M, a genuinely truncated enumeration returns Failure[\"EnumerationLimit\", ...] with partial chains and \"Complete\" -> False; a list is always exhaustive.";
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
  "VerifyAlgebraicDecomposition[p,parts,x] checks the exact polynomial identity p=ComposeDecomposition[parts,x]. Options \"RequireComplete\" and \"RequireNormalized\" additionally check those properties; both default to False.";

Options[AlgebraicDecompositions] = {"MaxDecompositions" -> Infinity};
Options[VerifyAlgebraicDecomposition] = {"RequireComplete" -> False, "RequireNormalized" -> False};

Begin["`Private`"];

$failureTag = Unique["AlgebraicDecompositionFailure"];
fail[tag_String, message_String, extra_: <||>] :=
  Throw[Failure[tag, Join[<|"MessageTemplate" -> message|>, extra]], $failureTag];
invalid[] := Failure["InvalidArguments", <|"MessageTemplate" ->
  "Use a documented argument sequence and an unassigned polynomial variable."|>];

(* This is the only algebraic-number normalization boundary. In particular,
   RootReduce is applied to scalars, never to a polynomial containing x. *)
red[z_] := Module[{r},
  If[MatchQ[z, _Integer | _Rational], Return[z]];
  If[!FreeQ[z, _Real], fail["InexactCoefficient", "Approximate coefficients are not accepted."]];
  r = Quiet[Check[RootReduce[z], $Failed]];
  If[r === $Failed || !FreeQ[r, _RootReduce],
    fail["AlgebraicArithmetic", "Exact algebraic-number reduction failed."]];
  r
];

(* Ascending dense coefficient vectors. Zero is always {0}. *)
trim[v_List] := Module[{k = Length[v]},
  If[k == 0, Return[{0}]];
  While[k > 1 && v[[k]] === 0, k--];
  Take[v, k]
];
zeroQ[v_List] := v === {0};
vectorDegree[v_List] := If[zeroQ[v], -Infinity, Length[v] - 1];

prepare[p_, x_Symbol] := Module[{q, c},
  If[NumericQ[x], fail["InvalidVariable", "The polynomial variable must be an unassigned nonnumeric symbol."]];
  q = Quiet[Check[Expand[p], $Failed]];
  If[q === $Failed || !TrueQ[PolynomialQ[q, x]],
    fail["NotPolynomial", "The input must be a univariate polynomial."]];
  c = CoefficientList[q, x];
  If[c === {}, c = {0}];
  If[!FreeQ[c, _Real],
    fail["InexactCoefficient", "Approximate coefficients are not accepted."]];
  If[!(And @@ (TrueQ[NumericQ[#]] & /@ c)),
    fail["NonAlgebraicCoefficient", "Every coefficient must be an explicit exact algebraic number; symbolic parameters are not accepted."]];
  c = red /@ c;
  If[!AllTrue[c, TrueQ[NumericQ[#]] && FreeQ[#, _Real] && TrueQ[Element[#, Algebraics]] &],
    fail["NonAlgebraicCoefficient", "Every coefficient must be a recognized exact algebraic number."]];
  trim[c]
];

checkOptions[s_Symbol, opts_List] := If[
  !AllTrue[First /@ Flatten[opts], MemberQ[First /@ Options[s], #] &],
  fail["UnknownOption", "An unknown option was supplied."]];

expression[v_List, x_] := Expand[Fold[#1 x + #2 &, 0, Reverse[v]]];
properDegrees[n_Integer] := If[n < 4, {}, Select[Divisors[n], 1 < # < n &]];

add[a_List, b_List] := trim[red /@
  (PadRight[a, Max[Length[a], Length[b]]] +
   PadRight[b, Max[Length[a], Length[b]]])];
subtract[a_List, b_List] := add[a, -b];
multiply[a_List, b_List, limit_: Infinity] := Module[{size},
  If[zeroQ[a] || zeroQ[b], Return[{0}]];
  size = Min[Length[a] + Length[b] - 1, limit];
  trim[red /@ Take[ListConvolve[
    Take[a, UpTo[size]], Take[b, UpTo[size]], {1, -1}, 0], size]]
];
digitCompose[digits_List, h_List] :=
  Fold[add[multiply[#1, h], #2] &, {0}, Reverse[digits]];
compose[a_List, b_List] := digitCompose[List /@ a, b];
composeChain[parts_List] := Fold[compose[#2, #1] &, {0, 1}, Reverse[parts]];

(* Only coefficients below t^limit are needed for certificate congruences. *)
truncatedPower[a_List, exponent_Integer, limit_Integer] :=
  Module[{result = {1}, base = Take[a, UpTo[limit]], k = exponent},
    While[k > 0,
      If[OddQ[k], result = multiply[result, base, limit]];
      k = Quotient[k, 2];
      If[k > 0, base = multiply[base, base, limit]]];
    PadRight[result, limit]
  ];

(* Coefficients u_k of (1+s_1 t+...)^(1/m), truncated before t^d.
   m S U' = U S' gives the O(d^2) recurrence used here. *)
rightCandidate[c_List, d_Integer] := Module[{n, m, s, u, k, i},
  n = Length[c] - 1; m = Quotient[n, d];
  s = Table[red[c[[n - k + 1]]/Last[c]], {k, 0, d - 1}];
  If[AllTrue[Rest[s], # === 0 &], Return[Append[ConstantArray[0, d], 1]]];
  u = ConstantArray[0, d]; u[[1]] = 1;
  Do[u[[k + 1]] = red[Total[Table[
      (((1 + 1/m) i - k) s[[i + 1]] u[[k - i + 1]]),
      {i, 1, k}]]/k], {k, 1, d - 1}];
  Prepend[Reverse[u], 0]
];

(* Exact monic long division. The top coefficient is canceled by assignment;
   lower positions are reduced immediately, keeping zero recognition exact. *)
monicDivide[a_List, h_List] := Module[{r = a, q, d, n, k, j, t, nonzero},
  d = Length[h] - 1; n = Length[a] - 1;
  If[n < d, Return[{{0}, a}]];
  nonzero = Select[Range[0, d - 1], h[[# + 1]] =!= 0 &];
  q = ConstantArray[0, n - d + 1];
  Do[t = r[[k + d + 1]]; q[[k + 1]] = t;
    If[t =!= 0,
      Do[r[[k + j + 1]] = red[r[[k + j + 1]] - t h[[j + 1]]],
        {j, nonzero}]];
    r[[k + d + 1]] = 0,
    {k, n - d, 0, -1}];
  {trim[q], trim[Take[r, d]]}
];

baseDigits[c_List, h_List, full_: True] :=
  Module[{q = c, digit, out, d = Length[h] - 1, monomial, j = 1, tag},
  monomial = AllTrue[Most[h], # === 0 &];
  out = Reap[While[If[monomial, j <= Length[c], !zeroQ[q]],
    If[monomial,
      digit = trim[Take[c, {j, Min[j + d - 1, Length[c]]}]]; j += d,
      {q, digit} = monicDivide[q, h]];
    Sow[digit, tag];
    (* Once a digit is nonconstant no outer polynomial can exist. Ordinary
       searches stop here; exported certificates retain the entire expansion. *)
    If[!full && Length[digit] > 1, Break[]]], tag][[2]];
  If[out === {}, {{0}}, First[out]]
];

(* Obstruction indices are mathematical, zero-based digit/power indices. *)
obstruction[digits_List] := Module[{position},
  position = FirstPosition[Rest /@ digits, Except[0], None, {2}, Heads -> False];
  If[position === None, None,
    With[{j = position[[1]], k = position[[2]]},
      <|"DigitIndex" -> j - 1, "Power" -> k, "Coefficient" -> digits[[j, k + 1]]|>]]
];

degreeTrial[c_List, d_Integer, full_: False] := Module[{h = rightCandidate[c, d]},
  {h, baseDigits[c, h, full]}
];
rightPair[c_List, d_Integer] := Module[{h, digits},
  {h, digits} = degreeTrial[c, d];
  If[AllTrue[digits, Length[#] === 1 &], {First /@ digits, h}, None]
];
publicTest[c_List, d_Integer, x_] := Module[{h, digits, outer, obs},
  {h, digits} = degreeTrial[c, d, True]; outer = First /@ digits;
  obs = obstruction[digits];
  <|"Type" -> "DegreeTest", "RightDegree" -> d,
    "OuterDegree" -> Quotient[Length[c] - 1, d],
    "Inner" -> expression[h, x], "OuterCandidate" -> expression[outer, x],
    "Digits" -> (expression[#, x] & /@ digits),
    "Decomposable" -> (obs === None), "Obstruction" -> obs,
    "Residual" -> If[obs === None, 0, expression[subtract[c, compose[outer, h]], x]]|>
];

checkDegree[c_List, d_] := If[!IntegerQ[d] || d < 2 ||
    d >= Length[c] - 1 || Mod[Length[c] - 1, d] =!= 0,
  fail["InvalidRightDegree", "The right degree must be a proper divisor d of the polynomial degree with 1<d<n."]];

firstPair[c_List] := Module[{pair = None, d},
  Do[pair = rightPair[c, d]; If[pair =!= None, Break[]],
    {d, properDegrees[Length[c] - 1]}];
  pair
];
allPairs[c_List] := DeleteCases[rightPair[c, #] & /@ properDegrees[Length[c] - 1], None];

oneChain[c_List] := Module[{v = c, out = {}, pair},
  pair = firstPair[v];
  While[pair =!= None,
    (* Minimal successful right degree implies an indecomposable inner factor. *)
    PrependTo[out, pair[[2]]]; v = pair[[1]];
    pair = firstPair[v]];
  Prepend[out, v]
];

allChains[c_List, limit_] := Module[{pairs, atomic, walk, out = {}, capTag = Unique["EnumerationCap"]},
  pairs[v_List] := pairs[v] = allPairs[v];
  atomic[v_List] := atomic[v] = (firstPair[v] === None);
  walk[v_List, suffix_List] := Module[{ps = pairs[v], chain},
    If[ps === {},
      chain = Prepend[suffix, v];
      If[!zeroQ[subtract[c, composeChain[chain]]],
        fail["InternalVerification", "An enumerated chain failed exact recomposition."]];
      AppendTo[out, chain];
      If[limit =!= Infinity && Length[out] > limit, Throw[Null, capTag]],
      Do[If[atomic[pr[[2]]], walk[pr[[1]], Prepend[suffix, pr[[2]]]]], {pr, ps}]]];
  Catch[walk[c, {}], capTag];
  out
];

AlgebraicDecompose[p_, x_Symbol] := Catch[Module[{c = prepare[p, x], chain},
  chain = oneChain[c];
  If[!zeroQ[subtract[c, composeChain[chain]]],
    fail["InternalVerification", "The complete chain failed exact recomposition."]];
  expression[#, x] & /@ chain], $failureTag];
AlgebraicDecompositions[p_, x_Symbol, opts : OptionsPattern[]] := Catch[
  Module[{c, limit, chains},
    checkOptions[AlgebraicDecompositions, {opts}];
    limit = OptionValue["MaxDecompositions"];
    If[!(limit === Infinity || (IntegerQ[limit] && limit > 0)),
      fail["InvalidLimit", "MaxDecompositions must be a positive integer or Infinity."]];
    c = prepare[p, x]; chains = allChains[c, limit];
    If[Length[chains] > limit,
      fail["EnumerationLimit", "More chains exist than the requested cap; partial output is not exhaustive.",
        <|"Complete" -> False, "Limit" -> limit,
          "PartialDecompositions" -> Map[expression[#, x] &, Take[chains, limit], {2}]|>]];
    Map[expression[#, x] &, chains, {2}]], $failureTag];
AlgebraicDecompositionPairs[p_, x_Symbol] := Catch[
  Map[expression[#, x] &, allPairs[prepare[p, x]], {2}], $failureTag];
AlgebraicRightDecompose[p_, x_Symbol, d_] := Catch[Module[{c, pair},
  c = prepare[p, x]; checkDegree[c, d]; pair = rightPair[c, d];
  If[pair === None, Missing["NotDecomposable", d], expression[#, x] & /@ pair]], $failureTag];

AlgebraicDecompositionData[p_, x_Symbol, d_] := Catch[Module[{c},
  c = prepare[p, x]; checkDegree[c, d]; publicTest[c, d, x]],
  $failureTag];
AlgebraicDecompositionData[p_, x_Symbol] := Catch[Module[{c, ds, ts, good},
  c = prepare[p, x]; ds = properDegrees[Length[c] - 1];
  ts = publicTest[c, #, x] & /@ ds;
  good = (#["RightDegree"] & /@ Select[ts, TrueQ[#["Decomposable"]] &]);
  <|"Type" -> "AllDegreeTests", "InputDegree" -> vectorDegree[c],
    "TestedRightDegrees" -> ds, "AcceptedRightDegrees" -> good,
    "Indecomposable" -> If[Length[c] < 3,
      Missing["NotApplicable", "DegreeBelowTwo"], good === {}],
    "Tests" -> ts|>], $failureTag];

ComposeDecomposition[parts_List, x_Symbol] := Catch[Module[{vs},
  If[NumericQ[x], fail["InvalidVariable", "The polynomial variable must be an unassigned nonnumeric symbol."]];
  vs = prepare[#, x] & /@ parts;
  expression[composeChain[vs], x]], $failureTag];
VerifyAlgebraicDecomposition[p_, parts_List, x_Symbol, opts : OptionsPattern[]] := Catch[
  Module[{c, vs, v, complete, normalized},
    checkOptions[VerifyAlgebraicDecomposition, {opts}];
    complete = OptionValue["RequireComplete"]; normalized = OptionValue["RequireNormalized"];
    If[!MemberQ[{True, False}, complete] || !MemberQ[{True, False}, normalized],
      fail["InvalidOption", "Verification options must be True or False."]];
    c = prepare[p, x]; vs = prepare[#, x] & /@ parts;
    v = composeChain[vs];
    If[!zeroQ[subtract[c, v]], Return[False]];
    If[normalized && Length[vs] > 1 && !AllTrue[Rest[vs], Length[#] >= 2 && First[#] === 0 && Last[#] === 1 &], Return[False]];
    If[complete,
      If[Length[c] <= 2, Return[Length[vs] === 1]];
      If[!AllTrue[vs, Length[#] >= 3 && firstPair[#] === None &], Return[False]]];
    True], $failureTag];

(* A deliberately different checker: no rightCandidate, monicDivide,
   baseDigits, firstPair, or allPairs call occurs below. *)
verifyTest[c_List, t_, x_] := Module[
  {keys, d, n, m, h, f, digits, obs, top, res},
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
  top = truncatedPower[Reverse[h], m, d];
  If[!AllTrue[red /@ (Take[Reverse[c], d] - Last[c] top), # === 0 &], Return[False]];
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
  (* Reconstruction with constant digits already proves c = f(h). *)
  If[obs === None, zeroQ[res], zeroQ[subtract[res, subtract[c, compose[f, h]]]]]
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
