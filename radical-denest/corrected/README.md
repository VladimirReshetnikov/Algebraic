# Corrected versions of `Strad.wl`

Three generations of the corrected denester live here.

| File | Context | Produced by | Reviewed by |
|---|---|---|---|
| `StradFixed.wl` | ``RadicalDenest` `` | `src/code-review/unified-A` (first unified analysis) | review-4, review-5, review-6 (no longer in the repository; assessed in unified-B); probing session (`KNOWN_GAPS.md`) |
| `StradFixed2.wl` | ``RadicalDenest2` `` | `src/code-review/unified-B` (second unified analysis) | `src/code-review/review-7`, `review-8`, `review-9` |
| `StradFixed3.wl` | ``RadicalDenest3` `` | `src/code-review/unified-C` (third unified analysis) | — |

`StradFixed3.wl` is the current version. The earlier versions are kept because
the analyses, the reviews and `KNOWN_GAPS.md` refer to them; the three packages
use different contexts and can be loaded side by side for differential testing.

## StradFixed3.wl

```wl
Get["src/corrected/StradFixed3.wl"];
Strad[Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]]]   (* Sqrt[6] + Sqrt[35] + Sqrt[77]: coset search *)
Strad[(239 + 169 Sqrt[2])^(1/7)]                 (* 1 + Sqrt[2]: odd-index trace-norm recipe *)
Strad[Sqrt[28^(1/3) - 3]]                        (* (-1 - 28^(1/3) + 98^(1/3))/3: Honsbeek with a rational summand *)
Strad[(3 + 2 Sqrt[2])^(1/6), "MaxRecursion" -> 0]   (* (1 + Sqrt[2])^(1/3): index reduction without recursion *)
ExactAlgebraicQ[Root[#^5 + # - Pi &, 1]]         (* False: exact is not algebraic *)
EqualityStatus[Sqrt[2], -Sqrt[2]]                (* "Different", decided by exact algebra *)
Strad[Sqrt[2], 17]                               (* Failure["InvalidOption", ...] *)
DenestReport[Sqrt[5 + 2 Sqrt[6]]]                (* adds ResultChanged, CertificateKind, CertificatesTruncated *)
```

Contract: as for `StradFixed2.wl` below, with these corrections. The exact
input grammar admits rationals, Gaussian rationals, their `Plus`, `Times` and
rational-`Power` combinations, `Root` objects whose defining polynomial (single
or triangular-system form) has coefficients in that grammar and a valid index,
and `AlgebraicNumber` objects with an admitted generator and Gaussian-rational
coefficients; other exact objects are opaque host nodes. `EqualityStatus` is
decided by exact algebra in every branch; `"NumericPrefilter"` (now `False` by
default) only prunes search candidates. Every proposal stage receives and
returns its incumbent. Unchanged results are memoized together with the budget
that produced them and are reused only by searches with no larger budget. The
classification of the input and the report costs run inside the resource
region. Malformed calls such as `Strad[e, 17]` and `Strad[]` return a
`Failure`.

What it does that `StradFixed2.wl` did not: the trace–norm criterion for every
odd index up to `"MaxOddIndex"` (default 9) via the Dickson recurrences; a
Honsbeek recognizer that accepts any two-term sum of terms with rational cubes,
including rational summands and terms like `2^(2/3) 7^(1/3)`; a square-class
coset search for multi-surd square roots (an integer-relation stage per coset
certified by `RootReduce`, then rational systems), which finds
`Sqrt[6] + Sqrt[35] + Sqrt[77]`, `Sqrt[6] + Sqrt[10] + Sqrt[21]`,
`Sqrt[10] + Sqrt[15] + Sqrt[35]`, `Sqrt[30] + Sqrt[42] + Sqrt[70]` and
`(Sqrt[2] + Sqrt[3] + Sqrt[5])/2` without the multiplier search; index
reductions such as `(3 + 2 Sqrt[2])^(1/4) -> Sqrt[1 + Sqrt[2]]` offered before
recursion.

New options (defaults): `"MaxOddIndex"` (9), `"DiscriminantBatchCap"` (24),
`"MaxCosets"` (16); `"NumericPrefilter"` now defaults to `False`. All other
options and public symbols are those of `StradFixed2.wl`.

See `src/code-review/unified-C/unified_analysis_C.pdf` for the catalogue of the
22 issues it addresses, the design changes, the mathematics and the executed
experiments; the regression suite is
`src/code-review/unified-C/tests/StradFixed3.wlt` (230 tests).

## StradFixed2.wl

```wl
Get["src/corrected/StradFixed2.wl"];
Strad[Sqrt[5 + 2 Sqrt[6]]]                       (* Sqrt[2] + Sqrt[3] *)
Strad[(41 - 29 Sqrt[2])^(1/5)]                   (* (-1)^(1/5) (Sqrt[2] - 1): principal branch kept *)
Strad[(7 20^(1/3) - 19)^(1/6)]                   (* (5/3)^(1/3) - (2/3)^(1/3) *)
Strad[Sqrt[16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]]], True]   (* Sqrt[5] + Sqrt[11 - 2 Sqrt[29]] *)
Strad[x + Sqrt[5 + 2 Sqrt[6]], "Solver" -> (0 &)]   (* x + Sqrt[2] + Sqrt[3]: the solver is only a proposal *)
DenestReport[Sqrt[1 + Sqrt[2]], "MaxTrials" -> 20, "TimeBudget" -> 10]   (* status, limits, statistics, certificates *)
```

Contract, for an exact algebraic input and for every exact algebraic island of
a symbolic host: every replaced island is certified equal to the island it
replaces by exact algebra (`RootReduce`, then `PossibleZeroQ` with
`Method -> "ExactAlgebraics"`), whatever produced the candidate; a replacement
is strictly cheaper under `RadicalCost` or the island is returned unchanged;
the whole call runs inside one `TimeConstrained`/`MemoryConstrained` region
(`"TimeBudget"`, `"MemoryBudget"`) and every expensive kernel operation inside
its own bounded region (`"OperationTime"`, `"CertifyTime"`); `"MaxTrials"`
bounds the multiplier trials spent on any one island; symbolic hosts are never
simplified and ambient `$Assumptions` are ignored; unknown or invalid options
return a `Failure`. There is no completeness guarantee.

What it does that `StradFixed.wl` did not: exact fast paths for direct,
indirect (fourth-root), Gaussian, cubic-in-quadratic, Honsbeek and multi-surd
square roots; separation of the phase of a negative radicand,
`rho^(p/q) = (-1)^(p/q) (-rho)^(p/q)`; linear factors of `x^k - rho` over the
radicals of `rho` for every divisor `k` of the index (Kummer roots and index
reduction), with recursion on sub-problems; whole-island `RootReduce` and
`Simplify` proposals that catch cancellation across summands; a multiplier
queue with one capped admission gate and a patience rule; a structured
`DenestReport`. Every one of the fifteen inputs listed in `KNOWN_GAPS.md` is
now denested.

Public symbols: `Strad`, `DenestRadicals`, `DenestCore`, `DenestReport`,
`EqualityStatus`, `CertifiedEqualQ`, `ExactAlgebraicQ`, `RadicalExpressionQ`,
`RadicalDepth`, `RadicalCost`, `RationalizeDenominator`, `Factorc`.

Options (defaults): `"AllLevels"` (False), `"Verbose"` (False), `"Trace"`
(False), `"Multipliers"` (Automatic), `"Solver"` (Automatic), `"Factor"`
(True), `"MaxTrials"` (120), `"TimeBudget"` (120 s), `"OperationTime"` (30 s),
`"CertifyTime"` (20 s), `"MemoryBudget"` (1 GiB), `"MultiplierCap"` (1000),
`"MaxRootIndex"` (32), `"MaxDegree"` (64), `"MaxSolveDegree"` (4),
`"MaxLeafCount"` (20000), `"MaxPasses"` (4), `"MaxRecursion"` (3),
`"Patience"` (25), `"NumericPrefilter"` (True), `"MaxTraceEntries"` (200).

See `src/code-review/unified-B/unified_analysis_B.pdf` for the catalogue of the
23 issues it addresses, the design, the mathematics of the fast paths and the
executed experiments; the regression suite is
`src/code-review/unified-B/tests/StradFixed2.wlt`. Its three reviews are
`src/code-review/review-7`, `review-8` and `review-9`; their findings are
addressed by `StradFixed3.wl`.

## StradFixed.wl

The first corrected version keeps the architecture of the original (wrapper,
radical markers, multiplier search with minimal polynomials and polynomial
GCDs over algebraic extensions, roots-of-unity orbit) but certifies every
result against the input by exact algebra and adds budgets, a visited set, a
quadratic-surd fast path and candidate polishing. See
`src/code-review/unified-A/unified_analysis.pdf`, Section 7, for its change
list and Section 5 for its test results. Its known gaps are listed in
`KNOWN_GAPS.md`; the reviews of it are `src/code-review/review-4`, `review-5`
and `review-6`.
