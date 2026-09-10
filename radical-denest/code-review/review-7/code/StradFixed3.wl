(* ::Package:: *)

(* StradFixed3.wl -- proposed, NOT native-kernel-validated revision.
   Derived from RadicalDenest StradFixed2.wl at commit
   9000d6f533a68ee7659a6830ad25bba401f800a5, Git blob
   0bdeded347385a55a044fdd35883006d053685dc.  See the accompanying audit.

   Scope: evaluated, pure arithmetic expressions with principal complex powers.
   Exact input grammar accepts rational/Gaussian rational constants, rational
   powers and arithmetic combinations, canonical rational-polynomial Root
   objects, and AlgebraicNumber objects with admitted generators and rational
   coefficient lists. Other Root presentations are conservatively unsupported;
   apply RootReduce separately to known algebraic objects when necessary.

   Candidates must be smaller and certified by exact algebra. Numerical hints
   NEVER decide equality or inequality. Local congruence rewrites are committed
   only if the complete pass is cheaper. The search, input classification and
   cost construction share a time/memory region. Ordinary argument evaluation,
   option evaluation and final report assembly are outside that search budget.
   Kernel constraints are cooperative limits, not an OS sandbox or hard-real-time
   guarantees. MaxTrials bounds each multiplier-search visit, not the session.
   User functions/upvalues must be trusted, side-effect-free arithmetic code.

   No completeness, optimality, or performance improvement is asserted.
   Context RadicalDenest3` permits side-by-side testing with RadicalDenest2`.
   Distributed under the repository's MIT No Attribution License. *)

BeginPackage["RadicalDenest3`"];

Strad::usage = "Strad[expr, opts] denests the exact algebraic radicals occurring in expr and returns an expression certified equal to expr. Strad[expr, True, opts] also processes inner nesting levels and repeats passes while they improve the result.";
DenestRadicals::usage = "DenestRadicals[expr, opts] is the option-driven form of Strad with its own option defaults.";
DenestCore::usage = "DenestCore[problem, opts] denests one exact algebraic number without traversing a symbolic host.";
DenestReport::usage = "DenestReport[expr, opts] returns an Association with the result (\"Result\"), \"Status\", \"Limits\", \"Statistics\", \"Certificates\", \"ElapsedSeconds\", \"Options\" and an optional bounded \"Trace\".";
EqualityStatus::usage = "EqualityStatus[a, b] is \"Equal\", \"Different\" or \"Unknown\" for exact algebraic numbers a and b, decided by exact algebra within a time limit.";
CertifiedEqualQ::usage = "CertifiedEqualQ[a, b] is True only when EqualityStatus[a, b] is \"Equal\".";
ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] recognizes the conservative exact algebraic input grammar: rationals, Gaussian rationals, canonical rational-polynomial Root objects, AlgebraicNumber objects with admitted generators and rational coefficients, and arithmetic/rational powers. False also means unsupported or a validation timeout.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] is True when e is an explicit radical expression: rationals, Gaussian rationals and Plus, Times and rational Power combinations of them. Root and AlgebraicNumber objects are not radical expressions.";
RadicalDepth::usage = "RadicalDepth[e] is the maximal number of nested rational-power nodes on a path of e. Root and AlgebraicNumber objects are opaque and count as depth 0.";
RadicalCost::usage = "RadicalCost[e] is the lexicographic cost {#Root and AlgebraicNumber objects, radical depth, #rational-power nodes, LeafCount, total bit size of integer and rational atoms, including Gaussian components} used to decide whether a rewrite is an improvement.";
RationalizeDenominator::usage = "RationalizeDenominator[expr] rewrites expr with a rational denominator using a certified polynomial inverse of the exact algebraic denominator. It need not reduce RadicalCost.";
Factorc::usage = "Factorc[expr] offers Factor of an exact algebraic expr as a certified proposal and returns it only when it is certified equal and cheaper. Symbolic input is returned unchanged.";

