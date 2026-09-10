# Notes on subtle Mathics behaviour

Findings collected while making `AsymptoticAnalysis` work in **Mathics3
10.0.1**, scanner 10.0.1, SymPy 1.14.0, and Python 3.11 on Windows. These are
observations about the tested interpreter, not promises about every Mathics
release. Linux CI exercises the same pinned Python packages separately.

This is the practical companion to [WOLFRAM-NOTES.md](WOLFRAM-NOTES.md).
The [compatibility guide](Mathics/COMPATIBILITY.md) records installation and
achieved package coverage; the [background comparison](Mathics/README.md)
provides broader context. Native Mathics examples below describe the
unadapted interpreter. Package-owned workarounds do not redefine its
`System` functions and are never loaded in the official Wolfram kernel.

## Starting and loading

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

## Streaming standalone source

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

## Control flow and evaluation budgets

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

## Messages and test harnesses

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

## Associations, lists, and held callables

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
  [LISTS.md](Mathics/LISTS.md).
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
  a failed evaluation with logarithms of positive products split into sums;
  see [NUMERICAL.md](Mathics/NUMERICAL.md).
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

## Exact assumptions and branch proofs

- Inline option values need protection as well as internal proof questions.
  Mathics rewrites `Element[Sin[a], Reals]` to `Element[a, Reals]`, although
  `a = Pi/2 + I` satisfies the first condition and violates the second. The
  held analytic boundary preserves membership heads inside inline immediate,
  delayed, and nested `Assumptions` rules before option evaluation. It keeps
  side effects under the original once-only option resolution. A value
  already rewritten in caller-side evaluation cannot be reconstructed. See
  [INPUT-ASSUMPTIONS.md](Mathics/INPUT-ASSUMPTIONS.md) for the precise boundary.
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
  See [ASSUMPTIONS.md](Mathics/ASSUMPTIONS.md) and
  [CALLABLES.md](Mathics/CALLABLES.md).

## Series, special functions, and numerical cores

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
  reporting successful evidence. See [ALGEBRA.md](Mathics/ALGEBRA.md).
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
  [NUMERICAL.md](Mathics/NUMERICAL.md) for supported examples and limitations.
- `Expand` can leave an exact cancellation such as matching `2^-x` terms
  or polynomial-logarithmic perturbative terms unreduced. In the Zeta and
  perturbative-inverse regressions, `Simplify`, `Together`, and
  `FullSimplify` each prove the difference exactly zero. Changing the exact
  normalizer is different from introducing a numerical tolerance.
- A numerical check at an exact quadratic root or principal Lambert value
  is a smoke test, not evidence for arbitrary-precision accuracy across a
  family. Exact interval certificates, asymptotic remainders, and numerical
  residual checks have distinct contracts.

## Display and preservation checks

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

## Incoming work reviewed during the compatibility campaign

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
