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

Eleven workloads exercise sparse certificate generation, decomposition over an
algebraic coefficient field, two complete-chain enumerations, two Galois field
constructions, bounded catalogue generation, multiplication by a root of unity,
two input-field operations, and generalized reciprocal recognition. `--match` selects labels:

```console
python benchmarks/compare_solvers.py --baseline 0bb70f4 --match certificate
```

The script loads each baseline implementation directly from the resolved commit.
It warms both versions, alternates their execution order, and checks exact output
equality after every sample. Input construction and equality checks are excluded
from the measured calls. The Galois checks compare the complete exact action,
coordinates, Gram matrices, subgroup data, and exponent. Reciprocal recognition
is measured with identical dependencies; that recognizer does not invoke the
shared field engine. A mismatch fails the command.

The catalogue workload bypasses the result cache and compares every polynomial
and root index in enumeration order. The multiplication workload uses identical
current field data for both implementations and measures only matrix recovery,
with its original precision fallback. It does not measure field construction.
Its selected cube root of unity is uniquely isolated before timing.
The input-field workloads copy identical current field data into each version's
own field class, so both multiplication and element reconstruction use the
corresponding implementation. Field construction is excluded; every resulting
matrix or minimal-polynomial/root-index pair is compared exactly.
These isolate the `InputFieldData` methods; the prepared `theta` object and its
root evaluator come from the current implementation in both cases.

The JSON records the baseline commit, current Git HEAD, dependency versions,
hashes of the current Python source text with normalized newlines, every timing
sample, medians, and
exact-check status. Ratios describe these workloads on the current machine;
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
