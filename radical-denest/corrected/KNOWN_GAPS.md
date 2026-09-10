# Denestable inputs that `StradFixed.wl` does not denest

> Status (5 September 2026, later the same day): all fifteen inputs below are
> denested by the second corrected version `StradFixed2.wl` (see
> `src/code-review/unified-B/unified_analysis_B.pdf`, Section 7.4) and by the
> third, `StradFixed3.wl` (`src/code-review/unified-C`, Section 7.5); both
> regression suites carry them as `G-*` tests. This file describes the first
> corrected version.

Findings of a probing session on 5 September 2026 (Wolfram 15.0.1). Four
batteries of denestable inputs taken from the literature guide
(`docs/report`) and from constructed identities were run through `Strad` of
the corrected package with a 400 s wall limit per input. The scripts are
`src/code-review/unified-A/harness/probe_gaps_{1,2,3,4}.wl`, the transcripts
`src/code-review/unified-A/logs/probe_gaps_{1,2,3,4}.txt` (the fourth run was
stopped by hand after its timing section). Every returned value was checked
against the input with `RootReduce`; no wrong value was returned anywhere.

136 inputs were run. Of the 111 that are denestable and not auto-evaluated by
the kernel, 96 were denested to the expected depth, including all
quadratic-surd and multiquadratic sums with up to four independent square
roots, the depth-3 inputs, the Ramanujan and Honsbeek identities, mixed-index
sums, complex radicands, cube, fifth and seventh roots of positive elements of
quadratic fields, and a `Root` input. The 15 misses fall into five families.

## A. Principal root of a negative radicand, index 5 or more (8 inputs)

| id | input | expected (depth 1) |
|---|---|---|
| C05 | `(41 - 29 Sqrt[2])^(1/5)` | `(-1)^(1/5) (Sqrt[2] - 1)` |
| C14 | `(-99 - 70 Sqrt[2])^(1/6)` | `(-1)^(1/6) (1 + Sqrt[2])` |
| S11 | `(-21 - 15 2^(1/3) - 12 2^(2/3))^(1/5)` | `(-1)^(1/5) (1 + 2^(1/3))` |
| S12 | `(-239 - 169 Sqrt[2])^(1/7)` | `(-1)^(1/7) (1 + Sqrt[2])` |
| S13 | `(76 - 44 Sqrt[3])^(1/5)` | `(-1)^(1/5) (Sqrt[3] - 1)` |
| S14 | `(682 - 305 Sqrt[5])^(1/5)` | `(-1)^(1/5) (Sqrt[5] - 2)` |
| S15 | `(1393 - 985 Sqrt[2])^(1/9)` | `(-1)^(1/9) (Sqrt[2] - 1)` |
| S20 | `((Sqrt[2] - Sqrt[3])^5 expanded)^(1/5)` | `(-1)^(1/5) (Sqrt[3] - Sqrt[2])` |

The same shapes with index 3 (C13, S18, S19) and index 4 (P18) are denested.

Cause. `tryMultiplier` intersects `x^r - rho` with the minimal polynomial of
the *principal* root and solves the resulting factor. For a negative real
radicand the real root `-|rho|^(1/r)` lies in `Q(rho)` and is a linear factor
of `x^r - rho`, but it is not a conjugate of the principal root, so it is
never in the GCD. For r = 3 or 4 the GCD is quadratic over `Q(rho)` and
`Solve` returns a clean closed form; for r >= 5 the GCD has degree 4 or more
and `Solve` returns `Root` objects (C05) or deeply nested square roots (C14).
These candidates are certified equal to the input but are not cheaper under
`RadicalCost`, so the input is returned; the verbose log shows
`success: {1, 8}` followed by an unchanged result.

