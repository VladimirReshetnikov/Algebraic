# Root decomposition

Additive and multiplicative decomposition of algebraic numbers (`Root` objects)
into components of the smallest possible maximum degree, answering
[Mathematica StackExchange question 105933](https://mathematica.stackexchange.com/q/105933/7288).

For an algebraic number `a` of degree `n`:

```
D+(a) = min { max deg(b_i) : a = b_1 + ... + b_r }
Dx(a) = min { max deg(b_i) : a = b_1 * ... * b_r }
```

with the `b_i` ranging over all algebraic numbers.  The article
[`article/root-decomposition.pdf`](article/root-decomposition.pdf) contains
the complete theory with proofs; this file documents the software.

## Contents

| File | Purpose |
| --- | --- |
| `RootDecomposition.wl` | Wolfram Language package (Wolfram 15.0.1). |
| `RootDecomposition.wlt`, `RunTests.wl` | Regression tests (`wolfram -script RunTests.wl`). |
| `Examples.wl` | Worked examples (`Get["Examples.wl"]`). |
| `python/rootdecomp.py` | Independent Python implementation on python-flint (+ SymPy for the input-field factorization). |
| `python/test_rootdecomp.py` | Python regression suite; failures exit nonzero. |
| `python/verify_wolfram.py` | Independent exact verification of Python results in a native Wolfram kernel. |
| `python/requirements.txt` | Python dependencies (tested with python-flint 0.8 and SymPy 1.14). |
| `article/` | The unified article (`.tex`, `.pdf`). |
| `reports/report-01` … `report-09` | The nine original reports, unpacked verbatim. |
| [`../WOLFRAM-NOTES.md`](../WOLFRAM-NOTES.md) | Subtle Wolfram Language behaviour found while developing the package. |

## Wolfram Language package

```wolfram
Get["RootDecomposition.wl"];
ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

RootProductDecomposition[ap]["Expression"]
(* Root[1 + # + #^3 &, 1] Root[1 - # + #^3 &, 1]   (inactive Times) *)
RootSumDecomposition[as]["Expression"]
(* Root[1 + # + #^3 &, 1] + Root[1 - # + #^3 &, 1]  (inactive Plus) *)
RootSumDecomposition[ap]["Terms"]
(* two sextic Roots: the product root is a sum of two numbers of degree 6, and nothing better exists *)
```

Functions:

- `RootSumDecomposition[a]`, `RootSumDecomposition[a, d]`: minimal-maximum-degree sum, or a sum with all summands of degree at most `d`.
- `RootProductDecomposition[a]`, `RootProductDecomposition[a, d]`: search for products; the two-factor search is complete, while arbitrary-length products also use heuristics.
- `RootGaloisData[a]` or `RootGaloisData[poly, x]`: Galois group as permutations of the roots, its order and exponent, all subgroups with their fixed fields, the tower basis of the splitting field and the automorphism matrices.
- `RootDecompositionLowerBound[a]`: a rigorous lower bound (largest prime factor of the degree, Frobenius cycle types).
- `RootBoundedDecomposition[a, Plus|Times, d, height, count]`: bounded dictionary search.
- `RootDecompositionVerify[a, terms, Plus|Times]`: exact verification.

Results are associations with `"Terms"`, `"Degrees"`, `"MaximumDegree"`, `"LowerBound"`,
`"Optimal"` (global optimality, with the certification qualifications below), `"ScopeOptimal"` (optimal within the class that
was searched), `"Verified"`, `"Method"`, `"Expression"` (an inactive sum or product), and for
products `"TwoFactorOptimal"` and `"NormExponent"`.  A `Failure` is returned when a
representation with the requested degree does not exist in the searched class, or when a
resource limit is hit; it never asserts global impossibility by itself.

Options:

- `"Scope" -> "InputField"` restricts all components to `Q(a)`.
- `"Engine" -> "InputField" | "SplittingField" | Automatic`: the input-field engine (principal
  subfields from a factorization over `Q(a)`, no Galois group) is tried first and is complete
  within `Q(a)`; the splitting-field engine (numerical resolvents, trace-form coordinates) is
  used when the fast path does not reach a lower bound, and is complete for sums and for
  two-factor products.
- `"Coefficients" -> "GaussianRationals"` (sums): allow coefficients in `Q(i)`; terms are returned
  as `{coefficient, root}` pairs.
- `"MaxTerms" -> 2` (sums): only representations with at most two summands.
- `"MaxFactors" -> 2` (products): only the complete two-factor algorithm.
- `"TensorTest"`, `"RecursionDepth"`, `"BoundedSearch" -> {height, count}` (products): the
  many-factor heuristics.
- `"MaxGroupOrder"` (default 400), `"WorkingPrecision"` (default 80 digits), `"MaxTries"`.

`"Optimal"` refers to the unrestricted global problem. It is true when a proved lower bound
is attained, or a complete unrestricted additive search excludes every smaller degree.
`"ScopeOptimal"` refers to the requested field and component constraints; `"TwoFactorOptimal"`
separately records two-factor optimality within the requested field scope. In particular, `(1+Sqrt[2])(1+Sqrt[3])(1+Sqrt[5])`
has a two-factor optimum of 4 and a global product optimum of 2. Restricting `"MaxFactors"`
to 2 must not label the degree-4 answer globally optimal.

An explicit degree bound applies even when a lower bound already excludes it; the function
returns failure rather than a larger trivial answer. Term and factor limits include rational
components introduced by normalization. `"Scope" -> "InputField"` restricts the returned
components throughout the search; radical extraction outside the field is reserved for global
searches. Gaussian coefficients are supported for unrestricted flat sums in the Wolfram
implementation; a finite `"MaxTerms"` in Gaussian mode is rejected because the corresponding
coefficient-selection problem is not the fixed-space linear problem.

The Wolfram Galois engine uses exact minimal polynomials from `RootReduce`, numerical root
matching, counting checks and a group-closure check. Its search-exhaustion conclusions rely on
that numerical matching; these are distinct from the exact positive identity and degree checks
performed with `RootReduce` and `MinimalPolynomial`. The resolvent construction is practical
for Galois groups of order up to a few hundred.

## Python implementation

Requires `python-flint` and SymPy; the dependency file records the tested minimum versions.

```powershell
python -m pip install -r requirements.txt
python test_rootdecomp.py
python verify_wolfram.py  # optional independent check; requires a native Wolfram kernel
```

```python
import rootdecomp as rd
ap = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
print(rd.product_decomposition(ap))
# Decomposition(Times: Root[1 - # + #^3 &, 1] * Root[1 + # + #^3 &, 1]; degrees=[3, 3], max=3, ...)
print(rd.sum_decomposition(rd.parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")))
```

The main functions are `sum_decomposition`, `product_decomposition`, `galois_data`,
`input_field_data`, `lower_bound`, and `bounded_decomposition`. Python uses `dmax=None` for
automatic degree minimization, `scope="Global"` or `"InputField"`, and
`engine="auto"`, `"input"` or `"splitting"`. The component limits are `max_terms` and
`max_factors`, with `None` meaning unrestricted. Gaussian coefficients are a Wolfram-only
option. A constrained search with no answer returns `None`; invalid arguments and resource
or precision failures raise exceptions.

`parse_wolfram_root` and `AlgebraicNumber.wolfram()` exchange polynomial `Root` syntax with
Mathematica. Real roots have the same increasing order. Python orders complex roots in conjugate
pairs by real part and imaginary magnitude, negative imaginary part first. Wolfram's non-real
indices can depend on the isolation method, so arbitrary complex interchange needs a branch
check; it is not guaranteed merely by copying the index. See the
[Wolfram `Root` documentation](https://reference.wolfram.com/language/ref/Root.html).
The Python constructor requires an irreducible integer minimal polynomial (normalized to primitive form)
and a valid one-based root index. The Galois computation uses Arb ball arithmetic with unique
integer, factor and root identification; exact factorizations and rational linear algebra run
in FLINT.

`verify_numeric(a, result)` checks whether the difference ball contains zero. This is a useful
consistency check but does not prove equality. `verify_exact(a, result)` reconstructs the sum
or product using exact composed polynomials and certified root selection. The optional
`verify_wolfram.py` independently checks returned identities and degrees using the native kernel;
`python verify_wolfram.py --emit review.wl` writes the same checks for later execution.

## Historical timings

The table below is retained as provenance for the original implementation. Current review
measurements and validation follow it.

| Task | Wolfram | Python |
| --- | --- | --- |
| Product example, fast path in `Q(a)`, certified optimal | 0.2 s | 1.9 s |
| Sum example, fast path in `Q(a)`, certified optimal | 1.3 s | 0.4 s |
| Splitting-field data of the degree-9 examples (group of order 36) | 18–21 s | 3–5 s |
| `D+(ap) = 6` with cached splitting-field data | 0.2 s | 0.15 s |
| `ToNumberField[roots, All]` for the same field (the reports' design) | 14 min | – |

These measurements describe the original implementation on its development machine; they are
not performance guarantees. `python benchmark.py` measures the current checkout, and the
regression scripts report their own results. The original Python script only printed failed
checks; the current suite asserts its expectations and exits nonzero on failure.

## Review validation (7 September 2026)

- Native Wolfram 15.0.1: `wolfram -script RunTests.wl` passed **67 tests**, with no failures.
- Python 3.14, python-flint 0.8.0, SymPy 1.14.0: `python test_rootdecomp.py` passed
  **12 test methods**, including the 18 article examples as subtests and 11 methods covering
  bounds, certificates, field scope, cache isolation, arithmetic and root selection. Returned
  example identities are checked with `verify_exact`.
- `python verify_wolfram.py` passed **12 independent exact identity and degree checks** in
  the native kernel, including all four branches of the complex biquadratic test polynomial.
- The revised **21-page article** was rebuilt with three serial
  `pdflatex -interaction=nonstopmode -halt-on-error root-decomposition.tex` passes and rendered
  for visual inspection. The final log has no warnings or overfull/underfull boxes.

A serial comparison in separate fresh Python processes measured the default
`product_decomposition` search for the degree-nine **sum** example: **55.76 s** for repository
revision `7e2314c`, **14.69 s** for this revision, approximately **3.8 times faster** in that run.
Both returned the same maximum degree 9 with global optimality unclaimed. Importing the module
and the independent verification were outside the timed region; field construction was included.
These are single-run local measurements, not a guaranteed ratio. Use `python benchmark.py --full`
to include this case in the current benchmark.

The improvements avoid repeated root isolation, multiplication-matrix construction, failed
field-pair tests and tensor-family tests across degree thresholds. They also use balanced
polynomial products, exact subgroup containment, the stronger compositum-degree bound, and
early rejection of impossible bounded-search boxes. Many-factor tensor search starts at the
unrestricted lower bound rather than the two-factor square-root bound.

## Tensor search implementation

Tensor candidates first pass an exact compositum check. For fixed fields
`L^H_i` in a Galois field `L`, their compositum is fixed by the intersection
of the subgroups `H_i`. A nontrivial intersection means the product basis
cannot span `L`, so the candidate can be discarded before constructing
multiplication matrices. The two-factor and tensor searches share this
degree calculation.

Python also tests necessary tensor identities using rigorous Arb enclosures.
When the field degrees multiply to `|G|` and the subgroup intersection is
trivial, the map `g -> (g H_1, ..., g H_r)` bijects the Galois group with the
product of the right-coset sets. Conjugates of a product of field elements
therefore form a rank-one tensor in these coordinates. A tensor minor whose
ball excludes zero proves that a candidate fails. Inconclusive enclosures
continue to the exact rational tensor solve. Accepted decompositions retain
the existing exact checks, and both the candidate order and search caps are
preserved. Wolfram uses the exact subgroup filter; its numerical precision
estimates are not used to certify this additional rejection test.

The field engine also shares integral-polynomial normalization, rational
matrix construction, subgroup closure and coordinate-power reconstruction
with the radicals solver. Prime-degree lower bounds return immediately once
the degree-divisibility bound is already sharp.

## Main mathematical results

- Both examples have globally optimal maximum degree 3.
- Sums: complete finite algorithm (trace descent + fixed spaces); `D+(ap) = 6` while any sum inside `Q(ap)` needs degree 9.
- Two-factor products: complete finite algorithm with a radical exponent `t`; optimal factors can lie outside the splitting field (`sqrt((1+sqrt2)(1+sqrt3))`).
- Many factors: `(1+sqrt2)(1+sqrt3)(1+sqrt5)` needs three factors to attain maximum degree 2; `Dx(1+sqrt2+sqrt3) = 4` by an arithmetic sign obstruction. These implementations do not provide a complete arbitrary-length product algorithm.
- `sqrt2+sqrt3+sqrt6` is a flat sum of three quadratics but admits no binary sum or product splitting, even with Gaussian rational coefficients.
