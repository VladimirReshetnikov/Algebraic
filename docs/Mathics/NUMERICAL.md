# Numerical precision in Mathics

Mathics3 10.0.1 evaluates the tested `FindRoot` seeds and Newton updates at
machine precision despite a supplied `WorkingPrecision`. Before the package
adapter, `InverseNumericalCheck` could therefore label a machine-precision
reference root as high-precision numerical evidence. The independent
[precision audit](../../validation/mathics-numerical-precision-audit.json)
retains the exact programs and original outputs for a rational root, an
irrational quadratic root, and an integer root.

The Mathics-only late adapter redirects `FindRoot` in the five package-owned
numerical comparison consumers. If the requested reference-root precision
goal exceeds the demonstrated machine capability, it returns
`Failure["MathicsNumericalPrecisionUnavailable", ...]` instead of successful
comparison evidence. Delegated roots are also checked for sufficient returned
precision. This is an explicit compatibility limitation: arbitrary-precision
reference-root computation remains available in the official Wolfram kernel.

There is one exact exception. An unchanged integer seed can be recognized as
an exact root by direct substitution into an exact polynomial equation. The
adapter checks that the seed represents that integer without changing its
value, proves the substituted polynomial is exactly zero, and returns the
integer as the reference root before the consumer's requested numerical
conversion. It does not rationalize an approximation or add precision to
unverified digits.

For example, after loading the package in a separate input:

```wl
$IterationLimit = 1000000;
s = AsymptoticInverse[x^2, {x, Infinity}, {y, 1}];
InverseNumericalCheck[s, 4, WorkingPrecision -> 30]
InverseNumericalCheck[s, 2, WorkingPrecision -> 30]
```

The first check verifies the exact seed `2` and returns its reference root at
30-digit precision. The second needs the irrational reference root `Sqrt[2]`
and returns the explicit Mathics precision failure. Similarly, the inverse of
`3 x` at target `1` refuses precision 30, while a request with
`WorkingPrecision -> 10` succeeds with a machine root meeting its precision
goal. These are bounded examples, not a guarantee for every low-precision
input, convergence condition, or special inverse family.

## Logarithms of small products

Arbitrary-precision `N[Log[c r], n]` returns `Indeterminate` on the tested
interpreter when `c` is an irrational constant and the rational `r` is below
about `10^-17`; `N[Log[Sqrt[2]/10^16], 40]` evaluates while
`N[Log[Sqrt[2]/10^17], 40]` does not, and `N[Log[Sqrt[Pi]] + Log[10^-20], 40]`
evaluates. The same late adapter therefore also redirects `N` in the five
numerical consumers: when an evaluation returns `Indeterminate`, it retries
with every `Log` of a product whose factors are all numerically positive
rewritten as the sum of their logarithms, and otherwise returns the first
value unchanged. The rewrite is valid for positive real factors, which is
the real-branch situation in which these logarithmic target coordinates
arise; it is not applied to products with a nonpositive or nonnumeric factor.
Values that still contain `Indeterminate` are rejected by the consumers'
finite-value guards instead of reaching a realness comparison, which would
abort the Mathics evaluator.

Exact symbolic specialization, asymptotic remainders, interval certificates,
and numerical root comparisons have different contracts. This adapter changes
only package numerical reference-root calls on Mathics. Direct caller uses of
`FindRoot`, installed interpreter definitions, and official Wolfram loading
and numerical behavior retain their existing dispatch. Nonprincipal Lambert
values have additional [evaluation limitations](ALGEBRA.md).
