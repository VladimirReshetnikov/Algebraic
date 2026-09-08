(* ::Package:: *)
(* AlgebraicDecomposition 1.0.0
   Exact functional decomposition in characteristic zero.
   Original implementation: MIT-0. See LICENSE.txt and article/article.pdf.
   No Factor, Solve, Decompose, PossibleZeroQ, or numerical arithmetic is used.
*)

BeginPackage["AlgebraicDecomposition`"];

AlgebraicDecompose::usage =
  "AlgebraicDecompose[p, x] returns a complete composition chain, outermost first, for a univariate polynomial with exact algebraic coefficients. Every component except the first is monic and zero at zero. The option \"DegreeOrder\" is \"Ascending\" (default) or \"Descending\". Constants and linear polynomials return {p}.";
AlgebraicDecomposeAtDegree::usage =
  "AlgebraicDecomposeAtDegree[p, x, d] returns {f, h} with p == f(h), h monic, h(0) == 0, and Degree[h] == d. A valid but unsuccessful degree returns Missing[\"NotDecomposableAtDegree\", d]. An invalid degree or input returns Failure.";
AlgebraicRightComponents::usage =
  "AlgebraicRightComponents[p, x] returns all normalized nontrivial two-component decompositions {f, h}, ordered by increasing degree of h. It returns {} when no such decomposition exists.";
AlgebraicDecomposeAll::usage =
  "AlgebraicDecomposeAll[p, x] returns an Association containing \"Decompositions\", \"EnumerationComplete\", and \"ReturnedCount\". Chains are complete and normalized, with affine-equivalent chains represented once. \"MaxDecompositions\" defaults to Infinity; a finite cap uses one additional distinct chain to detect truncation.";
AlgebraicDecompositionReport::usage =
  "AlgebraicDecompositionReport[p, x] tests every proper degree divisor and returns the unique normalized candidate and either its outer component or an exact nonconstant h-adic remainder obstruction. This is a mathematical decision record, not a proof-assistant certificate.";
AlgebraicCompose::usage =
  "AlgebraicCompose[{f1, f2, ...}, x] computes f1(f2(...)) using exact coefficient-vector arithmetic. AlgebraicCompose[{}, x] is x.";
AlgebraicVerifyDecomposition::usage =
  "AlgebraicVerifyDecomposition[p, chain, x] checks exact equality to the composition. Options \"RequireComplete\" and \"RequireNormalized\" default to False. Invalid coefficient domains return Failure rather than False.";

Options[AlgebraicDecompose] = {"DegreeOrder" -> "Ascending"};
Options[AlgebraicDecomposeAll] = {"MaxDecompositions" -> Infinity};
Options[AlgebraicVerifyDecomposition] = {
  "RequireComplete" -> False, "RequireNormalized" -> False};

Begin["`Private`"];

$failureTag = Unique["AlgebraicDecompositionFailure$"];

fail[tag_String, text_String, data_: <||>] :=
  Throw[Failure[tag, Join[<|"MessageTemplate" -> text|>, data]], $failureTag];

(* Reduction is coefficientwise, never applied to a polynomial in x as a
   single algebraic number. All input values are exact and domain-checked.
   The rational fast path avoids needless RootReduce calls. *)
red[z_] := Module[{r},
  If[MatchQ[z, _Integer | _Rational], Return[z]];
  r = Quiet[Check[RootReduce[z], $Failed]];
  If[r === $Failed || Head[r] === RootReduce,
    fail["AlgebraicArithmetic", "Exact algebraic reduction did not complete.",
      <|"Expression" -> z|>]];
  r
];

(* A closed algebraic-expression grammar. Domain membership additionally
   excludes numerical/transcendental Root objects. No assumptions about
   unassigned coefficient parameters are made. *)
algebraicFormQ[z_] := Which[
  MatchQ[z, _Integer | _Rational], True,
  Head[z] === Complex, algebraicFormQ[Re[z]] && algebraicFormQ[Im[z]],
  Head[z] === Root || Head[z] === AlgebraicNumber,
    NumericQ[z] && TrueQ[Element[z, Algebraics]],
  Head[z] === Plus || Head[z] === Times,
    AllTrue[List @@ z, algebraicFormQ],
  Head[z] === Power,
    MatchQ[z[[2]], _Integer | _Rational] && algebraicFormQ[z[[1]]],
  True, False
];

