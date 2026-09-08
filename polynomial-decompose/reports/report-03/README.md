# AlgebraicDecomposition 1.0.0

Exact functional decomposition of univariate polynomials with algebraic
coefficients, including radicals, algebraic `Root` objects, `AlgebraicNumber`,
and complex algebraic numbers.

**Validation status:** the accompanying mathematical proofs and independent
Python exact number-field checks are complete. The Wolfram package and its
60 native regression tests have **not been executed in a Wolfram kernel** in
this delivery environment: the available Wolfram evaluator returned HTTP 404
and no local Wolfram kernel was installed. A successful independent check is
not a successful native package test. Run the supplied native suite before
relying on this implementation in production.

## Files

| Path | Purpose |
| --- | --- |
| `article/article.pdf` | Detailed mathematical article, proofs, examples, API, and complete source appendix |
| `article/article.tex` | Standalone LaTeX source; embeds the package listing and bibliography |
| `AlgebraicDecomposition.wl` | Path-relative convenience loader |
| `Kernel/AlgebraicDecomposition.wl` | Complete, self-contained implementation |
| `Kernel/init.m` | Standard application loader for `Needs` |
| `Examples/Examples.wl` | Runnable original, nested, Root, and certificate examples |
| `Tests/AlgebraicDecomposition.wlt` | 60 native `VerificationTest` cases, including 24 seeded cases inside one property test |
| `Tests/RunTests.wl` | Command-line native test runner |
| `Verification/verify_exact.py` | Independent exact number-field implementation and verification |
| `Verification/report.json` | Actual executed independent results, including baseline discrepancies |
| `Verification/check_source.py` | Basic source delimiter/comment/string and packaging checks, not a Wolfram parser |
| `Verification/source_checks.json` | Result of those basic source checks |
| `Verification/README.md` | Precise validation scope and reproducibility information |
| `Verification/requirements.txt` | Pinned Python verification dependency |
| `build.sh` | Rebuild the PDF using pdfLaTeX |
| `SHA256SUMS` | File-integrity manifest |

## Load

Use a fresh kernel and an unassigned variable.

```wl
Get["/absolute/path/AlgebraicDecomposition/AlgebraicDecomposition.wl"]
Clear[x];
AlgebraicDecompose[(x^4 + x)^2, x]
(* Mathematical expectation: {x^2, x^4 + x} *)
```

Alternatively, put the entire `AlgebraicDecomposition` directory under
`$UserBaseDirectory/Applications` and evaluate:

