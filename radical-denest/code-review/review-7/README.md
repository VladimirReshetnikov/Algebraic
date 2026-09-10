# Audit of StradFixed2.wl and a proposed StradFixed3.wl

Review date: 5 September 2026.

**Start with `article.pdf` (21 pages). `article.tex` is its self-contained source.**

This is an independent audit and a proposed revision, not an upstream release.
No remote repository files were changed. The proposed Wolfram code and its 50
native regression tests were **not executed in a Wolfram kernel**. The available
Wolfram service returned an endpoint error, and no local kernel was installed.
The exact Python/SymPy checks did run: 14,190 assertions passed. Those assertions
check mathematics, source integrity and selected static properties; they do not
establish native Wolfram behavior or performance.

## Contents

- `article.tex`, `article.pdf`: analysis, source-line references, findings matrix,
  mathematical proofs, compatibility changes, test evidence and bibliography.
- `code/StradFixed2.pinned.wl`: byte-exact reviewed original.
- `code/StradFixed3.wl`: standalone proposed revision in context ``RadicalDenest3` ``.
- `code/StradFixed2-to-3.patch`: unified diff, including the context rename.
- `code/build_improved.py`: checks the original Git blob and reproduces the revision
  through 36 checked edit groups. The generated code has 816 lines.
- `code/LICENSE`: original repository's MIT No Attribution license.
- `tests/verify_independent.py`: executed exact algebra and lexical/static checks.
- `tests/StradFixed3.wlt`: 50 supplied, unexecuted native Wolfram tests.
- `tests/run_tests.wls`: fresh-kernel native test runner.
- `evidence/`: executed independent results, patch manifest, native execution
  status, and PDF quality-check record.
- `SOURCE_MANIFEST.json`: pinned sources and source-access qualifications.
- `SHA256SUMS`: checksums of all other delivered files.

## Provenance

Repository: `VladimirReshetnikov/RadicalDenest`

Pinned commit: `9000d6f533a68ee7659a6830ad25bba401f800a5`

Reviewed path: `src/corrected/StradFixed2.wl`

Git blob: `0bdeded347385a55a044fdd35883006d053685dc`

The reviewed file has 41,416 bytes and 745 lines. Its Git object hash was checked
independently. All original-source line references in the article refer to this
copy, not to a later version of `main`.

## Principal findings

The original architecture has a valuable exact acceptance gate and correct
quadratic, cubic, branch-orbit and denominator-inverse formulas. The audit does
not demonstrate an unequal accepted numerical result for a valid, genuinely
algebraic, parameter-free input.

The remaining issues include overpermissive admission of exact `Root` objects,
a heuristic route to the exact-looking status `"Different"`, loss of a better
incumbent between proposal stages, rejection of useful unchanged subproblems,
resource-boundary mismatches, resource-insensitive negative caching, malformed
argument dispatch, and ambiguous proposal/certificate reporting. The article
separates confirmed source defects, evaluator-sensitive regression obligations,
previously acknowledged limitations, and proposed improvements.

The proposed revision preserves the established proposal engine. It also adds
an odd-index trace--norm reconstruction method inside a real quadratic field,
with a proof in the article. This is not a general completeness or minimum-depth
algorithm, and no runtime speedup has been measured.

## Using the proposed package

From the extracted archive's root directory in a Wolfram session:

```wl
Get["code/StradFixed3.wl"];
expr = Sqrt[5 + 2 Sqrt[6]];
RadicalDenest3`Strad[expr]
RadicalDenest3`DenestReport[expr, "AllLevels" -> True, "TimeBudget" -> 30]
```

The expected mathematical value of `expr` is `Sqrt[2] + Sqrt[3]`. The example is
usage code, not a transcript of a run performed during this review.

The original can be loaded simultaneously for differential testing:

```wl
Get["code/StradFixed2.pinned.wl"];
RadicalDenest2`Strad[expr]
```

Use fully qualified names when both contexts are loaded. Do not overwrite an
existing deployed implementation with the proposal before native testing.

### Deliberate compatibility changes

The public context is ``RadicalDenest3` ``. Opaque admission is conservative:
rational-polynomial `Root` presentations with valid integer selectors and
`AlgebraicNumber` objects with admitted generators and rational coefficients are
recognized; other valid algebraic presentations can remain unsupported.
`NumericPrefilter` defaults to `False`; enabling it records hints without deciding
inequality. Disabled reports can have `Missing["NotComputed"]` costs. Malformed
calls return `Failure`. Gaussian components are included in the integer/rational
bit-size cost. Reports explicitly label accepted-proposal records and truncation.

Resource constraints cover search, preflight and cost construction, not ordinary
argument evaluation, option-expression evaluation, or final report assembly.
Kernel constraints are cooperative and are not a process sandbox. `MaxTrials`
bounds a multiplier-search visit, not all recursively related work. The package
continues to leave mixed-inexact trees and unsupported/held hosts unchanged.
User callbacks and upvalues must be trusted; this is not a safe evaluator for
arbitrary untrusted Wolfram programs.

## Reproducing the checks

Python 3 with SymPy is required for the independent checks. The executed
versions were Python 3.13.5 and SymPy 1.14.0. From the archive root:

```sh
python code/build_improved.py
python tests/verify_independent.py
```

The builder uses only the Python standard library. The verification writes
`evidence/independent_results.json`; the delivered text file is the captured
transcript of the executed run. Do not invoke Python with `-O`, which disables
assertions.

A standard LaTeX installation can rebuild the PDF:

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

The article uses standard packages and needs no external image or font files.

With an actual Wolfram installation, run the native suite separately:

```sh
wolframscript -file tests/run_tests.wls
```

This last command was not executed here. It writes
`evidence/native_test_report.txt` and exits nonzero when native tests fail. The
supplied `evidence/native_execution_status.json` describes the review session;
it is not changed automatically by a later user-run test. Native differential
comparison with the upstream unified-B tests and randomized families remains a
release requirement.

`make pdf`, `make independent`, and `make native` provide corresponding shortcuts.
On systems with `sha256sum`, `sha256sum -c SHA256SUMS` checks the delivered files
before rebuilding them. A later rebuild can intentionally change generated
files and therefore their checksums.
