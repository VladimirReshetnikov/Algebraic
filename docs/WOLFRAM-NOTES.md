# Notes on subtle Wolfram Language behaviour

For observations from the alternate interpreter, see the maintained
[Mathics evaluation notes](MATHICS-NOTES.md). Their workarounds are confined
to Mathics; they do not replace the native behaviours recorded here.

The maintained package is now named AsymptoticAnalysis; its standalone entry
point is `AsymptoticAnalysis.wl` and its Wolfram context is
``"AsymptoticAnalysis`"``. Public `AsymptoticInverse` calls are unchanged.
Historical observations below keep the package names and filenames used in
their recorded runs. See the [current loading guide](../src/Documentation/UserGuide.md#getting-started).

Findings collected while developing `RootDecomposition.wl` and
`AsymptoticInverse` (Wolfram 15.0.1, Windows). Kept as a checklist for exact
algebraic-number code, asymptotic computation, and Wolfram evaluation semantics.

## Loading from HTTP

For the current renamed package, use:

```wolfram
Get[URLDownload[
  "https://raw.githubusercontent.com/VladimirReshetnikov/Asymptotic/main/AsymptoticAnalysis.wl"]];
```

This URL selects the complete standalone file at the repository root.
The modular entry point `src/Kernel/AsymptoticAnalysis.wl` loads sibling
files from a local checkout. See the [loading guide](../src/Documentation/UserGuide.md#getting-started)
for local, offline, and commit-pinned forms.

- In a native Wolfram 15.0.1 probe, both `$InputFileName` and `$Input` were
  empty inside a file loaded by `Get["http://127.0.0.1:.../probe.wl"]`.
  Do not assume that a remotely loaded entry point can locate sibling
  modules through these variables. The repository-root standalone file
  (named `AsymptoticInverse.wl` in that probe, now `AsymptoticAnalysis.wl`)
  includes all modules and needs only one HTTP fetch.
- Cold `Get` calls against the unbuffered 574,410-byte GitHub distribution
  intermittently emitted `Syntax::sntue` at varying positions and omitted
  definitions. The package could still return `Null` and register its context.
  `URLRead` retrieved the correct complete bytes. A loopback gzip fixture
  reproduced the failure, also with `Method -> "HTTP"`. Holding the source
  in a literal inside the downloaded file did not fix its outer reader.
  The precise internal cause was not established.
- Download the complete file first and evaluate it with
  `Get[URLDownload[url]]`. This uses a single fetch and preserves ordinary
  file parsing of package context changes. The returned file is temporary.
- `Get[URLRead[url, "Body"], Method -> "String"]` passed initial tests but
  later had connection failures under the native harness even while direct
  `URLRead` probes succeeded. Redirecting the native process's diagnostics
  did not consistently resolve the discrepancy. No specific HTTP or reader
  implementation bug is asserted from that observation. The downloaded-file
  form is the supported route and passed the final repeated native runs.
- An experimental small HTTP loader that itself fetched the complete source
  passed its initial three-kernel run. On two later runs, all seven checks
  passed but the kernel then exited with status `3221225477` (`0xC0000005`).
  Those runs were rejected and that entry point was withdrawn. The exact
  native failure mechanism was not established. The
  downloaded-file command completed repeated runs with normal kernel exit.
- Keep package source as a sequence of top-level expressions. Wrapping the
  source expressions in `Module` or another holding expression can parse symbols before
  `BeginPackage` and `Begin` establish their intended contexts. Inline
  companion files at their original load positions, including the early
  exact-termination helper.
- Parse acceptance expressions after `Get` has returned. A test expression
  parsed alongside `Get` can resolve an exported symbol in the global context before
  the package context is on `$ContextPath`.

## Truncated Dirichlet expansions and transported bounds

The `Zeta`/`LerchPhi` constructors write their finite expression as
`1 + 2^-x + 3^-x`, but the shared series calculus stores the scale as
`E^-x` with exponents `Log[n]`. After `SeriesTruncate`, `Normal` therefore
prints `(E^-x)^Log[2]`; the two forms agree for real `x` but are not
`SameQ`, and `Simplify` without a realness assumption does not identify
them. Compare truncated Dirichlet results numerically or under `x > 1`. The
bound transport in `SeriesTruncate` rewrites the discarded part back to
`n^-x` before taking its absolute value, so `"TruncationDiscardedPart"` and
the transported `"AbsoluteRemainderBound"` use the constructor's form.
`Abs[3^-x]` with a symbolic `x` remains an `Abs` expression in the bound;
it evaluates once `x` is numeric.

## Missing model fields and coefficient queries

An association lookup for a missing key produces `Missing["KeyAbsent", key]`.
The same happens for `Lookup[{}, key]`: an empty list is an empty rule
collection, so a lookup over an empty list of associations returns
`Missing["KeyAbsent", key]` rather than `{}`. Code that collects a field from
a possibly empty list of records must map an accessor over the list instead
of calling `Lookup` on it; the aggregate test runner exports such fields and
a `Missing` value cannot be exported as JSON.
Passing that result to `Join` does not validate a result object's capability:
it emits `Join::incpt` before the public query can report a useful refusal.
`InverseExpansionCoefficient` now checks its ordinary inverse model before
reading or augmenting it. A forward `GeneralizedSeries` is a valid package
object but need not carry this model. The
[coefficient-model note](development/INVERSE_COEFFICIENT_MODELS.md) records the
native reproduction and the preserved empty-index and infinity cases.

## Control flow

- `Return[expr]` inside `Do`, `While`, `Table`, ... returns from the *loop*, not
  from the enclosing `Module`.  Either use the documented second argument,
  `Return[expr, Module]`, or a uniquely tagged `Catch`/`Throw`.  The package uses
  tagged `Catch`/`Throw` everywhere a loop must abort a function.
- `Break[]` and `Continue[]` in a nested `Do` act on the innermost loop only.

## Number-field functions (performance)

- `ToNumberField[roots, All]` for the nine roots of the degree-9 example
  (splitting field of degree 36) took about 14 minutes, and a single
  `ToNumberField[root, theta]` conversion into that field took a further
  10 minutes.  The reason is not the field degree but the power basis of a
  generic primitive element: its minimal polynomial has coefficients around
  `10^20` and the coordinates of the roots in that basis have enormous
  heights.  Every report in `reports/` proposed exactly this construction
  without having run it.
- `RootReduce[theta + w*Root[p, k]]` (adjoining one root to a partial
  primitive element) is fast, about one second per step up to degree 36.  The
  package builds the Galois group from these minimal polynomials and never
  converts anything into the power basis of the primitive element; it uses a
  tower monomial basis with traces instead.
- `RootReduce[theta + w*Root[p, k]]` can return an element of *smaller*
  degree than `theta` for unlucky integer weights `w` (the combination is
  degenerate).  Always check that the degree is a multiple of the previous one
  and re-draw the weight otherwise.
- `Factor[p, Extension -> theta]` for a degree-9 polynomial over a degree-18
  field took 23 s; over a degree-36 field it is much slower.  Avoid factoring
  over large number fields when linear algebra will do.
- `MinimalPolynomial[a, x]` returns a polynomial with *rational* coefficients
  for non-integral `a`; normalise with a primitive-integer routine before
  reading off heights.

## Root objects

- Ordering of `Root[f, k]`: real roots first in increasing order, then the
  non-real roots in conjugate pairs ordered by increasing real part and
  then by increasing `|Im|`, with the root of negative imaginary part first
  within a pair.  (Checked on `#^5-#-1`, `#^8-4#^6-16#^4-8#^2+4`,
  `#^6+#^4+3#^2-2#+5` and `#^4+1`.)
- Roots of polynomials of degree at most 4 may auto-simplify to radicals or
  rationals (`Root[#^2-2&,1]` evaluates to `-Sqrt[2]`).  Measure degree with
  `MinimalPolynomial`, never with `Head` or the exponent of the displayed
  polynomial.
- A convenient way to build a `Root` object from a polynomial in a symbol:
  `Root[Function @@ {poly /. x -> Slot[1]}, k]`.
- `Root[f, k]` with reducible `f` evaluates to a root of a factor; enumerate
  the roots of a reducible polynomial factor by factor.
- `RootReduce` handles `Power[Root[...], 1/t]` (principal branch), which is
  how the package produces t-th roots of field elements.

## Numerics

- `N[expr, prec]` with a non-numeric `prec` (for example `ComplexInfinity`
  produced by an upstream error) prints `N::precbd` and returns the exact
  input unchanged; the failure then surfaces far away as `Part::partw` or
  `Do::iterb`.  Validate precisions before calling `N`.
- `Accuracy[x]` and `Precision[x]` of an exact number are `Infinity`; a
  rounding check that requires `Accuracy[z] > k` must accept exact input.
- Significance arithmetic tracks error estimates through long computations;
  the package checks `Accuracy` before rounding a numerical trace to an
  integer and escalates precision on failure.

## Lists and iterators

- `Join @@ Table[expr, {i}, {j}, {k}]` flattens only one level; a triple
  `Table` needs `Flatten`.
- `Subsets[list, {k}]` materialises every subset; for combinatorial families
  with a divisibility constraint, generate them recursively instead.
- `Times[vector, matrix]` multiplies the rows of the matrix by the vector
  entries (used for `DiagonalMatrix[v].M` without building the diagonal
  matrix).
- `Do[..., {maxTries}]` without an iterator variable is fine; a `Do` whose
  iterator list has become non-numeric prints `Do::iterb`.

## Symbols

- `Module[{E = ...}, ...]` localises the system symbol `E`; it works but is
  confusing.  The package uses `EE`/`FF` for field bases.
- Inside a package, use a private symbol for the polynomial variable and
  convert user polynomials with `poly /. var -> x`.

## Scripts

- In `wolfram.exe -script file.wl`, standard output is block-buffered when
  redirected: nothing appears until the kernel exits.  Long runs should log
  to a file with `WriteString["log", ...]` (which flushes).
- `wolfram.exe` seats are limited and shared with other sessions on the
  machine; track the PIDs of the kernels you start and kill only those.
- `TestReport["file.wlt"]` needs absolute paths or `SetDirectory` first.

## Miscellaneous

- `FactorList[poly, Modulus -> p]` gives the factorisation pattern used for
  Frobenius cycle types; skip primes dividing the discriminant.
- `IrreduciblePolynomialQ` accepts integer polynomials in one variable and is
  fast enough for enumerating small coefficient boxes.
- `LinearSolve[B, v]` on a rank-deficient `B` returns one particular
  solution; `NullSpace` returns rows.  `RowReduce` gives a canonical basis of
  a row space, convenient for de-duplicating embedded subspaces.

## Findings added during the implementation of the input-field engine

- `Factor[P, Extension -> Root[P, k]]` returns the factors with coefficients
  written as polynomial expressions in the `Root` object itself (for example
  `-1 + 2 x^2 + 2 x Root[...] + 3 Root[...]^2 + ...`), so their coordinates
  in the power basis are obtained by substituting a symbol for the `Root`
  object and reading off `CoefficientList`; no `ToNumberField` call is
  needed.  The factorisation of the degree-9 minimal polynomial over its own
  field takes 0.3 s.
- `PolynomialRemainder[expr, P, z]` with `P` written in a *different*
  variable treats `P` as a constant and returns 0 silently.  Keep one
  variable per polynomial ring and convert explicitly (`P /. x -> z`).
- A function with the pattern `f[cache_Symbol]` does not match a call
  `f[cache]` when `cache` holds an `Association`: the argument is evaluated
  first, the pattern fails, and the call is returned *unevaluated*.  A
  downstream test `res =!= $Failed` then treats the unevaluated expression
  as a success.  Use a package-level symbol for mutable caches, or `HoldAll`.
- `Module[{E = ...}]` with the system symbol `E` is legal but easy to
  misread; the package uses `EE`, `FF`.
- `LatticeReduce` accepts integer matrices only; clear denominators of a
  rational null-space basis first.  Reduced null vectors give factors of
  much smaller height than the raw `NullSpace` output.
- `RootReduce[q * Root[...]]` is necessary before displaying a rescaled root:
  `Root[8+4#+#^3&,1]/2` stays as written otherwise.
- Kernel seats are shared with other sessions on the machine; never run
  `taskkill /F /IM wolfram.exe` blindly.  Track the PIDs of kernels started
  by the session and kill only those.

## Findings from the asymptotic-inverse work (Wolfram 15.0.1, September 2026)

### Scripts and test harnesses

- `wolfram.exe -script file.wl a b c` leaves `$ScriptCommandLine` **empty**;
  the arguments are only available in `$CommandLine` (after the `-script`
  entry).  `wolframscript -file` populates `$ScriptCommandLine`.
- Inside a `.wlt` file run through `TestReport`, `$InputFileName` is the
  file of the *caller*, not the `.wlt` file.  A test file that locates its
  package through `DirectoryName[$InputFileName]` works only when driven by
  a runner in the expected directory; preload the package in the driver to
  make the suite location-independent.
- Nine independently written packages for the same problem were all
  delivered "unexecuted" (no kernel was available to their authors).  Run
  natively, seven suites passed completely and the two failures (one each
  in reports 01 and 04) were *zero-recognition* failures in residual
  checkers, not wrong coefficients; see the next section.
- One batch invocation of a kernel exited with status 1 after two seconds
  and produced no output at all, while an identical rerun succeeded.  Treat
  a silent instant exit as a transient kernel start failure and rerun
  before investigating the script.

### Zero recognition for exact residuals

- `Simplify` does **not** denest nested radicals: it leaves
  `-2 Sqrt[2] - 2 Sqrt[3] + 2 Sqrt[5 + 2 Sqrt[6]]` unevaluated although it
  is zero (`Sqrt[5 + 2 Sqrt[6]] == Sqrt[2] + Sqrt[3]`).  Such expressions
  arise as soon as `RootReduce`d exponents (`Root` objects) are multiplied
  into coefficients and later displayed with `ToRadicals`.  Use
  `RootReduce[expr] === 0` (or `FullSimplify`) for zero tests of algebraic
  numbers; `Simplify[expr == 0]` is not enough.
- `Expand` and `Simplify` do not relate `Log[4]`, `Log[8]`, `Log[32]`,
  `Log[128]` to `Log[2]`: the residual
  `-(Log[4]^2)/16 - Log[2] Log[32]/64 + Log[8] Log[128]/64` is exactly zero
  but survives both.  Canonicalise logarithms of positive rationals first
  (`Log[n] -> Sum[e Log[p]]` over the prime factorisation, or
  `PowerExpand` on a provably positive argument), then test for zero.
- Conclusion for residual checkers: canonicalise coefficients with
  `RootReduce` (algebraic part) and prime-factorised logarithms before the
  zero test, or the checker reports spurious nonzero residuals.

### Series and InverseSeries with logarithms and irrational powers

- `Series[f, {x, 0, n}]` handles logarithmic coefficients: e.g.
  `Series[Sin[x] + x^2 Log[x], {x, 0, 5}]` gives
  `SeriesData[x, 0, {1, Log[x], -1/6, 0, 1/120}, 1, 6, 1]`, and
  `Series[x^x - 1, {x, 0, 2}]` gives `SeriesData[x, 0, {Log[x], Log[x]^2/2}, 1, 3, 1]`.
- Terms with irrational exponents are left **outside** the `SeriesData`:
  `Series[x + x^Sqrt[2], {x, 0, 3}]` returns
  `x^Sqrt[2] + SeriesData[x, 0, {1}, 1, 4, 1]` (also with
  `Assumptions -> x > 0`), and `Series[x^Pi + x, ...]` behaves the same way.
  Hence "Series output" for a power-log germ is in general a `Plus` of a
  `SeriesData` and finitely many irrational-power monomials, and a parser
  must accept that shape.
- `InverseSeries` returns unevaluated when a coefficient contains `Log[x]`
  (`InverseSeries[Series[x + x^2 (1 + Log[x]), {x, 0, 3}], y]`), which is
  the root of the Stack Exchange question.
- `SeriesData` arithmetic with logarithmic coefficients works (products,
  `D`), but the `O[y]^n` term hides logarithmic factors: a genuine
  remainder of the log example is `O[y^3 (1 + Abs[Log[y]])^2]`, not `O[y]^3`.
- `Series[Sqrt[x^2 + x^3], {x, 0, 2}]` without assumptions yields
  coefficients `Sqrt[x^2]/x`; add `Assumptions -> x > 0` to obtain the
  positive branch.
- `Asymptotic[x + x^Sqrt[2] + x^2, x -> 0, SeriesTermGoal -> 3]` returns the
  input unchanged (it is already a finite sum), and `Asymptotic` on
  `ProductLog[-1, -y]` at `y -> 0` produces an unusable expression full of
  `Floor[Arg[y]/(2 Pi)]`; the lower Lambert branch needs the explicit
  `-Log[y] - Log[-Log[y]] + ...` expansion instead.

### Throw, Catch and scripts

- An **uncaught `Throw`** in `wolfram.exe -script` terminates the whole
  script silently: no `Throw::nocatch` message is printed and the exit code
  is 0.  Every subsequent statement is skipped.  Symptom: a log file that is
  opened at the top of the script stays empty.
- A wrapper `catch[body_] := Catch[body, tag]` **without a Hold attribute**
  evaluates `body` before `Catch` is entered, so a `Throw` inside `body`
  is uncaught (and kills a script, see above).  Give the wrapper `HoldAll`
  (`SetAttributes[catch, HoldAll]`).  The same applies to any helper that is
  meant to wrap `Catch`, `TimeConstrained`, `Quiet` or `Block` around an
  argument.
- A hung kernel keeps its licence seat; a new `wolfram.exe -script` that
  cannot obtain a seat exits **immediately with status 0 and no output**.
  Find the culprit with
  `Get-CimInstance Win32_Process -Filter "name='wolfram.exe'"` (PowerShell),
  which shows the command line of each kernel, and stop only your own with
  `Stop-Process -Id <pid> -Force` (`taskkill /F /PID` from Git Bash did not
  terminate it).
- `jetPowerSeries`-style loops that stop when a truncated product becomes
  empty never terminate when the truncation cutoff is `Infinity`; guard every
  series loop against an infinite working order.
- `FindRoot[f == c, {x, x0}]` inside a `Module[{..., x, ...}]` whose local
  `x` merely *holds* the global symbol does not work: `FindRoot` has
  `HoldAll`, receives the local `x$nnn`, and fails ("not a valid variable" /
  no convergence).  Inject the actual symbol with `With[{xv = x}, FindRoot[...
  {xv, x0} ...]]`.
- `FindRoot` with `WorkingPrecision -> 60` and a starting value of precision
  50 emits `FindRoot::precw` and, under `Check`, looks like a failure; raise
  the precision of the starting value (`N[expr, 60]`) first.
- `Check[expr, $Failed]` around `Quiet[...]` is the wrong order: use
  `Quiet[Check[expr, $Failed]]` so that the messages still trigger `Check`.

### Applied inverse functions and conditional branches (version 1.5.0)

- `InverseFunction[F, k, n][a1, ..., an]` solves the scalar equation
  `F[a1, ..., t, ..., an] == ak`, with `t` in position `k`. The other
  argument positions are retained. It does not represent a multivariate
  inverse map. A real source condition can select a branch, but realness
  alone need not do so: both signs of `Sqrt[y]` invert `t^2` near `y = 0+`.
  [Official inverse-function semantics](https://reference.wolfram.com/language/ref/InverseFunction.html).
- Apply a pure function to fresh source arguments instead of replacing its
  formal symbols or slots throughout its body. Native application handles
  nested scopes and renames named parameters to avoid capture. Inspect a
  formal-parameter declaration under `HoldComplete`: an `OwnValue` on a
  global symbol used as a formal must not alter its declared arity. Slot,
  named, named-list and `Function[Null, body, attrs]` forms are distinct
  syntactic cases. [Official pure-function semantics](https://reference.wolfram.com/language/ref/Function.html).
- `ConditionalExpression` may propagate out of mathematical arguments and
  contribute conditions to an assumptions-aware function. A public
  `HoldAllComplete` boundary lets the package separate expansion-variable
  conditions from parameter assumptions before that propagation can change
  the call. The private entry then evaluates normally, including supplied
  option sequences and native closed-form inverses.
  [ConditionalExpression](https://reference.wolfram.com/language/ref/ConditionalExpression.html),
  [HoldAllComplete](https://reference.wolfram.com/language/ref/HoldAllComplete.html).
- Source and target conditions have different variables. Inside
  `InverseFunction[ConditionalExpression[F[#], C[#]] &]`, `C` restricts the
  original source. An outer condition on `y` restricts the target approach.
  On the common `AsymptoticExpansion` and `AsymptoticInverse` boundaries,
  variable-dependent `Assumptions` clauses are checked as eventual approach
  conditions and parameter-only clauses stay separate. Checking at the
  endpoint itself is wrong for deleted conditions such as `0 < y < 1`
  near `y -> 0+`.
- Conditions inside unevaluated binders, holding heads or control branches
  cannot safely be hoisted just because the expression contains a
  `ConditionalExpression`. Evaluate an ordinary callable first, and reject
  a remaining scope whose condition semantics are unsupported.
- A bounded list of real roots is not a completeness proof. Automatic inverse
  selection needs a complete real fiber and boundary analysis, or a verified
  unique candidate under strict monotonicity on a connected real domain.
  An unresolved candidate is different from a disproved candidate. An
  explicit `"InverseFunctionBranches"` choice still needs its local domain,
  target limit, approach side and derivative sign validated.
- Native `InverseFunction` can evaluate before the adapter sees its syntax:
  `InverseFunction[Sin][y]` becomes `ArcSin[y]`. Preserve that native branch.
  Do not attempt to reconstruct an earlier callable or condition from an
  already computed closed form. An inverse operator that remains unevaluated
  must use the selected real inverse engine; native `Series` on that operator
  can reproduce the original complex-root or undefined-coefficient failure.
- Varying non-inverted arguments cannot be frozen at their limiting values.
  The supported exact family reduction is
  `A(x) F(t) + B(x) == Y(x)` to `F(t) == (Y(x) - B(x))/A(x)`, with eventual
  `A(x) != 0` proved from the argument's available jet. The identity is checked
  independently. More general coupled variation, and varying source
  conditions the reduction cannot preserve, fail explicitly.
- Repeated working-order attempts revisit the same inverse node. Cache its
  parsed callable and branch proof for the duration of a public call, keyed
  by the full relevant expression, assumptions, target germ and explicit
  selection. Do not reuse a proof across changed parameter contexts merely
  because the printed callable is similar.
- Numerical branch checks must substitute the recovered **source root** into
  `SourceDomain`, even when the object displays a squared inverse or another
  power. Legacy logarithmic results express some domains in their positive
  local variable; normalize that coordinate before substitution. The result
  remains numerical evidence, not a certificate.
- A certificate proves the source restriction on its whole closed interval.
  Rational affine comparisons should use exact endpoint ranges: independently
  rounding `x` and `1/10` in `x - 1/10` can leave a negative lower bound at
  the exact endpoint `x = 1/10`, however high the precision. This is not a
  reason to weaken a strict inequality or introduce a numerical tolerance.
  Likewise, an exact root at the supplied center need not produce a singleton
  enclosure after other outward-rounded arithmetic; test exact containment
  and the certified width/error bound.
- In an observable `e[z]` applied to a series in `y`, an expression free of
  `z` may still depend on `y`. Expand that dependence in the recorded local
  coordinate; it is not a constant coefficient. Otherwise the input
  `Sin[y] = y + O[y^3]` can falsely prove `z != y` from a spurious leading
  constant block. Relational decisions must respect the remaining error.
- `Unequal[a,b,c]` requires all three pairs to be distinct. Adjacent-pair
  checks suffice for ordered chains, but not for n-ary `Unequal`.
- Automatic series arithmetic needs a guard around internal evaluation.
  Match the whole n-ary `Plus` or `Times`, rather than repeatedly matching
  subsets under their `Flat` and `Orderless` attributes. Restrict upvalues to
  deliberate arithmetic and function heads so that `Normal`, formatting,
  property access, and explicit operation APIs retain their own semantics.
- `SeriesNormalize` holds the supplied tree with `HoldAllComplete`, including
  symbolic aliases resolved from held `OwnValues`. Releasing a delayed alias
  with arithmetic disabled can otherwise simplify `s/s` to `1` before checking
  whether `s` has a nonzero leading term. The native regression distinguishes
  that case from an expression already evaluated and stored by the caller.
- A final cutoff cannot be imposed independently on every child. The held
  normalizer retains exact input terms through products and divisions, then
  truncates the result. It can increase the work order of newly formed
  functions after cancellation, but never refines an input's unknown tail.
- Native `FailureQ[$Failed]` is true. Test the structural form
  `Failure["ResourceLimit", _Association]` before taking failure parts;
  indexing `$Failed[[1]]` emits a message during an ordinary exact-jet probe.
- Native `Limit` ignores assumptions involving its limit variable. Prove the
  branch on the recorded approach first, simplify absolute values with those
  branch facts, and pass independent parameter conditions to the limit.
  Lambert-core limits are often much easier in the original target variable
  than after replacing it by the reciprocal of a fresh small coordinate.
- Native `Series[..., Analytic -> False]` can return an expression tree
  containing several `SeriesData` objects, including truncated exponential
  phases. Import that structure before applying `Normal`; each operation
  must transport the unknown remainder. An unchanged special function is
  not an exact finite expansion. Require exact equality before accepting a
  native expression that has no remainder.
- On a proved real ray, native Bessel, Airy, and integral expansions can
  contain complex connection terms. Real projection preserves an absolute
  error bound only after the original source is proved real. It must not
  silently declare unconstrained symbolic parameters real. Exact half-integer
  Bessel identities must retain both exponentials when both are present.
- `SeriesData` does not record the logarithmic degree of its unknown tail.
  Within the admitted power-log class, a strict loss in the remainder power
  absorbs any fixed logarithmic degree. Compute an explicit omitted block
  and prove the native tail smaller before reporting a sharper boundary.
  The maximum degree among retained coefficients is not a tail-degree bound.
- `Log[u^k]` cannot be replaced by `k Log[u]` merely because the coordinate
  `u` is positive. The finite power-log parser also needs a proof that the
  fixed exponent is real; the scaled identity for `Log[c u^k]` additionally
  requires `c > 0`. Negative real exponents are valid. Under `a^2 == -1`,
  `x + x^2 Log[x^a]^2` is a real monotone source near zero, but the rewrite
  changes a bounded winding coefficient into `-Log[x]^2`. Checking the
  resulting real coefficients cannot repair that lost source identity.
  Use retained assumptions at the neutral proof boundary, leave unproved
  logarithms unnormalized, and preserve exact cancellation before parsing.
  Prove positivity recursively for nested bases such as `(1/u)^a`; every
  power needs a real exponent, including inner powers. The focused infinity
  control caught the gap in the original two-pattern implementation. The
  final helper retains the whole logarithm when any such proof is missing.
  The [13 baseline observations](../validation/log-power-normalization-baseline.json)
  reproduce both public depth witnesses and changed flat coefficients;
  the exact-core probe retains the logarithm and has a different admission concern.
  The [logarithm normalization notes](development/LOG_POWER_NORMALIZATION.md)
  record the proof, affected consumers, structured after-guard refusals,
  and the completed 207/0 focused acceptance;
  this is separate from preserving a complex result in explicit native mode.
- A homogeneous Fourier composition recurrence must test support exhaustion
  and the next complete coefficient before forming its next product. For
  `B = 1`, exponent one and `U = w + w^2`, the exact result is `1 + U`;
  its unused square nevertheless has four candidate pairs below cutoff five.
  The [current baseline](../validation/fourier-termination-baseline.json)
  also reproduces a public residual failure with an explicit budget of seven;
  the [after-fix probes](../validation/fourier-termination-after-fix.json)
  record zero residual blocks at relative cutoff six. A zero must be a full
  coefficient identity under retained assumptions, not a pointwise value.
  Integer exponents do not terminate every Fourier/logarithmic amplitude:
  `B = Exp[I L]` at exponent zero has no zero coefficient, and `B = L` at
  exponent one has second coefficient `1/2`. Keep necessary pair/frequency
  budgets and boundary logarithmic envelopes. The
  [Fourier termination note](development/FOURIER_TERMINATION.md) separates
  these characterizations from the completed 68/0 focused acceptance and
  separate loading checks.
- A generic observable must inspect the returned Taylor chart and exclusive
  endpoint, not only the order requested from `Series`. A truthful custom
  provider returning `u + O(u^2)` cannot justify coefficients beyond that
  boundary as zero. For a local increment bounded by `w^alpha M^d`, Taylor
  order `N = Ceiling[C/alpha]` suffices below exclusive power `C`; equality
  at the power boundary still contributes logarithmic degree `N d`.
- A real-sided Taylor bound requires a real input path. Prove reality of the
  whole inner argument before truncation: an imaginary term can be hidden in
  a discarded tail, and the completed output coefficients may still be real.
  Under `a^2 == -1`, `a Re[a z]` is a useful witness; substituting the real-axis
  Taylor rule for `Re` along `a x` would produce the false result `-x`.
  Keep the formal input value separate from the actual expansion coordinate
  when using assumptions, and do not promote a fixed-parameter neighborhood
  to a joint-domain proof. Complex output cancellation remains permitted.
- The constant of a sided expansion need not equal the point value.
  `FractionalPart[1-u]` has constant `1` for positive `u`, whereas
  `FractionalPart[1]` is `0`. Use the native sided constant when the full
  inner germ has a proved side. An exact point uses its actual value; a
  pure uncertainty such as `1 + O(w)` requires compatible information on
  both sides and at the point. `Analytic -> False` alone cannot repair a
  consumer that replaces a correct sided constant with the endpoint value.
  The [nine baseline observations](../validation/observable-ingress-baseline.json)
  reproduce both errors on Wolfram 15.0.1 Windows with unchanged sources.
  The [observable Taylor notes](development/OBSERVABLE_INGRESS.md) separate
  these checks from the still-open general analyticity-admission question.
- Native `SeriesData` index limits are separate from dense coefficient
  allocation. Probes on Wolfram 15.0.1 for 64-bit Windows admit a positive
  denominator through `2^63-1` and individual signed indices from `-2^63`
  through `2^63-1`. The difference `nmax-nmin` must also fit the nonnegative
  signed range: valid individual indices do not suffice. A constructor with
  a span larger than `2^63-1` can silently discard supplied coefficients,
  so absence of messages does not establish a faithful native view.
  The optional exporter must check denominator, both endpoints, and span
  before dense allocation or inverse coefficient scaling. This restriction
  belongs to the native representation; it does not limit the sparse
  expansion's exact rational exponents. The
  [14 constructor characterizations](../validation/native-index-range-probe.json)
  distinguish native diagnostics from silent coefficient loss. The separate
  [46/0 focused acceptance](../validation/review-native-index-range-tests.json)
  covers 17 new range cases and 29 existing export/representation cases in
  four selected files, with unchanged sources during the run. C17 in the
  [review register](development/CODE_REVIEW_STATUS.md) records that scope;
  the full suite was not run.
- On the same native kernel, `RawJSON` export of the signed boundary
  integer `-2^63` produced malformed numeric text. Boundary diagnostics
  serialize lattice indices as `InputForm` strings; they do not infer
  successful JSON encoding from successful evaluation of the exact integer.
- Native rule-form term goals are not package nonzero-block counts. On
  Wolfram 15.0.1 Windows, `Series[Exp[x], x -> 0, SeriesTermGoal -> 0]`
  retains the constant term, while negative integer goals return an empty
  finite part. An explicit `Automatic` goal also produces a leading series;
  the corresponding `Asymptotic` calls remain unresolved. Scalar automatic
  routing now tries both compatible native engines for those explicit goals.
  Reuse the effective common option values after package preparation rather
  than evaluating delayed options again. Configured defaults and option-name
  equivalence require their own ingress policy; this repair does not settle
  those wave-3 findings.
- Absolute majorants should be computed structurally. The bounds
  `Abs[Sin[a + I b]] <= Exp[Abs[b]]` and the analogous cosine bound expose
  cancellation of opposite exponential carriers without costly simplification
  inside `Abs`. Real oscillatory coefficients must be polynomial in bounded
  modes; a reciprocal such as `1/(1 + Sin[x])` is not bounded merely because
  `Sin[x]` is bounded.
- Parameterized finite-argument functions can be curried into the existing
  analytic composition calculus. Extract a proved positive Frobenius power
  first when an irrational order lies outside native Puiseux exponents.
  Only one argument varies in this adapter; parameter and branch conditions
  remain part of admission.
- `Context` holds its argument. To inspect a computed head, pass it to a
  helper matching `h_Symbol`; `Context[Head[node]]` does not inspect the
  evaluated head as ordinary argument evaluation would suggest.
- Keep the `Normal` contract separate from StandardForm display. The finite
  `"Expression"` field is already an ordinary expression. Returning that
  field drops every remainder and metadata field, including nested series
  retained solely in operation recipes. A pure remainder returns `0`.
- A held backend selector cannot discover a computed option container without
  evaluation. Resolve trailing containers while keeping the source held, then
  release the source in the selected backend's context. Otherwise a computed
  `Assumptions -> True` list can let the source simplify under ambient
  assumptions before the package's neutral proof scope starts. Container
  preparation is observable and need not preserve arbitrary native side-effect
  ordering. Keep original held arguments as well as the prepared native request.
- Before package-to-native fallback, retain evaluated source/specification
  values and materialize common delayed options once. Releasing the original
  request again repeats user programs. Native-only options must be routed or
  rejected before a successful package engine can silently ignore them.
- An interval proof can succeed before its requested accuracy is reached.
  Such a retry may need higher arithmetic order as well as a narrower interval.
  Cap automatic order planning without rejecting an exact zero-residual proof;
  explicit invalid orders remain errors. A reached arithmetic cap does not
  prevent useful interval contraction. Preserve the best certified attempt
  separately from the last attempt and from any certificate proving a fixed
  center's accuracy floor.
