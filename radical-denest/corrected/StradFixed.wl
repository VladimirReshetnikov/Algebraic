(* ::Package:: *)

(* StradFixed.wl -- a corrected and hardened version of src/original/Strad.wl

   The architecture of the original (wrapper -> marker -> multiplier search ->
   minimal polynomial / polynomial GCD -> roots-of-unity orbit) is retained.
   The changes are confined to correctness, robustness and resource control:

     * every accepted candidate is certified, with exact algebra, to equal the
       ORIGINAL problem (not the principal root of its power);
     * the custom factorizer only applies the power identities
       (a^b)^c -> a^(bc) and (F S)^p -> F^p S^p when they are provably valid,
       and its output is certified anyway;
     * factoring and marking are restricted to exact numeric algebraic
       subexpressions, so symbolic hosts are left untouched;
     * the prime comparator, the stale-length slice, the Ceiling[Log] cap and
       the {}[[1]] access are fixed; the multiplier cap is a real cap;
     * the search has a trial budget, a time budget and a visited set;
     * private context symbols replace the marker `f` and the variable `x`;
     * no Unprotect[Print]; diagnostics go through a "Verbose" option;
     * a result is only returned if it is certified equal to the input AND
       strictly cheaper under an explicit radical-complexity cost.

   Author: analysis session of 5 September 2026. *)

BeginPackage["RadicalDenest`"];

Strad::usage = "Strad[expr, opts] denests exact algebraic radicals occurring in expr and returns an expression certified equal to expr. Strad[expr, True] processes all nesting levels.";
DenestRadicals::usage = "DenestRadicals[expr, opts] is the option-driven wrapper behind Strad. DenestRadicals[expr, allLevels] is the legacy positional form.";
DenestCore::usage = "DenestCore[problem, opts] runs the multiplier search on a single exact nested radical and returns a certified equal expression (or problem itself).";
RationalizeDenominator::usage = "RationalizeDenominator[expr] rewrites expr so that its denominator is rational, using the minimal polynomial of the denominator.";
RadicalDepth::usage = "RadicalDepth[expr] is the maximal number of nested rational-power nodes on a path of expr.";
RadicalCost::usage = "RadicalCost[expr] is the lexicographic cost {#Root objects, radical depth, #radical nodes, leaf count} used to decide whether a rewrite is an improvement.";
ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] is True when e is an exact numeric algebraic number.";
CertifiedEqualQ::usage = "CertifiedEqualQ[a, b] is True only when a - b is proved to be zero by exact algebra.";
Factorc::usage = "Factorc[expr] is the branch-safe version of the original custom factorizer.";

Options[Strad] = Options[DenestRadicals] = {
   "AllLevels" -> False, "Verbose" -> False, "Multipliers" -> Automatic,
   "MaxTrials" -> 400, "TimeBudget" -> 120, "MultiplierCap" -> 1000,
   "CertifyTime" -> 20, "Solver" -> Automatic, "Factor" -> True};
Options[DenestCore] = {
   "Verbose" -> False, "Multipliers" -> Automatic, "MaxTrials" -> 400,
   "TimeBudget" -> 120, "MultiplierCap" -> 1000, "CertifyTime" -> 20};

Begin["`Private`"];

(* ------------------------------------------------------------------ *)
(* logging, predicates, certification                                 *)
(* ------------------------------------------------------------------ *)

$verbose = False;
$certifyTime = 20;
log[args___] := If[TrueQ[$verbose], Print[args]];

ExactAlgebraicQ[e_] := TrueQ[NumericQ[e] && Precision[e] === Infinity &&
    Quiet[Check[Element[e, Algebraics], False]]];

exactRealQ[e_] := ExactAlgebraicQ[e] && TrueQ[Quiet[Element[e, Reals]]];
positiveRealQ[e_] := exactRealQ[e] && TrueQ[Quiet[e > 0]];

(* numeric prefilter (cheap rejection) followed by exact certification *)
CertifiedEqualQ[a_, b_] := Module[{d, num, r},
   If[! ExactAlgebraicQ[a] || ! ExactAlgebraicQ[b], Return[False]];
   d = a - b;
   num = Quiet[N[d, 30]];
   If[NumberQ[num] && Abs[num] > 10^-20, Return[False]];
   r = Quiet[TimeConstrained[Check[RootReduce[d] === 0, $Failed], $certifyTime, $Failed]];
   If[r === True, Return[True]];
   If[r === False, Return[False]];
   r = Quiet[TimeConstrained[Check[PossibleZeroQ[d, Method -> "ExactAlgebraics"], $Failed], $certifyTime, $Failed]];
   TrueQ[r]];

