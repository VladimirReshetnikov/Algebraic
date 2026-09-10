# Radical-denesting bibliography: download kit

## Important: this is NOT the requested collection of downloaded papers

**External PDFs downloaded in this session: 0. Original TeX sources downloaded: 0.**

Direct file transfers failed in the execution environment (DNS/network failures). The alternative download tool failed as well. Web search and page inspection remained available, so the attached reports could be indexed and public-copy leads researched, but the original remote file bytes could not be obtained.

This ZIP therefore contains a **reference catalog and a runnable downloader**, not the cited publications. Its presence must not be interpreted as successful completion of the original download request. Search-indexed links and public download buttons are leads, not confirmation that the corresponding bytes can be retrieved from your connection.

## Coverage

The three input reports contain **278 bibliography occurrences**: 93 in report 1, 99 in report 2, and 86 in report 3. They have been consolidated into **107 work/resource groups**, retaining every original citation and its report identifier. These are not 107 distinct papers: some citations describe software, collections of related web pages, or more than one edition.

The catalog distinguishes direct full-text candidates, public web resources, repository/download-page leads, catalog-only records, and works for which no direct public copy was identified. This is a complete mapping of the supplied bibliography, **not a claim of an exhaustive Internet availability search**. No entry is certified permanently unavailable.

## Start here

Open `INDEX.html` in a browser for the searchable catalog. No network is needed to read the index itself; its outbound source links require Internet access.

To run the downloader, extract this ZIP to a normal folder and use Python **3.9 or later**. No third-party Python packages are required.

```console
python download_all.py
```

On systems where the interpreter is named `python3`, use:

```console
python3 download_all.py
```

To include uncertain publisher endpoints explicitly labeled as optional probes:

```console
python download_all.py --try-publisher-probes
```

The Windows launcher is `RUN_WINDOWS.cmd`. On macOS/Linux, run `sh RUN_MAC_LINUX.sh`. Launchers pass through command-line arguments.

By default the script creates `radical_denesting_downloads/` and packages its actual contents into `radical_denesting_downloads.zip`, beside the script. An Internet connection and normal public access to each host are required. Network errors, changed URLs, download restrictions and absent sources can still leave the resulting collection incomplete.

Useful commands:

```console
python download_all.py --dry-run
python download_all.py --only barbero,perucca
python download_all.py --output my_collection --zip my_collection.zip
python download_all.py --help
python -m unittest discover -s tests -v
```

Rerunning resumes successful tasks only after checking their stored file hashes; failed tasks are retried. The program reports unsuccessful tasks and returns exit code 2 when at least one attempted task failed. A work with no configured download is retained in the catalog but is not falsely recorded as a successful task. Ctrl+C preserves completed downloads, writes the current report and ZIP, and exits with code 130.

## Pairing and versions

A typical work folder has this structure after successful downloads:

```text
radical_denesting_downloads/
  bibliography_manifest.json
  download_results.csv
  download_state.json
  SUMMARY.json
  079_perucca/
    README.md
    arxiv/
      2511.02498v1/
        paper.pdf
        source_original.tar.gz    [when the original response is an archive]
        source/
          main.tex                [original filename retained when available]
          ...                     [bibliography, figures and other source files]
```

Ten configured routes attempt arXiv PDF/source pairs. An explicit version in the manifest is retained. For an unversioned citation the program resolves the available version once from the abstract page, records it, and uses the **same pinned version** for both PDF and source. It refuses to label an unversioned pair as version-matched if it cannot establish a version.

The Barbero journal page also advertises a separate LaTeX source. It is paired with the journal PDF, not with the arXiv PDF. Original archives are retained when supplied, and source files are safely extracted without compilation. No TeX is reconstructed from PDFs. PDF-only submissions or archives without recognizable TeX are logged as source failures.

Some candidates are preprints, conference versions, public-domain editions or Russian originals rather than the precise publisher typesetting or translation cited. These distinctions are recorded per entry. Shanks's 1974 item requires two separate scanned pages; both download tasks are retained. Some journal page scans also contain adjacent material. Web citations are saved as HTML/source resources when configured; they are not converted into invented publisher PDFs. HTML snapshots do not recursively download images, style sheets or other page dependencies.

## What the downloader checks — and what it does not

The script rejects HTML error/login/challenge pages posing as PDFs, checks PDF headers/trailers, records SHA-256 hashes and sizes, and imposes response and extraction limits. Archive extraction rejects traversal paths, links and special files. It never executes downloaded code or compiles TeX. Review unfamiliar sources before running or compiling them.

These are **format and transfer-integrity checks**, not proof of bibliographic identity, completeness, scientific correctness or permission to redistribute. A publisher preview can be a valid PDF; examine the saved file and edition notes. Landing-page resolution follows a limited set of explicit PDF/TeX links and may miss JavaScript-only or unusual repository interfaces. It is not a universal website scraper. Searches and URLs reflect work performed on September 5, 2026, and can become stale.

Only ordinary unauthenticated HTTP(S) access is attempted. The script does not bypass paywalls, login requirements, anti-bot challenges or other access controls. Public download availability is not necessarily an open license; preserve attribution and comply with the rights and terms attached to each work. Optional publisher probes do not change these restrictions.

## Files in this kit

- `INDEX.html`: searchable human-readable catalog, including source links, evidence labels, notes and original citation mapping.
- `catalog.csv`: one row per work/resource group, with candidate links and original report references.
- `needs_followup.csv`: catalog-only, unresolved, and landing-page-only leads that need additional checking. A listing here does not mean the work is paywalled.
- `manifest.json`: structured metadata and all configured download tasks; includes explicit zero-download session status.
- `original_bibliography.json`: all 278 original bibliography records extracted from the user-supplied reports.
- `download_all.py`: resumable standard-library downloader and ZIP builder.
- `RUN_WINDOWS.cmd`, `RUN_MAC_LINUX.sh`: convenience launchers.
- `tests/test_download_all.py`: offline functional and safety tests using synthetic in-memory fixtures; no publication bytes are included.
- `OFFLINE_TEST_RESULTS.txt`: actual test output from this session.
- `PLANNED_DOWNLOADS.txt`: dry-run list of all configured tasks, including optional probes.
- `SHA256SUMS.txt`: checksums of the kit files.

The downloader was tested **offline only**. A passing offline test suite is not a successful live download test.
