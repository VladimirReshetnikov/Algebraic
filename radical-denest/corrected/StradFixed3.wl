(* ::Package:: *)

(* StradFixed3.wl -- third corrected version of src/original/Strad.wl.

   Successor of StradFixed2.wl (RadicalDenest3`). It answers the three reviews
   of the second corrected version (src/code-review/review-7, review-8,
   review-9). The report in src/code-review/unified-C explains every change.

   Contract (for an exact algebraic input E and every exact algebraic island of
   a symbolic host):
     * every replaced island is certified equal to the island it replaces by
       exact algebra (RootReduce, then PossibleZeroQ with
       Method -> "ExactAlgebraics"), whatever produced the candidate; the
       optional numeric prefilter only prunes candidates inside the search and
       never decides an equality status;
     * an accepted replacement is strictly cheaper under RadicalCost, or the
       island is returned unchanged; every search stage returns its incumbent
       or a certified cheaper candidate;
     * the exact input grammar admits rationals, Gaussian rationals, Plus,
       Times and rational Power combinations of them, Root objects whose
       defining polynomial has coefficients in that grammar and a valid root
       index, and AlgebraicNumber objects with an admitted generator and
       Gaussian-rational coefficients; other exact objects are unsupported;
     * the whole call, including the classification of the input and the cost
       computations of the report, runs inside one TimeConstrained and
       MemoryConstrained region ("TimeBudget", "MemoryBudget"); every expensive
       kernel operation runs inside its own bounded region; "MaxTrials" bounds
       the multiplier trials spent on any one island;
     * symbolic hosts are never simplified; ambient $Assumptions are ignored;
     * malformed, unknown or invalid options produce a Failure.
   There is no completeness or minimum-depth guarantee: an unchanged result
   means that the enabled bounded methods found nothing cheaper. The kernel
   limits are cooperative and are not an operating-system sandbox.

   Context: RadicalDenest3`. The package can be loaded next to RadicalDenest3`
   and RadicalDenest` for differential testing. Author: analysis session of
   5 September 2026. *)

BeginPackage["RadicalDenest3`"];

Strad::usage = "Strad[expr, opts] denests the exact algebraic radicals occurring in expr and returns an expression certified equal to expr. Strad[expr, True, opts] also processes inner nesting levels and repeats passes while they improve the result.";
DenestRadicals::usage = "DenestRadicals[expr, opts] is the option-driven form of Strad with its own option defaults.";
DenestCore::usage = "DenestCore[problem, opts] denests one exact algebraic number without traversing a symbolic host.";
DenestReport::usage = "DenestReport[expr, opts] returns an Association with the result (\"Result\"), \"Status\", \"Limits\", \"Statistics\", \"Certificates\", \"ElapsedSeconds\", \"Options\" and an optional bounded \"Trace\".";
EqualityStatus::usage = "EqualityStatus[a, b] is \"Equal\", \"Different\" or \"Unknown\" for exact algebraic numbers a and b, decided by exact algebra only (RootReduce, then PossibleZeroQ with Method -> \"ExactAlgebraics\") within a time limit; inputs outside the supported grammar give \"Unknown\".";
CertifiedEqualQ::usage = "CertifiedEqualQ[a, b] is True only when EqualityStatus[a, b] is \"Equal\".";
ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] is True when e is in the supported exact algebraic grammar: rationals, Gaussian rationals, Plus, Times and rational Power combinations of them, Root objects of a polynomial with such coefficients and a valid root index, and AlgebraicNumber objects with an admitted generator and Gaussian-rational coefficients. False also covers unsupported exact representations.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] is True when e is an explicit radical expression: rationals, Gaussian rationals and Plus, Times and rational Power combinations of them. Root and AlgebraicNumber objects are not radical expressions.";
RadicalDepth::usage = "RadicalDepth[e] is the maximal number of nested rational-power nodes on a path of e. Root and AlgebraicNumber objects are opaque and count as depth 0.";
RadicalCost::usage = "RadicalCost[e] is the lexicographic cost {#Root and AlgebraicNumber objects, radical depth, #rational-power nodes outside opaque objects, LeafCount, total bit size of integer, rational and Gaussian-rational atoms} used to decide whether a rewrite is an improvement.";
RationalizeDenominator::usage = "RationalizeDenominator[expr] rewrites expr with a rational denominator using a certified polynomial inverse of the exact algebraic denominator. It need not reduce RadicalCost.";
Factorc::usage = "Factorc[expr] offers Factor of an exact algebraic expr as a certified proposal and returns it only when it is certified equal and cheaper. Symbolic input is returned unchanged.";

Options[Strad] = {
   "AllLevels" -> False, "Verbose" -> False, "Trace" -> False,
   "Multipliers" -> Automatic, "Solver" -> Automatic, "Factor" -> True,
   "MaxTrials" -> 120, "TimeBudget" -> 120, "OperationTime" -> 30,
   "CertifyTime" -> 20, "MemoryBudget" -> 1073741824,
   "MultiplierCap" -> 1000, "MaxRootIndex" -> 32, "MaxDegree" -> 64,
   "MaxSolveDegree" -> 4, "MaxLeafCount" -> 20000, "MaxPasses" -> 4,
   "MaxRecursion" -> 3, "Patience" -> 25, "NumericPrefilter" -> False, "MaxTraceEntries" -> 200,
   "MaxOddIndex" -> 9, "DiscriminantBatchCap" -> 24, "MaxCosets" -> 16};
Options[DenestRadicals] = Options[Strad];
Options[DenestCore] = Options[Strad];
Options[DenestReport] = Options[Strad];

Begin["`Private`"];

(* ------------------------------------------------------------------ *)
(* session state (dynamically scoped by run[]), statistics, tracing   *)
(* ------------------------------------------------------------------ *)

$active = False;
$cfg = Association[Options[Strad]];
$deadline = Infinity;
$stats = <||>; $limits = <||>; $trace = {}; $records = {}; $memo = <||>; $inProgress = <||>;
$recursion = 0; $lastCertificateMethod = "None";
$x = Unique["RadicalDenest3`Private`x"];

newStats[] := <|"Islands" -> 0, "Trials" -> 0, "Operations" -> 0,
   "OperationTimeouts" -> 0, "OperationFailures" -> 0,
   "Certificates" -> 0, "CertificatesEqual" -> 0, "CertificatesDifferent" -> 0,
   "CertificatesUnknown" -> 0, "NumericRejections" -> 0, "CosetSystems" -> 0,
   "CandidatesAccepted" -> 0, "MultipliersProposed" -> 0,
   "MultipliersAdmitted" -> 0, "DuplicateMultipliers" -> 0,
   "FastPathAccepted" -> 0, "PassesCompleted" -> 0|>;

bump[key_String] := AssociateTo[$stats, key -> (Lookup[$stats, key, 0] + 1)];
limitHit[key_String] := AssociateTo[$limits, key -> True];
remaining[] := $deadline - AbsoluteTime[];
expiredQ[] := If[remaining[] <= 0, limitHit["TimeBudget"]; True, False];

log[args___] := If[TrueQ[$cfg["Verbose"]], Print["[RadicalDenest3] ", args]];
trace[tag_String, data_: <||>] := If[TrueQ[$cfg["Trace"]] &&
    Length[$trace] < $cfg["MaxTraceEntries"],
   AppendTo[$trace, <|"Event" -> tag, "Data" -> data|>]];

(* Every expensive kernel operation runs inside bounded[...]: its own time
   limit, clipped to the remaining session time, with messages silenced and
   failures turned into $Failed. *)
