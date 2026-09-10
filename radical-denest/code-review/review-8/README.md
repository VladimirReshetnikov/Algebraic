# StradFixed2 audit and proposed StradFixed3 derivative

Prepared for Vladimir Reshetnikov, September 5, 2026.

## Contents

- `article.pdf` — detailed review, mathematical proofs, findings, validation boundaries, and complete proposed source listing.
- `article.tex` — editable LaTeX source. Compile from this directory; it includes `code/StradFixed3.wl` by relative path.
- `code/StradFixed3.wl` — self-contained proposed derivative in the separate ``RadicalDenest3` `` context.
- `tests/StradFixed3.wlt` — 52 native Wolfram regression tests, **not executed here**.
- `tests/run_tests.wls` — native test runner; writes a report only when actually run.
- `tests/probe_original.wls` — source-specific diagnostic probes of the original package.
- `tests/differential.wls` — supplementary 18-input comparison of original and proposed packages.
- `verification/verify_math.py` — independently executable exact mathematical and lexical/structural checks.
- `verification/results.json` and `verification/results.txt` — actual executed Python results, including the proposed package hash.
- `SOURCE_ACCESS.md` — source and execution provenance, including access limitations.
- `CHANGES.md` — implementation map and policy changes.
- `SHA256SUMS` — checksums of delivered files (excluding this checksum file).

## Validation status

The independent run passed **3,412 assertions**: **3,399 mathematical**, **3 Python control-flow-model**, **5 lexical**, and **5 structural** checks. This is NOT a count of native package tests or independent end-to-end denesting examples. Python was 3.13.5; SymPy was 1.14.0. Multiple assertions may belong to one parameter case.

**None of the 52 native Wolfram tests was run.** The connected Wolfram service failed with HTTP 404 before evaluating a diagnostic request, and no local Wolfram kernel was available. The source requires clean-kernel loading, the supplied native suite, and the repository's existing test batteries before adoption. No native performance improvement or regression parity is claimed.

The article distinguishes source-level defects, mathematical counterexamples to helper coverage, acknowledged design policies, and unexecuted native expectations. It does not assert a reproduced wrong default numerical output from StradFixed2.

## Build the article

Use a reasonably complete TeX Live installation with `newpx`, `amsmath`, `mathtools`, `microtype`, `booktabs`, `longtable`, `listings`, `xurl`, and the other standard packages named in the preamble.

```sh
latexmk -pdf -interaction=nonstopmode -halt-on-error article.tex
```

Alternatively run `pdflatex -interaction=nonstopmode -halt-on-error article.tex` at least twice. No bibliography processor is needed. Do not move the LaTeX file away from its `code/` subdirectory without updating the listing path.

## Run the independent checks

```sh
python verification/verify_math.py
```

The script requires SymPy. It writes `verification/results.json`; the delivered text transcript was obtained by redirecting stdout:

```sh
python verification/verify_math.py > verification/results.txt
```

Elapsed time and hashes are recorded, not fixed golden values. Rerunning or editing files changes their checksums. These checks do not parse or execute Wolfram Language.

## Run native validation

The following require an available Wolfram kernel and `wolframscript`:

```sh
wolframscript -file tests/run_tests.wls
wolframscript -file tests/probe_original.wls /path/to/StradFixed2.wl
wolframscript -file tests/differential.wls /path/to/StradFixed2.wl
```

Use an absolute original-source path when the working directory may differ. The runners locate the proposed package relative to their script file. They do not download source, mutate the original repository, or create a replacement upstream file. The differential corpus is supplementary and intentionally uses different time limits from the repository benchmarks.

After these tests, rerun unified-B's existing native regression suite and reported batteries on the proposal. Record the upstream commit, kernel version, platform, inputs, elapsed time, messages, termination limits, equality, and cost/depth changes separately. Private-helper tests matter because later stages can hide a lost intermediate candidate by rediscovering it.

## Load and use the proposed code

```wl
Get["code/StradFixed3.wl"];
RadicalDenest3`Strad[Sqrt[5 + 2 Sqrt[6]]]
RadicalDenest3`DenestReport[expr, "AllLevels" -> True]
```

The expected behavior of these examples has not been checked in a native kernel here. Return expressions can differ syntactically while remaining equal and cheaper.

Optional square-class search:

```wl
rho = 118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462];
RadicalDenest3`DenestReport[Sqrt[rho],
  "SquareClassSearch" -> True,
  "NumericPrefilter" -> False]
```

The article proves that the desired positive root is `Sqrt[6] + Sqrt[35] + Sqrt[77]`, lying in a different square-class coset from the input field.

Optional processing of independent mixed-input list entries:

```wl
RadicalDenest3`Strad[{0.5, Sqrt[5 + 2 Sqrt[6]]},
  "ProcessExactIslands" -> True,
  "ListProgress" -> "Independent"]
```

Approximate leaves are not rationalized. The default remains conservative for inexact hosts, and the default list cost policy remains global.

## Contract and limitations

Changed values must be explicit radicals, pass exact equality certification, and satisfy the configured progress policy. Numerical rejection is optional search pruning, never an exact public `"Different"` certificate. Equality can return `"Unknown"`; the type recognizer can return False for a valid but unsupported algebraic representation or when its budget is exhausted.

The algorithms are heuristic, representation-sensitive, and bounded. No unchanged result proves impossibility. The odd-index theorem applies to roots in a real quadratic field, not all radical denestings. The coset theorem applies inside a specified multiquadratic ambient field; the implementation's enumeration and solver are bounded and do not make an unconditional completeness claim.

Time and memory controls cover the core session, not prior argument/option evaluation, serialization, preexisting process memory, or arbitrary external effects. Kernel controls are cooperative, not operating-system containment. User callbacks and functions embedded in Root objects are not treated as hostile code in a security sandbox.

Accepted-candidate records are not a final-result proof chain. Committed-pass records have a separate scope and can be marked incomplete after an interrupt. Neither journal is an independent proof object.

## Provenance

The upstream source was inspected through web-rendered/raw GitHub views of `main` on September 5, 2026; no immutable commit was resolved and no byte-identical local original-source snapshot was established. This is a source-informed derivative, not a guaranteed clean-apply patch. Attribution to the upstream RadicalDenest project is retained. No new license for upstream-derived material is asserted by this archive. Consult the upstream project's applicable terms before redistribution.
