# Algebraic

Exact computations with algebraic numbers, organised around concrete
questions. The root-decomposition project answers the Mathematica
StackExchange question
[*Factor a polynomial Root into Roots of smallest possible degree*](https://mathematica.stackexchange.com/q/105933/7288):
given a `Root` object, write it as a sum or a product of `Root` objects whose
largest degree is as small as possible. The polynomial-decompose project
answers [*Is it possible to make Decompose work with coefficients containing
radicals?*](https://mathematica.stackexchange.com/q/206618/7288): express a
polynomial with exact algebraic coefficients as a composition of
indecomposable polynomials, and enumerate or certify all normalized answers.

## Layout

| Path | Contents |
| --- | --- |
| `docs/mathematica.stackexchange.com/` | Archived questions and their answers (`.md`, `.tex`, `.pdf`, `.url`). |
| `root-decomposition/` | Algebraic-number sums and products: theory, implementations, tests and nine source reports. |
| `root-decomposition/article/` | The unified article `root-decomposition.tex` / `.pdf`: complete theory with proofs, the algorithms, examples and a comparison of the nine reports. |
| `root-decomposition/RootDecomposition.wl` | Wolfram Language package: `RootSumDecomposition`, `RootProductDecomposition`, `RootGaloisData`, lower bounds, bounded search, verification. |
| `root-decomposition/RootDecomposition.wlt`, `RunTests.wl`, `Examples.wl` | Native regression tests (executed in Wolfram 15.0.1), a script runner and worked examples. |
| `root-decomposition/python/` | `rootdecomp.py`, an independent Python port built on python-flint (Arb ball arithmetic, FLINT factoring, exact rational linear algebra), with `test_rootdecomp.py` and a benchmark. |
| `root-decomposition/reports/report-01` … `report-09` | The nine original technical reports (article source, PDF, their own Wolfram packages, tests and SymPy verification scripts), unpacked verbatim. |
| `root-decomposition/README.md` | Usage of the package, the Python port, and a summary of results. |
| `polynomial-decompose/README.md` | Functional polynomial decomposition: usage, algorithm, certificate contracts, and comparison of three source reports. |
| `polynomial-decompose/article/` | Unified article in editable TeX and rendered PDF. |
| `polynomial-decompose/AlgebraicDecomposition.wl` | Native Wolfram package for one/all complete chains, all pairs, fixed-degree attempts, and independent certificate checking. |
| `polynomial-decompose/python/` | Exact Python implementation using SymPy number fields, regression tests, benchmarks, and native Wolfram cross-checks. |
| `polynomial-decompose/reports/` | Three original reports, preserved with their sources, PDFs, code, tests, licenses, and historical validation results. |
| `WOLFRAM-NOTES.md` | Subtle Wolfram Language behaviour discovered while developing and running the code. |
| `LICENSE`, `polynomial-decompose/LICENSE` | MIT-0 for the original project; MIT for polynomial-decompose, retaining its report 3 source notice. Original reports retain their own licenses. |

## Decomposing algebraic numbers

For an algebraic number `a` of degree `n` the quantities

```
D+(a) = min over a = b1 + ... + br  of  max deg(bi)
Dx(a) = min over a = b1 * ... * br  of  max deg(bi)
```

are studied, where the components may be any algebraic numbers.  Sums have
a complete finite algorithm (trace descent to the splitting field, then
rational linear algebra on fixed fields of subgroups of the Galois group).
Products of two factors have a complete algorithm (norm descent with an
explicit radical exponent; optimal factors can lie outside the splitting
field).  Products of arbitrarily many factors are handled by the two-factor
criterion, a rank-one tensor test, recursive splitting, bounded search and
rigorous lower bounds; the implementations do not decide this problem in general.  Both examples of the
question have globally optimal maximum degree 3.

## Quick start

Wolfram Language (from `root-decomposition/`):

```wolfram
Get["RootDecomposition.wl"];
RootProductDecomposition[Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]]["Expression"]
RootSumDecomposition[Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]]["Expression"]
```

Python (from `root-decomposition/python/`; install with
`python -m pip install -r requirements.txt`):

```python
import rootdecomp as rd
a = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
print(rd.product_decomposition(a))
```

Run `python test_rootdecomp.py` for the Python regression suite and
`wolfram -script RunTests.wl` from `root-decomposition/` for the native Wolfram
suite. With a Wolfram kernel on `PATH`, `python verify_wolfram.py` independently
checks representative Python results using exact `RootReduce` and
`MinimalPolynomial` computations.

An explicit degree or component limit is a constraint on the returned answer.
Exhausting a two-factor search certifies the two-factor optimum; it does not
certify the optimum over arbitrarily many factors. See
[`root-decomposition/README.md`](root-decomposition/README.md) for option and
certificate semantics.

## Decomposing polynomials

For `p = f(g(x))`, fixing the degree of a monic inner component `g` with
`g(0) = 0` forces all its coefficients. A formal-root recurrence constructs
that candidate; exact monic division decides whether it works. This avoids
factoring derivatives and works with general algebraic coefficients,
including nonreal numbers and `Root`/`CRootOf` values. Normalized components
remain in the original coefficient field in characteristic zero.

```wolfram
Get["polynomial-decompose/AlgebraicDecomposition.wl"];
AlgebraicDecompose[(x^2 + Sqrt[2] x)^3 + x^2 + Sqrt[2] x, x]
(* {x^3+x, x^2+Sqrt[2] x} *)
```

From `polynomial-decompose/python/`:

```python
import sympy as sp
import algebraic_decompose as ad
x = sp.Symbol("x")
h = x**2 + sp.sqrt(2)*x
print(ad.decompose(h**3 + h, x))
# [x**3 + x, x**2 + sqrt(2)*x]
```

The [project guide](polynomial-decompose/README.md) explains exhaustive chain
enumeration, explicit output-limit failures, positive and negative
certificates, the original radical-coefficient example, and reproducible
validation commands. The [unified article](polynomial-decompose/article/polynomial-decompose.pdf)
proves the algorithm and compares the three reports and the posted
derivative-factorization approach.
