(* ::Package:: *)

(* Algebraic.wl -- exact computation with polynomials and algebraic numbers.

   One package for four operations that were developed separately and share an
   engine:

     * functional decomposition of a polynomial with exact algebraic
       coefficients, p = f(g(x))                     AlgebraicDecompose
     * decomposition of an algebraic number into a sum or a product of
       algebraic numbers of the smallest possible maximum degree
                                                     RootSumDecomposition
                                                     RootProductDecomposition
     * expression of an algebraic number by radicals whenever its Galois group
       is solvable                                   RootToRadicals
     * removal of nested root extractions from an exact algebraic expression
                                                     DenestRadicals

   The merge is not a bundle.  The Galois engine (numerical resolvents, tower
   basis, trace-form coordinates) is written once and used by the sum/product
   decomposition and by the radical descent; the radical grammar
   (RadicalExpressionQ, RadicalDepth) is written once and used by the radical
   descent and by the denester; and the functional decomposition supplies the
   inner/outer splitting that the radical descent needs.  The four sources are
   root-decomposition/RootDecomposition.wl,
   polynomial-decompose/AlgebraicDecomposition.wl,
   root-to-radicals/RootToRadicals.wl and
   radical-denest/DenestRadicals.wl; see algebraic/README.md for what
   changed in the merge.

   The package runs in the Wolfram kernel and in Mathics3 (https://mathics.org).
   Portability is confined to one layer: every name beginning with a lower-case
   "k" below is a portable stand-in for a Wolfram System function.  In the
   Wolfram kernel each one is a thin wrapper over the builtin; under Mathics it
   is a Wolfram Language implementation of the same contract.  The algorithms
   call only those names, so both kernels run the same code.  No System symbol
   is ever redefined.  AlgebraicKernelReport[] states what the running kernel
   supplies natively and which operations are available.

   License: MIT-0.  See algebraic/README.md and the LICENSE file of the
   repository.
*)

BeginPackage["Algebraic`"];

(* ------------------------------------------------------------------ *)
(* Functional decomposition of polynomials                            *)
(* ------------------------------------------------------------------ *)

AlgebraicDecompose::usage =
  "AlgebraicDecompose[p,x] returns one complete composition chain, outermost first. AlgebraicDecompose[p] infers the variable when p has exactly one. It chooses the smallest successful right degree at each step. All components except the first are monic with zero constant term. Exact algebraic coefficients are required.";
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

(* ------------------------------------------------------------------ *)
(* Sum and product decomposition of algebraic numbers                 *)
(* ------------------------------------------------------------------ *)

RootSumDecomposition::usage = "RootSumDecomposition[a] represents the exact algebraic number a as a sum of algebraic numbers whose largest degree over the rationals is as small as possible.
RootSumDecomposition[a, d] looks for a representation whose summands all have degree at most d.
The result is an Association with keys \"Terms\", \"Degrees\", \"MaximumDegree\", \"LowerBound\", \"Optimal\", \"ScopeOptimal\", \"Scope\", \"Expression\", \"Verified\" and \"Method\".";

RootProductDecomposition::usage = "RootProductDecomposition[a] represents the exact nonzero algebraic number a as a product of algebraic numbers whose largest degree over the rationals is as small as possible.
RootProductDecomposition[a, d] looks for a representation whose factors all have degree at most d.
The result is an Association with the same keys as RootSumDecomposition, plus \"TwoFactorOptimal\" and \"NormExponent\".";

RootGaloisData::usage = "RootGaloisData[a] computes the Galois group of the minimal polynomial of a as a group of permutations of its roots, the splitting field in a tower basis, all subgroups with their fixed fields, and related data.
RootGaloisData[poly, x] does the same for a squarefree rational polynomial.";

RootDecompositionLowerBound::usage = "RootDecompositionLowerBound[a] gives a rigorous lower bound for the maximum degree in any finite sum or product decomposition of a, from the largest prime divisor of deg(a) and from Frobenius cycle types of its minimal polynomial.";

RootDecompositionVerify::usage = "RootDecompositionVerify[a, terms, Plus|Times] checks exactly that the terms combine to a and returns their degrees.";

RootBoundedDecomposition::usage = "RootBoundedDecomposition[a, Plus|Times, d, h, r] searches for a decomposition of a into at most r components of degree at most d such that all components except the last are roots of primitive integer polynomials of coefficient height at most h; the last component is the exact residual.";

RootDecompositionCatalog::usage = "RootDecompositionCatalog[d, h] lists all roots of irreducible primitive integer polynomials of degree at most d and coefficient height at most h.";

(* ------------------------------------------------------------------ *)
(* Radical expressions                                                *)
(* ------------------------------------------------------------------ *)

RootToRadicals::usage = "RootToRadicals[a] expresses the exact algebraic number a by radicals when the Galois group of its minimal polynomial is solvable; it returns a Failure otherwise. RootToRadicals[a, Method -> \"Galois\"] forces the general Galois-Kummer descent; Method -> \"Structural\" uses only the structural recognizers.";
RootRadicalReport::usage = "RootRadicalReport[a] returns an Association with the radical expression (if any), the method used, the Galois group order (when it was computed), the verification status and the timing.";
RootSolvableQ::usage = "RootSolvableQ[a] gives True if the Galois group of the minimal polynomial of a is solvable (so that a is expressible by radicals), False otherwise.";

(* ------------------------------------------------------------------ *)
(* Denesting                                                          *)
(* ------------------------------------------------------------------ *)

DenestRadicals::usage = "DenestRadicals[expr, opts] denests the exact algebraic radicals occurring in expr and returns an expression certified equal to expr. DenestRadicals[expr, True, opts] also processes inner nesting levels and repeats passes while they improve the result.";
DenestCore::usage = "DenestCore[problem, opts] denests one exact algebraic number without traversing a symbolic host.";
DenestReport::usage = "DenestReport[expr, opts] returns an Association with the result (\"Result\"), \"Status\", \"Limits\", \"Statistics\", \"Certificates\", \"ElapsedSeconds\", \"Options\" and an optional bounded \"Trace\".";
EqualityStatus::usage = "EqualityStatus[a, b] is \"Equal\", \"Different\" or \"Unknown\" for exact algebraic numbers a and b, decided by exact algebra only (a canonical algebraic reduction, then an exact zero test) within a time limit; inputs outside the supported grammar give \"Unknown\".";
CertifiedEqualQ::usage = "CertifiedEqualQ[a, b] is True only when EqualityStatus[a, b] is \"Equal\".";
RadicalCost::usage = "RadicalCost[e] is the lexicographic cost {#Root and AlgebraicNumber objects, radical depth, #rational-power nodes outside opaque objects, LeafCount, total bit size of integer, rational and Gaussian-rational atoms} used to decide whether a rewrite is an improvement.";
RationalizeDenominator::usage = "RationalizeDenominator[expr] rewrites expr with a rational denominator using a certified polynomial inverse of the exact algebraic denominator. It need not reduce RadicalCost.";
Factorc::usage = "Factorc[expr] offers a factorization of an exact algebraic expr as a certified proposal and returns it only when it is certified equal and cheaper. Symbolic input is returned unchanged.";

(* ------------------------------------------------------------------ *)
(* Shared grammar of exact algebraic expressions                      *)
(* ------------------------------------------------------------------ *)

ExactAlgebraicQ::usage = "ExactAlgebraicQ[e] is True when e is in the supported exact algebraic grammar: rationals, Gaussian rationals, Plus, Times and rational Power combinations of them, Root objects of a polynomial with such coefficients and a valid root index, and AlgebraicNumber objects with an admitted generator and Gaussian-rational coefficients. False also covers unsupported exact representations.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] is True when e is an explicit radical expression: rationals, Gaussian rationals and Plus, Times and rational Power combinations of them. Root and AlgebraicNumber objects are not radical expressions.";
RadicalDepth::usage = "RadicalDepth[e] is the maximal number of nested rational-power nodes on a path of e. Root and AlgebraicNumber objects are opaque and count as depth 0.";

(* ------------------------------------------------------------------ *)
(* The package itself                                                 *)
(* ------------------------------------------------------------------ *)

$AlgebraicVersion::usage = "$AlgebraicVersion is the version string of the Algebraic package.";
$AlgebraicResolventLimit::usage = "$AlgebraicResolventLimit is the largest degree of a resultant the Galois engine will factor while building a resolvent tower; beyond it RootGaloisData, the decompositions and the radical descent return Failure[\"EngineLimit\", ...]. Infinity in the Wolfram kernel, 48 in Mathics, where the factorisation is interpreted.";
$AlgebraicFrobeniusPrimes::usage = "$AlgebraicFrobeniusPrimes is the number of primes whose Frobenius cycle types RootDecompositionLowerBound and the decompositions scan for the lower bound: 40 in the Wolfram kernel, 10 in Mathics. Fewer primes leave the bound rigorous but not always as sharp.";
$AlgebraicFrobeniusPrimesSolvable::usage = "$AlgebraicFrobeniusPrimesSolvable is the number of primes RootSolvableQ and RootToRadicals scan for a cycle type that proves the Galois group non-solvable before any group computation: 60 in the Wolfram kernel, 12 in Mathics.";
$AlgebraicMemoLimit::usage = "$AlgebraicMemoLimit is the number of entries after which each of the package's memo tables (reductions, minimal polynomials, root values, Galois data) is emptied; 5000.";
$AlgebraicTimeScale::usage = "$AlgebraicTimeScale multiplies the internal time limits the package gives the kernel's own algebra (a few seconds for a minimal polynomial, twenty for a factorisation over an extension): 1 in the Wolfram kernel, 4 in Mathics.";
AlgebraicKernelReport::usage = "AlgebraicKernelReport[] returns an Association describing the running kernel: \"Kernel\" (\"Wolfram\" or \"Mathics\"), \"Version\", \"NativeFunctions\" and \"EmulatedFunctions\" (the System functions the portable layer had to supply), and \"Operations\" mapping each of the four operations to True, False or a string explaining a restriction.";

(* Messages.  Engine-level messages are issued from the package symbol
   Algebraic; the four sources issued them from their own package symbols. *)

Algebraic::unprobed = "The portable layer asked whether `1` is native, but no load-time probe decides it; the emulation is used.";
Algebraic::inexact = "The input `1` is not an exact algebraic number.";
Algebraic::notalg = "Could not compute a rational minimal polynomial of `1`.";
Algebraic::order = "The Galois group has order `1`, larger than the limit `2` (option \"MaxGroupOrder\").";
Algebraic::group = "Failed to determine the Galois group numerically after `1` attempts; increase \"WorkingPrecision\" or \"MaxTries\".";
Algebraic::prec = "Numerical rounding failed at precision `1`; retrying with higher precision.";
Algebraic::verify = "Internal error: a candidate decomposition failed exact verification.";
Algebraic::unsupported = "`1` is not available in this kernel: `2`.";

RootToRadicals::notsolv = "The Galois group of the minimal polynomial is not solvable (`1`); no radical expression exists.";
RootToRadicals::inexact = "The input `1` is not an exact algebraic number.";
RootToRadicals::verify = "The candidate radical expression could not be verified exactly within the time limit; returning it with \"Verified\" -> `1`.";
RootToRadicals::opts = "Invalid option value `1`.";

$AlgebraicVersion = "1.0.0";

Begin["`Private`"];

(* ================================================================== *)
(* 0.  Portable kernel layer                                          *)
(* ================================================================== *)

(* Every name below beginning with a lower-case "k" is a portable stand-in
   for a Wolfram System function.  The rest of the package calls only these
   names, never the builtins they replace, so the Wolfram kernel and Mathics3
   run the same algorithm code.  No System symbol is redefined anywhere.

   Availability is decided by evaluating the builtin once at load time and
   comparing the answer with the known-correct one, rather than by testing
   $Version: a Mathics release that implements a function correctly then uses
   it.  $kNative records the outcome and AlgebraicKernelReport[] publishes it. *)

(* kx is the portable layer's own polynomial variable and is assigned, so it
   is never used as a pattern variable.  The algorithms below keep using the
   unassigned private symbol x for the same purpose. *)
kx = Unique["Algebraic`Private`kx"];
ey = Unique["Algebraic`Private`ey"];       (* the elimination variable *)
ktag = Unique["Algebraic`Private`ktag"];   (* a private Catch tag *)

(* Return[expr, Module] is not implemented in Mathics 10.0.1: it does not
   message, the value is discarded, and evaluation continues after it.  A
   function that needs that behaviour wraps its Module in Catch[..., moduleTag]
   and throws instead.  The tag is shared, so the innermost such Catch
   receives the throw, which is exactly what Return[expr, Module] means. *)
moduleTag = Unique["Algebraic`Private`moduleReturn"];

(* A probe must not be able to abort the evaluator: every test below was
   checked to leave both kernels running.  Simplify applied to a Root object
   aborts Mathics 10.0.1 with a Python AssertionError, so that one is not
   probed; kSimplify is gated on RootReduce instead.

   The decision is made on the returned value under Quiet, never with Check.
   In Mathics 10.0.1 a message -- or even a Print -- issued anywhere earlier in
   the same top-level evaluation makes a later two-argument Check take its
   failure branch, and the association below is one top-level evaluation.  The
   UpTo probe messages, so with Check every probe after it reported a missing
   builtin, MinimalPolynomial included, which Mathics does implement and the
   package depends on.  Judging the value is also the better test: a builtin
   that answers correctly while emitting a message is present. *)
SetAttributes[probe, HoldFirst];
probe[test_, expected_] := TrueQ[Quiet[test === expected]];

$kNative = <|
  "Lookup" -> probe[Lookup[<|"a" -> 1|>, "a"], 1],
  "KeyExistsQ" -> probe[KeyExistsQ[<|"a" -> 1|>, "a"], True],
  "AssociateTo" -> probe[Module[{s = <|"a" -> 1|>}, AssociateTo[s, "b" -> 2]; s], <|"a" -> 1, "b" -> 2|>],
  "Merge" -> probe[Merge[{<|"a" -> 1|>, <|"a" -> 2|>}, Total], <|"a" -> 3|>],
  "FailureQ" -> probe[FailureQ[Failure["t", <||>]], True],
  "MissingQ" -> probe[MissingQ[Missing["x"]], True],
  "SelectFirst" -> probe[SelectFirst[{1, 2, 3}, EvenQ], 2],
  "MinimalBy" -> probe[MinimalBy[{{1, 2}, {0, 5}}, First], {{0, 5}}],
  "DeleteDuplicatesBy" -> probe[DeleteDuplicatesBy[{1, 2, 3, 4}, EvenQ], {1, 2}],
  "UpTo" -> probe[Take[{1, 2, 3}, UpTo[5]], {1, 2, 3}],
  "ListConvolve" -> probe[ListConvolve[{1, 2}, {3, 4, 5}, {1, -1}, 0], {3, 10, 13, 10}],
  "Ordering" -> probe[Ordering[{3, 1, 2}], {2, 3, 1}],
  "ArrayReshape" -> probe[ArrayReshape[{1, 2, 3, 4}, {2, 2}], {{1, 2}, {3, 4}}],
  "MemoryConstrained" -> probe[MemoryConstrained[1 + 1, 10^8], 2],
  "RandomChoiceScalar" -> probe[ListQ[RandomChoice[{1, 2, 3}]], False],
  "OptionNames" -> (Options[probeOptions] = {"s" -> 1};
    probe[First /@ Options[probeOptions], {"s"}]),
  "PolynomialRemainder" -> probe[PolynomialRemainder[kx^3, kx^2 - 1, kx], kx],
  "PolynomialGCD" -> probe[PolynomialGCD[kx^2 - 1, kx^2 - 2 kx + 1], kx - 1],
  "Resultant" -> probe[Resultant[kx^2 - 2, kx^2 - 3, kx], 1],
  "Discriminant" -> probe[Discriminant[kx^2 - 4, kx], 16],
  "FactorList" -> probe[FactorList[2 kx^2 - 2], {{2, 1}, {-1 + kx, 1}, {1 + kx, 1}}],
  "FactorListModulus" -> probe[FactorList[kx^2 + 1, Modulus -> 5], {{1, 1}, {2 + kx, 1}, {3 + kx, 1}}],
  "IrreduciblePolynomialQ" -> probe[IrreduciblePolynomialQ[kx^2 + 1], True],
  "SquareFreeQ" -> probe[SquareFreeQ[kx^2 - 1], True],
  "CoefficientRules" -> probe[CoefficientRules[kx^2, kx], {{2} -> 1}],
  "Cyclotomic" -> probe[Cyclotomic[3, kx], 1 + kx + kx^2],
  (* Wolfram returns -((Sqrt[2] - kx) (Sqrt[2] + kx)); only the fact that the
     quadratic split at all is probed. *)
  "FactorExtension" -> probe[Head[Factor[kx^2 - 2, Extension -> Sqrt[2]]], Times],
  "RootReduce" -> probe[RootReduce[Sqrt[2] Sqrt[2] - 2], 0],
  "MinimalPolynomial" -> probe[MinimalPolynomial[Sqrt[2] + Sqrt[3], kx], 1 - 10 kx^2 + kx^4],
  "ToRadicals" -> probe[ToRadicals[Root[#^2 - 2 &, 2]], Sqrt[2]],
  "Decompose" -> probe[Decompose[kx^4 + kx^2, kx], {kx^2 + kx, kx^2}],
  "NumericQRoot" -> probe[NumericQ[Root[#^3 - 2 &, 1]], True],
  "AlgebraicsRoot" -> probe[Element[Root[#^3 - 2 &, 1], Algebraics], True],
  "LatticeReduce" -> probe[Sort[Abs[LatticeReduce[{{1, 1}, {1, 0}}]]], {{0, 1}, {1, 0}}],
  "FindIntegerNullVector" -> probe[Abs[FindIntegerNullVector[N[{Sqrt[2], Sqrt[8]}, 30]]], {2, 1}]
|>;

(* A name with no probe is a bug in this file, not a missing builtin: the
   Wolfram kernel would silently run the emulation.  It happened once, with
   FindIntegerNullVector, and the interpreted LLL declined the sixteen surds
   of a denesting the native function relates in 0.1 s. *)
kNativeQ[name_String] := With[{v = $kNative[name]},
  Which[v === True, True, v === False, False, True, Message[Algebraic::unprobed, name]; False]];

(* Mathics is an interpreter: internal time allowances are scaled so that a
   budget expressed in Wolfram seconds still buys the same computation.  The
   user's own "TimeBudget" and similar options are never scaled. *)
$AlgebraicTimeScale = If[kNativeQ["RootReduce"], 1, 4];
$kTimeScale := $AlgebraicTimeScale;

(* How many primes the Frobenius scans may use.  Factorising the minimal
   polynomial modulo one prime costs milliseconds in the Wolfram kernel and
   about two seconds for degree nine under Mathics, where it runs on the
   modular arithmetic of section 0.4.  Scanning fewer primes leaves both
   conclusions sound -- the exponent multiple becomes a divisor of the full
   one, so the lower bound it feeds can only come out smaller, and a
   nonsolvability proof from any single prime stands on its own -- but the
   lower bound is then not always as sharp, and an optimality claim that
   depends on it can come back False where the Wolfram kernel proves True. *)
$AlgebraicFrobeniusPrimes = If[kNativeQ["FactorListModulus"], 40, 10];
$AlgebraicFrobeniusPrimesSolvable = If[kNativeQ["FactorListModulus"], 60, 12];
$kFrobeniusPrimes := $AlgebraicFrobeniusPrimes;
$kFrobeniusPrimesSolvable := $AlgebraicFrobeniusPrimesSolvable;

(* ------------------------------------------------------------------ *)
(* 0.1  Associations and lists                                        *)
(* ------------------------------------------------------------------ *)

If[kNativeQ["KeyExistsQ"],
  (* KeyExistsQ messages on a non-association; the package asks about
     arbitrary results, so the question is answered rather than reported. *)
  kKeyExistsQ[a_, key_] := TrueQ[Quiet[KeyExistsQ[a, key]]],
  kKeyExistsQ[a_?AssociationQ, key_] := MemberQ[Keys[a], Verbatim[key]] || MemberQ[Keys[a], key];
  kKeyExistsQ[_, _] := False];

If[kNativeQ["Lookup"],
  kLookup[a_, key_] := Lookup[a, key];
  kLookup[a_, key_, default_] := Lookup[a, key, default],
  (* Mathics: association part extraction works, Lookup does not.  The two
     list cases follow the Wolfram kernel exactly: a list of associations is
     threaded over, but the empty list is an empty rule collection, so
     Lookup[{}, key, default] is default and not {}. *)
  kLookup[a_, key_] := kLookup[a, key, Missing["KeyAbsent", key]];
  kLookup[a_?AssociationQ, keys_List, default_] := kLookup[a, #, default] & /@ keys;
  kLookup[a_?AssociationQ, key_, default_] := If[kKeyExistsQ[a, key], a[key], default];
  kLookup[l_List, key_, default_] := If[l === {}, default, kLookup[#, key, default] & /@ l];
  kLookup[_, _, default_] := default];

If[kNativeQ["AssociateTo"],
  kAssociateTo[s_, rules_] := AssociateTo[s, rules],
  kAssociateTo[s_, rules_] := (s = Join[s, Association @@ Flatten[{rules}]])];
SetAttributes[kAssociateTo, HoldFirst];

(* Merge accepts a list of associations or a list of rules; the package uses
   both forms. *)
If[kNativeQ["Merge"],
  kMerge[list_, f_] := Merge[list, f],
  kMerge[list_List, f_] := Module[{rules, keys},
    rules = Join @@ (If[AssociationQ[#], kNormalRules[#], {#}] & /@ list);
    keys = DeleteDuplicates[First /@ rules];
    Association @@ Table[k -> f[Last /@ Select[rules, First[#] === k &]], {k, keys}]]];
kNormalRules[a_?AssociationQ] := Table[k -> a[k], {k, Keys[a]}];

If[kNativeQ["FailureQ"],
  kFailureQ[e_] := FailureQ[e],
  kFailureQ[e_] := Head[e] === Failure || e === $Failed];

If[kNativeQ["MissingQ"],
  kMissingQ[e_] := MissingQ[e],
  kMissingQ[e_] := Head[e] === Missing];

If[kNativeQ["SelectFirst"],
  kSelectFirst[l_, f_] := SelectFirst[l, f];
  kSelectFirst[l_, f_, d_] := SelectFirst[l, f, d],
  kSelectFirst[l_, f_] := kSelectFirst[l, f, Missing["NotFound"]];
  kSelectFirst[l_List, f_, d_] := Module[{r = d}, Do[If[TrueQ[f[e]], r = e; Break[]], {e, l}]; r]];

If[kNativeQ["MinimalBy"],
  kMinimalBy[l_, f_] := MinimalBy[l, f],
  kMinimalBy[l_List, f_] := If[l === {}, {}, Module[{vals = f /@ l, m},
    m = First[Sort[vals]]; Pick[l, vals, m]]]];

If[kNativeQ["DeleteDuplicatesBy"],
  kDeleteDuplicatesBy[l_, f_] := DeleteDuplicatesBy[l, f],
  kDeleteDuplicatesBy[l_List, f_] := Module[{seen = {}, out = {}, v},
    Do[v = f[e]; If[! MemberQ[seen, v], AppendTo[seen, v]; AppendTo[out, e]], {e, l}]; out]];

(* Positions.  The Position and FirstPosition options the package needs
   (an explicit level specification, Heads -> False, an explicit default) are
   the ones Mathics 10.0.1 does not implement, and the structures searched are
   small, so one Wolfram Language implementation serves both kernels.  This
   also removes any doubt about whether Heads -> True would have matched the
   List head of a flat list against a pattern such as Except[0]. *)

(* All indices i with l[[i]] matching, as a flat list of integers. *)
kIndices[l_List, patt_] := Select[Range[Length[l]], MatchQ[l[[#]], patt] &];

(* The first such index, or default. *)
kFirstIndex[l_List, patt_] := kFirstIndex[l, patt, Missing["NotFound"]];
kFirstIndex[l_List, patt_, default_] := kSelectFirst[Range[Length[l]], MatchQ[l[[#]], patt] &, default];

(* The first position at level {n} of a nested list, as {i1, ..., in}, or
   default.  Heads are never examined. *)
kFirstPositionAtLevel[expr_, patt_, default_, n_Integer] :=
  Replace[Catch[walkLevel[expr, patt, n, {}]; Null, ktag],
    {kFound[pos_] :> pos, _ :> default}];
walkLevel[e_, patt_, 0, pos_] := If[MatchQ[e, patt], Throw[kFound[pos], ktag], Null];
walkLevel[e_List, patt_, n_Integer, pos_] :=
  Do[walkLevel[e[[i]], patt, n - 1, Append[pos, i]], {i, Length[e]}];
walkLevel[_, _, _, _] := Null;

If[kNativeQ["UpTo"],
  kTakeUpTo[l_List, n_] := Take[l, UpTo[n]],
  kTakeUpTo[l_List, n_] := Take[l, Min[n, Length[l]]]];

If[kNativeQ["Ordering"],
  kOrdering[l_] := Ordering[l],
  kOrdering[l_List] := Last /@ Sort[Transpose[{l, Range[Length[l]]}]]];

If[kNativeQ["ArrayReshape"],
  kArrayReshape[l_, dims_] := ArrayReshape[l, dims],
  kArrayReshape[l_List, {r_Integer, c_Integer}] :=
    Table[l[[(i - 1) c + j]], {i, r}, {j, c}]];

If[kNativeQ["ListConvolve"],
  kConvolve[a_List, b_List] := ListConvolve[a, b, {1, -1}, 0],
  (* The only form the package uses: the full linear convolution of two
     ascending coefficient lists, length Length[a] + Length[b] - 1.  It is
     assembled from whole-list operations -- one scaled, shifted copy of a per
     coefficient of b -- because an interpreter charges per evaluation, and
     the scalar double loop made the modular arithmetic below the slowest
     part of the package. *)
  kConvolve[a_List, b_List] := Module[{n = Length[a] + Length[b] - 1},
    Total[Table[PadRight[PadLeft[b[[i]] a, Length[a] + i - 1], n], {i, Length[b]}]]]];

SetAttributes[kMemoryConstrained, HoldFirst];
If[kNativeQ["MemoryConstrained"],
  kMemoryConstrained[expr_, bytes_] := MemoryConstrained[expr, bytes];
  kMemoryConstrained[expr_, bytes_, fail_] := MemoryConstrained[expr, bytes, fail],
  (* Mathics enforces no memory limit; the time limit still applies, and
     AlgebraicKernelReport[] reports the budget as unenforced. *)
  kMemoryConstrained[expr_, bytes_] := expr;
  kMemoryConstrained[expr_, bytes_, fail_] := expr];

(* ------------------------------------------------------------------ *)
(* 0.1a  Failure detection without Check                             *)
(* ------------------------------------------------------------------ *)

(* Two-argument Check cannot be used anywhere in this package.  In Mathics
   10.0.1 a Check takes its failure branch when any message was issued, or any
   Print performed, earlier in the same top-level evaluation -- inside a
   Module, several calls deep, and regardless of an inner Quiet.  A caller
   that prints progress, or the "Verbose" option of DenestRadicals, would therefore
   turn every later Check into a spurious failure.

   kCheck evaluates its first argument with messages suppressed and decides
   from the result, which is what the call sites here need: each one goes on
   to validate the value it got (PolynomialQ, ListQ, a degree test), so no
   information is lost by not counting messages. *)
SetAttributes[kCheck, HoldAll];
kCheck[expr_, fail_] := Module[{r = Quiet[expr]},
  If[r === $Failed || Head[r] === Failure, fail, r]];

(* Mathics converts a Root object to SymPy's CRootOf whenever Expand,
   PolynomialQ, Coefficient or Exponent see it, and CRootOf's constructor
   isolates every root and factors the polynomial: seconds per call, on
   every coefficient operation.  Around such calls the objects are replaced
   by symbols and put back afterwards. *)
withRootsAbstracted[f_, e_] := Module[{roots = rootsIn[e], syms},
  If[roots === {}, Return[f[e]]];
  syms = Table[Unique["Algebraic`Private`rt"], {Length[roots]}];
  f[e /. Thread[roots -> syms]] /. Thread[syms -> roots]];
(* the Root objects of an expression, and the defining polynomial of a Root
   object's function in the variable kx: an exact univariate polynomial of
   positive degree, or $Failed *)
rootsIn[e_] := DeleteDuplicates[Cases[e, _Root, {0, Infinity}]];
rootFunctionPolynomial[f_] := With[{poly = kCheck[kExpand[f[kx]], $Failed]},
  If[poly === $Failed || ! TrueQ[kPolynomialQ[poly, kx]] || ! FreeQ[poly, _Real] || Exponent[poly, kx] < 1, $Failed, poly]];
clearDenominators[c_List] := c LCM @@ (Denominator /@ c);

If[kNativeQ["RootReduce"],
  kExpand[e_] := Expand[e]; kPolynomialQ[e_, v_] := PolynomialQ[e, v],
  kExpand[e_] := withRootsAbstracted[Expand, e];
  kPolynomialQ[e_, v_] := withRootsAbstracted[PolynomialQ[#, v] &, e]];

(* Check as the denester's bounded operations use it: any message fails the
   operation at once.  In the Wolfram kernel that is Check itself; in Mathics
   a two-argument Check takes its failure branch for any message issued
   earlier in the same top-level evaluation, so there the value alone
   decides.  Without this the Wolfram kernel ran an operation that used to
   fail on a message to its time limit, and a 1 s denesting took 60. *)
SetAttributes[kCheckMessages, HoldAll];
If[kNativeQ["RootReduce"],
  kCheckMessages[expr_, fail_] := Quiet[Check[expr, fail]],
  kCheckMessages[expr_, fail_] := kCheck[expr, fail]];

(* LinearSolve returns its own unevaluated expression for an inconsistent
   system in both kernels (with LinearSolve::nosol), so an unsolvable system
   is recognised from the result and not from the message. *)
kLinearSolve[a_, b_] := Module[{s = Quiet[LinearSolve[a, b]]},
  If[ListQ[s], s, $Failed]];

(* Transpose of a one-row matrix is a flat list in Mathics 10.0.1, and
   MatrixPower of a 1x1 matrix a one-element list; the decompositions reach
   both through a one-dimensional subspace, and LinearSolve on the flat list
   then aborts the evaluator. *)
kAssociateTo[$kNative, "Transpose" -> probe[Transpose[{{1, 2, 3}}], {{1}, {2}, {3}}]];
kAssociateTo[$kNative, "MatrixPower" -> probe[MatrixPower[{{2}}, 3], {{8}}]];
If[kNativeQ["Transpose"],
  kTranspose[m_] := Transpose[m],
  kTranspose[m_List] := Table[m[[i, j]], {j, Length[First[m]]}, {i, Length[m]}]];
If[kNativeQ["MatrixPower"],
  kMatrixPower[m_, k_] := MatrixPower[m, k],
  kMatrixPower[m_List, k_Integer?NonNegative] := Fold[#1 . m &, IdentityMatrix[Length[m]], Range[k]]];

(* A bounded memo for pure functions of their input.  The regression
   suite asks the same questions of the same few polynomials hundreds of
   times -- the lower bound of one degree-nine root alone costs half a minute
   on Mathics -- and the exact reduction is asked about the same coefficient
   combinations again and again.  Each table is dropped once it holds
   $kMemoLimit entries, so a long session cannot grow without bound. *)
$AlgebraicMemoLimit = 5000;
$kMemoLimit := $AlgebraicMemoLimit;
$kMemo = <||>;
SetAttributes[kMemo, HoldRest];
kMemo[tag_String, key_, compute_] := Module[{table, value},
  table = kLookup[$kMemo, tag, <||>];
  If[kKeyExistsQ[table, key], Return[table[key]]];
  value = compute;
  If[Length[table] >= $kMemoLimit, table = <||>];
  kAssociateTo[table, key -> value];
  kAssociateTo[$kMemo, tag -> table];
  value];

(* The single variable of a univariate polynomial, or None. *)
polyVar[p_] := Module[{v = Variables[p]},
  Which[v === {}, None, Length[v] === 1, First[v], True, None]];

(* ------------------------------------------------------------------ *)
(* 0.2  Dense coefficient lists over an exact field                   *)
(* ------------------------------------------------------------------ *)

(* Ascending dense coefficient lists.  The zero polynomial is {}. *)
(* CoefficientList aborts Mathics 10.0.1 with a Python TypeError when an
   algebraic coefficient cancels to zero only under SymPy -- for example
   x Sqrt[2]/(2 + Sqrt[3]) - x Root[4 + #^4 - 28 #^2 &, 3], whose two
   coefficients are equal -- and no probe can detect that without aborting.
   On a kernel without RootReduce the list is therefore assembled from the
   expanded terms structurally: each term's power of v is read off and its
   coefficient is kept unsimplified, which is what the callers' exact
   reduction then handles. *)
If[kNativeQ["RootReduce"],
  kCoefficientList[p_, v_] := CoefficientList[p, v],
  kCoefficientList[p_, v_] := Module[{e = kExpand[p], terms, n, c, k},
    If[e === 0, Return[{}]];
    terms = If[Head[e] === Plus, List @@ e, {e}];
    n = Max[Exponent[#, v] & /@ terms];
    If[! IntegerQ[n] || n < 0, Return[CoefficientList[p, v]]];
    c = ConstantArray[0, n + 1];
    Do[k = Exponent[t, v]; c[[k + 1]] = c[[k + 1]] + (t /. v -> 1), {t, terms}];
    c]];

(* Ascending dense coefficient lists.  The zero polynomial is {}.  A zero
   coefficient is recognised structurally: asking == of a polynomial
   coefficient would reach the kernel's equation solver. *)
clTrim[c_List] := Module[{k = Length[c]},
  While[k >= 1 && (c[[k]] === 0 || kExpand[c[[k]]] === 0), k--];
  Take[c, k]];
clOf[p_, v_] := clTrim[kCoefficientList[kExpand[p], v]];
clTo[c_List, v_] := If[c === {}, 0, kExpand[Total[Table[c[[i]] v^(i - 1), {i, Length[c]}]]]];
clDeg[c_List] := Length[c] - 1;
clLC[c_List] := If[c === {}, 0, Last[c]];
clScale[a_List, s_] := If[s === 0, {}, clTrim[s a]];
clDeriv[c_List] := clTrim[Table[(i - 1) c[[i]], {i, 2, Length[c]}]];

(* Quotient and remainder over a field, ascending lists. *)
(* $Failed when a coefficient degenerates: Cancel of a quotient of nested
   radicals can return Indeterminate in Mathics, and Indeterminate == 0
   there aborts the evaluator (a NaN comparison) rather than staying
   unevaluated. *)
clDivide[a_List, b_List] := Catch[Module[{r = a, q, db = clDeg[b], da = clDeg[a], lb, k, t},
  If[b === {}, Throw[$Failed, ktag]];
  If[da < db, Throw[{{}, a}, ktag]];
  lb = clLC[b]; q = ConstantArray[0, da - db + 1];
  Do[t = If[k + db + 1 <= Length[r], r[[k + db + 1]], 0];
    If[degenerateQ[t], Throw[$Failed, ktag]];
    If[t =!= 0 && ! TrueQ[t == 0],
      t = Cancel[t/lb];
      If[degenerateQ[t], Throw[$Failed, ktag]];
      q[[k + 1]] = t;
      Do[r[[k + j + 1]] = Cancel[kExpand[r[[k + j + 1]] - t b[[j + 1]]]], {j, 0, db}]],
    {k, da - db, 0, -1}];
  {clTrim[q], clTrim[r]}], ktag];

clMod[a_List, b_List] := Replace[clDivide[a, b], {d_List :> Last[d], _ -> $Failed}];
clQuo[a_List, b_List] := Replace[clDivide[a, b], {d_List :> First[d], _ -> $Failed}];

clGCD[a_List, b_List] := Module[{u = a, v = b, w},
  While[v =!= {}, w = clMod[u, v]; If[w === $Failed, Return[$Failed]]; u = v; v = w];
  If[u === {}, {}, clScale[u, 1/clLC[u]]]];

(* Content and primitive part of a list with rational entries. *)
clPrimitive[c_List] := Module[{den, num, g},
  If[c === {}, Return[{0, {}}]];
  den = LCM @@ (Denominator /@ c); num = c den;
  g = GCD @@ num; If[g === 0, Return[{0, {}}]];
  If[Last[num] < 0, g = -g];
  {g/den, num/g}];

(* ------------------------------------------------------------------ *)
(* 0.3  Polynomial algebra over the rationals                         *)
(* ------------------------------------------------------------------ *)

If[kNativeQ["PolynomialRemainder"],
  kPolynomialRemainder[a_, b_, v_] := PolynomialRemainder[a, b, v],
  kPolynomialRemainder[a_, b_, v_] := clTo[clMod[clOf[a, v], clOf[b, v]], v]];

(* PolynomialGCD takes no variable, so the fallback finds it.  The package
   only ever asks for the gcd of two univariate polynomials. *)
If[kNativeQ["PolynomialGCD"],
  kPolynomialGCD[a_, b_] := PolynomialGCD[a, b],
  kPolynomialGCD[a_, b_] := Module[{vars = Variables[{a, b}], v, g},
    If[vars === {}, Return[GCD[a, b]]];
    If[Length[vars] > 1, Return[$Failed]];
    v = First[vars];
    g = clGCD[clOf[a, v], clOf[b, v]];
    Which[g === $Failed, $Failed, g === {}, 0, True, clTo[Last[clPrimitive[g]], v]]]];

If[kNativeQ["Resultant"],
  kResultant[a_, b_, v_] := Resultant[a, b, v],
  kResultant[a_, b_, v_] := clResultant[clOf[a, v], clOf[b, v]]];

If[kNativeQ["Discriminant"],
  kDiscriminant[p_, v_] := Discriminant[p, v],
  kDiscriminant[p_, v_] := Module[{c = clOf[p, v], n},
    n = clDeg[c];
    If[n < 1, 0, (-1)^(n (n - 1)/2) clResultant[c, clDeriv[c]]/clLC[c]]]];

(* {{content,1},{f1,e1},...} with primitive integer f_i, as FactorList gives. *)
factorPairs[e_] := Replace[If[Head[e] === Times, List @@ e, {e}],
  {Power[b_, n_Integer /; n > 0] :> {b, n}, f_ :> {f, 1}}, {1}];

If[kNativeQ["FactorList"],
  kFactorList[p_] := FactorList[p],
  kFactorList[p_] := Module[{v = polyVar[p], pairs, content = 1, out = {}, prim, c},
    If[p === 0, Return[{{0, 1}}]];
    If[v === None, Return[{{p, 1}}]];
    pairs = factorPairs[Factor[p]];
    Do[If[FreeQ[pr[[1]], v],
       content = content pr[[1]]^pr[[2]],
       {c, prim} = clPrimitive[clOf[pr[[1]], v]];
       content = content c^pr[[2]];
       AppendTo[out, {clTo[prim, v], pr[[2]]}]], {pr, pairs}];
    Prepend[out, {content, 1}]]];

If[kNativeQ["IrreduciblePolynomialQ"],
  kIrreduciblePolynomialQ[p_] := IrreduciblePolynomialQ[p],
  kIrreduciblePolynomialQ[p_] := Module[{v = polyVar[p], fl},
    If[v === None || ! TrueQ[kPolynomialQ[p, v]] || Exponent[p, v] < 1, Return[False]];
    fl = Select[kFactorList[p], Exponent[#[[1]], v] > 0 &];
    Length[fl] === 1 && fl[[1, 2]] === 1]];

If[kNativeQ["SquareFreeQ"],
  kSquareFreeQ[p_] := SquareFreeQ[p],
  kSquareFreeQ[p_] := Module[{v = polyVar[p], c},
    If[v === None, Return[p =!= 0]];
    c = clOf[p, v];
    c =!= {} && ListQ[c = clGCD[c, clDeriv[c]]] && clDeg[c] === 0]];

If[kNativeQ["CoefficientRules"],
  kCoefficientRules[p_, vars_] := CoefficientRules[p, vars],
  kCoefficientRules[p_, vars_List] := Module[{terms},
    terms = If[Head[kExpand[p]] === Plus, List @@ kExpand[p], {kExpand[p]}];
    (Exponent[#, vars] -> (# /. Thread[vars -> 1])) & /@ DeleteCases[terms, 0]];
  kCoefficientRules[p_, v_] := kCoefficientRules[p, {v}]];

If[kNativeQ["Cyclotomic"],
  kCyclotomic[n_, v_] := Cyclotomic[n, v],
  kCyclotomic[n_Integer, v_] := clTo[cyclotomicList[n], v]];
cyclotomicList[1] = {-1, 1};
cyclotomicList[n_Integer] := cyclotomicList[n] = Module[{num, d},
  num = Join[{-1}, ConstantArray[0, n - 1], {1}];
  Do[num = clQuo[num, cyclotomicList[d]], {d, Most[Divisors[n]]}];
  num];

(* ------------------------------------------------------------------ *)
(* 0.4  Factorisation patterns modulo a prime (Frobenius cycle types) *)
(* ------------------------------------------------------------------ *)

(* Arithmetic on ascending coefficient lists over GF(prime). *)
mTrim[c_List, q_] := Module[{d = Mod[c, q], k},
  k = Length[d]; While[k >= 1 && d[[k]] === 0, k--]; Take[d, k]];
mMul[a_List, b_List, q_] := If[a === {} || b === {}, {}, mTrim[kConvolve[a, b], q]];
(* quotient and remainder over GF(q), ascending lists *)
mDivide[a_List, b_List, q_] := Module[{r = Mod[a, q], db, inv, bb, quo, n, k, t},
  If[b === {}, Return[$Failed]];
  db = Length[b] - 1; inv = PowerMod[Last[b], -1, q]; bb = Mod[b, q];
  n = Length[r];
  If[n - 1 < db, Return[{{}, mTrim[r, q]}]];
  quo = ConstantArray[0, n - db];
  Do[t = r[[k + db + 1]];
    If[t =!= 0,
      t = Mod[t inv, q]; quo[[k + 1]] = t;
      r = Mod[r - t PadRight[PadLeft[bb, k + db + 1], n], q]],
    {k, n - 1 - db, 0, -1}];
  {mTrim[quo, q], mTrim[Take[r, Min[db, Length[r]]], q]}];
mMod[a_List, b_List, q_] := Replace[mDivide[a, b, q], {d_List :> Last[d], _ -> $Failed}];
mGCD[a_List, b_List, q_] := Module[{u = mTrim[a, q], v = mTrim[b, q], w},
  While[v =!= {}, w = mMod[u, v, q]; u = v; v = w];
  If[u === {}, {}, mTrim[u PowerMod[Last[u], -1, q], q]]];
mPowerMod[base_List, e_Integer, f_List, q_] := Module[{r = {1}, b = mMod[base, f, q], k = e},
  While[k > 0,
    If[OddQ[k], r = mMod[mMul[r, b, q], f, q]];
    k = Quotient[k, 2];
    If[k > 0, b = mMod[mMul[b, b, q], f, q]]];
  r];
mQuo[a_List, b_List, q_] := Replace[mDivide[a, b, q], {d_List :> First[d], _ -> $Failed}];

(* Padded subtraction and monic normalisation over GF(q). *)
mSub[a_List, b_List, q_] := Module[{n = Max[Length[a], Length[b]]},
  mTrim[PadRight[a, n] - PadRight[b, n], q]];
mMonic[c_List, q_] := Module[{d = mTrim[c, q]},
  If[d === {}, {}, mTrim[d PowerMod[Last[d], -1, q], q]]];

(* Degrees of the irreducible factors of a squarefree polynomial modulo a
   prime, by distinct-degree factorisation: with h = x^(q^i) mod f, the gcd of
   h - x and f is the product of the irreducible factors of degree exactly i.
   The loop stops as soon as twice the level exceeds the degree of what is
   left, which is then irreducible -- without that exit the levels ran to the
   degree of the input and one prime cost seconds under Mathics.

   Returns $Failed when the image is not squarefree or the leading
   coefficient vanishes; the callers skip the primes where that happens. *)
clFactorDegreesMod[c_List, q_Integer] := Catch[Module[
  {f, h, i = 0, g, degs = {}, n},
  If[c === {} || Mod[Last[c], q] === 0, Throw[$Failed, ktag]];
  f = mMonic[c, q];
  n = Length[f] - 1;
  If[n < 1, Throw[$Failed, ktag]];
  h = mMod[{0, 1}, f, q];
  While[Length[f] - 1 > 0,
    i++;
    If[i > n, Throw[$Failed, ktag]];
    h = mPowerMod[h, q, f, q];
    g = mGCD[mSub[h, {0, 1}, q], f, q];
    If[Length[g] - 1 > 0,
      If[! IntegerQ[(Length[g] - 1)/i], Throw[$Failed, ktag]];
      degs = Join[degs, ConstantArray[i, (Length[g] - 1)/i]];
      f = mQuo[f, g, q];
      If[Length[f] - 1 > 0, h = mMod[h, f, q]]];
    If[Length[f] - 1 > 0 && 2 (i + 1) > Length[f] - 1,
      AppendTo[degs, Length[f] - 1]; Break[]]];
  Sort[degs]], ktag];

If[kNativeQ["FactorListModulus"],
  kFactorDegreesMod[poly_, v_, q_Integer] :=
    Module[{fl = FactorList[poly, Modulus -> q]},
      Sort[Join @@ (ConstantArray[Exponent[#[[1]], v], #[[2]]] & /@
        Select[fl, Exponent[#[[1]], v] > 0 &])]],
  kFactorDegreesMod[poly_, v_, q_Integer] := clFactorDegreesMod[clOf[poly, v], q]];

kRationalQ[e_] := IntegerQ[e] || Head[e] === Rational;

(* NumberQ[Indeterminate] is True in Mathics, and a comparison against
   Indeterminate aborts its evaluator, so every numerical value is tested
   with this before it meets < or Sort. *)
degenerateQ[v_] := ! FreeQ[v, Indeterminate | ComplexInfinity | DirectedInfinity];
kFiniteNumberQ[v_] := NumberQ[v] && ! degenerateQ[v];
kGaussianQ[e_] := kRationalQ[e] || (Head[e] === Complex && kRationalQ[Re[e]] && kRationalQ[Im[e]]);
positiveIntegerQ[v_] := IntegerQ[v] && v > 0;
componentLimitQ[v_] := v === Infinity || positiveIntegerQ[v];      (* a cap on a count *)
degreeLimitQ[v_] := v === Automatic || positiveIntegerQ[v];        (* a cap on a degree *)

(* ------------------------------------------------------------------ *)
(* 0.5a  Minimal polynomials by elimination                           *)
(* ------------------------------------------------------------------ *)

(* On a kernel without RootReduce the minimal polynomial is the whole exact
   algebraic engine: every canonical reduction, every degree and every zero
   test goes through it.  Mathics does implement MinimalPolynomial, through
   SymPy, and it is fast on radicals -- but on a sum or a product of Root
   objects of degree six and up it did not finish in a minute, which is
   exactly the shape the Galois descent produces at every tower step.

   So the minimal polynomial of an expression built from rationals, Gaussian
   rationals, Root objects, Plus, Times and rational powers is computed here
   by elimination, and only an expression outside that grammar is handed to
   the kernel.  For u with p(u) = 0 and v with q(v) = 0,

       u + v    is a root of  Res_y(p(y), q(x - y)),
       u v      is a root of  Res_y(p(y), y^deg(q) q(x/y)),
       u^(1/m)  is a root of  p(x^m),
       u^n      is a root of  Res_y(p(y), x - y^n),
       1/u      is a root of  the reversal of p,

   and after each step the result is factored over the rationals and the one
   irreducible factor that vanishes at the value is kept.  The factor is
   chosen numerically at moderate precision, and when the numerical test does
   not leave exactly one candidate the surviving ones are decided exactly. *)

(* The Sylvester matrix of two ascending coefficient lists; its determinant is
   the resultant.  Computing the resultant that way avoids the deep recursion
   of a Euclidean scheme: over a coefficient ring of polynomials the recursive
   form exceeded $RecursionLimit, and Det is fast in both kernels. *)
sylvesterMatrix[a_List, b_List] := Module[{m = clDeg[a], n = clDeg[b], ra, rb},
  ra = Reverse[a]; rb = Reverse[b];
  Join[
    Table[PadRight[Join[ConstantArray[0, i], ra], m + n], {i, 0, n - 1}],
    Table[PadRight[Join[ConstantArray[0, i], rb], m + n], {i, 0, m - 1}]]];

clResultant[a_List, b_List] := Which[
  a === {} || b === {}, 0,
  clDeg[a] === 0 && clDeg[b] === 0, 1,
  clDeg[a] === 0, clLC[a]^clDeg[b],
  clDeg[b] === 0, clLC[b]^clDeg[a],
  True, Det[sylvesterMatrix[a, b]]];

(* the primitive integer form of a rational polynomial in v *)
primitiveIn[poly_, v_] := clTo[Last[clPrimitive[clOf[poly, v]]], v];

(* eliminate ey from p(ey) and an expression q in kx and ey *)
eliminateY[p_, q_] := Module[{pp, qq},
  pp = clOf[p /. kx -> ey, ey];
  qq = clOf[kExpand[q], ey];
  If[pp === {} || qq === {}, $Failed, kExpand[clResultant[pp, qq]]]];

(* The irreducible factor of poly that vanishes at value, or $Failed.

   Exactly one irreducible factor can vanish there, so the decision is made on
   the margin between the smallest scaled residual and the next one, at
   increasing precision.  When no precision separates them the answer is
   $Failed and kMinimalPolynomial falls back to the kernel's own function:
   guessing would be wrong, and confirming with an exact zero test would call
   the reduction this function is part of computing. *)
selectFactor[poly_, value_] := Catch[Module[
  {fl, prec = 60, v, res, attempt},
  If[poly === 0 || ! TrueQ[kPolynomialQ[poly, kx]], Throw[$Failed, ktag]];
  fl = Select[First /@ kFactorList[kExpand[poly]], Exponent[#, kx] >= 1 &];
  If[fl === {}, Throw[$Failed, ktag]];
  If[Length[fl] === 1, Throw[primitiveIn[First[fl], kx], ktag]];
  Do[
    (* kN, not N: the kernel's N of a non-real Root object costs ten
       seconds and more per root in Mathics *)
    v = kCheck[kN[value, prec], $Failed];
    If[! kFiniteNumberQ[v], Throw[$Failed, ktag]];
    (* the value zero: its minimal polynomial is the factor kx *)
    If[TrueQ[Abs[v] < 10^(-prec/2)] && MemberQ[fl, kx], Throw[kx, ktag]];
    res = scaledResidual[#, v, prec] & /@ fl;
    If[! AllTrue[res, kFiniteNumberQ[#] || # === Infinity &], Throw[$Failed, ktag]];
    (* a margin, for the same reason as in kRootIndex: the residual of the
       right factor is limited by the accuracy of the value, not by prec *)
    With[{k = nearestByMargin[res, 10^-8, 10^4]}, If[k =!= $Failed, Throw[primitiveIn[fl[[k]], kx], ktag]]];
    prec = 2 prec, {attempt, 2}];
  $Failed], ktag];

(* |f(v)| divided by the size of the largest term of f at v, so that the
   comparison does not depend on the scale of f. *)
scaledResidual[f_, v_, prec_] := Module[{c = clOf[f, kx], r, terms, scale, pw},
  pw = kPowerList[v, Length[c] - 1];   (* not v^(i - 1): machine precision for a complex v in Mathics *)
  terms = kCheck[Table[N[c[[i]] pw[[i]], prec], {i, Length[c]}], $Failed];
  If[! ListQ[terms] || ! AllTrue[terms, kFiniteNumberQ], Return[Infinity]];
  r = Total[terms];
  scale = Max[Abs /@ terms];
  If[! kFiniteNumberQ[r] || ! TrueQ[scale > 0], Return[Infinity]];
  Abs[r]/scale];

(* --- the grammar --- *)

(* An expression that is a polynomial in a single Root object r with rational
   coefficients -- which is what every coefficient of a decomposition over
   Q(r) looks like -- is handled by one resultant: with f the polynomial of r
   and g the expression reduced modulo f, the value is a root of
   Res_y(f(y), x - g(y)).  The general fold below would chain a resultant per
   operation and factor a polynomial of degree deg(f)^2 at each step; one
   such coefficient took 46 s that way. *)
singleRootPolynomialQ[e_] := Module[{roots = rootsIn[e]},
  Length[roots] === 1 && Head[roots[[1]]] === Root &&
    With[{g = e /. roots[[1]] -> ey}, TrueQ[kPolynomialQ[g, ey]] &&
      AllTrue[kCoefficientList[g, ey], kRationalQ]]];
(* {the Root object of e, its minimal polynomial in kx, the representative of
   e modulo it as a polynomial in ey}, or $Failed *)
singleRootData[e_] := Module[{r = First[rootsIn[e]], f, g},
  f = minPolyOfRoot[r];
  If[f === $Failed || Exponent[f, kx] < 1, Return[$Failed]];
  g = clMod[clOf[e /. r -> ey, ey], clOf[f /. kx -> ey, ey]];
  If[g === $Failed, $Failed, {r, f, clTo[g, ey]}]];
minPolyInSingleRoot[e_] := Module[{d = singleRootData[e], r, f, g, el},
  If[d === $Failed, Return[$Failed]];
  {r, f, g} = d;
  If[FreeQ[g, ey], Return[primitiveIn[Denominator[g] kx - Numerator[g], kx]]];
  el = eliminateY[f, kx - g];
  If[el === $Failed, $Failed, selectFactor[el, e]]];

minPolyOfTree[e_] := Which[
  ! kGaussianQ[e] && ! FreeQ[e, _Root] && singleRootPolynomialQ[e], minPolyInSingleRoot[e],
  kRationalQ[e], primitiveIn[Denominator[e] kx - Numerator[e], kx],
  Head[e] === Complex && kRationalQ[Re[e]] && kRationalQ[Im[e]],
    primitiveIn[kExpand[(kx - Re[e])^2 + Im[e]^2], kx],
  Head[e] === Root, minPolyOfRoot[e],
  Head[e] === Plus, minPolyOfFold[List @@ e, Plus],
  Head[e] === Times, minPolyOfFold[List @@ e, Times],
  Head[e] === Power && Length[e] === 2 && kRationalQ[e[[2]]],
    minPolyOfPower[e[[1]], e[[2]]],
  True, $Failed];

minPolyOfRoot[r_] := kMemo["minPolyOfRoot", r, minPolyOfRootCompute[r]];
minPolyOfRootCompute[r_] := With[{poly = rootFunctionPolynomial[r[[1]]]}, If[poly === $Failed, $Failed, selectFactor[poly, r]]];

(* fold a Plus or a Times one operand at a time, eliminating ey each time *)
minPolyOfFold[parts_List, op_] := Catch[Module[{p, acc, q, elim, i},
  p = minPolyOfTree[First[parts]];
  If[p === $Failed, Throw[$Failed, ktag]];
  acc = First[parts];
  Do[
    q = minPolyOfTree[parts[[i]]];
    If[q === $Failed, Throw[$Failed, ktag]];
    acc = op[acc, parts[[i]]];
    If[Exponent[q, kx] === 1,
      (* a rational operand r: u + r is a root of p(x - r), and u r of p(x/r);
         the coefficient arithmetic of the decompositions consists mostly of
         such steps, and a resultant for each of them was the dominant cost *)
      With[{r = -Coefficient[q, kx, 0]/Coefficient[q, kx, 1]},
        If[r === 0 && op === Times, Throw[primitiveIn[kx, kx], ktag]];
        p = primitiveIn[kExpand[If[op === Plus, p /. kx -> kx - r, p /. kx -> kx/r]], kx]],
      elim = If[op === Plus,
        eliminateY[p, q /. kx -> (kx - ey)],
        eliminateY[p, kExpand[ey^Exponent[q, kx] (q /. kx -> kx/ey)]]];
      If[elim === $Failed, Throw[$Failed, ktag]];
      p = selectFactor[elim, acc];
      If[p === $Failed, Throw[$Failed, ktag]]],
    {i, 2, Length[parts]}];
  p], ktag];

minPolyOfPower[base_, r_] := Catch[Module[
  {p = minPolyOfTree[base], num = Numerator[r], den = Denominator[r], q},
  If[p === $Failed, Throw[$Failed, ktag]];
  If[den > 1,
    p = selectFactor[kExpand[p /. kx -> kx^den], base^(1/den)];
    If[p === $Failed, Throw[$Failed, ktag]]];
  If[Abs[num] =!= 1,
    q = eliminateY[p, kx - ey^Abs[num]];
    If[q === $Failed, Throw[$Failed, ktag]];
    p = selectFactor[q, base^(Abs[num]/den)];
    If[p === $Failed, Throw[$Failed, ktag]]];
  If[num < 0, p = primitiveIn[clTo[Reverse[clOf[p, kx]], kx], kx]];
  p], ktag];

(* ------------------------------------------------------------------ *)
(* 0.5b  Numerical values: N for Root objects and complex numbers     *)
(* ------------------------------------------------------------------ *)

(* Two properties of Mathics3 10.0.1 numerics decide what this section
   supplies; both were measured, neither shows in Precision or Accuracy.

   1. N[Root[f, k], p] is correct to p digits, but takes four to ten seconds
      per non-real root, at machine precision as well (a real root takes
      0.05 s); the Galois engine evaluates every root of every resolvent.

   2. For a complex number z carrying p digits, z^n, 1/z, z/w, Conjugate[z],
      Sqrt[z], Exp[z], Log[z], Arg[z], and N[Sqrt[q], p] for a Gaussian
      rational q, are all computed at machine precision and returned with
      precision p.  Sums, products, Dot, Total, Re, Im, Abs and Norm are
      exact, and so is every real-argument function used below: real x^q
      (with the principal value for a negative base), Exp, Log, Cos, Sin and
      the two-argument ArcTan.  The Galois engine (section 2) rounds traces
      of such values to integers, and the radical descent (section 3)
      verifies a candidate to 150 digits, so either would take noise for a
      result on that kernel.

   So on a kernel whose complex numerics fail the probe "ComplexPower":

     * kN[e, p] evaluates e bottom-up with sums, products, and complex
       powers in polar form from Abs and ArcTan[re, im];
     * a Root object evaluates with every other root of its polynomial:
       all roots at machine precision as the eigenvalues of the companion
       matrix, each polished by Newton's method at the working precision,
       the residual |f(z)| checked, and the list put into the Wolfram
       kernel's root order (rootOrderedQ); the kernel's own N[Root, p] is
       the fallback when any of that fails;
     * kPowerList[z, m] and kDivide[a, b] are what the engine uses in place
       of z^Range[0, m] and a/b on such values.

   Values of roots are memoised per polynomial, index and precision. *)

kAssociateTo[$kNative, "ComplexPower" -> probe[
  Module[{z = N[3/7 + 2 I/11, 40]},
    TrueQ[Abs[z^6 - (3/7 + 2 I/11)^6] < 10^-30] &&
    TrueQ[Abs[N[Sqrt[3/7 + 2 I/11], 40]^2 - (3/7 + 2 I/11)] < 10^-30]], True]];

(* polynomial value by Horner's rule, ascending coefficients *)
kHorner[c_List, z_] := Fold[#1 z + #2 &, 0, Reverse[c]];

If[kNativeQ["ComplexPower"],
  kPowerList[z_, m_Integer] := Prepend[z^Range[1, m], 1];   (* not 0^0 for a zero root *)
  kDivide[a_, b_] := a/b;
  kIntPower[z_, n_Integer] := z^n,
  kPowerList[z_, m_Integer] := FoldList[#1 z &, 1, Range[m]];
  kInverse[z_] := If[TrueQ[Im[z] == 0], 1/Re[z], (Re[z] - I Im[z])/(Re[z]^2 + Im[z]^2)];
  kDivide[a_, b_] := a kInverse[b];
  (* repeated multiplication: a squaring written as #1 #1 is Power[#1, 2]
     the moment the function is defined, and hits the kernel's Power *)
  kIntPower[z_, n_Integer] := Which[n == 0, 1, n < 0, kIntPower[kInverse[z], -n],
    True, Fold[#1 z &, 1, Range[n]]]];

(* Newton polishing of one root from an exact seed, at precision prec *)
polishRoot[c_List, seed_, prec_] := Catch[Module[{n = clDeg[c], z, d, k, work = prec + 20, r, fz},
  z = N[seed, work];
  d = Rest[c] Range[1, n];
  Do[
    r = kDivide[kHorner[c, z], kHorner[d, z]];
    If[! kFiniteNumberQ[r], Throw[$Failed, ktag]];
    z = z - r;
    If[TrueQ[Abs[r] < 10^(-prec - 5)], Break[]],
    {k, 60}];
  fz = kHorner[c, z];
  If[! kFiniteNumberQ[z] || ! TrueQ[Abs[fz] < 10^(-prec) Max[Abs[c]] Max[1, Abs[z]]^n],
    $Failed, z]], ktag];

(* All roots of an integer polynomial at machine precision: the eigenvalues
   of the companion matrix.  Eigenvalues of a machine-number matrix is
   complete and fast here (degree 12 in 4 s, degree 20 in 17 s), where the
   kernel's own N[Root[f, k]] isolates one non-real root in four to ten
   seconds, Solve[N[p] == 0, x] takes forty seconds at degree 9, and a
   Durand-Kerner iteration written in the language sixty at degree 6. *)
SetAttributes[galoisPrint, HoldAll];       (* the trace of the numerics and the Galois engine *)
galoisPrint[args__] := If[TrueQ[$galoisDebug], Print[args]];

machineRoots[c_List] := Module[{n = clDeg[c], cm, m, ev, s, cs},
  If[n < 1, Return[$Failed]];
  galoisPrint["machineRoots: degree ", n, " coefficients ", Short[c, 1]];
  cm = N[c/Last[c]];
  (* balanced: with x = s y and s the root-radius bound every entry of the
     companion matrix is at most 1 in size.  On the raw coefficients of a
     degree-12 resolvent (up to 2 10^14) the eigenvalue solver raised
     SymPy's PrecisionExhausted, which no Quiet or Check catches. *)
  s = Max[Table[Abs[cm[[i]]]^(1/(n - i + 1)), {i, n}]];
  If[! TrueQ[s > 0], s = 1.];
  cs = Table[cm[[i]]/s^(n - i + 1), {i, n}];
  m = Table[Which[j === n, -cs[[i]], i === j + 1, 1., True, 0.], {i, n}, {j, n}];
  ev = kCheck[Eigenvalues[m], $Failed];
  If[! ListQ[ev] || Length[ev] =!= n || ! AllTrue[ev, kFiniteNumberQ], $Failed, s ev]];

(* Wolfram's order of the roots of a polynomial: the real roots increasing,
   then the non-real roots by increasing real part, then by increasing
   |Im|, the root of negative imaginary part first in a conjugate pair.
   Real parts (and |Im|) closer than tol are the same value. *)
rootOrderedQ[a_, b_, tol_] := Which[
  Abs[Re[a] - Re[b]] > tol, Re[a] < Re[b],
  Abs[Abs[Im[a]] - Abs[Im[b]]] > tol, Abs[Im[a]] < Abs[Im[b]],
  True, Im[a] < Im[b]];

(* The machine-precision roots in the Wolfram order, or $Failed when two
   ordering keys are too close for machine precision to order them.  This is
   what a Root object evaluates to at machine precision (the kernel's own
   N[Root] takes four to ten seconds per non-real root) and what decides a
   root index when the margins allow. *)
machineRootsOrdered[c_List] := kMemo["machineRootsOrdered", c, machineRootsOrderedCompute[c]];
(* the real roots increasing, then the non-real roots in the Wolfram order,
   as {reals, complexes}; $Failed when the non-real roots do not pair up *)
splitOrderedRoots[vals_List, tol_] := Module[{reals, complexes},
  reals = Sort[Re /@ Select[vals, Abs[Im[#]] < tol &]];
  complexes = Sort[Select[vals, Abs[Im[#]] >= tol &], rootOrderedQ[#1, #2, tol] &];
  If[OddQ[Length[complexes]], $Failed, {reals, complexes}]];

(* an exact seed for polishing: the machine value rounded, not Rationalized --
   with a tolerance Mathics' Rationalize can hand back the machine number
   itself, and N[machineReal, 100] stays a machine number *)
roundSeed[z_, scale_] := If[Abs[Im[z]] < 10^-9 scale,
  Round[Re[z] 10^14]/10^14, Round[Re[z] 10^14]/10^14 + I Round[Im[z] 10^14]/10^14];

machineRootsOrderedCompute[c_List] := Catch[Module[{m, scale, tol, split, reals, complexes, i, a, b},
  m = machineRoots[c];
  If[m === $Failed, Throw[$Failed, ktag]];
  scale = Max[1, Max[Abs[m]]]; tol = 10^-9 scale;
  split = splitOrderedRoots[m, tol];
  If[split === $Failed, Throw[$Failed, ktag]];
  {reals, complexes} = split;
  Do[If[Abs[reals[[i]] - reals[[i + 1]]] < 10^4 tol, Throw[$Failed, ktag]], {i, Length[reals] - 1}];
  Do[a = complexes[[i]]; b = complexes[[i + 1]];
    If[Abs[Re[a] - Re[b]] < 10^4 tol && Abs[Abs[Im[a]] - Abs[Im[b]]] < 10^4 tol && Abs[Im[a] - Im[b]] < 10^4 tol,
      Throw[$Failed, ktag]], {i, Length[complexes] - 1}];
  Join[reals, complexes]], ktag];

kRootValues[c_List, prec_Integer] := kMemo["rootValues", {c, prec}, rootValuesCompute[c, prec]];
rootValuesCompute[c_List, prec_] := Module[{n = clDeg[c], m, scale, seeds, polished, tol, i, j},
  m = machineRoots[c];
  If[m === $Failed, Return[$Failed]];
  scale = Max[1, Max[Abs[m]]];
  seeds = roundSeed[#, scale] & /@ m;
  polished = Quiet[polishRoot[c, #, prec] & /@ seeds];
  If[MemberQ[polished, $Failed],
    galoisPrint["rootValues: polishing failed for ", Short[c, 1], " at ", prec, " seeds ", seeds];
    Return[$Failed]];
  tol = 10^(-Floor[prec/2]) scale;
  (* two seeds converging to one root: a repeated root, or a lost one *)
  Do[If[Abs[polished[[i]] - polished[[j]]] < tol, Return[$Failed]], {i, n}, {j, i + 1, n}];
  Replace[splitOrderedRoots[polished, tol], {reals_, complexes_} :> Join[reals, complexes]]];

(* the value of Root[f, k] at precision prec *)
kRootValue[r_Root, prec_] := Module[{poly = rootFunctionPolynomial[r[[1]]], c, vals},
  If[poly === $Failed || Length[r] < 2 || ! IntegerQ[r[[2]]], Return[N[r, prec]]];
  c = kCoefficientList[poly, kx];
  If[! AllTrue[c, kRationalQ] || r[[2]] < 1, Return[N[r, prec]]];
  c = clearDenominators[c];
  vals = If[! IntegerQ[prec] || prec <= 16, machineRootsOrdered[c], kRootValues[c, prec]];
  If[ListQ[vals] && r[[2]] <= Length[vals], Return[vals[[r[[2]]]]]];
  (* the polished list failed (a repeated root, a lost root, two ordering
     keys too close): polish this one root from its machine value; the
     kernel's own N[Root] is the last resort and costs ten seconds and more
     per non-real root *)
  galoisPrint["kRootValue: no ordered values for ", Short[c, 1], " index ", r[[2]], " at ", prec];
  vals = machineRootsOrdered[c];
  If[ListQ[vals] && r[[2]] <= Length[vals] && IntegerQ[prec] && prec > 16,
    With[{m = vals[[r[[2]]]]},
      With[{z = Quiet[polishRoot[c, roundSeed[m, Max[1, Abs[m]]], prec]]},
        If[z =!= $Failed, Return[N[z, prec]]]]]];
  galoisPrint["kRootValue: native N for ", Short[r, 1], " at ", prec];
  N[r, prec]];

(* the bottom-up evaluator; w is the working precision *)
numValue[r_Root, w_] := kRootValue[r, w];
numValue[x_Integer | x_Rational | x_Real, w_] := N[x, w];
numValue[Complex[a_, b_], w_] := N[a, w] + I N[b, w];
numValue[e_List, w_] := numValue[#, w] & /@ e;
(* e_Plus, not Plus[a__]: in Mathics the sequence pattern under a Flat
   head binds a to the whole sum, and the rule loses to numValue[e_, w_] *)
numValue[e_Plus, w_] := Plus @@ (numValue[#, w] & /@ (List @@ e));
numValue[e_Times, w_] := Times @@ (numValue[#, w] & /@ (List @@ e));
numValue[Power[b_, n_Integer], w_] := kIntPower[numValue[b, w], n];
numValue[Power[b_, q_], w_] := numPower[numValue[b, w], numValue[q, w]];
numValue[Exp[a_], w_] := numExp[numValue[a, w]];
numValue[Log[a_], w_] := numLog[numValue[a, w]];
numValue[Abs[a_], w_] := Abs[numValue[a, w]];
numValue[Re[a_], w_] := Re[numValue[a, w]];
numValue[Im[a_], w_] := Im[numValue[a, w]];
numValue[Conjugate[a_], w_] := With[{v = numValue[a, w]}, Re[v] - I Im[v]];
numValue[e_, w_] := N[e, w];

numLog[v_] := Log[Abs[v]] + I ArcTan[Re[v], Im[v]];
numExp[u_] := Exp[Re[u]] (Cos[Im[u]] + I Sin[Im[u]]);
(* the principal value: a real base is handed to the kernel, which gets a
   negative base right; otherwise polar form *)
numPower[v_, q_] := Which[
  ! kFiniteNumberQ[v] || ! kFiniteNumberQ[q], N[Power[v, q]],
  TrueQ[Im[v] == 0] && TrueQ[Im[q] == 0], Re[v]^Re[q],
  TrueQ[Im[q] == 0], Abs[v]^Re[q] (Cos[Re[q] ArcTan[Re[v], Im[v]]] + I Sin[Re[q] ArcTan[Re[v], Im[v]]]),
  True, numExp[q numLog[v]]];

(* N for expressions that may contain Root objects or complex values *)
If[kNativeQ["ComplexPower"],
  kN[e_] := N[e];
  kN[e_, prec_] := N[e, prec],
  kN[e_] := If[FreeQ[e, _Root], N[e], N[numValue[e, 16]]];
  kN[e_, MachinePrecision] := kN[e];
  kN[e_, prec_] := If[FreeQ[e, _Root | _Complex | _Power | Log], N[e, prec],
    N[numValue[e, prec + 10], prec]]];

(* whether the values above deliver the digits they claim; decides the
   Galois engine's availability (section 2) *)
kAssociateTo[$kNative, "RootPrecision" -> probe[
  Module[{r = Root[#^6 + 112 #^3 + 27436 &, 5], v},
    v = kN[27436 + 112 r^3 + r^6, 60];
    kFiniteNumberQ[v] && TrueQ[Abs[v] < 10^-40]], True]];
(* ------------------------------------------------------------------ *)
(* 0.5  Exact algebraic numbers                                       *)
(* ------------------------------------------------------------------ *)

(* kRationalQ, kFiniteNumberQ and kGaussianQ are defined before section 0.5a,
   whose evaluator and its load-time probe need them. *)

kRootObject[poly_, v_, k_Integer] := Root[Function @@ {poly /. v -> Slot[1]}, k];

nativeMinimalPolynomial[a_, v_] := Module[{p},
  If[! kNativeQ["MinimalPolynomial"], Return[$Failed]];
  (* SymPy raises an uncatchable exception for a non-algebraic argument *)
  If[! kNativeQ["RootReduce"] && ! algebraicShapeQ[a], Return[$Failed]];
  If[! FreeQ[a, _Root], galoisPrint["nativeMinimalPolynomial on ", Short[a, 1]]];
  p = kCheck[MinimalPolynomial[a, v], $Failed];
  If[Head[p] === MinimalPolynomial || ! TrueQ[kPolynomialQ[p, v]], $Failed, p]];

If[kNativeQ["RootReduce"],
  (* the Wolfram kernel: its own MinimalPolynomial is complete and fast *)
  kMinimalPolynomial[a_, v_] := nativeMinimalPolynomial[a, v],
  (* elsewhere: elimination first, the kernel's own function as the fallback *)
  kMinimalPolynomial[a_, v_] := Module[{p},
    (* the kernel's own function is fast and exact on simple radicals, but
       took four minutes on the nested radical (2^(1/3) - 1)^(1/3) and did
       not finish on sums of Root objects; it is given a few seconds, then
       elimination takes over *)
    If[FreeQ[a, _Root | _AlgebraicNumber],
      p = TimeConstrained[nativeMinimalPolynomial[a, v], 3 $kTimeScale, $Failed];
      If[p =!= $Failed, Return[p]]];
    p = minPolyOfTree[a];
    (* no native fallback for an expression with Root objects: SymPy's
       minimal_polynomial refines every non-real CRootOf for minutes *)
    If[p === $Failed, Return[If[FreeQ[a, _Root], nativeMinimalPolynomial[a, v], $Failed]]];
    kExpand[p /. kx -> v]]];

(* The unique root index of mp at which the value of z is attained.

   The decision is made on the margin between the nearest root and the next
   nearest, not on an absolute distance tied to the working precision: on
   Mathics kN[Root[f, k], p] is accurate to about eleven digits whatever p it
   reports, so a threshold of 10^(-p/3) never passed, precision was escalated
   to 540 digits, and one selection took minutes.  There is no exact
   confirmation: the kernel's PossibleZeroQ on the difference of two distinct
   Root objects is the computation SymPy does not finish, and the canonical
   reduction would re-enter this selection.  Two roots of an irreducible
   integer polynomial closer than the margin would be needed to fool it; the
   exit is a tagged Throw, since Return[expr, Module] is not implemented in
   Mathics. *)
(* The index of the smallest distance when it is below tol and the next
   smallest is more than ratio times larger; $Failed otherwise.  The root
   index selection and the factor selection both decide this way. *)
nearestByMargin[dists_List, tol_, ratio_, floor_: 0] := Module[{ord = kOrdering[dists]},
  If[TrueQ[dists[[ord[[1]]]] < tol] &&
      (Length[dists] === 1 || TrueQ[dists[[ord[[2]]]] > Max[ratio dists[[ord[[1]]]], floor]]), ord[[1]], $Failed]];
(* the two roots of c0 + c1 x + c2 x^2, the + sign first *)
quadraticRoots[{c0_, c1_, c2_}] := (-c1 + {1, -1} Sqrt[c1^2 - 4 c2 c0])/(2 c2);

kRootIndex[mp_, z_, degree_Integer] := Catch[Module[
  {prec = 60, zv, vals, attempt, c},
  If[degree === 1, Throw[1, ktag]];
  (* machine precision first: the ordered eigenvalues and the evaluator's
     machine value of z decide when the nearest root is a million times
     closer than the next; the polished values below decide otherwise *)
  c = clOf[mp, kx];
  If[AllTrue[c, kRationalQ],
    vals = machineRootsOrdered[clearDenominators[c]];
    zv = kCheck[kN[z], $Failed];
    If[ListQ[vals] && Length[vals] === degree && kFiniteNumberQ[zv],
      With[{k = nearestByMargin[Abs[vals - zv], 10^-7 Max[1, Abs[zv]], 10^6]}, If[k =!= $Failed, Throw[k, ktag]]]];
    galoisPrint["index: machine order ", If[ListQ[vals], "ambiguous margins", "unavailable"], ", polishing"]];
  Do[
    zv = kCheck[kN[z, prec], $Failed];
    If[! kFiniteNumberQ[zv], Throw[$Failed, ktag]];
    vals = kCheck[Table[kN[kRootObject[mp, kx, j], prec], {j, degree}], $Failed];
    If[! ListQ[vals] || ! AllTrue[vals, kFiniteNumberQ], Throw[$Failed, ktag]];
    With[{k = nearestByMargin[Abs[vals - zv], 10^-9 Max[1, Abs[zv]], 10^6]}, If[k =!= $Failed, Throw[k, ktag]]];
    prec = 2 prec, {attempt, 2}];
  $Failed], ktag];

If[kNativeQ["RootReduce"],
  kRootReduce[e_] := RootReduce[e],
  (* Mathics: MinimalPolynomial is native and exact; the canonical form is the
     rational value in degree 1, the classical radical in degree 2 (matching
     the Wolfram kernel, which leaves quadratic surds in radical form), and a
     Root object above.  The branch is selected numerically and confirmed by
     the exact zero test PossibleZeroQ. *)
  kRootReduce[e_] := Which[
    kGaussianQ[e], e,
    ! FreeQ[e, _Real], e,
    (* a root of unity written as an exponential: the Wolfram kernel reduces
       Exp[2 Pi I/5] to a Root object of the cyclotomic polynomial *)
    rootOfUnityFormQ[e], rootOfUnityReduce[e],
    (* each distinct trigonometric atom is reduced once and its Root object
       substituted, so that a polynomial in one such atom stays a polynomial
       in one Root object (the cheap path) instead of a fresh elimination
       through the root of unity for every coefficient *)
    (* a root of unity inside an expression: the atom becomes its Root
       object (or radical) first *)
    ! FreeQ[e, _?rootOfUnityFormQ] && ! rootOfUnityFormQ[e],
      kRootReduce[kExpand[e /. t_?rootOfUnityFormQ :> kMemo["rootOfUnity", t, rootOfUnityReduce[t]]]],
    ! FreeQ[e, _?trigOfRationalPiQ],
      kRootReduce[kExpand[e /. t_?trigOfRationalPiQ :> trigAtomReduce[t]]],
    (* a polynomial in one Root object: its representative modulo the
       minimal polynomial, in milliseconds (elimination and the numerical
       root index took seconds per coefficient of a decomposition) *)
    True, kMemo["rootReduce", e, rootReduceByElimination[e]]];
  (* The unique representative of degree below deg f of a polynomial in the
     Root object r of the irreducible f, by one polynomial remainder: it
     decides the exact zero test in milliseconds.  It is not the canonical
     form -- that stays the Root object, which does not depend on which
     generator the expression happened to contain -- so kRootReduce does
     not return it. *)
  singleRootReduce[e_] := Module[{d = singleRootData[e], r, f, v},
    If[d === $Failed, Return[$Failed]];
    {r, f, v} = d;
    Which[
      FreeQ[v, ey], v,
      Exponent[f, kx] <= 2, kExpand[v /. ey -> kRootReduce[r]],
      True, kExpand[v /. ey -> r]]];
  (* degree three and up: in degree one and two the canonical form is the
     rational or the radical, as in the Wolfram kernel *)
  irreducibleRootFunctionQ[f_] := With[{poly = rootFunctionPolynomial[f]},
    poly =!= $Failed && Exponent[poly, kx] >= 3 &&
      AllTrue[kCoefficientList[poly, kx], kRationalQ] && kIrreduciblePolynomialQ[poly]];
  (* E^(I Pi r) with r rational, tested structurally: a pattern Complex[0, _]
     does not match the atomic Complex in Mathics *)
  rootOfUnityFormQ[e_] := Head[e] === Power && Length[e] === 2 && e[[1]] === E &&
    Head[e[[2]]] === Times && Length[e[[2]]] === 2 && e[[2, 2]] === Pi &&
    Head[e[[2, 1]]] === Complex && Re[e[[2, 1]]] === 0 && kRationalQ[Im[e[[2, 1]]]];
  rootOfUnityReduce[e_] := Module[{r = Im[First[e[[2]]]]/2, q, mp, k},
    (* e = E^(2 Pi I r) (Exp[x] is Power[E, x]); a primitive root of unity of order Denominator[r] *)
    q = Denominator[r];
    If[q === 1, Return[1]]; If[q === 2, Return[-1]];
    mp = kCyclotomic[q, kx];
    k = kRootIndex[mp, e, Exponent[mp, kx]];
    If[k === $Failed, e, kRootReduce[kRootObject[mp, kx, k]]]];
  rootReduceByElimination[e_] := Module[{mp, c, deg, k, r, t0 = AbsoluteTime[]},
    mp = kMinimalPolynomial[e, kx];
    galoisPrint["reduce: minimal polynomial of ", Short[e, 1], " in ", Round[AbsoluteTime[] - t0, 0.01], " s, degree ", Exponent[mp, kx]];
    If[mp === $Failed, Return[e]];
    c = clOf[mp, kx]; deg = clDeg[c];
    Which[
      deg < 1, Return[e],
      deg === 1, Return[Cancel[-c[[1]]/c[[2]]]],
      deg === 2,
        (* the two candidates differ by Sqrt of the discriminant, so forty
           digits decide; PossibleZeroQ took thirty seconds here *)
        r = With[{v = kN[e, 40]},
          Select[kExpand /@ quadraticRoots[c], TrueQ[Abs[kN[#, 40] - v] < 10^-20 Max[1, Abs[v]]] &]];
        If[Length[r] === 1, Return[First[r]]]];
    k = kRootIndex[mp, e, deg];
    galoisPrint["reduce: index ", k, " after ", Round[AbsoluteTime[] - t0, 0.01], " s"];
    If[k === $Failed, e, kRootObject[mp, kx, k]]]];

(* An exact zero test.  The canonical reduction decides it in the Wolfram
   kernel; on a kernel whose RootReduce replacement can leave an expression
   alone, the exact algebraic zero test decides it as well. *)
kExactZeroQ[e_] := If[kNativeQ["RootReduce"],
  TrueQ[Quiet[kRootReduce[e]] === 0],
  (* Mathics: its exact zero test is fast on radicals and decides them
     through SymPy; elimination is the second opinion and the only one for
     an expression it cannot handle *)
  Which[
    (* a machine-precision value far from zero settles it *)
    With[{v = kCheck[kN[e], $Failed]}, kFiniteNumberQ[v] && TrueQ[Abs[v] > 10^-6]], False,
    Head[e] =!= Root && singleRootPolynomialQ[e] && singleRootReduce[e] =!= $Failed,
    singleRootReduce[e] === 0,
    (* PossibleZeroQ hands an expression with Root objects to SymPy's
       minimal_polynomial, which refines every non-real CRootOf for a minute
       or more; the elimination decides those *)
    ! FreeQ[e, _Root], TrueQ[Quiet[kRootReduce[e]] === 0],
    True, TrueQ[Quiet[kPossibleZeroQ[e]]] || TrueQ[Quiet[kRootReduce[e]] === 0]]];

If[kNativeQ["NumericQRoot"],
  kNumericQ[e_] := NumericQ[e],
  kNumericQ[e_] := TrueQ[NumericQ[e]] ||
    (! FreeQ[e, _Root | _AlgebraicNumber] &&
      TrueQ[NumericQ[e /. {r_Root :> 1, a_AlgebraicNumber :> 1}]])];

If[kNativeQ["AlgebraicsRoot"],
  kAlgebraicQ[e_] := TrueQ[Element[e, Algebraics]],
  (* structural: Mathics answers Element[e, Algebraics] by asking SymPy for a
     minimal polynomial, and for Pi or Sin[1] that raises a Python exception
     no Quiet or Check can catch *)
  kAlgebraicQ[e_] := algebraicShapeQ[e]];
(* A trigonometric function of a rational multiple of Pi is an algebraic
   number; the Wolfram kernel's RootReduce turns it into a Root object, and
   on other kernels trigToRootsOfUnity writes it through the root of unity
   E^(I Pi r) -- Cos[r Pi] = (z + z^(n - 1))/2, z^n = 1 -- for the reduction
   of section 0.5 to canonicalise. *)
rationalPiMultipleQ[a_] := a === Pi || (Head[a] === Times && Length[a] === 2 && a[[2]] === Pi && kRationalQ[a[[1]]]);
trigOfRationalPiQ[e_] := MemberQ[{Cos, Sin, Tan, Cot, Sec, Csc}, Head[e]] && Length[e] === 1 && rationalPiMultipleQ[First[e]];
trigAtomReduce[t_] := kMemo["trigAtom", t, kRootReduce[kExpand[trigToRootsOfUnity[t]]]];
trigToRootsOfUnity[e_] := e /. t_?trigOfRationalPiQ :>
  With[{z = kRootReduce[E^(I First[t])], n = 2 Denominator[First[t]/Pi]},
    Switch[Head[t],
      Cos, (z + z^(n - 1))/2, Sin, (z - z^(n - 1))/(2 I),
      Tan, (z - z^(n - 1))/(I (z + z^(n - 1))), Cot, I (z + z^(n - 1))/(z - z^(n - 1)),
      Sec, 2/(z + z^(n - 1)), Csc, 2 I/(z - z^(n - 1))]];

(* an expression built from the leaves leafQ admits by Plus, Times and Power
   with a rational exponent; the radical grammar of section 5 and the
   algebraic shape below are the two instances *)
algebraicGrammarQ[e_, leafQ_] := Which[
  leafQ[e], True,
  AtomQ[e], False,
  Head[e] === Plus || Head[e] === Times, AllTrue[List @@ e, algebraicGrammarQ[#, leafQ] &],
  Head[e] === Power && Length[e] === 2, kRationalQ[e[[2]]] && algebraicGrammarQ[e[[1]], leafQ],
  True, False];
(* an expression built from Gaussian rationals, Root and AlgebraicNumber
   objects and trigonometric values by Plus, Times and rational Power *)
algebraicShapeQ[e_] := algebraicGrammarQ[e,
  kGaussianQ[#] || Head[#] === Root || Head[#] === AlgebraicNumber || trigOfRationalPiQ[#] &];

If[kNativeQ["ToRadicals"],
  kToRadicals[e_] := ToRadicals[e],
  kToRadicals[e_] := e /. r_Root :> radicalOfRoot[r]];
radicalOfRoot[r_Root] := Module[{poly = rootFunctionPolynomial[r[[1]]], deg, sols, sel},
  If[poly === $Failed, Return[r]];
  deg = Exponent[poly, kx];
  If[deg > 4, Return[r]];
  sols = kCheck[kx /. Solve[poly == 0, kx], $Failed];
  If[! ListQ[sols], Return[r]];
  sel = Select[sols, TrueQ[Quiet[PossibleZeroQ[# - r]]] &];
  If[sel === {}, r, First[sel]]];

(* Exact zero test.  In the Wolfram kernel PossibleZeroQ is asked for the
   exact-algebraics method; Mathics does not know the option and would leave
   the call unevaluated, but its default already decides exact algebraic
   differences through SymPy. *)
If[kNativeQ["RootReduce"],
  kPossibleZeroQ[e_] := PossibleZeroQ[e, Method -> "ExactAlgebraics"],
  kPossibleZeroQ[e_] := PossibleZeroQ[e]];

(* Simplify applied to an expression containing a Root object aborts the
   Mathics 10.0.1 evaluator with a Python AssertionError, which no Check or
   Quiet can catch, so it is never reached on a kernel without RootReduce.
   The options are dropped there as well; Mathics does not accept them. *)
If[kNativeQ["RootReduce"],
  kSimplify[e_] := Simplify[e, Assumptions -> True, TimeConstraint -> 5],
  kSimplify[e_] := If[FreeQ[e, _Root | _AlgebraicNumber], kCheck[Simplify[e], e], e]];

(* Factor of an exact algebraic expression, as a proposal only: every caller
   certifies the result against its input before accepting it. *)
If[kNativeQ["RootReduce"],
  kFactor[e_] := Factor[e],
  kFactor[e_] := If[FreeQ[e, _Root | _AlgebraicNumber], kCheck[Factor[e], e], e]];

(* Factorisation over an extension.  Without it a polynomial is reported
   irreducible, which costs the methods that look for a Kummer multiplier by
   splitting x^k - rho over the radicals of rho their candidates; every other
   method, and every certification, is unaffected. *)
If[kNativeQ["FactorList"] && kNativeQ["FactorExtension"],
  kFactorListExtension[p_, ext_] := FactorList[p, Extension -> ext],
  kFactorListExtension[p_, ext_] := {{p, 1}}];

(* PolynomialGCD over an extension.  The gcd over the rationals divides it, so
   the fallback proposes fewer candidates and never a wrong one. *)
If[kNativeQ["FactorExtension"],
  kPolynomialGCDExtension[a_, b_] := PolynomialGCD[a, b, Extension -> Automatic],
  kPolynomialGCDExtension[a_, b_] := kPolynomialGCD[a, b]];

(* Solve, in the two forms the package needs.  Mathics solves up to degree 4
   and returns Root objects above it, but knows neither the Cubics/Quartics
   options nor a solution domain. *)
If[kNativeQ["RootReduce"],
  kSolveRadicals[eq_, v_] := Solve[eq, v, Cubics -> True, Quartics -> True],
  kSolveRadicals[eq_, v_] := Solve[eq, v]];
If[kNativeQ["RootReduce"],
  kSolveRationals[eqs_, vars_] := Solve[eqs, vars, Rationals],
  kSolveRationals[eqs_, vars_] := Module[{sol = kCheck[Solve[eqs, vars], $Failed]},
    If[! ListQ[sol], $Failed,
      Select[sol, ListQ[#] && AllTrue[#, MatchQ[#, _ -> _?kRationalQ] &] &]]]];

(* The index of the smallest entry: Ordering[list, 1] gives it as a
   one-element list, which Mathics does not implement at all. *)
kOrderingFirst[l_List] := First[kOrdering[l]];

(* RandomChoice[list] gives the chosen element in the Wolfram kernel and a
   one-element list in Mathics 10.0.1.  The Galois engine draws a random
   integer weight with it, and a one-element list silently turned the weight,
   the primitive element and every conjugate that followed into lists. *)
If[kNativeQ["RandomChoiceScalar"],
  kRandomChoice[l_] := RandomChoice[l],
  kRandomChoice[l_] := First[RandomChoice[l]]];

(* The declared option names of a symbol.  Mathics 10.0.1 turns a string
   option name into a symbol when Options[head] = {...} is assigned, and
   returns the options as RuleDelayed, so Options[head] does not give the
   declared names back; OptionValue does accept either form.  Every option
   read this way is declared with a string name. *)
If[kNativeQ["OptionNames"],
  kOptionNames[head_] := First /@ Options[head],
  kOptionNames[head_] := Replace[First /@ Options[head], s_Symbol :> SymbolName[s], {1}]];

(* The default option values of a symbol, as an association keyed by the
   declared names.  Association @@ Options[head] would be keyed by whatever
   the kernel stored, which is not the same thing. *)
kDefaultConfig[head_] :=
  Association @@ Table[n -> OptionValue[head, {}, n], {n, kOptionNames[head]}];

(* Decompose and AlgebraicDecompose use the same outermost-first order, so the
   package's own functional decomposition supplies the operation directly.
   AlgebraicDecompose normalises every component after the first to be monic
   with zero constant term; Decompose does not promise that, and no caller
   relies on the unnormalised form. *)
If[kNativeQ["Decompose"],
  kDecompose[p_, v_] := Decompose[p, v],
  kDecompose[p_, v_] := Module[{r = kCheck[AlgebraicDecompose[p, v], $Failed]},
    If[ListQ[r] && ! kFailureQ[r], r, {p}]]];

If[kNativeQ["LatticeReduce"],
  kLatticeReduce[m_] := LatticeReduce[m],
  kLatticeReduce[m_List] := lllReduce[m]];

(* Textbook LLL with exact rational Gram-Schmidt; the package uses it only to
   find a short vector in a small integer lattice, so a plain implementation
   is enough.  Rows are replaced with ReplacePart rather than assigned to:
   part assignment through a list of indices (b[[{i, j}]] = b[[{j, i}]])
   aborts Mathics 10.0.1 with a Python AttributeError, and assignment through
   a negative index silently writes the wrong element there. *)
lllReduce[basis_List] := Module[
  {b = basis, n = Length[basis], mu, B, k = 2, i, q, steps = 0, cap},
  If[n < 2 || ! MatrixQ[basis, kRationalQ], Return[b]];
  cap = 200 n^2;
  {mu, B} = gramData[b];
  While[k <= n && steps++ < cap,
    Do[q = Round[mu[[k, i]]];
      If[q =!= 0, b = ReplacePart[b, k -> b[[k]] - q b[[i]]]; {mu, B} = gramData[b]],
      {i, k - 1, 1, -1}];
    If[TrueQ[B[[k]] >= (3/4 - mu[[k, k - 1]]^2) B[[k - 1]]],
      k++,
      b = ReplacePart[b, {k - 1 -> b[[k]], k -> b[[k - 1]]}];
      {mu, B} = gramData[b];
      k = Max[2, k - 1]]];
  b];

(* The Gram-Schmidt coefficients mu[[i,j]] and the squared norms B[[i]] of the
   orthogonalised rows, all exact. *)
gramData[b_List] := Module[{n = Length[b], bstar = b, mu, i, j, d},
  mu = Table[0, {n}, {n}];
  Do[Do[d = bstar[[j]] . bstar[[j]];
      mu[[i, j]] = If[d === 0, 0, (b[[i]] . bstar[[j]])/d];
      bstar = ReplacePart[bstar, i -> bstar[[i]] - mu[[i, j]] bstar[[j]]],
      {j, 1, i - 1}], {i, n}];
  {mu, Table[bstar[[i]] . bstar[[i]], {i, n}]}];

(* An integer relation among numerical values, as a proposal.  Wolfram's
   FindIntegerNullVector is itself a heuristic and the one caller certifies
   every candidate it leads to exactly, so a relation that does not hold costs
   one reduction and nothing else.  The fallback scales the values to integers,
   LLL-reduces the lattice spanned by (e_i, scaled v_i), and accepts the
   shortest row whose last entry is small enough for the relation to be
   plausible.  It declines more than twelve values: the exact rational
   Gram-Schmidt below is not fast enough for a larger lattice, and no caller
   needs one. *)
If[kNativeQ["FindIntegerNullVector"],
  kFindIntegerNullVector[vec_] := FindIntegerNullVector[vec],
  kFindIntegerNullVector[vec_List] := Module[
    {n = Length[vec], digits, ints, rows, red, cand, bound},
    If[n < 2 || n > 12 || ! AllTrue[vec, NumberQ], Return[$Failed]];
    digits = Replace[Precision /@ vec, MachinePrecision -> 15, {1}];
    If[! AllTrue[digits, NumberQ], Return[$Failed]];
    digits = Floor[2 Min[digits]/3];
    If[digits < 8, Return[$Failed]];
    ints = Round[10^digits vec];
    If[! AllTrue[ints, IntegerQ], Return[$Failed]];
    rows = Table[Append[UnitVector[n, i], ints[[i]]], {i, n}];
    red = lllReduce[rows];
    bound = 10^Max[1, Floor[digits/3]];
    cand = Select[red, Most[#] =!= ConstantArray[0, n] && Abs[Last[#]] <= bound &];
    If[cand === {}, $Failed, Most[First[SortBy[cand, Most[#] . Most[#] &]]]]]];

(* ------------------------------------------------------------------ *)
(* 0.6  Names the caller and the package must share                   *)
(* ------------------------------------------------------------------ *)

(* Two System names appear in package input or output but are absent from
   Mathics 10.0.1.  Read inside the private context an absent name would
   become a private symbol, so caller input would not match the package's
   patterns and the package's output would print with a private context
   prefix.  Creating the inert System symbol aligns the syntax; it does not
   supply an implementation, and on a kernel that has the function this does
   nothing at all.

     Inactive          wraps Plus or Times in the "Expression" field of a
                       decomposition, so that the field can be read without
                       collapsing the sum or product.  Inert is all that is
                       needed: the package never asks Inactive to do anything.
     AlgebraicNumber   is one head of the exact algebraic grammar.  Mathics
                       has no algebraic-number arithmetic, so no such object
                       can arise there; aligning the name only makes
                       ExactAlgebraicQ answer False about it instead of
                       silently not recognising the head. *)
Scan[If[Names["System`" <> #] === {}, Symbol["System`" <> #]] &,
  {"Inactive", "AlgebraicNumber"}];

(* ------------------------------------------------------------------ *)
(* 0.7  The kernel report                                             *)
(* ------------------------------------------------------------------ *)

(* Select applied to an Association tests the wrong thing in Mathics 10.0.1
   (Select[<|"p" -> True|>, TrueQ] is <||>), so the keys are filtered as a
   list.  Nothing else in the package selects from an association. *)
AlgebraicKernelReport[] := Module[{native, emulated},
  native = Sort[Select[Keys[$kNative], TrueQ[$kNative[#]] &]];
  emulated = Sort[Select[Keys[$kNative], ! TrueQ[$kNative[#]] &]];
  <|"Kernel" -> If[StringContainsQ[$Version, "Mathics"], "Mathics", "Wolfram"],
    "Version" -> $Version,
    "PackageVersion" -> $AlgebraicVersion,
    "NativeFunctions" -> native,
    "EmulatedFunctions" -> emulated,
    "TimeScale" -> $kTimeScale,
    "Limits" -> <|"ResolventDegree" -> $AlgebraicResolventLimit, "FrobeniusPrimes" -> $AlgebraicFrobeniusPrimes,
      "FrobeniusPrimesSolvable" -> $AlgebraicFrobeniusPrimesSolvable, "MemoEntries" -> $AlgebraicMemoLimit,
      "TimeScale" -> $AlgebraicTimeScale|>,
    "Operations" -> <|
      "AlgebraicDecompose" -> True,
      "RootDecompositionLowerBound" -> True,
      "RootDecompositionVerify" -> True,
      "RootSumDecomposition" -> galoisNote,
      "RootProductDecomposition" -> galoisNote,
      "RootGaloisData" -> galoisNote,
      "RootSolvableQ" -> True,
      "RootToRadicals" -> If[kNativeQ["RootPrecision"], True,
        "Only the structural recognizers; the Galois-Kummer descent needs the Galois engine."],
      "DenestRadicals" -> If[kNativeQ["FactorExtension"], True,
        "Kummer multipliers found by factorisation over an extension are not available; the other denesting methods are."]|>|>];

galoisNote := If[kNativeQ["RootPrecision"], True,
  "Not available: the Galois engine needs Root objects to evaluate to the precision they report, and this kernel returns fewer correct digits than that."];
AlgebraicKernelReport[__] := $Failed;

(* ================================================================ *)

(* 1.  Functional decomposition of polynomials                      *)

(* ================================================================ *)

(* Exact characteristic-zero functional decomposition over algebraic
   numbers, from polynomial-decompose/AlgebraicDecomposition.wl.  For
   p = f(g(x)), fixing the degree of a monic inner component g with g(0) = 0
   forces all of its coefficients; a formal-root recurrence constructs that
   candidate and exact monic division decides whether it works.  No
   factorisation, no Solve, no approximate zero test and no radical denesting
   is used.

   Sections 2 to 4 use this as their functional-decomposition step, and on a
   kernel without Decompose the portable layer routes kDecompose here. *)

Options[AlgebraicDecompositions] ={"MaxDecompositions" -> Infinity};
Options[VerifyAlgebraicDecomposition] = {"RequireComplete" -> False, "RequireNormalized" -> False};

$failureTag = Unique["Algebraic`Private`decompositionFailure"];
fail[tag_String, message_String, extra_: <||>] := Throw[failure[tag, message, extra], $failureTag];
invalid[] := failure["InvalidArguments", "Use a documented argument sequence and an unassigned polynomial variable."];

(* This is the only algebraic-number normalization boundary. In particular,
   RootReduce is applied to scalars, never to a polynomial containing x. *)
red[z : (_Integer | _Rational)] := z;
red[z_] := Module[{r},
  If[!FreeQ[z, _Real], fail["InexactCoefficient", "Approximate coefficients are not accepted."]];
  r = kCheck[kRootReduce[z], $Failed];
  If[r === $Failed || !FreeQ[r, _RootReduce | _kRootReduce],
    fail["AlgebraicArithmetic", "Exact algebraic-number reduction failed."]];
  r
];

(* Ascending dense coefficient vectors. Zero is always {0}. *)
trim[v_List] := With[{c = clTrim[v]}, If[c === {}, {0}, c]];   (* the zero polynomial is {0} in this section *)
zeroQ[v_List] := v === {0};
vectorDegree[v_List] := If[zeroQ[v], -Infinity, Length[v] - 1];

checkVariable[x_] := If[kNumericQ[x],
  fail["InvalidVariable", "The polynomial variable must be an unassigned nonnumeric symbol."]];
prepare[p : (_Integer | _Rational), x_Symbol] := (checkVariable[x]; {p});
prepare[p_, x_Symbol] := Module[{q, c},
  checkVariable[x];
  q = kCheck[kExpand[p], $Failed];
  If[q === $Failed || !TrueQ[kPolynomialQ[q, x]],
    fail["NotPolynomial", "The input must be a univariate polynomial."]];
  c = kCoefficientList[q, x];
  If[c === {}, c = {0}];
  If[!FreeQ[c, _Real],
    fail["InexactCoefficient", "Approximate coefficients are not accepted."]];
  If[!(And @@ (TrueQ[kNumericQ[#]] & /@ c)),
    fail["NonAlgebraicCoefficient", "Every coefficient must be an explicit exact algebraic number; symbolic parameters are not accepted."]];
  c = red /@ c;
  If[!AllTrue[c, TrueQ[kNumericQ[#]] && FreeQ[#, _Real] && kAlgebraicQ[#] &],
    fail["NonAlgebraicCoefficient", "Every coefficient must be a recognized exact algebraic number."]];
  trim[c]
];

(* kOptionNames rather than Options[s]: Mathics stores the string option
   names as symbols, and a caller's "MaxDecompositions" -> 2 was rejected as
   unknown against that list. *)
checkOptions[s_Symbol, opts_List] := If[unknownOptions[s, opts] =!= {},
  fail["UnknownOption", "An unknown option was supplied."]];
unknownOptions[head_Symbol, rules_List] := Complement[First /@ Flatten[rules], kOptionNames[head]];

expression[v_List, x_] := kExpand[kHorner[v, x]];
properDegrees[n_Integer] := If[n < 4, {}, Select[Divisors[n], 1 < # < n &]];
properDegreeQ[n_Integer, d_] := IntegerQ[d] && 1 < d < n && Mod[n, d] === 0;

add[a_List, b_List] := With[{m = Max[Length[a], Length[b]]},
  trim[red /@ (PadRight[a, m] + PadRight[b, m])]];
subtract[a_List, b_List] := add[a, -b];
multiply[a_List, b_List, limit_: Infinity] := If[zeroQ[a] || zeroQ[b], {0},
  With[{size = Min[Length[a] + Length[b] - 1, limit]},
    trim[red /@ Take[kConvolve[kTakeUpTo[a, size], kTakeUpTo[b, size]], size]]]];
digitCompose[digits_List, h_List] := Module[{d = Length[h] - 1},
  If[d > 0 && Last[h] === 1 && AllTrue[Most[h], # === 0 &] &&
      AllTrue[digits, Length[#] <= d &],
    trim[red /@ Flatten[PadRight[#, d] & /@ digits]],
    Fold[add[multiply[#1, h], #2] &, {0}, Reverse[digits]]]
];
compose[a_List, b_List] := digitCompose[List /@ a, b];
composeChain[parts_List] := Fold[compose[#2, #1] &, {0, 1}, Reverse[parts]];

(* Only coefficients below t^limit are needed for certificate congruences. *)
truncatedPower[a_List, exponent_Integer, limit_Integer] :=
  Module[{result = {1}, base = kTakeUpTo[a, limit], k = exponent},
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
  position = kFirstPositionAtLevel[Rest /@ digits, Except[0], None, 2];
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

(* Pure presentation of independently established degree-test results. *)
exhaustiveData[c_List, tests_List] := Module[{good},
  good = kLookup[Select[tests, TrueQ[#["Decomposable"]] &], "RightDegree", {}];
  <|"Type" -> "AllDegreeTests", "InputDegree" -> vectorDegree[c],
    "TestedRightDegrees" -> properDegrees[Length[c] - 1], "AcceptedRightDegrees" -> good,
    "Indecomposable" -> If[Length[c] < 3,
      Missing["NotApplicable", "DegreeBelowTwo"], good === {}], "Tests" -> tests|>
];

checkDegree[c_List, d_] := If[!properDegreeQ[Length[c] - 1, d],
  fail["InvalidRightDegree", "The right degree must be a proper divisor d of the polynomial degree with 1<d<n."]];

firstPair[c_List] := Module[{pair = None, d},
  Do[pair = rightPair[c, d]; If[pair =!= None, Break[]],
    {d, properDegrees[Length[c] - 1]}];
  pair
];
allPairs[c_List] := DeleteCases[rightPair[c, #] & /@ properDegrees[Length[c] - 1], None];

oneChain[c_List] := Module[{v = c, out = {}, pair},
  While[(pair = firstPair[v]) =!= None,
    (* Minimal successful right degree implies an indecomposable inner factor. *)
    PrependTo[out, pair[[2]]]; v = pair[[1]]];
  Prepend[out, v]
];

checkedChain[c_List, chain_List] := If[zeroQ[subtract[c, composeChain[chain]]], chain,
  fail["InternalVerification", "A complete chain failed exact recomposition."]];

allChains[c_List, limit_] := Module[{pairs, atomic, walk, out = {}, capTag = Unique["Algebraic`Private`enumerationCap"]},
  pairs[v_List] := pairs[v] = allPairs[v];
  atomic[v_List] := atomic[v] = (firstPair[v] === None);
  walk[v_List, suffix_List] := Module[{ps = pairs[v]},
    If[ps === {},
      AppendTo[out, checkedChain[c, Prepend[suffix, v]]];
      If[limit =!= Infinity && Length[out] > limit, Throw[Null, capTag]],
      Do[If[atomic[pr[[2]]], walk[pr[[1]], Prepend[suffix, pr[[2]]]]], {pr, ps}]]];
  Catch[walk[c, {}], capTag];
  out
];

(* every entry point of this section prepares its input the same way *)
prepared[p_, x_, f_] := Catch[f[prepare[p, x]], $failureTag];

AlgebraicDecompose[p_, x_Symbol] := prepared[p, x,
  Function[c, expression[#, x] & /@ checkedChain[c, oneChain[c]]]];
(* the variable is inferred when the polynomial has exactly one *)
AlgebraicDecompose[p_] := Catch[Module[{vars = polynomialVariables[p]},
  If[Length[vars] =!= 1,
    fail["VariableInference", If[vars === {},
      "AlgebraicDecompose[p] needs a polynomial with a variable; give the variable as the second argument.",
      "AlgebraicDecompose[p] needs a polynomial with exactly one variable; give the variable as the second argument."],
      <|"Variables" -> vars|>]];
  AlgebraicDecompose[p, First[vars]]], $failureTag];
(* the symbols of a polynomial with algebraic coefficients: Root and
   AlgebraicNumber objects are set aside first, since Variables lists a Root
   object on a kernel where NumericQ of it is False *)
polynomialVariables[p_] := Select[Variables[p /. {_Root -> 1, _AlgebraicNumber -> 1}],
  Head[#] === Symbol && ! kNumericQ[#] &];
AlgebraicDecompositions[p_, x_Symbol, opts : OptionsPattern[]] := Catch[
  Module[{c, limit, chains},
    checkOptions[AlgebraicDecompositions, {opts}];
    limit = OptionValue["MaxDecompositions"];
    If[! componentLimitQ[limit],
      fail["InvalidLimit", "MaxDecompositions must be a positive integer or Infinity."]];
    c = prepare[p, x]; chains = allChains[c, limit];
    If[Length[chains] > limit,
      fail["EnumerationLimit", "More chains exist than the requested cap; partial output is not exhaustive.",
        <|"Complete" -> False, "Limit" -> limit,
          "PartialDecompositions" -> Map[expression[#, x] &, Take[chains, limit], {2}]|>]];
    Map[expression[#, x] &, chains, {2}]], $failureTag];
AlgebraicDecompositionPairs[p_, x_Symbol] := prepared[p, x, Function[c, Map[expression[#, x] &, allPairs[c], {2}]]];
AlgebraicRightDecompose[p_, x_Symbol, d_] := prepared[p, x, Function[c, checkDegree[c, d];
  With[{pair = rightPair[c, d]},
    If[pair === None, Missing["NotDecomposable", d], expression[#, x] & /@ pair]]]];

AlgebraicDecompositionData[p_, x_Symbol, d_] := prepared[p, x, Function[c, checkDegree[c, d]; publicTest[c, d, x]]];
AlgebraicDecompositionData[p_, x_Symbol] := prepared[p, x,
  Function[c, exhaustiveData[c, publicTest[c, #, x] & /@ properDegrees[Length[c] - 1]]]];

ComposeDecomposition[parts_List, x_Symbol] := Catch[Module[{vs},
  checkVariable[x];
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
  If[!(And @@ (kKeyExistsQ[t, #] & /@ keys)), Return[False]];
  If[t["Type"] =!= "DegreeTest", Return[False]];
  n = Length[c] - 1; d = t["RightDegree"];
  If[!properDegreeQ[n, d], Return[False]];
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
    If[kLookup[t["Obstruction"], "DigitIndex", -1] =!= obs["DigitIndex"] ||
       kLookup[t["Obstruction"], "Power", -1] =!= obs["Power"], Return[False]];
    If[red[kLookup[t["Obstruction"], "Coefficient", Indeterminate] -
        obs["Coefficient"]] =!= 0, Return[False]]];
  res = prepare[t["Residual"], x];
  (* Reconstruction with constant digits already proves c = f(h). *)
  If[obs === None, zeroQ[res], zeroQ[subtract[res, subtract[c, compose[f, h]]]]]
];

verifyData[c_List, data_, x_] := Module[{ds, ts, expected},
  If[!AssociationQ[data] || !kKeyExistsQ[data, "Type"], Return[False]];
  If[data["Type"] === "DegreeTest", Return[verifyTest[c, data, x]]];
  If[data["Type"] =!= "AllDegreeTests", Return[False]];
  ds = properDegrees[Length[c] - 1]; ts = kLookup[data, "Tests", None];
  If[!ListQ[ts] || Length[ts] =!= Length[ds], Return[False]];
  If[!AllTrue[ts, verifyTest[c, #, x] &] || kLookup[ts, "RightDegree", {}] =!= ds, Return[False]];
  expected = exhaustiveData[c, ts];
  kLookup[data, Keys[expected], None] === Values[expected]
];

VerifyAlgebraicDecompositionData[p_, data_, x_Symbol] := Catch[
  Module[{c, result}, c = prepare[p, x];
    result = kCheck[Catch[verifyData[c, data, x], $failureTag], False];
    TrueQ[result]], $failureTag];

AlgebraicDecompose[___] := invalid[];
AlgebraicDecompositions[___] := invalid[];
AlgebraicDecompositionPairs[___] := invalid[];
AlgebraicRightDecompose[___] := invalid[];
AlgebraicDecompositionData[___] := invalid[];
VerifyAlgebraicDecompositionData[___] := invalid[];
ComposeDecomposition[___] := invalid[];
VerifyAlgebraicDecomposition[___] := invalid[];

(* ================================================================ *)

(* 2.  Galois engine, sums and products of algebraic numbers        *)

(* ================================================================ *)

(* From root-decomposition/RootDecomposition.wl.  For an algebraic number a
   of degree n this computes

       D+(a) = min max deg(b_i)  over all finite sums     a = b_1 + ... + b_r,
       Dx(a) = min max deg(b_i)  over all finite products a = b_1 * ... * b_r,

   the b_i ranging over all algebraic numbers.  Sums have a complete
   algorithm (trace descent to the splitting field, then exact rational
   linear algebra on the fixed fields of the subgroups of the Galois group);
   two-factor products have one (norm descent with an explicit radical
   exponent); products of arbitrarily many factors combine the two-factor
   criterion, a rank-one tensor test, recursive splitting, a bounded search
   and rigorous lower bounds, and report what has been certified.

   The Galois group is a permutation group of the roots computed by
   numerical resolvents; the splitting field is held in a tower monomial
   basis with rational coordinates read off traces.  This engine, the exact
   input handling, the Frobenius tests and the shared predicates below are
   also what section 3 descends through -- in the separate packages that
   section reached into this one's private context through sixteen
   assignments, which the merge removes. *)

(* ------------------------------------------------------------------ *)
(* Utilities                                                          *)
(* ------------------------------------------------------------------ *)

failure[tag_String, msg_String, extra_: <||>] :=
  Failure[tag, Join[<|"MessageTemplate" -> msg|>, extra]];

engineOptionsQ[scope_, engine_, prec_, order_, tries_] :=
  MemberQ[{"Global", "InputField"}, scope] && MemberQ[{Automatic, "InputField", "SplittingField"}, engine] &&
  IntegerQ[prec] && prec >= 30 && positiveIntegerQ[order] && positiveIntegerQ[tries];
degreeFailure[d_, lb_] := failure["DegreeBound", "The requested maximum degree is below a proved lower bound",
  <|"MaximumDegree" -> d, "LowerBound" -> lb|>];

(* The portable exact zero test: the canonical algebraic reduction decides
   it in the Wolfram kernel, and an exact algebraic zero test backs it up on a
   kernel whose reduction can leave an expression alone. *)
rootObject[poly_, k_Integer] := kRootObject[poly, x, k];
primitiveIntegerCoefficients[coeffs_] := Last[clPrimitive[coeffs]];
rootValuesAt[poly_, prec_] := Table[kN[rootObject[poly, j], prec], {j, Exponent[poly, x]}];

(* Expand is explicit: FromDigits builds a Horner form, which the Wolfram
   kernel expands on its own and Mathics does not, and the result is compared
   structurally in several places. *)
primitiveIntegerPolynomial[poly_] := primitiveIn[poly, x];

minimalPolynomialOf[a_] := kMemo["minimalPolynomialOf", a, minimalPolynomialCompute[a]];
minimalPolynomialCompute[a_] := Module[{p},
  p = kMinimalPolynomial[a, x];
  If[p === $Failed || ! kPolynomialQ[p, x] || ! And @@ (kRationalQ /@ kCoefficientList[p, x]), $Failed,
    primitiveIntegerPolynomial[p]]];

algebraicDegree[a_] := Module[{p = minimalPolynomialOf[a]}, If[p === $Failed, $Failed, Exponent[p, x]]];

rootIndexOf[a_, poly_] := Module[{n = Exponent[poly, x], vals, av, k},
  (* A stored Root index is only a candidate: isolation methods can order roots differently. *)
  If[Head[a] === Root && IntegerQ[a[[2]]] && 1 <= a[[2]] <= n &&
      kExactZeroQ[a - rootObject[poly, a[[2]]]], Return[a[[2]]]];
  av = kN[a, 40];
  vals = rootValuesAt[poly, 40];
  k = kOrderingFirst[Abs[vals - av]];
  If[kExactZeroQ[a - rootObject[poly, k]], Return[k]];
  (* Fixed-precision nearest-root matching may tie for very close roots.
     Exact equality remains decisive, so numerical ambiguity is not an input error. *)
  kSelectFirst[DeleteCases[Range[n], k], kExactZeroQ[a - rootObject[poly, #]] &, $Failed]];

(* ------------------------------------------------------------------ *)
(* Input normalization                                                *)
(* ------------------------------------------------------------------ *)

inputData[a_] := Module[{p, n, k},
  If[! FreeQ[a, _Real], Message[Algebraic::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  p = minimalPolynomialOf[a];
  If[p === $Failed, Message[Algebraic::notalg, a]; Return[failure["NotAlgebraic", "Not algebraic"]]];
  n = Exponent[p, x];
  If[n == 1, Return[<|"Value" -> kRootReduce[a], "Polynomial" -> p, "Degree" -> 1, "Index" -> 1|>]];
  k = rootIndexOf[a, p];
  If[k === $Failed, Return[failure["RootIndex", "Could not identify the root branch"]]];
  <|"Value" -> a, "Polynomial" -> p, "Degree" -> n, "Index" -> k|>];

(* ------------------------------------------------------------------ *)
(* Lower bounds                                                       *)
(* ------------------------------------------------------------------ *)

largestPrimeFactor[1] = 1;
largestPrimeFactor[n_Integer] := Max[First /@ FactorInteger[n]];

(* least d with e | lcm(1..d): the largest prime power dividing e *)
exponentBound[1] = 1;
exponentBound[e_Integer] := Max[Power @@@ FactorInteger[e]];

(* Gaussian coefficients contribute a C2 factor.  For d >= 2 this does not
   enlarge lcm(1,...,d); only the d = 1 exponent bound changes. *)
gaussianPrimeBound[n_Integer] := Max[1, Max[Select[First /@ FactorInteger[n], # > 2 &] /. {} -> {1}]];
gaussianExponentBound[e_Integer] := If[MemberQ[{1, 2}, e], 1, exponentBound[e]];

(* cycle type at a prime not dividing the discriminant or leading coefficient *)
frobeniusCycleType[poly_, p_] := kFactorDegreesMod[poly, x, p];

frobeniusExponentMultiple[poly_, maxPrimesIn_: Automatic] :=
  kMemo["frobeniusExponentMultiple", {poly, Replace[maxPrimesIn, Automatic :> $kFrobeniusPrimes]}, frobeniusExponentMultipleCompute[poly, maxPrimesIn]];
(* the primes dividing this one are the primes the cycle-type scans skip *)
frobeniusModulus[poly_] := kDiscriminant[poly, x] Coefficient[poly, x, Exponent[poly, x]];
frobeniusExponentMultipleCompute[poly_, maxPrimesIn_] := Module[
  {maxPrimes = Replace[maxPrimesIn, Automatic :> $kFrobeniusPrimes], bad = frobeniusModulus[poly], ps},
  ps = kTakeUpTo[Select[Prime[Range[maxPrimes + 10]], Mod[bad, #] != 0 &], maxPrimes];
  LCM @@ Prepend[Flatten[frobeniusCycleType[poly, #] & /@ ps], 1]];

lowerBoundFromPolynomial[poly_] := kMemo["lowerBound", {poly, $kFrobeniusPrimes}, lowerBoundCompute[poly]];
lowerBoundCompute[poly_] := Module[{n = Exponent[poly, x], bound},
  bound = largestPrimeFactor[n];
  If[bound == n, bound, Max[bound, exponentBound[frobeniusExponentMultiple[poly]]]]];

RootDecompositionLowerBound[a_] := Module[{in = inputData[a]},
  If[kFailureQ[in], Return[in]];
  lowerBoundFromPolynomial[in["Polynomial"]]];

(* ------------------------------------------------------------------ *)
(* Galois group by numerical resolvents                               *)
(* ------------------------------------------------------------------ *)

Options[RootGaloisData] = {
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12,
  "Cache" -> True
};

$galoisCache = <||>;

allRoots[poly_] := Module[{fl},
  fl = Select[kFactorList[poly], Exponent[#[[1]], x] > 0 &];
  Join @@ Table[rootObject[f[[1]], j], {f, fl}, {j, Exponent[f[[1]], x]}]];

roundInteger[z_] := Module[{r},
  If[Abs[Im[z]] > 10^-12, Throw["precision", precTag]];
  r = Round[Re[z]];
  If[Abs[Re[z] - r] > 10^-12 || Accuracy[z] < 12, Throw["precision", precTag]];
  r];

roundIntegerMatrix[m_] := Map[roundInteger, m, {2}];

(* The elimination of section 0.5a produces a resultant of degree deg(theta)
   deg(f) whose irreducible factor the kernel must find; the Wolfram kernel's
   MinimalPolynomial does that natively, the interpreted kFactorList does not
   finish a degree-72 one.  Above this limit the engine returns
   Failure["EngineLimit", ...] at once. *)
$AlgebraicResolventLimit = If[kNativeQ["RootReduce"], Infinity, 48];
$kResolventLimit := $AlgebraicResolventLimit;

galoisGroupNumerically[roots_List, nums_List, prec_, maxOrder_, maxTries_] :=
  Module[{n = Length[roots], orbit, vals, thetaExact = 0, tower = {}, k, w, newTheta, m, md, mroots,
          cand, matched, idx, used, ok, perms, set, mt, lastDeg, tol, dists, pos, rprec},
    orbit = {{}}; vals = {0};
    rprec = Max[30, Floor[prec/2]];
    tol = 10^(-Floor[rprec/2]);
    Do[
      ok = False; used = {};
      Do[
        w = kRandomChoice[Complement[Range[1, Max[60, maxTries]], used]];
        AppendTo[used, w];
        (* the next elimination is a resultant of degree Length[orbit] n; on a
           kernel without a native factoriser it is refused beyond
           $kResolventLimit rather than left to run for hours *)
        If[Length[orbit] n > $kResolventLimit,
          Throw[failure["EngineLimit", "The Galois engine on this kernel stops at a resolvent of this size",
            <|"ResultantDegree" -> Length[orbit] n, "Limit" -> $kResolventLimit|>], failTag]];
        newTheta = kRootReduce[thetaExact + w roots[[k]]];
        m = minimalPolynomialOf[newTheta];
        If[m === $Failed, Continue[]];
        md = Exponent[m, x];
        lastDeg = Length[orbit];
        galoisPrint["galois: k=", k, " w=", w, " degree ", md, " orbit ", lastDeg, " prec ", prec];
        If[md < lastDeg || Mod[md, lastDeg] != 0, Continue[]];
        If[md > maxOrder, Message[Algebraic::order, md, maxOrder];
          Throw[failure["GroupOrder", "Galois group too large", <|"Order" -> md, "Limit" -> maxOrder|>], failTag]];
        mroots = If[md == 1, {kN[newTheta, rprec]}, rootValuesAt[m, rprec]];
        cand = Join @@ Table[{Append[orbit[[i]], j], vals[[i]] + w nums[[j]]},
                  {i, Length[orbit]}, {j, Complement[Range[n], orbit[[i]]]}];
        matched = {}; idx = {};
        Do[
          dists = Abs[c[[2]] - mroots];
          pos = kOrderingFirst[dists];
          If[dists[[pos]] < tol, AppendTo[matched, c]; AppendTo[idx, pos]],
          {c, cand}];
        galoisPrint["galois:   matched ", Length[matched], " distinct ", Length[Union[idx]], " of ", md];
        If[Length[matched] == md && Length[Union[idx]] == md,
          orbit = matched[[All, 1]]; vals = matched[[All, 2]];
          thetaExact = newTheta;
          If[md > lastDeg, AppendTo[tower, {k, md/lastDeg}]];
          ok = True; Break[]],
        {maxTries}];
      If[! ok, Message[Algebraic::group, maxTries];
        Throw[failure["GaloisGroup", "Could not determine the Galois group"], failTag]],
      {k, n}];
    perms = orbit;
    set = Association @@ Thread[perms -> Range[Length[perms]]];
    If[! kKeyExistsQ[set, Range[n]], Throw[failure["GaloisGroup", "Identity missing"], failTag]];
    mt = Table[set[perms[[i]][[perms[[j]]]]], {i, Length[perms]}, {j, Length[perms]}];
    If[! FreeQ[mt, _Missing], Throw[failure["GaloisGroup", "Closure check failed"], failTag]];
    <|"Permutations" -> perms, "Order" -> Length[perms], "Tower" -> tower, "PrimitiveElement" -> thetaExact,
      "MultiplicationTable" -> mt, "Identity" -> set[Range[n]]|>];

(* Shared with RootToRadicals: queue-based closure with constant-time membership. *)
groupClosure[mt_, idElem_, gs_, visit_: None] := Module[{seen = ConstantArray[False, Length[mt]], queue = {idElem}, pos = 1, h},
  seen[[idElem]] = True;
  While[pos <= Length[queue],
    Do[h = mt[[queue[[pos]], g]];
      If[! seen[[h]], seen[[h]] = True; AppendTo[queue, h];
        If[visit =!= None, visit[queue[[pos]], g, h]]], {g, gs}];
    pos++];
  Sort[queue]];

(* Subgroup lattice from the multiplication table. *)
(* Assignment into an association part is refused in Mathics 10.0.1, so the
   subgroup table below is extended with kAssociateTo rather than assigned to.
   The generator lists it records drive every fixed-field computation, and an
   association that silently stayed a single entry made the whole subgroup
   lattice collapse to the trivial subgroup. *)
subgroupLattice[mt_, idElem_] := Module[{ord = Length[mt], seen, queue, H, J, g, pos = 1},
  seen = <|{idElem} -> {}|>;
  Do[J = groupClosure[mt, idElem, {g}]; If[! kKeyExistsQ[seen, J], kAssociateTo[seen, J -> {g}]], {g, ord}];
  queue = Keys[seen];
  While[pos <= Length[queue],
    H = queue[[pos++]];
    Do[
      If[! MemberQ[H, g],
        J = groupClosure[mt, idElem, Append[seen[H], g]];
        If[! kKeyExistsQ[seen, J], kAssociateTo[seen, J -> Join[seen[H], {g}]]; AppendTo[queue, J]]],
      {g, ord}]];
  Table[<|"Elements" -> k, "Generators" -> seen[k], "Order" -> Length[k], "Index" -> ord/Length[k]|>, {k, Keys[seen]}]];

elementOrder[mt_, g_, idElem_] := Module[{h = g, k = 1}, While[h != idElem, h = mt[[h, g]]; k++]; k];

(* The loop exits through its own condition: Return inside While returns
   from the enclosing function in the Wolfram kernel but only from the loop in
   Mathics. *)
retryPrecision[compute_, prec0_] := Module[{prec = prec0, result = "precision", attempt = 0},
  galoisPrint["galois: precision ", prec0];
  While[attempt++ < 4 && result === "precision",
    result = Catch[compute[prec], precTag];
    If[result === "precision" && attempt < 4, Message[Algebraic::prec, prec]; prec *= 2]];
  If[result === "precision", failure["Precision", "Precision escalation failed"], result]];

(* The numerical-resolvent engine rounds traces of high-precision root values
   to integers, so it needs kN[Root[f, k], p] to deliver the p digits it
   reports.  A kernel where it does not is refused here rather than allowed to
   round noise into a plausible wrong group. *)
kernelPrecisionFailure[] := failure["KernelPrecision",
  "The Galois engine needs Root objects to evaluate to the precision they report, and this kernel returns fewer correct digits than that. The operations that do not use it are unaffected; see AlgebraicKernelReport[].",
  <|"Kernel" -> $Version|>];

(* The refusal is the first statement of the body, not a conditional
   definition: in Mathics a definition lhs /; cond := rhs evaluates lhs when
   the symbol already has a definition, which a second Get of this file
   does, and the guard then lands on the value's head instead. *)
buildGaloisData[poly_, prec0_, maxOrder_, maxTries_] :=
  If[! kNativeQ["RootPrecision"], kernelPrecisionFailure[],
    retryPrecision[Function[prec, Catch[buildGaloisDataAtPrecision[poly, prec, maxOrder, maxTries], failTag]], prec0]];

basisValues[nums_, perms_, tower_, basisExp_] := Module[{gens = tower[[All, 1]], pw},
  pw = Table[kPowerList[nums[[i]], Max[Flatten[{0, basisExp}]]], {i, Length[nums]}];
  Table[Times @@ Table[pw[[perm[[gens[[j]]]], ex[[j]] + 1]], {j, Length[gens]}], {perm, perms}, {ex, basisExp}]];

buildGaloisDataAtPrecision[poly_, prec_, maxOrder_, maxTries_] := Module[
  {roots, nums, n, gg, perms, ord, tower, basisExp, val, gram, gramInv, mt, idElem,
   rootCoords, auts, subs, fixed, orders, numsPerm, groupGens},
  roots = allRoots[poly];
  n = Length[roots];
  nums = kN[roots, prec];
  gg = galoisGroupNumerically[roots, nums, prec, maxOrder, maxTries];
  perms = gg["Permutations"]; ord = gg["Order"]; tower = gg["Tower"];
  basisExp = Tuples[Range[0, # - 1] & /@ tower[[All, 2]]];
  val = basisValues[nums, perms, tower, basisExp];
  gram = roundIntegerMatrix[kTranspose[val] . val];
  If[Det[gram] == 0, Throw["precision", precTag]];
  gramInv = Inverse[gram];
  mt = gg["MultiplicationTable"]; idElem = gg["Identity"];
  numsPerm = Map[nums[[#]] &, perms];
  rootCoords = kTranspose[gramInv . roundIntegerMatrix[kTranspose[val] . numsPerm]];
  subs = subgroupLattice[mt, idElem];
  groupGens = kSelectFirst[subs, #["Order"] == ord &]["Generators"];
  auts = ConstantArray[None, ord]; auts[[idElem]] = IdentityMatrix[ord];
  Do[auts[[s]] = gramInv . roundIntegerMatrix[kTranspose[val] . val[[mt[[All, s]]]]], {s, groupGens}];
  (* The multiplication table determines every remaining automorphism exactly. *)
  groupClosure[mt, idElem, groupGens, Function[{parent, generator, element},
    If[auts[[element]] === None, auts[[element]] = auts[[parent]] . auts[[generator]]]]];
  (* consistency check: automorphisms permute the root coordinates *)
  Do[If[kTranspose[auts[[s]] . kTranspose[rootCoords]] != rootCoords[[perms[[s]]]],
    Throw["precision", precTag]], {s, ord}];
  fixed = Table[
    If[sub["Order"] == 1, IdentityMatrix[ord],
      NullSpace[Join @@ Table[auts[[g]] - IdentityMatrix[ord], {g, sub["Generators"]}]]],
    {sub, subs}];
  subs = MapThread[Append[#1, "FixedField" -> #2] &, {subs, fixed}];
  orders = Table[elementOrder[mt, g, idElem], {g, ord}];
  <|"Type" -> "Galois", "Polynomial" -> poly, "Roots" -> roots, "NumericRoots" -> nums, "Precision" -> prec,
    "Degree" -> n, "Permutations" -> perms, "Order" -> ord, "Exponent" -> LCM @@ orders,
    "Tower" -> tower, "BasisExponents" -> basisExp, "Values" -> val, "Gram" -> gram,
    "GramInverse" -> gramInv, "MultiplicationTable" -> mt, "Identity" -> idElem,
    "RootCoordinates" -> rootCoords, "Automorphisms" -> auts, "Subgroups" -> subs,
    "PrimitiveElement" -> gg["PrimitiveElement"]|>];

(* the leading coefficient c of an integer polynomial and its monic integral
   model c^(n-1) f(x/c), whose roots are c times the roots of f *)
monicModel[poly_] := With[{c = Coefficient[poly, x, Exponent[poly, x]]},
  {c, kExpand[c^(Exponent[poly, x] - 1) (poly /. x -> x/c)]}];

RootGaloisData[a_, opts : OptionsPattern[]] := Module[{in},
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  RootGaloisData[in["Polynomial"], x, opts]];

RootGaloisData[poly0_, var_Symbol, OptionsPattern[]] := Module[{poly, c, res, mon, key},
  If[! kPolynomialQ[poly0, var] || ! FreeQ[poly0, _Real] ||
      ! And @@ (kRationalQ /@ kCoefficientList[poly0, var]) || Exponent[poly0, var] < 1,
    Return[failure["InvalidPolynomial", "Expected a nonconstant polynomial with exact rational coefficients"]]];
  If[! engineOptionsQ["Global", Automatic, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]] ||
      ! MemberQ[{True, False}, OptionValue["Cache"]], Return[failure["InvalidOptions", "Invalid Galois computation options"]]];
  poly = primitiveIntegerPolynomial[poly0 /. var -> x];
  {c, mon} = monicModel[poly];
  If[! kSquareFreeQ[mon], Return[failure["NotSquareFree", "The polynomial is not squarefree"]]];
  (* Scale and OriginalPolynomial belong to the input, not just its integral model.
     Include resource limits so a cached large group cannot bypass a smaller cap. *)
  key = {poly, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]};
  If[OptionValue["Cache"] && kKeyExistsQ[$galoisCache, key], Return[$galoisCache[key]]];
  (* data computed under any cap is valid under a larger one: the radical
     descent asks with the cap enlarged by the roots of unity it adjoins,
     and rebuilt the same group *)
  If[OptionValue["Cache"],
    With[{fit = kSelectFirst[Keys[$galoisCache],
        MatchQ[#, {poly, OptionValue["WorkingPrecision"], _, _}] && AssociationQ[$galoisCache[#]] &&
          TrueQ[$galoisCache[#]["Order"] <= OptionValue["MaxGroupOrder"]] &, None]},
      If[fit =!= None, Return[$galoisCache[fit]]]]];
  res = buildGaloisData[mon, OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]];
  If[kFailureQ[res], Return[res]];
  res = Join[res, <|"Scale" -> c, "OriginalPolynomial" -> poly,
    "SplittingFieldDegree" -> res["Order"],
    "SubfieldDegrees" -> Sort[#["Index"] & /@ res["Subgroups"]]|>];
  (* assignment into an association part is refused in Mathics 10.0.1
     (Association is Protected), so the cache is extended instead *)
  If[OptionValue["Cache"], kAssociateTo[$galoisCache, key -> res]];
  res];

(* ------------------------------------------------------------------ *)
(* Field element utilities                                            *)
(* ------------------------------------------------------------------ *)

valuesAtPrecision[gd_, prec_] := If[prec <= gd["Precision"], gd["Values"],
  basisValues[kN[gd["Roots"], prec], gd["Permutations"], gd["Tower"], gd["BasisExponents"]]];

conjugates[gd_, v_] := gd["Values"] . v;

coordinatesFromConjugates[gd_, yv_] := gd["GramInverse"] . (roundInteger /@ (kTranspose[gd["Values"]] . yv));

multiplicationMatrix[gd_, yv_] := gd["GramInverse"] . roundIntegerMatrix[kTranspose[gd["Values"]] . (yv gd["Values"])];

multiplicationMatrixOfElement[gd_, v_] := Module[{den = LCM @@ Denominator[v]},
  multiplicationMatrix[gd, conjugates[gd, den v]]/den];

(* Reconstruct one coordinate vector from integral traces; retain the matrix route if a large power
   exhausts trace precision at which the multiplication matrix itself can still be recovered. *)
powerCoordinates[gd_, v_, 0] := coordinateOfOne[gd];
powerCoordinates[gd_, v_, 1] := v;
powerCoordinates[gd_, v_, k_Integer?positiveIntegerQ] := Module[{den = LCM @@ Denominator[v], result},
  result = Catch[coordinatesFromConjugates[gd, conjugates[gd, den v]^k]/den^k, precTag];
  If[result === "precision",
    With[{matrix = multiplicationMatrixOfElement[gd, v]}, Nest[matrix . # &, v, k - 1]], result]];

(* Fix a denominator once.  For integral B, Norm(B)/B is integral; its conjugates permit exact
   quotient coordinates from integer traces.  Uncertain traces use one lazily cached matrix. *)
powerDivider[gd_, v_] := Module[{den = LCM @@ Denominator[v], values, norm, reciprocals, matrix, divide},
  If[v == 0 v, Return[failure["ZeroDenominator", "The field denominator is zero"]]];
  reciprocals = Catch[
    values = conjugates[gd, den v]; norm = roundInteger[Times @@ values];
    If[norm == 0 || AnyTrue[values, TrueQ[# == 0] &], Throw["precision", precTag]];
    norm/values, precTag];
  matrix[] := matrix[] = multiplicationMatrixOfElement[gd, v];
  divide[num_, 0] := num;
  divide[num_, k_Integer?positiveIntegerQ] := Module[{numDen = LCM @@ Denominator[num], result},
    result = If[reciprocals === "precision", "precision", Catch[
      (den^k/(numDen norm^k)) coordinatesFromConjugates[gd, conjugates[gd, numDen num] reciprocals^k], precTag]];
    If[result === "precision", kLinearSolve[kMatrixPower[matrix[], k], num], result]];
  divide];

elementDegree[gd_, v_] := gd["Order"]/Count[gd["Automorphisms"], _?(# . v == v &)];

coordinateOfOne[gd_] := UnitVector[gd["Order"], 1];

(* exact mean of the conjugates: Tr(y)/[L:Q] with Tr(b_j) = Gram[j,1] *)
meanTrace[gd_, v_] := (v . gd["Gram"][[1]])/gd["Order"];

elementToAlgebraic[gd_, v_] := Module[{reps, d, den, prec, vals, poly, cl, k, cands, mag, need, id = gd["Identity"]},
  If[Rest[v] == 0 Rest[v], Return[First[v]]];
  reps = kDeleteDuplicatesBy[Range[gd["Order"]], gd["Automorphisms"][[#]] . v &];
  d = Length[reps];
  den = LCM @@ Denominator[v];
  mag = Max[Abs[conjugates[gd, den v]]];
  need = Ceiling[d Log10[2 Max[mag, 2]]] + 30;
  prec = Max[gd["Precision"], need];
  vals = valuesAtPrecision[gd, prec] . (den v);
  poly = kExpand[Times @@ (x - vals[[reps]])];
  cl = roundInteger /@ kCoefficientList[poly, x];
  poly = primitiveIntegerPolynomial[FromDigits[Reverse[cl], x] /. x -> den x];
  cands = rootValuesAt[poly, prec];
  k = kOrderingFirst[Abs[cands - vals[[id]]/den]];
  kRootReduce[rootObject[poly, k]]];

(* ------------------------------------------------------------------ *)
(* Input-field engine: subfields of K = Q(a) by principal subfields     *)
(* (factorization of the minimal polynomial over K), no Galois group.  *)
(* Field data of both engines share the keys "Type", "Order" (dimension),*)
(* "Subgroups" (list with "Index" = field degree, "FixedField" rows).   *)
(* ------------------------------------------------------------------ *)

(* coordinates (length n) of a polynomial expression in the symbol z modulo P(z) *)
polyCoords[expr_, P_, n_] := PadRight[kCoefficientList[kPolynomialRemainder[kExpand[expr], P, z], z], n];

intersectRowSpaces[A_, B_] := Module[{ca, cb},
  ca = NullSpace[A]; cb = NullSpace[B];
  If[ca === {}, Return[B]]; If[cb === {}, Return[A]];
  NullSpace[Join[ca, cb]]];

canonicalRows[rows_] := DeleteCases[RowReduce[rows], {0 ..}];

fieldContainsQ[big_, small_] := MatrixRank[Join[big, small]] == Length[big];

(* Newton power sums p_j = sum of j-th powers of the roots of a monic polynomial *)
powerSums[P_, n_] := Module[{s},
  s[0] = n;
  s[k_] := s[k] = -k Coefficient[P, x, n - k] - Sum[Coefficient[P, x, n - i] s[k - i], {i, k - 1}];
  Table[s[j], {j, 0, n - 1}]];

inputFieldData[poly_] := Module[{n = Exponent[poly, x], c, P, Pz, theta, fac, factors, principal, subfields, newS, traces, galois, m, rows, eqs, r, key, data},
  {c, P} = monicModel[poly];
  Pz = P /. x -> z;
  key = {"InputField", poly};
  If[kKeyExistsQ[$galoisCache, key], Return[$galoisCache[key]]];
  theta = rootObject[P, 1];
  fac = First /@ Select[kFactorListExtension[P, theta], Exponent[#[[1]], x] > 0 &];
  factors = Map[Function[f, kExpand[f /. theta -> z]], fac];
  galois = And @@ (Exponent[#, x] == 1 & /@ factors);
  principal = {};
  Do[
    m = Exponent[g, x];
    If[m == 1 && kExpand[g - (x - z)] === 0, Continue[]];   (* only the factor x - theta gives K itself *)
    rows = Table[
      r = kPolynomialRemainder[x^j - z^j, g, x];
      Table[polyCoords[Coefficient[r, x, i], Pz, n], {i, 0, m - 1}],
      {j, 0, n - 1}];
    eqs = Flatten[Table[Table[rows[[j + 1, i + 1, k]], {j, 0, n - 1}], {i, 0, m - 1}, {k, n}], 1];
    AppendTo[principal, canonicalRows[NullSpace[eqs]]],
    {g, factors}];
  subfields = {canonicalRows[IdentityMatrix[n]]};
  Do[
    newS = subfields;
    Do[AppendTo[newS, canonicalRows[intersectRowSpaces[S, V]]], {S, subfields}];
    subfields = DeleteDuplicates[newS],
    {V, principal}];
  subfields = DeleteDuplicates[Append[subfields, {UnitVector[n, 1]}]];
  traces = powerSums[P, n];
  data = <|"Type" -> "InputField", "Polynomial" -> P, "PolynomialZ" -> Pz, "Scale" -> c, "Degree" -> n, "Order" -> n,
    "Galois" -> galois, "FactorDegrees" -> Sort[Exponent[#, x] & /@ factors],
    "Subgroups" -> Table[<|"Index" -> Length[S], "FixedField" -> S, "Elements" -> None, "Order" -> n/Length[S]|>, {S, subfields}],
    "SubfieldDegrees" -> Sort[Length /@ subfields], "TraceVector" -> traces|>;
  kAssociateTo[$galoisCache, key -> data];
  data];

(* generic element operations dispatching on the engine type *)
toExact[fd_, v_] := If[fd["Type"] === "InputField",
  Module[{theta = fd["Theta"]}, kRootReduce[Sum[v[[j + 1]] theta^j, {j, 0, fd["Degree"] - 1}]]],
  elementToAlgebraic[fd, v]];

meanTraceOf[fd_, v_] := If[fd["Type"] === "InputField", (v . fd["TraceVector"])/fd["Degree"], meanTrace[fd, v]];

multMatrix[fd_, v_] := If[fd["Type"] === "InputField",
  Module[{n = fd["Degree"], Pz = fd["PolynomialZ"], poly},
    poly = Sum[v[[j + 1]] z^j, {j, 0, n - 1}];
    kTranspose[Table[polyCoords[poly z^k, Pz, n], {k, 0, n - 1}]]],
  multiplicationMatrixOfElement[fd, v]];

(* attach the actual input root: theta = c*a as a Root object of P; target coordinates (0,1/c,0,...) *)
attachTarget[fd_, a_] := Module[{P = fd["Polynomial"], c = fd["Scale"], n = fd["Degree"], k},
  k = rootIndexOf[c a, P];
  If[k === $Failed, Return[$Failed]];
  Join[fd, <|"Theta" -> rootObject[P, k], "TargetCoordinates" -> UnitVector[n, 2]/c|>]];

inputFieldAt[poly_, a_] := Module[{fd = inputFieldData[poly]},
  If[kFailureQ[fd], $Failed, attachTarget[fd, a]]];

(* ------------------------------------------------------------------ *)
(* Result assembly                                                    *)
(* ------------------------------------------------------------------ *)

termDegrees[terms_] := algebraicDegree /@ terms;

RootDecompositionVerify[a_, terms_List, op : (Plus | Times)] := Module[{degs, ok},
  degs = termDegrees[terms];
  ok = FreeQ[{a, terms}, _Real] && And @@ (positiveIntegerQ /@ degs) && kExactZeroQ[a - (op @@ terms)];
  <|"Verified" -> ok, "Degrees" -> degs, "MaximumDegree" -> Max[Prepend[degs, 1]]|>];

makeResult[a_, op_, terms_, lb_, scope_, method_, optimal_, scopeOptimal_, extra_: <||>] := Module[{v, degs},
  v = RootDecompositionVerify[a, terms, op];
  degs = v["Degrees"];
  If[! TrueQ[v["Verified"]], Message[Algebraic::verify];
    Return[failure["Verification", "A candidate failed exact verification"]]];
  Join[<|"Terms" -> terms, "Degrees" -> degs, "MaximumDegree" -> Max[degs], "LowerBound" -> lb,
    "Optimal" -> optimal, "ScopeOptimal" -> scopeOptimal, "Scope" -> scope, "Verified" -> v["Verified"],
    "Expression" -> Inactive[op] @@ terms, "Method" -> method|>, extra]];

(* the index of a among the roots of the Galois data and its coordinates,
   or the failure the three engines report *)
targetOf[gd_, a_] := With[{target = locateTarget[gd, a]},
  If[target === $Failed, failure["RootIndex", "Could not locate the input among the roots"],
    {target, gd["RootCoordinates"][[target]]/gd["Scale"]}]];
(* the coordinates of a and the stabilizer an "InputField" scope restricts
   the search to, or the failure *)
galoisTarget[gd_, a_, scope_] := Replace[targetOf[gd, a],
  {t_, v_} :> {v, If[scope === "InputField", stabilizerOf[gd, t], None]}];
(* the engine-dependent extra keys of a result, and the degrees a search walks *)
engineExtra[fd_] := If[fd["Type"] === "InputField",
  <|"AmbientDegree" -> fd["Degree"], "AmbientGalois" -> fd["Galois"]|>, <|"GroupOrder" -> fd["Order"]|>];
degreeList[dmax_, lb_, n_] := If[dmax === Automatic, Range[lb, n - 1], {dmax}];
(* the input-field fast path settles the question when the ambient field is
   Galois, when only that field was asked about, or when it already reached
   the lower bound; otherwise its result is kept as a fallback *)
fastPathDecisiveQ[fd_, scope_, engine_, res_, lb_] := fd["Galois"] || scope === "InputField" ||
  engine === "InputField" || (! kFailureQ[res] && res["MaximumDegree"] == lb);
preferResult[res_, fallback_] := If[res =!= $Failed && ! kFailureQ[res], res, fallback];
notFoundFailure[dmax_, extra_: <||>] := failure["NotFound", "No representation with the requested maximum degree",
  Join[<|"MaximumDegree" -> dmax|>, extra]];
(* the one-component answer under a cap of one component *)
singleComponent[a_, op_, n_, lb_, dmax_, scope_, method_, what_, extra_: <||>] :=
  If[dmax === Automatic || n <= dmax,
    makeResult[a, op, {kRootReduce[a]}, lb, scope, method, lb == n, True, extra],
    failure["NotFound", "The input itself exceeds the degree bound for a single " <> what]];
(* the Gaussian trivial result, written without makeResult *)
gaussianTrivialResult[a_, n_, lb_, scope_, method_, optimal_, scopeOptimal_, extra_: <||>] :=
  Join[<|"Terms" -> {{1, kRootReduce[a]}}, "Degrees" -> {n}, "MaximumDegree" -> n, "LowerBound" -> lb,
    "Optimal" -> optimal, "ScopeOptimal" -> scopeOptimal, "Scope" -> scope, "Verified" -> True,
    "Expression" -> Inactive[Plus][kRootReduce[a]], "Method" -> method, "Coefficients" -> "GaussianRationals"|>, extra];

(* locate c*a among the roots of the Galois data; returns the index *)
locateTarget[gd_, a_] := With[{c = gd["Scale"]},
  kFirstIndex[gd["Roots"], _?(kExactZeroQ[# - c a] &), $Failed]];

stabilizerOf[gd_, target_] := Select[Range[gd["Order"]], gd["Permutations"][[#, target]] == target &];

(* ------------------------------------------------------------------ *)
(* Additive decomposition                                             *)
(* ------------------------------------------------------------------ *)

Options[RootSumDecomposition] = {
  "Scope" -> "Global",               (* "Global" or "InputField" *)
  "Engine" -> Automatic,             (* Automatic, "InputField" or "SplittingField" *)
  "Coefficients" -> "Rationals",     (* "Rationals" or "GaussianRationals" *)
  "MaxTerms" -> Infinity,
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12
};

(* maximal fields of degree <= d (contained in the target's field when stab is given) *)
eligibleFields[fd_, d_, stab_: None] :=
  Select[fd["Subgroups"], #["Index"] <= d && (stab === None || SubsetQ[#["Elements"], stab]) &];

candidateFields[gd_, d_, stab_: None] := Module[{subs = eligibleFields[gd, d, stab]},
  Select[subs, Function[H, ! AnyTrue[subs, #["Index"] > H["Index"] &&
    If[gd["Type"] === "Galois", SubsetQ[H["Elements"], #["Elements"]],
      fieldContainsQ[#["FixedField"], H["FixedField"]]] &]]]];


(* Solve v in the sum of the given spaces (each an association with a "Basis" of rows);
   returns the list of {space, contribution vector} or $Failed. *)
solveInSpaces[spaces_, v_] := Module[{B, sol, lens, p = 1, chunks},
  If[spaces === {}, Return[$Failed]];
  B = kTranspose[Join @@ (#["Basis"] & /@ spaces)];
  sol = kLinearSolve[B, v];
  If[sol === $Failed, Return[$Failed]];
  lens = Length[#["Basis"]] & /@ spaces;
  chunks = Table[With[{ch = Take[sol, {p, p + lens[[i]] - 1}]}, p += lens[[i]]; ch], {i, Length[spaces]}];
  Select[MapThread[{#1, #2 . #1["Basis"]} &, {spaces, chunks}], #[[2]] != 0 #[[2]] &]];

findSumRepresentation[spaces_, v_, maxTerms_] := Module[{limit, res, full = $Failed},
  limit = If[maxTerms === Infinity, Min[3, Length[spaces]], Min[maxTerms, Length[spaces]]];
  If[maxTerms === Infinity && Length[spaces] > limit,
    full = solveInSpaces[spaces, v];
    If[full === $Failed, Return[$Failed]]];
  res = Catch[
    Do[Do[With[{r = solveInSpaces[s, v]}, If[r =!= $Failed, Throw[r, foundTag]]], {s, Subsets[spaces, {k}]}], {k, 1, limit}];
    $Failed, foundTag];
  If[res === $Failed, full, res]];

RootSumDecomposition[a_, opts : OptionsPattern[]] := RootSumDecomposition[a, Automatic, opts];

(* dmax excludes a rule: with a plain dmax_, Mathics matched
   RootSumDecomposition[a, "Scope" -> s] against this definition, binding the rule to dmax
   and leaving no options, where the Wolfram kernel picks the definition
   above. *)
RootSumDecomposition[a_, dmax : Except[_Rule | _RuleDelayed], OptionsPattern[]] := Module[
  {in, n, lb, scope = OptionValue["Scope"], coeffs = OptionValue["Coefficients"], trivial, gaussian},
  If[! degreeLimitQ[dmax] || ! componentLimitQ[OptionValue["MaxTerms"]] ||
      ! MemberQ[{"Rationals", "GaussianRationals"}, coeffs] ||
      ! engineOptionsQ[scope, OptionValue["Engine"], OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]],
    Return[failure["InvalidOptions", "Invalid additive decomposition options"]]];
  If[coeffs === "GaussianRationals" && OptionValue["MaxTerms"] =!= Infinity,
    Return[failure["UnsupportedOptions", "Finite MaxTerms with Gaussian coefficients requires a rank-constrained search and is not implemented"]]];
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  n = in["Degree"];
  gaussian = coeffs === "GaussianRationals";
  lb = If[n == 1, 1, If[gaussian, gaussianPrimeBound[n], lowerBoundFromPolynomial[in["Polynomial"]]]];
  If[dmax =!= Automatic && dmax < lb, Return[degreeFailure[dmax, lb]]];
  trivial := If[gaussian, gaussianTrivialResult[a, n, lb, scope, "Trivial", lb == n, lb == n],
    makeResult[a, Plus, {kRootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n]];
  If[OptionValue["MaxTerms"] === 1, Return[singleComponent[a, Plus, n, lb, dmax, scope, "SingleTerm", "term"]]];
  If[n == 1 || (dmax =!= Automatic && dmax >= n) || lb == n, Return[trivial]];
  (* Everything below this point needs the Galois engine, directly or through
     the input-field fast path, so a kernel whose Root numerics are not what
     they report is refused here.  The answers above -- the trivial and
     single-term ones, the lower bound and the degree checks -- are exact and
     stay available. *)
  If[! kNativeQ["RootPrecision"], Return[kernelPrecisionFailure[]]];
  retryPrecision[Function[prec, sumDecompositionCore[a, in, dmax, lb, scope, gaussian, OptionValue["MaxTerms"], prec,
    OptionValue["MaxGroupOrder"], OptionValue["MaxTries"], OptionValue["Engine"]]], OptionValue["WorkingPrecision"]]];

sumDecompositionCore[a_, in_, dmax_, lb0_, scope_, gaussian_, maxTerms_, prec_, maxOrder_, maxTries_, engine_] := Module[
  {n = in["Degree"], lb = lb0, poly, gd, va, stab, res = $Failed, fd},
  poly = in["Polynomial"];
  (* fast path inside K = Q(a): complete within K; globally complete when K is Galois *)
  If[! gaussian && engine =!= "SplittingField",
    fd = inputFieldAt[poly, a];
    If[fd =!= $Failed,
      res = sumSearch[fd, a, fd["TargetCoordinates"], None, n, lb, dmax, scope, maxTerms,
        If[fd["Galois"], "GaloisInputField", "InputFieldSubfields"], fd["Galois"]];
      If[fastPathDecisiveQ[fd, scope, engine, res, lb], Return[res]]]];
  If[gaussian && kPolynomialRemainder[poly, x^2 + 1, x] =!= 0, poly = kExpand[poly (x^2 + 1)]];
  gd = RootGaloisData[poly, x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[kFailureQ[gd], Return[preferResult[res, gd]]];
  Module[{c = gd["Scale"], tv = galoisTarget[gd, a, scope], iCoord, iMult},
    If[kFailureQ[tv], Return[tv]];
    {va, stab} = tv;
    lb = Max[lb, If[gaussian, gaussianExponentBound[gd["Exponent"]], exponentBound[gd["Exponent"]]]];
    If[gaussian,
      iCoord = gd["RootCoordinates"][[kFirstIndex[gd["Roots"], _?(kExactZeroQ[# - c I] &)]]]/c;
      iMult = multiplicationMatrix[gd, conjugates[gd, iCoord]];
      Return[gaussianSumSearch[gd, a, va, iMult, n, lb, dmax, scope, maxTerms, stab]]];
    If[lb >= n,
      If[dmax =!= Automatic && dmax < n, Return[degreeFailure[dmax, lb]]];
      Return[makeResult[a, Plus, {kRootReduce[a]}, lb, scope, "CompleteSearch", True, True, <|"GroupOrder" -> gd["Order"]|>]]];
    sumSearch[gd, a, va, stab, n, lb, dmax, scope, maxTerms,
      If[scope === "Global", "SplittingFieldFixedSpaces", "InputFieldSubfields"], scope === "Global"]]];

(* additive search in a field-data structure; complete within the field, globally complete if completeQ *)
(* the first degree in dlist at which the maximal fields represent va, as
   the representation; basis gives the coefficient space of one field *)
representationAtDegree[fd_, va_, stab_, dlist_, maxTerms_, basis_] := Catch[
  Do[
    With[{spaces = Table[<|"Index" -> H["Index"], "Field" -> H["FixedField"], "Basis" -> basis[H]|>,
        {H, candidateFields[fd, d, stab]}]},
      With[{rep = findSumRepresentation[spaces, va, maxTerms]},
        If[rep =!= $Failed, Throw[rep, foundTag]]]],
    {d, dlist}];
  $Failed, foundTag];

sumSearch[fd_, a_, va_, stab_, n_, lb_, dmax_, scope_, maxTerms_, method_, completeQ_] := Module[
  {extra = engineExtra[fd], rep, rational = 0, terms = {}, mean, term, atLowerBound},
  rep = representationAtDegree[fd, va, stab, degreeList[dmax, lb, n], maxTerms, #["FixedField"] &];
  If[rep =!= $Failed,
    Do[mean = meanTraceOf[fd, e[[2]]]; rational += mean;
      term = e[[2]] - mean UnitVector[Length[va], 1];
      If[term != 0 term, AppendTo[terms, term]], {e, rep}];
    terms = toExact[fd, #] & /@ terms;
    (* Centering must not add a component beyond a finite MaxTerms cap. *)
    If[rational != 0,
      If[maxTerms =!= Infinity && Length[terms] >= maxTerms,
        terms[[1]] = kRootReduce[terms[[1]] + rational], AppendTo[terms, rational]]];
    If[terms === {}, terms = {0}];
    atLowerBound = Max[termDegrees[terms]] == lb;
    Return[makeResult[a, Plus, terms, lb, scope, method,
      atLowerBound || ((dmax === Automatic) && completeQ && maxTerms === Infinity),
      (dmax === Automatic && (completeQ || scope === "InputField")) || atLowerBound, extra]]];
  If[dmax === Automatic,
    makeResult[a, Plus, {kRootReduce[a]}, lb, scope, "CompleteSearch", (completeQ && maxTerms === Infinity) || n == lb,
      completeQ || scope === "InputField" || n == lb, extra],
    notFoundFailure[dmax, Join[<|"Scope" -> scope|>, extra]]]];

gaussianSumSearch[gd_, a_, va_, iMult_, n_, lb_, dmax_, scope_, maxTerms_, stab_] := Module[{rep},
  rep = representationAtDegree[gd, va, stab, degreeList[dmax, lb, n], maxTerms,
    canonicalRows[Join[#["FixedField"], Map[iMult . # &, #["FixedField"]]]] &];
  If[rep =!= $Failed, Return[gaussianResult[gd, a, rep, iMult, lb, scope, dmax === Automatic]]];
  If[dmax === Automatic,
    gaussianTrivialResult[a, n, lb, scope, "CompleteSearch", scope === "Global" || n == lb, True, <|"GroupOrder" -> gd["Order"]|>],
    notFoundFailure[dmax, <|"Scope" -> scope|>]]];

(* Gaussian mode: each contribution e in E + iE is split as u + i w with u, w in E. *)
gaussianResult[gd_, a_, rep_, iMult_, lb_, scope_, automatic_] := Module[{terms = {}, Bf, sol, u, w, degs, pivot, verified},
  Do[
    Bf = e[[1]]["Field"];
    sol = kLinearSolve[kTranspose[Join[Bf, Map[iMult . # &, Bf]]], e[[2]]];
    If[sol === $Failed, Throw["precision", precTag]];
    u = Take[sol, Length[Bf]] . Bf; w = Drop[sol, Length[Bf]] . Bf;
    Which[
      w == 0 w, AppendTo[terms, {1, u}],
      u == 0 u, AppendTo[terms, {I, w}],
      MatrixRank[{u, w}] == 1, pivot = kFirstIndex[u, _?(# != 0 &)];
        AppendTo[terms, {1 + I w[[pivot]]/u[[pivot]], u}],
      True, AppendTo[terms, {1, u}]; AppendTo[terms, {I, w}]],
    {e, rep}];
  terms = Map[{#[[1]], elementToAlgebraic[gd, #[[2]]]} &, terms];
  If[terms === {}, terms = {{1, 0}}];
  degs = algebraicDegree[#[[2]]] & /@ terms;
  verified = kExactZeroQ[a - Total[Times @@@ terms]];
  If[! verified, Return[failure["Verification", "A Gaussian candidate failed exact verification"]]];
  <|"Terms" -> terms, "Degrees" -> degs, "MaximumDegree" -> Max[degs], "LowerBound" -> lb,
    "Optimal" -> (Max[degs] == lb || (automatic && scope === "Global")), "ScopeOptimal" -> (automatic || Max[degs] == lb), "Scope" -> scope,
    "Verified" -> verified,
    "Expression" -> Inactive[Plus] @@ (Times @@@ terms), "Method" -> "GaussianFixedSpaces",
    "Coefficients" -> "GaussianRationals", "GroupOrder" -> gd["Order"]|>];

(* ------------------------------------------------------------------ *)
(* Multiplicative decomposition                                       *)
(* ------------------------------------------------------------------ *)

Options[RootProductDecomposition] = {
  "Scope" -> "Global",
  "Engine" -> Automatic,
  "MaxFactors" -> Infinity,
  "RecursionDepth" -> 3,
  "TensorTest" -> True,
  "BoundedSearch" -> {2, 3},          (* {height, factors} for the final quadratic dictionary search, or None *)
  "WorkingPrecision" -> 80,
  "MaxGroupOrder" -> 400,
  "MaxTries" -> 12
};

(* p-adically minimal integral scaling: the smallest rational q > 0 (prime by prime) such that q*u is an
   algebraic integer; this removes accidental huge scalings produced by linear algebra. *)
integralScale[f_] := Module[{d = Exponent[f, x], c, primes, q = 1, e, v},
  c = kCoefficientList[f/Coefficient[f, x, d], x];  (* monic, rational *)
  primes = Union @@ (First /@ FactorInteger[#] & /@ DeleteCases[Abs[Join[Numerator[c], Denominator[c]]], 0 | 1]);
  Do[
    v[r_] := If[r == 0, Infinity, IntegerExponent[Numerator[r], p] - IntegerExponent[Denominator[r], p]];
    e = Max[Table[If[c[[i + 1]] == 0, -Infinity, Ceiling[-v[c[[i + 1]]]/(d - i)]], {i, 0, d - 1}]];
    If[e =!= -Infinity, q = q p^e],
    {p, primes}];
  q];

niceScale[u_] := Module[{f, c, nz, d, best = 1, h, hb = {Infinity, 0, 0}, g, q0},
  f = minimalPolynomialOf[u];
  If[f === $Failed, Return[1]];
  c = kCoefficientList[f, x]; d = Length[c] - 1; nz = kIndices[c, Except[0]];
  q0 = integralScale[f];
  Do[
    g = primitiveIntegerCoefficients[ReplacePart[c, Thread[nz -> c[[nz]] (q q0)^(d + 1 - nz)]]];
    h = {Max[Abs[g]], -Sign[First[g]], Abs[Log[Abs[q]]]};
    If[Order[h, hb] == 1, hb = h; best = q q0],
    {q, DeleteDuplicates[Flatten[Table[{s k/l, s l/k}, {k, 1, 12}, {l, 1, 12}, {s, {1, -1}}]]]}];
  best];

principalRoot[u_, t_Integer] := If[t == 1, u, kRootReduce[Power[u, 1/t]]];

compositumDegreeBound[fd_, fields_] := If[fd["Type"] === "Galois",
  fd["Order"]/Length[Intersection @@ (#["Elements"] & /@ fields)], Times @@ (#["Index"] & /@ fields)];

twoFactorSearch[fd_, a_, n_, d_, stab_, scope_, ma_] := Module[{tmax, subs, pairs, mt},
  tmax = If[scope === "Global" && stab === None && (fd["Type"] === "Galois" || fd["Galois"]), Min[d, Floor[d^2/n]], 1];
  Catch[
    Do[
      subs = eligibleFields[fd, d/t, stab];
      If[subs === {}, Continue[]];
      mt = kMatrixPower[ma, t];
      pairs = Select[Join @@ Table[{subs[[i]], subs[[j]]}, {i, Length[subs]}, {j, i, Length[subs]}],
        n <= t compositumDegreeBound[fd, #] &];
      pairs = SortBy[pairs, {Max[#[[1]]["Index"], #[[2]]["Index"]], #[[1]]["Index"] + #[[2]]["Index"]} &];
      Do[
        With[{res = tryPair[fd, pr, mt, t, a, d]}, If[res =!= $Failed, Throw[res, foundTag]]],
        {pr, pairs}],
      {t, 1, tmax}];
    $Failed, foundTag]];

(* choose a small nullspace vector: LLL-reduce the integer basis, take the shortest E-part *)
shortestVector[ns_, len_] := Module[{ints, red},
  ints = clearDenominators /@ ns;
  red = If[Length[ints] > 1, kLatticeReduce[ints], ints];
  First[kMinimalBy[red, With[{h = Take[#, len]}, h . h] &]]];

tryPair[fd_, pr_, mt_, t_, a_, d_] := Module[{EE = pr[[1]]["FixedField"], FF = pr[[2]]["FixedField"], ns, u, uExact, q, b, cc, degs},
  ns = NullSpace[MapThread[Join, {kTranspose[EE], -mt . kTranspose[FF]}]];
  If[ns === {}, Return[$Failed]];
  u = Take[shortestVector[ns, Length[EE]], Length[EE]] . EE;
  uExact = toExact[fd, u];
  q = niceScale[uExact];
  b = principalRoot[kRootReduce[q uExact], t];
  cc = kRootReduce[a/b];
  degs = algebraicDegree /@ {b, cc};
  If[Max[degs] <= d && kExactZeroQ[a - b cc],
    <|"Terms" -> {b, cc}, "Exponent" -> t, "FieldDegrees" -> {pr[[1]]["Index"], pr[[2]]["Index"]}|>,
    $Failed]];

(* Exact rank-one tensor test for families of at least three subfields whose product basis spans L. *)
familiesWithProduct[subs_, target_, minSize_] := Module[{rec},
  rec[start_, remaining_, acc_] := Module[{out = {}, i},
    If[remaining == 1, Return[If[Length[acc] >= minSize, {acc}, {}]]];
    Do[If[Divisible[remaining, subs[[i]]["Index"]],
        out = Join[out, rec[i + 1, remaining/subs[[i]]["Index"], Append[acc, subs[[i]]]]]],
      {i, start, Length[subs]}];
    out];
  rec[1, target, {}]];

$multCache = <||>;

tensorSearch[gd_, va_, d_, stab_, maxFactors_] := Module[{subs, ord = gd["Order"], fams, count = 0},
  subs = SortBy[Select[eligibleFields[gd, d, stab], #["Index"] > 1 &], #["Index"] &];
  fams = Select[familiesWithProduct[subs, ord, 3], Length[#] <= maxFactors &];
  $multCache = <||>;
  Catch[
    Do[count++; If[count > 5000, Throw[$Failed, foundTag]];
      With[{res = tensorTest[gd, fam, va]}, If[res =!= $Failed, Throw[res, foundTag]]], {fam, fams}];
    $Failed, foundTag]];

tensorTest[gd_, fam_, va_] := Module[{bases, prodBasis, mats, coords, dims, tensor, piv, pos, vecs, ok, elems, ord = gd["Order"], idx},
  bases = #["FixedField"] & /@ fam; dims = Length /@ bases;
  If[compositumDegreeBound[gd, fam] < ord, Return[$Failed]];
  mats = Map[Function[B, Map[(If[! kKeyExistsQ[$multCache, #], kAssociateTo[$multCache, # -> multMatrix[gd, #]]]; $multCache[#]) &, B]], bases];
  idx = Tuples[Range /@ dims];
  prodBasis = Table[Fold[#2 . #1 &, UnitVector[ord, 1], Table[mats[[j, i[[j]]]], {j, Length[fam]}]], {i, idx}];
  If[MatrixRank[prodBasis] < ord, Return[$Failed]];
  coords = kLinearSolve[kTranspose[prodBasis], va];
  tensor = kArrayReshape[coords, dims];
  pos = kFirstPositionAtLevel[tensor, _?(# != 0 &), Missing["NotFound"], Length[dims]];
  If[kMissingQ[pos], Return[$Failed]];
  piv = Extract[tensor, pos];
  vecs = Table[Table[Extract[tensor, ReplacePart[pos, j -> i]]/piv, {i, dims[[j]]}], {j, Length[fam]}];
  ok = tensor == piv Fold[Outer[Times, #1, #2] &, First[vecs], Rest[vecs]];
  If[! ok, Return[$Failed]];
  elems = MapThread[#1 . #2 &, {vecs, bases}];
  elems[[1]] = piv elems[[1]];
  elems];

(* merge rational factors and rescale each factor to a small representative *)
cleanProductTerms[terms_, maxFactors_: Infinity] := Module[{rat, rest, q},
  rat = Times @@ Select[terms, kRationalQ];
  rest = Select[terms, ! kRationalQ[#] &];
  If[rest === {}, Return[{rat}]];
  Do[q = niceScale[rest[[j]]]; rest[[j]] = kRootReduce[q rest[[j]]]; rat /= q, {j, 2, Length[rest]}];
  rest[[1]] = kRootReduce[rat rest[[1]]];
  q = niceScale[rest[[1]]];
  rest[[1]] = kRootReduce[q rest[[1]]];
  If[q != 1,
    If[Length[rest] >= maxFactors, rest[[Length[rest]]] = kRootReduce[rest[[Length[rest]]]/q], AppendTo[rest, 1/q]]];
  rest];

RootProductDecomposition[a_, opts : OptionsPattern[]] := RootProductDecomposition[a, Automatic, opts];

(* dmax excludes a rule: with a plain dmax_, Mathics matched
   RootProductDecomposition[a, "Scope" -> s] against this definition, binding the rule to dmax
   and leaving no options, where the Wolfram kernel picks the definition
   above. *)
RootProductDecomposition[a_, dmax : Except[_Rule | _RuleDelayed], OptionsPattern[]] := Module[
  {in, n, lb, scope = OptionValue["Scope"], trivial, bd = OptionValue["BoundedSearch"]},
  If[! degreeLimitQ[dmax] || ! componentLimitQ[OptionValue["MaxFactors"]] ||
      ! IntegerQ[OptionValue["RecursionDepth"]] || OptionValue["RecursionDepth"] < 0 ||
      ! MemberQ[{True, False}, OptionValue["TensorTest"]] ||
      ! (bd === None || (MatchQ[bd, {_Integer, _Integer}] && And @@ (positiveIntegerQ /@ bd))) ||
      ! engineOptionsQ[scope, OptionValue["Engine"], OptionValue["WorkingPrecision"], OptionValue["MaxGroupOrder"], OptionValue["MaxTries"]],
    Return[failure["InvalidOptions", "Invalid multiplicative decomposition options"]]];
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  n = in["Degree"];
  If[n == 1 && in["Value"] === 0,
    Return[makeResult[0, Times, {0}, 1, scope, "Trivial", True, True, <|"TwoFactorOptimal" -> True, "NormExponent" -> 1|>]]];
  lb = If[n == 1, 1, lowerBoundFromPolynomial[in["Polynomial"]]];
  If[dmax =!= Automatic && dmax < lb, Return[degreeFailure[dmax, lb]]];
  trivial := makeResult[a, Times, {kRootReduce[a]}, lb, scope, "Trivial", lb == n, lb == n, <|"TwoFactorOptimal" -> (lb == n), "NormExponent" -> 1|>];
  If[OptionValue["MaxFactors"] === 1,
    Return[singleComponent[a, Times, n, lb, dmax, scope, "SingleFactor", "factor",
      <|"TwoFactorOptimal" -> (lb == n), "NormExponent" -> 1|>]]];
  If[n == 1 || (dmax =!= Automatic && dmax >= n) || lb == n, Return[trivial]];
  (* the engine refusal, as in RootSumDecomposition *)
  If[! kNativeQ["RootPrecision"], Return[kernelPrecisionFailure[]]];
  retryPrecision[Function[prec, productDecompositionCore[a, in, dmax, lb, scope, OptionValue["MaxFactors"], OptionValue["RecursionDepth"],
    OptionValue["TensorTest"], prec, OptionValue["MaxGroupOrder"], OptionValue["MaxTries"], OptionValue["Engine"], bd]],
    OptionValue["WorkingPrecision"]]];

productDecompositionCore[a_, in_, dmax_, lb0_, scope_, maxFactors_, depth_, tensorQ_, prec_, maxOrder_, maxTries_, engine_, bounded_] := Module[
  {n = in["Degree"], lb = lb0, gd, fd, res = $Failed},
  (* fast path inside K = Q(a) *)
  If[engine =!= "SplittingField",
    fd = inputFieldAt[in["Polynomial"], a];
    If[fd =!= $Failed,
      res = productSearch[fd, a, fd["TargetCoordinates"], None, n, lb, dmax, scope, maxFactors, depth, tensorQ, prec, maxOrder, maxTries, engine,
        fd["Galois"] || scope === "InputField", bounded];
      If[fastPathDecisiveQ[fd, scope, engine, res, lb], Return[res]]]];
  gd = RootGaloisData[in["Polynomial"], x, "WorkingPrecision" -> prec, "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries];
  If[kFailureQ[gd], Return[preferResult[res, gd]]];
  Module[{tv = galoisTarget[gd, a, scope], va, stab},
    If[kFailureQ[tv], Return[tv]];
    {va, stab} = tv;
    lb = Max[lb, exponentBound[gd["Exponent"]]];
    If[lb >= n,
      If[dmax =!= Automatic && dmax < n, Return[degreeFailure[dmax, lb]]];
      Return[makeResult[a, Times, {kRootReduce[a]}, lb, scope, "Trivial", True, True, <|"TwoFactorOptimal" -> True, "NormExponent" -> 1, "GroupOrder" -> gd["Order"]|>]]];
    productSearch[gd, a, va, stab, n, lb, dmax, scope, maxFactors, depth, tensorQ, prec, maxOrder, maxTries, engine, True, bounded]]];

productSearch[fd_, a_, va_, stab_, n_, lb_, dmax_, scope_, maxFactors_, depth_, tensorQ_, prec_, maxOrder_, maxTries_, engine_, completeQ_, bounded_] := Module[
  {dlist = degreeList[dmax, lb, n], twoDegrees, d, two, best, terms, degs, res, tens, sub, extra = engineExtra[fd],
   remaining, f, parts, ma, atLowerBound},
  twoDegrees = Select[dlist, #^2 >= n &];
  (* 1. two-factor algorithm (norm-intersection criterion; complete when the ambient field is Galois) *)
  two = $Failed;
  If[twoDegrees =!= {}, ma = multMatrix[fd, va]];
  Do[two = twoFactorSearch[fd, a, n, d, stab, scope, ma]; If[two =!= $Failed, Break[]], {d, twoDegrees}];
  If[two === $Failed && dmax === Automatic, two = <|"Terms" -> {kRootReduce[a]}, "Exponent" -> 1, "FieldDegrees" -> {n}|>];
  best = If[two === $Failed, $Failed,
    atLowerBound = Max[termDegrees[two["Terms"]]] == lb;
    makeResult[a, Times, two["Terms"], lb, scope,
      If[Length[two["Terms"]] == 1, "CompleteTwoFactorSearch", "NormIntersection"], atLowerBound,
      atLowerBound || (maxFactors === 2 && dmax === Automatic && completeQ),
      Join[<|"TwoFactorOptimal" -> (atLowerBound || ((dmax === Automatic) && completeQ)),
        "NormExponent" -> two["Exponent"]|>, extra]]];
  If[maxFactors === 2,
    Return[If[best === $Failed, failure["NotFound", "No two-factor representation with the requested maximum degree", <|"MaximumDegree" -> dmax|>], best]]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 2. rank-one tensor test for independent families of subfields *)
  If[tensorQ,
    Do[
      If[best =!= $Failed && d >= best["MaximumDegree"], Break[]];
      tens = tensorSearch[fd, va, d, stab, maxFactors];
      If[tens =!= $Failed,
        terms = cleanProductTerms[toExact[fd, #] & /@ tens, maxFactors];
        atLowerBound = Max[termDegrees[terms]] == lb;
        res = makeResult[a, Times, terms, lb, scope, "TensorRankOne", atLowerBound, atLowerBound,
          Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]];
        If[res["Verified"] && (best === $Failed || res["MaximumDegree"] < best["MaximumDegree"]), best = res; Break[]]],
      {d, dlist}]];
  If[best =!= $Failed && best["MaximumDegree"] == lb, Return[best]];
  (* 3. recursive splitting of the factors *)
  If[best =!= $Failed && depth > 0 && Length[best["Terms"]] >= 2,
    remaining = maxFactors; terms = {};
    Do[
      f = best["Terms"][[j]]; parts = {f};
      If[algebraicDegree[f] > lb,
        sub = RootProductDecomposition[f, "RecursionDepth" -> depth - 1, "WorkingPrecision" -> prec,
                "MaxGroupOrder" -> maxOrder, "MaxTries" -> maxTries, "TensorTest" -> tensorQ, "Engine" -> engine,
                "Scope" -> scope, "BoundedSearch" -> bounded, "MaxFactors" -> remaining - Length[best["Terms"]] + j];
        If[! kFailureQ[sub] && sub["Verified"], parts = sub["Terms"]]];
      remaining -= Length[parts]; terms = Join[terms, parts],
      {j, Length[best["Terms"]]}];
    degs = termDegrees[terms];
    If[Max[degs] < best["MaximumDegree"],
      best = makeResult[a, Times, terms, lb, scope, "RecursiveSplitting", Max[degs] == lb, Max[degs] == lb,
        Join[<|"TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]]]];
  (* 4. small bounded dictionary search (quadratic dictionary only; larger catalogs are enormous) *)
  If[scope === "Global" && bounded =!= None && (best === $Failed || best["MaximumDegree"] > lb),
    Do[
      res = RootBoundedDecomposition[a, Times, dd, bounded[[1]], Min[bounded[[2]], maxFactors]];
      If[! kFailureQ[res] && res["Verified"] && (best === $Failed || res["MaximumDegree"] < best["MaximumDegree"]),
        best = Join[res, <|"Scope" -> scope, "TwoFactorOptimal" -> False, "NormExponent" -> 1|>, extra]; Break[]],
      {dd, lb, Min[2, If[best === $Failed, dmax, best["MaximumDegree"] - 1]]}]];
  If[best === $Failed, notFoundFailure[dmax], best]];

(* ------------------------------------------------------------------ *)
(* Bounded dictionary search                                          *)
(* ------------------------------------------------------------------ *)

catalogRoots[d_, h_, firstDegree_] := Module[{polys},
  polys = Join @@ Table[
    Select[Tuples[Append[ConstantArray[Range[-h, h], m], Range[h]]],
      GCD @@ # == 1 && kIrreduciblePolynomialQ[FromDigits[Reverse[#], x]] &],
    {m, firstDegree, d}];
  polys = FromDigits[Reverse[#], x] & /@ polys;
  DeleteDuplicates[Join @@ Table[kRootReduce[rootObject[p, j]], {p, polys}, {j, Exponent[p, x]}]]];

RootDecompositionCatalog[d_Integer?Positive, h_Integer?Positive] := catalogRoots[d, h, 1];

RootDecompositionCatalog[_, _] := failure["InvalidBounds", "Degree and height must be positive integers"];

RootBoundedDecomposition[a_, op : (Plus | Times), d_Integer, h_Integer, r_Integer] := Module[
  {cat, n, lb, search, residual, in, res},
  If[! And @@ (positiveIntegerQ /@ {d, h, r}), Return[failure["InvalidBounds", "Degree, height and component count must be positive integers"]]];
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  n = in["Degree"]; lb = lowerBoundFromPolynomial[in["Polynomial"]];
  If[d < lb, Return[degreeFailure[d, lb]]];
  If[n <= d, Return[makeResult[a, op, {kRootReduce[a]}, lb, "Bounded", "Trivial", lb == n, lb == n || r == 1]]];
  (* Degree of a compositum is at most the product of the factor degrees.
     Reject impossible boxes before constructing an exponential-size catalog. *)
  If[n > d^r, Return[failure["NotFoundWithinBounds", "The degree exceeds the product of the component degree bounds",
    <|"Degree" -> d, "Height" -> h, "Components" -> r|>]]];
  cat = catalogRoots[d, h, 2];
  residual[prefix_] := kRootReduce[If[op === Plus, a - Total[prefix], a/Times @@ prefix]];
  search[prefix_, start_, slots_] := Module[{rr, deg, i},
    rr = residual[prefix];
    deg = algebraicDegree[rr];
    If[deg <= d, Throw[Append[prefix, rr], foundTag]];
    If[slots <= 1 || deg > d^slots || largestPrimeFactor[deg] > d, Return[]];
    Do[search[Append[prefix, cat[[i]]], i, slots - 1], {i, start, Length[cat]}]];
  res = Catch[search[{}, 1, r]; $Failed, foundTag];
  If[res === $Failed,
    failure["NotFoundWithinBounds", "No decomposition found within the bounds", <|"Degree" -> d, "Height" -> h, "Components" -> r|>],
    With[{atLowerBound = Max[termDegrees[res]] == lb},
      makeResult[a, op, res, lb, "Bounded", "DictionarySearch", atLowerBound, atLowerBound]]]];

RootBoundedDecomposition[_, _, _, _, _] := failure["InvalidBounds", "Expected Plus or Times and positive integer bounds"];

(* ================================================================ *)

(* 3.  Radical expressions                                          *)

(* ================================================================ *)

(* From root-to-radicals/RootToRadicals.wl.  Two layers: structural
   recognizers (a user-supplied subfield generator, ToRadicals, functional
   decomposition, generalized reciprocal symmetry, Dickson polynomials, the
   pair-sum resolvent), and the general Galois-Kummer descent, which is
   complete for solvable inputs.  The descent uses the group, the splitting
   field and the coordinates of section 2 directly; the functional
   decomposition it recurses through is section 1.  Nonsolvability is proved
   by Frobenius cycle types or by the exact group. *)

(* The Galois engine, the exact-algebra helpers and the Frobenius tests of
   section 2 are used directly: the four operations now share one private
   context, so the sixteen aliases into another package's private context
   that this code used to open are gone. *)

okQ[r_] := ! kFailureQ[r];      (* a usable result of a recursive step *)

(* ------------------------------------------------------------------ *)
(* Radical grammar                                                     *)
(* ------------------------------------------------------------------ *)

(* RadicalExpressionQ and RadicalDepth are defined once, in section 5. *)

(* ------------------------------------------------------------------ *)
(* Numerics and verification                                           *)
(* ------------------------------------------------------------------ *)

$prec = 60;

(* the candidate closest to the target value, if it is clearly separated from the others *)
selectCandidate[cands_List, target_] := If[cands === {}, $Failed,
  With[{k = nearestByMargin[Abs[kN[cands, $prec] - kN[target, $prec]], 10^-20, 0, 10^-15]},
    If[k === $Failed, $Failed, cands[[k]]]]];

(* exact verification with a time limit; True, False or Indeterminate (numerically equal, not proved) *)
verifyExact[expr_, a_, limit_] := Module[{r = TimeConstrained[kExactZeroQ[expr - a], limit, Indeterminate]},
  If[r === Indeterminate && ! TrueQ[Abs[kN[expr - a, 200]] < 10^-150], False, r]];

(* does the polynomial fac (exact algebraic coefficients, possibly of height 10^100) vanish at a?  The
   evaluation precision exceeds the cancellation between the terms, and the residual is compared with
   the largest term. *)
vanishesAtQ[fac_, a_] := Module[{n = Exponent[fac, x], cl, prec, na, terms},
  If[n < 1, Return[False]];
  cl = kCoefficientList[fac, x];
  prec = 60 + Max[0, Ceiling[Log10[Max[Append[Abs[kN[cl, 20]], 1]]]]];
  na = kN[a, prec];
  terms = kN[cl, prec] kPowerList[na, n];
  TrueQ[Abs[Total[terms]] < 10^-25 Max[Abs[terms]]]];

(* ------------------------------------------------------------------ *)
(* Frobenius negative tests                                            *)
(* ------------------------------------------------------------------ *)

(* prime degree n: a solvable transitive group lies in AGL(1,n), whose cycle types are 1^n, n, 1 d^((n-1)/d) *)
agl1TypeQ[degs_, n_] := degs === {n} || (First[degs] == 1 && Length[Union[Rest[degs]]] == 1);

(* a single prime cycle of length l > n/2 (the rest fixed) makes a transitive group primitive; a
   solvable primitive group has prime-power degree n = p^k and lies in AGL(k,p), where an element
   fixing a point is conjugate into GL(k,p) and its fixed points form a subspace of size p^j, so
   p^k - p^j = l forces l = n - 1.  Hence such a cycle proves nonsolvability unless n is a prime
   power and l = n - 1. *)
singlePrimeCycleQ[degs_, n_] := Module[{l = Last[degs]},
  PrimeQ[l] && 2 l > n && Union[Most[degs]] === {1} && ! (PrimePowerQ[n] && l == n - 1)];

(* True: proved nonsolvable.  False: no obstruction found (inconclusive). *)
frobeniusNonsolvableQ[poly_, maxPrimesIn_: Automatic] :=
  kMemo["frobeniusNonsolvable", {poly, maxPrimesIn}, frobeniusNonsolvableCompute[poly, maxPrimesIn]];
frobeniusNonsolvableCompute[poly_, maxPrimesIn_] := Catch[Module[
  {n = Exponent[poly, x], maxPrimes = Replace[maxPrimesIn, Automatic :> $kFrobeniusPrimesSolvable], bad, p = 2, count = 0},
  bad = If[PrimeQ[n], ! agl1TypeQ[#, n] &, singlePrimeCycleQ[#, n] &];
  With[{d = frobeniusModulus[poly]},
    While[count < maxPrimes,
      p = NextPrime[p];
      If[Mod[d, p] == 0, Continue[]];
      count++;
      If[bad[frobeniusCycleType[poly, p]], Throw[True, moduleTag]]]];
  False], moduleTag];

frobeniusReason[n_] := Which[
  PrimeQ[n], "Frobenius cycle type outside AGL(1," <> ToString[n] <> ")",
  PrimePowerQ[n], "Frobenius element with a long prime cycle that no affine group of degree " <> ToString[n] <> " contains",
  True, "Frobenius element with a long prime cycle in a non-prime-power degree"];

(* the lcm of the orders of the Frobenius elements divides |G|; beyond the limit the resource status
   is settled without building the splitting field.  Returns None or a Failure. *)
orderLimitFailure[poly_, maxOrder_] := With[{mult = frobeniusExponentMultiple[poly]},
  If[mult > maxOrder,
    failure["ResourceLimit", "A divisor of the Galois group order exceeds \"MaxGroupOrder\"",
      <|"GroupOrderMultiple" -> mult, "Limit" -> maxOrder|>],
    None]];

(* the engine's Galois data, with its resource failure renamed *)
galoisData[poly_, maxOrder_, prec_] := With[{gd = RootGaloisData[poly, x, "MaxGroupOrder" -> maxOrder, "WorkingPrecision" -> prec]},
  If[kFailureQ[gd] && gd[[1]] === "GroupOrder",
    failure["ResourceLimit", "The Galois group is larger than \"MaxGroupOrder\"", gd[[2]]], gd]];
(* the same after the Frobenius bound on the group order has been checked
   against the cap, which is cheaper than building the group *)
galoisDataChecked[poly_, maxOrder_, prec_] := With[{limit = orderLimitFailure[poly, maxOrder]},
  If[limit =!= None, limit, galoisData[poly, maxOrder, prec]]];
groupSolvableQ[gd_] := solvableQ[gd["MultiplicationTable"], gd["Identity"], Range[gd["Order"]]];

(* ------------------------------------------------------------------ *)
(* Structural layer                                                    *)
(* ------------------------------------------------------------------ *)

$method = Automatic; $opts = {}; $methodUsed = None; $galoisInfo = <||>; $extension = None;

monic[p_] := kExpand[p/Coefficient[p, x, Exponent[p, x]]];
binomialQ[g_] := With[{n = Exponent[g, x]}, Exponent[g - Coefficient[g, x, n] x^n - Coefficient[g, x, 0], x] <= 0];
formulaSolvableQ[g_] := Exponent[g, x] <= 4 || binomialQ[g];

(* the radical expression of an exact algebraic number, or $Failed *)
sub[a_, depth_] := With[{r = radicalsOf[a, depth]}, If[okQ[r], r, $Failed]];

(* explicit formulas for degrees 2 and 3 (Solve can spend a long time simplifying large radical
   coefficients); the coefficient list is low to high *)
rootOrbit[root_, n_] := root (-1)^(2 Range[0, n - 1]/n);

cubicRoots[{d0_, c0_, b0_, a0_}] := Module[{b = b0/a0, c = c0/a0, d = d0/a0, pp, qq, branches},
  pp = c - b^2/3; qq = 2 b^3/27 - b c/3 + d;
  If[pp === 0, Return[rootOrbit[(-qq)^(1/3), 3] - b/3]];
  branches = rootOrbit[(-qq/2 + Sqrt[qq^2/4 + pp^3/27])^(1/3), 3];
  branches - pp/(3 branches) - b/3];

(* all radical solutions of g(x) = v for a polynomial g whose coefficients may be radicals or
   algebraic atoms: degree <= 4 by formulas or Solve, binomials x^n + c by n-th roots; else $Failed *)
solveWithRadicalRHS[g_, v_] := Module[{n = Exponent[g, x], cl = kCoefficientList[kExpand[g - v], x], sols},
  Which[
    n == 1, {-cl[[1]]/cl[[2]]},
    n == 2, quadraticRoots[cl],
    n == 3 && cl[[1]] =!= 0, cubicRoots[cl],
    n <= 4, sols = Quiet[x /. kSolveRadicals[g == v, x]];
      If[ListQ[sols], Select[sols, RadicalExpressionQ], $Failed],
    binomialQ[g], rootOrbit[(-cl[[1]]/cl[[-1]])^(1/n), n],
    True, $Failed]];

(* solve g(x) = v and pick the solution equal to the exact number target *)
solveAndSelect[g_, v_, target_] := With[{cands = solveWithRadicalRHS[g, v]},
  If[cands === $Failed, $Failed, selectCandidate[cands, target]]];

factorAt[p_, a_, extension_] :=
  kSelectFirst[First /@ Quiet[kFactorListExtension[p, extension]], vanishesAtQ[#, a] &, $Failed];

(* 0. user-supplied subfield generators ("Extension" option): factor p over Q(gens) cumulatively (the
   factor containing a over a larger field divides the one over a smaller field, and factoring a small
   polynomial over a large field is much cheaper than factoring p over it); solve the factor containing
   a with the generators kept as atoms (substituting their radical expressions into high-degree
   coefficients and expanding would blow up), select the branch numerically, and substitute once at the
   end.  This is the pair-sum reduction with the generators given instead of searched for, and it is
   what the notebook of the question does by hand. *)
structuralExtension[a_, p_, depth_] := Catch[Module[{gens, fac = p, rads, sel},
  If[$extension === None, Return[$Failed]];
  gens = Flatten[{$extension}];
  Do[
    fac = factorAt[fac, a, gens[[;; i]]];
    If[fac === $Failed, Throw[$Failed, moduleTag]],
    {i, Length[gens]}];
  If[! formulaSolvableQ[fac], Return[$Failed]];
  rads = Block[{$extension = None}, Table[sub[g, depth - 1], {g, gens}]];   (* a radical g comes back as is *)
  If[MemberQ[rads, $Failed], Return[$Failed]];
  sel = solveAndSelect[fac, 0, a] /. Thread[gens -> rads];
  If[RadicalExpressionQ[sel], sel, $Failed]], moduleTag];

(* 1. functional decomposition p = g1(g2(...gk(x))), peeled from the outside: v_i = (g_{i+1} o ... o g_k)(a)
   is a root of g_i(x) - v_{i-1} *)
structuralDecompose[a_, p_, depth_] := Catch[Module[{comp = kDecompose[p, x], k, vals, rad},
  k = Length[comp];
  If[k < 2, Return[$Failed]];
  vals = Reverse[FoldList[kRootReduce[#2 /. x -> #1] &, a, Reverse[Rest[comp]]]];
  rad = sub[vals[[1]], depth - 1];
  Do[
    If[rad === $Failed, Throw[$Failed, moduleTag]];
    rad = solveAndSelect[comp[[i]], rad, vals[[i]]],
    {i, 2, k}];
  rad], moduleTag];

(* 2. generalized reciprocal symmetry: p(x) = x^m P(x + c/x), degree 2m; c^m is the constant term *)
rationalMthRoots[q_, m_] := With[{r = Abs[Numerator[q]]^(1/m), s = Denominator[q]^(1/m)},
  If[IntegerQ[r] && IntegerQ[s], Select[{r/s, -r/s}, #^m == q &], {}]];

reciprocalDecomposition[p_] := Catch[Module[{n = Exponent[p, x], m, q, rem, P},
  If[OddQ[n] || n < 4, Return[$Failed]];
  m = n/2; q = monic[p];
  Do[
    rem = q; P = 0;
    Do[With[{cf = Coefficient[rem, x, m + k]}, P += cf x^k; rem = kExpand[rem - cf x^m (x + c/x)^k]], {k, m, 0, -1}];
    If[rem === 0, Throw[{c, P}, moduleTag]],
    {c, rationalMthRoots[Coefficient[q, x, 0], m]}];
  $Failed], moduleTag];

structuralReciprocal[a_, p_, depth_] := Module[{rd = reciprocalDecomposition[p], c, yrad},
  If[rd === $Failed, Return[$Failed]];
  c = rd[[1]];
  yrad = sub[kRootReduce[a + c/a], depth - 1];        (* a + c/a is a root of P *)
  If[yrad === $Failed, $Failed, solveAndSelect[x^2 + c, yrad x, a]]];   (* a solves x^2 - y x + c = 0 *)

(* 3. Dickson polynomials: the centered polynomial is D_n(x, c) - b, and the roots are zeta^j u + c/(zeta^j u)
   with u^n a root of s^2 - b s + c^n *)
dickson[0, _] = 2; dickson[1, _] = x;
dickson[n_, c_] := dickson[n, c] = kExpand[x dickson[n - 1, c] - c dickson[n - 2, c]];

structuralDickson[a_, p_, depth_] := Module[{n = Exponent[p, x], q = monic[p], t, c, b, diff, u},
  If[n < 3, Return[$Failed]];
  t = -Coefficient[q, x, n - 1]/n;
  q = kExpand[q /. x -> x + t];
  c = -Coefficient[q, x, n - 2]/n;
  diff = kExpand[q - dickson[n, c]];
  If[c == 0 || Exponent[diff, x] > 0, Return[$Failed]];
  b = -diff;
  u = ((b + Sqrt[b^2 - 4 c^n])/2)^(1/n);
  selectCandidate[t + # + c/# & /@ rootOrbit[u, n], a]];

(* 4. pair-sum resolvent: Res_x(p(x), p(y-x)) = 2^n p(y/2) R2(y)^2 where the roots of R2 are a_i + a_j (i<j).
   A root y0 of a low-degree factor of R2 generates a field over which p may have a factor of
   degree <= 4 containing a. *)
pairSumPolynomial[p_] := Catch[Module[{fl, r2 = 1},
  fl = kFactorList[Cancel[kResultant[p, p /. x -> y - x, x]/(2^Exponent[p, x] (p /. x -> y/2))]];
  Do[If[Exponent[f[[1]], y] > 0, If[OddQ[f[[2]]], Throw[$Failed, moduleTag]]; r2 *= f[[1]]^(f[[2]]/2)], {f, fl}];
  r2 /. y -> x], moduleTag];

structuralPairSum[a_, p_, depth_] := Catch[Module[{n = Exponent[p, x], r2, facs, na, nroots, y0, fac, yrad, sel},
  If[n < 4 || n > 12, Return[$Failed]];
  r2 = pairSumPolynomial[p];
  If[r2 === $Failed, Return[$Failed]];
  facs = SortBy[Select[First /@ kFactorList[r2], 2 <= Exponent[#, x] <= Min[6, n - 1] &], Exponent[#, x] &];
  na = kN[a, 40]; nroots = rootValuesAt[p, 40];
  Do[
    y0 = rootObject[g, j];
    If[Min[Abs[kN[y0, 40] - na - nroots]] > 10^-15, Continue[]];   (* y0 = a + a' for a conjugate a' *)
    fac = factorAt[p, a, y0];
    If[fac === $Failed || Exponent[fac, x] > 4, Continue[]];
    yrad = sub[y0, depth - 1];
    If[yrad === $Failed, Continue[]];
    sel = solveAndSelect[kExpand[fac /. y0 -> yrad], 0, a];
    If[sel =!= $Failed, Throw[sel, moduleTag]],
    {g, facs}, {j, Exponent[g, x]}];
  $Failed], moduleTag];

structuralMethods = {
  {"Extension", structuralExtension},
  {"ToRadicals", Function[{a, p, depth}, With[{r = Quiet[TimeConstrained[kToRadicals[a], 5, $Failed]]},
      If[RadicalExpressionQ[r], r, $Failed]]]},
  {"Decompose", structuralDecompose},
  {"Reciprocal", structuralReciprocal},
  {"Dickson", structuralDickson},
  {"PairSum", structuralPairSum}};

(* the structural driver: a radical expression equal to a, or $Failed *)
(* The recognizer is bound to a symbol before it is applied.  Applying a
   function through a Part expression -- m[[2]][a, p, depth] -- makes a Return
   inside that function return from *this* Do in Mathics 10.0.1 instead of
   from the function, so the first recognizer that declined ended the search
   silently and no structural form was ever found. *)
structural[a_, p_, depth_] := Catch[Module[{r},
  If[depth <= 0, Return[$Failed]];
  Do[
    With[{recognizer = m[[2]]}, r = recognizer[a, p, depth]];
    If[okQ[r] && RadicalExpressionQ[r], $methodUsed = m[[1]]; Throw[r, moduleTag]],
    {m, structuralMethods}];
  $Failed], moduleTag];

(* ------------------------------------------------------------------ *)
(* Group theory on the multiplication table                            *)
(* ------------------------------------------------------------------ *)

(* Reversing a pair inverts its commutator, so unordered pairs generate the same subgroup. *)
commutatorSubgroup[mt_, idElem_, H_] := Module[{inv = Association @@ Table[g -> kFirstIndex[mt[[g]], idElem], {g, H}]},
  groupClosure[mt, idElem, DeleteDuplicates[
    Function[{g, h}, mt[[mt[[inv[g], inv[h]]], mt[[g, h]]]]] @@@ Subsets[H, {2}]]]];

solvableQ[mt_, idElem_, H_] := Catch[Module[{cur = Sort[H], nxt},
  While[Length[cur] > 1,
    nxt = commutatorSubgroup[mt, idElem, cur];
    If[nxt === cur, Throw[False, moduleTag]];
    cur = nxt];
  True], moduleTag];

(* composition series with prime quotients, from H down to 1: at each step a normal subgroup of prime
   index containing the commutator subgroup (obtained by enlarging the latter while staying proper) *)
primeSeries[mt_, idElem_, H0_] := Catch[Module[{H = Sort[H0], steps = {}, normal, p},
  While[Length[H] > 1,
    normal = commutatorSubgroup[mt, idElem, H];
    If[normal === H, Throw[$Failed, moduleTag]];
    Do[If[! MemberQ[normal, g],
        With[{J = groupClosure[mt, idElem, Append[normal, g]]}, If[Length[J] < Length[H], normal = J]]], {g, H}];
    p = Length[H]/Length[normal];
    If[! PrimeQ[p], Throw[$Failed, moduleTag]];
    AppendTo[steps, <|"Group" -> H, "Normal" -> normal, "Generator" -> First[Complement[H, normal]], "Prime" -> p|>];
    H = normal];
  steps], moduleTag];

fixedByQ[gd_, v_, elems_] := AllTrue[elems, gd["Automorphisms"][[#]] . v == v &];

(* ------------------------------------------------------------------ *)
(* General Galois-Kummer descent                                       *)
(* ------------------------------------------------------------------ *)

(* the descent proper, for Galois data gd of p(x) Prod Phi_q(x); may throw "precision" *)
descend[gd_, a_, primes_, resolventForm_] := Module[
  {ord = gd["Order"], c = gd["Scale"], tv = targetOf[gd, a], va, zetaIdx, zetaMult, zeta, H, steps, baseBasis, rad, radCompute, branch},
  If[kFailureQ[tv], Return[tv]];
  va = Last[tv];
  (* roots of unity zeta_q = Exp[2 Pi I/q] among the (scaled) roots, as multiplication matrices and as
     radical symbols; zeta_2 = -1 is handled by the same multiplication table *)
  zetaIdx = Association @@ Table[q -> kFirstIndex[gd["Roots"], _?(kExactZeroQ[# - c Exp[2 Pi I/q]] &)], {q, primes}];
  zetaMult = Association @@ Table[q -> multiplicationMatrixOfElement[gd, gd["RootCoordinates"][[zetaIdx[q]]]/c], {q, primes}];
  kAssociateTo[zetaMult, 2 -> -IdentityMatrix[ord]];   (* assignment into an association is refused in Mathics *)
  zeta = Association @@ Table[q -> (-1)^(2/q), {q, primes}];
  H = Select[Range[ord], Function[s, AllTrue[Values[zetaIdx], gd["Permutations"][[s, #]] == # &]]];
  steps = primeSeries[gd["MultiplicationTable"], gd["Identity"], H];
  If[steps === $Failed, Return[failure["NotSolvable", "Could not build a prime composition series"]]];
  (* basis of Q(zeta_m): monomials prod zeta_q^e_q, 0 <= e_q <= q-2, as symbols and as coordinate vectors *)
  baseBasis = Table[{Times @@ MapThread[zeta[#1]^#2 &, {primes, e}],
      Fold[Function[{vec, qe}, Nest[zetaMult[qe[[1]]] . # &, vec, qe[[2]]]], UnitVector[ord, 1], MapThread[List, {primes, e}]]},
    {e, Tuples[Range[0, # - 2] & /@ primes]}];
  rad[v_, level_] := rad[v, level] = radCompute[v, level];
  (* level 0: the element lies in Q(zeta_m) *)
  radCompute[v_, 0] := With[{sol = kLinearSolve[kTranspose[baseBasis[[All, 2]]], v]},
    If[sol === $Failed, Throw[failure["Descent", "Element not in the base cyclotomic field"], radTag]];
    kExpand[sol . baseBasis[[All, 1]]]];
  (* branch[Rk, q, level]: the q-th root of Rk^q (one level down) with the branch equal to Rk *)
  branch[Rk_, q_, level_] := branch[Rk, q, level] = Module[{qrad, sel},
    qrad = rad[powerCoordinates[gd, Rk, q], level - 1];
    sel = selectCandidate[rootOrbit[qrad^(1/q), q], gd["Values"][[gd["Identity"]]] . Rk];
    If[sel === $Failed, Throw[failure["Branch", "Could not identify the radical branch"], radTag]];
    sel];
  (* one prime step: v is fixed by steps[[level]]["Normal"]; extract q-th roots of the Lagrange resolvents
     R_k = Sum_j zeta^(-kj) sigma^j(v) (Fourier form), or of R_k1 alone with R_k = c_k R_k1^m, c_k one
     level down (eigenvector form) *)
  radCompute[v_, level_] := Catch[Module[{st = steps[[level]], generators, q, zw, R, nonzero, R0rad, k1, u, divide, ck, choices = {}},
    If[v == 0 v, Throw[0, moduleTag]];
    generators = #["Generator"] & /@ steps[[level ;;]]; q = st["Prime"];
    If[fixedByQ[gd, v, generators], Throw[rad[v, level - 1], moduleTag]];
    (* zw[[j+1, e+1]] = zeta^e sigma^j(v), as vectors: q^2 matrix-vector products instead of matrix powers *)
    zw = NestList[zetaMult[q] . # &, #, q - 1] & /@ NestList[gd["Automorphisms"][[st["Generator"]]] . # &, v, q - 1];
    R = Table[Sum[zw[[j + 1, Mod[-k j, q] + 1]], {j, 0, q - 1}], {k, 0, q - 1}];
    nonzero = Select[Range[1, q - 1], R[[# + 1]] != 0 R[[# + 1]] &];
    R0rad = rad[R[[1]], level - 1];
    If[resolventForm =!= "Eigenvector" || q == 2,
      AppendTo[choices, (R0rad + Sum[branch[R[[k + 1]], q, level], {k, nonzero}])/q]];
    If[resolventForm =!= "Fourier" && q > 2,
      k1 = First[nonzero];
      u = branch[R[[k1 + 1]], q, level];
      divide = powerDivider[gd, R[[k1 + 1]]];
      AppendTo[choices, (R0rad + u + Sum[
        With[{m = Mod[k PowerMod[k1, -1, q], q]},
          ck = divide[R[[k + 1]], m];
          If[! fixedByQ[gd, ck, generators], Throw[failure["Descent", "Eigenvector ratio is not in the lower field"], radTag]];
          rad[ck, level - 1] u^m],
        {k, DeleteCases[nonzero, k1]}])/q]];
    First[SortBy[choices, LeafCount]]], moduleTag];
  <|"Expression" -> Catch[rad[va, Length[steps]], radTag], "ExtendedGroupOrder" -> ord, "SeriesPrimes" -> (#["Prime"] & /@ steps)|>];

galoisRadicals[a_, p_] := Catch[Module[{maxOrder, prec, form, gd0, order, primes, poly, gd, res},
  {maxOrder, prec, form} = OptionValue[RootToRadicals, $opts, {"MaxGroupOrder", "WorkingPrecision", "Resolvents"}];
  gd0 = galoisDataChecked[p, maxOrder, prec];
  If[kFailureQ[gd0], Return[gd0]];
  order = gd0["Order"];
  $galoisInfo = <|"GaloisGroupOrder" -> order|>;
  If[! groupSolvableQ[gd0],
    Message[RootToRadicals::notsolv, "order " <> ToString[order]];
    Return[failure["NotSolvable", "The Galois group is not solvable", <|"GaloisGroupOrder" -> order|>]]];
  primes = Select[First /@ FactorInteger[order], OddQ];
  (* adjoin the roots of unity; a cyclotomic factor equal to p itself is already present *)
  poly = kExpand[p Times @@ Select[kCyclotomic[#, x] & /@ primes, kPolynomialGCD[#, p] === 1 &]];
  Do[
    gd = galoisData[poly, maxOrder Times @@ (primes - 1), prec];
    If[kFailureQ[gd], Throw[gd, moduleTag]];
    res = Catch[descend[gd, a, primes, form], precTag];
    If[res =!= "precision", Break[]];
    prec *= 2,
    {3}];
  If[res === "precision", Return[failure["Precision", "Precision escalation failed in the descent"]]];
  If[kFailureQ[res], Return[res]];
  If[kFailureQ[res["Expression"]], Return[res["Expression"]]];
  $galoisInfo = Join[$galoisInfo, <|"ExtendedGroupOrder" -> res["ExtendedGroupOrder"], "SeriesPrimes" -> res["SeriesPrimes"], "Primes" -> primes|>];
  res["Expression"]], moduleTag];

(* ------------------------------------------------------------------ *)
(* Driver                                                              *)
(* ------------------------------------------------------------------ *)

Options[RootToRadicals] = {
  Method -> Automatic,            (* Automatic, "Structural", "Galois" *)
  "Resolvents" -> Automatic,      (* Automatic (shorter of the two), "Fourier", "Eigenvector" *)
  "MaxGroupOrder" -> 400,
  "WorkingPrecision" -> 80,
  "VerificationTimeLimit" -> 60,
  "MaxDepth" -> 6,
  "Extension" -> None             (* exact algebraic numbers generating a subfield over which p is factored first *)
};
Options[RootRadicalReport] = Options[RootToRadicals];

(* recursive core: a radical expression, or a Failure *)
radicalsOf[a_, depth_] := Module[{in, p, n, r},
  If[RadicalExpressionQ[a], Return[a]];
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  p = in["Polynomial"]; n = in["Degree"];
  If[n == 1, Return[in["Value"]]];
  If[$method =!= "Galois", r = structural[a, p, depth]; If[okQ[r], Return[r]]];
  If[$method === "Structural", Return[failure["NotFound", "No structural radical form was found"]]];
  If[frobeniusNonsolvableQ[p],
    Message[RootToRadicals::notsolv, frobeniusReason[n]];
    $galoisInfo = <|"Method" -> "Frobenius"|>;
    Return[failure["NotSolvable", "The Galois group is not solvable (Frobenius cycle types)"]]];
  r = galoisRadicals[a, p];
  If[okQ[r], $methodUsed = "Galois"];
  r];

validOptionsQ[opts_] := With[{o = OptionValue[RootToRadicals, opts, #] &},
  MemberQ[{Automatic, "Structural", "Galois"}, o[Method]] &&
  MemberQ[{Automatic, "Fourier", "Eigenvector"}, o["Resolvents"]] &&
  positiveIntegerQ[o["MaxGroupOrder"]] && positiveIntegerQ[o["MaxDepth"]] &&
  IntegerQ[o["WorkingPrecision"]] && o["WorkingPrecision"] >= 30 &&
  (o["Extension"] === None || AllTrue[Flatten[{o["Extension"]}], FreeQ[#, _Real] && minimalPolynomialOf[#] =!= $Failed &])];

(* the expanded form when it is smaller: the Galois descent can return
   (5 2^(1/5) + 5 2^(2/5))/5 for 2^(1/5) + 2^(2/5); a nested radical that
   Expand would only enlarge is kept as it is *)
tidyRadicals[e_] := With[{t = kExpand[e]}, If[LeafCount[t] < LeafCount[e], t, e]];

RootRadicalReport[a_, opts : OptionsPattern[]] := Catch[Module[{t0 = AbsoluteTime[], o = Flatten[{opts}], in, r, ver},
  If[! validOptionsQ[o], Message[RootToRadicals::opts, o]; Return[failure["InvalidOptions", "Invalid options"]]];
  If[! FreeQ[a, _Real], Message[RootToRadicals::inexact, a]; Return[failure["Inexact", "Inexact input"]]];
  in = inputData[a];
  If[kFailureQ[in], Return[in]];
  Block[{$method = OptionValue[Method], $opts = o, $methodUsed = None, $galoisInfo = <||>,
         $prec = Max[60, OptionValue["WorkingPrecision"]], $extension = OptionValue["Extension"]},
    r = radicalsOf[a, OptionValue["MaxDepth"]];
    If[kFailureQ[r], Throw[Failure[r[[1]], Join[r[[2]], $galoisInfo, <|"Degree" -> in["Degree"], "Time" -> AbsoluteTime[] - t0|>]], moduleTag]];
    r = tidyRadicals[r];
    ver = verifyExact[r, a, OptionValue["VerificationTimeLimit"]];
    If[ver =!= True, Message[RootToRadicals::verify, ver]];
    Join[<|"Expression" -> r, "Verified" -> ver, "Method" -> $methodUsed, "Degree" -> in["Degree"],
      "RadicalDepth" -> RadicalDepth[r], "LeafCount" -> LeafCount[r]|>, $galoisInfo, <|"Time" -> AbsoluteTime[] - t0|>]]], moduleTag];

RootToRadicals[a_, opts : OptionsPattern[]] := With[{r = RootRadicalReport[a, opts]},
  Which[kFailureQ[r], r,
    r["Verified"] === False, failure["VerificationFailed", "The candidate expression is not equal to the input"],
    True, r["Expression"]]];

RootSolvableQ[a_, opts : OptionsPattern[RootToRadicals]] := Module[{in = inputData[a], p, gd},
  If[kFailureQ[in], Return[in]];
  If[in["Degree"] <= 4, Return[True]];
  p = in["Polynomial"];
  If[frobeniusNonsolvableQ[p], Return[False]];
  gd = galoisDataChecked[p, OptionValue["MaxGroupOrder"], OptionValue["WorkingPrecision"]];
  If[kFailureQ[gd], gd, groupSolvableQ[gd]]];

(* ================================================================ *)

(* 4.  Denesting                                                    *)

(* ================================================================ *)

(* From radical-denest/DenestRadicals.wl (context RadicalDenest3`).
   DenestRadicals rewrites an exact algebraic expression with fewer nested root
   extractions.  Its contract is unchanged by the merge:

     * every replaced island is certified equal to the island it replaces by
       exact algebra, whatever produced the candidate; the optional numeric
       prefilter only prunes candidates inside the search and never decides an
       equality status;
     * an accepted replacement is strictly cheaper under RadicalCost, or the
       island is returned unchanged;
     * the whole call runs inside one time- and memory-bounded region, and
       every expensive kernel operation inside its own;
     * symbolic hosts are never simplified, ambient $Assumptions are ignored,
       and malformed or unknown options produce a Failure.

   There is no completeness or minimum-depth guarantee: an unchanged result
   means the enabled bounded methods found nothing cheaper.  The kernel limits
   are cooperative and are not an operating-system sandbox.  On a kernel
   without a memory limit the memory budget is not enforced; the time budget
   still is, and AlgebraicKernelReport[] says so. *)

Options[DenestRadicals] = {"AllLevels" -> False, "Verbose" -> False, "Trace" -> False,
   "Multipliers" -> Automatic, "Solver" -> Automatic, "Factor" -> True,
   "MaxTrials" -> 120, "TimeBudget" -> 120, "OperationTime" -> 30,
   "CertifyTime" -> 20, "MemoryBudget" -> 1073741824,
   "MultiplierCap" -> 1000, "MaxRootIndex" -> 32, "MaxDegree" -> 64,
   "MaxSolveDegree" -> 4, "MaxLeafCount" -> 20000, "MaxPasses" -> 4,
   "MaxRecursion" -> 3, "Patience" -> 25, "NumericPrefilter" -> False, "MaxTraceEntries" -> 200,
   "MaxOddIndex" -> 9, "DiscriminantBatchCap" -> 24, "MaxCosets" -> 16};
Options[DenestCore] = Options[DenestRadicals];
Options[DenestReport] = Options[DenestRadicals];

(* ------------------------------------------------------------------ *)
(* session state (dynamically scoped by run[]), statistics, tracing   *)
(* ------------------------------------------------------------------ *)

$active = False;
$cfg = kDefaultConfig[DenestRadicals];
$deadline = Infinity;
$stats = <||>; $limits = <||>; $trace = {}; $records = {}; $memo = <||>; $inProgress = <||>;
$recursion = 0; $lastCertificateMethod = "None";
$x = Unique["Algebraic`Private`dx"];

newStats[] := <|"Islands" -> 0, "Trials" -> 0, "Operations" -> 0,
   "OperationTimeouts" -> 0, "OperationFailures" -> 0,
   "Certificates" -> 0, "CertificatesEqual" -> 0, "CertificatesDifferent" -> 0,
   "CertificatesUnknown" -> 0, "NumericRejections" -> 0, "CosetSystems" -> 0,
   "CandidatesAccepted" -> 0, "MultipliersProposed" -> 0,
   "MultipliersAdmitted" -> 0, "DuplicateMultipliers" -> 0,
   "FastPathAccepted" -> 0, "PassesCompleted" -> 0|>;

bump[key_String] := kAssociateTo[$stats, key -> (kLookup[$stats, key, 0] + 1)];
limitHit[key_String] := kAssociateTo[$limits, key -> True];
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
bounded[body_, kind_: "Operation"] := Module[
   {timeKey = If[kind === "Certificate", "CertifyTime", "OperationTime"], seconds, value},
   seconds = Min[remaining[], $cfg[timeKey]];
   If[seconds <= 0, limitHit[If[remaining[] <= 0, "TimeBudget", timeKey]]; Return[$Failed]];
   bump["Operations"];
   value = kCheckMessages[TimeConstrained[body, seconds, operationTimedOut], operationFailed];
   Which[
    value === operationTimedOut,
     bump["OperationTimeouts"]; trace["OperationTimeout"]; limitHit[timeKey];
     If[remaining[] <= 0, limitHit["TimeBudget"]]; $Failed,
    value === operationFailed || value === $Failed || value === $Aborted,
     bump["OperationFailures"]; $Failed,
    True, value]];
(* a bounded operation whose result must be a list; default otherwise *)
SetAttributes[boundedList, HoldFirst];
boundedList[body_, default_: {}] := With[{v = bounded[body]}, If[ListQ[v], v, default]];
(* certificates, one bounded operation each: an exact zero and an exact sign *)
certifiedZeroQ[d_] := TrueQ[bounded[kRootReduce[d], "Certificate"] === 0];
certifiedPositiveQ[e_] := TrueQ[bounded[e > 0, "Certificate"]];
certifiedNegativeQ[e_] := TrueQ[bounded[e < 0, "Certificate"]];

(* ------------------------------------------------------------------ *)
(* option resolution and validation                                   *)
(* ------------------------------------------------------------------ *)

finiteNonnegativeQ[v_] := MatchQ[v, _Integer | _Rational | _Real] && TrueQ[0 <= v < Infinity];
nonnegativeIntegerQ[v_] := IntegerQ[v] && v >= 0;
booleanQ[v_] := v === True || v === False;


resolveOptions[head_Symbol, raw_List] := Module[{rules, names, unknown, cfg, bad},
   rules = Flatten[raw];
   If[! AllTrue[rules, MatchQ[#, _Rule | _RuleDelayed] &],
    Return[failure["InvalidOption", "Options must be rules.", <|"Rules" -> rules|>]]];
   names = kOptionNames[head];
   unknown = unknownOptions[head, rules];
   If[unknown =!= {},
    Return[failure["UnknownOption", "Unknown option(s): `Keys`.", <|"Keys" -> unknown|>]]];
   (* effective defaults of the head actually called, first explicit rule wins *)
   (* Association applied to anything but a literal list of rules retains the
      unevaluated expression in Mathics 10.0.1, so the rules are built first
      and applied. *)
   cfg = Association @@ Table[key -> OptionValue[head, rules, key], {key, names}];
   bad = Join[
     Select[{"AllLevels", "Verbose", "Trace", "Factor", "NumericPrefilter"}, ! booleanQ[cfg[#]] &],
     Select[{"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience", "DiscriminantBatchCap", "MaxCosets"}, ! nonnegativeIntegerQ[cfg[#]] &],
     Select[{"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount", "MaxPasses", "MaxOddIndex"}, ! positiveIntegerQ[cfg[#]] &],
     Select[{"TimeBudget", "OperationTime", "CertifyTime"}, ! finiteNonnegativeQ[cfg[#]] &]];
   If[! (cfg["Multipliers"] === Automatic || ListQ[cfg["Multipliers"]]), AppendTo[bad, "Multipliers"]];
   If[! (cfg["Solver"] === Automatic || MatchQ[cfg["Solver"], _Function | _Symbol]), AppendTo[bad, "Solver"]];
   If[cfg["MaxSolveDegree"] > 4, AppendTo[bad, "MaxSolveDegree"]];
   If[bad =!= {},
    Return[failure["InvalidOption", "Invalid value(s) for `Keys`; limits must be finite and of the documented type.", <|"Keys" -> bad|>]]];
   cfg];

(* ------------------------------------------------------------------ *)
(* grammar, depth, cost                                               *)
(* ------------------------------------------------------------------ *)

opaqueQ[e_] := MatchQ[e, _Root | _AlgebraicNumber];

RadicalExpressionQ[e_] := algebraicGrammarQ[e, kGaussianQ];

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
     p = kCheck[kExpand[fs[$x]], $Failed];
     If[p === $Failed || ! TrueQ[kPolynomialQ[p, $x]], Return[$Failed]];
     degree = Exponent[p, $x];
     If[! positiveIntegerQ[degree] || ks > degree, Return[$Failed]];
     If[! AllTrue[kCoefficientList[p, $x], RadicalExpressionQ], Return[$Failed]];
     p,
    (* the kernel writes a root of a polynomial with algebraic coefficients as a
       triangular system Root[{f1, f2, ...}, {k1, k2, ...}]; every polynomial of
       the system must have coefficients in the radical grammar *)
    ListQ[fs] && ListQ[ks] && Length[fs] === Length[ks] && fs =!= {} && AllTrue[fs, Head[#] === Function &] && AllTrue[ks, positiveIntegerQ],
     vars = Table[Unique["Algebraic`Private`rv"], {Length[fs]}];
     ps = kCheck[kExpand[#[Sequence @@ vars]] & /@ fs, $Failed];
     If[ps === $Failed || ! AllTrue[ps, TrueQ[kPolynomialQ[#, vars]] && ! FreeQ[#, Alternatives @@ vars] &], Return[$Failed]];
     If[! AllTrue[ps, AllTrue[Values[kCoefficientRules[#, vars]], RadicalExpressionQ] &], Return[$Failed]];
     Last[ps],
    True, $Failed]];

algebraicFormQ[e_] := Which[
   kGaussianQ[e], True,
   Head[e] === Root, rootPolynomial[e] =!= $Failed,
   Head[e] === AlgebraicNumber, Length[e] === 2 && ListQ[e[[2]]] && AllTrue[e[[2]], kGaussianQ] && algebraicFormQ[e[[1]]],
   AtomQ[e], False,
   MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, algebraicFormQ],
   Head[e] === Power && Length[e] === 2, kRationalQ[e[[2]]] && algebraicFormQ[e[[1]]],
   True, False];

(* exactness is decided by the grammar (algebraic by construction) *)
ExactAlgebraicQ[e_] := algebraicFormQ[e] && FreeQ[e, Indeterminate | ComplexInfinity | _DirectedInfinity];
exactQ[e_] := ExactAlgebraicQ[e];

(* The two source packages disagreed on heads outside the grammar: the
   denester took the maximum over the parts of any head, the radical descent
   gave 0 (Sin[Sqrt[2]], HoldForm[Sqrt[2]] and {Sqrt[2]} are not radical
   expressions, so nothing in them is a nested radical).  The latter is kept;
   inside the grammar the two agreed, and a non-integer exponent counts as
   one level whether or not it is rational. *)
RadicalDepth[e_] := Which[
   AtomQ[e] || opaqueQ[e], 0,
   Head[e] === Power && Length[e] === 2, RadicalDepth[First[e]] + If[IntegerQ[Last[e]], 0, 1],
   MemberQ[{Plus, Times}, Head[e]], Max[Prepend[RadicalDepth /@ (List @@ e), 0]],
   True, 0];

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
smallQ[e_] := If[LeafCount[e] > $cfg["MaxLeafCount"], limitHit["MaxLeafCount"]; False, True];

(* ------------------------------------------------------------------ *)
(* exact certification                                                *)
(* ------------------------------------------------------------------ *)

(* RootReduce is a canonicalizer: a reduced difference that is a nonzero exact
   algebraic number (an integer, rational, Gaussian rational, Root object or
   explicit radical form such as 2 Sqrt[2]) proves inequality *)
canonicalNonzeroQ[e_] := e =!= 0 && exactQ[e] && FreeQ[e, RootReduce | kRootReduce];

(* heuristic pruning by significance arithmetic, used only by the search gate;
   it can lose a candidate, never accept one, and never decides EqualityStatus *)
numericallyDifferentQ[d_] := Module[{num},
   If[! TrueQ[$cfg["NumericPrefilter"]], Return[False]];
   num = bounded[kN[d, 40]];
   TrueQ[NumberQ[num] && Accuracy[num] >= 25 && Abs[num] > 10^-20]];

certify[a_, b_] := Module[{d, r},
   bump["Certificates"]; $lastCertificateMethod = "None";
   If[! exactQ[a] || ! exactQ[b], bump["CertificatesUnknown"]; Return["Unknown"]];
   If[a === b, $lastCertificateMethod = "SameQ"; bump["CertificatesEqual"]; Return["Equal"]];
   d = a - b;
   r = bounded[kRootReduce[d], "Certificate"];
   Which[
    r === 0, $lastCertificateMethod = "RootReduce"; bump["CertificatesEqual"]; Return["Equal"],
    canonicalNonzeroQ[r], $lastCertificateMethod = "RootReduce"; bump["CertificatesDifferent"]; Return["Different"]];
   r = bounded[kPossibleZeroQ[d], "Certificate"];
   Which[
    r === True, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics"; bump["CertificatesEqual"]; "Equal",
    r === False, $lastCertificateMethod = "PossibleZeroQ/ExactAlgebraics"; bump["CertificatesDifferent"]; "Different",
    True, bump["CertificatesUnknown"]; "Unknown"]];

SetAttributes[standalone, HoldAll];
(* one denesting session: the shared state every stage reads, for a body
   evaluated with the given configuration and time budget in seconds *)
SetAttributes[session, HoldRest];
session[cfg_, seconds_, body_] :=
  Block[{$active = True, $cfg = cfg, $deadline = AbsoluteTime[] + seconds,
    $stats = newStats[], $limits = <||>, $trace = {}, $records = {}, $memo = <||>, $inProgress = <||>,
    $recursion = 0, $lastCertificateMethod = "None", $Assumptions = True}, body];
standalone[body_, failure_] := If[TrueQ[$active], body,
   session[kDefaultConfig[DenestRadicals], 20,
    kCheck[TimeConstrained[kMemoryConstrained[body, 1073741824], 20 $kTimeScale, failure], failure]]];

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
   v = bounded[kSimplify[candidate]];
   best = accept[v, target, best, method <> "/Simplify"];
   v = bounded[kExpand[candidate]];
   best = accept[v, target, best, method <> "/Expand"];
   v = bounded[Together[candidate]];
   best = accept[v, target, best, method <> "/Together"];
   v = rationalizeRaw[candidate];
   best = accept[v, target, best, method <> "/Rationalize"];
   best];

(* ------------------------------------------------------------------ *)
(* certified denominator inverse                                      *)
(* ------------------------------------------------------------------ *)

validPolynomialQ[p_, x_] := Module[{degree},
   If[! FreeQ[p, $Failed | $Aborted | operationFailed | operationTimedOut] || ! TrueQ[kPolynomialQ[p, x]], Return[False]];
   degree = Exponent[p, x];
   IntegerQ[degree] && 1 <= degree <= $cfg["MaxDegree"]];

rationalizeRaw[e_] := Module[{t, num, den, p, c, inv, result},
   t = bounded[Together[e]];
   If[t === $Failed, Return[$Failed]];
   num = Numerator[t]; den = Denominator[t];
   If[kRationalQ[den], Return[t]];
   If[! exactQ[den] || ! smallQ[den], Return[$Failed]];
   p = bounded[kMinimalPolynomial[den, $x]];
   If[! validPolynomialQ[p, $x], Return[$Failed]];
   c = kCoefficientList[p, $x];
   If[! AllTrue[c, kRationalQ] || First[c] === 0, Return[$Failed]];
   (* p(d) = 0 gives 1/d = -(a1 + a2 d + ... + an d^(n-1))/a0 (Horner form) *)
   inv = bounded[-Fold[#1 den + #2 &, Last[c], Reverse[Rest[Most[c]]]]/First[c]];
   If[inv === $Failed || certify[den inv, 1] =!= "Equal", Return[$Failed]];
   result = bounded[kExpand[num inv]];
   If[result === $Failed || ! smallQ[result], $Failed, result]];

RationalizeDenominator[e_] := standalone[Replace[rationalizeRaw[e], $Failed -> e], e];

Factorc[e_] := standalone[If[exactQ[e], accept[bounded[kFactor[e]], e, e, "Factor"], e], e];

(* ------------------------------------------------------------------ *)
(* exact low-degree fast paths                                        *)
(* ------------------------------------------------------------------ *)

(* a + b Sqrt[c] with rational a, b, c > 0 nonsquare, after expansion *)
quadraticParts[rho_] := Module[{e, terms, rat, irr, a, t, c, b},
   e = bounded[kExpand[rho]];
   If[e === $Failed, Return[$Failed]];
   terms = If[Head[e] === Plus, List @@ e, {e}];
   rat = Select[terms, kRationalQ]; irr = Select[terms, ! kRationalQ[#] &];
   If[Length[irr] =!= 1, Return[$Failed]];
   a = Total[rat]; t = First[irr];
   c = Replace[t, {Sqrt[cc_?kRationalQ] :> cc, Times[k_?kRationalQ, Sqrt[cc_?kRationalQ]] :> k^2 cc, _ -> $Failed}];
   If[c === $Failed || ! TrueQ[c > 0] || kRationalQ[Sqrt[c]], Return[$Failed]];
   b = Replace[t, {Sqrt[_] :> 1, Times[k_?kRationalQ, Sqrt[_]] :> Sign[k], _ -> 1}];
   (* represent as a + b Sqrt[c] with b = +-1 and c absorbing the coefficient *)
   {a, b, c}];

(* direct and indirect denesting of Sqrt[a + b Sqrt[c]] > 0 *)
quadraticSquareRoots[{a_, b_, c_}] := Module[{d, s, u, v, e, out = {}},
   d = a^2 - b^2 c;
   If[d >= 0,
    s = Sqrt[d];
    If[kRationalQ[s] && a > 0,
     u = (a + s)/2; v = (a - s)/2;
     If[u >= 0 && v >= 0, AppendTo[out, Sqrt[u] + Sign[b] Sqrt[v]]]]];
   (* indirect criterion: -c d must be a rational square *)
   If[d < 0 && b > 0,
    e = Sqrt[b^2 - a^2/c];
    If[kRationalQ[e] && 0 <= e <= b,
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
   If[! kRationalQ[n], Return[{}]];
   Do[dn = kExpand[$x d1 - n d0]; sn = kExpand[$x s1 - n s0];
    {d0, d1} = {d1, dn}; {s0, s1} = {s1, sn}, {q - 1}];
   roots = rationalRoots[d1 - 2 a];
   Do[den = s1 /. $x -> t;
    If[den =!= 0, beta = t/2 + b Sqrt[c]/den;
     If[certifiedZeroQ[beta^q - (a + b Sqrt[c])], AppendTo[out, beta]]],
    {t, roots}];
   out];

(* the roots of the linear factors of a factor list *)
linearRoot[f_] := -Coefficient[f, $x, 0]/Coefficient[f, $x, 1];
linearFactorRoots[fl_List] := Cases[fl, {f_, _Integer} /; kPolynomialQ[f, $x] && Exponent[f, $x] === 1 :> linearRoot[f]];
rationalRoots[p_] := DeleteDuplicates[Select[linearFactorRoots[boundedList[kFactorList[p]]], kRationalQ]];

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
   If[AllTrue[terms, kRationalQ], Return[{}]];
   {a, b} = Replace[bounded[kRootReduce[#^3], "Certificate"], $Failed -> Null] & /@ terms;
   If[! AllTrue[{a, b}, kRationalQ] || a === 0 || b === 0, Return[{}]];
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
(* the primes dividing any of the integers (signs and units ignored) *)
classPrimes[classes_List] :=
   boundedList[Union @@ (Select[First /@ FactorInteger[Abs[#]], PrimeQ] & /@ DeleteCases[classes, 0 | 1 | -1])];

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
    If[! kKeyExistsQ[seen, rep], kAssociateTo[seen, rep -> True]; AppendTo[cosets, rep]],
    {v, all}];
   cosets];

(* solve (Sum[x_u Sqrt[u]])^2 == rho, rho given as class -> coefficient *)
surdSystem[u_List, coeffs_Association] := Module[{vars, cand, sq, basis, eqs, sol},
   If[u === {} || Length[u] > 16, Return[{}]];
   bump["CosetSystems"];
   vars = Table[Unique["Algebraic`Private`coef"], {Length[u]}];
   cand = vars . Sqrt[u];
   sq = bounded[kExpand[cand^2]];
   If[sq === $Failed, Return[{}]];
   basis = Union[Keys[coeffs], DeleteDuplicates[Cases[sq, Power[n_Integer, Rational[1, 2]] :> n, {0, Infinity}]]];
   eqs = Prepend[Table[Coefficient[sq, Sqrt[bb]] == kLookup[coeffs, bb, 0], {bb, DeleteCases[basis, 1]}],
     (sq /. Power[_Integer, Rational[1, 2]] -> 0) == kLookup[coeffs, 1, 0]];
   sol = bounded[kSolveRationals[eqs, vars]];
   (* only fully rational solutions are candidates; Solve may return
      conditional or parametric solutions, which are not *)
   If[! ListQ[sol], Return[{}]];
   sol = Select[sol, ListQ[#] && AllTrue[#, MatchQ[#, _Rule] && kRationalQ[Last[#]] &] && Length[#] === Length[vars] &];
   DeleteDuplicates[(cand /. #) & /@ sol]];

(* integer-relation proposal for one unknown set: an integer vector
   (n0, n_u) with n0 Sqrt[rho] + Sum[n_u Sqrt[u]] = 0 gives the candidate
   -Sum[n_u Sqrt[u]]/n0; it is proposed only when its square reduces to rho,
   so a spurious relation costs one RootReduce and nothing else *)
surdRelation[u_List, rho_] := Module[{sign, vec, rel, cand},
   If[u === {} || Length[u] > 32, Return[{}]];
   (* Sign[] of a sum with negative terms can stay unevaluated; the comparisons decide numerically *)
   sign = Which[certifiedPositiveQ[rho], 1, certifiedNegativeQ[rho], -1, True, 0];
   If[sign === 0, Return[{}]];
   vec = bounded[kN[Prepend[Sqrt[u], Sqrt[sign rho]], 80 + 10 Length[u]]];
   If[! ListQ[vec] || ! AllTrue[vec, NumberQ], Return[{}]];
   rel = bounded[kFindIntegerNullVector[vec]];
   If[! ListQ[rel] || ! AllTrue[rel, IntegerQ] || First[rel] === 0, Return[{}]];
   cand = -(Rest[rel] . Sqrt[u])/First[rel];
   If[sign === -1, cand = I cand];
   If[certifiedZeroQ[cand^2 - rho], {cand, -cand}, {}]];

(* a summand c Sqrt[r] with rational c and r > 0 as {squarefree radicand, coefficient};
   the kernel writes Sqrt[6]/2 as Sqrt[3/2], which is Sqrt[6] with coefficient 1/2 *)
surdTerm[t_] := Which[
   kRationalQ[t], {1, t},
   MatchQ[t, Power[_Integer | _Rational, Rational[1, 2]]], surdTerm[{1, t}],
   MatchQ[t, Times[_?kRationalQ, Power[_Integer | _Rational, Rational[1, 2]]]], surdTerm[{t[[1]], t[[2]]}],
   MatchQ[t, {_?kRationalQ, Power[_Integer | _Rational, Rational[1, 2]]}],
    If[t[[2, 1]] <= 0, $Failed,
     {Numerator[t[[2, 1]]] Denominator[t[[2, 1]]], t[[1]]/Denominator[t[[2, 1]]]}],
   True, $Failed];

(* the first f[U] over the sets that is not empty, within the time budget *)
firstNonempty[f_, sets_List] := Module[{out = {}},
   Do[If[expiredQ[], Break[]]; out = f[U]; If[out =!= {}, Break[]], {U, sets}]; out];

multiSurdSquareRoots[rho_] := Module[{e, terms, parsed, surds, coeffs, primes, extra, cosets, out},
   e = bounded[kExpand[rho]];
   If[e === $Failed, Return[{}]];
   terms = If[Head[e] === Plus, List @@ e, {e}];
   parsed = surdTerm /@ terms;
   If[MemberQ[parsed, $Failed], Return[{}]];
   coeffs = kMerge[Rule @@@ parsed, Total];
   surds = Select[Keys[coeffs], # > 1 &];
   If[Length[surds] < 2 || Length[surds] > 15, Return[{}]];
   primes = classPrimes[surds];
   If[primes === {}, Return[{}]];
   (* the two cheap unknown sets first, then the cosets of the square-class
      group of the radicands over the primes of the radicands and of the
      coefficients; the first system with a rational solution wins *)
   extra = classPrimes[Flatten[{Numerator[#], Denominator[#]} & /@ Select[Values[coeffs], kRationalQ]]];
   cosets = cosetBases[surds, Union[primes, extra]];
   (* stage 1: certified integer-relation proposals, one per coset *)
   out = firstNonempty[surdRelation[#, e] &, cosets];
   If[out =!= {}, Return[out]];
   (* stage 2: the rational systems *)
   firstNonempty[surdSystem[#, coeffs] &, DeleteDuplicates[Join[{Union[{1}, primes], Union[{1}, primes, surds]}, cosets]]]];

(* Gaussian square root: Sqrt[a + b I] with a^2 + b^2 a rational square *)
gaussianSquareRoots[z_] := Module[{a = Re[z], b = Im[z], n},
   n = Sqrt[a^2 + b^2];
   If[kRationalQ[n], {Sqrt[(n + a)/2] + I Sign[b] Sqrt[(n - a)/2]}, {}]];

(* roots of unity as rational powers of -1 *)
unity[k_Integer, q_Integer] := (-1)^(Mod[2 k, 2 q]/q);

(* candidates for rho^(1/q), rho exact, produced by the shape-specific recipes *)
rootCandidates[rho_, q_Integer] := Module[{parts, out = {}, r = rho, neg},
   If[q === 2 && Head[rho] === Complex, Return[gaussianSquareRoots[rho]]];
   neg = certifiedNegativeQ[rho];
   If[neg, r = -rho];
   Which[
    q === 2,
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticSquareRoots[parts]];
     out = Join[out, honsbeekSquareRoots[r], multiSurdSquareRoots[r]],
    OddQ[q] && q >= 3 && q <= $cfg["MaxOddIndex"],
     parts = quadraticParts[r];
     If[parts =!= $Failed, out = quadraticOddRoots[parts, q]]];
   If[neg, out = (-1)^(1/q) out];      (* (-1)^(1/2) is I *)
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
   r = bounded[kToRadicals[z]];
   If[r =!= $Failed, AppendTo[out, r]];
   r = bounded[kRootReduce[z], "Certificate"];
   If[r =!= $Failed, r = bounded[kToRadicals[r]]; If[r =!= $Failed, AppendTo[out, r]]];
   DeleteDuplicates[Select[out, exactQ]]];

(* roots gamma of x^k == rho lying in the field generated by the radicals of rho *)
(* the exact radical forms of a list of roots, failures dropped *)
exactRadicalForms[roots_List] := DeleteDuplicates[Select[Flatten[radicalForms /@ DeleteCases[roots, $Failed]], exactQ]];
linearRoots[rho_, k_Integer] := Module[{fl},
   fl = boundedList[kFactorListExtension[$x^k - rho, radicalExtension[rho]], $Failed];
   If[fl === $Failed, fl = boundedList[kFactorListExtension[$x^k - rho, Automatic], $Failed]];
   If[fl === $Failed, Return[{}]];
   exactRadicalForms[bounded[Together[#]] & /@ linearFactorRoots[fl]]];

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
  Module[{best = If[incumbent === Automatic, target, incumbent], gammas, k, rest, sub, dens, reduced, offer},
   (* the orbit of z under the n-th roots of unity, raised to the power p *)
   offer[z_, n_Integer, method_String] :=
     Do[best = acceptWithPolish[bounded[kExpand[(z unity[l, n])^p]], target, best, method], {l, 0, n - 1}];
   Do[
    If[expiredQ[], Break[]];
    gammas = linearRoots[rho, k];
    rest = q/k;
    If[rest === 1,
     Do[offer[gamma, q, "LinearFactor"], {gamma, gammas}],
     (* rho = gamma^k, so target = (gamma zeta_k^j)^(p/rest) zeta_rest^l for some j, l;
        the distinct values gamma zeta_k^j are each processed once *)
     dens = DeleteDuplicates[DeleteCases[Flatten[Table[bounded[kExpand[gamma unity[j, k]]], {gamma, gammas}, {j, 0, k - 1}]], $Failed]];
     Do[
      If[expiredQ[], Break[]];
      reduced = den^(1/rest);
      offer[reduced, rest, "IndexReduction"];
      sub = recurse[reduced];
      If[sub =!= reduced && exactQ[sub], offer[sub, rest, "IndexReduction/Recursive"]],
      {den, dens}]];
    If[RadicalDepth[best] <= 1, Break[]],
    {k, Reverse[Rest[Divisors[q]]]}];
   best];

(* negative real radicand: rho^(p/q) = (-1)^(p/q) (-rho)^(p/q); the modulus is
   denested recursively and the phase-separated candidate is offered whether
   or not the recursion changed the modulus *)
negativeRadicandCandidate[target_, rho_, p_Integer, q_Integer, incumbent_] :=
  If[! certifiedNegativeQ[rho], incumbent,
   With[{sub = recurse[(-rho)^(p/q)]},
    acceptWithPolish[bounded[kExpand[(-1)^(p/q) sub]], target, incumbent, "NegativeRadicand"]]];

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
    cap = $cfg["MultiplierCap"], proposalCap, admit, offer, roomQ, batchRoomQ, seeds, terms, m, theta, p, degree, gcd, gd,
    roots, mroot, candidate, disc, primes, j, digits, batch, sol, trials = 0, sinceImprovement = 0, bestDegree = Infinity},
   If[cap === 0 || $cfg["MaxTrials"] === 0 || expiredQ[], Return[best]];
   q = reductionIndex[target]; If[q === $Failed, Return[best]];
   rho = bounded[kExpand[target^q]]; If[rho === $Failed || ! exactQ[rho], Return[best]];
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
     canonical = bounded[kExpand[value]];
     (* a structural test: Equal on an exact radical expression is decided
        numerically, and in Mathics that aborts the evaluator with a NaN
        comparison for a multiplier such as a cube root of 2^(1/3) - 1 *)
     If[canonical === $Failed || canonical === 0, Return[False]];
     key = ToString[canonical, InputForm];
     If[kKeyExistsQ[seen, key], bump["DuplicateMultipliers"]; Return[False]];
     kAssociateTo[seen, key -> True]; AppendTo[queue, value];
     admitted++; bump["MultipliersAdmitted"]; True];
   (* a candidate for the target; an improvement resets the patience counter *)
   offer[value_, method_String] := Module[{before = best},
     best = acceptWithPolish[value, target, best, method];
     If[best =!= before, sinceImprovement = 0]];
   (* room for another proposal, and within one discriminant batch *)
   roomQ[] := admitted < cap && proposed < proposalCap && ! expiredQ[];
   batchRoomQ[] := admitted < cap && proposed < proposalCap && batch < $cfg["DiscriminantBatchCap"] && ! expiredQ[];
   If[ListQ[$cfg["Multipliers"]],
    seeds = $cfg["Multipliers"],
    terms = DeleteCases[Replace[#, {Times[a___, _?kRationalQ, b___] :> a*b, _?kRationalQ -> 0, Complex[a_, b_] :> Sign[b] I}] & /@
        If[Head[rho] === Plus, List @@ rho, {rho}], 0];
    seeds = Join[{1}, DeleteCases[complementaryMultiplier /@ terms, 1], {2, 3, 5}]];
   Do[If[! roomQ[], Break[]]; admit[seed], {seed, seeds}];
   While[cursor <= Length[queue] && ! expiredQ[],
    (* "MaxTrials" bounds the trials spent on this island; "Patience" stops the
       search when an improvement exists (found by an earlier stage or by this
       search) and the last "Patience" trials did not improve on it *)
    If[trials >= $cfg["MaxTrials"], limitHit["MaxTrials"]; Break[]];
    If[best =!= target && sinceImprovement >= $cfg["Patience"], limitHit["Patience"]; Break[]];
    m = queue[[cursor]]; cursor++; trials++; sinceImprovement++; bump["Trials"];
    (* the multiplied radicand keeps its radical presentation: the GCD roots then
       come out in the radicals of rho, not as opaque algebraic numbers *)
    theta = bounded[kExpand[m rho]];
    If[theta === $Failed, Continue[]];
    p = bounded[kMinimalPolynomial[theta^(1/q), $x]];
    If[! validPolynomialQ[p, $x], If[p =!= $Failed, limitHit["MaxDegree"]]; Continue[]];
    degree = Exponent[p, $x];
    log["multiplier ", m, "  minpoly degree ", degree];
    bestDegree = Min[bestDegree, degree];
    trace["Trial", <|"Multiplier" -> m, "Degree" -> degree, "Index" -> q|>];
    (* roots of x^q == m rho: linear factors over the radicals of the radicand, then the
       proper GCD factor with the minimal polynomial of the principal root *)
    roots = If[m === 1, {}, linearRoots[theta, q]];
    gcd = bounded[kPolynomialGCDExtension[p, $x^q - theta]];
    If[validPolynomialQ[gcd, $x],
     gd = Exponent[gcd, $x];
     If[gd < q,
      roots = Join[roots, Which[
         gd === 1, {linearRoot[gcd]},
         gd <= $cfg["MaxSolveDegree"],
          sol = bounded[kSolveRadicals[gcd == 0, $x]];
          If[ListQ[sol], Select[$x /. sol, exactQ], {}],
         True, {}]]]];
    roots = exactRadicalForms[roots];
    If[roots =!= {},
     mroot = bounded[m^(1/q)];
     If[mroot =!= $Failed,
      Do[If[expiredQ[], Break[]];
       Do[If[expiredQ[], Break[]];
        candidate = bounded[kExpand[z/mroot unity[k, q]]];
        offer[candidate, "MultiplierOrbit"];
        (* a certified but not cheaper candidate (e.g. gamma^(1/3) with gamma in Q(rho))
           may itself be denestable: try it recursively *)
        If[candidate =!= $Failed && RadicalDepth[candidate] <= RadicalDepth[target] && candidate =!= target &&
          certify[candidate, target] === "Equal",
         offer[recurse[candidate], "MultiplierOrbit/Recursive"]],
        {k, 0, q - 1}],
       {z, roots}]]];
    If[RadicalDepth[best] <= 1, Break[]];
    (* discriminant primes of a promising trial (smallest degree seen so far): stream
       prime powers and a bounded prefix of mixed-radix products *)
    If[! ListQ[$cfg["Multipliers"]] && degree <= bestDegree && roomQ[],
     disc = bounded[kDiscriminant[p, $x]];
     If[IntegerQ[disc] && disc =!= 0,
      primes = boundedList[kTakeUpTo[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], 8]];
      batch = 0;
      Do[If[! batchRoomQ[], Break[]];
       Do[If[! batchRoomQ[], Break[]];
        batch++; admit[m prime^e], {e, 1, q - 1}], {prime, primes}];
      j = 1;
      While[primes =!= {} && j < q^Length[primes] && batchRoomQ[],
       digits = IntegerDigits[j, q, Length[primes]]; j++; batch++;
       admit[m Times @@ MapThread[Power, {primes, digits}]]]]]];
   If[admitted >= cap, limitHit["MultiplierCap"]];
   If[trials >= $cfg["MaxTrials"], limitHit["MaxTrials"]];
   best];

(* ------------------------------------------------------------------ *)
(* one exact algebraic island                                         *)
(* ------------------------------------------------------------------ *)

(* whole-island proposals that do not depend on the shape *)
genericProposals[target_, incumbent_] := Module[{best = incumbent, r, solver},
   solver = $cfg["Solver"];
   If[solver =!= Automatic,
    r = bounded[Catch[Catch[solver[target], _, $Failed &]]];
    best = acceptWithPolish[r, target, best, "Solver"]];
   If[! FreeQ[target, _Root | _AlgebraicNumber],
    r = bounded[kToRadicals[target]];
    If[r =!= $Failed && r =!= target, best = acceptWithPolish[recurse[r], target, best, "ToRadicals"]]];
   r = bounded[kRootReduce[target], "Certificate"];
   If[r =!= $Failed,
    best = accept[r, target, best, "RootReduce"];
    If[Head[r] === Root && kPolynomialQ[First[r][$x], $x] && Exponent[First[r][$x], $x] <= 4,
     best = acceptWithPolish[bounded[kToRadicals[r]], target, best, "RootReduce/ToRadicals"]]];
   best = accept[bounded[kSimplify[target]], target, best, "Simplify"];
   If[TrueQ[$cfg["Factor"]], best = accept[bounded[kFactor[target]], target, best, "Factor"]];
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
   cands = boundedList[rootCandidates[rho, q]];
   Do[best = acceptWithPolish[bounded[kExpand[c^p]], target, best, "FastPath"], {c, cands}];
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
     best = acceptWithPolish[bounded[kExpand[(root^(2/q))^p]], target, best, "EvenIndexSplit"];
     root = recurse[root^(2/q)];
     best = acceptWithPolish[bounded[kExpand[root^p]], target, best, "EvenIndexSplit/Recursive"]]];
   best];

(* the multiplier search is meant for a radical node or a product of radical
   nodes; a sum island gets the whole-island proposals only *)
searchableQ[e_] := MatchQ[e, Power[_, _Rational]] ||
   (Head[e] === Times && AllTrue[List @@ e, MatchQ[#, _?kGaussianQ | Power[_, _Rational]] &]);

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
   If[kKeyExistsQ[$memo, target],
    entry = $memo[target]; best = entry["Result"];
    If[entry["Complete"] && And @@ Thread[entry["Budget"] >= memoBudget[]], Return[best]]];
   If[kKeyExistsQ[$inProgress, target], Return[best]];
   bump["Islands"];
   Block[{$inProgress = Append[$inProgress, target -> True]},
    best = powerProposals[target, best];
    If[RadicalDepth[best] >= 2 || ! FreeQ[best, _Root | _AlgebraicNumber], best = genericProposals[target, best]];
    If[RadicalDepth[best] >= 2 && $cfg["Solver"] === Automatic && searchableQ[target] && ! expiredQ[],
     best = multiplierSearch[target, best]]];
   kAssociateTo[$memo, target -> <|"Result" -> best, "Budget" -> memoBudget[], "Complete" -> ! expiredQ[]|>];
   best];

(* an exact algebraic island: children first (all levels) or outermost
   radical nodes first (default), then the island as a whole *)
(* recombination of an island whose components were rewritten: the proposals
   are computed from the rewritten form but certified against the original *)
combineProposals[target_, incumbent_] := Module[{best = incumbent, r},
   r = bounded[kRootReduce[incumbent], "Certificate"];
   best = accept[r, target, best, "Combine/RootReduce"];
   best = accept[bounded[kSimplify[incumbent]], target, best, "Combine/Simplify"];
   best = accept[bounded[Together[incumbent]], target, best, "Combine/Together"];
   best = accept[bounded[kExpand[incumbent]], target, best, "Combine/Expand"];
   best];

(* the components of e denested as islands of their own, and the cheaper of two forms *)
rebuildChildren[e_] := If[Head[e] === Power, Power[island[First[e]], Last[e]], Map[island, e]];
cheaperOf[new_, old_] := If[new =!= old && cheaperQ[new, old], new, old];
island[e_] := Module[{current = e, rebuilt},
   If[expiredQ[], Return[e]];
   If[RadicalDepth[e] < 2 && FreeQ[e, _Root | _AlgebraicNumber], Return[e]];
   If[MatchQ[e, Power[_, _Rational]],
    If[TrueQ[$cfg["AllLevels"]],
     (* the radicand is an island of its own; congruence carries its certificate *)
     current = cheaperOf[rebuildChildren[e], e]];
    Return[improveNumber[current]]];
   If[MemberQ[{Plus, Times}, Head[e]] || MatchQ[e, Power[_, _Integer]],
    (* components first: each component certified against itself *)
    current = cheaperOf[rebuildChildren[e], e];
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
  session[cfg, cfg["TimeBudget"],
   Module[{committed = {e, Missing["NotComputed"]}, initialCost = Missing["NotComputed"], candidate, candidateCost,
     outcome = Null, started = AbsoluteTime[], passes, status, numericInput = False},
    passes = If[TrueQ[cfg["AllLevels"]] && ! coreOnly, cfg["MaxPasses"], 1];
    If[TrueQ[cfg["TimeBudget"] == 0], limitHit["TimeBudget"],
     (* the classification of the input and every cost computation are inside the region *)
     outcome = TimeConstrained[
       kMemoryConstrained[
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
     Which[outcome === memoryStopped, limitHit["MemoryBudget"], outcome === timeStopped, limitHit["TimeBudget"]]];
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
     "CertificatesTruncated" -> (kLookup[$stats, "CandidatesAccepted", 0] > Length[$records]),
     "LimitsMeaning" -> "Guards that were triggered or caps that were reached; not impossibility certificates",
     "ElapsedSeconds" -> AbsoluteTime[] - started, "Options" -> cfg,
     "Trace" -> $trace, "CompletenessClaim" -> False|>]];

invoke[e_, head_Symbol, rules_List, report_, core_] := Module[{cfg, result},
   cfg = resolveOptions[head, rules];
   If[kFailureQ[cfg], Return[cfg]];
   result = run[e, cfg, core];
   If[TrueQ[report], result, result["Result"]]];

(* every argument sequence reaches the option validator, so a malformed call
   such as DenestRadicals[e, 17] returns a Failure instead of staying unevaluated *)
DenestRadicals[e_, all : (True | False), args___] := invoke[e, DenestRadicals, {"AllLevels" -> all, args}, False, False];
DenestRadicals[e_, args___] := invoke[e, DenestRadicals, {args}, False, False];
DenestCore[e_, args___] := invoke[e, DenestCore, {args}, False, True];
DenestReport[e_, all : (True | False), args___] := invoke[e, DenestReport, {"AllLevels" -> all, args}, True, False];
DenestReport[e_, args___] := invoke[e, DenestReport, {args}, True, False];
DenestRadicals[] := noExpression[]; DenestCore[] := noExpression[]; DenestReport[] := noExpression[];
noExpression[] := failure["InvalidArguments", "An expression is required."];

(* ================================================================ *)

(* 5.  The shared radical grammar                                   *)

(* ================================================================ *)

(* RadicalExpressionQ, RadicalDepth, RadicalCost and ExactAlgebraicQ are
   defined once, in section 4, and are used by sections 3 and 4 alike.  The
   two packages had arrived at the same predicate independently:
   RootToRadicals` admitted rationals, Gaussian rationals and Plus, Times and
   rational Power combinations of them, and so did RadicalDenest3`, which in
   addition checks the arity of a Power node and treats Root and
   AlgebraicNumber objects as opaque.  The stricter pair is the one kept. *)


End[];
EndPackage[];