Fix. For a negative real radicand denest `|rho|^(1/r)` and multiply by
`(-1)^(1/r)` (the fast path already listed in the report's future work). More
generally, take the linear factors of `x^r - rho` over `Q(rho)` with
`Factor[..., Extension -> Automatic]` and apply the roots-of-unity orbit to
each of their roots, not only to the roots of the GCD with the principal
root's minimal polynomial.

## B. Composite index whose answer generates a larger field than the radicand (4 inputs)

| id | input | expected |
|---|---|---|
| R03 | `(7 20^(1/3) - 19)^(1/6)` (Ramanujan) | `(5/3)^(1/3) - (2/3)^(1/3)` |
| P02 | `(133 + 57 2^(2/3) 3^(1/3) + 48 2^(1/3) 3^(2/3))^(1/6)` | `2^(1/3) + 3^(1/3)` |
| S10 | `((2^(1/3) + 5^(1/3))^6 expanded)^(1/6)` | `2^(1/3) + 5^(1/3)` |
| S04 | `((2^(1/3) + 3^(1/3))^9 expanded)^(1/9)` | `2^(1/3) + 3^(1/3)` |

Cube roots of the same elements (R09, `(5 + 3 12^(1/3) + 3 18^(1/3))^(1/3)`)
and sixth roots whose answer has the same degree as the radicand (S01, S02,
S06-S09) are denested.

Cause. Here `[Q(beta) : Q(rho)] = 3`, so `x^6 - rho` has a cubic factor over
`Q(rho)`, and `Solve` returns its roots as `(gamma)^(1/3)` with
`gamma = beta^3` in `Q(rho)`, for example `(1 + 20^(1/3) - 50^(1/3))^(1/3)`
for R03. This candidate is certified but has the same depth as the input, so
it is discarded; the recursive pass in `recursiveCore` runs only on accepted
candidates, and the cube root `gamma^(1/3)` would have been denested by the
existing machinery (as R09 shows).

Fix. Index reduction: if `rho` is a k-th power in `Q(rho)` (a linear factor
of `x^k - rho` over the extension), replace `rho^(1/r)` by
`gamma^(1/(r/k))` with a branch check, then denest that. Alternatively run
the denester recursively on certified candidates of equal depth before the
cost comparison, under the existing recursion guard.

## C. The factorizer extracts a factor whose root is irrational (1 input)

| id | input | expected |
|---|---|---|
| S05 | `(1296 + 880 Sqrt[2] + 720 Sqrt[3] + 528 Sqrt[6])^(1/6)` | `1 + Sqrt[2] + Sqrt[3]` |

Cause. `Factorc` rewrites the radicand as `16 (81 + 55 Sqrt[2] + ...)`, so
the wrapper hands the core `2^(2/3) (81 + ...)^(1/6)`. The remaining sixth
root has degree 12 instead of 4 and the core finds nothing cheaper. With
`"Factor" -> False` the same input is denested in 0.11 s.

Fix. Extract from a radicand only factors that are perfect r-th powers, or
try the core on both the factored and the unfactored problem.

## D. Cancellation across summands (1 input)

| id | input | expected |
|---|---|---|
| Q21 | `Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]]` | `0` |

Cause. Each summand is individually non-denestable (minimal polynomial of
degree 4 for every multiplier tried), and the wrapper treats summands as
independent problems. This is the joint-denesting gap listed in the report's
future work, now with Landau's cancellation identity as a concrete failing
input. Sums whose summands denest individually (Q20, P15, P25) and products
that the kernel merges into one radical (P08, Q19) are handled.

## E. Time budget not enforced inside a trial (1 input)

| id | input | expected |
|---|---|---|
| P13 | `Sqrt[(Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7] + Sqrt[11])^2 expanded]` | the five-term sum |

Cause. The four-prime analogue (Q11) takes 2.9 s, the five-prime input does
not finish in 400 s, and `"TimeBudget" -> 20, "MaxTrials" -> 5` still runs
for 408 s. `MinimalPolynomial` of the problem takes 0.07 s, so the time is
spent inside the first trial: `PolynomialGCD`/`Solve` over an extension with
eleven square-root generators (degree 32). The budget is checked only between
trials, so guarantee (iv) of the report ("stops within TimeBudget seconds")
does not hold for a single expensive trial.

Fix. Wrap each trial in `TimeConstrained` with the remaining budget, and add a
direct test for radicands of the form `(sum of square roots)^2`, which the
pairwise-product structure of the expanded radicand exposes without any field
computation.

## Not counted as misses

- X01-X07 (`Sqrt[3 + 4 I]`, `(-2 + 2 I)^(1/3)`, ...) and P09-P11
  (`Sqrt[(1 + Sqrt[2])^2]`, `((1 - Sqrt[2])^3)^(1/3)`) are evaluated by the
  kernel itself before `Strad` sees them.
- N01-N04 are non-denestable controls and were correctly left unchanged.
- P24, `Sqrt[a + 2 Sqrt[a - 1]]`, has a symbolic parameter and is left
  untouched by design.
- P25 and P29 have no representation of smaller depth; the returned values
  are the expected simplifications.
- `Sqrt[2 + Sqrt[2]]` (N01) is unchanged; its depth-one form
  `(-1)^(1/8) + (-1)^(-1/8)` needs roots of unity as constants, a convention
  the package does not adopt.
- R15 in the first battery was mis-constructed by hand (its radicand is not
  `(1 + 2^(1/3) + 3^(1/3))^2`); the correctly constructed R16-R18 are denested.

## Conclusions

The corrected package is sound on everything tried: no wrong value, no
message, and controls unchanged. Its completeness gaps are concentrated in
the `Solve`-based candidate step of the core and in the wrapper's
preprocessing, not in certification: in families A and B the core actually
finds a certified candidate and then throws it away because it is not
cheaper in its raw form. Families A, B and C are each fixable locally
(negative-radicand fast path or linear factors of `x^r - rho`; index
reduction or recursion on equal-depth candidates; restricting the factor
extraction). Family E needs per-trial time limits to honour the documented
budget. Family D is a design limit of the summand-by-summand architecture.
