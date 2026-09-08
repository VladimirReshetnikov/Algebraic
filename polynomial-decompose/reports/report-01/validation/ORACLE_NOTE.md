# An observed external-oracle discrepancy

This concerns the installed **SymPy 1.14.0** in the preparation environment, not every release or the current upstream state. No upstream patch or issue has been submitted as part of this artifact.

A minimal exact reproduction is:

```python
import sympy as s
x = s.symbols('x')
p = (x**3 + x**2 + x)**2
print(s.__version__)
print(s.Poly(p, x, domain=s.QQ).decompose())
```

The observed result was a singleton containing the degree-six polynomial, although the displayed construction supplies a degree-two outer factor and degree-three inner factor. With the default integer domain in this installation, the same example was decomposed. Exact rational field arithmetic should not lose the decomposition.

Inspection of `sympy.polys.densetools._dup_right_decompose` in that installed version found this update:

```python
coeff += (i - r*j)*fc*gc
```

Here `r` is the outer degree, `s` the inner degree, `fc` is the input coefficient indexed by `n+j-i`, and `gc` is the candidate coefficient indexed by `s-j`. In this indexing, the differential identity for the formal r-th root requires

```python
coeff += (i - (r + 1)*j)*fc*gc
```

followed by division by `i*r*lc`, as in that routine. The missing `j` term gives `x**3+x**2+3*x/2` instead of `x**3+x**2+x` over QQ for the example above. An integer-domain truncated quotient can accidentally conceal this particular error. This is a diagnosis of the observed implementation; the archive does not modify SymPy.

The coefficient recurrence implemented in this archive is derived independently in the article and checked against SymPy's **formal series** expansion, which is a different operation. Polynomial long division is also checked independently. Known constructed decompositions provide expected factors without relying on any decomposition oracle.

Of 24 selected constructed-composite comparisons against the installed `.decompose()`, 18 produced a different degree multiset. Their names and both degree sequences are recorded in `reference_results.json`. Exact composition of the oracle's returned factors was still checked: the issue was missed decomposition, not an incorrect product of the returned composition chain. Generic-polynomial oracle comparisons are useful smoke checks but are not used as a completeness proof.
