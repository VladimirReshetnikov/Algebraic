# `algebraic` — the Python package

Exact computation with polynomials and algebraic numbers. Three operations
that were developed as separate top-level modules, in one importable package:

| Module | Operation | Backend |
| --- | --- | --- |
| `algebraic.polynomial_decomposition` | functional decomposition of a polynomial with exact algebraic coefficients, `p = f(g(x))` | SymPy number fields, with python-flint for rational polynomial arithmetic |
| `algebraic.root_decomposition` | an algebraic number as a sum or a product of algebraic numbers of the smallest possible maximum degree | python-flint: Arb ball arithmetic, FLINT factoring, exact `fmpq` linear algebra |
| `algebraic.radicals` | an algebraic number by radicals whenever its Galois group is solvable | the Galois engine of `root_decomposition`, plus SymPy for the low-degree formulas |

The Wolfram Language counterpart is [`../Algebraic.wl`](../Algebraic.wl). It
carries a fourth operation, radical denesting (`Strad`), which has no Python
implementation; that asymmetry is the only difference in scope between the
two packages.

## Install

```bash
python -m pip install -r requirements.txt   # sympy >= 1.14, python-flint >= 0.8
```

or, for an editable install of the package itself, from this directory:

```bash
python -m pip install -e .
```

Without installing, run everything from this directory: `algebraic/` is
directly importable from here.

## Use

```python
import sympy as sp
import algebraic as alg

x = sp.Symbol("x")

# p = f(g(x)) with radical coefficients
h = x**2 + sp.sqrt(2)*x
alg.decompose(h**3 + h, x)
# [x**3 + x, x**2 + sqrt(2)*x]

# a degree-9 algebraic number as a product of two cubics
a = alg.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
alg.product_decomposition(a)
# Decomposition(Times: Root[1 + # + #^3 &, 1] * Root[1 - # + #^3 &, 1];
#               degrees=[3, 3], max=3, lower_bound=3, optimal=True, ...)

# by radicals
alg.root_to_radicals("Root[#^4 - 10 #^2 + 1 &, 4]")
# RadicalResult(sqrt(2*sqrt(6) + 5); method=LowDegree, verified=True, ...)
```

`alg.decompositions`, `alg.decomposition_pairs`, `alg.right_decompose` and
`alg.decomposition_data` give the exhaustive chain enumeration, the pairs, one
fixed inner degree, and the certificates; `alg.sum_decomposition`,
`alg.bounded_decomposition`, `alg.catalog`, `alg.galois_data` and
`alg.lower_bound` are the rest of the second operation; `alg.is_solvable`,
`alg.is_radical_expression` and `alg.radical_depth` the rest of the third.
Everything else stays reachable through the three modules.

Two names mean different things in the two engines and are deliberately not
re-exported at the top level: `verify_numeric` (a decomposition, versus a
radical expression) and `frobenius_cycle_types` (a fixed number of primes,
versus a caller-supplied one). Ask for them through the module —
`root_decomposition.verify_numeric` or `radicals.verify_numeric`.

## Tests

```bash
python -m unittest discover -s tests -t . -v
```

95 tests: 26 for the functional decomposition, 37 for sums and products, 32
for radicals. They take about 20 seconds together.

## Checking the answers in a Wolfram kernel

```bash
python verify_wolfram.py                     # all three groups
python verify_wolfram.py --group radicals
python verify_wolfram.py --emit check.wl     # write the script, do not run it
```

40 cases. The *polynomial* group loads `../Algebraic.wl` and compares Python's
complete chains, chain sets, pairs and certificates with the package's own,
and feeds Python's certificates to the package's independent certificate
checker; the Wolfram side recomposes every chain itself with polynomial
substitution and exact `RootReduce`. The *decomposition* and *radicals* groups
load no package at all: they check with `RootReduce` and `MinimalPolynomial`
directly, so they are independent of the Wolfram implementation of the same
algorithm. Root indices are never exchanged — the two systems number non-real
roots differently — so a radical expression is identified with its conjugate
numerically at 60 digits against the value Python computed.

This merges the three cross-language scripts the separate projects carried,
and with them the three copies of the kernel harness that had drifted apart:
one searched `PATH` only, one also fell back to a hard-coded Wolfram 15 path,
one captured the kernel's output and the others did not.

## Benchmarks

```bash
python benchmark.py                 # the standard set
python benchmark.py --full          # add the expensive searches
python benchmark.py --group radicals
```

Input construction and the exact verification of each returned identity are
outside the timed call.

`../../benchmarks/compare_solvers.py` is a separate, older harness that
compares the *pre-merge* modules against a pinned Git revision; it reads them
from the four project directories, which the merge left in place.

## What the merge changed

The three modules are the ones from `polynomial-decompose/python/`,
`root-decomposition/python/` and `root-to-radicals/python/`. Beyond the move:

* the radical descent reached its Galois engine by inserting a sibling
  directory into `sys.path` and importing `rootdecomp`; it is now an ordinary
  `from . import root_decomposition` inside one package;
* `roottoradicals.py` became `radicals.py`, so that the module name and the
  `root_to_radicals` function it exports no longer collide in the package
  namespace;
* the command-line demonstrations at the bottom of two modules moved out of
  the importable modules and into `benchmark.py`;
* the three test suites and the three Wolfram cross-checks became one of each.

No algorithm changed, and the Python answers are still compared against a
Wolfram kernel case by case.
