# Exact assumption consequences in Mathics

The Mathics adapter supplements the interpreter's assumption handling with a
small set of exact real-domain and sign proofs. These rules help the package
validate symbolic coefficients and its positive local coordinates. They do
not replace quantifier elimination, branch selection, or the package's
remainder proofs.

The adapter operates only in Mathics. The official Wolfram kernel continues
to use its original `Element`, `Simplify`, and `FullSimplify` definitions.

The implemented consequences include:

| Recorded assumptions | Consequence used by the package |
| --- | --- |
| `u > 0` | `-1/u` is real; `1/u` is positive; `Log[u]` is real. |
| `a > 0 && b > 0` | `a b` is real and positive. |
| `a b > 0` | `1/(a b)` is real and positive; neither factor must be real. |
| `u > 0` | `Sqrt[(1 + 2 u)^2]` reduces to `1 + 2 u`. |
| `a < 0` | `Sqrt[a^2]` reduces to `-a`; `Log[a]` is not real. |
| `Element[a, Reals]` | `Sqrt[a^2]` reduces to `Abs[a]`. |

Facts come from explicit membership assertions and comparisons in a
conjunction, including lists of assumptions. A comparison can also supply a
weaker sign bound through an exact finite numeric endpoint. The proof code
does not collect unconditional facts from the branches of `Or`, from `Not`,
or from quantified expressions.

Realness is closed under real sums and products, positive bases raised to
real powers, and integer powers with the necessary nonzero guard for negative
exponents. Nonnegative bases with positive real exponents are also admitted.
Signs are propagated through these operations, compatible sums, and a small
set of functions with proved real domains. For example, a real exponential
and a real hyperbolic cosine are positive, and a logarithm requires a positive
argument. The Gamma and Barnes G real-domain rules likewise require a
positive argument.

These are sufficient conditions. An unresolved proof remains unresolved;
the adapter does not infer falsity from failure to prove a fact. It also does
not use approximate numerical samples, generic nonzero assumptions, or
`PowerExpand`. In particular:

- `Element[a, Reals]` alone does not establish that `Log[a]` is real.
- `a >= 0` alone does not establish that `1/a` is a finite real number.
- `a > 0 || b > 0` does not establish either individual inequality.
- A negative base raised to a rational power with odd denominator is not
  treated as a real root. Wolfram Language `Power` uses the principal complex
  branch.
- A real argument alone does not establish a finite real tangent at a pole.
- A real difference does not make ordered operands real: neither
  `u + I > I` nor `u + a > a` is admitted merely from `u > 0`.
  Native simplification is withheld while an ordered operand's realness is
  unresolved, so canceling an unknown complex offset cannot bypass this check.

Mathics 10 can eagerly weaken a symbolic native membership expression. For
example, its `Element[Log[a], Reals]` can become `Element[a, Reals]` before a
simplifier receives the assumptions. The package therefore resolves its
internal membership tests to a held adapter that preserves the original
question until its domain can be checked. Numeric membership and other
domains still use the native interpreter. The adapter cannot reconstruct a
user expression that Mathics already transformed before it entered the
package.

The implementation is in
[`MathicsAssumptions.wl`](../../src/Kernel/MathicsAssumptions.wl).
The portable regression suite exercises positive local coordinates,
symbolic signs, square-root branches, and negative or complex
counterexamples. The run receipts identify the interpreter and exact test
selection; these checks do not claim full mathematical equivalence with the
Wolfram simplifier.
