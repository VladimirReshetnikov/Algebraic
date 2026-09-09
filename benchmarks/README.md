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

Six workloads exercise sparse certificate generation, decomposition over an
algebraic coefficient field, complete chain enumeration, two Galois field
constructions, and generalized reciprocal recognition. `--match` selects labels:

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

The JSON records the baseline commit, dependency versions, hashes of the current
Python source text with normalized newlines, every timing sample, medians, and
exact-check status. Ratios describe these workloads on the current machine;
they do not compare complete test-suite runtimes. Native Wolfram and independent
cross-language correctness remain covered by the three projects' test suites and
`python/verify_wolfram.py` scripts.