trim[v_List] := Module[{k = Length[v]},
  If[k == 0, Return[{0}]];
  While[k > 1 && v[[k]] === 0, k--];
  Take[v, k]
];
normalVector[v_List] := trim[red /@ v];
zeroVectorQ[v_List] := v === {0};
vectorDegree[v_List] := If[zeroVectorQ[v], -Infinity, Length[v] - 1];

inputVector[p_, x_Symbol] := Module[{q, c, r, i},
  If[NumericQ[x],
    fail["InvalidVariable", "The polynomial variable must be an unassigned, nonnumeric symbol."]];
  q = Quiet[Check[Expand[p], $Failed]];
  If[q === $Failed || ! TrueQ[PolynomialQ[q, x]],
    fail["NotPolynomial", "The input is not a univariate polynomial in the specified variable.",
      <|"Input" -> p, "Variable" -> x|>]];
  c = CoefficientList[q, x];
  If[c === {}, c = {0}];
  If[! FreeQ[c, _Real],
    fail["InexactCoefficient", "Only exact coefficients are accepted; inexact numbers are not rationalized."]];
  r = Table[
    With[{a = red[c[[i]]]},
      If[! algebraicFormQ[a] || ! NumericQ[a] ||
          ! TrueQ[Element[a, Algebraics]],
        fail["NonAlgebraicCoefficient",
          "A coefficient could not be certified as an exact algebraic number in the supported representation.",
          <|"CoefficientIndex" -> i - 1, "Coefficient" -> c[[i]]|>]];
      a],
    {i, Length[c]}];
  trim[r]
];

