# AlgebraicDecomposition 1.0.0

Exact functional decomposition of univariate polynomials with algebraic coefficients, including radicals, constant polynomial `Root` objects, and `AlgebraicNumber` values. Components are returned **outermost first**. The algorithm is factorization-free and does not modify the built-in `Decompose`.

## Contents

- `article/article.pdf` and `article/article.tex`: mathematical theory, proofs, algorithms, worked examples, API, implementation discussion, and validation record.
- `Kernel/AlgebraicDecomposition.wl`: self-contained Wolfram Language package.
- `Kernel/init.m`, `PacletInfo.wl`: optional package/paclet metadata.
- `Examples/Examples.wl`: worked usage examples.
- `Tests/AlgebraicDecomposition.wlt`: 107 native MUnit tests.
- `Tests/RunTests.wls`: fresh-kernel test runner.
- `Reference/exact_decomposition.py`: independently implemented exact Python reference using SymPy coefficient domains.
- `validation/`: reproducible reference checks, recorded results, test generator, lexical checks, and the limitations of validation.

## Quick start

Extract the archive. In a fresh Wolfram Language kernel, set `base` to the extracted `AlgebraicDecomposition` directory, using a normal local path:

```wl
base = "C:/path/to/AlgebraicDecomposition";
Get[FileNameJoin[{base, "Kernel", "AlgebraicDecomposition.wl"}]];
Clear[x];

p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
    (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
    (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;

chain = AlgebraicDecompose[p, x];
AlgebraicVerifyDecomposition[p, chain, x,
    "RequireComplete" -> True, "RequireNormalized" -> True]
```

The mathematically expected chain (verified by the independent exact reference implementation) is

```wl
{3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
   (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3,
 x^2 + x/Sqrt[2]}
```

The different scaling from the question is deliberate: every inner component is **monic and zero at zero**. The original normalization is recovered by

```wl
{chain[[1]] /. x -> x/Sqrt[2], Sqrt[2] chain[[2]]}
```

An algebraic number not expressed in radicals works in the same way:

```wl
alpha = Root[#^5 - # - 1 &, 1];
p = Expand[(x^2 + alpha x)^3 + alpha (x^2 + alpha x) + 1];
AlgebraicDecompose[p, x]
(* Expected: {x^3 + alpha x + 1, x^2 + alpha x} *)
```

## API

```wl
AlgebraicDecompose[p, x, "DegreeOrder" -> "Ascending"]
AlgebraicDecomposeAtDegree[p, x, d]
AlgebraicRightComponents[p, x]
AlgebraicDecomposeAll[p, x, "MaxDecompositions" -> Infinity]
AlgebraicDecompositionReport[p, x]
AlgebraicCompose[chain, x]
AlgebraicVerifyDecomposition[p, chain, x,
    "RequireComplete" -> False, "RequireNormalized" -> False]
```

`AlgebraicDecomposeAtDegree` returns `{f,h}`, `Missing["NotDecomposableAtDegree",d]` for a valid but unsuccessful degree, or `Failure[...]` for invalid input. A valid nontrivial right degree is a proper divisor of the input degree, greater than one.

`AlgebraicDecomposeAll` returns an association with `"Decompositions"`, `"EnumerationComplete"`, and `"ReturnedCount"`. A cap does not silently imply completeness. The enumerator looks for one extra distinct chain before declaring truncation. The cap limits output, not all intermediate work.

`AlgebraicDecompositionReport` tests all proper degree divisors. Each unsuccessful trial includes a normalized candidate and its first nonconstant h-adic remainder, an exact obstruction. This record is not a formal proof-assistant certificate.

Constants and linear polynomials use the terminal convention `{p}`. Empty composition is the identity: `AlgebraicCompose[{},x]` returns `x`. No affine identity factors are inserted into complete chains.

## Mathematical basis

Let `n = Degree[p]`, `d | n`, `1 < d < n`, and `m = n/d`. Set

`C(t) = t^n p(1/t)/LeadingCoefficient[p]`.

The only possible monic, zero-constant right component of degree `d` is

`h(x) = x^d + b1 x^(d-1) + ... + b_(d-1) x`,

where `1+b1 t+...` is the formal power series `C(t)^(1/m)` truncated modulo `t^d`. A quadratic-cost recurrence computes these coefficients without taking a numerical root or adjoining new algebraic numbers. Repeated monic polynomial division then decides whether `p` belongs to `K[h]`. In characteristic zero, normalized components automatically lie in the coefficient field of `p`, even when a decomposition was originally considered over a larger field.

## Supported domain and arithmetic

The input must evaluate to a univariate polynomial with exact algebraic-number coefficients. The variable must be an unassigned, nonnumeric symbol. Machine-precision and arbitrary-precision real coefficients are rejected; no rationalization is performed. Symbolic coefficient parameters and transcendental constants are outside this implementation's input domain. Selected complex algebraic values are supported. Radical branch choices are preserved; `PowerExpand` is not used.

Coefficients are reduced with `RootReduce`, with an integer/rational fast path. Zero testing is exact. There is no `Extension` option because no factorization field needs to be chosen. An explicit common primitive-element backend is discussed in the article but is not implemented in this release.

## Validation status — important

**574 independent exact reference checks passed, with 0 failures**, using Python 3.13.5 and SymPy 1.14.0. Six Wolfram source/test files also passed lexical delimiter/comment/string checks. **The 107 native MUnit tests have not been executed in a Wolfram kernel.** The available Wolfram connector returned HTTP 404, and no local Wolfram kernel was available. The package targets Wolfram Language 13.0 or later; that version compatibility is a target, not a tested guarantee.

The reference implementation validates the mathematics and expected results, not Wolfram evaluation semantics. See `validation/STATUS.md`. An observed incompleteness in the installed SymPy decomposition oracle is documented separately in `validation/ORACLE_NOTE.md`; the main tests do not treat that oracle as authoritative.

Run native tests in a new process:

```text
wolframscript -file Tests/RunTests.wls
```

Or after loading the package in a fresh notebook kernel:

```wl
TestReport[FileNameJoin[{base, "Tests", "AlgebraicDecomposition.wlt"}]]
```

Run the independent tests (requires Python 3.10+ and SymPy; the recorded run used the versions above):

```text
python validation/run_reference_tests.py
python validation/wl_static_check.py
```

Build the article (TeX Live with the packages named in the preamble):

```text
cd article
latexmk -pdf -interaction=nonstopmode -halt-on-error article.tex
```

## License

The original code, tests, reference implementation, and exposition are provided under MIT-0; see `LICENSE.txt`. References retain their own copyrights. No third-party papers or font files are included.