(* ------------------------------------------------------------------ *)
(* representation cost                                                *)
(* ------------------------------------------------------------------ *)

RadicalDepth[e_] := If[AtomQ[e], 0,
   If[MatchQ[e, Power[_, _Rational]], 1 + RadicalDepth[First[e]],
    Max[Prepend[RadicalDepth /@ (List @@ e), 0]]]];

RadicalCost[e_] := {Count[e, _Root | _AlgebraicNumber, {0, Infinity}],
   RadicalDepth[e], Count[e, Power[_, _Rational], {0, Infinity}], Count[e, _?AtomQ, {-1}], LeafCount[e]};

cheaperQ[new_, old_] := Order[RadicalCost[new], RadicalCost[old]] === 1;
pickCheapest[list_List] := First[SortBy[list, RadicalCost]];

safeSimplify[e_] := Quiet[TimeConstrained[Simplify[e], $certifyTime, e]];

(* ------------------------------------------------------------------ *)
(* denominator rationalization (valid for nonzero algebraic denominators) *)
(* ------------------------------------------------------------------ *)

RationalizeDenominator[expr_] := Module[{x, e, num, denom, minpoly, q},
   e = Together[expr];
   denom = Denominator[e]; num = Numerator[e];
   If[denom === 1 || ! ExactAlgebraicQ[denom], Return[expr]];
   minpoly = Quiet[Check[MinimalPolynomial[denom, x], $Failed]];
   If[! PolynomialQ[minpoly, x], Return[expr]];
   q = PolynomialQuotient[minpoly, x - denom, x] /. x -> 0;
   Expand[num*q]/(-(minpoly /. x -> 0))];

(* ------------------------------------------------------------------ *)
(* structural helpers                                                 *)
(* ------------------------------------------------------------------ *)

radicalQ[e_] := MatchQ[e, Power[_, _Rational]];
nestedRadicalQ[e_] := RadicalDepth[e] >= 2;