fromVector[v_List, x_Symbol] :=
  Total[MapIndexed[#1 x^(First[#2] - 1) &, v]];

properDegrees[v_List] := Module[{n = Length[v] - 1},
  If[n < 4, {}, Select[Divisors[n], 1 < # < n &]]
];

checkOptions[s_Symbol, o_List] := Module[{keys, bad},
  keys = First /@ Options[s];
  bad = Select[First /@ Flatten[o], ! MemberQ[keys, #] &];
  If[bad =!= {},
    fail["UnknownOption", "An unknown option was supplied.", <|"Options" -> bad|>]]
];

(* Ascending coefficient vectors. Products reduce once per output
   coefficient; division reduces after each update to preserve exact zeros. *)
vAdd[a_List, b_List] :=
  normalVector[PadRight[a, Max[Length[a], Length[b]]] +
    PadRight[b, Max[Length[a], Length[b]]]];
vSubtract[a_List, b_List] := vAdd[a, -b];

vMultiply[a_List, b_List] := Module[{out, i, j},
  If[zeroVectorQ[a] || zeroVectorQ[b], Return[{0}]];
  out = ConstantArray[0, Length[a] + Length[b] - 1];
  Do[
    If[a[[i]] =!= 0 && b[[j]] =!= 0,
      out[[i + j - 1]] = out[[i + j - 1]] + a[[i]] b[[j]]],
    {i, Length[a]}, {j, Length[b]}];
  normalVector[out]
];

vCompose[f_List, h_List] := Module[{out = {0}, i},
  Do[out = vAdd[vMultiply[out, h], {f[[i]]}],
    {i, Length[f], 1, -1}];
  out
];

vComposeChain[chain_List] := Fold[vCompose, {0, 1}, chain];

(* Polynomial long division by a monic polynomial, implemented explicitly
   so no implicit coefficient-domain or Extension setting is involved. *)
vDivideMonic[a_List, h_List] := Module[
  {n = Length[a] - 1, d = Length[h] - 1, q, r = a, s, k, j},
  If[d < 1 || Last[h] =!= 1,
    fail["InternalInvariant", "Monic division received an invalid divisor."]];
  If[n < d, Return[{{0}, a}]];
  q = ConstantArray[0, n - d + 1];
  Do[
    s = r[[k + 1]];
    q[[k - d + 1]] = s;
    If[s =!= 0,
      Do[r[[k - d + j + 1]] =
        red[r[[k - d + j + 1]] - s h[[j + 1]]],
        {j, 0, d - 1}]];
    r[[k + 1]] = 0,
    {k, n, d, -1}];
  {trim[q], trim[Take[r, d]]}
];

(* C(t)=t^n p(1/t)/lc(p), B(t)^m=C(t) modulo t^d.
   b_k = Sum[((m+1)j-m k)c_j b_(k-j),j=1..k]/(m k).
   h(x)=x^d+b_1 x^(d-1)+...+b_(d-1)x. *)
rightCandidate[p_List, d_Integer] := Module[
  {n = Length[p] - 1, m, c, b, k, j},
  m = Quotient[n, d];
  c = Table[red[p[[n - j + 1]]/Last[p]], {j, 0, d - 1}];
  b = ConstantArray[0, d]; b[[1]] = 1;
  Do[
    b[[k + 1]] = red[
      Total[Table[((m + 1) j - m k) c[[j + 1]] b[[k - j + 1]],
        {j, 1, k}]]/(m k)],
    {k, 1, d - 1}];
  Prepend[Reverse[b], 0]
];

(* h-adic expansion. A first nonconstant digit is an exact obstruction. *)
outerData[p_List, h_List] := Module[{q = p, digits = {}, qr, j = 0},
  While[Length[q] > 1,
    qr = vDivideMonic[q, h];
    If[Length[qr[[2]]] > 1,
      Return[<|"Success" -> False, "DigitIndex" -> j,
        "RemainderVector" -> qr[[2]], "PriorDigits" -> digits|>]];
    AppendTo[digits, First[qr[[2]]]];
    q = qr[[1]]; j++];
  AppendTo[digits, First[q]];
  <|"Success" -> True, "OuterVector" -> trim[digits]|>
];

trialData[p_List, d_Integer] := Module[{h, t},
  h = rightCandidate[p, d];
  t = outerData[p, h];
  If[TrueQ[t["Success"]] &&
      ! zeroVectorQ[vSubtract[vCompose[t["OuterVector"], h], p]],
    fail["InternalVerification", "The reconstructed pair failed exact recomposition."]];
  Join[<|"RightDegree" -> d, "OuterDegree" -> Quotient[Length[p] - 1, d],
    "RightVector" -> h|>, t]
];

rightPairs[p_List] := Module[{out = {}, t, d},
  Do[t = trialData[p, d];
    If[TrueQ[t["Success"]],
      AppendTo[out, {t["OuterVector"], t["RightVector"]}]],
    {d, properDegrees[p]}];
  out
];

completeVectorChain[p_List, order_String] := Module[{ds, t, d},
  ds = properDegrees[p];
  If[order === "Descending", ds = Reverse[ds]];
  Do[
    t = trialData[p, d];
    If[TrueQ[t["Success"]],
      Return[Join[completeVectorChain[t["OuterVector"], order],
        completeVectorChain[t["RightVector"], order]]]],
    {d, ds}];
  {p}
];

verifyChain[p_List, chain_List] :=
  zeroVectorQ[vSubtract[vComposeChain[chain], p]];

AlgebraicDecompose[p_, x_Symbol, opts : OptionsPattern[]] := Catch[
  Module[{v, chain, order = OptionValue["DegreeOrder"]},
    checkOptions[AlgebraicDecompose, {opts}];
    If[! MemberQ[{"Ascending", "Descending"}, order],
      fail["InvalidOption", "DegreeOrder must be Ascending or Descending."]];
    v = inputVector[p, x];
    chain = completeVectorChain[v, order];
    If[! verifyChain[v, chain],
      fail["InternalVerification", "The complete chain failed exact recomposition."]];
    fromVector[#, x] & /@ chain], $failureTag];

AlgebraicDecomposeAtDegree[p_, x_Symbol, d_Integer] := Catch[
  Module[{v = inputVector[p, x], t},
    If[! MemberQ[properDegrees[v], d],
      fail["InvalidRightDegree", "The right degree must be a proper divisor of the polynomial degree and greater than one.",
        <|"RightDegree" -> d, "PolynomialDegree" -> vectorDegree[v]|>]];
    t = trialData[v, d];
    If[TrueQ[t["Success"]],
      fromVector[#, x] & /@ {t["OuterVector"], t["RightVector"]},
      Missing["NotDecomposableAtDegree", d]]], $failureTag];

AlgebraicRightComponents[p_, x_Symbol] := Catch[
  Module[{v = inputVector[p, x]},
    Map[fromVector[#, x] &, rightPairs[v], {2}]], $failureTag];

(* Enumerate by the rightmost INDECOMPOSABLE component, not by arbitrary
   binary splitting. This prevents duplicate chains from different
   parenthesizations. The memo table is local to this call. *)
AlgebraicDecomposeAll[p_, x_Symbol, opts : OptionsPattern[]] := Catch[
  Module[{v, limit = OptionValue["MaxDecompositions"], memo, visit,
      results = {}, capTag = Unique["EnumerationCap$"], complete, chains},
    checkOptions[AlgebraicDecomposeAll, {opts}];
    If[! (limit === Infinity || (IntegerQ[limit] && limit >= 1)),
      fail["InvalidOption", "MaxDecompositions must be Infinity or a positive integer."]];
    v = inputVector[p, x];
    memo[q_List] := memo[q] = rightPairs[q];
    visit[q_List, suffix_List] := Module[{pairs = memo[q], pair, chain},
      If[pairs === {},
        chain = Prepend[suffix, q];
        If[! verifyChain[v, chain],
          fail["InternalVerification", "An enumerated chain failed exact recomposition."]];
        AppendTo[results, chain];
        If[limit =!= Infinity && Length[results] > limit,
          Throw[Null, capTag]],
        Do[
          If[memo[pair[[2]]] === {},
            visit[pair[[1]], Prepend[suffix, pair[[2]]]]],
          {pair, pairs}]]
    ];
    Catch[visit[v, {}], capTag];
    complete = limit === Infinity || Length[results] <= limit;
    If[! complete, results = Take[results, limit]];
    chains = Map[fromVector[#, x] &, results, {2}];
    <|"Decompositions" -> chains, "EnumerationComplete" -> complete,
      "ReturnedCount" -> Length[chains]|>], $failureTag];

AlgebraicDecompositionReport[p_, x_Symbol] := Catch[
  Module[{v = inputVector[p, x], tests, records, any, n},
    n = vectorDegree[v];
    tests = trialData[v, #] & /@ properDegrees[v];
    records = Map[Function[t,
      Join[<|"RightDegree" -> t["RightDegree"],
          "OuterDegree" -> t["OuterDegree"],
          "Candidate" -> fromVector[t["RightVector"], x],
          "DecomposableAtDegree" -> t["Success"]|>,
        If[TrueQ[t["Success"]],
          <|"OuterComponent" -> fromVector[t["OuterVector"], x]|>,
          <|"ObstructionDigit" -> t["DigitIndex"],
            "NonconstantRemainder" -> fromVector[t["RemainderVector"], x],
            "PreviousConstantDigits" -> t["PriorDigits"]|>]]], tests];
    any = AnyTrue[tests, TrueQ[#["Success"]] &];
    <|"Polynomial" -> fromVector[v, x], "Degree" -> n,
      "Status" -> Which[n < 1, "Constant", n == 1, "Linear",
        any, "Decomposable", True, "Indecomposable"],
      "DecisionComplete" -> True, "Trials" -> records|>], $failureTag];

AlgebraicCompose[chain_List, x_Symbol] := Catch[
  If[NumericQ[x],
    fail["InvalidVariable", "The polynomial variable must be an unassigned, nonnumeric symbol."]];
  fromVector[vComposeChain[inputVector[#, x] & /@ chain], x], $failureTag];

AlgebraicVerifyDecomposition[p_, chain_List, x_Symbol,
    opts : OptionsPattern[]] := Catch[
  Module[{v, cs, full = OptionValue["RequireComplete"],
      norm = OptionValue["RequireNormalized"]},
    checkOptions[AlgebraicVerifyDecomposition, {opts}];
    If[! MemberQ[{True, False}, full] || ! MemberQ[{True, False}, norm],
      fail["InvalidOption", "Verification options must be True or False."]];
    v = inputVector[p, x]; cs = inputVector[#, x] & /@ chain;
    If[! verifyChain[v, cs], Return[False]];
    If[norm && Length[cs] > 1 && ! AllTrue[Rest[cs],
        Length[#] >= 2 && First[#] === 0 && Last[#] === 1 &],
      Return[False]];
    If[full,
      If[Length[v] <= 2, Return[Length[cs] == 1]];
      If[! AllTrue[cs, Length[#] >= 3 && rightPairs[#] === {} &],
        Return[False]]];
    True], $failureTag];

(* Explicit catch-all results for invalid arities/types. They do not alter
   built-in Decompose or any global symbol definitions. *)
invalidCall[] := Failure["InvalidArguments", <|"MessageTemplate" ->
  "Use an unassigned symbol for the variable, an integer for a requested degree, and a list for a composition chain; see the function usage."|>];
AlgebraicDecompose[___] := invalidCall[];
AlgebraicDecomposeAtDegree[___] := invalidCall[];
AlgebraicRightComponents[___] := invalidCall[];
AlgebraicDecomposeAll[___] := invalidCall[];
AlgebraicDecompositionReport[___] := invalidCall[];
AlgebraicCompose[___] := invalidCall[];
AlgebraicVerifyDecomposition[___] := invalidCall[];

End[];
EndPackage[];
