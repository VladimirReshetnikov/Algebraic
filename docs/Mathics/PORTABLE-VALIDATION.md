# Portable validation: guarantees and evidence limits

The portable suite records selected, reproducible observations on Mathics3 or
an official Wolfram kernel. A complete pass records that every selected assertion
passed, together with runtime information and source fingerprints. Complete
acceptance of this suite is one milestone toward the project's
[complete compatibility and coverage targets](../development/COVERAGE_TARGETS.md);
it does not establish compatibility for every supported Wolfram input, every
public option combination, or the original MUnit suite.

This note is a **source audit**, not a new runtime receipt. Its current runner
implementation reference is commit
[`26a1154c304b50b5a9a74fa392c23a7d2fdad996`](https://github.com/VladimirReshetnikov/Asymptotic/blob/26a1154c304b50b5a9a74fa392c23a7d2fdad996/validation/run_mathics_tests.py).
The earlier audit covered
[`38aa253aaf792577100103a76a9db165d7390e0e`](https://github.com/VladimirReshetnikov/Asymptotic/tree/38aa253aaf792577100103a76a9db165d7390e0e),
whose runner, suite, and verifier were unchanged in peer merge
`4da0dbcac93b1a4221bd55e1f2c787268350c33f`. Commit `45ea65f` repairs timeout
admission, executable symlink handling, report/input aliases, and forgotten
observed source differences. The merged `26a1154` also includes timer-overflow
cleanup and a mandatory package-readiness gate. The source-snapshot and
output-volume limitations below still apply.
The maintained sources are the [runner](../../validation/run_mathics_tests.py),
[portable assertions](../../validation/MathicsTests.wl), and
[acceptance verifier](../../validation/check_mathics_acceptance.py).

The recorded [runner integrity tests](../../validation/wave4-runner-integrity-tests.json)
report **32 succeeded, 0 failed, 0 skipped** on Python 3.14.4 / Windows 11.
Their recorded hashes match the runner and test source at `45ea65f`, before
the later merge. The merged Mathics-tool discovery passes 66 tests; the
[validation index](../../validation/README.md#mathics-wave-4-hardening) keeps
that result and real-kernel loading checks separate. These tool tests cover
synthetic protocol peers, temporary Python processes, and virtual environments;
they do not execute the Mathics or Wolfram package suite or establish the same
test outcomes on every host. Runtime outcomes are recorded separately from
this source audit.

## What the runner checks

`run_mathics_tests.py` launches one fresh process for each selected case, from a
temporary working directory. It clears the `WOLFRAMINIT` and `MATHKERNELINIT`
environment variables and uses `-noinit` with the official kernel. The portable
script explicitly raises Mathics's session `$IterationLimit` to `1000000` and
prints the runtime version and effective iteration limit. These are test
environment settings, not package defaults or evidence that arbitrary requests
terminate within the same budget.

The script compares each evaluated actual and expected expression using
`SameQ`. The Python runner accepts a result only when there is one matching test
ID, one valid success/failure record, a consistent process exit code, one kernel
header, and complete actual/expected output blocks. It retains the complete
combined standard output and standard error. A malformed protocol, crash,
reported assertion failure, launch failure, or ordinary finite timeout cannot
count as a successful case. This validates the suite's reported assertions; it
is not an independent mathematical re-evaluation by Python.

Receipts distinguish `Selected`, `Executed`, `Succeeded`, `Failed`, and
`NotRun`. They are written before the first case, after completed cases, and
after the loop. `RunComplete: true` means the runner reached its final reporting
step: a launch error can end the loop with unrun cases. Read that flag together
with the counters and individual outcomes. The runner's normal success exit
requires all selected cases to succeed and no source difference to have been
observed at any reporting checkpoint.

Selection uses the literal declaration format
`portableTest["case-id", "group", ...]`. The current inventory contains 120
cases. The Python inventory is a regular-expression scan, not a Wolfram Language
parser: a semantically valid declaration written in a different format can be
omitted from that inventory. Empty inventories and duplicate recognized IDs
are rejected. See the source/mutation audit in
[report 36, N05](../../external-reports/code-review/wave-4/code-review-36/results/novelty_ledger.csv).

## Source fingerprints and the frozen suite

The runner fingerprints the selected entry file, itself, and the portable
suite. When the entry is named `AsymptoticAnalysis.wl` and its parent directory
is named `Kernel`, it additionally fingerprints that directory's sibling
`*.wl` files. This covers the maintained modular layout and relocated copies
with the same directory convention. It is not a general dependency closure:
`init.m`, external files, and sibling modules reached through other entry or
directory names are not automatically included.

The suite's bytes are copied once to a temporary file and every case executes
that copy. `TestSuiteSnapshotSHA256` identifies those copied bytes. Package
sources are **not** copied: each fresh kernel receives the original live entry
path through `ASYMPTOTIC_PORTABLE_SOURCE`. The receipt's `Command` names the
original suite path; the executed command substitutes the temporary suite copy.
The temporary copy is not made read-only or rehashed between launches: its
recorded hash identifies the byte buffer used to create it, not continuous
integrity of the executed file.

`TestedSourcesSHA256` records the initial fingerprints.
`SourcesUnchangedDuringRun` remains `true` only while every reporting checkpoint
matches them. Since `45ea65f`, the first observed difference is retained in
`FirstObservedSourceDriftSHA256`, the flag stays `false`, and the normal final
exit is nonzero even if every case passes and the original bytes are restored.
For such a run, `SourcesSHA256AfterRun` records the latest fingerprints and can
equal the initial fingerprints; the first-drift field explains the failed
integrity result.

This fixes the earlier behavior at `38aa253`, where a matching later comparison
could erase a previously observed difference from the final receipt. The
historical mechanism and mock-kernel experiments are documented in
[report 30, F1](../../external-reports/code-review/wave-4/code-review-30/evidence/findings.json)
and [report 35's runner experiments](../../external-reports/code-review/wave-4/code-review-35/evidence/runner_experiments.json).
The current runner's restoration regression is included in the linked integrity
receipt. Retaining observed differences still does not provide a continuous
filesystem guarantee:

- Files are read sequentially, so a fingerprint set is not an atomic snapshot.
- Case discovery, the initial suite fingerprint, and the suite-byte copy are
  separate reads. Concurrent edits can occur between them.
- A package file can change and return to its original contents between
  comparisons, so no checkpoint necessarily observes that difference.

The dependency-closure limitations remain, including
[report 30, F2](../../external-reports/code-review/wave-4/code-review-30/evidence/findings.json)
and [report 29, N2](../../external-reports/code-review/wave-4/code-review-29/results/novelty-ledger.json).
Supplied mock-kernel experiments test harness mechanisms; they are not additional
Mathics package passes or evidence that source mutation occurred in a CI run.

The runner also protects its fingerprinted inputs from report writes. Before
launch and before every receipt write, both `--output` and its `<output>.tmp`
staging path are checked for direct, relative-path, symlink, or hard-link aliases
of the initial and currently discovered input files. An observed collision is
rejected. This protects the monitored input set, including newly discovered
siblings, rather than every possible dependency. It is an observed-path check,
not a filesystem lock against changes between checking a path and writing it.
Unrelated existing output files can still be replaced, so choose a fresh receipt
path when preserving earlier evidence.

For new evidence, use a dedicated checkout and keep its source files unchanged
until the run finishes. Preserve the receipt, exact revision, source hashes,
runtime header, and selected case inventory together. A source hash associates
reported bytes with a revision; it does not by itself trace every file a kernel
actually loaded.

## Load checks, timeouts, and interruption

Before every selected assertion, the suite evaluates
`CheckAbort[Check[Get[portableSource], $Failed], $Aborted]` and rejects either
failure marker. In a separate top-level input, it requires package registration,
the public context path, a return to `Global`, nonempty downvalues for
`AsymptoticInverse` and `AsymptoticExpansion`, and nonempty subvalues for
`GeneralizedSeries`. A valid wrapper can return a non-`Null` value after loading.
This is a readiness check, not validation of every definition or dependency.

The [load integration checker](../../validation/check_mathics_loading.py)
executes eleven fixtures in fresh kernels: eight incomplete or aborted loaders
must stop before the builtin-only assertion, while both real entry points and
a non-`Null` wrapper must pass. The corresponding
[Mathics](../../validation/mathics-final-loading-gate.json) and
[official Wolfram](../../validation/mathics-wolfram-final-loading-gate.json)
receipts each pass 11/11 with unchanged inputs. Their copy-integrity checks
belong to this separate checker, not the main runner.

Earlier suites only checked the stored load result in a separately selected
loading case, so a builtin-only assertion could pass after failed loading.
That historical mechanism is described in
[report 33, F03](../../external-reports/code-review/wave-4/code-review-33/evidence/source-novelty-ledger.json).
It is repaired in the current suite; earlier receipts retain their original
suite hashes and scope.

`--timeout` must now be finite and satisfy `0 < seconds <= 86400`; the default
is 180 seconds. Both CLI argument parsing and direct calls to `run_case` enforce
this contract before creating a process. Consequently, an invalid explicitly
supplied timeout is also rejected with `--list`. At `38aa253`, `NaN`, infinity,
and excessively large finite values could pass validation; nonfinite values
could also enter receipts as nonstandard JSON constants. That historical
admission defect, described in
[report 29, N1](../../external-reports/code-review/wave-4/code-review-29/results/novelty-ledger.json)
and [report 35, N02](../../external-reports/code-review/wave-4/code-review-35/evidence/findings.json),
is repaired in `45ea65f` and covered by the recorded integrity tests.

For an admitted timeout, the runner waits for the process with that limit and
then terminates its owned process group/tree. Cleanup and output draining have
additional waits. The option is not a strict total wall-clock limit for either
the case including cleanup or the whole suite.

Captured output has no byte limit. The runner buffers complete diagnostics and
serializes accumulated results again at checkpoints, so a time limit does not
also bound memory use or receipt size. There is no `--max-output` or aggregate
suite-timeout option in this version. The related source findings are recorded
in [report 31, N4](../../external-reports/code-review/wave-4/code-review-31/evidence/novelty_ledger.csv).

On interruption while a case is active, the runner attempts to terminate only
that process's tree/group and then re-raises the interruption. The active case
is not appended as an explicit `Interrupted` row. The last checkpoint normally
retains `RunComplete: false`, completed results, and a `NotRun` count that still
includes that case. Preserve this incomplete receipt as diagnostic evidence;
it does not establish an outcome for the active case. See
[report 29, N3 and supplied harness results](../../external-reports/code-review/wave-4/code-review-29/results/harness-tests.json).

The runner now anchors an existing executable path with `os.path.abspath()`
without dereferencing its symlinks. This applies to explicit `--python`, the
default `sys.executable`, and `--wolfram`. An unqualified executable name that
is not an existing file in the caller's working directory remains available
for normal `PATH` lookup. At `38aa253`, `Path.resolve()` could instead select a
POSIX virtual environment's base interpreter and lose the intended dependencies;
[report 31's interpreter-identity experiment](../../external-reports/code-review/wave-4/code-review-31/evidence/venv_identity.json)
documents that historical mechanism. The path-selection repair is covered by
the recorded integrity tests; outcomes beyond their Windows host remain
unverified by that receipt. Retain the actual runtime header with evidence.

## What acceptance verification adds

`check_mathics_acceptance.py` reads the chosen revision from immutable Git
objects and compares the submitted receipts with that reference. It checks
the exact reported source sets and hashes, the frozen-suite hash, case IDs and
groups, complete counters, successful exit codes, raw protocol consistency,
runtime version, iteration budget, and exactly one observation of every
recognized case for each package layout. It rejects missing or duplicate cases
and verifies that the receipt files did not change during verification.

These checks bind the **reported** source hashes to immutable Git bytes. They
do not retrospectively prove continuous filesystem immutability during the
kernel runs, independently observe package loading, or audit every installed
dependency. A verified requirements-file hash identifies that input file;
`RequirementsHashStatus: "NotRecorded"` means the shard did not record it.
Runtime headers provide separate version evidence. `--run-url` stores a
caller-supplied URL and does not query GitHub workflow status.

The peer acceptance record introduced by commit
`affa3d373c8875099e95b65a82bc234783b94894`
records 101 cases per layout and **202 successful Linux Mathics observations**
from [workflow 34430399328](https://github.com/VladimirReshetnikov/Asymptotic/actions/runs/34430399328),
against reference `ffe08b18ea2a6a72546503b135b47b4979e7d010`.
The runner limitations above do not establish that those runs suffered source
mutation, interpreter substitution, or another failure, and do not invalidate
those existing observations without such evidence. Their scope remains the
complete maintained portable suite at the recorded source hashes and runtime,
not all package inputs, later changed sources, or complete Mathics compatibility.
The later runner repairs improve new evidence collection; they do not rerun or
change the source revision of these historical observations.

## Practical commands

Run these from the repository root. `--list` starts no kernel and can be used
to inspect a selection before running it:

```console
python validation/run_mathics_tests.py --list
python validation/run_mathics_tests.py --group loading --list
python validation/run_mathics_tests.py --case "inverse-*" --list
```

Repeated `--case` patterns are combined by union, as are repeated `--group`
values; when both kinds are supplied, their selections are intersected. Unknown
groups, unmatched patterns, and an empty intersection are errors. Argument
parsing validates an explicitly supplied timeout before `--list` can return.
Listing does not check runtime availability, source-file existence, or output
aliases; it is an inventory and argument check only.

For a Windows virtual environment installed from
[the pinned requirements](../../validation/requirements-mathics.txt), the
following commands write separate fresh receipts for loading and the complete
portable suite on each layout:

```console
python validation/run_mathics_tests.py --python .venv/mathics/Scripts/python.exe --group loading --timeout 180 --output portable-results/loading.json
python validation/run_mathics_tests.py --python .venv/mathics/Scripts/python.exe --timeout 300 --output portable-results/modular.json
python validation/run_mathics_tests.py --python .venv/mathics/Scripts/python.exe --source AsymptoticAnalysis.wl --timeout 300 --output portable-results/standalone.json
```

The timeouts are operational budgets, not claims that every case will finish
within them. `--wolfram EXECUTABLE` selects the same portable suite on an
official kernel and is mutually exclusive with `--python`:

```console
python validation/run_mathics_tests.py --wolfram wolfram.exe --group loading --timeout 180 --output portable-results/wolfram-loading.json
```

For existing downloaded CI artifacts, point the verifier at a directory
containing only shard receipt JSON files, and choose the exact revision those
shards report. Keep workflow-status captures and previous acceptance outputs
outside that directory. For the recorded Linux reference, the command shape is:

```console
python validation/check_mathics_acceptance.py --receipts PATH_TO_EXTRACTED_SHARDS --revision ffe08b18ea2a6a72546503b135b47b4979e7d010 --output portable-results/acceptance.json --run-url https://github.com/VladimirReshetnikov/Asymptotic/actions/runs/34430399328
```

Replace `PATH_TO_EXTRACTED_SHARDS` with the actual artifact directory. This
command verifies existing evidence and starts no Mathics or Wolfram process.
The examples here document supported arguments; their inclusion is not a
receipt that these commands were rerun for this documentation change.
