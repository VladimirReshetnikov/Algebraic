# Solver performance comparisons

Run the shared Python comparison from the repository root:

```console
python benchmarks/compare_solvers.py --baseline 204c97f --samples 7 --output build/solver-comparison.json
```

Create the output directory first if it does not exist. The script can also be
run by absolute path from another directory. It uses the same Python, SymPy,
and python-flint dependencies as the solvers. The baseline revision must be
available in the local Git history; `204c97f` is the merged baseline before the
shared solver refactoring.

Twenty-one workloads exercise sparse certificate generation, decomposition over an
algebraic coefficient field, two complete-chain enumerations, two Galois field
constructions, bounded catalogue generation, multiplication by a root of unity,
two input-field operations, input-field construction, generalized reciprocal
recognition, three certificate verification workloads, complete-chain generation
with verification, four full root searches, and a full quintic radical expression.
`--match` selects labels:

```console
python benchmarks/compare_solvers.py --baseline 0bb70f4 --match certificate
```

To reproduce the later preparation and search comparisons against their own
baseline, use:

```console
python benchmarks/compare_solvers.py --baseline b2a8ada --match verification --cold-sympy-cache --samples 7
python benchmarks/compare_solvers.py --baseline b2a8ada --match "of degree-9" --samples 7
```

Each verification-only workload prepares one certificate before timing and
requires both verifiers to accept it. The dense degree-48 and power degree-360
certificates cover every proper divisor; the sparse algebraic degree-240 certificate
checks right degree four for \((2+\sqrt{2})x^{240}+x^7+7\).
The chain workflow includes enumeration
and complete/normalized verification, then compares the entire returned chain
sets outside the clock. The four root searches use each revision's own algebraic
number class and compare every result field, including normalized term
polynomials/root indices, bounds, optimality flags, method, and extra metadata.
The warm-up populates each version's field caches before those search timings.
The capped quartic sum allows at most two terms; the degree-eight tensor product
allows at most three factors and disables recursive splitting. Their inputs are
\(1+\sqrt{2}+\sqrt{3}\) and \((1+\sqrt{2})(1+\sqrt{3})(1+\sqrt{5})\), respectively,
represented by exact polynomials and selected root indices.
These rows compare exact outputs; independent identity proofs remain the job
of the project verification suites.

`--cold-sympy-cache` clears registered SymPy caches before every timed call,
outside the clock. This flag does not clear solver field/result caches or rebuild
inputs; workload-specific cache handling is described below. The JSON records
this choice; the default retains warmed SymPy caches.

The script loads each baseline implementation directly from the resolved commit.
It warms both versions, alternates their execution order, and checks exact output
equality after every sample. Input polynomial and algebraic-number construction,
signature calculation, and equality checks are excluded from the measured calls.
The Galois checks compare the complete exact action, coordinates, Gram matrices,
subgroup data, and exponent. A mismatch fails the command.

The catalogue workload bypasses the result cache and compares every polynomial
and root index in enumeration order. The multiplication workload uses identical
current field data for both implementations and measures only matrix recovery,
with its original precision fallback. It does not measure field construction.
Its selected cube root of unity is uniquely isolated before timing.
The two prepared input-field degree-8 workloads copy identical current field data
into each version's own field class, so both multiplication and element
reconstruction use the corresponding implementation. Field construction is
excluded; every resulting matrix or minimal-polynomial/root-index pair is
compared exactly. These isolate the `InputFieldData` methods; the prepared
`theta` object and its root evaluator come from the current implementation in
both cases.

The separate `input-field S4 construction` workload builds the degree-four input
field for root index one of \(x^4-x-1\). Each revision receives an input constructed
with its own algebraic-number class. Every call clears that revision's `_ifcache`
and runs `input_field_data`; **both cache clearing and field construction are
inside the clock**. The comparison retains every field-data attribute, with
`theta` represented by its exact polynomial and root index.

Both radical workloads share the current `rootdecomp` dependency. Reciprocal
recognition does not invoke that dependency. The `quintic radical expression`
workload calls each revision's public `root_to_radicals` on the same current-class
algebraic number: root index five of \(5x^5-25x^3+25x+6\). Its timed call includes
expression generation, branch selection, and verification. Each result must use
the `Dickson` method and have `verified is True`. The comparison retains the
full result record except its elapsed `time`, and also checks radical depth and
leaf count. Those signatures are calculated outside the clock.

