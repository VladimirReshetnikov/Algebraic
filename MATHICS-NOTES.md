# Notes on subtle Mathics behaviour

Reproducible observations about [Mathics3](https://mathics.org/), the
open-source Wolfram Language interpreter, collected while making this
repository's code run in it. They are a checklist, not a specification: every
entry records what a stated release actually did.

The companion [WOLFRAM-NOTES.md](WOLFRAM-NOTES.md) records the same kind of
observation for the official kernel. A Mathics workaround never changes what
the Wolfram kernel does, and no `System` symbol is ever redefined; the two
files are kept separate for that reason.

The first part comes from making the unified `algebraic/Algebraic.wl` package
of this repository run in Mathics3 10.0.1. The second was imported with the
asymptotic-inverse notes from the separate
[AsymptoticAnalysis](https://github.com/VladimirReshetnikov/Asymptotic)
project; its evaluator observations are general, but its examples and its
references to `validation/` files belong to that repository.

## Findings from the unified `Algebraic` package (Mathics3 10.0.1, September 2026)

Collected while making `algebraic/Algebraic.wl` run in Mathics3 10.0.1
(scanner 10.0.1, SymPy 1.14.0, mpmath 1.3.0, NumPy 2.4.6, Python 3.11.15 on
Windows) alongside Wolfram 15.0.1. Every item was reproduced on that
interpreter; none is a claim about other Mathics releases. The Wolfram side of
the same investigation, including the contracts the portable layer has to
reproduce, is in
[WOLFRAM-NOTES.md](WOLFRAM-NOTES.md#findings-from-merging-the-four-packages-into-algebraicalgebraicwl-wolfram-1501-september-2026).

The package confines all of this to one layer: names beginning with a
lower-case `k` in ``Algebraic`Private` `` stand in for System functions, and
the algorithms call only those. No `System` symbol is redefined, and the
Wolfram kernel takes the native branch of every one of them.

### Running it

- Install into an isolated **Python 3.11** environment: `python -m venv env`
  then `env/Scripts/python -m pip install Mathics3 packaging`. `packaging` is
  needed explicitly; Mathics 10.0.1 imports it from its number-theory module
  without declaring the dependency.
- Run a script with `python -X utf8 -m mathics --no-readline -q -f file.m`.
  The `-f`/`--file` option is the one that works: `-script file.m` and
  `-e file.m` were both accepted on the command line and then evaluated
  nothing, printing only the banner and `Goodbye!`. UTF-8 mode is needed on
  Windows so the printer can emit Wolfram syntax characters, and
  `--no-readline` avoids a startup error there.
- Set `$IterationLimit = 1000000` at the top of a script (see also
  [control flow and evaluation budgets](#control-flow-and-evaluation-budgets)
  below). The default 4096
  counts ownvalue substitutions across a whole input evaluation and stops
  valid work well short of an infinite loop.
- Standard output is block-buffered when redirected, and a Python-level crash
  loses whatever had not been flushed. When bisecting a crash, print a marker
  before each step and read the *last* marker, not the error.
- An unbalanced bracket is reported as `Syntax::sntxi` at the **end** of the
  file, with the last line's number, not at the opening bracket.

### Speed is not the problem; coverage is

`MinimalPolynomial`, `PossibleZeroQ`, `Factor` over the rationals, `Solve` up
to degree 4, `N[Root[f, k], 200]`, and `Det`/`NullSpace`/`RowReduce`/`Inverse`
on exact rational matrices of order 20 to 24 all return in milliseconds,
because they go straight to SymPy and mpmath. What costs time is Wolfram
Language interpretation between those calls, so the package scales its own
internal time allowances (`$kTimeScale`) rather than its algorithms.

### Rule ordering: a catch-all can beat an exact zero-argument definition

```wolfram
f[] := "specific"; f[___] := "catchall";
f[]        (* "catchall" *)
```

The order of the two definitions does not matter. Definitions with a fixed
positive arity *are* ranked correctly against `___` (`g[a_, b_] := ...` and
`h[a_Integer] := ...` both win over `g[___]`/`h[___]`), so this bites exactly
the zero-argument case. `AlgebraicKernelReport[]` was returning `$Failed` for
this reason; its argument-error definition is now `AlgebraicKernelReport[__]`.

### Control flow: only tagged `Catch`/`Throw` is portable

AsymptoticAnalysis reaches the same conclusion through its private module
adapter (see [control flow and evaluation budgets](#control-flow-and-evaluation-budgets)
below); the table records what each construct actually did.

| Construct | Wolfram 15.0.1 | Mathics 10.0.1 |
| --- | --- | --- |
| `Return[x]` directly in `Module` | returns from the function | same |
| `Return[x]` inside `Do` or `Table` | returns from the loop only | same |
| `Return[x]` inside `While` | returns from the function | **loop only** |
| `Return[x, Module]` anywhere | returns from the `Module` | **falls through** |
| `Throw[x, tag]` / `Catch[..., tag]` | returns from the `Catch` | same |

`Return[x, Module]` is not implemented at all — not inside a loop and not
directly inside a `Module`. It does not message; the value is discarded and
evaluation continues after the `Return`, so the function returns whatever
follows. The twelve `Return[..., Module]` calls in the radical descent and the
`Return[result]` inside the `While` of the precision-escalation loop were
therefore silently taking the wrong branch, and are now tagged throws or
loops restructured to exit through their condition.

### `Check` counts messages for the whole top-level evaluation

The [messages and test harnesses](#messages-and-test-harnesses) section
below records the same contamination for AsymptoticAnalysis; this is the
fuller characterization.

A two-argument `Check` takes its failure branch when *anything* earlier in the
same top-level evaluation issued a message or performed a `Print`:

```wolfram
{Take[{1, 2, 3}, UpTo[5]], Check[1 + 1, "poisoned"]}   (* {Take[...], "poisoned"} *)
{Print["progress"], Quiet[Check[1 + 1, "poisoned"]]}   (* {Null, "poisoned"} *)
Module[{}, Print["inner"]; Quiet[Check[1 + 1, "poisoned"]]]   (* "poisoned" *)
```

An inner `Quiet` does not help, and the `Print` may be several calls deep. An
outer `Quiet` that stops the earlier message from being issued at all does
prevent it (`Quiet[{1/0, Check[1 + 1, $Failed]}]` gives `2`), but
`Quiet[Print[...]]` still prints and still poisons.

The consequence for a package is that `Check` cannot be used anywhere, because
a caller's progress output — or the package's own `"Verbose"` option — turns
every later `Check` into a spurious failure. The unified package replaced all
eleven `Quiet[Check[expr, fail]]` calls with a `kCheck` that suppresses
messages and decides from the returned value. That is what the call sites
needed anyway: each one goes on to test the value with `PolynomialQ`, `ListQ`
or a degree check.

The first symptom was subtle: the load-time feature probes were written as one
association of `Check`-based comparisons, the `UpTo` probe messages, and every
probe after it in the association reported a missing builtin — including
`MinimalPolynomial`, which Mathics implements and the package depends on.

### Results that are wrong without any diagnostic

These are more dangerous than the crashes further down, because the value
looks plausible.

- **`Select` on an association tests the wrong object.**
  `Select[<|"p" -> True, "q" -> False|>, TrueQ]` is `<||>`, and
  `Select[..., ! TrueQ[#] &]` is the whole association. Both directions are
  wrong. Filter `Keys[assoc]` as a list and index back into the association.
- **`Transpose` of a one-row matrix is a flat list.** `Transpose[{{1, 2,
  3}}]` is `{1, 2, 3}` (Wolfram: `{{1}, {2}, {3}}`), and `MatrixQ` of the
  result is `False`; `Transpose[{{1}, {2}, {3}}]` is right. `LinearSolve`
  given that flat list aborts the evaluator (`TypeError: unsupported operand
  type(s) for +: 'One' and 'list'`), which is how a decomposition through a
  one-dimensional subspace died. The package uses `kTranspose`, a `Table`.
- **`MatrixPower[{{2}}, 3]` is `{8}`**, not `{{8}}`; `kMatrixPower` folds
  `Dot` over an identity matrix.
- **`Indeterminate == 0` aborts the evaluator** (`TypeError: Invalid NaN
  comparison`) instead of staying unevaluated, and so does any `==` whose
  operand evaluates numerically to NaN. `Cancel` of a quotient of nested
  radicals can return `Indeterminate`, which is how `Strad[(2^(1/3) -
  1)^(1/3)]` reached it inside the coefficient-list division of section 0.
  Test coefficients for `Indeterminate` before comparing them.
- **Assignment through a negative part index writes a different element.**
  `Module[{l = {1, 2, 3}}, l[[-1]] = 9; l]` gives `{1, 9, 3}`. The positive
  form `l[[Length[l]]] = 9` is correct. (The package had one such assignment,
  in the recursive product split.)
- **An unimplemented function inside an accessor yields the accessor's view of
  the unevaluated expression.** `MinimalBy` is not implemented, so
  `First[MinimalBy[list, f]]` evaluates to `First[MinimalBy[list, f]]` —
  that is, to `list`. A routine that picked the shortest vector of a lattice
  basis silently returned the entire basis. Whenever an unevaluated call is
  passed to `First`, `Last`, `Part` or `Length`, expect a plausible wrong
  value rather than an error.
- **`RandomChoice[list]` returns a one-element list**, where the Wolfram
  kernel returns the chosen element: `RandomChoice[{1, 2, 3}]` is `{2}`.
  The Galois engine drew a random integer weight this way, and the weight,
  the primitive element built from it and every conjugate that followed
  were lists; the group search then reported failure after its twelve
  tries. `First[RandomChoice[list]]` is what the package uses there.
- **Assignment into an association part is refused**, with
  `Set::write: Tag Association ... is Protected`, and the association is
  left unchanged: `assoc[key] = value` does nothing. A subgroup table built
  that way stayed a single entry and the whole subgroup lattice collapsed to
  the trivial subgroup; two caches never filled. Extend with `AssociateTo`
  (or, since that is missing too, `Join[assoc, <|key -> value|>]`).
- **`Association` applied to anything but a literal list of rules retains
  the unevaluated expression.** `Association[Table[k -> k^2, {k, 2}]]` is
  `<|Table[k -> k^2, {k, 2}]|>`, and so is `Association[Thread[...]]` and
  `Association[Options[f]]`; every key lookup on such an object misses.
  Evaluate the rules first and apply: `Association @@ Table[...]`. (Also
  recorded under [associations, lists, and held callables](#associations-lists-and-held-callables)
  below; it cost the denester its whole configuration.)
- **A string option name is stored as a symbol, and the option as
  `RuleDelayed`.** After `Options[f] = {"MaxTrials" -> 120}`, `Options[f]`
  is `{MaxTrials :> 120}`, so `First /@ Options[f]` are symbols and an
  association keyed by them answers `Missing` to `"MaxTrials"`.
  `OptionValue[f, rules, "MaxTrials"]` still works with the string. The
  package recovers the declared names with `SymbolName` on a kernel whose
  probe shows the conversion.
- **Applying a function through a `Part` expression makes a `Return` inside
  it return from the caller's loop.** With `g[q_] := Catch[Module[{u, v = q},
  If[True, Return["ret"]]; "no"], tg]` and `tbl = {{"name", g}}`,
  `Do[r = g[1]; Print[r], {k, 2}]` prints twice, but
  `Do[r = tbl[[1, 2]][1]; Print[r], {k, 2}]` prints nothing: the `Return`
  ends the `Do`. Binding first, `With[{fn = m[[2]]}, r = fn[1]]`, behaves
  correctly. The structural radical search dispatched its recognizers as
  `m[[2]][a, p, depth]`; the first one that declined ended the search, and
  no structural form was ever found.
- `Missing[key]` uses the **symbol** `KeyAbsent`, not the string:
  `<|"a" -> 1|>["b"]` is `Missing[KeyAbsent, "b"]` where Wolfram gives
  `Missing["KeyAbsent", "b"]`. Test with a `MissingQ` equivalent, never by
  comparing the literal.
- `Equal` on arbitrary-precision numbers is tolerant here, so a zero test on a
  small numerical scale must be written as `TrueQ[scale > 0]` rather than
  `TrueQ[scale == 0]`. (Also recorded under
  [associations, lists, and held callables](#associations-lists-and-held-callables) below.)

### Crashes that no `Quiet` or `Check` can catch

Each of these raises a Python exception that terminates the interpreter, so
they must be avoided structurally rather than guarded.

- `Simplify` applied to an expression containing a `Root` object:
  `AssertionError`. The package's `kSimplify` therefore refuses `Root` and
  `AlgebraicNumber` arguments on a kernel without `RootReduce`.
- `Root` with a named-argument pure function, `Root[Function[y, y^3 - 2], 1]`:
  `Root::nuni`, then `NotImplementedError` from the pure-function to SymPy
  conversion. Only the slot form `Root[Function @@ {poly /. x -> Slot[1]}, k]`
  works — which is what the packages already used.
- Part assignment through a list of indices,
  `b[[{i, j}]] = b[[{j, i}]]`: `AttributeError: 'NoneType' object has no
  attribute 'replace'`. The LLL reduction now swaps rows with `ReplacePart`.
- `Im[Indeterminate] == 0`: `TypeError: Invalid NaN comparison`. Test for
  `Indeterminate` and the infinities before any comparison on a numeric
  value. (Also recorded under
  [associations, lists, and held callables](#associations-lists-and-held-callables) below.)

### Part specifications and level arguments

Working: `m[[All, 1]]`, `m[[i ;;]]`, `m[[;; i]]`, `m[[{j, i}]]` for reading,
`Map[f, l, {2}]`, `Cases[e, patt, {0, Infinity}]`, `Cases[l, patt, {2}]`,
`Subsets[l, {k}]`, `Replace[l, r, {1}]`, `Flatten[l, 1]`, `Total`, `Pick`,
`Outer`, `Tuples`, nested part assignment `m[[i, j]] = v`.

Not working:

- `list[[All, "key"]]` and `list[[i ;;, "key"]]` on a list of associations:
  `Part::pspec`, left unevaluated. Use `#["key"] & /@ list`.
- `Join[m1, m2, 2]` (joining matrices horizontally): left unevaluated. Use
  `MapThread[Join, {m1, m2}]`.
- `Take[list, UpTo[n]]`: `Take::seqs`. Use `Take[list, Min[n, Length[list]]]`.
- `Position[expr, patt, {1}, 1]` and `FirstPosition` with a level
  specification, a default or `Heads -> False`: left unevaluated.

### `Root` objects, and what the algebraic engine does provide

Mathics' algebraic engine is stronger than the missing-function list suggests,
which is what makes the package portable at all.

- `Root[f, k]` exists, with the **same root ordering as Wolfram** — real roots
  first in increasing order, then conjugate pairs — checked on `#^3 - 2`,
  `#^4 - # - 1` and `#^2 - 2`.
- `N[Root[f, k], p]` works at arbitrary precision and for non-real roots;
  `N[expr, p]` for an `expr` built from `Root` objects by `Plus`, `Times`,
  `Power` and `Sqrt` runs but is machine-accurate as soon as a non-real
  value meets `Power`, `Sqrt` or division (next section).
- `MinimalPolynomial` handles radicals, `Root` objects, and arithmetic
  combinations of them: `MinimalPolynomial[Root[#^3 - 2 &, 1] + Sqrt[2], x]`
  is the correct degree-6 polynomial, in about five milliseconds. It refuses
  `AlgebraicNumber` objects (`MinimalPolynomial::nalg`).
- `PossibleZeroQ` decides exact algebraic differences correctly, including
  `Sqrt[5 + 2 Sqrt[6]] - Sqrt[2] - Sqrt[3]` and
  `Root[#^3 - 2 &, 1]^3 - 2`. `FullSimplify` proves the same nested-radical
  identity. Do not pass `Method -> "ExactAlgebraics"`; the option is not
  recognised and leaves the call unevaluated.
- **`N[Root[f, k], p]` is correct to `p` digits, but slow for non-real
  roots**, and the eleven-digit residual first blamed on it was the
  complex-arithmetic defect described in the next section: substituting the
  value back into `27436 + 112 #^3 + #^6` with `r^3` and `r^6` gives
  `1.1*10^-11`, evaluating the same polynomial by Horner's rule (products and
  sums only) gives `10^-56` at `p = 60` and `10^-116` at `p = 120`. The
  cost is the problem: the non-real root of that sextic takes 13 s at 60
  digits and 47 s at 120, a non-real root of `#^5 - 5 #^3 + 5 # - 3` 11 s at
  60 digits, while a real root of a quintic takes 0.05 s and every root at
  machine precision (`N[Root[f, k]]`) 0.01 s. The package therefore takes
  the machine value as an exact rational seed (`Round[x 10^14]/10^14`) and
  polishes it by Newton's method at the working precision -- 0.5 s to 60
  digits, 0.7 s to 130 -- with the residual checked and the kernel's own `N`
  as the fallback (section 0.5b of the package). The seed must be exact:
  `N[machineReal, 100]` stays a machine number, `N[rational, 100]` does not,
  and `Rationalize[x, 10^-13]` can return the machine number itself.
- **Machine-precision root ordering is the Wolfram kernel's** on every
  polynomial checked, so the seed of `Root[f, k]` polishes to the k-th root
  in Wolfram's order; the package relies on that.
- `MinimalPolynomial` on a **sum or product of `Root` objects** of degree
  six and up did not finish in a minute (`Root[27436 + #^6 + 112 #^3 &, 5]
  + 7 Root[#^3 - 2 &, 3]`), although on radicals and on single `Root`
  objects it takes milliseconds. Resultants by Sylvester determinant --
  `Det` of a 9x9 matrix with polynomial entries takes 0.6 s -- are the
  practical route; a Euclidean resultant recursion over polynomial
  coefficients exceeded `$RecursionLimit` (200) and returned a wrong
  value.
- `Root[f, k]` does **not** auto-simplify to radicals in low degree:
  `Root[#^2 - 2 &, 1]` stays a `Root` object where Wolfram gives `-Sqrt[2]`.
  A `RootReduce` replacement has to reproduce Wolfram's three regimes — see
  the Wolfram notes — or the two kernels print different (equal) answers.
- `NumericQ[Root[...]]` is `False` (Wolfram: `True`), and
  `Element[Root[...], Algebraics]` and `Element[Root[...], Reals]` are left
  unevaluated. `Root` arithmetic does not auto-evaluate either:
  `Root[#^3 - 2 &, 1]^3` stays unevaluated rather than becoming `2`.
- Not implemented: `RootReduce`, `ToRadicals`, `Decompose`, `Resultant`,
  `Discriminant`, `FactorList` (with or without `Modulus`),
  `Factor[..., Extension -> ...]`, `PolynomialQuotient`,
  `PolynomialRemainder`, `PolynomialGCD`, `PolynomialMod`,
  `IrreduciblePolynomialQ`, `SquareFreeQ`, `CoefficientRules`, `Cyclotomic`,
  `NSolve`, `NRoots`, `Roots`, `Reduce`, `Eliminate`, `GroebnerBasis`,
  `LatticeReduce`, `FindIntegerNullVector`, `Surd`, and `AlgebraicNumber`
  arithmetic. `Expand[expr, Modulus -> p]` *is* implemented, which is enough
  to build modular polynomial arithmetic.
- Also not implemented, from the list and association vocabulary the packages
  use: `Lookup`, `KeyExistsQ`, `AssociateTo`, `Merge`, `KeyDrop`, `MissingQ`,
  `FailureQ`, `SelectFirst`, `MinimalBy`, `DeleteDuplicatesBy`, `Ordering`,
  `ArrayReshape`, `ListConvolve`, `MemoryConstrained`, `Nothing`, and `Normal`
  on an association. `assoc[key]` reading and `Join` on associations work;
  `assoc[key] = value` is refused because `Association` is `Protected`.
- `TimeConstrained` works, including the three-argument form.
  `MemoryConstrained` does not, so a memory budget is simply not enforced
  there; the time budget still is.

### Complex arbitrary-precision arithmetic is partly machine precision

Measured with `z = N[7874506561843/12500000000000 - 545561817985861 I/10^14,
80]` and a Gaussian rational `q = 3/7 + 2 I/11`; every result below carries
`Precision` 80 (or the precision asked for), so nothing warns.

- **Exact** (error `10^-80`): `z + w`, `z w`, `-z`, `I z`, `z/2`, `z/7`,
  `Times @@ list`, `Total`, `Dot`, `Norm`, `Re`, `Im`, `Abs`, `Round`,
  `Floor`, `N[exactExpression, 80]` for an expression in Gaussian rationals
  (`N[q^6 + 112 q^3 + 27436, 80]` in 17 ms), and every real-argument
  function used by the package: `x^q` for real `x` (with the principal
  value `1 + Sqrt[3] I` for `(-8)^(1/3)`), `Exp`, `Log`, `Cos`, `Sin`,
  `Sqrt` of a negative real, `ArcTan[re, im]`.
- **Machine precision, reported as 80 digits**: `z^n` for every integer
  `n` other than 1 (`z^2` differs from `z z` by `10^-15`), `1/z`, `z/w`,
  `Divide`, `Conjugate[z]` (`10^-17`), `Sqrt[z]`, `z^(1/3)`, `Exp[z]`,
  `Log[z]`, `Exp[I theta]` for a real 80-digit `theta` (`2*10^-17`, while
  `Cos[theta] + I Sin[theta]` is exact), `Arg[z]` (returned as a machine
  number), and `N[Sqrt[q], 80]`, `N[q^(1/5), 80]` for a Gaussian rational
  `q` (`2*10^-17`). `x^k /. x -> z` and `Expand[z^2]` go through the same
  `Power`.
- A polynomial evaluated as `c . z^Range[0, n]` is therefore wrong at the
  eleventh digit; `Fold[#1 z + #2 &, 0, Reverse[c]]` is right. A power by
  repeated multiplication (`Fold[#1 z &, 1, Range[n]]`) is exact; but a
  squaring written `#1 #1` inside a pure function is `Power[#1, 2]` the
  moment the function is defined, and hits the same defect -- so does
  `z z` when the two factors are the same *symbol*, as in `Times[x, x]`
  with `x` later substituted.
- The package's `kN` (section 0.5b) evaluates an expression bottom-up on
  this kernel -- sums and products, integer powers by repeated
  multiplication, `1/z` from `Re` and `Im`, a complex `z^q` as
  `Abs[z]^q (Cos[q t] + I Sin[q t])` with `t = ArcTan[Re[z], Im[z]]`, `Exp`
  and `Log` likewise -- and hands a real base to the kernel's own `Power`.
  With that, the residual of a sextic root at 120 digits is `2*10^-126`
  and a nested cube-root identity checks to `10^-110`. The engine's own
  arithmetic on root values uses `kPowerList` and `kDivide` for the same
  reason. The load-time probe `"ComplexPower"` (`N[q, 40]^6` against the
  exact value) decides whether any of this is needed; on the Wolfram
  kernel it is not.
- **A conditional definition evaluates its left-hand side on reload.**
  `f[x_, y_] /; cond := rhs` is safe when `f` has no definitions, but once
  it has one -- on the second `Get` of the package, which a test harness
  and an example script both do -- Mathics evaluates `f[x_, y_]` with that
  definition, and the rule is attached to the head of whatever came out
  (`Tag Association in <|...|> is Protected`, plus the messages the body
  issued on pattern arguments). The Wolfram kernel holds the left-hand
  side. Put the condition inside the body.
- **A pattern `Complex[0, _Rational]` does not match the atom.**
  `MatchQ[Complex[0, 2/5], Complex[0, _Rational]]` is `True` in the
  Wolfram kernel (atoms with a "structural" form match such patterns) and
  `False` in Mathics; the same for `Rational[_, _]`. Test the head and
  `Re`/`Im` instead. `Exp[x]` is `Power[E, x]` in both kernels, so a rule
  written on `Exp[...]` never fires either.
- **`f[Plus[a__], w_]` does not do what it does in Wolfram.** Under a
  `Flat` head the sequence pattern binds `a` to the whole sum
  (`k[1 + x + y, 2]` with `k[Plus[a__], w_] := {a}` gives `{1 + x + y}`),
  and next to a catch-all `f[e_, w_]` the `Plus` rule is never chosen at
  all -- the same for `Times[a__]`. `f[e_Plus, w_]` with `List @@ e` works.
  `f[Plus[a_, b__], w_]` also works, binding `a` to the first term.

### `TimeConstrained` does not stop a long SymPy computation

`TimeConstrained[expr, t, fail]` is implemented with a timer thread that
raises `TimeoutException` in the evaluating thread through
`PyThreadState_SetAsyncExc` (`timed_threads.ThreadingTimeout`). The
exception is an `Exception`, and the `except Exception` clauses between
the timer and the work swallow it: a `TimeConstrained[..., 300]` around
the degree-9 product example ran for an hour, a 30 s budget around
`DenestReport` once ran for 2.4 hours, and the three-argument form was no
better. Where the whole computation is Mathics-level (loops, pattern
matching) the cooperative `check_stopped` does end it, which is why
`Strad`'s own budgets are honoured on cheaper inputs. The test driver
`run_mathics.py` enforces its limit itself: it evaluates each statement
in a worker thread, sets the evaluation's `stopped` flag past the limit,
then raises a `BaseException` subclass in the thread until it ends; the
statement is reported as `TIMEOUT` and the kernel goes on.

### Arithmetic in one algebraic number: reduce, do not eliminate

A polynomial in a single `Root` object `b` of an irreducible `f` has a
unique representative of degree below `deg f`, computable by one
polynomial remainder. On Mathics the package returns that representative
from `kRootReduce` (and decides `kExactZeroQ` from it), where the Wolfram
kernel would return a new `Root` object of the same value: the
representative is structurally canonical, so `===` on reduced coefficients
is an exact equality test, and it costs milliseconds against seconds for
the elimination plus numerical root index that a fresh `Root` object
needs. The eight functions of the functional decomposition, whose
coefficients live in such a field, got five to fifty times faster.

### Anything that refines a non-real `CRootOf` costs ten seconds

An in-thread profile (`ALGEBRAIC_PROFILE` in `run_mathics.py`) of the two
slowest cases -- a decomposition with a non-real quintic `Root`
coefficient (over 600 s) and a Gaussian binary-sum search (over 300 s)
-- put nearly all of the time into SymPy's `CRootOf` refinement
(`rootoftools.eval_rational`, 8 to 13 s per call), which is reached by:

- `N[Root[f, k], p]` and `N[Root[f, k]]` themselves;
- `PossibleZeroQ` on an expression containing a `Root` object: SymPy's
  `minimal_polynomial` (`_minpoly_add`, `_choose_factor`) refines every
  `CRootOf` in it, 45-146 s per call;
- native `MinimalPolynomial` on such an expression, the same way;
- a matrix operation whose entries contain a `Root` object: the pivot test
  `_iszero` asks the assumptions system whether the entry is zero, which
  evaluates it;
- `z^n` of a complex bignum inside the factor-selection residual (the
  machine-precision `Power` defect, which also made the selection wrong).

The package now keeps `Root` objects away from all of these on that
kernel: `kN`/`kRootValue` evaluate through the ordered eigenvalues and
Newton polishing, `kExactZeroQ` rejects at machine precision first and
decides a `Root`-containing zero by elimination (`selectFactor` recognises
the value zero), `kMinimalPolynomial` has no native fallback for such
input, and residuals use `kPowerList`. The two cases take 12.6 s and 46 s.

### Where the Galois engine stops on Mathics

With the numerics of section 0.5b in place, `RootGaloisData[Root[#^3 - 2
&, 1]]` takes 41 s and the quartic `#^4 - 10 #^2 + 1` with its subfield
lattice 18 s. `Sqrt[2] 3^(1/3)` (degree 6, group order 12) reaches its
full group at the third resolvent -- 6 s, 7 s and 21 s for the three
reductions -- and then stalls: the fourth resolvent is a degree-12
element plus a sextic root, whose elimination is a degree-72 resultant,
and the interpreted `kFactorList` that has to pick its irreducible factor
does not finish in twenty minutes. The Wolfram kernel's `MinimalPolynomial`
does the same step in milliseconds. `Failure` is a protected Global
symbol in Mathics: a stand-in definition needs `Unprotect` first.

### Every root of a polynomial numerically

- `NSolve`, `NRoots` and `Roots` are not implemented. `Solve[N[p] == 0, x]`
  returns every root as a machine number, but took 40 s on a degree-9
  polynomial and 42 s on degree 12 (0.4 s on a sextic); `FindRoot` from a
  complex start took 15 s and stopped at `FindRoot::maxiter` on a sextic.
  `N[Root[f, k]]` at machine precision is 0.05 s for a real root and four
  to ten seconds for each non-real root of a fresh polynomial.
- **`Eigenvalues` of the machine-number companion matrix** is complete and
  fast: 0.4 s for degree 5, 0.9 s for 6, 1.8 s for 9, 4.4 s for 12, 17 s for
  20, with the same residuals as `Solve` (both go through NumPy). Real roots
  come back with an imaginary part of order `10^-65`, so a tolerance
  decides which roots are real. The package's `machineRoots` (section 0.5b)
  is this, and `kRootValues` polishes each eigenvalue by Newton's method at
  the requested precision and sorts the list into the Wolfram kernel's
  `Root` order itself. (An earlier note here said `Eigenvalues` of a
  numerical matrix was wrong or slow; that was on an exact matrix.)
- **`Eigenvalues` of a badly scaled machine matrix aborts the
  interpreter.** On the companion matrix of a degree-12 resolvent with
  coefficients up to `2*10^14`, SymPy's `_eigenvals_eigenvects_mpmath`
  raised `PrecisionExhausted`, which no `Quiet` or `Check` catches; at 30
  digits it failed on a plain quartic. Balancing the polynomial first (`x =
  s y`, `s` the root-radius bound, every entry then at most 1) makes the
  same matrix solve in 0.6 s with residual `10^-13`; the roots are `s`
  times the eigenvalues.
- Durand-Kerner written in the language is not an option: 61 s for a
  sextic, 411 s for degree 12, at a millisecond or more per scalar
  operation.

### Testing

`VerificationTest`, `TestReport` and `TestResultObject` are absent; the
names are not even in ``System` ``, so `VerificationTest[1 + 1, 2]` is the
inert `VerificationTest[2, 2]`. That absence is what makes a portable runner
possible: a `VerificationTest` defined in `` Global` `` before the suite is
read is the one the suite's calls resolve to, and the same `.wlt` file runs
under `TestReport` in the Wolfram kernel and under that definition here.
`BeginTestSection`/`EndTestSection` need the same treatment.

### Package loading

`BeginPackage`, `Begin["`Private`"]`, `End`, `EndPackage`, usage messages,
`Options`/`OptionValue`/`OptionsPattern`, `SetAttributes`, `Unique`, message
definitions and `$Packages` all behave as expected, and after `Get` the
context path is `{"Algebraic`", "System`", "Global`"}` exactly as in Wolfram.
A `Get` of a single self-contained file needs no path handling, which is why
the merged package is one file.

## Findings imported with the asymptotic-inverse notes

From `AsymptoticAnalysis` on Mathics3 10.0.1, scanner 10.0.1, SymPy 1.14.0 and
Python 3.11 on Windows. The workarounds described are that package's, in its
own adapter context; the paths under `validation/` are in its repository, not
this one.

### Starting and loading

- Use an isolated Python 3.11 environment and
  [validation/requirements-mathics.txt](../validation/requirements-mathics.txt).
  `packaging` is included explicitly: Mathics 10.0.1 imports it from its
  number-theory module without declaring the dependency.
- On Windows, use `python -X utf8 -m mathics --no-readline`. Without
  `--no-readline`, the tested command-line interface can fail with an
  undefined `readline` name. UTF-8 mode also prevents output encoding errors
  when printing Wolfram syntax characters.
- Load a local modular checkout with
  `Get["src/Kernel/AsymptoticAnalysis.wl"]`, or load the self-contained
  `Get["AsymptoticAnalysis.wl"]`. The latter needs no sibling kernel files.
  Native Wolfram HTTP-loading observations in the companion notes do not
  establish Mathics HTTP compatibility; a downloaded local file is the
  reproducible Mathics entry point used here.
- Parse package calls after `Get` returns. A single `--code` string containing
  both `Get` and an initially unknown exported function can bind that function
  in `Global` before `BeginPackage` runs. Separate input expressions or a
  streaming `.wl` script avoid that ambiguity.
- `ClearAll` alone does not make an unqualified name bind to a new adapter
  symbol when a `System` symbol has the same name. The package temporarily
  prepends its adapter context while reading implementation definitions.
  Mathics `EndPackage` retains an inserted context, so the package explicitly
  removes that context from the public search path after loading.
- Missing public option, function, and formal-symbol names must have a shared
  context. Otherwise an unimplemented name such as `SeriesTermGoal`,
  `BarnesG`, or `\[FormalL]` can become private inside the package but global
  in caller input. Creating an inert `System` name aligns syntax; it does not
  supply a backend implementation.
- Reloading can evaluate an old private definition while reading a new
  left-hand side. The Mathics loader clears package-private definitions
  first. Similarly, late overrides retain existing downvalues as data,
  clear their dispatch symbol, then install the new rules.

### Streaming standalone source

- Keep `Begin`, definitions, and `End` as separately parsed statements.
  Parsing a whole adapter before evaluating its `Begin` binds its symbols
  in the wrong context. The standalone builder stores adapter statements as
  strings and uses `Scan[ToExpression, ...]` only in Mathics.
- A semicolon is not always a statement terminator. `Condition` uses `/;`
  and `Span` uses `;;`. A splitter that handles strings, comments, and bracket
  nesting but overlooks these operators corrupts top-level conditional
  definitions. The first broad standalone run exposed this; the corrected
  builder has an explicit regression for both operators and open spans.
- A successful `Get`, registered package context, or working first example
  does not establish a clean load. Check diagnostics, exported contexts,
  representative definitions, repeated loading, and both distribution forms.

### Control flow and evaluation budgets

- Mathics 10.0.1 does not implement `Return[value, Module]`, and ordinary
  returns can be intercepted by loops. The package uses a private module
  adapter with a distinct `Catch`/`Throw` tag per invocation, including nested
  modules and initializers. It does not replace native `Module` or `Return`.
- `$IterationLimit` counts nonliteral ownvalue substitutions throughout an
  input evaluation. A finite, valid calculation can exhaust the default
  4096, so hitting the limit does not by itself demonstrate an infinite
  rewrite loop. The portable harness explicitly sets and records
  `$IterationLimit = 1000000` on Mathics. The package leaves the user's global
  setting alone; configure it explicitly for substantial calculations.
- Mathics interpretation is slower than the compiled Wolfram evaluator.
  Internal symbolic proof attempts receive four times their original time
  allowance. This changes the available computation time, not the proof
  criterion or fallback. Explicit `CoreCheckTimeConstraint` values and the
  documented five-second callable-application guard are excluded from this
  scaling. `MaxTerms` and outer process timeouts remain independent limits.
- A symbolic finite `Sum` can evaluate its body before binding its iterator.
  A derivative order such as `D[f, {x, n}]` can then reach Python with
  symbolic `n` and crash. Where this occurs in finite perturbative and
  logarithmic formulas, the adapter uses `Total[Table[...]]` with the same
  bounds and coefficients.

### Messages and test harnesses

- Mathics' two-argument `Check` can count an earlier `Print` in the same
  top-level evaluation as an error from the checked expression. For example,
  progress output followed by `Check` inside one compound expression can
  select the fallback even though the calculation issued no message. Keep
  progress output in a separate evaluation; print test diagnostics after
  evaluating the assertion. Do not bypass a failed proof because its failure
  might have this cause—remove the harness contamination and rerun it.
- Evaluate each case in a fresh process. A missing feature may leave an
  expression unevaluated, emit messages, return a structured failure, or
  raise a Python exception. These are different outcomes and must remain
  visible in the receipt.
- On Windows, a virtual-environment Python launcher can spawn a second
  interpreter process. Killing only the launcher on timeout leaves the
  calculation running. The runner terminates its owned process tree;
  POSIX runs use an owned process group. Never kill all Python or Wolfram
  processes when other worktrees are active.
- Freeze the suite before a multi-case run and fingerprint the package
  sources. Editing the suite while successive kernels read it can produce
  misleading syntax errors or mix different tests in one report. Partial,
  interrupted, and changed-source runs are explicitly incomplete.
- Require successful package loading before selecting any assertion. A test
  such as `Check[1 + 1, $Failed]` can pass even after an empty or failed load.
  The suite checks the load result, registered package, context path, and
  restored global context in a separate top-level input. The integration
  checker exercises five failed/incomplete loaders and both real entry points.
- Reject nonfinite or nonpositive process timeouts before starting a kernel.
  Protect input paths from report output and its temporary sibling, including
  aliases. Once source drift is observed, retain the failed stability flag
  even if the original bytes later return. Receipt integrity is separate from
  a mathematical feature assertion.

### Associations, lists, and held callables

- Mapping over an empty list can invalidate its internal evaluation cache.
  Even `b = {}; f /@ b; {b, 2, 0}` can raise a Python `AssertionError` in
  unadapted Mathics. Package-owned public, private, and compatibility definitions
  use an adapter that returns
  an empty list directly for exactly this two-argument `Map` case. It
  retains evaluation of the function expression, applies that function zero
  times, and delegates other forms to native `Map`. Flat-sector operations
  and Fourier residual metadata exercise this boundary. Empty-key and
  empty-association `Lookup` calls require the same protection, including
  preservation of default evaluation counts and subsequent list reuse. An
  empty first list denotes an empty rule collection: its scalar lookup uses
  the default once. An empty key list uses it zero times; multiple missing
  results share one lazy default. See
  [LISTS.md](docs/Mathics/LISTS.md).
- `Equal` on arbitrary-precision numbers is tolerant in Mathics 10.0.1:
  `N[10^-12, 10] == 0` evaluates to `True`, while `N[10^-12, 10] > 0` is
  `True` as well; Wolfram returns `False` for the equality. A zero test on a
  small numerical scale must therefore be written as `TrueQ[scale > 0]`
  rather than `TrueQ[scale == 0]`; the numerical checker's `"Ratio"` was
  `Indeterminate` on Mathics for every small remainder scale until it did.
- `NumericQ[Indeterminate]` is `True` in Mathics 10.0.1 (`False` in Wolfram),
  and `Im[Indeterminate] == 0` raises a Python `TypeError` ("Invalid NaN
  comparison") that aborts the evaluator. Every package numerical consumer
  now tests `finiteNumericQ`, which also excludes `Indeterminate` and
  infinities, before any realness comparison.
- Arbitrary-precision `N[Log[c r], n]` returns `Indeterminate` when `c` is an
  irrational constant such as `Sqrt[Pi]`, `Pi` or `E` and the rational `r` is
  below about `10^-17`, although `N[Log[c] + Log[r], n]` and the machine
  precision `N[Log[c r]]` evaluate. A tail target `Erfc[x] = 10^-20` reaches
  this form through `Log[Sqrt[Pi] y]`. The Mathics numerical adapter retries
  a failed evaluation with logarithms of products split into sums when an
  exact positive grammar proves every factor positive; a machine-precision
  sign is not a branch proof, since it rounds `10^-400` to zero and can round
  an exactly negative factor to a positive number. See
  [NUMERICAL.md](docs/Mathics/NUMERICAL.md).
- The explicit `Erfc`, `LogGamma`, `Gamma` and `LambertThreshold` adapters of
  `AsymptoticSpecialInverse` exceed the default `$IterationLimit` of 4096 and
  need the raised session limit; each then takes roughly one to one and a
  half minutes on the tested Windows interpreter.
- `KeyExistsQ` is not implemented in Mathics 10.0.1: `KeyExistsQ[<|"k" -> 1|>, "k"]`
  stays unevaluated, even for a plain association. The package supplies its
  own adapter inside its compatibility context, so package code may use it,
  but caller-side tests and examples must not. A portable case checks key
  absence through the result accessor instead, for example
  `Head[s["RemainderLowerBound"]] === Missing`.
- Mathics' three-argument `ToExpression` can evaluate the parsed expression
  before its wrapper holds it. When inspecting existing private symbols,
  parse a call to a `HoldAllComplete` helper containing the symbol name.
  This keeps effectful ownvalues from running during adapter installation.
- `Association[Map[...]]` and `Association[Reap[...][[2]]]` can retain the
  unevaluated rule-producing expression. Evaluate the rules first, then use
  `Association @@ rules`. This fixes retained refinement frontiers and
  finite-depth regions without replacing their enumeration algorithms.
- Assigning to the final list entry with `list[[-1]] = value` can raise a
  Python `IndexError`, even for a nonempty one-element list. The equivalent
  positive index `list[[Length[list]]]` fixes certificate history updates.
- Lookup defaults must stay lazy. Missing-key handling, ordered lists of
  keys, association updates, and key selection have bounded package-local
  adapters; an unevaluated lookup must not be mistaken for a successful
  membership proof.
- Mathics' `FirstPosition` implementation does not provide the pattern and
  `Heads` behaviour needed here. The adapter uses `Position` with the
  requested levels and head policy, then selects the first position.
- Named `Function` parameters need the three-argument
  `Extract[function, {1}, HoldComplete]`. Mathics lacks this form. Traverse
  the held expression without releasing a formal parameter's ownvalue, and
  apply the wrapper only after reaching the part. Ordinary function
  application remains responsible for lexical binding and capture avoidance.
- `Take[..., UpTo[n]]` needs a bounded adapter. Check empty and shorter
  sequences as well as a full sequence; incomplete sectors must not turn
  into unevaluated `Take` expressions in result metadata.

### Exact assumptions and branch proofs

- Inline option values need protection as well as internal proof questions.
  Mathics rewrites `Element[Sin[a], Reals]` to `Element[a, Reals]`, although
  `a = Pi/2 + I` satisfies the first condition and violates the second. The
  held analytic boundary preserves applied membership heads inside inline
  immediate, delayed, and nested `Assumptions` rules and inside inline
  `ConditionalExpression` conditions before option evaluation. It keeps
  side effects under the original once-only option resolution, leaves a bare
  `Element` symbol that an option program holds as data untouched, and does
  not descend below `Hold`-family barriers. A value already rewritten in
  caller-side evaluation cannot be reconstructed. See
  [INPUT-ASSUMPTIONS.md](docs/Mathics/INPUT-ASSUMPTIONS.md) for the precise boundary.
- Native symbolic `Element[Log[a], Reals]` can lose the logarithm's positive
  domain before assumptions are considered. Internal realness questions
  therefore use a held adapter. Already evaluated caller input cannot be
  reconstructed afterward.
- Numeric-function status does not guarantee that Mathics can decide exact
  realness. An unresolved native membership question must still reach
  structural proof rules; for example, positivity of the exact Glaisher
  constant proves its logarithm real in the Barnes expansion.
- A real difference does not prove ordered operands real. Canceling the
  offset in `u + I > I` is invalid, and `u + a > a` requires realness of `a`.
  Both the affine proof and the boundary before native simplification check
  real operands. Complex equality and inequality remain legitimate:
  `u + I != I` holds for positive real `u`.
- Collect unconditional facts from conjunctions, not individual branches
  of `Or`, negations, or quantified formulas. Unknown means unproved.
  Realness alone does not prove `Log[a]` real or `1/a` finite; nonzero and
  sign conditions matter. `a b > 0` proves the reciprocal product positive
  without proving either factor real individually.
- Do not use `PowerExpand` to force square-root or fractional-power
  identities. `Sqrt[a^2]` can become `a`, `-a`, or `Abs[a]` only with the
  corresponding branch facts. Factoring a small polynomial square requires
  an exact identity check and must not remove a rational singularity.
- A finite search for inverse candidates is not a completeness proof.
  The Mathics extension admits a bounded polynomial/affine class through
  real-domain, interval, and derivative proofs. Disconnected or otherwise
  unproved domains remain conservative failures. A failed finite search for
  a small enough neighborhood establishes no negative mathematical theorem.
- Wolfram can evaluate `InverseFunction` before package dispatch while
  Mathics leaves the operator intact. Test that runtime boundary explicitly;
  do not alter the Wolfram branch to make it resemble Mathics.
  See [ASSUMPTIONS.md](docs/Mathics/ASSUMPTIONS.md) and
  [CALLABLES.md](docs/Mathics/CALLABLES.md).

### Series, special functions, and numerical cores

- Native Mathics `Series` does not accept the same assumptions options, and
  its `Limit` interface uses numeric direction conventions. The local
  adapters apply an assumption scope and translate directions; they do not
  claim Wolfram's complete symbolic limit or asymptotic engine.
- A missing Taylor expansion can be supplied from a convergent defining
  series only with its domain and tail preserved. The hypergeometric and
  PolyLog adapters restrict arity, denominator parameters, convergence class,
  argument shape, and the surrounding multiplier, and return explicit
  `SeriesData` order. A surrounding pole could amplify an omitted
  coefficient and is not admitted by this bounded shortcut.
- Gamma and Barnes G asymptotic corrections are Poincare expansions.
  Bernoulli tails must remain attached; computing a finite polynomial model
  never makes the original special function exact.
- Unimplemented univariate `CoefficientRules` can leave a finite inverse
  formula correct while corrupting its remainder metadata. Validate both.
  Likewise, Fourier exponential identities do not replace the separate
  real-conjugacy and frequency-budget checks.
- The tested Mathics two-argument `ProductLog[k, z]` lacks a numerical arity
  implementation and converts to SymPy using the wrong argument order. In particular,
  `N[ProductLog[0, E]]` can return `-Infinity`. Package-created principal
  values use the exact equivalent `ProductLog[z]` before specialization;
  `ProductLog[E]` gives 1. Symbolic lower-branch formulas do not establish
  reliable nonprincipal numerical evaluation. Exact `s[value]` substitution
  remains useful, but external `N` can produce wrong complex values for
  surrounding functions while leaving `ProductLog` unresolved. The tested
  lower-branch numerical checker declines an unproved branch instead of
  reporting successful evidence. See [ALGEBRA.md](docs/Mathics/ALGEBRA.md).
- The same `ProductLog` conversion can turn a satisfiable symbolic equality
  into `False`, even without numerical evaluation. Package simplifiers and
  the assumption walker keep retained two-argument branch values unresolved.
  Raw exact values and Booleans already changed before adapter entry cannot
  be recovered; exact specialization is therefore also limited.
- Native Mathics `FindRoot` can return a machine-precision reference while
  ignoring a higher working precision. Package numerical consumers now
  refuse unavailable reference precision explicitly. An unchanged integer
  seed is accepted exactly only after exact polynomial substitution proves
  the root. No nearby rational is guessed or approximate digits padded. See
  [NUMERICAL.md](docs/Mathics/NUMERICAL.md) for supported examples and limitations.
- `Expand` can leave an exact cancellation such as matching `2^-x` terms
  or polynomial-logarithmic perturbative terms unreduced. In the Zeta and
  perturbative-inverse regressions, `Simplify`, `Together`, and
  `FullSimplify` each prove the difference exactly zero. Changing the exact
  normalizer is different from introducing a numerical tolerance.
- A numerical check at an exact quadratic root or principal Lambert value
  is a smoke test, not evidence for arbitrary-precision accuracy across a
  family. Exact interval certificates, asymptotic remainders, and numerical
  residual checks have distinct contracts.

### Display and preservation checks

- Native Mathics tag assignment rejects some valid arithmetic upvalue
  declarations. Build the held package-owned rules with automatic arithmetic
  disabled, then install the complete set once. Installing rules one at a
  time can evaluate later left-hand sides. Repeated `UpValues` retrieval can
  also introduce redundant `HoldPattern` wrappers, which must be normalized
  when avoiding duplicate rules on reload.
- A pattern-variable `Format` declaration can attach to the wrong protected
  head. Use an explicit result head for the Mathics-only OutputForm rule.
  Notebook box behaviour is a separate capability from exact computation;
  inspect `Normal[s]`, `s["Remainder"]`, and `InputForm[s]` directly.
- Preserve official-kernel behaviour by excluding adapter parsing as well as
  evaluation. Compare attributes, options, all value tables, messages,
  formatting/default values, contexts, and selected native builtins in fresh
  load/reload kernels. These checks complement executable regressions;
  neither alone proves equivalence in every possible surrounding program.
- When other worktrees publish independent fixes, compare Mathics-only
  changes against the updated upstream control. Retain earlier full-suite
  evidence under its original source hashes instead of relabeling it as a
  test of the new upstream code. The
  [preservation receipt](../validation/mathics-wolfram-preservation.json)
  records these stages separately.

### Incoming work reviewed during the compatibility campaign

- The `5b2b6cd` review fixes were inspected at the exact-exponent collection
  and composition-parameter boundaries. In particular, composition retains
  complete source/operation dependencies and replays a captured parameter
  only along an exact inner forward source, instead of treating the old
  remainder as uniform. These changes are included in the current Mathics
  regression snapshots; representative composition checks also pass.
- The `6195452` native-view fix checks the denominator, signed endpoints,
  and their difference before constructing dense `SeriesData`. The optional
  view can decline an unrepresentable native index while the sparse
  expression and analytic remainder remain intact. Source review found the
  index and span checks in the correct order before allocation. Mathics
  provides the `$SystemWordLength` symbol used by this guard.
- The `1ced1ae` rule-goal fix, merged through `a55df16`, reuses already
  evaluated common options for native leading requests. The new routing is
  confined to explicit scalar rule specifications and leaves package cutoff
  validation and explicit native backend selection in their existing paths.
  The source review checked that reuse; the upstream native tests are a
  separate validation record.
- The peer review identified a race in the new native-definition harness:
  package snapshots were frozen but the capture script was read live for
  each kernel. The runner now executes a frozen, hashed script and rejects
  source or snapshot drift. Focused tests deliberately change both forms
  during a mocked multi-kernel run and require failure.
- These were focused source and compatibility reviews, not independent
  reruns of every upstream review package. Their own validation receipts
  retain their separate scopes. Later upstream code changes require a fresh
  native control and relevant Mathics checks, even if a Git merge is clean.