(* LCM of exponent denominators of the rational-power nodes of maximal depth *)
reductionExponent[e_] := Module[{d = RadicalDepth[e], nodes},
   nodes = Select[Cases[e, Power[_, _Rational], {0, Infinity}], RadicalDepth[#] == d &];
   If[nodes === {}, 1, LCM @@ (Denominator[Last[#]] & /@ nodes)]];

summands[e_] := If[Head[e] === Plus, List @@ e, {e}];
factorsOf[e_] := If[Head[e] === Times, List @@ e, {e}];

complexitySort[list_] := SortBy[list, {LeafCount[#], Quiet[N[Abs[#], 20]]} &];

(* ------------------------------------------------------------------ *)
(* branch-safe custom factorizer                                      *)
(* ------------------------------------------------------------------ *)

(* (a^b)^c -> a^(b c) is valid when c is an integer or b is real with -1 < b <= 1 *)
powerMergeSafeQ[b_, c_] := IntegerQ[c] || (exactRealQ[b] && TrueQ[-1 < b <= 1]);

Factorc[expr_] := Module[{r},
   r = Quiet[Check[factorcRaw[expr], expr]];
   If[ExactAlgebraicQ[expr], If[CertifiedEqualQ[r, expr], r, expr], r]];

factorcRaw[expr_] :=
  Flatten[fullfactor[expr] //. {
      pow : {a : Except[_List], b : Except[_List]} :> {a^b},
      prod : {rep : (Repeated[{Except[_List]}, {2, Infinity}])} :> {Times[rep]},
      sum : {rep : Repeated[{{Except[_List]}}, {2, Infinity}]} :> Plus[rep],
      pow2 : {{a : Except[_List]}, b : Except[_List]} :> {a^b},
      pow3 : {{{a : Except[_List]}}, b : Except[_List]} :> {a^b}}][[1]];

fullfactor[expr_] := Module[{factorlist, i = 0, j = 0, done = False},
   factorlist = FactorList[expr];
   While[! done && j < 5,
    j++;
    done = True;
    For[i = 1, i <= Length[factorlist], i++,
     Which[
      Head[factorlist[[i, 1]]] === Power && powerMergeSafeQ[factorlist[[i, 1, 2]], factorlist[[i, 2]]],
      done = False;
      factorlist[[i]] = {{factorlist[[i, 1, 1]], factorlist[[i, 1, 2]]*factorlist[[i, 2]]}},
      And[MemberQ[{Integer, Rational}, Head[factorlist[[i, 1]]]], ! PrimeQ[factorlist[[i, 1]]], Abs[factorlist[[i, 1]]] =!= 1],
      done = False;
      factorlist[[i]] = {#[[1]], #[[2]]*factorlist[[i, 2]]} & /@ FactorInteger[factorlist[[i, 1]]],
      Head[factorlist[[i, 1]]] === Plus,
      done = False;
      factorlist[[i]] = combine[fullfactor /@ (List @@ factorlist[[i, 1]]), factorlist[[i, 2]]],
      True,
      factorlist[[i]] = {factorlist[[i]]}]];
    factorlist = Flatten[factorlist, 1]];
   factorlist];

(* common-factor extraction from a sum raised to the power pow:
   (F S)^pow -> F^pow S^pow only when pow is an integer, or F > 0, or S > 0 *)
combine[terms_List, pow_] := Module[{simpler = terms, base, bases, positions, factor, i, j, k, extracted, remaining, fval, sval},
   For[i = 1, i <= Length[terms], i++,
    base = terms[[i]];
    For[j = 1, j <= Length[base], j++,
     For[k = j + 1, k <= Length[base], k++,
      If[base[[j, 1]] === base[[k, 1]] && base[[j]] =!= {0, 0},
       base[[j]] = {base[[j, 1]], base[[j, 2]] + base[[k, 2]]};
       base[[k]] = {0, 0}]];
     If[base[[j, 1]] === 1, base[[j]] = {0, 0}]];
    simpler[[i]] = DeleteCases[base, {0, 0}]];
   bases = Intersection @@ Map[#[[1]] &, simpler, {2}];
   If[bases === {}, Return[{{simpler, pow}}]];
   extracted = simpler;
   bases = Table[
     positions = Position[#, {bases[[i]], Except[_List]}, 1] & /@ extracted;
     factor = Min[Extract[extracted[[#]], positions[[#]]][[1, 2]] & /@ Range[Length[extracted]]];
     For[j = 1, j <= Length[extracted], j++,
      extracted[[j, Sequence @@ (positions[[j, 1]]), 2]] -= factor];
     {bases[[i]], factor},
     {i, Length[bases]}];
   fval = Times @@ (#[[1]]^#[[2]] & /@ bases);
   sval = Plus @@ ((Times @@ (#[[1]]^#[[2]] & /@ #)) & /@ extracted);
   If[IntegerQ[pow] || positiveRealQ[fval] || positiveRealQ[sval],
    Append[({#[[1]], #[[2]]*pow} & /@ bases), {extracted, pow}],
    {{simpler, pow}}]];

(* apply the factorizer only to maximal exact numeric non-atomic subexpressions *)
numericTargetQ[s_] := ! AtomQ[s] && ExactAlgebraicQ[s];
safeFactorAll[expr_] := If[numericTargetQ[expr], Factorc[expr], expr /. s_?numericTargetQ :> Factorc[s]];

(* ------------------------------------------------------------------ *)
(* the wrapper                                                        *)
(* ------------------------------------------------------------------ *)

Strad[expr_, opts : OptionsPattern[]] := DenestRadicals[expr, opts];
Strad[expr_, all : (True | False), opts : OptionsPattern[]] := DenestRadicals[expr, "AllLevels" -> all, opts];
Strad[l_List, rest___] := Strad[#, rest] & /@ l;

DenestRadicals[expr_, all : (True | False), opts : OptionsPattern[]] := DenestRadicals[expr, "AllLevels" -> all, opts];
DenestRadicals[l_List, rest___] := DenestRadicals[#, rest] & /@ l;

sumQ[expression_] := MemberQ[expression, _Plus | Complex[Except[0], _], {0, Infinity}];

DenestRadicals[expr_, opts : OptionsPattern[]] :=
  Block[{$verbose = OptionValue["Verbose"], $certifyTime = OptionValue["CertifyTime"]},
   Module[{level, mod, problems, solver, coreOpts, rules, result, candidates, i1, i2, iter, best},
    If[Precision[expr] =!= Infinity && ! FreeQ[expr, _Real | _Complex?InexactNumberQ], Return[expr]];
    level = If[TrueQ[OptionValue["AllLevels"]], ReplaceRepeated, ReplaceAll];
    solver = OptionValue["Solver"];
    coreOpts = FilterRules[{opts}, Options[DenestCore]];
    If[solver === Automatic, solver = recursiveCore[#, coreOpts] &];
    (* Root/AlgebraicNumber objects are first converted to radicals when possible *)
    mod = expr;
    If[! FreeQ[mod, _Root | _AlgebraicNumber],
     mod = Quiet[TimeConstrained[ToRadicals[mod], $certifyTime, mod]];
     If[! FreeQ[mod, _Root | _AlgebraicNumber], mod = expr]];
    mod = If[TrueQ[OptionValue["Factor"]], safeFactorAll[mod], mod];
    (* mark exact algebraic radicands raised to rational powers *)
    mod = level[mod, radicand_?ExactAlgebraicQ^pow_Rational :> normalizeRadicand[radicand, pow]];
    (* group products of two markers whose radicands both contain radicals *)
    mod = mod //. Times[a___, mark[rad1_, pow1_], b___, mark[rad2_, pow2_], c___] :>
       Times[a, b, c, mark[(rad1^pow1)*(rad2^pow2)]] /; And[! FreeQ[rad1, Power], ! FreeQ[rad2, Power]];
    mod = level[mod, mark[rad_, pow_] :> mark[rad^pow]];
    mod = mod //. Times[a___, mark[rad1_], b___, mark[rad2_], c___] :> Times[a, b, c, mark[rad1*rad2]] /;
       And[And[Re[#] != 0, Im[#] != 0] &[N[rad1, 10]], And[Re[#] != 0, Im[#] != 0] &[N[rad2, 10]]];
    problems = DeleteDuplicates[Cases[mod, mark[_], {0, Infinity}]];
    log["problems: ", problems];
    If[! TrueQ[OptionValue["AllLevels"]],
     rules = (# -> Replace[#, mark[val_] :> solver[val]]) & /@ problems;
     result = mod /. rules,
     (* all levels: resolve innermost markers first, with an iteration cap *)
     iter = 0;
     For[i1 = 1, MemberQ[problems, mark[__]] && iter < 20 Length[problems] + 20, i1++,
      iter++;
      i1 = Mod[i1, Length[problems], 1];
      If[MatchQ[problems[[i1]], mark[problem__] /; FreeQ[problem, mark[__]]],
       problems[[i1]] = problems[[i1]] -> (problems[[i1]] /. mark -> solver);
       For[i2 = 1, i2 <= Length[problems], i2++,
        If[Head[problems[[i2]]] =!= Rule, problems[[i2]] = problems[[i2]] //. problems[[i1]]]]]];
     result = mod //. Cases[problems, _Rule];
     result = result /. mark[v_] :> v];
    (* choose the cheapest certified representative among input, result, Simplify[result] *)
    candidates = DeleteDuplicates[{result, safeSimplify[result], denestInnerSurds[result]}];
    If[ExactAlgebraicQ[expr],
     candidates = Select[candidates, CertifiedEqualQ[#, expr] &]];
    candidates = Select[candidates, cheaperQ[#, expr] &];
    If[candidates === {}, expr, pickCheapest[candidates]]]];

(* the core, followed by one further all-level pass on a partial solution *)
$recursion = 0;
recursiveCore[problem_, coreOpts_] := Module[{sol, again},
   sol = DenestCore[problem, Sequence @@ coreOpts];
   If[sol =!= problem && RadicalDepth[sol] >= 2 && $recursion < 2,
    again = Block[{$recursion = $recursion + 1},
      DenestRadicals[sol, "AllLevels" -> True, Sequence @@ coreOpts]];
    If[cheaperQ[again, sol] && CertifiedEqualQ[again, problem], sol = again]];
   sol];

(* value-preserving normalization of a radicand (the original marker rule), certified *)
normalizeRadicand[radicand_, pow_] := Module[{factored, i, j, value},
   value = Quiet[Check[
      factored = FactorTermsList[radicand];
      factored[[2]] = Flatten[{Replace[Factorc[factored[[2]]], prod_Times :> List @@ prod]}];
      factored[[1]] = DeleteCases[{#, ComplexExpand[factored[[1]]/#]} &[GCD[Re[factored[[1]]], Im[factored[[1]]]]], 1];
      factored[[1]] = #[[1]]^#[[2]] & /@ Flatten[FactorInteger /@ factored[[1]], 1];
      factored = Flatten[factored];
      factored = factored //. {a___, expr1_, b___, expr2_, c___} :> {a, b, c, ComplexExpand[expr1*expr2]} /; And[sumQ[expr1], sumQ[expr2]];
      j = 1;
      For[i = 1, i <= Length[factored], i++,
       If[TrueQ[N[Re[factored[[i]]], 100] < 0], factored[[i]] = -factored[[i]]; j *= -1]];
      factored = DeleteCases[Prepend[factored, j], 1];
      safeSimplify[Times @@ (safeSimplify[RationalizeDenominator[Together[#]]] & /@ factored)],
      $Failed]];
   If[value === $Failed || ! CertifiedEqualQ[value, radicand], value = radicand];
   mark[value, pow]];

(* ------------------------------------------------------------------ *)
(* quadratic surds: Sqrt[a + b Sqrt[c]] with rational a, b, c              *)
(* If a > 0 and a^2 - b^2 c = delta^2 with delta rational, then           *)
(*   Sqrt[a + b Sqrt[c]] = Sqrt[(a+delta)/2] + Sign[b] Sqrt[(a-delta)/2];   *)
(* the right-hand side is nonnegative, so it is the principal root.        *)
(* ------------------------------------------------------------------ *)

rationalQ[e_] := MatchQ[e, _Integer | _Rational];
(* named patterns are essential: two identical `_?rationalQ` factors would be
   combined by Times into (_?rationalQ)^(3/2) before matching *)
surdParts[rad_] := Replace[Expand[rad], {
    a_?rationalQ + b_?rationalQ Sqrt[c_?rationalQ] :> {a, b, c},
    a_?rationalQ + Sqrt[c_?rationalQ] :> {a, 1, c},
    _ :> $Failed}];
denestSurd[a_, b_, c_] := Module[{delta, s, u, v, r},
   If[a == 0 || b == 0 || c <= 0, Return[$Failed]];
   If[a < 0,
    If[TrueQ[a + b Sqrt[c] < 0], r = denestSurd[-a, -b, c]; Return[If[r === $Failed, $Failed, I r]], Return[$Failed]]];
   delta = a^2 - b^2 c;
   If[delta < 0, Return[$Failed]];
   s = Sqrt[delta];
   If[! rationalQ[s], Return[$Failed]];
   u = (a + s)/2; v = (a - s)/2;
   Sqrt[u] + Sign[b] Sqrt[v]];
denestSurdPower[rad_] := Module[{p = surdParts[rad], r},
   If[p === $Failed, Return[Sqrt[rad]]];
   r = denestSurd @@ p;
   If[r === $Failed, Sqrt[rad], r]];
denestInnerSurds[e_] := FixedPoint[Replace[#, Power[rad_, Rational[1, 2]] :> denestSurdPower[rad], {0, Infinity}] &, e, 4];

(* variants of a certified candidate; all are value preserving *)
polish[cand_] := DeleteDuplicates[Flatten[{cand, safeSimplify[cand],
     safeSimplify[Quiet[Check[RationalizeDenominator[Together[cand]], cand]]],
     denestInnerSurds[cand], safeSimplify[denestInnerSurds[cand]]}]];

(* ------------------------------------------------------------------ *)
(* the core: multiplier search                                        *)
(* ------------------------------------------------------------------ *)

DenestCore[problem_, OptionsPattern[]] :=
  Block[{$verbose = OptionValue["Verbose"], $certifyTime = OptionValue["CertifyTime"],
    $trials = 0, $maxTrials = OptionValue["MaxTrials"], $deadline = AbsoluteTime[] + OptionValue["TimeBudget"],
    $visited = <||>, $cap = OptionValue["MultiplierCap"]},
   Module[{radicand, outerpower, reductionpower, multiplierstack, multipliers, multiplier, terms, history,
     attempt, solution, updatehistory, stackchange, addmultipliers, forced, i1, i2, i3, r},
    If[! ExactAlgebraicQ[problem] || ! nestedRadicalQ[problem], Return[problem]];
    If[TrueQ[CertifiedEqualQ[problem, 0]], Return[0]];
    reductionpower = reductionExponent[problem];
    If[! IntegerQ[reductionpower] || reductionpower < 2, Return[problem]];
    outerpower = 1/reductionpower;
    radicand = problem^reductionpower;
    (* fast path for quadratic surds *)
    If[MatchQ[problem, Power[_, Rational[1, 2]]],
     r = denestSurdPower[First[problem]];
     If[r =!= problem && cheaperQ[r, problem] && CertifiedEqualQ[r, problem],
      log["quadratic surd fast path: ", problem, " -> ", r]; Return[r]]];
    log["problem  ", problem];
    log["outer root: ", reductionpower];
    forced = OptionValue["Multipliers"];
    If[ListQ[forced],
     multipliers = {{False, {0, Infinity, Infinity}}, forced},
     terms = DeleteCases[Replace[#, {Times[a___, Alternatives[_Rational, _Integer], b___] :> a*b,
           Alternatives[_Rational, _Integer] -> 0, Complex[a_, b_] :> Sign[b]*I}] & /@
        summands[Expand[RationalizeDenominator[radicand]]], 0];
     terms = SortBy[terms, Quiet[N[Re[#], 20]] &];
     multipliers = Prepend[DeleteCases[complementaryMultiplier /@ terms, 1], 1];
     multipliers = {{True, {0, Infinity, Infinity}}, DeleteDuplicates[multipliers]}];
    solution = problem;
    history = {{0, Infinity, Infinity}};
    multiplierstack = {multipliers};
    r = Catch[
      For[i1 = 1, i1 <= Length[multiplierstack], i1++,
       If[ListQ[multiplierstack[[i1, 2]]] =!= True,
        multiplierstack[[i1]] = multiplierstack[[i1, -2]] @@ (multiplierstack[[i1, -1]])];
       multipliers = multiplierstack[[i1]];
       stackchange = False;
       If[multipliers[[1, 2]] =!= history[[1]],
        log["multiplier count: ", Length[multipliers[[2]]], "  from: ", multipliers[[1, 2, {1, -1}]]],
        log["multiplier count: ", Length[multipliers[[2]]], "  multipliers: ", multipliers[[2]]]];
       For[i2 = 1, i2 <= Length[multipliers[[2]]], i2++,
        multiplier = multipliers[[2, i2]];
        updatehistory = False;
        addmultipliers = False;
        If[KeyExistsQ[$visited, multiplier],
         log["skipping visited multiplier ", multiplier];
         multiplierstack[[i1, 2, i2]] = {multiplier, $visited[multiplier]};
         Continue[]];
        If[$trials >= $maxTrials || AbsoluteTime[] > $deadline,
         log["budget exhausted after ", $trials, " trials"];
         Throw[Null, "budget"]];
        $trials++;
        attempt = If[And[Length[history] >= 3, history[[-2]] =!= history[[1]]],
          tryMultiplier[problem, radicand, outerpower, multiplier, history[[-1, -1]], True],
          tryMultiplier[problem, radicand, outerpower, multiplier, history[[-1, -1]], False]];
        $visited[multiplier] = attempt[[2, -1]];
        multiplierstack[[i1, 2, i2]] = {multiplier, attempt[[2, -1]]};
        If[And[multipliers[[1, 1]] === True, attempt[[2, -1]] <= history[[-1, -1]]], addmultipliers = True];
        If[attempt[[1]] === True,
         updatehistory = True;
         If[history[[-1]] =!= history[[1]], stackchange = True];
         If[Length[attempt] == 3,
          log["success: ", attempt[[2, {1, -1}]]];
          solution = If[cheaperQ[attempt[[-1]], solution], attempt[[-1]], solution];
          If[Or[history[[-1]] === history[[1]], history[[2, -1]]/attempt[[2, -1]] >= reductionpower],
           history = Append[history, attempt[[2]]];
           Throw[Null, "solution"],
           log["attempting additional denesting, current solution is: ", solution]]];
         If[And[history[[-1]] =!= history[[1]], Or[attempt[[2, -1]] < history[[-1, -1]], history[[-2]] === history[[1]]]],
          log["improvement  ", attempt[[2, {1, -1}]]];
          addmultipliers = True]];
        If[addmultipliers === True,
         Module[{smaller, larger, done, new},
          If[attempt[[2, -1]] <= history[[-1, -1]],
           smaller = attempt[[2]]; larger = history[[-1]],
           smaller = history[[-1]]; larger = attempt[[2]]];
          new = {{False, smaller}, newMultipliers, {smaller, If[larger =!= history[[1]], larger, Null], reductionpower}};
          log["adding new multipliers from: ", multiplier];
          If[multipliers[[1, 1]] === False,
           done = {multipliers[[1]], multipliers[[2, 1 ;; i2]]};
           multiplierstack = Insert[multiplierstack, new, i1 + 1];
           If[i2 < Length[multipliers[[2]]],
            multiplierstack = Insert[multiplierstack, {multipliers[[1]], multipliers[[2, i2 + 1 ;; -1]]}, i1 + 2]];
           multiplierstack[[i1]] = done,
           stackchange = False;
           For[i3 = Length[multiplierstack], i3 >= i1, i3--,
            If[Or[multiplierstack[[i3, 1, 2]] === history[[1]], new[[1, 2, -1]] > multiplierstack[[i3, 1, 2, -1]],
              And[new[[1, 2, -1]] === multiplierstack[[i3, 1, 2, -1]],
               LeafCount[new[[1, 2, 1]]] >= LeafCount[multiplierstack[[i3, 1, 2, 1]]]]],
             multiplierstack = Insert[multiplierstack, new, i3 + 1];
             Break[]]]]]];
        If[updatehistory === True,
         For[i3 = Length[history], i3 >= 1, i3--,
          If[history[[i3, -1]] > attempt[[2, -1]],
           history = Insert[history, attempt[[2]], i3 + 1];
           Break[]]]];
        If[stackchange === True, Break[]]];
       (* products of promising initial multipliers, after the first pass *)
       If[And[i1 === 1, ! ListQ[forced]],
        Module[{worst, extra, ff, good},
         good = Cases[multiplierstack[[i1, 2]], {_, _?NumericQ}];
         If[Length[good] >= 2,
          worst = Max[good[[All, 2]]];
          extra = DeleteCases[DeleteDuplicates[
              Replace[(Distribute[ff @@ (#^Range[0, 1] & /@ (Cases[good, {mult_, degree_} /; degree < worst][[All, 1]])), List] //. {
                    ff[a___, Power[base_Times, exp_], b___] :> ff[a, b, Sequence @@ ((List @@ base)^exp)],
                    ff[a___, prod_Times, b___] :> ff[a, b, Sequence @@ prod],
                    ff[a___, Power[base_, exp_], b___] :> ff[a, b, (-1)^exp, (-base)^exp] /; And[base != -1, TrueQ[Re[base] < 0]],
                    ff[a___, Power[base_, Rational[num1_, denom_]], b___, Power[base_, Rational[num2_, denom_]], c___] :>
                     ff[a, b, c, base^(Mod[num1 + num2, denom]/denom)]}) /. ff -> Times,
                 Times[a___, _Integer, b___] :> a*b, {1}] //. Power[base_, Rational[a_, b_]] :> base^(Mod[a, b]/b)],
             Alternatives @@ multiplierstack[[i1, 2, All, 1]]];
          extra = Select[extra, ExactAlgebraicQ[#] && ! TrueQ[# == 0] &];
          If[Length[extra] > $cap, extra = Take[complexitySort[extra], $cap]];
          If[Length[extra] >= 1,
           log["adding multipliers based on progress in initial guess"];
           multiplierstack = Insert[multiplierstack, {multiplierstack[[i1, 1]], extra}, i1 + 1]]]]]],
      "solution" | "budget"];
    log["history: ", #[[{1, -1}]] & /@ history];
    log["trials: ", $trials];
    If[solution =!= problem && CertifiedEqualQ[solution, problem], solution, problem]]];

(* complementary multiplier for one term of the expanded radicand *)
complementaryMultiplier[term_] := Times @@ (complementaryFactor /@ factorsOf[term]);
complementaryFactor[Power[b_, Rational[n_, d_]]] := b^((d - n)/d);
complementaryFactor[Complex[0, _]] := -I;
complementaryFactor[e_] := Module[{deep = Cases[e, Power[_, _Rational], {0, Infinity}], maxd},
   If[deep === {}, 1,
    maxd = Max[RadicalDepth /@ deep];
    Times @@ (complementaryFactor /@ Select[deep, RadicalDepth[#] == maxd &])]];

(* one trial: {progress?, {multiplier, minpoly, degree}, [certified answer]} *)
tryMultiplier[problem_, radicand_, outerpower_, multiplier_, best_, worseknown_] :=
  Module[{arg1, r = 1/outerpower, minpoly, degree, polygcd, possibilities, roots, certified, result},
   result = {False, {multiplier, Null, Infinity}};
   If[! ExactAlgebraicQ[multiplier] || TrueQ[Quiet[PossibleZeroQ[multiplier, Method -> "ExactAlgebraics"]]],
    log["invalid multiplier skipped: ", multiplier]; Return[result]];
   minpoly = Quiet[Check[MinimalPolynomial[(multiplier*radicand)^outerpower, arg1], $Failed]];
   If[! PolynomialQ[minpoly, arg1], log["minimal polynomial failed for ", multiplier]; Return[result]];
   degree = Exponent[minpoly, arg1];
   result = {False, {multiplier, Function[Evaluate[minpoly /. arg1 -> #]], degree}};
   log["multiplier: ", multiplier, "   minpoly degree: ", degree];
   If[Or[degree <= best, GCD[degree, best] < best],
    polygcd = Quiet[Check[PolynomialGCD[minpoly, arg1^r - multiplier*radicand, Extension -> Automatic], $Failed]];
    If[! PolynomialQ[polygcd, arg1], log["PolynomialGCD failed for ", multiplier]; Return[result]];
    If[And[0 < Exponent[polygcd, arg1] < r],
     roots = Quiet[Check[arg1 /. Solve[polygcd == 0, arg1], {}]];
     roots = Select[Flatten[{roots}], ExactAlgebraicQ];
     possibilities = Flatten[Outer[Times, roots/(multiplier^outerpower), Exp[2*I*Pi*Range[0, r - 1]/r]]];
     certified = Select[possibilities, CertifiedEqualQ[#, problem] &];
     If[certified =!= {},
      certified = DeleteDuplicates[Flatten[polish /@ certified]];
      result = {True, result[[2]], pickCheapest[certified]},
      log["GCD of degree ", Exponent[polygcd, arg1], " but no certified candidate for ", multiplier];
      If[Or[degree < best, And[GCD[degree, best] < best, worseknown =!= True]], result[[1]] = True]],
     If[polygcd =!= 1 && Exponent[polygcd, arg1] > 0,
      If[Or[degree < best, And[GCD[degree, best] < best, worseknown =!= True]], result[[1]] = True],
      log["PolynomialGCD returned a constant: ", {radicand, outerpower, multiplier}]]],
    If[And[worseknown =!= True, degree != best],
     log["previous progress identified"];
     result[[1]] = True]];
   result];

(* generate a batch of multipliers from a discriminant, with a real cap *)
newMultipliers[smaller_, larger_, reductionpower_] :=
  Module[{arg1, new, primes, multiplierprimes, minprimes = 5, primeratio = 100, count, t, i3, disc},
   If[Or[larger === Null, GCD[smaller[[-1]], larger[[-1]]] == Min[smaller[[-1]], larger[[-1]]]],
    disc = Quiet[Check[Discriminant[smaller[[2]][arg1], arg1], $Failed]];
    If[! IntegerQ[disc] || disc == 0, Return[{{False, smaller}, {}}]];
    primes = DeleteCases[FactorInteger[disc, Automatic], {-1, 1}];
    primes = Select[primes, If[PrimeQ[#[[1]]], True, log["composite factor dropped: ", #]; False] &];
    primes = SortBy[primes, First][[All, 1]];
    multiplierprimes = primes;
    For[i3 = Length[primes], And[i3 > minprimes, multiplierprimes[[i3]]/multiplierprimes[[i3 - 1]] > primeratio], i3--,
     multiplierprimes[[i3]] = 0];
    multiplierprimes = DeleteCases[multiplierprimes, 0];
    (* largest t with reductionpower^t - 1 <= cap, computed in integer arithmetic *)
    t = 0; While[reductionpower^(t + 1) - 1 <= $cap, t++];
    count = Min[Max[1, t], Length[multiplierprimes]];
    multiplierprimes = Take[multiplierprimes, count];
    new = smaller[[1]]*Drop[Union[Divisors[(Times @@ multiplierprimes)^(reductionpower - 1)], primes], 1],
    log["GCD of smallest degrees is smaller than any observed degree: ", {smaller[[{1, -1}]], larger[[{1, -1}]]}];
    new = {smaller[[1]]*larger[[1]]}];
   new = DeleteCases[new, m_ /; KeyExistsQ[$visited, m]];
   {{False, smaller}, complexitySort[new]}];

End[];
EndPackage[];
