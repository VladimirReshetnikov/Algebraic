# Radical-denesting literature — PARTIAL package

## What is actually included

This is **not the completed download collection requested**. The file-download
runtime had no working external network connection: requests to public hosts
failed during DNS resolution or connection setup. Web search and some web-page
reads worked, but they did not provide downloadable file bytes to the runtime.
No new external HTTP download succeeded during preparation.

Five matching papers were recovered from the user's earlier Library upload
`articles.zip` and are included unchanged, each in its own subdirectory:

| Directory | Included PDF | Pages |
|---|---|---:|
| `papers/009_bfht/` | Borodin–Fagin–Hopcroft–Tompa, *Decreasing the Nesting Depth of Expressions Involving Square Roots* (1985) | 20 |
| `papers/012_landau92/` | Landau, *Simplification of Nested Radicals*, **FOCS 1989 extended abstract** | 6 |
| `papers/025_jeffrey/` | Jeffrey–Rich, *Simplifying Square Roots of Square Roots by Denesting* | 13 |
| `papers/032_berndt98/` | Berndt–Chan–Zhang, *Radicals and units in Ramanujan's work* (1998) | 14 |
| `papers/046_gkioulekas/` | Gkioulekas, *On the denesting of nested square roots* (2017) | 12 |

Each directory also contains the corresponding **user-supplied OCR TeX
transcription** under `ocr_transcription/`. These are **not original author TeX
sources**. They have not been corrected or recompiled for this task. In
particular, the Landau file must not be confused with the longer SIAM 1992
journal article, which is not included.

The sixth paper in the earlier upload, Scheinerman's *When Close Enough Is
Close Enough*, was not included because it was not a bibliography match.

## The index and retrieval manifest

Open **`index.html`** in a browser. It is searchable and links to the included
files, public-source URLs, and original bibliography records. `index.csv` is
the same reference-level index in tabular form.

The three bibliographies supplied in `reports(20260905-194517).zip` contain
278 records, grouped into 107 overlapping-reference groups. Some original
records are compound citations covering multiple works, editions or web
resources; **107 is not a count of unique papers**.

`manifest.json` contains the complete original citation text, grouping,
source links, version notes, explicit retrieval candidates and local-file
provenance. Direct PDF candidates or arXiv retrieval jobs were assembled for
34 literature groups. Ten arXiv papers have paired PDF/source retrieval jobs.
The official Journal of Integer Sequences page also explicitly provides a
PDF and a LaTeX file for Barbero–Cerruti–Murru–Abrate. Those original source
files have **not yet been downloaded**.

Entries lacking a resolved full text remain in the index. “Unresolved” is not
a claim that no free copy exists. Likewise, a source URL is not evidence that
the file was successfully retrieved. Links copied from the reports are
labeled separately from links inspected through publisher/author pages.
Publisher previews, subscription pages, thesis registers, and unrelated
papers are not substituted for full texts.

For some references an author manuscript, technical report, or conference
precursor is the open-access lead. The manifest records the distinction;
these copies are not silently relabeled as the journal version.

## Continue the downloads

The included downloader uses **Python 3.9 or later and the standard library
only**. No packages need to be installed.

From the extracted package directory, run:

```console
python fetch_literature.py
```

On Windows, `download.cmd` is a double-clickable launcher. The Python launcher
form also works:

```console
py -3 fetch_literature.py
```

The program downloads the explicit manifest candidates, keeps successful
files in per-reference directories, updates the index, and creates
`radical_denesting_literature.zip` next to the extracted package directory.
Running it again resumes completed assets without downloading their bytes
again, provided their recorded SHA-256 checksum still matches.

Useful options:

```console
python fetch_literature.py --no-web
python fetch_literature.py --only perucca,cavallo,barbero
python fetch_literature.py --try-unverified-pdfs
python fetch_literature.py --workers 2 --timeout 60 --retries 2
python fetch_literature.py --index-only --no-zip
python fetch_literature.py --dry-run
```

`--no-web` excludes software-documentation and discussion-page snapshots.
`--try-unverified-pdfs` also attempts explicit PDF leads that were left in the
unresolved landing-page list. The default does not crawl arbitrary links or
try to bypass subscriptions or access controls. An unresolved citation will
not automatically be solved by this script; a newly located URL can be added
to that reference's `assets` array in `manifest.json`.

The script deliberately does not include every hyperlink found in a paper's
references: that would download unrelated publications and contaminate the
collection. Web references are saved in their native HTML or source-code
format, not represented as invented publisher PDFs. HTML snapshots may still
need a network connection for external styles, scripts or images.

## arXiv and source pairing

For each arXiv paper, the program first resolves a specific version and then
uses that **same version** for both the PDF and the submission-source URL.
The choice is recorded in `download_state.json` and preserved on subsequent
runs. When version resolution fails, a specific known version from the
manifest is used and the fallback is recorded. Delete only the relevant
`arxiv_versions` entry in the state file to resolve a newer version on a
later run; old version directories are retained.

The original source payload is retained, whether it is a tar archive, a ZIP,
a gzipped TeX file, or plain TeX. Source archives are unpacked beside their
PDF, preserving auxiliary `.bib`, `.sty`, image and other submission files.
Path traversal, symbolic links, special files and excessive expansion are
rejected. No source file is executed or compiled.

An arXiv source endpoint can return a PDF-only submission. The program marks
that explicitly rather than renaming the PDF as a `.tex` file or fabricating
source code. File signatures and PDF end markers are checked; an HTML error
page is not accepted as a PDF. These checks are not a full mathematical or
bibliographic identity verification of every future download.

## Provenance and audit files

- `papers/*/PROVENANCE.json`: provenance and SHA-256 checksums of the five
  recovered PDF/OCR pairs.
- `manifest.json`: complete curated retrieval plan and original citations.
- `bibliography/`: verbatim bibliography material extracted from the reports.
- `preparation_download_failures.jsonl`: failed requests made during preparation.
- `download_state.json`, `download_log.jsonl`: created/updated by the downloader.
- `*.provenance.json`: final URL, timestamp, media type, size and checksum for
  each successfully retrieved asset.
- `SHA256SUMS.txt`: checksums of the initial package files, excluding itself.

The downloader's offline tests exercise PDF checks, real local HTTP transfer,
plain/gzipped TeX and archive extraction, traversal rejection, and the local
index/ZIP generation. Its execution against public websites could not be
validated in the preparation environment. See `tests/test_fetcher.py`.

Preparation date: 2026-09-05.