The JSON records the baseline commit, current Git HEAD, dependency versions,
hashes of the current Python source text with normalized newlines, every timing
sample, medians, and exact-check status. Ratios describe these workloads on the current machine;
they do not compare complete test-suite runtimes. Native Wolfram and independent
cross-language correctness remain covered by the three projects' test suites and
`python/verify_wolfram.py` scripts.

The source hashes identify the code actually loaded, including local edits if
present; Git HEAD alone does not identify uncommitted source changes.

## Recorded comparison (9 September 2026)

The [saved comparison](results/refactor-2026-09-09.json) measures solver revision
`f3fceb2` against baseline `204c97f`, using Python 3.14.4, SymPy 1.14.0, and
python-flint 0.8.0. Each row gives the median of seven samples per version after
warm-up. All eleven workloads returned identical exact outputs on every check.

| Workload | Baseline (seconds) | Refactored (seconds) | Baseline / refactored |
| --- | ---: | ---: | ---: |
| Sparse degree-600 certificate | 0.061940 | 0.000842 | 73.58x |
| Algebraic degree-96 chain | 0.327013 | 0.018737 | 17.45x |
| Chebyshev degree-120 all chains | 0.041738 | 0.033090 | 1.26x |
| Power degree-360 all chains | 0.064030 | 0.010908 | 5.87x |
| S4 field construction | 0.152472 | 0.048385 | 3.15x |
| Order-36 field construction | 2.280092 | 0.471752 | 4.83x |
| Degree-2 height-4 catalogue | 0.000882 | 0.000778 | 1.13x |
| Input-field degree-8 multiplication matrix | 0.000023 | 0.000018 | 1.28x |
| Input-field degree-8 element reconstruction | 0.000159 | 0.000109 | 1.45x |
| Order-48 unity multiplication matrix | 0.038619 | 0.011869 | 3.25x |
| Degree-48 reciprocal recognition | 0.004004 | 0.000212 | 18.89x |

These selected cases illustrate specific improvements; they do not establish a
universal speedup. In particular, very short timings are sensitive to system
load. The JSON retains all samples and unrounded values for inspection.

## Additional refinement comparison (9 September 2026)

The [verification snapshot](results/refinement-verification-2026-09-09.json) and
[search snapshot](results/refinement-search-2026-09-09.json) compare solver
revision `a39acf7` against `b2a8ada`, which already includes the earlier
refactoring. Both record seven alternating samples per version, with exact
checks passing on every warm-up and timed result.

The first two rows clear registered SymPy caches before each timed call, while
retaining prepared inputs. The two root-search rows use warmed field and SymPy
caches. Their timing boundaries are described above.

| Workload | Baseline (seconds) | Refined (seconds) | Baseline / refined |
| --- | ---: | ---: | ---: |
| Dense degree-48 certificate verification | 0.737595 | 0.229719 | 3.21x |
| Chebyshev degree-120 chains with verification | 0.236360 | 0.145153 | 1.63x |
| Sum of degree-9 product root | 0.187873 | 0.107650 | 1.75x |
| Product of degree-9 sum root | 0.266291 | 0.141649 | 1.88x |

These comparisons concern different revisions and cache conditions from the
earlier table. The added rank check can cost time on nonempty nullspaces, and
the low-precision trace trial can cost time when it needs the original fallback.
The selected workloads show where the refinements help; they do not establish
that every input becomes faster.

## Exact-domain and bounded-search comparison (9 September 2026)

The [capped-sum snapshot](results/capped-sum-2026-09-09.json),
[tensor-product snapshot](results/tensor-product-2026-09-09.json), and
[exact-domain verification snapshot](results/exact-domain-verification-2026-09-09.json)
compare solver revision `2a827ce` against `90d2386`. Each records seven alternating
samples and complete exact-output checks. The root searches retain warm field and
SymPy caches. The chain-generation-and-verification workload clears registered
SymPy caches outside each timed call.

| Workload | Baseline (seconds) | Refined (seconds) | Baseline / refined |
| --- | ---: | ---: | ---: |
| Two-term quartic sum | 0.000162 | 0.000121 | 1.34x |
| Three-factor degree-8 tensor product | 0.009630 | 0.007552 | 1.28x |
| Chebyshev degree-120 chains with verification | 0.049570 | 0.039397 | 1.26x |

