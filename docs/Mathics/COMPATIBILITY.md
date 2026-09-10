# Running AsymptoticAnalysis in Mathics3

**Complete compatibility with [Mathics3](https://mathics.org/), alongside the
official Wolfram kernel, is a project goal. It is not yet achieved.** The goal
covers the package's public operations and their mathematical contracts;
successful loading and selected examples are intermediate milestones.

Mathics support is being developed and tested against **Mathics3 10.0.1**
with scanner 10.0.1, SymPy 1.14.0, and Python 3.11. The package's declared
Wolfram Language requirement and Wolfram functionality are unchanged.

The [background notes](README.md) describe the language and evaluator
differences. This page tracks the package's actual compatibility work;
background claims about an interpreter are not evidence that a package
feature has passed a regression test.
The maintained [Mathics implementation notes](../MATHICS-NOTES.md) collect
reproducible evaluator gotchas in the same form as the Wolfram notes.
The [portable validation guide](PORTABLE-VALIDATION.md) explains what the
runner and acceptance verifier check, along with their source-provenance,
loading, timeout, and interpreter-selection limits.

## Goal and current status

| Area | Current status | Work needed for complete compatibility |
| --- | --- | --- |
| Modular and standalone loading | Mathics-specific bootstrap and evaluator adapters are implemented. | Preserve clean loading, reloads, namespace isolation, and generated-source parity as both kernels evolve. |
| Symbolic expansions and operations | Focused examples exercise inverse and forward calculus, arithmetic, refinement, and selected extended scales. | Validate the full supported public input and option space, including exceptional and resource-limited paths. |
| Assumptions and inverse branches | Conservative exact rules cover selected polynomial and affine-domain proofs. | Extend unresolved domains and sign/uniqueness proofs without weakening branch hypotheses. |
| Native backends and special functions | Coverage depends on the interpreter's available functions and package adapters. | Close missing functionality and parameter-range gaps; an inert native symbol is not compatibility. |
| Numerical checks, certificates, and display | Exact rational certificate examples and numerical precision contracts are checked; unavailable Mathics root precision is refused explicitly. | Supply reliable arbitrary-precision reference roots, extend certificate coverage, and validate front-end presentation. |
| Consolidated acceptance | All 101 portable cases pass in both layouts on Linux at `ffe08b1`; later upstream logarithm changes have separate focused checks and native comparisons. | Extend acceptance to remaining input/option ranges and keep results tied to each tested source revision. |

The limitations below describe remaining work, not a permanently reduced
Mathics feature target. Until a proof or operation is supported, a clear
failure or unresolved result preserves the package's mathematical contract;
it does not count as successful compatibility for that input. The
[validation section](#validation-and-remaining-work) distinguishes executed
checks from the remaining acceptance work.

## Install and load

Use an isolated **Python 3.11** environment:

```text
python -m venv .venv/mathics
.venv/mathics/Scripts/python -m pip install -r validation/requirements-mathics.txt
.venv/mathics/Scripts/python -X utf8 -m mathics --no-readline
```

On Linux or macOS, replace `.venv/mathics/Scripts/python` with
`.venv/mathics/bin/python`. The `--no-readline` option avoids a Mathics 10.0.1
Windows command-line startup error. UTF-8 mode allows the command-line
printer to emit Wolfram syntax characters on Windows. `packaging` is included
in the requirements because the Mathics number-theory module imports it even
though Mathics 10.0.1 does not declare it as an installation dependency.

Load either entry point from the repository root:

```wolfram
Get["src/Kernel/AsymptoticAnalysis.wl"];
(* Or use the generated, self-contained AsymptoticAnalysis.wl. *)
If[StringContainsQ[$Version, "Mathics"], $IterationLimit = 1000000];

s = AsymptoticInverse[x + x^2, {x, 0}, {y, 4}];
Normal[s]
s["Remainder"]
```

Evaluate `Get` before parsing subsequent package calls. A command-line
`--code` string containing both the load and a first package call is parsed
as one expression; its previously unknown function names can bind to
the `Global` context. Separate input expressions or a `.wl` script preserve streaming
package context resolution.

The larger iteration budget is an explicit Mathics session setting. Mathics
counts nonliteral ownvalue substitutions throughout an input evaluation;
its default of 4096 can stop valid package calculations, including a modest
Gamma expansion. The package does not change this global setting itself.
Package term limits and the regression runner's process timeout remain in
force independently of the evaluator budget.

## Isolation from the Wolfram kernel

Only Mathics loads the compatibility modules. Package implementation symbols
then resolve selected missing or incompatible operations through
the ``AsymptoticAnalysis`Mathics`` context. The adapter context is removed from
the public context path at the end of loading. No Mathics `System` function is patched.
Missing inert system names used in public input, such as `SeriesTermGoal`,
are established so caller input and package patterns use the same symbols.
An inert name does not imply an implemented backend or special function.

The standalone builder preserves this isolation by storing Mathics bootstrap
statements as strings and parsing them one at a time only on Mathics. Thus
an official Wolfram kernel does not even create the adapter symbols. The
original arithmetic and formatting declarations still execute on Wolfram;
Mathics uses equivalent package-owned declarations where its tag assignment
checks reject the original forms.

## Compatibility subtleties

* **Early returns:** Mathics 10.0.1 does not implement
  `Return[value, Module]`. Its ordinary returns can be intercepted by loops.
  The package adapter uses a distinct `Catch`/`Throw` tag for each module,
  including nested calls and module initializers.
* **Associations:** the package supplies bounded adapters for lookup,
  membership, updates, and key selection. A missing-key lookup evaluates its
  default only when needed; list-valued lookups preserve key order.
* **Empty lists:** native Mathics mapping can invalidate the cache of a
  reused empty list and crash later metadata construction. Package-owned
  maps return an empty list directly in the exact two-argument empty case;
  other forms retain native behavior. This enables flat-sector operations
  and empty Fourier residuals. See [list semantics](LISTS.md).
* **Simplification:** Mathics can raise a Python exception for atomic
  assumptions in two-argument simplification. The adapter passes an
  equivalent list of assumptions. Its algebraic and inequality reasoning
  remains more limited than Wolfram's.
  A conservative [exact assumption adapter](ASSUMPTIONS.md) proves finite
  realness and signs from explicit conjunctions, preserving unresolved
  branches. It does not implement quantifier elimination.
  Held analytic entry points also preserve membership predicates inside
  inline `Assumptions` values before native Mathics can weaken them. Immediate
  and delayed values retain their evaluation counts. Conditions already
  changed during caller-side evaluation cannot be recovered; see the
  [inline assumption boundary](INPUT-ASSUMPTIONS.md).
  Unresolved ordered predicates are kept out of native simplification until
  their operands are proved real. This prevents cancellation of a common
  complex offset from manufacturing a real inequality.
  Retained two-argument `ProductLog` values also bypass native simplification
  and the assumption walker, because Mathics' SymPy conversion can return
  an incorrect Boolean for a satisfiable branch equality. Already evaluated
  caller values cannot be recovered; see [the precise boundary](ALGEBRA.md).
* **Held callables:** named `Function` parameters require the three-argument
  held `Extract` operation that Mathics lacks. The adapter preserves held
  parameters and lexical binding while traversing the requested parts.
  See [callable and inverse-branch contracts](CALLABLES.md) for the bounded
  polynomial and affine-domain proofs. Wolfram can evaluate `InverseFunction`
  before package dispatch; two regression cases explicitly record the
  resulting runtime difference instead of requiring a false parity claim.
* **Messages and `Check`:** Mathics 10's two-argument `Check` can treat an
  earlier `Print` in the same input evaluation as an error from its checked
  expression. Evaluate progress output in a separate input. Regression
  diagnostics are emitted after the tested calculation for this reason.
* **Finite derivative sums:** Mathics can evaluate a symbolic derivative
  index before binding a finite `Sum`. The perturbative inverse and
  logarithmic Euler adapters use equivalent finite tables.
* **Certificates:** the Mathics adapter updates the final history entry
  using its positive list index. Mathics 10 can otherwise raise a Python
  `IndexError` for the equivalent negative-index assignment.
* **Retained refinement:** computed association rule lists are evaluated
  before constructing refinement frontiers and depth regions. Successive
  refinements preserve the original source object and transport its remainder.
* **Exact numbers:** unsupported algebraic-number normalization retains an
  exact symbolic expression and uses exact simplification. It never replaces
  an exact exponent or coefficient by a floating-point approximation.
* **Taylor series:** local package Taylor calls apply assumptions in a
  scope because Mathics `Series` does not accept the Wolfram assumptions
  option. Native backend requests retain their distinct native contract.
  The limit adapter maps Wolfram direction strings to Mathics' numeric
  direction convention; Mathics' native limit engine has limited assumption
  handling, so parameter-dependent limits still need individual validation.
  Bounded defining-series adapters additionally support `Hypergeometric0F1`,
  `Hypergeometric1F1`, `Hypergeometric2F1`, convergent `HypergeometricPFQ`, and
  `PolyLog` at a vanishing monomial argument. Positive denominator parameters,
  exact function arity, a constant outer multiplier, and an explicit order
  term prevent unsupported continuation or lost tails. This also supplies the
  ordinary Bessel J origin expansion through the existing Frobenius identity.
* **Gamma asymptotics:** a finite large-positive-argument Stirling model
  supplies the missing native `LogGamma` series to the existing jet algebra.
  Its Bernoulli tail remains a Poincare remainder, with term limits enforced;
  it is never reported as an exact expansion. See
  [DLMF 5.11](https://dlmf.nist.gov/5.11).
* **Fourier and exact cores:** bounded coefficient rules and trigonometric
  identities preserve inverse coefficients and sector metadata. Principal
  Lambert expressions are normalized to one-argument `ProductLog` before
  numerical specialization, avoiding Mathics' unsupported two-argument
  numerical form and incorrect argument order when converting it to SymPy.
  Retained exact nonprincipal formulas remain available, subject to Mathics'
  own exact pre-evaluation defects; applying native Mathics `N`
  to them can produce incorrect surrounding values. Numerical nonprincipal Lambert evaluation
  remains unsupported; see [algebra and core-function details](ALGEBRA.md).
* **Numerical precision:** Mathics `FindRoot` can ignore working precision
  and return machine digits. The package refuses unavailable reference-root
  precision explicitly, except for an unchanged integer seed proved to be
  an exact polynomial root by substitution. Lower precision requests still
  check achieved precision. See [numerical contracts](NUMERICAL.md).
* **Time budgets:** internal symbolic proof attempts receive four times their
  Wolfram wall-clock allowance because Mathics interpretation is slower.
  Proof criteria and fallbacks are unchanged. Explicit `CoreCheckTimeConstraint`
  values and the documented five-second callable-application guard keep their
  original deadlines. User calls to ``System`TimeConstrained`` are unaffected.
* **Display:** Mathics and Wolfram front ends have different box support.
  Use `Normal[s]`, `s["Remainder"]`, and `InputForm[s]` when inspecting
  computation results independently of their display.

## Validation and remaining work

Run the portable exact regression suite with:

```text
python validation/run_mathics_tests.py --python .venv/mathics/Scripts/python.exe --timeout 300
python validation/run_mathics_tests.py --python .venv/mathics/Scripts/python.exe --source AsymptoticAnalysis.wl --timeout 300
python validation/run_mathics_tests.py --wolfram wolfram.exe
```

Use `--list` to list cases and `--case` or `--group` to select a focused run.
Each case has a fresh kernel and a process timeout. Reports retain exact
expected and actual values, interpreter diagnostics, and source hashes.
An interrupted run or one that overlaps source edits is not an acceptance
record. The portable suite supplements the existing Wolfram MUnit suite.

The suite now contains **120 cases**. The newest cases check the omitted-interval
certificate diagnostic, Zeta truncation bound transport, exact affine certificate translation the local-coordinate numerical check at a `10^100` offset, explicit coefficient power precedence, the residual target-offset label, and the explicit `Erfc`, `LogGamma`, `Gamma` and `LambertThreshold` adapters with the Erfc numerical contract; the earlier wave-4 additions cover reused empty
lookup lists, shared lazy defaults, an empty inverse multi-index, conservative
nonprincipal branch proofs, and numerical precision. The final focused Windows
checks pass **8/8 in both layouts on both kernels**, including the strengthened
integer-root precision assertion. The corrected empty-rule-collection semantics
match the official controls, and earlier incorrect inferred fixtures remain
preserved. Both runtimes also pass **11/11 loading fixtures**. The
[wave-4 validation record](../../validation/README.md#mathics-wave-4-hardening)
links those raw reports and seven successful Fourier contracts per loader.
A complete 108-case run is not claimed by these focused checks; its separate
Linux run uses immutable `26a1154`, while the earlier complete checkpoint is
identified below.

The [API inventory](API-COVERAGE.md) maps all 38 exported symbols to exact
portable cases and remaining input/option gaps. The complete
[Linux acceptance record](../../validation/mathics-linux-ffe08b1-acceptance.json)
verifies **101 successes per layout**, with every case occurring exactly once,
across all ten shards of the
[successful workflow](https://github.com/VladimirReshetnikov/Asymptotic/actions/runs/34430399328).
Its immutable source is `ffe08b18ea2a6a72546503b135b47b4979e7d010`.
The verifier checks raw kernel output and package, suite and runner hashes
against that commit. Later upstream principal-logarithm changes are covered
by separate focused integration checks; this full run is not relabeled as
testing those later sources.

The earlier Windows
[receipt summary](../../validation/mathics-test-coverage.json) records 101
distinct cases with successful evidence in each package layout across three
source snapshots. The two earlier full runs each retain their 76/77 outcome
and a separately validated correction of an exact-normalization assertion;
the later batches cover additional operations, held assumptions and retained
Newton and recipe refinement. This historical aggregate is separate from
the complete Linux run. Individual examples do not establish every parameter
range of a family.

The summary retains exact receipt-byte hashes and adds separate CRLF-to-LF
normalized comparison hashes, with explicit policies for both. Git preserves
the captured receipt bytes; historical package and suite byte hashes remain unchanged.
The API inventory separately identifies the reported original-Wolfram
control evidence and the limits of its published per-case records.

A separate [observable merge audit](../../validation/mathics-observable-merge-audit.json)
checks the new observable helpers on a frozen 55-module snapshot after
`ffe08b1`. Exact assertions pass for sine composition, composite normalization,
sine with a real coefficient of unknown sign, and Taylor-provider chart and
order guards. The source-coordinate example is refused with an earlier
`InexactInput` failure instead of the upstream expected tag. A local
square-root observable returns an equivalent trigonometric coefficient, but
the original `Expand`/`SameQ` comparison is retained as a mismatch. The
symbolic complex-tail and varying-source-coordinate fixtures reach their
180-second process limits and remain unvalidated. This bounded modular audit
does not add passing cases to the portable receipt summary or establish
standalone or Wolfram acceptance.

The subsequent principal-logarithm repairs have their own
[first-guard audit](../../validation/mathics-log-power-guard-audit.json) and
[recursive-guard audit](../../validation/mathics-recursive-log-power-guard-audit.json).
The recursive version at `cc1b06c` passes all ten focused groups, five per
loader: real and unknown exponent controls, complex-exponent refusals,
a public depth inverse, reciprocal/scaled nested positive monomials, and
refusal of unproved inner branches. Its 55 modules and standalone artifact
remain unchanged during the checks. The earlier audit preserves two faulty
row-comparison assertions alongside corrected coefficient reconstructions;
it does not rewrite those initial outcomes. These checks cover the later
source delta without extending the full Linux run's source claim.

| Area | Checked behavior |
| --- | --- |
| Loading and evaluator primitives | Clean load, reload, public contexts, held returns, association operations, pattern positions. |
| Ordinary inverse calculus | Finite and infinite source points, ramification, irrational powers, logarithmic coefficients, exact termination, residuals, perturbative formulas. |
| Forward calculus | Exact polynomial, exponential, logarithmic and irrational-power terms, finite approach from below, decaying exponential. |
| Algebra and state | Addition, multiplication, cancellation with retained error, truncation, two-stage refinement, depth enumeration. |
| Function input | Named and slot callables, binding and capture avoidance, conditional polynomial inverse branches, explicit conservative domain failures. |
| Special forward examples | Gamma and Barnes G Stirling corrections, Bessel J and Erf at zero, PolyLog at zero, Zeta Dirichlet terms. |
| Other inverse scales | Reciprocal-logarithmic, Lambert, Fourier, Gamma, Barnes G, exponential-core, first flat exponential sector. |
| Exact error checks | Rational quadratic root certificate and inaccurate fixed-center `AccuracyFloor` with retained history. |
| Numerical smoke checks | Exact quadratic root and principal Lambert specialization at `E`. These do not establish general numerical accuracy. |

Unrestricted symbolic branch proofs, sophisticated native asymptotics,
remaining special-function parameter ranges, nontrivial numerical
certificates, and notebook display require further feature-specific testing.
Mathics does not implement all
Wolfram builtins, and an explicit native backend request is limited to the
interpreter's actual implementation. Unsupported proofs must remain failures
or unresolved expressions; they are not replaced by guessed domains or
numerical evidence.

The [Wolfram preservation receipt](../../validation/mathics-wolfram-preservation.json)
records **1,452 passes and the same 12 existing failures across 79 suites**
on Wolfram 15.0.1 for Windows. All 1,464 per-test records match the untouched
`6687962` baseline. The receipt retains an earlier run with one extra failure
and the subsequent matching full rerun instead of discarding that evidence.

The latest wave-4 native comparison uses updated upstream `1a183a8`, including
its Fourier termination repair and public help, as the control for the
56-module `26a1154` candidate. All 2,060 modular and 2,059 standalone package
symbols match across all ten captured fields and contexts, with load/reload,
six monitored System builtins and eight behavior probes passing. Eight
focused portable cases also pass in each official-kernel layout. The complete
108-case official suite was not run at this stage. The historical comparisons
below remain separate.

Independent review fixes were subsequently merged from `origin/main`.
Native definition comparisons separately record the `021c584` review merge
and the later `350c70f`, `a55df16`, `ac91e66` and `a76c0b5` controls. An earlier
comparison uses `cc1b06c`, including its recursive positive-monomial logarithm
recognizer, as the control for the merged 55-module candidate at `07f283c`.
Relative to the preceding capture, only the private `parseFinite` downvalues
change and `finitePositiveMonomialLog` is added; every Mathics adapter hash
is unchanged. The earlier
54-module, held inline-assumption and observable comparisons are retained
separately. All 2,060 modular and 2,059 standalone package symbols
match across attributes, options, own/down/up/sub/numeric/default/format
values, messages, and contexts. Six System builtins, including `Map`, retain
their definitions before loading, after loading, and after reloading; eight
behavior probes also pass in every phase. The earlier full-suite result is
not relabeled as a full run of these later upstream changes. Each receipt
identifies its exact source hashes; absolute source-directory strings are
the only normalized definition content.

To reproduce a native definition comparison, provide a baseline checkout or
extracted Git archive and run:

```text
python validation/check_mathics_definitions.py --baseline BASELINE_REPOSITORY --candidate . --wolfram wolfram.exe --output native-definitions.json --captures .venv/native-captures
```

Both entry points are checked by default. The tool copies package inputs and
the exact hashed Wolfram capture script into temporary snapshots, runs fresh
kernels serially, and verifies load/reload and selected builtin state. It
checks the frozen capture script before each launch and at completion, and
rejects changes to original package or tool files. Focused regressions confirm
that editing either the original or frozen capture script invalidates the
run; a changed frozen script also blocks the next kernel launch. Its deliberate
changed-value fixture was rejected as well. Definition comparisons and finite
regressions are scoped evidence; neither proves every possible surrounding
program or every Wolfram version behaves identically.
