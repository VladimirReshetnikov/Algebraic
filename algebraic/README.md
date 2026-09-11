# Algebraic — the unified package

One Wolfram Language package, `Algebraic.wl`, and one Python package,
`python/algebraic/`, for four operations on polynomials and algebraic numbers
that were developed as separate projects in this repository:

| Operation | Wolfram | Python | Source project |
| --- | --- | --- | --- |
| functional decomposition of a polynomial with exact algebraic coefficients, `p = f(g(x))` | `AlgebraicDecompose` and seven companions | `algebraic.polynomial_decomposition` | [`polynomial-decompose/`](../polynomial-decompose) |
| an algebraic number as a sum or a product of algebraic numbers of the smallest possible maximum degree | `RootSumDecomposition`, `RootProductDecomposition`, `RootGaloisData`, … | `algebraic.root_decomposition` | [`root-decomposition/`](../root-decomposition) |
| an algebraic number by radicals whenever its Galois group is solvable | `RootToRadicals`, `RootRadicalReport`, `RootSolvableQ` | `algebraic.radicals` | [`root-to-radicals/`](../root-to-radicals) |
| removal of nested root extractions, certified by exact algebra | `Strad`, `DenestReport`, `EqualityStatus`, … | — | [`radical-denest/`](../radical-denest) |