```wl
Needs["AlgebraicDecomposition`"]
```

The core file `Kernel/AlgebraicDecomposition.wl` can also be loaded directly.
The package has no Python dependency and does not require an internet connection.
It targets modern Wolfram kernels with associations, `Failure`, and
`RootReduce`; no minimum-version compatibility claim has been natively tested.

## Main API

All factor lists are **outermost first**. Every component except the first
is normalized to be monic with zero constant term.

```wl
AlgebraicDecompose[p, x]                  (* one complete chain *)
AlgebraicDecompositions[p, x]              (* all normalized complete chains *)
AlgebraicDecompositionPairs[p, x]          (* all normalized nontrivial pairs *)
AlgebraicRightDecompose[p, x, d]           (* pair with specified inner degree *)
AlgebraicDecompositionData[p, x]           (* exhaustive degree certificates *)
AlgebraicDecompositionData[p, x, d]        (* one fixed-degree certificate *)
VerifyAlgebraicDecompositionData[p, data, x]
ComposeDecomposition[parts, x]
VerifyAlgebraicDecomposition[p, parts, x]  (* identity only, not atomicity *)
```

`AlgebraicDecompose` selects the smallest successful right degree at each step.
This guarantees that each stripped right component is indecomposable.
`AlgebraicDecompositions` returns all complete chains modulo intervening affine
changes, not infinitely many affine variants. The enumeration can have large
output. `AlgebraicDecompositionPairs` returns pairs sorted by inner degree.

For a valid proper divisor `d`, an unsuccessful fixed-degree request returns
`Missing["NotDecomposable", d]`. Invalid arguments, unsupported coefficients,
and algebraic arithmetic failures return `Failure`. A valid polynomial of
degree zero or one returns a singleton list by convention; it is not labeled
an indecomposable nonlinear polynomial. The zero polynomial's metadata degree
is `-Infinity`. An empty composition list represents `x`.

The certificate verifier returns `False` for bad certificate data, but
`Failure` for an invalid input polynomial. It does not rerun the candidate
recurrence or the division search. The certificate is exact computer-algebra
evidence, not a formally verified proof-assistant object. Wolfram expressions
are executable; the checker is not a sandbox for hostile input.

## Original example

```wl
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
    (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
    (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[p, x];
VerifyAlgebraicDecomposition[p, chain, x]
```

The mathematically expected normalized chain is

```wl
{3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
   (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3,
 x^2 + x/Sqrt[2]}
```

This composes to the user's polynomial and is affine-equivalent to the pair
in the question. Radical versus `Root` formatting can vary without changing
this exact result. For `p /. x -> x^4 - x + 1`, the complete degree sequence is
`{3, 2, 4}`.

## Algorithm and guarantees

For degree `n = m d`, normalize a proposed inner polynomial `h` to be monic
with `h(0)=0`. The coefficients of degrees `n-1` down to `n-d+1` in
`p/LeadingCoefficient[p]` force all non-leading coefficients of `h`.
A finite formal-root recurrence recovers the candidate in the coefficient
field, without factoring or constructing new algebraic numbers.

Repeated monic division writes `p = Sum[r[j] h^j]` with `Degree[r[j]] < d`.
The candidate works exactly when every digit `r[j]` is constant. A nonconstant
digit coefficient is a negative certificate. Testing every proper divisor
is complete. In characteristic zero, normalized decompositions over any
larger field already lie in the original coefficient field: no `Extension`
search is necessary.

The dense fixed-degree algorithm costs `O(n^2)` field operations; searching
all degrees and one complete chain costs `O(tau(n) n^2)`. These are not
bit-complexity or runtime guarantees. Exact algebraic field degrees and
coefficient heights matter substantially.

## Input and scale limitations

Only explicit exact algebraic coefficients are accepted. Machine and
arbitrary-precision approximations, symbolic parameters, transcendental
coefficients, rational functions, and finite-field calculations are not
supported. The package never silently uses `RootApproximant`, a numerical
zero tolerance, or `PowerExpand`. Algebraic cancellations are reduced before
determining the input degree. Exact expressions not recognized as algebraic
should first be supplied in an explicit algebraic representation.

The implementation uses dense vectors and scalar `RootReduce`. Very high
degrees, large compositum fields, or many complete chains can be expensive.
A common-primitive-element optimized backend is discussed in the article but
is not implemented as an option. `System` symbols are not patched.

## Reproduce the tests

Native Wolfram suite (not yet executed in this delivery):

```sh
wolframscript -file Tests/RunTests.wl
```

Or in a notebook:

```wl
TestReport["/absolute/path/AlgebraicDecomposition/Tests/AlgebraicDecomposition.wlt"]
```

Independent mathematical checks (executed successfully):

```sh
python -m pip install -r Verification/requirements.txt
python Verification/verify_exact.py --output Verification/report.json
python Verification/check_source.py
```

The recorded exact run covered 974 inputs, 2,001 degree tests, and 1,042
complete chains. Of 848 differential comparisons against SymPy 1.14.0,
14 had different degree patterns; the report records examples and the
independently verified decompositions. These comparisons are not counted as
universal baseline agreement. See `Verification/README.md` for details.

## Rebuild the article

```sh
sh build.sh
```

A standard LaTeX installation with pdfLaTeX, Latin Modern, AMS packages,
`listings`, `microtype`, `geometry`, `fancyhdr`, and `hyperref` is sufficient.
No external bibliography or image files are needed. The embedded package
listing must be refreshed when changing the standalone package source;
`Verification/check_source.py` checks that they match.

## Provenance and license

The mathematical foundation is the classical characteristic-zero
factorization-free decomposition method, particularly Kozen--Landau (1989).
The article gives self-contained proofs and primary-source references; it
does not claim invention of this classical algorithm. The derivative-code
audit refers to the 2019 Stack Exchange question supplied by the user and
makes no unverified claim that current `Decompose` is integer-only.

Original code and explanatory material in this bundle are supplied under
the MIT license in `LICENSE`. Third-party articles are cited, not bundled.