SetAttributes[bounded, HoldAll];
bounded[body_, kind_: "Operation"] := Module[{seconds, value},
   seconds = Min[remaining[], If[kind === "Certificate", $cfg["CertifyTime"], $cfg["OperationTime"]]];
   If[seconds <= 0,
    limitHit[If[remaining[] <= 0, "TimeBudget", kind <> "Time"]]; Return[$Failed]];
   bump["Operations"];
   value = Quiet[Check[TimeConstrained[body, seconds, operationTimedOut], operationFailed]];
   Which[
    value === operationTimedOut,
     bump["OperationTimeouts"]; trace["OperationTimeout"];
     limitHit[If[kind === "Certificate", "CertifyTime", "OperationTime"]];
     If[remaining[] <= 0, limitHit["TimeBudget"]]; $Failed,
    value === operationFailed || value === $Failed || value === $Aborted,
     bump["OperationFailures"]; $Failed,
    True, value]];

(* ------------------------------------------------------------------ *)
(* option resolution and validation                                   *)
(* ------------------------------------------------------------------ *)

finiteNonnegativeQ[v_] := MatchQ[v, _Integer | _Rational | _Real] && TrueQ[0 <= v < Infinity];
nonnegativeIntegerQ[v_] := IntegerQ[v] && v >= 0;
positiveIntegerQ[v_] := IntegerQ[v] && v >= 1;
booleanQ[v_] := v === True || v === False;

flattenRules[items_List] := Flatten[Replace[items, l_List :> flattenRules[l], {1}], 1];

