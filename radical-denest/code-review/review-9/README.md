# StradFixed2 review and proposed StradFixed3 revision

Prepared for Vladimir Reshetnikov, September 2026.

Start with `article.pdf` (the full technical review). Its self-contained LaTeX
source is `article.tex`. The proposed standalone Wolfram Language package is
`StradFixed3.wl`, in the separate public context ``RadicalDenest3` ``. It does not
load or overwrite the original package.

## Reviewed baseline

Repository: https://github.com/VladimirReshetnikov/RadicalDenest

Commit: `9000d6f533a68ee7659a6830ad25bba401f800a5`

Path: `src/corrected/StradFixed2.wl`

Git blob: `0bdeded347385a55a044fdd35883006d053685dc`

The included `StradFixed2.original.wl` is the exact 41,416-byte, 745-line baseline.
Its Git blob hash was checked against the repository metadata. The manifest
lists the prior review, survey, literature editions, and official documentation
consulted. The 2026 literature re-typesettings contain editorial corrections;
they are not treated as unmodified publisher facsimiles.

## Validation status

**Executed:** 396 independent checks, with 396 passing and zero failing, using
Python 3.13.5 and SymPy 1.14.0. These include exact symbolic identities, exact
multiquadratic arithmetic, finite enumeration/budget models, source provenance,
lexical delimiter checks, and structural assertions. Full results are in
`independent_results.json`.

**Not executed:** the 40 native Wolfram regression tests in
`StradFixed3Tests.wlt`. The Wolfram connector was attempted but did not provide a
working kernel for this review. The independent checks do NOT establish native
Wolfram parsing, evaluation semantics, package loading, regression success, or
performance. No `native_results.json` is included or implied.

This is a proposed research revision requiring native qualification before
production use. The article does not demonstrate an incorrect returned
numerical value from the original on the intended closed exact-algebraic input
class. Its principal findings are contract, search-state, coverage, and resource
control defects, with evidence categories distinguished explicitly.

## Load and use

From the extracted directory in a Wolfram kernel:

```wolfram
Get["StradFixed3.wl"];
RadicalDenest3`DenestCore[Sqrt[3 + 2 Sqrt[2]], "MaxTrials" -> 0]

RadicalDenest3`DenestReport[
  Sqrt[37 + 4 Sqrt[15] + 6 Sqrt[14] + 2 Sqrt[210]],
  "MaxTrials" -> 0, "Trace" -> True]
```

The first example is intended to return `1 + Sqrt[2]`. The second targets the
proved identity with `Sqrt[6] + Sqrt[10] + Sqrt[21]`; the native test suite checks
both equality and reduced depth. These are expected behaviors, not recorded
native outputs from this review.

Public entry points retain the original names: `Strad`, `DenestRadicals`,
`DenestCore`, `DenestReport`, `EqualityStatus`, `CertifiedEqualQ`,
`ExactAlgebraicQ`, `RadicalExpressionQ`, `RadicalDepth`, `RadicalCost`,
`RationalizeDenominator`, and `Factorc`.

Using fully qualified names avoids ambiguity when both the original and revised
packages are loaded for differential testing. `Strad[expr, True, opts]` retains
the all-levels overload. Unknown and malformed option tails are routed to the
option validator.

## Changes

The revision conservatively validates indexed rational-polynomial `Root`
objects and `AlgebraicNumber` payloads; preserves incumbents across power-search
stages; offers useful index reductions before requiring recursive progress;
avoids negative memoization across unequal search budgets; adds path-local
cycle detection; repairs explicit operation wrappers and the discriminant
proposal batch limit; and moves preflight/cost work inside the session budget.

Numeric significance arithmetic is diagnostic only and is disabled by default.
An exact oracle is still required for acceptance. Cost accounting now includes
Gaussian-rational components and prunes opaque nodes consistently.

Two bounded proposal kernels are added: small-rank character/Hadamard
reconstruction for multiquadratic square roots, and odd-index trace–norm
reconstruction inside a quadratic field. Their derivations, scope, and limits
are proved in the article.

New options:

| Option | Default | Meaning |
|---|---:|---|
| `"MaxCharacterRank"` | 2 | Independent square-class generators; 0 disables; maximum admitted setting is 4. |
| `"MaxCharacterPatterns"` | 8 | Maximum sign patterns tested by the character kernel. |
| `"MaxOddIndex"` | 7 | Maximum odd index for the new quadratic-field kernel. |
| `"DiscriminantBatchCap"` | 24 | Maximum proposals in one discriminant-derived batch. |

`"NumericPrefilter"` remains accepted for compatibility, but now requests only
optional diagnostic numerical work. It never proves `"Different"` or bypasses
an exact equality test.

## Remaining limits and compatibility notes

The package is still heuristic and bounded: an unchanged result is not a proof
of non-denestability, and no minimum-depth claim is made. Search order, early
exits, budgets, and the conservative input grammar can affect coverage. Existing
proposal mechanisms are retained, but native behavior or performance equivalence
to the previous version is not asserted. The first applicable nonempty fast
kernel may short-circuit later fast kernels.

The stricter recognizer deliberately rejects some mathematically algebraic
representations outside its supported grammar. It is not an algebraicity
decision procedure or a sandbox for executable Wolfram input. Ordinary argument
evaluation and option resolution occur before the internal session budget.

Time/memory controls are cooperative kernel limits, not hard process-level
wall-clock or resident-memory guarantees. Degree limits are principally output
filters, not pre-computation complexity bounds. Incomplete work is published
only at complete-pass checkpoints. Reports contain a bounded sample of accepted
proposals, not a replayable committed proof DAG. A timed-out or disabled report
may return `Missing["NotComputed"]` for cost fields instead of recomputing costs
after the deadline.

## Native tests

With `wolframscript` on PATH, from the extracted directory:

```text
wolframscript -file run_tests.wls
```

The runner prints the native TestReport and writes `native_results.json` with
the actual kernel version and counts. Exit status is 0 for no failed tests, 1
for test failures, and 2 for loading/report/export errors or an unexpected test count. The suite includes
white-box tests isolating stage monotonicity, index reduction, memoization, and
numeric diagnostic behavior from the kernel's ability to discover a formula.
Run it in a fresh kernel; the article also describes differential and timing
checks that are still needed.

## Reproduce the source revision and independent checks

Python and SymPy are needed for the independent checks. SymPy 1.14.0 was used
for the included results. The source generator itself uses only the Python
standard library.

```text
python build_revision.py
python independent_checks.py
```

`build_revision.py` rejects a baseline with a different Git blob and checks its
patch anchors. It combines that verified baseline with
`revision_definitions.wl` to reproduce `StradFixed3.wl`. The human-readable diff
is `StradFixed2-to-3.diff`.

## Rebuild the article

Run pdfLaTeX twice from this directory, or use `build_pdf.sh` on a system with
an ordinary POSIX shell:

```text
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

The article uses standard TeX Live/MiKTeX packages and Latin Modern fonts. No
font files, external images, bibliography database, or custom class are needed.
The delivered PDF was rendered and visually inspected. Generated timestamps
can prevent a rebuilt PDF from being byte-identical while retaining identical
content.

`pdf_validation.json` records PDF layout and font-embedding checks.

`SHA256SUMS.txt` covers every delivered file except itself. Regenerating any
covered file may change its hash. No license change to the retained baseline is
implied by inclusion in this review bundle.