Options[Strad] = {
   "AllLevels" -> False, "Verbose" -> False, "Trace" -> False,
   "Multipliers" -> Automatic, "Solver" -> Automatic, "Factor" -> True,
   "MaxTrials" -> 120, "TimeBudget" -> 120, "OperationTime" -> 30,
   "CertifyTime" -> 20, "MemoryBudget" -> 1073741824,
   "MultiplierCap" -> 1000, "MaxRootIndex" -> 32, "MaxDegree" -> 64,
   "MaxSolveDegree" -> 4, "MaxLeafCount" -> 20000, "MaxPasses" -> 4,
   "MaxRecursion" -> 3, "Patience" -> 25, "NumericPrefilter" -> False, "MaxTraceEntries" -> 200};
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
$stats = <||>; $limits = <||>; $trace = {}; $records = {}; $memo = <||>;
$recursion = 0; $inProgress = {};
$x = Unique["RadicalDenest3`Private`x"];

newStats[] := <|"Islands" -> 0, "Trials" -> 0, "Operations" -> 0,
   "OperationTimeouts" -> 0, "OperationFailures" -> 0,
   "Certificates" -> 0, "CertificatesEqual" -> 0, "CertificatesDifferent" -> 0,
   "CertificatesUnknown" -> 0, "NumericRejections" -> 0, "NumericHints" -> 0,
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
     Select[{"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience"}, ! nonnegativeIntegerQ[cfg[#]] &],
     Select[{"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount", "MaxPasses"}, ! positiveIntegerQ[cfg[#]] &],
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

algebraicFormQ[e_] := Which[
   gaussianQ[e], True,
   Head[e] === Root, canonicalRootPolynomial[e] =!= $Failed,
   Head[e] === AlgebraicNumber,
    Length[e] === 2 && ListQ[e[[2]]] && AllTrue[e[[2]], rationalQ] &&
      algebraicFormQ[e[[1]]],
   AtomQ[e], False,
   MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, algebraicFormQ],
   Head[e] === Power && Length[e] === 2, rationalQ[e[[2]]] && algebraicFormQ[e[[1]]],
   True, False];

(* Root is NOT algebraic by its head alone. Only a rational polynomial
   together with a valid numerical root selector is admitted here. *)
canonicalRootPolynomial[e_] := Module[{p, degree, args},
   If[Head[e] =!= Root, Return[$Failed]];
   args = List @@ e;
   If[! MemberQ[{2, 3}, Length[args]] || Head[args[[1]]] =!= Function ||
     ! positiveIntegerQ[args[[2]]], Return[$Failed]];
   If[Length[args] === 3 && ! MemberQ[{0, 1}, args[[3]]], Return[$Failed]];
   p = bounded[Expand[args[[1]][$x]]];
   If[p === $Failed || ! TrueQ[PolynomialQ[p, $x]], Return[$Failed]];
   degree = Exponent[p, $x];
   If[! positiveIntegerQ[degree] || args[[2]] > degree ||
      ! AllTrue[CoefficientList[p, $x], rationalQ], Return[$Failed]];
   p];

ExactAlgebraicQ[e_] := standalone[
   algebraicFormQ[e] && FreeQ[e, Indeterminate | ComplexInfinity | _DirectedInfinity], False];
exactQ[e_] := ExactAlgebraicQ[e];

RadicalDepth[e_] := Which[
   AtomQ[e] || opaqueQ[e], 0,
   MatchQ[e, Power[_, _Rational]], 1 + RadicalDepth[First[e]],
   True, Max[Prepend[RadicalDepth /@ (List @@ e), 0]]];

(* Stop at opaque objects once; do not subtract overlapping payload counts. *)
radicalNodes[e_] := Which[
   opaqueQ[e] || AtomQ[e], 0,
   True, Boole[MatchQ[e, Power[_, _Rational]]] + Total[radicalNodes /@ (List @@ e)]];
opaqueNodes[e_] := Which[opaqueQ[e], 1, AtomQ[e], 0,
   True, Total[opaqueNodes /@ (List @@ e)]];
bitSize[e_] := Which[
   IntegerQ[e], 1 + IntegerLength[Abs[e], 2],
   Head[e] === Rational, 2 + IntegerLength[Abs[Numerator[e]], 2] + IntegerLength[Denominator[e], 2],
   Head[e] === Complex, bitSize[Re[e]] + bitSize[Im[e]],
   AtomQ[e], 0,
   True, Total[bitSize /@ (List @@ e)]];
RadicalCost[e_] := {opaqueNodes[e], RadicalDepth[e], radicalNodes[e], LeafCount[e], bitSize[e]};
cheaperQ[new_, old_] := Order[RadicalCost[new], RadicalCost[old]] === 1;
pickCheapest[list_List] := First[SortBy[list, RadicalCost]];
smallQ[e_] := If[LeafCount[e] > $cfg["MaxLeafCount"], limitHit["MaxLeafCount"]; False, True];

(* ------------------------------------------------------------------ *)
(* exact certification                                                *)
(* ------------------------------------------------------------------ *)

canonicalNonzeroQ[e_] := Module[{p},
   If[gaussianQ[e], Return[e =!= 0]];
   If[Head[e] =!= Root, Return[False]];
   p = canonicalRootPolynomial[e];
   p =!= $Failed && Coefficient[p, $x, 0] =!= 0];

(* Optional diagnostic only. Accuracy estimates are not interval certificates. *)
numericallyDifferentQ[d_] := Module[{num},
   If[! TrueQ[$cfg["NumericPrefilter"]], Return[False]];
   num = bounded[N[d, 40]];
   TrueQ[NumberQ[num] && Accuracy[num] >= 25 && Abs[num] > 10^-20]];

certify[a_, b_] := Module[{d, r},
   bump["Certificates"];
   If[! exactQ[a] || ! exactQ[b], bump["CertificatesUnknown"]; Return["Unknown"]];
   If[a === b, bump["CertificatesEqual"]; Return["Equal"]];
   d = a - b;
   If[numericallyDifferentQ[d], bump["NumericHints"]; trace["NumericNonzeroHint"]];
   r = bounded[RootReduce[d], "Certificate"];
   Which[
    r === 0, bump["CertificatesEqual"]; Return["Equal"],
    canonicalNonzeroQ[r], bump["CertificatesDifferent"]; Return["Different"]];
   r = bounded[PossibleZeroQ[d, Method -> "ExactAlgebraics"], "Certificate"];
   Which[
    r === True, bump["CertificatesEqual"]; "Equal",
    r === False, bump["CertificatesDifferent"]; "Different",
    True, bump["CertificatesUnknown"]; "Unknown"]];

SetAttributes[standalone, HoldAll];
standalone[body_, failure_] := If[TrueQ[$active], body,
   Module[{cfg = resolveOptions[Strad, {}]},
    If[FailureQ[cfg], Return[failure]];
    Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + 20,
      $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>,
      $recursion = 0, $inProgress = {}, $Assumptions = True},
     Quiet[Check[TimeConstrained[MemoryConstrained[body, 1073741824, failure], 20, failure], failure]]]]];

EqualityStatus[a_, b_] := standalone[certify[a, b], "Unknown"];
CertifiedEqualQ[a_, b_] := EqualityStatus[a, b] === "Equal";

(* The single acceptance gate. A candidate replaces the incumbent only if it is
   an explicit radical expression, small, strictly cheaper than the incumbent,
   and certified equal to the ORIGINAL target of this island. *)
accept[candidate_, target_, incumbent_, method_String] := Module[{},
   If[candidate === $Failed || candidate === target || ! RadicalExpressionQ[candidate] ||
     ! smallQ[candidate] || ! cheaperQ[candidate, incumbent], Return[incumbent]];
   If[certify[candidate, target] === "Equal",
    bump["CandidatesAccepted"];
    If[Length[$records] < $cfg["MaxTraceEntries"],
     AppendTo[$records, <|"Before" -> target, "After" -> candidate, "Method" -> method, "EqualityStatus" -> "Equal", "Scope" -> "AcceptedProposal"|>]];
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

(* real cube roots inside Q(Sqrt[c]): trace-norm criterion *)
cubicInQuadratic[{a_, b_, c_}] := Module[{norm, n, roots, out = {}, den, beta},
   norm = a^2 - b^2 c;
   n = Sign[norm] Abs[norm]^(1/3);
   If[! rationalQ[n], Return[{}]];
   roots = rationalRoots[$x^3 - 3 n $x - 2 a];
   Do[den = t^2 - n;
    If[den =!= 0, beta = t/2 + b Sqrt[c]/den;
     If[TrueQ[bounded[RootReduce[beta^3 - (a + b Sqrt[c])] === 0, "Certificate"]], AppendTo[out, beta]]],
    {t, roots}];
   out];

(* Dickson trace-norm reconstruction for odd m >= 5 in a real quadratic
   field. This tests membership in Q(Sqrt[c]), not general denestability. *)
quadraticOddRoots[{a_, b_, c_}, m_Integer] := Module[
   {norm = a^2 - b^2 c, n, poly, roots, den, beta, out = {}},
   If[m < 5 || ! OddQ[m] || m > $cfg["MaxRootIndex"], Return[{}]];
   n = bounded[Sign[norm] Abs[norm]^(1/m)];
   If[n === $Failed || ! rationalQ[n], Return[{}]];
   poly = bounded[Sum[m/(m-j) Binomial[m-j,j] (-n)^j $x^(m-2j),
      {j,0,Quotient[m,2]}] - 2 a];
   If[poly === $Failed, Return[{}]];
   roots = rationalRoots[poly];
   Do[
    If[expiredQ[], Break[]];
    den = bounded[Sum[Binomial[m-1-j,j] (-n)^j t^(m-1-2j),
       {j,0,Quotient[m-1,2]}]];
    If[den === $Failed || den === 0, Continue[]];
    beta = bounded[t/2 + b Sqrt[c]/den];
    If[beta =!= $Failed && TrueQ[bounded[
       RootReduce[beta^m - (a+b Sqrt[c])] === 0, "Certificate"]],
     AppendTo[out,beta]], {t,roots}];
   out];

rationalRoots[p_] := Module[{fl},
   fl = bounded[FactorList[p]];
   If[fl === $Failed || ! ListQ[fl], Return[{}]];
   DeleteDuplicates[Select[Cases[fl, {f_, _Integer} /; PolynomialQ[f, $x] && Exponent[f, $x] === 1 :>
       -Coefficient[f, $x, 0]/Coefficient[f, $x, 1]], rationalQ]]];

(* Honsbeek: Sqrt[A + B] with A^3, B^3 nonzero rationals, A + B > 0 real *)
honsbeekSquareRoots[rho_] := Module[{terms, a, b, ratio, roots, den, num, out = {}},
   If[Head[rho] =!= Plus || Length[rho] =!= 2, Return[{}]];
   terms = List @@ rho;
   If[! AllTrue[terms, MatchQ[#, Power[_?rationalQ, Rational[1, 3]] | Times[_?rationalQ, Power[_?rationalQ, Rational[1, 3]]]] &], Return[{}]];
   {a, b} = Replace[bounded[RootReduce[#^3], "Certificate"], $Failed -> Null] & /@ terms;
   If[! AllTrue[{a, b}, rationalQ] || a === 0 || b === 0, Return[{}]];
   ratio = b/a;
   roots = rationalRoots[$x^4 + 4 $x^3 + 8 ratio $x - 4 ratio];
   Do[den = b - s^3 a;
    If[den > 0,
     num = -s^2 terms[[1]]^2/2 + s terms[[1]] terms[[2]] + terms[[2]]^2;
     out = Join[out, {num/Sqrt[den], -num/Sqrt[den]}]],
    {s, roots}];
   out];

(* Sqrt of a rational combination of several square roots of rationals:
   solve (Sum x_u Sqrt[u])^2 == rho over the rationals *)
multiSurdSquareRoots[rho_] := Module[{e, surds, primes, unknownSets, out = {}, vars, cand, sq, basis, eqs, sol, ratpart},
   e = bounded[Expand[rho]];
   If[e === $Failed, Return[{}]];
   surds = DeleteDuplicates[Cases[e, Power[n_Integer, Rational[1, 2]] /; n > 1 :> n, {0, Infinity}]];
   If[Length[surds] < 2 || Length[surds] > 15, Return[{}]];
   If[! AllTrue[If[Head[e] === Plus, List @@ e, {e}],
      MatchQ[#, _?rationalQ | Power[_Integer, Rational[1, 2]] | Times[_?rationalQ, Power[_Integer, Rational[1, 2]]]] &], Return[{}]];
   primes = bounded[Union @@ (First /@ FactorInteger[#] & /@ surds)];
   If[primes === $Failed, Return[{}]];
   unknownSets = DeleteDuplicates[{Union[{1}, primes], Union[{1}, primes, surds]}];
   ratpart[ex_] := ex /. Power[_Integer, Rational[1, 2]] -> 0;
   Do[
    If[Length[U] > 16, Continue[]];
    vars = Table[Unique["RadicalDenest3`Private`coef"], {Length[U]}];
    cand = vars . Sqrt[U];
    sq = bounded[Expand[cand^2]];
    If[sq === $Failed, Continue[]];
    basis = Union[surds, DeleteDuplicates[Cases[sq, Power[n_Integer, Rational[1, 2]] :> n, {0, Infinity}]]];
    eqs = Prepend[Table[Coefficient[sq, Sqrt[bb]] == Coefficient[e, Sqrt[bb]], {bb, basis}], ratpart[sq] == ratpart[e]];
    sol = bounded[Solve[eqs, vars, Rationals]];
    If[ListQ[sol] && sol =!= {},
     out = Join[out, DeleteDuplicates[cand /. sol]];
     Break[]],
    {U, unknownSets}];
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
    q === 3,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = cubicInQuadratic[parts]];
     If[neg, out = (-1)^(1/3) out],
    OddQ[q] && q >= 5,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticOddRoots[parts,q]];
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
   DeleteDuplicates[Select[Flatten[radicalForms /@ roots], exactQ]]];

(* denest a sub-problem recursively under the shared budget *)
recurse[sub_] := If[$recursion >= $cfg["MaxRecursion"] || expiredQ[], sub,
   Block[{$recursion = $recursion + 1, $cfg = Append[$cfg, "MaxTrials" -> Quotient[$cfg["MaxTrials"], 4]]},
    improveNumber[sub]]];

(* candidates for target == rho^(p/q) from linear factors of x^k - rho, k | q *)
kummerCandidates[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[{best = incumbent, gammas, k, rest, sub, den},
   Do[
    If[expiredQ[], Break[]];
    gammas = linearRoots[rho, k];
    rest = q/k;
    Do[
     If[expiredQ[], Break[]];
     If[rest === 1,
      Do[best = acceptWithPolish[bounded[Expand[(gamma unity[l, q])^p]], target, best, "LinearFactor"], {l, 0, q - 1}],
      (* rho = gamma^k, so target = (gamma zeta_k^j)^(p/rest) zeta_rest^l for some j, l *)
      Do[
       den = bounded[Expand[gamma unity[j, k]]];
       If[den === $Failed, Continue[]];
       sub = recurse[den^(1/rest)];
       If[exactQ[sub] && RadicalDepth[sub] <= RadicalDepth[target],
        Do[best = acceptWithPolish[bounded[Expand[(sub unity[l, rest])^p]], target, best, "IndexReduction"], {l, 0, rest - 1}]],
       {j, 0, k - 1}]],
     {gamma, gammas}];
    If[RadicalDepth[best] < RadicalDepth[target], Break[]],
    {k, Reverse[Rest[Divisors[q]]]}];
   best];

(* negative real radicand: rho^(p/q) = (-1)^(p/q) (-rho)^(p/q) *)
negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer, incumbent_] := Module[{sub},
   If[! TrueQ[bounded[rho < 0, "Certificate"]], Return[incumbent]];
   sub = recurse[(-rho)^(p/q)];
   accept[bounded[Expand[(-1)^(p/q) sub]], target, incumbent, "NegativeRadicand"]];

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
   (* the only insertion point: caps admissions, counts proposals, dedups by expanded syntax, not algebraic value *)
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
       search when an improvement has been found and further trials do not help *)
    If[trials >= $cfg["MaxTrials"], limitHit["MaxTrials"]; Break[]];
    If[best =!= initialBest && sinceImprovement >= $cfg["Patience"], limitHit["Patience"]; Break[]];
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
      If[primes === $Failed, primes = {}];
      batch = 0;
      Do[If[admitted >= cap || proposed >= proposalCap || batch >= 24 || expiredQ[], Break[]];
       Do[If[batch >= 24 || admitted >= cap || proposed >= proposalCap || expiredQ[], Break[]];
        batch++; admit[m prime^e], {e, 1, q - 1}], {prime, primes}];
      j = 1;
      While[primes =!= {} && j < q^Length[primes] && batch < 24 && admitted < cap && proposed < proposalCap && ! expiredQ[],
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
    r = bounded[Catch[solver[target], _, $Failed &]];
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

(* fast paths for a single rational-power node *)
powerProposals[target_, incumbent_] := Module[{best = incumbent, rho, p, q, root, cands, before},
   If[! MatchQ[target, Power[_, _Rational]], Return[best]];
   rho = First[target]; p = Numerator[Last[target]]; q = Denominator[Last[target]];
   If[q > $cfg["MaxRootIndex"], limitHit["MaxRootIndex"]; Return[best]];
   (* shape-specific recipes for the q-th root, then the integer power p *)
   before = best;
   cands = rootCandidates[rho, q];
   Do[best = acceptWithPolish[bounded[Expand[c^p]], target, best, "FastPath"], {c, cands}];
   If[best =!= before, bump["FastPathAccepted"]];
   If[RadicalDepth[best] <= 1 && FreeQ[best, _Root | _AlgebraicNumber], Return[best]];
   (* negative real radicand: separate the phase, denest the modulus *)
   best = negativeRadicandCandidate[target, rho, p, q, best];
   If[RadicalDepth[best] <= 1, Return[best]];
   (* roots of rho inside Q(rho), and index reduction through divisors of q *)
   best = kummerCandidates[target, rho, p, q, best];
   (* an even index with a quadratic recipe available for the square root *)
   If[RadicalDepth[best] >= 2 && EvenQ[q] && q > 2,
    root = recurse[rho^(1/2)];
    If[exactQ[root] && RadicalDepth[root] <= RadicalDepth[target],
     root = recurse[root^(2/q)];
     best = acceptWithPolish[bounded[Expand[root^p]], target, best, "EvenIndexSplit"]]];
   best];

(* the multiplier search is meant for a radical node or a product of radical
   nodes; a sum island gets the whole-island proposals only *)
searchableQ[e_] := MatchQ[e, Power[_, _Rational]] ||
   (Head[e] === Times && AllTrue[List @@ e, MatchQ[#, _?gaussianQ | Power[_, _Rational]] &]);

(* results for one island are memoized within the session: the same sub-problem
   recurs through roots of unity, index reduction and repeated passes *)
improveNumber[target_] := Module[{best = target, key},
   If[expiredQ[] || ! smallQ[target] || ! exactQ[target], Return[target]];
   If[RadicalDepth[target] < 2 && FreeQ[target, _Root | _AlgebraicNumber], Return[target]];
   If[MemberQ[$inProgress, target], Return[target]];
   (* A reduced-budget failure must not poison a later full-budget search. *)
   key = memoKey[target, $cfg["MaxTrials"], $cfg["MaxRecursion"] - $recursion];
   If[KeyExistsQ[$memo, key], Return[$memo[key]]];
   bump["Islands"];
   Block[{$inProgress = Append[$inProgress, target]},
    best = powerProposals[target, best];
    If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber],
     best = genericProposals[target, best]];
    If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic && searchableQ[target] && ! expiredQ[],
     best = multiplierSearch[target, best]]];
   If[best =!= target && ! expiredQ[], AssociateTo[$memo, key -> best]];
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
   $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>,
   $recursion = 0, $inProgress = {}, $Assumptions = True},
  Module[{committed = {e, Missing["NotComputed"]}, initialCost = Missing["NotComputed"],
    candidate, candidateCost, outcome = Null, started = AbsoluteTime[], passes, status, isNumber},
   passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
   If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
    outcome = TimeConstrained[MemoryConstrained[
      initialCost = RadicalCost[e]; committed = {e, initialCost};
      Which[
       ! FreeQ[e, _Real | _Complex?InexactNumberQ], limitHit["InexactInput"],
       coreOnly && ! exactQ[e], limitHit["NotExactAlgebraic"],
       True,
       isNumber = exactQ[e];
       Do[
        If[expiredQ[], Break[]];
        candidate = If[coreOnly, improveNumber[First[committed]], walk[First[committed]]];
        bump["PassesCompleted"];
        If[candidate === First[committed], Break[]];
        candidateCost = RadicalCost[candidate];
        If[Order[candidateCost, Last[committed]] =!= 1, Break[]];
        If[isNumber && certify[candidate, e] =!= "Equal", Break[]];
        committed = {candidate, candidateCost};
        If[pass === passes && passes > 1, limitHit["MaxPasses"]],
        {pass, passes}]],
      cfg["MemoryBudget"], memoryStopped], cfg["TimeBudget"], timeStopped]];
   If[outcome === memoryStopped, limitHit["MemoryBudget"]];
   If[outcome === timeStopped, limitHit["TimeBudget"]];
   status = Which[outcome === timeStopped, "Timeout", outcome === memoryStopped, "MemoryLimit",
     TrueQ[cfg["TimeBudget"] == 0], "Disabled", First[committed] === e, "Unchanged", True, "Improved"];
   <|"Result" -> First[committed], "Status" -> status, "Limits" -> Keys[$limits],
    "InitialCost" -> initialCost, "FinalCost" -> Last[committed], "Statistics" -> $stats,
    "Certificates" -> $records, "CertificateKind" -> "Kernel-checked accepted proposals, not proof objects",
    "CertificateRecordsTruncated" -> ($stats["CandidatesAccepted"] > Length[$records]),
    "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg, "Trace" -> $trace,
    "BudgetScope" -> "Search, preflight and cost construction; excludes ordinary argument/option evaluation",
    "LimitsMeaning" -> "Triggered guards or reached caps, not impossibility certificates",
    "CompletenessClaim" -> False|>]];

invoke[e_, head_Symbol, rules_List, report_, core_] := Module[{cfg, result},
   cfg = resolveOptions[head, rules];
   If[FailureQ[cfg], Return[cfg]];
   result = run[e, cfg, core];
   If[TrueQ[report], result, result["Result"]]];

(* Deliberately accept raw arguments so malformed option syntax reaches
   resolveOptions instead of leaving the public call unevaluated. *)
invokeArgs[e_, head_Symbol, raw_List, report_, core_] := Module[{rules = raw},
   If[! TrueQ[core] && rules =!= {} && booleanQ[First[rules]],
    rules = Join[{"AllLevels" -> First[rules]}, Rest[rules]]];
   invoke[e, head, rules, report, core]];
Strad[e_, args___] := invokeArgs[e, Strad, {args}, False, False];
DenestRadicals[e_, args___] := invokeArgs[e, DenestRadicals, {args}, False, False];
DenestCore[e_, args___] := invokeArgs[e, DenestCore, {args}, False, True];
DenestReport[e_, args___] := invokeArgs[e, DenestReport, {args}, True, False];
Strad[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestRadicals[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestCore[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];
DenestReport[] := Failure["InvalidArguments", <|"MessageTemplate" -> "An expression is required."|>];

End[];
EndPackage[];