resolveOptions[head_Symbol, raw_List] := Module[{rules, names, unknown, cfg, bad},
   rules = flattenRules[raw];
   If[! AllTrue[rules, MatchQ[#, _Rule | _RuleDelayed] &],
    Return[Failure["InvalidOption", <|"MessageTemplate" -> "Options must be rules.", "Rules" -> rules|>]]];
   names = First /@ Options[head];
   unknown = Complement[First /@ rules, names];
   If[unknown =!= {},
    Return[Failure["UnknownOption", <|"MessageTemplate" -> "Unknown option(s): `Keys`.", "Keys" -> unknown|>]]];
   (* effective defaults of the head actually called, first explicit rule wins *)
   cfg = Association[Table[With[{name = key}, name -> OptionValue[head, rules, name]], {key, names}]];
   bad = Join[
     Select[{"AllLevels", "Verbose", "Trace", "Factor", "NumericPrefilter"}, ! booleanQ[cfg[#]] &],
     Select[{"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience", "DiscriminantBatchCap", "MaxCosets"}, ! nonnegativeIntegerQ[cfg[#]] &],
     Select[{"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount", "MaxPasses", "MaxOddIndex"}, ! positiveIntegerQ[cfg[#]] &],
     Select[{"TimeBudget", "OperationTime", "CertifyTime"}, ! finiteNonnegativeQ[cfg[#]] &]];
   If[! (cfg["Multipliers"] === Automatic || ListQ[cfg["Multipliers"]]), AppendTo[bad, "Multipliers"]];
   If[! (cfg["Solver"] === Automatic || MatchQ[cfg["Solver"], _Function | _Symbol]), AppendTo[bad, "Solver"]];
   If[cfg["MaxSolveDegree"] > 4, AppendTo[bad, "MaxSolveDegree"]];
   If[bad =!= {},
    Return[Failure["InvalidOption", <|"MessageTemplate" -> "Invalid value(s) for `Keys`; limits must be finite and of the documented type.", "Keys" -> bad|>]]];
   cfg];

(* ------------------------------------------------------------------ *)
(* grammar, depth, cost                                               *)
(* ------------------------------------------------------------------ *)

rationalQ[e_] := MatchQ[e, _Integer | _Rational];
gaussianQ[e_] := rationalQ[e] || (Head[e] === Complex && rationalQ[Re[e]] && rationalQ[Im[e]]);
opaqueQ[e_] := MatchQ[e, _Root | _AlgebraicNumber];

RadicalExpressionQ[e_] := Which[
   gaussianQ[e], True,
   AtomQ[e], False,
   MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, RadicalExpressionQ],
   Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
   True, False];

(* A Root object is admitted only when its defining function gives a nonconstant
   univariate polynomial whose coefficients are explicit algebraic numbers of the
   radical grammar and its index is a valid root selector; an AlgebraicNumber
   needs an admitted generator and Gaussian-rational coefficients. Exactness of
   the representation alone (Root[#^5 + # - Pi &, 1]) does not make a number
   algebraic. *)
rootPolynomial[e_] := Module[{args, fs, ks, p, degree, vars, ps},
   If[Head[e] =!= Root, Return[$Failed]];
   args = List @@ e;
   If[! MemberQ[{2, 3}, Length[args]], Return[$Failed]];
   If[Length[args] === 3 && ! MemberQ[{0, 1}, args[[3]]], Return[$Failed]];
   fs = args[[1]]; ks = args[[2]];
   Which[
    Head[fs] === Function && positiveIntegerQ[ks],
     p = Quiet[Check[Expand[fs[$x]], $Failed]];
     If[p === $Failed || ! TrueQ[PolynomialQ[p, $x]], Return[$Failed]];
     degree = Exponent[p, $x];
     If[! positiveIntegerQ[degree] || ks > degree, Return[$Failed]];
     If[! AllTrue[CoefficientList[p, $x], RadicalExpressionQ], Return[$Failed]];
     p,
    (* the kernel writes a root of a polynomial with algebraic coefficients as a
       triangular system Root[{f1, f2, ...}, {k1, k2, ...}]; every polynomial of
       the system must have coefficients in the radical grammar *)
    ListQ[fs] && ListQ[ks] && Length[fs] === Length[ks] && fs =!= {} && AllTrue[fs, Head[#] === Function &] && AllTrue[ks, positiveIntegerQ],
     vars = Table[Unique["RadicalDenest3`Private`rv"], {Length[fs]}];
     ps = Quiet[Check[Expand[#[Sequence @@ vars]] & /@ fs, $Failed]];
     If[ps === $Failed || ! AllTrue[ps, TrueQ[PolynomialQ[#, vars]] && ! FreeQ[#, Alternatives @@ vars] &], Return[$Failed]];
     If[! AllTrue[ps, AllTrue[Values[CoefficientRules[#, vars]], RadicalExpressionQ] &], Return[$Failed]];
     Last[ps],
    True, $Failed]];

algebraicFormQ[e_] := Which[
   gaussianQ[e], True,
   Head[e] === Root, rootPolynomial[e] =!= $Failed,
   Head[e] === AlgebraicNumber, Length[e] === 2 && ListQ[e[[2]]] && AllTrue[e[[2]], gaussianQ] && algebraicFormQ[e[[1]]],
   AtomQ[e], False,
   MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, algebraicFormQ],
   Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && algebraicFormQ[e[[1]]],
   True, False];

(* exactness is decided by the grammar (algebraic by construction) *)
ExactAlgebraicQ[e_] := algebraicFormQ[e] && FreeQ[e, Indeterminate | ComplexInfinity | _DirectedInfinity];
exactQ[e_] := ExactAlgebraicQ[e];

RadicalDepth[e_] := Which[
   AtomQ[e] || opaqueQ[e], 0,
   MatchQ[e, Power[_, _Rational]], 1 + RadicalDepth[First[e]],
   True, Max[Prepend[RadicalDepth /@ (List @@ e), 0]]];

(* recursive traversals that stop at opaque objects; Gaussian atoms are priced
   through their components *)
radicalNodes[e_] := Which[opaqueQ[e] || AtomQ[e], 0,
   True, Boole[MatchQ[e, Power[_, _Rational]]] + Total[radicalNodes /@ (List @@ e)]];
opaqueCount[e_] := Which[opaqueQ[e], 1, AtomQ[e], 0, True, Total[opaqueCount /@ (List @@ e)]];
bitSize[e_] := Which[
   IntegerQ[e], 1 + IntegerLength[Abs[e], 2],
   Head[e] === Rational, 2 + IntegerLength[Abs[Numerator[e]], 2] + IntegerLength[Denominator[e], 2],
   Head[e] === Complex, bitSize[Re[e]] + bitSize[Im[e]],
   AtomQ[e], 0,
   True, Total[bitSize /@ (List @@ e)]];

RadicalCost[e_] := {opaqueCount[e], RadicalDepth[e], radicalNodes[e], LeafCount[e], bitSize[e]};
cheaperQ[new_, old_] := Order[RadicalCost[new], RadicalCost[old]] === 1;
pickCheapest[list_List] := First[SortBy[list, RadicalCost]];
smallQ[e_] := If[LeafCount[e] > $cfg["MaxLeafCount"], limitHit["MaxLeafCount"]; False, True];

(* ------------------------------------------------------------------ *)
(* exact certification                                                *)
(* ------------------------------------------------------------------ *)

(* RootReduce is a canonicalizer: a reduced difference that is a nonzero exact
   algebraic number (an integer, rational, Gaussian rational, Root object or
   explicit radical form such as 2 Sqrt[2]) proves inequality *)
canonicalNonzeroQ[e_] := e =!= 0 && exactQ[e] && FreeQ[e, RootReduce];

(* heuristic pruning by significance arithmetic, used only by the search gate;
   it can lose a candidate, never accept one, and never decides EqualityStatus *)
numericallyDifferentQ[d_] := Module[{num},
   If[! TrueQ[$cfg["NumericPrefilter"]], Return[False]];
   num = bounded[N[d, 40]];
   TrueQ[NumberQ[num] && Accuracy[num] >= 25 && Abs[num] > 10^-20]];

certify[a_, b_] := Module[{d, r},
   bump["Certificates"]; $lastCertificateMethod = "None";
   If[! exactQ[a] || ! exactQ[b], bump["CertificatesUnknown"]; Return["Unknown"]];
   If[a === b, $lastCertificateMethod = "SameQ"; bump["CertificatesEqual"]; Return["Equal"]];
   d = a - b;
   r = bounded[RootReduce[d], "Certificate"];
   Which[
    r === 0, $lastCertificateMethod = "RootReduce"; bump["CertificatesEqual"]; Return["Equal"],
    canonicalNonzeroQ[r], $lastCertificateMethod = "RootReduce"; bump["CertificatesDifferent"]; Return["Different"]];
   r = bounded[PossibleZeroQ[d, Method -> "ExactAlgebraics"], "Certificate"];
   Which[
    r === True, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics"; bump["CertificatesEqual"]; "Equal",
    r === False, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics"; bump["CertificatesDifferent"]; "Different",
    True, bump["CertificatesUnknown"]; "Unknown"]];

SetAttributes[standalone, HoldAll];
standalone[body_, failure_] := If[TrueQ[$active], body,
   Block[{$active = True, $cfg = Association[Options[Strad]], $deadline = AbsoluteTime[] + 20,
     $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>, $inProgress = <||>,
     $recursion = 0, $lastCertificateMethod = "None", $Assumptions = True},
    Quiet[Check[TimeConstrained[MemoryConstrained[body, 1073741824, failure], 20, failure], failure]]]];

EqualityStatus[a_, b_] := standalone[certify[a, b], "Unknown"];
CertifiedEqualQ[a_, b_] := EqualityStatus[a, b] === "Equal";

(* The single acceptance gate. A candidate replaces the incumbent only if it is
   an explicit radical expression, small, strictly cheaper than the incumbent,
   and certified equal to the ORIGINAL target of this island. *)
accept[candidate_, target_, incumbent_, method_String] := Module[{},
   If[candidate === $Failed || candidate === target || ! RadicalExpressionQ[candidate] ||
     ! smallQ[candidate] || ! cheaperQ[candidate, incumbent], Return[incumbent]];
   (* optional heuristic pruning: skips the exact certificate of a candidate
      whose difference from the target is numerically far from zero *)
   If[numericallyDifferentQ[candidate - target], bump["NumericRejections"]; Return[incumbent]];
   If[certify[candidate, target] === "Equal",
    bump["CandidatesAccepted"];
    If[Length[$records] < $cfg["MaxTraceEntries"],
     AppendTo[$records, <|"Before" -> target, "After" -> candidate, "Method" -> method,
       "EqualityMethod" -> $lastCertificateMethod, "Scope" -> "AcceptedProposal"|>]];
    log[method, ": ", target, " -> ", candidate];
    trace["Accepted", <|"Method" -> method, "Cost" -> RadicalCost[candidate]|>];
    candidate,
    incumbent]];

(* variants of a candidate that may print more cheaply; each is re-gated *)
acceptWithPolish[candidate_, target_, incumbent_, method_String] := Module[{best = incumbent, v},
   If[expiredQ[] || candidate === $Failed || ! smallQ[candidate] || ! exactQ[candidate], Return[best]];
   best = accept[candidate, target, best, method];
   v = bounded[Simplify[candidate, Assumptions -> True, TimeConstraint -> 5]];
   best = accept[v, target, best, method <> "/Simplify"];
   v = bounded[Expand[candidate]];
   best = accept[v, target, best, method <> "/Expand"];
   v = bounded[Together[candidate]];
   best = accept[v, target, best, method <> "/Together"];
   v = rationalizeRaw[candidate];
   best = accept[v, target, best, method <> "/Rationalize"];
   best];

(* ------------------------------------------------------------------ *)
(* certified denominator inverse                                      *)
(* ------------------------------------------------------------------ *)

validPolynomialQ[p_, x_, minimum_Integer: 1] := Module[{degree},
   If[! FreeQ[p, $Failed | $Aborted | operationFailed | operationTimedOut] || ! TrueQ[PolynomialQ[p, x]], Return[False]];
   degree = Exponent[p, x];
   IntegerQ[degree] && degree >= minimum && degree <= $cfg["MaxDegree"]];

rationalizeRaw[e_] := Module[{t, num, den, p, c, inv, result},
   t = bounded[Together[e]];
   If[t === $Failed, Return[$Failed]];
   num = Numerator[t]; den = Denominator[t];
   If[rationalQ[den], Return[t]];
   If[! exactQ[den] || ! smallQ[den], Return[$Failed]];
   p = bounded[MinimalPolynomial[den, $x]];
   If[! validPolynomialQ[p, $x], Return[$Failed]];
   c = CoefficientList[p, $x];
   If[! AllTrue[c, rationalQ] || First[c] === 0, Return[$Failed]];
   (* p(d) = 0 gives 1/d = -(a1 + a2 d + ... + an d^(n-1))/a0 (Horner form) *)
   inv = bounded[-Fold[#1 den + #2 &, Last[c], Reverse[Rest[Most[c]]]]/First[c]];
   If[inv === $Failed || certify[den inv, 1] =!= "Equal", Return[$Failed]];
   result = bounded[Expand[num inv]];
   If[result === $Failed || ! smallQ[result], $Failed, result]];

RationalizeDenominator[e_] := standalone[Replace[rationalizeRaw[e], $Failed -> e], e];

Factorc[e_] := standalone[If[exactQ[e], accept[bounded[Factor[e]], e, e, "Factor"], e], e];

(* ------------------------------------------------------------------ *)
(* exact low-degree fast paths                                        *)
(* ------------------------------------------------------------------ *)

(* a + b Sqrt[c] with rational a, b, c > 0 nonsquare, after expansion *)
quadraticParts[rho_] := Module[{e, terms, rat, irr, a, t, c, b},
   e = bounded[Expand[rho]];
   If[e === $Failed, Return[$Failed]];
   terms = If[Head[e] === Plus, List @@ e, {e}];
   rat = Select[terms, rationalQ]; irr = Select[terms, ! rationalQ[#] &];
   If[Length[irr] =!= 1, Return[$Failed]];
   a = Total[rat]; t = First[irr];
   c = Replace[t, {Sqrt[cc_?rationalQ] :> cc, Times[k_?rationalQ, Sqrt[cc_?rationalQ]] :> k^2 cc, _ -> $Failed}];
   If[c === $Failed || ! TrueQ[c > 0] || rationalQ[Sqrt[c]], Return[$Failed]];
   b = Replace[t, {Sqrt[_] :> 1, Times[k_?rationalQ, Sqrt[_]] :> Sign[k], _ -> 1}];
   (* represent as a + b Sqrt[c] with b = +-1 and c absorbing the coefficient *)
   {a, b, c}];

(* direct and indirect denesting of Sqrt[a + b Sqrt[c]] > 0 *)
quadraticSquareRoots[{a_, b_, c_}] := Module[{d, s, u, v, e, out = {}},
   d = a^2 - b^2 c;
   If[d >= 0,
    s = Sqrt[d];
    If[rationalQ[s] && a > 0,
     u = (a + s)/2; v = (a - s)/2;
     If[u >= 0 && v >= 0, AppendTo[out, Sqrt[u] + Sign[b] Sqrt[v]]]]];
   (* indirect criterion: -c d must be a rational square *)
   If[d < 0 && b > 0,
    e = Sqrt[b^2 - a^2/c];
    If[rationalQ[e] && 0 <= e <= b,
     AppendTo[out, c^(1/4) (Sqrt[(b + e)/2] + Sign[a] Sqrt[(b - e)/2])]]];
   out];

(* real odd roots inside Q(Sqrt[c]): trace-norm criterion with the Dickson
   polynomials D_q(T, n) = u^q + v^q and S_q(T, n) = (u^q - v^q)/(u - v) for
   u + v = T, u v = n.  beta = A + B Sqrt[c] with beta^q = a + b Sqrt[c] exists
   in Q(Sqrt[c]) iff n^q = a^2 - b^2 c and D_q(T, n) = 2 a have rational
   solutions; then S_q(T, n) != 0 and beta = T/2 + b Sqrt[c]/S_q(T, n). *)
quadraticOddRoots[{a_, b_, c_}, q_Integer] := Module[{norm, n, d0 = 2, d1 = $x, s0 = 0, s1 = 1, dn, sn, roots, den, beta, out = {}},
   If[! OddQ[q] || q < 3 || q > $cfg["MaxOddIndex"], Return[{}]];
   norm = a^2 - b^2 c;
   n = Sign[norm] Abs[norm]^(1/q);
   If[! rationalQ[n], Return[{}]];
   Do[dn = Expand[$x d1 - n d0]; sn = Expand[$x s1 - n s0];
    {d0, d1} = {d1, dn}; {s0, s1} = {s1, sn}, {q - 1}];
   roots = rationalRoots[d1 - 2 a];
   Do[den = s1 /. $x -> t;
    If[den =!= 0, beta = t/2 + b Sqrt[c]/den;
     If[TrueQ[bounded[RootReduce[beta^q - (a + b Sqrt[c])] === 0, "Certificate"]], AppendTo[out, beta]]],
    {t, roots}];
   out];
cubicInQuadratic[parts_List] := quadraticOddRoots[parts, 3];

rationalRoots[p_] := Module[{fl},
   fl = bounded[FactorList[p]];
   If[fl === $Failed || ! ListQ[fl], Return[{}]];
   DeleteDuplicates[Select[Cases[fl, {f_, _Integer} /; PolynomialQ[f, $x] && Exponent[f, $x] === 1 :>
       -Coefficient[f, $x, 0]/Coefficient[f, $x, 1]], rationalQ]]];

(* Honsbeek: Sqrt[A + B] with A^3, B^3 nonzero rationals, A + B > 0 real *)
(* Honsbeek: Sqrt[A + B] where A^3 and B^3 are nonzero rationals (a rational
   summand counts as its own cube root); both signs are offered and a negative
   denominator gives complex candidates, the gate selects the principal one *)
honsbeekSquareRoots[rho_] := Module[{terms, a, b, ratio, roots, den, num, out = {}},
   If[Head[rho] =!= Plus || Length[rho] =!= 2, Return[{}]];
   terms = List @@ rho;
   (* each summand must be a rational or a real cube-root-like term such as
      28^(1/3) = 2^(2/3) 7^(1/3): depth one, radical indices dividing 3, cube rational *)
   If[! AllTrue[terms, RadicalDepth[#] <= 1 && FreeQ[#, Complex] && FreeQ[#, Power[_, r_Rational /; ! IntegerQ[3 r]]] &], Return[{}]];
   If[AllTrue[terms, rationalQ], Return[{}]];
   {a, b} = Replace[bounded[RootReduce[#^3], "Certificate"], $Failed -> Null] & /@ terms;
   If[! AllTrue[{a, b}, rationalQ] || a === 0 || b === 0, Return[{}]];
   ratio = b/a;
   roots = rationalRoots[$x^4 + 4 $x^3 + 8 ratio $x - 4 ratio];
   Do[den = b - s^3 a;
    If[den =!= 0,
     num = -s^2 terms[[1]]^2/2 + s terms[[1]] terms[[2]] + terms[[2]]^2;
     out = Join[out, {num/Sqrt[den], -num/Sqrt[den]}]],
    {s, roots}];
   out];

(* Sqrt of a rational combination of several square roots of integers.
   The candidate Sum[x_u Sqrt[u], u in U] is solved for rational x_u; the
   unknown sets U are (i) 1 and the primes of the radicands, (ii) also the
   radicands, and (iii) the cosets d H of the square-class group H generated by
   the radicands, d ranging over the classes generated by the primes of the
   radicands and of the coefficients (at most "MaxCosets" cosets).  By the
   single-coset theorem, a square root of rho that is a rational combination of
   square roots of integers has its support in one such coset. *)
squarefreeClass[n_Integer] := Module[{fl},
   fl = bounded[FactorInteger[Abs[n]]];
   If[fl === $Failed || ! ListQ[fl], Return[$Failed]];
   Times @@ (#[[1]]^Mod[#[[2]], 2] & /@ fl)];

(* the primes dividing any of the integers (signs and units ignored) *)
classPrimes[classes_List] := Module[{fl},
   fl = bounded[Union @@ (Select[First /@ FactorInteger[Abs[#]], PrimeQ] & /@ DeleteCases[classes, 0 | 1 | -1])];
   If[fl === $Failed || ! ListQ[fl], {}, fl]];

(* the coset unknown sets: each is a sorted list of squarefree integers *)
cosetBases[radicands_List, primes_List] := Module[{vec, classOf, hVectors, h, all, cosets = {}, seen = <||>, rep},
   If[primes === {} || Length[primes] > 10, Return[{}]];
   vec[n_] := Boole[Divisible[n, #]] & /@ primes;
   classOf[v_] := Times @@ MapThread[Power, {primes, v}];
   hVectors = {ConstantArray[0, Length[primes]]};
   Do[hVectors = Union[hVectors, Mod[# + vec[d], 2] & /@ hVectors], {d, radicands}];
   h = Sort[classOf /@ hVectors];
   all = Tuples[{0, 1}, Length[primes]];
   Do[If[Length[cosets] >= $cfg["MaxCosets"], limitHit["MaxCosets"]; Break[]];
    rep = Sort[classOf /@ (Mod[# + v, 2] & /@ hVectors)];
    If[! KeyExistsQ[seen, rep], AssociateTo[seen, rep -> True]; AppendTo[cosets, rep]],
    {v, all}];
   cosets];

(* solve (Sum[x_u Sqrt[u]])^2 == rho, rho given as class -> coefficient *)
surdSystem[u_List, coeffs_Association] := Module[{vars, cand, sq, basis, eqs, sol},
   If[u === {} || Length[u] > 16, Return[{}]];
   bump["CosetSystems"];
   vars = Table[Unique["RadicalDenest3`Private`coef"], {Length[u]}];
   cand = vars . Sqrt[u];
   sq = bounded[Expand[cand^2]];
   If[sq === $Failed, Return[{}]];
   basis = Union[Keys[coeffs], DeleteDuplicates[Cases[sq, Power[n_Integer, Rational[1, 2]] :> n, {0, Infinity}]]];
   eqs = Prepend[Table[Coefficient[sq, Sqrt[bb]] == Lookup[coeffs, bb, 0], {bb, DeleteCases[basis, 1]}],
     (sq /. Power[_Integer, Rational[1, 2]] -> 0) == Lookup[coeffs, 1, 0]];
   sol = bounded[Solve[eqs, vars, Rationals]];
   (* only fully rational solutions are candidates; Solve may return
      conditional or parametric solutions, which are not *)
   If[! ListQ[sol], Return[{}]];
   sol = Select[sol, ListQ[#] && AllTrue[#, MatchQ[#, _Rule] && rationalQ[Last[#]] &] && Length[#] === Length[vars] &];
   DeleteDuplicates[(cand /. #) & /@ sol]];

(* integer-relation proposal for one unknown set: an integer vector
   (n0, n_u) with n0 Sqrt[rho] + Sum[n_u Sqrt[u]] = 0 gives the candidate
   -Sum[n_u Sqrt[u]]/n0; it is proposed only when its square reduces to rho,
   so a spurious relation costs one RootReduce and nothing else *)
surdRelation[u_List, rho_] := Module[{sign, vec, rel, cand},
   If[u === {} || Length[u] > 32, Return[{}]];
   (* Sign[] of a sum with negative terms can stay unevaluated; the comparisons decide numerically *)
   sign = Which[TrueQ[bounded[rho > 0, "Certificate"]], 1, TrueQ[bounded[rho < 0, "Certificate"]], -1, True, 0];
   If[sign === 0, Return[{}]];
   vec = bounded[N[Prepend[Sqrt[u], Sqrt[sign rho]], 80 + 10 Length[u]]];
   If[! ListQ[vec] || ! AllTrue[vec, NumberQ], Return[{}]];
   rel = bounded[FindIntegerNullVector[vec]];
   If[! ListQ[rel] || ! AllTrue[rel, IntegerQ] || First[rel] === 0, Return[{}]];
   cand = -(Rest[rel] . Sqrt[u])/First[rel];
   If[sign === -1, cand = I cand];
   If[TrueQ[bounded[RootReduce[cand^2 - rho], "Certificate"] === 0], {cand, -cand}, {}]];

(* a summand c Sqrt[r] with rational c and r > 0 as {squarefree radicand, coefficient};
   the kernel writes Sqrt[6]/2 as Sqrt[3/2], which is Sqrt[6] with coefficient 1/2 *)
surdTerm[t_] := Which[
   rationalQ[t], {1, t},
   MatchQ[t, Power[_Integer | _Rational, Rational[1, 2]]], surdTerm[{1, t}],
   MatchQ[t, Times[_?rationalQ, Power[_Integer | _Rational, Rational[1, 2]]]], surdTerm[{t[[1]], t[[2]]}],
   MatchQ[t, {_?rationalQ, Power[_Integer | _Rational, Rational[1, 2]]}],
    If[t[[2, 1]] <= 0, $Failed,
     {Numerator[t[[2, 1]]] Denominator[t[[2, 1]]], t[[1]]/Denominator[t[[2, 1]]]}],
   True, $Failed];

multiSurdSquareRoots[rho_] := Module[{e, terms, parsed, surds, coeffs, primes, extra, cosets, sets, out = {}},
   e = bounded[Expand[rho]];
   If[e === $Failed, Return[{}]];
   terms = If[Head[e] === Plus, List @@ e, {e}];
   parsed = surdTerm /@ terms;
   If[MemberQ[parsed, $Failed], Return[{}]];
   coeffs = Merge[Rule @@@ parsed, Total];
   surds = Select[Keys[coeffs], # > 1 &];
   If[Length[surds] < 2 || Length[surds] > 15, Return[{}]];
   primes = classPrimes[surds];
   If[primes === {}, Return[{}]];
   (* the two cheap unknown sets first, then the cosets of the square-class
      group of the radicands over the primes of the radicands and of the
      coefficients; the first system with a rational solution wins *)
   extra = classPrimes[Flatten[{Numerator[#], Denominator[#]} & /@ Select[Values[coeffs], rationalQ]]];
   cosets = cosetBases[surds, Union[primes, extra]];
   (* stage 1: certified integer-relation proposals, one per coset *)
   Do[If[expiredQ[], Break[]];
    out = surdRelation[U, e];
    If[out =!= {}, Break[]],
    {U, cosets}];
   If[out =!= {}, Return[out]];
   (* stage 2: the rational systems *)
   sets = DeleteDuplicates[Join[{Union[{1}, primes], Union[{1}, primes, surds]}, cosets]];
   Do[If[expiredQ[], Break[]];
    out = surdSystem[U, coeffs];
    If[out =!= {}, Break[]],
    {U, sets}];
   out];

(* Gaussian square root: Sqrt[a + b I] with a^2 + b^2 a rational square *)
gaussianSquareRoots[z_] := Module[{a = Re[z], b = Im[z], n},
   n = Sqrt[a^2 + b^2];
   If[rationalQ[n], {Sqrt[(n + a)/2] + I Sign[b] Sqrt[(n - a)/2]}, {}]];

(* roots of unity as rational powers of -1 *)
unity[k_Integer, q_Integer] := (-1)^(Mod[2 k, 2 q]/q);

(* candidates for rho^(1/q), rho exact, produced by the shape-specific recipes *)
rootCandidates[rho_, q_Integer] := Module[{parts, out = {}, sign = 1, r = rho, neg},
   If[q === 2 && Head[rho] === Complex, Return[gaussianSquareRoots[rho]]];
   neg = TrueQ[bounded[rho < 0, "Certificate"]];
   If[neg, r = -rho];
   Which[
    q === 2,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticSquareRoots[parts]];
     out = Join[out, honsbeekSquareRoots[r], multiSurdSquareRoots[r]];
     If[neg, out = I out],
    OddQ[q] && q >= 3 && q <= $cfg["MaxOddIndex"],
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticOddRoots[parts, q]];
     If[neg, out = (-1)^(1/q) out]];
   out];

(* ------------------------------------------------------------------ *)
(* Kummer-linear factors and index reduction                          *)
(* ------------------------------------------------------------------ *)

(* the radicals (and I) occurring in an expression, as an explicit Extension
   specification: factoring over them keeps roots in radical presentation,
   whereas Extension -> Automatic may canonicalize them into Root objects *)
radicalExtension[e_] := Module[{ext = DeleteDuplicates[Cases[e, Power[_, _Rational], {0, Infinity}]]},
   If[! FreeQ[e, Complex], ext = Prepend[ext, I]];
   If[ext === {}, Automatic, ext]];

(* radical presentations of an algebraic number given with Root objects *)
radicalForms[z_] := Module[{out = {z}, r},
   If[FreeQ[z, _Root | _AlgebraicNumber], Return[out]];
   r = bounded[ToRadicals[z]];
   If[r =!= $Failed, AppendTo[out, r]];
   r = bounded[RootReduce[z], "Certificate"];
   If[r =!= $Failed, r = bounded[ToRadicals[r]]; If[r =!= $Failed, AppendTo[out, r]]];
   DeleteDuplicates[Select[out, exactQ]]];

(* roots gamma of x^k == rho lying in the field generated by the radicals of rho *)
linearRoots[rho_, k_Integer] := Module[{fl, roots},
   fl = bounded[FactorList[$x^k - rho, Extension -> radicalExtension[rho]]];
   If[fl === $Failed || ! ListQ[fl],
    fl = bounded[FactorList[$x^k - rho, Extension -> Automatic]]];
   If[fl === $Failed || ! ListQ[fl], Return[{}]];
   roots = Cases[fl, {f_, _Integer} /; PolynomialQ[f, $x] && Exponent[f, $x] === 1 :>
      bounded[Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]]];
   DeleteDuplicates[Select[Flatten[radicalForms /@ DeleteCases[roots, $Failed]], exactQ]]];

(* denest a sub-problem recursively under the shared budget *)
recurse[sub_] := If[$recursion >= $cfg["MaxRecursion"] || expiredQ[], sub,
   Block[{$recursion = $recursion + 1, $cfg = Append[$cfg, "MaxTrials" -> Quotient[$cfg["MaxTrials"], 4]]},
    improveNumber[sub]]];

(* candidates for target == rho^(p/q) from linear factors of x^k - rho, k | q.
   Every stage receives the incumbent and returns it unchanged when it finds
   nothing; the reduced presentation gamma^(1/(q/k)) is offered on its own
   before any recursion, so an index reduction that is already cheaper does
   not depend on recursive progress. *)
kummerCandidates[target_, rho_, p_Integer, q_Integer, incumbent_: Automatic] :=
  Module[{best = If[incumbent === Automatic, target, incumbent], gammas, k, rest, sub, dens, reduced},
   Do[
    If[expiredQ[], Break[]];
    gammas = linearRoots[rho, k];
    rest = q/k;
    If[rest === 1,
     Do[best = acceptWithPolish[bounded[Expand[(gamma unity[l, q])^p]], target, best, "LinearFactor"], {gamma, gammas}, {l, 0, q - 1}],
     (* rho = gamma^k, so target = (gamma zeta_k^j)^(p/rest) zeta_rest^l for some j, l;
        the distinct values gamma zeta_k^j are each processed once *)
     dens = DeleteDuplicates[DeleteCases[Flatten[Table[bounded[Expand[gamma unity[j, k]]], {gamma, gammas}, {j, 0, k - 1}]], $Failed]];
     Do[
      If[expiredQ[], Break[]];
      reduced = den^(1/rest);
      Do[best = acceptWithPolish[bounded[Expand[(reduced unity[l, rest])^p]], target, best, "IndexReduction"], {l, 0, rest - 1}];
      sub = recurse[reduced];
      If[sub =!= reduced && exactQ[sub],
       Do[best = acceptWithPolish[bounded[Expand[(sub unity[l, rest])^p]], target, best, "IndexReduction/Recursive"], {l, 0, rest - 1}]],
      {den, dens}]];
    If[RadicalDepth[best] <= 1, Break[]],
    {k, Reverse[Rest[Divisors[q]]]}];
   best];

(* negative real radicand: rho^(p/q) = (-1)^(p/q) (-rho)^(p/q); the modulus is
   denested recursively and the phase-separated candidate is offered whether
   or not the recursion changed the modulus *)
negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer, incumbent_: Automatic] :=
  Module[{best = If[incumbent === Automatic, target, incumbent], sub},
   If[! TrueQ[bounded[rho < 0, "Certificate"]], Return[best]];
   sub = recurse[(-rho)^(p/q)];
   acceptWithPolish[bounded[Expand[(-1)^(p/q) sub]], target, best, "NegativeRadicand"]];

(* ------------------------------------------------------------------ *)
(* the multiplier search (bounded FIFO queue, single admission gate)  *)
(* ------------------------------------------------------------------ *)

reductionIndex[e_] := Module[{d = RadicalDepth[e], nodes, q = 1},
   nodes = Select[Cases[e, Power[_, _Rational], {0, Infinity}], RadicalDepth[#] === d &];
   Do[q = LCM[q, Denominator[Last[node]]];
    If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[$Failed]], {node, nodes}];
   If[q < 2, $Failed, q]];

complementaryFactor[Power[b_, r_Rational]] := b^(Mod[-Numerator[r], Denominator[r]]/Denominator[r]);
complementaryFactor[Complex[0, _]] := -I;
complementaryFactor[e_] := Module[{deep = Cases[e, Power[_, _Rational], {0, Infinity}], maxd},
   If[deep === {}, 1, maxd = Max[RadicalDepth /@ deep];
    Times @@ (complementaryFactor /@ Select[deep, RadicalDepth[#] == maxd &])]];
complementaryMultiplier[term_] := Times @@ (complementaryFactor /@ If[Head[term] === Times, List @@ term, {term}]);

multiplierSearch[target_, initialBest_] := Module[
   {best = initialBest, q, rho, queue = {}, seen = <||>, admitted = 0, proposed = 0, cursor = 1,
    cap = $cfg["MultiplierCap"], proposalCap, admit, seeds, terms, m, theta, p, degree, gcd, gd, roots,
    mroot, candidate, disc, primes, j, digits, batch, sol, trials = 0, sinceImprovement = 0, bestDegree = Infinity},
   If[cap === 0 || $cfg["MaxTrials"] === 0 || expiredQ[], Return[best]];
   q = reductionIndex[target]; If[q === $Failed, Return[best]];
   rho = bounded[Expand[target^q]]; If[rho === $Failed || ! exactQ[rho], Return[best]];
   proposalCap = 4 cap;
   (* the only insertion point: caps admissions, counts proposals, dedups by exact canonical value *)
   admit[value_] := Module[{canonical, key},
     If[admitted >= cap, limitHit["MultiplierCap"]; Return[False]];
     If[proposed >= proposalCap, limitHit["MultiplierProposals"]; Return[False]];
     proposed++; bump["MultipliersProposed"];
     If[! exactQ[value] || ! smallQ[value], Return[False]];
     (* the key is the expanded form: algebraically equal multipliers written
        differently are rare among products of primes and visible radicals, and a
        RootReduce per proposal would dominate the cost of a trial *)
     canonical = bounded[Expand[value]];
     If[canonical === $Failed || TrueQ[canonical == 0], Return[False]];
     key = ToString[canonical, InputForm];
     If[KeyExistsQ[seen, key], bump["DuplicateMultipliers"]; Return[False]];
     AssociateTo[seen, key -> True]; AppendTo[queue, value];
     admitted++; bump["MultipliersAdmitted"]; True];
   If[ListQ[$cfg["Multipliers"]],
    seeds = $cfg["Multipliers"],
    terms = DeleteCases[Replace[#, {Times[a___, _?rationalQ, b___] :> a*b, _?rationalQ -> 0, Complex[a_, b_] :> Sign[b] I}] & /@
        If[Head[rho] === Plus, List @@ rho, {rho}], 0];
    seeds = Join[{1}, DeleteCases[complementaryMultiplier /@ terms, 1], {2, 3, 5}]];
   Do[If[admitted >= cap || proposed >= proposalCap || expiredQ[], Break[]]; admit[seed], {seed, seeds}];
   While[cursor <= Length[queue] && ! expiredQ[],
    (* "MaxTrials" bounds the trials spent on this island; "Patience" stops the
       search when an improvement exists (found by an earlier stage or by this
       search) and the last "Patience" trials did not improve on it *)
    If[trials >= $cfg["MaxTrials"], limitHit["MaxTrials"]; Break[]];
    If[best =!= target && sinceImprovement >= $cfg["Patience"], limitHit["Patience"]; Break[]];
    m = queue[[cursor]]; cursor++; trials++; sinceImprovement++; bump["Trials"];
    (* the multiplied radicand keeps its radical presentation: the GCD roots then
       come out in the radicals of rho, not as opaque algebraic numbers *)
    theta = bounded[Expand[m rho]];
    If[theta === $Failed, Continue[]];
    p = bounded[MinimalPolynomial[theta^(1/q), $x]];
    If[! validPolynomialQ[p, $x], If[p =!= $Failed, limitHit["MaxDegree"]]; Continue[]];
    degree = Exponent[p, $x];
    log["multiplier ", m, "  minpoly degree ", degree];
    bestDegree = Min[bestDegree, degree];
    trace["Trial", <|"Multiplier" -> m, "Degree" -> degree, "Index" -> q|>];
    (* roots of x^q == m rho: linear factors over the radicals of the radicand, then the
       proper GCD factor with the minimal polynomial of the principal root *)
    roots = If[m === 1, {}, linearRoots[theta, q]];
    gcd = bounded[PolynomialGCD[p, $x^q - theta, Extension -> Automatic]];
    If[validPolynomialQ[gcd, $x],
     gd = Exponent[gcd, $x];
     If[gd < q,
      roots = Join[roots, Which[
         gd === 1, {-Coefficient[gcd, $x, 0]/Coefficient[gcd, $x, 1]},
         gd <= $cfg["MaxSolveDegree"],
          sol = bounded[Solve[gcd == 0, $x]];
          If[ListQ[sol], Select[$x /. sol, exactQ], {}],
         True, {}]]]];
    roots = DeleteDuplicates[Select[Flatten[radicalForms /@ roots], exactQ]];
    If[roots =!= {},
     Module[{},
      mroot = bounded[m^(1/q)];
      If[mroot =!= $Failed,
       Do[If[expiredQ[], Break[]];
        Do[If[expiredQ[], Break[]];
         candidate = bounded[Expand[z/mroot unity[k, q]]];
         Module[{before = best},
          best = acceptWithPolish[candidate, target, best, "MultiplierOrbit"];
          If[best =!= before, sinceImprovement = 0]];
         (* a certified but not cheaper candidate (e.g. gamma^(1/3) with gamma in Q(rho))
            may itself be denestable: try it recursively *)
         If[candidate =!= $Failed && RadicalDepth[candidate] <= RadicalDepth[target] && candidate =!= target &&
           certify[candidate, target] === "Equal",
          Module[{before = best},
           best = acceptWithPolish[recurse[candidate], target, best, "MultiplierOrbit/Recursive"];
           If[best =!= before, sinceImprovement = 0]]],
         {k, 0, q - 1}],
        {z, roots}]]]];
    If[RadicalDepth[best] <= 1, Break[]];
    (* discriminant primes of a promising trial (smallest degree seen so far): stream
       prime powers and a bounded prefix of mixed-radix products *)
    If[! ListQ[$cfg["Multipliers"]] && degree <= bestDegree && admitted < cap && proposed < proposalCap && ! expiredQ[],
     disc = bounded[Discriminant[p, $x]];
     If[IntegerQ[disc] && disc =!= 0,
      primes = bounded[Take[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], UpTo[8]]];
      If[! ListQ[primes], primes = {}];
      batch = 0;
      Do[If[admitted >= cap || proposed >= proposalCap || batch >= $cfg["DiscriminantBatchCap"] || expiredQ[], Break[]];
       Do[If[admitted >= cap || proposed >= proposalCap || batch >= $cfg["DiscriminantBatchCap"] || expiredQ[], Break[]];
        batch++; admit[m prime^e], {e, 1, q - 1}], {prime, primes}];
      j = 1;
      While[primes =!= {} && j < q^Length[primes] && batch < $cfg["DiscriminantBatchCap"] && admitted < cap && proposed < proposalCap && ! expiredQ[],
       digits = IntegerDigits[j, q, Length[primes]]; j++; batch++;
       admit[m Times @@ MapThread[Power, {primes, digits}]]]]]];
   If[admitted >= cap, limitHit["MultiplierCap"]];
   If[trials >= $cfg["MaxTrials"], limitHit["MaxTrials"]];
   best];

(* ------------------------------------------------------------------ *)
(* one exact algebraic island                                         *)
(* ------------------------------------------------------------------ *)

(* whole-island proposals that do not depend on the shape *)
genericProposals[target_, incumbent_] := Module[{best = incumbent, r, mp, solver},
   solver = $cfg["Solver"];
   If[solver =!= Automatic,
    r = bounded[Catch[Catch[solver[target], _, $Failed &]]];
    best = acceptWithPolish[r, target, best, "Solver"]];
   If[! FreeQ[target, _Root | _AlgebraicNumber],
    r = bounded[ToRadicals[target]];
    If[r =!= $Failed && r =!= target, best = acceptWithPolish[recurse[r], target, best, "ToRadicals"]]];
   r = bounded[RootReduce[target], "Certificate"];
   If[r =!= $Failed,
    best = accept[r, target, best, "RootReduce"];
    If[opaqueQ[r] && Head[r] === Root && PolynomialQ[First[r][$x], $x] && Exponent[First[r][$x], $x] <= 4,
     best = acceptWithPolish[bounded[ToRadicals[r]], target, best, "RootReduce/ToRadicals"]]];
   best = accept[bounded[Simplify[target, Assumptions -> True, TimeConstraint -> 5]], target, best, "Simplify"];
   If[TrueQ[$cfg["Factor"]], best = accept[bounded[Factor[target]], target, best, "Factor"]];
   best = accept[rationalizeRaw[target], target, best, "Rationalize"];
   best];

(* fast paths for a single rational-power node; every stage receives and
   returns the incumbent *)
powerProposals[target_, incumbent_] := Module[{best = incumbent, rho, p, q, root, cands, before},
   If[! MatchQ[target, Power[_, _Rational]], Return[best]];
   rho = First[target]; p = Numerator[Last[target]]; q = Denominator[Last[target]];
   If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[best]];
   (* shape-specific recipes for the q-th root, then the integer power p *)
   before = best;
   cands = bounded[rootCandidates[rho, q]];
   If[! ListQ[cands], cands = {}];
   Do[best = acceptWithPolish[bounded[Expand[c^p]], target, best, "FastPath"], {c, cands}];
   If[best =!= before, bump["FastPathAccepted"]];
   If[RadicalDepth[best] <= 1, Return[best]];
   (* negative real radicand: separate the phase, denest the modulus *)
   best = negativeRadicandCandidate[target, rho, p, q, best];
   If[RadicalDepth[best] <= 1, Return[best]];
   (* roots of rho inside Q(rho), and index reduction through divisors of q *)
   best = kummerCandidates[target, rho, p, q, best];
   (* an even index: the square root first, then the remaining index *)
   If[RadicalDepth[best] >= 2 && EvenQ[q] && q > 2,
    root = recurse[rho^(1/2)];
    If[root =!= rho^(1/2) && exactQ[root],
     best = acceptWithPolish[bounded[Expand[(root^(2/q))^p]], target, best, "EvenIndexSplit"];
     root = recurse[root^(2/q)];
     best = acceptWithPolish[bounded[Expand[root^p]], target, best, "EvenIndexSplit/Recursive"]]];
   best];

(* the multiplier search is meant for a radical node or a product of radical
   nodes; a sum island gets the whole-island proposals only *)
searchableQ[e_] := MatchQ[e, Power[_, _Rational]] ||
   (Head[e] === Times && AllTrue[List @@ e, MatchQ[#, _?gaussianQ | Power[_, _Rational]] &]);

(* results for one island are memoized within the session: the same sub-problem
   recurs through roots of unity, index reduction and repeated passes *)
(* The memo records, for every island visited, the best certified result and
   the budget of the search that produced it (the multiplier trials and the
   recursion levels that were available, and whether the search completed
   inside the time budget).  A memoized improvement is reused as the incumbent
   of a later visit.  A memoized negative result is reused only when the
   earlier search had at least the budget of the current one and completed;
   otherwise the island is searched again, so a weak recursive search never
   poisons a later top-level search.  Islands on the current recursion path are
   not re-entered. *)
memoBudget[] := {$cfg["MaxTrials"], $cfg["MaxRecursion"] - $recursion};
improveNumber[target_] := Module[{best = target, entry},
   If[expiredQ[] || ! smallQ[target] || ! exactQ[target], Return[target]];
   If[RadicalDepth[target] < 2 && FreeQ[target, _Root | _AlgebraicNumber], Return[target]];
   If[KeyExistsQ[$memo, target],
    entry = $memo[target]; best = entry["Result"];
    If[entry["Complete"] && And @@ Thread[entry["Budget"] >= memoBudget[]], Return[best]]];
   If[KeyExistsQ[$inProgress, target], Return[best]];
   bump["Islands"];
   Block[{$inProgress = Append[$inProgress, target -> True]},
    best = powerProposals[target, best];
    If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber], best = genericProposals[target, best]];
    If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic && searchableQ[target] && ! expiredQ[],
     best = multiplierSearch[target, best]]];
   AssociateTo[$memo, target -> <|"Result" -> best, "Budget" -> memoBudget[], "Complete" -> ! expiredQ[]|>];
   best];

(* an exact algebraic island: children first (all levels) or outermost
   radical nodes first (default), then the island as a whole *)
(* recombination of an island whose components were rewritten: the proposals
   are computed from the rewritten form but certified against the original *)
combineProposals[target_, incumbent_] := Module[{best = incumbent, r},
   r = bounded[RootReduce[incumbent], "Certificate"];
   best = accept[r, target, best, "Combine/RootReduce"];
   best = accept[bounded[Simplify[incumbent, Assumptions -> True, TimeConstraint -> 5]], target, best, "Combine/Simplify"];
   best = accept[bounded[Together[incumbent]], target, best, "Combine/Together"];
   best = accept[bounded[Expand[incumbent]], target, best, "Combine/Expand"];
   best];

island[e_] := Module[{current = e, rebuilt},
   If[expiredQ[], Return[e]];
   If[RadicalDepth[e] < 2 && FreeQ[e, _Root | _AlgebraicNumber], Return[e]];
   If[MatchQ[e, Power[_, _Rational]],
    If[TrueQ[$cfg["AllLevels"]],
     (* the radicand is an island of its own; congruence carries its certificate *)
     rebuilt = Power[island[First[e]], Last[e]];
     If[rebuilt =!= e && cheaperQ[rebuilt, e], current = rebuilt]];
    Return[improveNumber[current]]];
   If[MemberQ[{Plus, Times}, Head[e]] || MatchQ[e, Power[_, _Integer]],
    (* components first: each component certified against itself *)
    rebuilt = If[Head[e] === Power, Power[island[First[e]], Last[e]], Map[island, e]];
    If[rebuilt =!= e && cheaperQ[rebuilt, e], current = rebuilt];
    If[RadicalDepth[current] >= 2 || ! FreeQ[current, _Root | _AlgebraicNumber],
     rebuilt = improveNumber[current];
     If[rebuilt =!= current, current = rebuilt]];
    If[current =!= e, current = combineProposals[e, current]];
    Return[current]];
   If[opaqueQ[e], Return[improveNumber[e]]];
   e];

(* ------------------------------------------------------------------ *)
(* host traversal by congruence                                       *)
(* ------------------------------------------------------------------ *)

walk[e_] := Module[{h},
   If[expiredQ[], Return[e]];
   If[exactQ[e], Return[island[e]]];
   If[AtomQ[e], Return[e]];
   h = Head[e];
   Which[
    MemberQ[{List, Plus, Times}, h], Map[walk, e],
    h === Power && Length[e] === 2 && MatchQ[Last[e], _Integer | _Rational], Power[walk[First[e]], Last[e]],
    True, e]];

(* ------------------------------------------------------------------ *)
(* the session                                                        *)
(* ------------------------------------------------------------------ *)

run[e_, cfg_Association, coreOnly_: False] :=
  Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + cfg["TimeBudget"],
    $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>, $inProgress = <||>,
    $recursion = 0, $lastCertificateMethod = "None", $Assumptions = True},
   Module[{committed = {e, Missing["NotComputed"]}, initialCost = Missing["NotComputed"], candidate, candidateCost,
     outcome = Null, started = AbsoluteTime[], passes, status, numericInput = False},
    passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
    If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
     (* the classification of the input and every cost computation are inside the region *)
     outcome = TimeConstrained[
       MemoryConstrained[
        Which[
         ! FreeQ[e, _Real | _Complex?InexactNumberQ], limitHit["InexactInput"],
         coreOnly && ! exactQ[e], limitHit["NotExactAlgebraic"],
         True,
         numericInput = exactQ[e];
         initialCost = RadicalCost[e]; committed = {e, initialCost};
         Do[
          If[expiredQ[], Break[]];
          candidate = If[coreOnly, improveNumber[First[committed]], walk[First[committed]]];
          bump["PassesCompleted"];
          If[candidate === First[committed], Break[]];
          candidateCost = RadicalCost[candidate];
          If[Order[candidateCost, Last[committed]] =!= 1, Break[]];
          (* whole-input certificate when the whole input is a number; hosts rely on congruence *)
          If[numericInput && certify[candidate, e] =!= "Equal", Break[]];
          (* the pass and its cost are published together *)
          committed = {candidate, candidateCost};
          If[pass === passes && passes > 1, limitHit["MaxPasses"]],
          {pass, passes}]],
        cfg["MemoryBudget"], memoryStopped],
       cfg["TimeBudget"], timeStopped];
     If[outcome === memoryStopped, limitHit["MemoryBudget"]];
     If[outcome === timeStopped, limitHit["TimeBudget"]]];
    status = Which[
      outcome === timeStopped, "Timeout",
      outcome === memoryStopped, "MemoryLimit",
      TrueQ[cfg["TimeBudget"] == 0], "Disabled",
      First[committed] === e, "Unchanged",
      True, "Improved"];
    <|"Result" -> First[committed], "Status" -> status, "ResultChanged" -> (First[committed] =!= e),
     "Limits" -> Keys[$limits],
     "InitialCost" -> initialCost, "FinalCost" -> Last[committed],
     "Statistics" -> $stats, "Certificates" -> $records,
     "CertificateKind" -> "Kernel-checked accepted proposals (Before, After, Method, EqualityMethod); a bounded sample, not a proof chain of the final result",
     "CertificatesTruncated" -> (Lookup[$stats, "CandidatesAccepted", 0] > Length[$records]),
     "LimitsMeaning" -> "Guards that were triggered or caps that were reached; not impossibility certificates",
     "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg,
     "Trace" -> $trace, "CompletenessClaim" -> False|>]];

invoke[e_, head_Symbol, rules_List, report_, core_] := Module[{cfg, result},
   cfg = resolveOptions[head, rules];
   If[FailureQ[cfg], Return[cfg]];
   result = run[e, cfg, core];
   If[TrueQ[report], result, result["Result"]]];

(* every argument sequence reaches the option validator, so a malformed call
   such as Strad[e, 17] returns a Failure instead of staying unevaluated *)
Strad[e_, all : (True | False), args___] := invoke[e, Strad, {"AllLevels" -> all, args}, False, False];
Strad[e_, args___] := invoke[e, Strad, {args}, False, False];
DenestRadicals[e_, all : (True | False), args___] := invoke[e, DenestRadicals, {"AllLevels" -> all, args}, False, False];
DenestRadicals[e_, args___] := invoke[e, DenestRadicals, {args}, False, False];
DenestCore[e_, args___] := invoke[e, DenestCore, {args}, False, True];
DenestReport[e_, all : (True | False), args___] := invoke[e, DenestReport, {"AllLevels" -> all, args}, True, False];
DenestReport[e_, args___] := invoke[e, DenestReport, {args}, True, False];
Strad[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestRadicals[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestCore[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestReport[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];

End[];
EndPackage[];
