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
| `python/test_rootdecomp.py` | Python regression and timing script. |
| `article/` | The unified article (`.tex`, `.pdf`). |
| `reports/report-01` … `report-09` | The nine original reports, unpacked verbatim. |
| `WOLFRAM-NOTES.md` | Subtle Wolfram Language behaviour found while developing the package. |

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
- `RootProductDecomposition[a]`, `RootProductDecomposition[a, d]`: the same for products.
- `RootGaloisData[a]` or `RootGaloisData[poly, x]`: Galois group as permutations of the roots, its order and exponent, all subgroups with their fixed fields, the tower basis of the splitting field and the automorphism matrices.
- `RootDecompositionLowerBound[a]`: a rigorous lower bound (largest prime factor of the degree, Frobenius cycle types).
- `RootBoundedDecomposition[a, Plus|Times, d, height, count]`: bounded dictionary search.
- `RootDecompositionVerify[a, terms, Plus|Times]`: exact verification.

Results are associations with `"Terms"`, `"Degrees"`, `"MaximumDegree"`, `"LowerBound"`,
`"Optimal"` (globally optimal, certified), `"ScopeOptimal"` (optimal within the class that
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

What is certified: `"Optimal" -> True` means that the maximum degree equals a proved lower bound
or that a complete algorithm (sums; two-factor products with `"MaxFactors" -> 2`) exhausted all
smaller degrees.  For products of many factors no complete algorithm is known; the package reports
the best verified decomposition and marks it optimal only when a lower bound is attained.

The Galois group is determined numerically (with exact minimal polynomials from `RootReduce`,
counting checks and a group-closure check); every decomposition returned is re-verified exactly
with `RootReduce` and `MinimalPolynomial`.  The resolvent construction is practical for Galois
groups of order up to a few hundred.

## Python implementation

Requires `python-flint` (0.7 or later) and SymPy.

```python
import rootdecomp as rd
ap = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
print(rd.product_decomposition(ap))
# Decomposition(Times: Root[1 - # + #^3 &, 1] * Root[1 + # + #^3 &, 1]; degrees=[3, 3], max=3, ...)
print(rd.sum_decomposition(rd.parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")))
```

`sum_decomposition`, `product_decomposition` (same options as above: `dmax`, `scope`,
`max_terms`, `max_factors`, `engine`), `galois_data`, `input_field_data`, `lower_bound`,
`bounded_decomposition`, `verify_numeric`, and `parse_wolfram_root` / `AlgebraicNumber.wolfram()`
for exchanging `Root` syntax with Mathematica (same root ordering).  The Galois computation uses
Arb ball arithmetic, so its integer roundings are rigorous; the exact factorizations and the
rational linear algebra run in FLINT.

## Timings (this machine)

| Task | Wolfram | Python |
| --- | --- | --- |
| Product example, fast path in `Q(a)`, certified optimal | 0.2 s | 1.9 s |
| Sum example, fast path in `Q(a)`, certified optimal | 1.3 s | 0.4 s |
| Splitting-field data of the degree-9 examples (group of order 36) | 18–21 s | 3–5 s |
| `D+(ap) = 6` with cached splitting-field data | 0.2 s | 0.15 s |
| `ToNumberField[roots, All]` for the same field (the reports' design) | 14 min | – |

The Wolfram suite (39 tests, `wolfram -script RunTests.wl`) and the Python suite
(18 checks, `python test_rootdecomp.py`) pass on this machine.

## Main mathematical results

- Both examples have globally optimal maximum degree 3.
- Sums: complete finite algorithm (trace descent + fixed spaces); `D+(ap) = 6` while any sum inside `Q(ap)` needs degree 9.
- Two-factor products: complete finite algorithm with a radical exponent `t`; optimal factors can lie outside the splitting field (`sqrt((1+sqrt2)(1+sqrt3))`).
- Many factors: `(1+sqrt2)(1+sqrt3)(1+sqrt5)` needs three factors; `Dx(1+sqrt2+sqrt3) = 4` by an arithmetic sign obstruction; no complete algorithm is known.
- `sqrt2+sqrt3+sqrt6` is a flat sum of three quadratics but admits no binary sum or product splitting, even with Gaussian rational coefficients.
