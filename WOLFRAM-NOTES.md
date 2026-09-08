# Notes on subtle Wolfram Language behaviour

Findings collected while developing `RootDecomposition.wl` (Wolfram 15.0.1,
Windows).  Kept as a checklist for future work on exact algebraic-number code.

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
