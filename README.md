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
The root-to-radicals project expresses solvable algebraic numbers in radicals
using structural family recognizers and Galois descent. The radical-denest
project removes nested root extractions -- `Sqrt[5 + 2 √6]` becomes
`√2 + √3` -- by reviewing, correcting and certifying an existing
Wolfram program through three rounds of code review, with a survey of the
denesting literature alongside.

## The unified package

The four operations are also one package: `algebraic/Algebraic.wl` (one
Wolfram Language context, ``Algebraic`​``, in one self-contained file, running
in the Wolfram kernel and in [Mathics3](https://mathics.org/)) and
`algebraic/python/` (one importable Python package with three modules; the
denester has no Python implementation). The projects below are the sources
it was merged from, kept with their articles, reports and validation
records; [`algebraic/README.md`](algebraic/README.md) says what the merge
changed and exactly what Mathics can and cannot run.

```wolfram
Get["algebraic/Algebraic.wl"];
AlgebraicDecompose[(x^2 + √2 x)^3 + x^2 + √2 x, x]      (* {x + x^3, √2 x + x^2} *)
RootProductDecomposition[Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]]["Expression"]
RootToRadicals[Root[#^4 - 10 #^2 + 1 &, 4]]                        (* Sqrt[5 + 2 √6] *)
DenestRadicals[Sqrt[5 + 2 √6]]                                        (* √2 + √3 *)
```

```python
import sympy as sp, algebraic as alg
x = sp.Symbol("x")
alg.decompose((x**2 + sp.sqrt(2)*x)**3 + x**2 + sp.sqrt(2)*x, x)  # [x**3 + x, x**2 + sqrt(2)*x]
alg.product_decomposition(alg.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]"))
alg.root_to_radicals("Root[#^4 - 10 #^2 + 1 &, 4]")
```

## Layout

| Path | Contents |
| --- | --- |
| `algebraic/Algebraic.wl` | The unified Wolfram package: all four operations, one context, Wolfram kernel and Mathics3. `Tests/Algebraic.wlt` (493 tests) with a runner for both kernels, `Examples.wl`, and `AlgebraicKernelReport[]`. |
| `algebraic/python/` | The unified Python package `algebraic` (`polynomial_decomposition`, `root_decomposition`, `radicals`), 95 tests, a 40-case cross-check against a Wolfram kernel, and a benchmark. |
| `docs/mathematica.stackexchange.com/` | Archived questions and their answers (`.md`, `.tex`, `.pdf`, `.url`). |
| `docs/report/` | radical-denest: *Radical Denesting: A Unified Research Guide* (48 pages, 103 annotated bibliography entries), with `verify.py` and its 59 exact SymPy checks of the identities used. |
| `docs/literature/` | radical-denest: the freely available sources cited by the guide -- 102 assets (54 PDFs, 49 TeX sources) covering 66 works, indexed by `download_manifest.json` (per-file SHA-256, origin URL, retrieval method), with six re-typeset scans and 26 assets that could not be retrieved. |
| `docs/scripts/` | radical-denest: the three download packages that were compared, the one selected and corrected to produce `docs/literature/`, and the record of both download passes. |
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
| `root-to-radicals/` | Radical expressions: Wolfram and Python implementations, native and Python tests, independent cross-language checks, and the accompanying article. |
| `radical-denest/` | Radical denesting: the program under review, its three corrected versions, and three rounds of code review with kernel experiments. |
| `radical-denest/original/DenestRadicals.wl`, `radical-denest/corrected/` | The 585-line program under review, and `DenestRadicalsFixed.wl`, `DenestRadicalsFixed2.wl`, `StradFixed3.wl` in separate contexts, with `KNOWN_GAPS.md` and a usage README. |
| `radical-denest/code-review/unified-A` … `unified-C` | Three rounds of unified analysis (62, 34 and 41 pages, TeX and PDF): catalogued defects with kernel evidence, the design of each corrected version, harnesses, logs, generated tables, and regression suites of 144 and 230 tests. |
| `radical-denest/code-review/review-7` … `review-9` | Three independent reviews of `DenestRadicalsFixed2.wl` at a pinned commit, each with a report, a proposed `StradFixed3.wl`, a native test suite and executed SymPy checks. |
| `radical-denest/README.md` | The program, what each round of review found and fixed, the literature survey, and the build requirements. |
| `benchmarks/` | Reproducible comparisons of all three Python solvers against an immutable Git revision, with exact output checks and raw timing samples. |
| `WOLFRAM-NOTES.md`, `MATHICS-NOTES.md` | Subtle Wolfram Language and [Mathics3](https://mathics.org/) behaviour discovered while developing and running the code, and the portability differences between the two kernels. |
| `LICENSE`, `polynomial-decompose/LICENSE` | MIT-0 for the original project and for radical-denest; MIT for polynomial-decompose, retaining its report 3 source notice. Original reports and reviews retain their own licenses, and the sources under `docs/literature/` remain under the terms of their publishers. |

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
AlgebraicDecompose[(x^2 + √2 x)^3 + x^2 + √2 x, x]
(* {x^3+x, x^2+√2 x} *)
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

## Denesting radicals

`DenestRadicals` rewrites an exact algebraic expression with fewer nested root
extractions and certifies every rewrite against its input by exact algebra;
an expression it cannot improve comes back unchanged.

```wolfram
Get["radical-denest/corrected/StradFixed3.wl"];
DenestRadicals[Sqrt[5 + 2 √6]]          (* √2 + √3 *)
DenestRadicals[(239 + 169 √2)^(1/7)]    (* 1 + √2 *)
DenestReport[Sqrt[5 + 2 √6]]   (* result, status, limits, statistics, certificates *)
```

`wolframscript -file radical-denest/code-review/unified-C/tests/run_tests.wls`
runs the 230-test regression suite of the current version. The three rounds of
review, with their harnesses and logs, are in `radical-denest/code-review/`;
the mathematics and the literature are in
[`docs/report/radical_denesting_unified.pdf`](docs/report/radical_denesting_unified.pdf)
with the cited sources themselves under `docs/literature/`. See
[`radical-denest/README.md`](radical-denest/README.md) for what each round
found and fixed.

## Merged history

`radical-denest/` and the `docs/report/`, `docs/literature/` and `docs/scripts/`
subtrees come from a separate repository,
[RadicalDenest](https://github.com/VladimirReshetnikov/RadicalDenest), merged
here with its full history: 27 commits with their original hashes, so the
commits and blob hashes cited by the review articles still resolve. The merge
moved `src/` to `radical-denest/` and left `docs/` where it was.

Neither `git log --follow` nor the default history simplification crosses a
merge commit, so the pre-merge history of a moved file is reached through its
old path with `--full-history`:

```
git log --full-history -- src/corrected/StradFixed3.wl
git log --full-history -- src/code-review/unified-B
```

Paths that did not move need nothing special (`git log -- docs/report/`).

The review artifacts name the upstream `src/...` paths deliberately: the
`SOURCE_MANIFEST.json` files, the `article.tex` citations of
`github.com/VladimirReshetnikov/RadicalDenest/tree/<sha>/src/...` and the
pinned copies of reviewed sources record what was reviewed at a pinned commit,
and rewriting them would falsify that record.

