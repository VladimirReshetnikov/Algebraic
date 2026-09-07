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
- `wolfram.exe` seats are limited; kill stale kernels with
  `taskkill /F /IM wolfram.exe` before a long batch.
- `TestReport["file.wlt"]` needs absolute paths or `SetDirectory` first.

## Miscellaneous

- `FactorList[poly, Modulus -> p]` gives the factorisation pattern used for
  Frobenius cycle types; skip primes dividing the discriminant.
- `IrreduciblePolynomialQ` accepts integer polynomials in one variable and is
  fast enough for enumerating small coefficient boxes.
- `LinearSolve[B, v]` on a rank-deficient `B` returns one particular
  solution; `NullSpace` returns rows.  `RowReduce` gives a canonical basis of
  a row space, convenient for de-duplicating embedded subspaces.
