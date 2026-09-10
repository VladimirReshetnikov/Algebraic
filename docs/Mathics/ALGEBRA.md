# Bounded algebra operations for Mathics

[`MathicsAlgebra.wl`](../../src/Kernel/MathicsAlgebra.wl) supplies the specific
missing algebra operations used by the package's Fourier coefficients and
special inverse scales. The module loads only on Mathics, and its names are
resolved only by package implementation code.

The coefficient-rules adapter accepts a polynomial in one specified symbol,
given either directly or in a singleton list. It returns nonzero coefficients
as exponent-vector rules in descending degree order. This lets the inverse
Gamma and Barnes G families compute the smallest inverse-logarithmic power
of the first omitted coefficient. It preserves exact symbolic coefficients
and delegates unsupported argument forms to the interpreter.

The current adapter constructs `CoefficientList` before removing zero
entries. Its intermediate storage therefore grows with polynomial degree,
even when only a few powers have nonzero coefficients. A sparse input and
the package's outer term budget do not bound this dense allocation. This is
a source-level resource limitation of this adapter, separate from the guarded
optional `SeriesData` export; no Mathics timing or allocation bound is claimed.

The Fourier reader uses the usual exact exponential identities for sine,
cosine, hyperbolic sine, and hyperbolic cosine. The reverse conversion uses
Euler's identity for each exponential; its argument can be complex. These
operations introduce no assumptions about reality, sign, logarithm branches,
or the absence of poles. The package's separate Fourier conjugacy checks and
frequency budgets remain responsible for admissibility. The adapter does
not claim general trigonometric simplification.

The sequence adapter supports `Take[expression, UpTo[n]]` for a nonnegative
integer `n`, including sequences shorter than `n` and empty sequences. Core
inverse constructors use this operation to retain complete available
sectors. Other `Take` forms continue to use the interpreter.

Checking only the finite expression is insufficient for these families:
missing coefficient rules or sequence operations can leave the finite
approximation correct while damaging its recorded remainder or sector
metadata. Regression checks therefore need to inspect the relevant metadata
and reject interpreter diagnostics as well as compare exact coefficients.

The late module
[`MathicsCoreFunctions.wl`](../../src/Kernel/MathicsCoreFunctions.wl) also
normalizes package-created principal Lambert values from `ProductLog[0, z]`
to the equivalent `ProductLog[z]` at four construction sites, while retaining
ordinary `System` heads in returned expressions. Native interpreter
definitions are unchanged.

The limitation extends to exact symbolic conversion. Mathics 10.0.1's
[`ProductLog` class](https://github.com/Mathics3/mathics-core/blob/10.0.1/mathics/builtin/specialfns/expintegral.py#L89-L127)
uses the
[generic SymPy bridge](https://github.com/Mathics3/mathics-core/blob/10.0.1/mathics/core/builtin.py#L711-L729),
which preserves argument order in both directions. Wolfram's
`ProductLog[k, z]` consequently reaches SymPy as `LambertW(k, z)`, although
[SymPy expects the argument before the branch](https://docs.sympy.org/latest/modules/functions/elementary.html#sympy.functions.elementary.exponential.LambertW).
Exact input can enter this
bridge before any explicit `N` call. The inherited
[numerical dispatcher](https://github.com/Mathics3/mathics-core/blob/10.0.1/mathics/core/builtin.py#L734-L783)
also accepts only one numerical argument; an inexact two-argument call can
remain unresolved instead of following the exact-input conversion path.

Nonprincipal cores retain active `System` expressions, so retaining an exact
formula or successfully substituting one exact target does not establish
general symbolic conversion, simplification, differentiation, or numerical
correctness in Mathics. This source-level bridge defect does not imply that
every retained nonprincipal formula is already incorrect. Raw `ProductLog[-1, 0]` also becomes the wrong one-argument
`ProductLog[-1]` before a package adapter can inspect it.
The exact specialization checked below remains a bounded example.
Applying native Mathics `N` can leave some
`ProductLog` terms unresolved while producing incorrect complex values for
surrounding functions. For example,
`N[Log[-ProductLog[-1, -1/100]], 30]` produces a nonreal value in the tested
interpreter, although the real lower branch makes that logarithm real.
Evaluate such numerical formulas in the official Wolfram kernel. The package
does not replace native `ProductLog` or `N`.

The previously checked lower-branch core example
`AsymptoticCoreInverse[x Log[x], x^2, {x, 0}, {y, 1}]` retains the correct exact
formula at `y = -1/100`. Its `InverseNumericalCheck` returns a conservative
failure when Mathics cannot establish the recorded branch condition; it does
not report a successful numerical comparison. This one check does not
establish every nonprincipal special-inverse numerical path.

The conversion defect also affects exact proofs. Native Mathics returns
`False` for `Simplify[ProductLog[-1, z] == -1]`, although `z = -1/E` satisfies
the equality, and can return `True` for the corresponding inequality.
Package `Simplify`, `FullSimplify`, `RootReduce`, `Refine`, and the direct
assumption walker conservatively retain an expression if it or its assumptions
still contain a two-argument `ProductLog`. The Taylor factorization check uses
the same guarded simplifier. This deliberately leaves some valid proofs
unresolved; it does not invent a replacement Lambert simplification engine.

The guard applies before the assumption walk or native simplification, but
after normal evaluation of its arguments. It cannot reconstruct a branch value
or equality already changed in caller-side evaluation. In particular, embedding
the explicit branch point directly in a raw Mathics equality can produce an
incorrect Boolean before the package sees it. No `System` function or global
evaluation attribute is replaced. The separate
[numerical precision boundary](NUMERICAL.md) also applies to package reference
root comparisons.
