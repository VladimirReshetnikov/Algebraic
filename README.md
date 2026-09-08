# Algebraic

Exact computations with algebraic numbers, organised around concrete
questions.  The first project in the repository answers the Mathematica
StackExchange question
[*Factor a polynomial Root into Roots of smallest possible degree*](https://mathematica.stackexchange.com/q/105933/7288):
given a `Root` object, write it as a sum or a product of `Root` objects whose
largest degree is as small as possible.

## Layout

| Path | Contents |
| --- | --- |
| `docs/mathematica.stackexchange.com/` | Archived copy of the question and its answers (`.md`, `.tex`, `.pdf`, `.url`). |
| `root-decomposition/` | The project: theory, implementations, tests and the nine source reports. |
| `root-decomposition/article/` | The unified article `root-decomposition.tex` / `.pdf`: complete theory with proofs, the algorithms, examples and a comparison of the nine reports. |
| `root-decomposition/RootDecomposition.wl` | Wolfram Language package: `RootSumDecomposition`, `RootProductDecomposition`, `RootGaloisData`, lower bounds, bounded search, verification. |
| `root-decomposition/RootDecomposition.wlt`, `RunTests.wl`, `Examples.wl` | Native regression tests (executed in Wolfram 15.0.1), a script runner and worked examples. |
| `root-decomposition/python/` | `rootdecomp.py`, an independent Python port built on python-flint (Arb ball arithmetic, FLINT factoring, exact rational linear algebra), with `test_rootdecomp.py` and a benchmark. |
| `root-decomposition/reports/report-01` … `report-09` | The nine original technical reports (article source, PDF, their own Wolfram packages, tests and SymPy verification scripts), unpacked verbatim. |
| `root-decomposition/README.md` | Usage of the package, the Python port, and a summary of results. |
| `WOLFRAM-NOTES.md` | Subtle Wolfram Language behaviour discovered while developing and running the code. |
| `LICENSE` | MIT-0. |

## The problem in one paragraph

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
