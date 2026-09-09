# Polynomial composition with algebraic coefficients

This project answers [“Is it possible to make Decompose work with coefficients
containing radicals?”](https://mathematica.stackexchange.com/q/206618/7288).
Given an exact polynomial with algebraic coefficients, it finds a complete
functional decomposition

\[
p=f_1\circ f_2\circ\cdots\circ f_r.
\]

Chains are **outermost first**. Every component after the first is monic and
has constant term zero. This removes the arbitrary affine changes between
adjacent components. For a nonlinear input, all returned components have
degree at least two and are indecomposable, even after extending the
coefficient field in characteristic zero. Constants and linear polynomials
return a singleton chain by convention.

The Wolfram Language and Python implementations offer one complete chain,
all complete normalized chains, all normalized two-component decompositions,
and independently checkable certificates for both successful and rejected
candidate degrees. Neither implementation factors the derivative or calls a
built-in polynomial decomposition routine. Construction and normalization of
algebraic coefficient fields can still involve algebraic-number algorithms.

## Files

| Path | Purpose |
| --- | --- |
| [`article/polynomial-decompose.tex`](article/polynomial-decompose.tex), [PDF](article/polynomial-decompose.pdf) | Unified theory, proofs, examples, implementation contracts, and comparison of the three reports. |
| [`AlgebraicDecomposition.wl`](AlgebraicDecomposition.wl) | Native Wolfram package. |
| [`AlgebraicDecomposition.wlt`](AlgebraicDecomposition.wlt), [`RunTests.wl`](RunTests.wl), [`Examples.wl`](Examples.wl) | Native tests, test runner, and worked examples. |
| [`python/algebraic_decompose.py`](python/algebraic_decompose.py) | Exact Python implementation using SymPy number fields, with optional FLINT acceleration for rational polynomial arithmetic. |
| [`python/test_algebraic_decompose.py`](python/test_algebraic_decompose.py), [`python/benchmark.py`](python/benchmark.py) | Python regression and performance checks. |
| [`python/verify_wolfram.py`](python/verify_wolfram.py) | Cross-language checks of complete chains, all pairs, and Python certificates in a native Wolfram kernel. |
| [`reports/README.md`](reports/README.md) | Provenance and directory mapping for the three unchanged source reports. |
| [`LICENSE`](LICENSE) | MIT license, retaining the notice from report 3. The repository's separate root-decomposition project uses the root MIT-0 license. |

## The algorithm

For every proper divisor \(d\) of \(n=\deg p\), write \(n=md\). There is at
most one possible monic right component \(h\) of degree \(d\) with \(h(0)=0\).
Its coefficients are forced by the first \(d\) terms of

\[
\left(\frac{t^n p(1/t)}{\operatorname{lc}(p)}\right)^{1/m}.
\]

A quadratic-cost recurrence computes these terms using exact field
arithmetic and division by positive integers. Repeated monic division then
writes \(p=\sum_j r_j(x)h(x)^j\), with \(\deg r_j<d\). The decomposition
exists exactly when every digit \(r_j\) is constant. A nonconstant digit is
an exact obstruction for that degree.

Ordinary searches stop at the first nonconstant digit; certificate generation
retains every digit. The independent checker verifies the leading-coefficient
congruence that forces \(h\), the full digit reconstruction, and the stated
obstruction. It does not rerun candidate construction or polynomial division.
For a monomial inner component \(h=x^d\), consecutive coefficient chunks are
the base digits, so searches can stop without computing polynomial quotients.
For a positive certificate, full digit reconstruction already proves a zero
residual; the verifier still checks the supplied residual, without composing
the outer polynomial again.
A truncated binary power checks the congruence without constructing all of
\(h^m\). Composition and certificate reconstruction share exact arithmetic.
Wolfram reconstructs nonoverlapping digits in base \(x^d\) by padding and joining
their coefficient blocks, and uses Horner arithmetic for other bases or overlapping
digits. Python also uses FLINT's native polynomial composition over the rationals
when available, with the same exact-domain fallback used by the tests.
Wolfram coefficient products use exact zero-padded convolution. Integer and
rational scalars return directly from normalization; other scalars retain the
exact algebraic reduction and validation path.
Existing Python `Poly` inputs reuse their coefficient field and coefficient vectors;
mixed-input verification reads their coefficients directly. Preparation and the
coefficient reader share the check for a matching generator over the integers,
rationals, or an exact algebraic field. These domains need no expression-wide
floating-point scan; other domains retain the original validation. Expression inputs
try coefficient collection without expansion first and expand only when needed.
The independent verifier shares exact conversions across its degree tests.
Scalar certificate digits skip polynomial parsing while retaining exact field
validation. Exhaustive Wolfram records share a metadata formatter only after
the verifier has independently checked all required degree tests.
A full indecomposability certificate must cover every proper divisor, including
the rejected ones.

For one chain, the smallest successful right degree is already indecomposable,
so only the outer factor needs further decomposition. Enumeration explores all
indecomposable right factors and shares intermediate results within each call.
It returns every normalized chain, including the distinct power and Chebyshev
degree orders described by Ritt's theory.

The dense fixed-degree test uses \(O(n^2)\) coefficient-field operations; this
is not a bit-complexity or wall-clock bound. Algebraic field degree, coefficient
size, and the number of output chains can dominate runtime.

## Wolfram Language

From this directory:

```wolfram
Get["AlgebraicDecomposition.wl"];
Clear[x];
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x + (12 + 26 Sqrt[2]) x^2
  + (56 + 8 Sqrt[2]) x^3 + (8 + 48 Sqrt[2]) x^4
  + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[p, x]
(* {3+3 Sqrt[2]+(8+14 Sqrt[2]) x+(8+24 Sqrt[2]) x^2+16 Sqrt[2] x^3,
     x^2+x/Sqrt[2]} *)

VerifyAlgebraicDecomposition[p, chain, x,
  "RequireComplete" -> True, "RequireNormalized" -> True]
(* True *)

Exponent[#, x]& /@ AlgebraicDecompose[p /. x -> x^4-x+1, x]
(* {3, 2, 4} *)

data = AlgebraicDecompositionData[p, x];
VerifyAlgebraicDecompositionData[p, data, x]
(* True *)
```

The chain in the original question uses a different affine normalization.
Replace the first component's variable by `x/Sqrt[2]` and multiply the second
component by `Sqrt[2]` to recover that form without changing their composition.

| Function | Result |
| --- | --- |
| `AlgebraicDecompose[p,x]` | One complete chain. |
| `AlgebraicDecompositions[p,x]` | All complete normalized chains. |
| `AlgebraicDecompositionPairs[p,x]` | All nontrivial `{outer,inner}` pairs in increasing inner degree. |
| `AlgebraicRightDecompose[p,x,d]` | The degree-`d` pair, or `Missing["NotDecomposable",d]`. Invalid degrees return `Failure`. |
| `AlgebraicDecompositionData[p,x,d]` | A full positive or negative degree certificate. Omit `d` for an exhaustive record. |
| `VerifyAlgebraicDecompositionData[p,data,x]` | Independent certificate validation. |
| `ComposeDecomposition[parts,x]` | Exact composition; an empty list represents `x`. |
| `VerifyAlgebraicDecomposition[p,parts,x]` | Exact identity check; use `"RequireComplete"` and `"RequireNormalized"` for the stronger contracts. |

`AlgebraicDecompositions` accepts `"MaxDecompositions" -> M`, default
`Infinity`. If more than `M` chains exist, it returns
`Failure["EnumerationLimit", ...]` containing `"PartialDecompositions"`,
`"Limit"`, and `"Complete" -> False`. Exactly `M` chains still returns a
complete list: the search looks for one additional chain before declaring
truncation. The limit bounds output, not time or arithmetic memory.

## Python

From `python/`, install the requirements and import the module:

```powershell
python -m pip install -r requirements.txt
```

```python
import sympy as sp
import algebraic_decompose as ad

x = sp.Symbol("x")
s = sp.sqrt(2)
h = x**2 + x/s
f = 3+3*s + (8+14*s)*x + (8+24*s)*x**2 + 16*s*x**3
p = sp.expand(f.subs(x, h))
chain = ad.decompose(p, x)
assert ad.verify_decomposition(p, chain, x,
    require_complete=True, require_normalized=True)
assert ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x)

# Every normalized complete chain; here the degree orders are
# (2,2,3), (2,3,2), and (3,2,2).
chains = ad.decompositions(x**12, x)

# An independently verifiable rejected degree.
h = x**2+x
q = h**3+x*h
certificate = ad.decomposition_data(q, x, 2)
assert certificate["decomposable"] is False
assert certificate["digits"] == [0, x, 0, 1]
assert ad.verify_decomposition_data(q, certificate, x)
```

The API names are `decompose`, `decompositions`, `decomposition_pairs`,
`right_decompose`, `decomposition_data`, `verify_decomposition_data`, `compose`,
and `verify_decomposition`. Arguments correspond to the Wolfram table, with
`snake_case` certificate keys. `right_decompose(p,x,d)` returns `None` on a
valid unsuccessful trial; invalid input or an invalid degree raises
`ValueError`. Constants and linear polynomials have
`"indecomposable": None`, since the nonlinear terminology does not apply.

Use `decompositions(p,x,max_chains=M)` for a finite output cap. When more than
`M` chains exist, `EnumerationLimitError` carries `partial_chains`, `limit`,
and `complete=False`; an ordinary returned list is always exhaustive.

Both implementations accept rational, real algebraic, and complex algebraic
coefficients, including general `Root`/`CRootOf` values. Algebraic identities
are reduced before determining the degree, so a leading coefficient that is
exactly zero cannot produce a spurious degree. Approximate coefficients,
free coefficient parameters, transcendental constants, and nonpolynomial
inputs are rejected. Python also rejects finite-characteristic `Poly`
objects. No numerical tolerance or silent rationalization is used.

## Report comparison and validation

The reports share the unique-candidate theorem and exact coefficient-field
descent. Their main differences are implementation and certificates:

| Source | Contribution adopted | Issue found in the original native package |
| --- | --- | --- |
| Report 1 | Direct coefficient-vector Python reference, bounded enumeration with explicit incompleteness, broad examples. | `Return` inside `Do` breaks complete-chain control flow; native test failures despite passing Python reference checks. |
| Report 2 | Structural order of right components; a useful alternative descending-pivot residual certificate. | `Return` inside `Do` prevents `firstSplit` from returning its successful result; native decomposition and verification tests fail. |
| Report 3 | Full polynomial-base digit certificates and an independent verifier; reliable native starting point. | Original all-chain enumeration has no cap and ordinary rejection computes unnecessary remaining digits. |

The live certificate schema uses **report 3's h-adic digits** throughout.
Report 2's outer candidate and residual can differ on rejected inputs, even
though both schemes are mathematically valid. Mixing those records would
invalidate a checker. The article also examines the derivative-factorization
answer, including its power-polynomial rejection and erroneous exponent
addition when composing monomials.

On 7 September 2026, all three archived Python validators were rerun on
temporary copies with Python 3.14.4 and SymPy 1.14.0. All passed: report 1
ran 574 checks; report 2 checked 144 generated composites and 348 candidate
residuals, among other cases; report 3 checked 974 polynomials, 2,001 candidate
degrees, and 1,042 complete chains. Report 3 also recorded 14 degree-pattern
disagreements with SymPy's built-in decomposition; that routine is not used
as a completeness oracle.

The unchanged archived native suites were independently executed with
Wolfram 15.0.1: report 1 passed **55/107**, report 2 **39/53**, and report 3
**60/60**. These results concern the original reports, whose historical
metadata remains unchanged. The unified project has its own regression
suites: **90/90 native tests** and **25 Python test methods** passed. The
Python methods include 12 generated affine-normalization cases across exact
fields and degree pairs, in addition to boundary, enumeration, and certificate
tampering checks. They also exercise truncated congruences, early rejection,
full certificate digits, 256 convolution products, and the Python fallback
without native acceleration. Typed certificate caches keep approximate and
Boolean values distinct from equal exact coefficients.
The native APIs and certificate verifier share an exact proper-degree check;
pattern-valued certificate degrees are rejected without running their predicates.
Native digit reconstruction matches independent symbolic arithmetic in 49 cases,
including empty digits, zero and constant bases, overlapping digits, and exact
algebraic coefficients.
Enumeration tests check that symbolic conversion caches release their field
engines and keep each call's polynomial variable separate.
All **15 cross-language corpus cases** passed as well.
Reproduce these checks with:

```powershell
# From polynomial-decompose/:
wolfram -script RunTests.wl
wolfram -script Examples.wl

# From polynomial-decompose/python/:
python -m unittest -v test_algebraic_decompose
python verify_wolfram.py
python benchmark.py --full --compare-report01
```

The cross-language corpus includes the question's sextic and nested example,
powers, Chebyshev collisions, negative certificates, complex and multiple
algebraic generators, a nonradical quintic coefficient, exact leading-term
cancellation, and degree-zero/one conventions. It compares complete chain
sets and all pairs as well as checking exact recomposition and certificates.

The [shared solver comparison](../benchmarks/README.md) records measurements at
refactoring revision `f3fceb2` against merged baseline `204c97f`, with exact
output checks, source hashes, and all timing samples.

The following historical measurements were retained in baseline `204c97f`.
They show the benefit of early rejection and the monomial-candidate shortcut
on the sparse negative input `x**96+x+1`. In separate
fresh Wolfram kernels, `RepeatedTiming[...,1]` for all pairs took 0.5751 seconds
in original report 3 and 0.02458 seconds in the unified package, about **23.4×**
faster. In Python, seven fresh searches over the same rational coefficient
vector, excluding coefficient-field conversion, gave median times of
0.03932 seconds for report 1 and 0.001100 seconds for the unified engine, about
**35.7×** faster. Both comparisons return the same exact empty pair set.
These are improvements on a specific sparse workload, not general speed
ratios. The full Python benchmark also checked a dense degree-96 input over
`Q(sqrt(2))` (1.263 seconds for one chain) and all 12 normalized chains of
`T_60` (0.0775 seconds), with exact verification outside the timed search.

Build the article from `article/` with three serial passes of
`pdflatex -interaction=nonstopmode -halt-on-error polynomial-decompose.tex`.
The editable TeX and rendered PDF are both maintained in Git. Run tests from
the live project; the reports are archival inputs and some original runners
write their historical result files in place.

The delivered 25-page PDF was rebuilt with three strict serial passes after
the final layout edits. Its final LaTeX log has no warnings, undefined
references, overfull boxes, or underfull boxes. Every page was rendered for
visual review, with full-size inspection of the API and bibliography pages.
