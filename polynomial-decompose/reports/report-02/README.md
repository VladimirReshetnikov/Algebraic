# AlgebraicDecomposition 1.0.0

Exact functional decomposition of univariate polynomials with algebraic
coefficients, including radicals, polynomial `Root` objects, and
`AlgebraicNumber` values. The characteristic-zero algorithm uses leading
coefficients and exact residuals, not derivative factorization.

**Validation status:** the independent Python/SymPy exact-field validation
passed. The Wolfram connector returned HTTP 404 and no local Wolfram kernel
was available, so the 53 supplied Wolfram tests have **not** been executed
in a Wolfram kernel here. Run them before relying on the package in production.
Source review and the lexical checker are not a substitute for kernel tests.

## Contents

- `article/algebraic-decomposition.pdf`: comprehensive mathematical article.
- `article/algebraic-decomposition.tex`: editable LaTeX source; its source
  appendix reads the distributed kernel file directly.
- `Kernel/AlgebraicDecomposition.wl`: complete standalone package implementation.
- `AlgebraicDecomposition.wl`: convenience loader (keep `Kernel/` alongside it).
- `Examples/Examples.wl`: runnable examples.
- `Tests/AlgebraicDecomposition.wlt`: 53 Wolfram test specifications, including
  one test covering 12 generated radical composites.
- `Tests/RunTests.wls`: command-line test runner; fails closed unless all tests
  succeed and exactly 53 tests are observed.
- `validation/`: independent exact-field reference code, executed reports,
  lexical checker, and detailed validation limitations.

## Load the package

Use an absolute path after extracting the archive:

```wolfram
Get["/path/to/algebraic-polynomial-decomposition/AlgebraicDecomposition.wl"];
Clear[x];
```

Alternatively load `Kernel/AlgebraicDecomposition.wl` directly. No third-party
Wolfram packages are required. A supported kernel-version matrix has not yet
been established by execution; the code uses standard exact algebraic-number,
association, and polynomial operations.

## Example

```wolfram
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
    (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
    (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[p, x];
VerifyAlgebraicDecomposition[p, chain, x]
```

The mathematically expected chain, independently checked in the Python
validation, is algebraically equivalent to:

```wolfram
{3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
   (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3,
 x^2 + x/Sqrt[2]}
```

Lists are **outermost first**. Every factor except the first is monic with
constant term zero. This accounts for the harmless scaling difference from
the motivating StackExchange answer.

A quintic algebraic coefficient is handled without conversion to radicals:

```wolfram
a = Root[#^5 - # - 1 &, 1];
g = (1 + a) x^2 + a^2 x + Sqrt[3];
h = x^3 + a x;
AlgebraicDecompose[Expand[g /. x -> h], x]
```

## Public API

| Function | Result |
|---|---|
| `AlgebraicDecompose[p,x]` | One complete normalized chain. |
| `AlgebraicDecompositions[p,x]` | All complete normalized chains, modulo affine insertions. |
| `AlgebraicRightDecompositions[p,x]` | All proper pairs `{g,h}`, with normalized `h`; neither factor is necessarily indecomposable. |
| `AlgebraicDecompositionAttempt[p,x,d]` | Candidate, outer polynomial, exact residual, and rejection witness for a proper divisor `d`. |
| `ComposeAlgebraicPolynomials[chain,x]` | Exact composition of a nonempty list. |
| `VerifyAlgebraicDecomposition[p,chain,x]` | Exact identity, normalization, indecomposability, and convention checks. |

The enumeration option `"MaxDecompositions"` defaults to `1000`. Set it to a
positive integer or `Infinity`. Exceeding the limit returns
`Failure["EnumerationLimit", ...]` with `"Complete" -> False` and
`"PartialDecompositions"`; partial output is never presented as exhaustive.
This is an output limit, not a guaranteed running-time or memory limit.

The verifier's `"ValidCompleteDecomposition"` checks a complete nonlinear
identity but does not require normalization. The separate `"Normalized"`
property records that condition. Constants and linear inputs use a singleton
convention, checked with `"ValidConstantOrLinearConvention"`.

## Input and failure policy

The variable must evaluate to an unassigned symbol. Coefficients must be exact
algebraic values recognized by the kernel. Algebraic coefficient reduction
precedes the degree calculation. Real and complex approximate numbers, free
parameters, transcendental coefficients, and rational functions are rejected
with `Failure`, not silently reported as indecomposable.

A valid unsuccessful fixed-degree attempt is not a `Failure`: it returns
`"Decomposable" -> False` and a nonzero exact residual. An empty proper-pair
list proves absolute indecomposability only for input degree at least two.
Ordinary Wolfram evaluation happens before the function receives its input.
External aborts and resource exhaustion are not mathematical certificates.

## Why the algorithm is complete

For `n = m d`, a normalized right component of degree `d` is forced by the
coefficients of degrees `n-1,...,n-d+1`. It is the strictly positive-power
part of the formal Laurent root `(p/lc(p))^(1/m)` whose leading term is `x^d`.
The package computes it by an exact recurrence, then recovers the unique
possible outer polynomial by descending coefficient subtraction. The residual
vanishes exactly when this degree succeeds. Testing all proper divisors is
therefore exhaustive. All coefficients remain in the original coefficient
field. The article supplies complete proofs, field-descent and poset results,
explicit quartic and sextic criteria, and a review of the derivative method.

## Execute the tests

From the extracted directory:

```sh
wolframscript -file Tests/RunTests.wls
```

Or use `TestReport["/absolute/path/Tests/AlgebraicDecomposition.wlt"]` in a
Wolfram session. The runner writes `Tests/LastTestReport.wxf`; no such native
pass report is included in this release because the suite was not run here.

Independent validation (requires Python and SymPy; executed with Python
3.13.5 and SymPy 1.14.0):

```sh
python validation/reference_validation.py
python validation/check_wl_structure.py
```

See `validation/VALIDATION.md` for counts, scope, and limitations. These scripts
do not execute the Wolfram package.

## Rebuild the article

Keep the archive layout intact, then:

```sh
cd article
latexmk -pdf -interaction=nonstopmode -halt-on-error algebraic-decomposition.tex
```

The included Makefile also provides `make pdf`, `make validate`, and
`make wolfram-tests` from the archive root.

## Scope and provenance

This implements exact univariate characteristic-zero polynomial composition.
It does not implement finite-characteristic, symbolic-parameter, approximate,
rational-function, multivariate, or ring-of-integers constrained decomposition.
A fixed primitive-element backend and a poset-based enumerator are discussed
as future optimizations, not advertised as implemented options.

The mathematical ideas are classical; see the article's references to
Kozen–Landau, von zur Gathen, Giesbrecht, Zieve–Müller, and Wyman–Zieve. This is
an original reference implementation and exposition, not an official Wolfram
Research package. It does not call the built-in `Decompose`.