Reproduce these comparisons with:

```console
python benchmarks/compare_solvers.py --baseline 90d2386 --match two-term --samples 7
python benchmarks/compare_solvers.py --baseline 90d2386 --match three-factor --samples 7
python benchmarks/compare_solvers.py --baseline 90d2386 --match "chains with verification" --cold-sympy-cache --samples 7
```

The capped sum avoids converting two centered components that the term cap would
discard. The tensor example exercises reuse of the fixed scale-candidate table.
The polynomial change avoids materializing expressions for exact `Poly` inputs
merely to scan for floating-point values. Its benefit depends on cache state:
a separate warm verification-only T120 comparison was about 7% slower, while
cold comparisons improved. These rows measure the specified complete workflows,
and do not establish a universal speedup. Unordered commutator pairs also reduce
derived-subgroup work in both languages, but this benchmark does not isolate that
change or claim a substantial full-descent improvement from it.

## Monomial verification and field-basis comparison (9 September 2026)

The [monomial verification snapshot](results/monomial-verification-2026-09-09.json)
and [field-basis product snapshot](results/basis-product-2026-09-09.json) compare
solver revision `88ade00` against `9dadd5c`. Each row records seven alternating
samples and exact checks of every warm-up and timed result. The verification rows
clear registered SymPy caches before each timed call, retaining the prepared
polynomial and certificate. The product search uses each revision's own warmed
field caches and compares every result field.

| Workload | Baseline (seconds) | Refined (seconds) | Baseline / refined |
| --- | ---: | ---: | ---: |
| Dense degree-48 certificate verification | 0.056046 | 0.051602 | 1.09x |
| Power degree-360 certificate verification | 0.032872 | 0.002866 | 11.47x |
| Sparse algebraic degree-240 certificate verification | 0.021861 | 0.001177 | 18.58x |
| Product of degree-9 sum root | 0.056431 | 0.045789 | 1.23x |

Reproduce these comparisons with:

```console
python benchmarks/compare_solvers.py --baseline 9dadd5c --match "certificate verification" --cold-sympy-cache --samples 7
python benchmarks/compare_solvers.py --baseline 9dadd5c --match "product of degree-9" --samples 7
```

Monomial certificate reconstruction pads and concatenates nonoverlapping digit
blocks, while retaining the same verification criteria and Horner fallback.
The product search batches multiplication and negation of the second field basis
in exact FLINT arithmetic, preserving column order. These measurements concern
certificate verification and the specified root search; generic polynomial-chain
enumeration remained approximately unchanged in the separate prototype comparison.

## Input-field construction and Dickson conversion (9 September 2026)

The [input-field construction snapshot](results/input-field-construction-2026-09-09.json)
and [Dickson conversion snapshot](results/dickson-radicals-2026-09-09.json) compare
solver revision `f2ce84c` against `e004333`. Each records seven alternating samples,
with complete output comparisons after warm-up and every timed call.

| Workload | Baseline (seconds) | Refined (seconds) | Baseline / refined |
| --- | ---: | ---: | ---: |
| Input-field S4 construction | 0.008262 | 0.006369 | 1.30x |
| Quintic radical expression | 0.000619 | 0.000311 | 1.99x |

Both measurements retain warmed SymPy caches. The construction row clears each
revision's solver field cache inside the timed call; it measures uncached field
construction and that cache clearing. Reusing the field generator's existing
exact coefficient representation avoids a redundant algebraic-field conversion.
The radical row includes the complete public conversion, branch selection and
verification, with the same current root dependency in both module revisions.
Its Dickson recognizer checks an exact rational differential identity instead
of reconstructing the symbolic polynomial recurrence.

Reproduce these comparisons with:

```console
python benchmarks/compare_solvers.py --baseline e004333 --match "input-field S4 construction" --samples 7
python benchmarks/compare_solvers.py --baseline e004333 --match "quintic radical expression" --samples 7
```

These are Python/FLINT workload measurements. The submillisecond radical timings
are sensitive to system load; all raw samples remain in the snapshot. The separate
31-sample prototype comparison also improved the complete quintic conversion by
1.99x, while the cyclic-quintic fallback control remained unchanged. This does
not establish a general descent or Wolfram performance improvement.