The Wolfram package runs in the Wolfram kernel and in
[Mathics3](https://mathics.org/). The four source projects keep their
articles, their reports and the implementations the merge started from; the
Wolfram package's header and the section banners inside it say which file
each part came from.

## Wolfram Language

```wolfram
Get["algebraic/Algebraic.wl"];

AlgebraicDecompose[(x^2 + Sqrt[2] x)^3 + x^2 + Sqrt[2] x, x]
(* {x + x^3, Sqrt[2] x + x^2} *)

RootProductDecomposition[Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]]["Expression"]
(* Inactive[Times][Root[1 + # + #^3 &, 1], Root[1 - # + #^3 &, 1]] *)

RootToRadicals[Root[#^4 - 10 #^2 + 1 &, 4]]
(* Sqrt[5 + 2 Sqrt[6]] *)

Strad[Sqrt[5 + 2 Sqrt[6]]]
(* Sqrt[2] + Sqrt[3] *)

AlgebraicKernelReport[]
(* which System functions the kernel supplies, which the package had to, and
   which operations that leaves available *)
```

All 28 public symbols keep the names, options and result formats documented
in the four project READMEs: [polynomial decomposition](../polynomial-decompose/README.md),
[sums and products](../root-decomposition/README.md),
[radicals](../root-to-radicals/README.md),
[denesting](../radical-denest/README.md). Two additions:
`$AlgebraicVersion`, and `AlgebraicKernelReport[]`.

Engine-level messages are issued from the package symbol `Algebraic`
(`Algebraic::inexact`, `::notalg`, `::order`, `::group`, `::prec`,
`::verify`); the four messages of `RootToRadicals` stay on that symbol.

### What the merge changed

It is one context, `Algebraic``, in one self-contained file — not four
packages loaded side by side:

* `RootToRadicals` used to open sixteen assignments into
  ``RootDecomposition`Private` `` to reach the Galois engine, the exact input
  handling, the Frobenius tests and the shared predicates. The four operations
  now share one private context and the aliases are gone.
* `RadicalExpressionQ` and `RadicalDepth` were defined independently by the
  radical descent and by the denester and had converged on the same
  predicate. The stricter pair, which checks the arity of a `Power` node and
  treats `Root` and `AlgebraicNumber` as opaque, is the one kept (section 5 of
  the file).
* `rationalQ` and `positiveIntegerQ` were defined three times, identically;
  `rationalRoots` meant two different things and the one that takes m-th
  roots of a rational is now `rationalMthRoots`.
* The functional decomposition of section 1 is what the radical descent
  recurses through, and on a kernel without `Decompose` it is what supplies
  that operation.
* `Return[expr, Module]` and `Return[expr]` inside `While`, which mean
  something else in Mathics, became tagged throws; `list[[-1]] = v` became a
  positive index; `MinimalBy` over `Norm` became the same minimisation over
  the exact squared norm. Each is correct in both kernels; the
  [Wolfram notes](../WOLFRAM-NOTES.md#findings-from-merging-the-four-packages-into-algebraicalgebraicwl-wolfram-1501-september-2026)
  record why.

### Mathics3

The package confines portability to one layer, section 0 of the file. Every
name beginning with a lower-case `k` in ``Algebraic`Private` `` stands in
for one System function; the algorithms call only those, and no System
symbol is ever redefined. Whether the kernel supplies a function is decided
by evaluating it once at load time and comparing the answer with the
known-correct one, not by testing `$Version`, so a Mathics release that
implements a function correctly then uses it. On Mathics3 10.0.1 the layer
supplies 34 functions, among them `RootReduce`, `Resultant`, `FactorList`,
`Cyclotomic`, `LatticeReduce`, the association vocabulary, and a minimal
polynomial by elimination (section 0.5a) for expressions the kernel's own
`MinimalPolynomial` cannot finish.

Measured on Mathics3 10.0.1, with Wolfram 15.0.1 giving the same answers:

| | Mathics3 10.0.1 |
| --- | --- |
| `AlgebraicDecompose`, all eight functions | available; the algebraic-coefficient example in 1 s |
| `Strad` and the denesting family | available; `Sqrt[5 + 2 Sqrt[6]]` in 1 s, `(239 + 169 Sqrt[2])^(1/7)` in 1.9 s; the Kummer multipliers that need factorisation over an extension are not tried, the other methods are |
| `EqualityStatus`, `CertifiedEqualQ`, `RadicalCost`, the grammar | available, exact |
| `RootDecompositionLowerBound`, `RootDecompositionVerify`, `RootSolvableQ` | available; the lower bound scans ten primes rather than forty, which leaves it rigorous but not always as sharp |
| `RootToRadicals` | the structural recognizers only: `Root[#^3 - 2 &, 1]` gives `2^(1/3)`, `Root[#^4 - 10 #^2 + 1 &, 4]` gives `Sqrt[5 + 2 Sqrt[6]]` |
| `RootGaloisData`, `RootSumDecomposition`, `RootProductDecomposition`, the Galois-Kummer descent | **not available**: they return `Failure["KernelPrecision", …]` |

The reason for the last row is a property of the interpreter, not of the
package: `N[Root[f, k], p]` in Mathics3 10.0.1 returns a number that carries
precision `p` and reports it through `Precision` and `Accuracy`, but for a
polynomial of degree six it agrees with the root to about eleven digits. The
numerical-resolvent Galois engine rounds traces of such values to integers,
so on that kernel it would round noise into a plausible wrong group. A
load-time probe measures the residual rather than trusting the reported
precision, and where it fails the engine refuses. `AlgebraicKernelReport[]`
says so. Everything in the table was checked case by case against the
Wolfram kernel; [MATHICS-NOTES.md](../MATHICS-NOTES.md) records every
evaluator difference met on the way, several of which produce a plausible
wrong value rather than an error.

Install and run:

```text
python -m venv env
env/Scripts/python -m pip install Mathics3 packaging
env/Scripts/python -X utf8 -m mathics --no-readline -q -f script.m
```

with `$IterationLimit = 1000000;` at the top of the script and `Get` of the
package before any package call.

### Tests

```text
cd algebraic/Tests
wolfram -script RunTests.wl > /dev/null 2>&1; cat wolfram-report.txt
python -X utf8 run_mathics.py
```

In the Wolfram kernel the report goes to `wolfram-report.txt`: `TestReport`
redraws a progress line on standard output continuously, a script cannot
switch it off, and redirected to a file it reached Git Bash's 2 GB limit
and blocked the kernel, so standard output is discarded. `run_mathics.py`
feeds the suite to Mathics one statement at a time -- a Python-level abort
inside one test then ends that test, not the run -- and prints each test ID
as it starts; `python -X utf8 -m mathics --no-readline -q -f RunTests.wl`
also works but prints nothing until it finishes. The Mathics run takes
hours.

`Algebraic.wlt` is the four suites of the four projects — 91, 94, 75 and 230
tests, 490 in all — with their package names mapped onto the unified
package; nothing was removed. In the Wolfram kernel the runner uses
`TestReport`. Mathics has neither `TestReport` nor `VerificationTest`, so the
runner defines its own `VerificationTest` before reading the same file: tests
that expect a Wolfram message are judged on their value only, and a test that
reaches an operation the kernel report marks unavailable counts as
"unavailable" rather than as a failure when it returns the documented
`KernelPrecision` failure. Both counts are printed.

`Examples.wl` reproduces the worked examples of the four projects in one
script.

## Python

See [`python/README.md`](python/README.md). Three modules in one package,
95 tests, a `verify_wolfram.py` that checks 40 Python results in a Wolfram
kernel — the polynomial group against `Algebraic.wl` itself — and a
benchmark script. The denester has no Python implementation; that is the one
difference in scope between the two packages.
