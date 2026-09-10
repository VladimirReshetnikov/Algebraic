# Radical-denesting bibliography: retrieval package

## IMPORTANT — this is not the requested downloaded-paper collection

**No external literature PDF or TeX-source file was successfully downloaded in this chat.**
The browser could read many public documents, but attempts to transfer their bytes into the
file-creation environment failed. The attached ZIP therefore contains a researched catalog
and a downloader, not the papers themselves. Do not treat it as a completed literature archive.

Prepared 5 September 2026 from the three reports in `reports(1).zip`.

## What is included

The three reports contain **278 bibliography occurrences** (93, 99, and 86 respectively).
They are mapped to **105 reference groups**. This is not a claim of 105 distinct papers:
some references group several forum pages or software documents; some conference and journal
versions of one work are grouped. The original wording and the many-to-many key mapping are retained.

The catalog contains **115 planned assets**: 56 PDF routes, 10 TeX-source routes, one repository
bundle with PDF and TeX, 43 web-page routes, and five program-source routes. These numbers count
retrieval targets, not successful downloads or guaranteed freely available publications.

Forty reference groups have a located full-text/source route, 13 have only unverified candidates,
26 are web-resource groups, and 26 have no established download route (one of these has a confirmed
subscription-login redirect). The search was not exhaustive. In particular, an unresolved book or
paper must not be interpreted as unavailable everywhere.

- `INDEX.html`: readable, searchable catalog with direct links and per-item evidence.
- `catalog.json` / `catalog.csv`: deduplicated inventory and download plan.
- `download_routes.csv`: one row per planned asset, with version and evidence level.
- `original_bibliography_entries.json`: all 278 extracted bibliography entries, with the reports' annotations.
- `reference_crosswalk.csv` / `bibliography_key_mapping.json`: original report keys to catalog groups.
- `unresolved_or_candidate_only.csv`: items still lacking an established full-text route.
- `download_all.py`: standard-library Python downloader, described below.
- `test_downloader.py` / `offline_tests.txt`: 13 passing offline tests; these are not live download tests.
- `network_probe_console.txt` / `network_probe_requests.json`: the actual failed transfer probe.

## Retrieve the actual files on a network-connected computer

Requires Python 3.10 or newer. There are no third-party Python dependencies or API keys.
Extract this package, open a terminal in the extracted directory, and run:

**Windows**

```text
py -3 download_all.py --include-candidates --zip radical_literature.zip
```

**macOS / Linux**

```text
python3 download_all.py --include-candidates --zip radical_literature.zip
```

`run_downloads_windows.cmd` and `run_downloads.sh` run the same command. The Windows launcher
pauses so you can read the final result. The downloader also works when called with `python`
on systems where that command is the correct Python 3 interpreter.

The `--include-candidates` option attempts the unverified endpoints too. It does not supply
credentials, use subscription access, or bypass a paywall. Without this option, 14 candidate
assets are skipped and 101 assets are planned. Even the non-candidate routes can fail later.

Useful examples:

```text
python3 download_all.py --dry-run
python3 download_all.py --only cavallo,barbero,euclid --zip selected_literature.zip
python3 download_all.py --no-web --include-candidates --zip papers_and_sources.zip
```

Use `py -3` in place of `python3` on Windows. `--no-web` excludes software/documentation/forum
records, but retains books. `--timeout`, `--retries`, `--max-mb`, and `--output` are configurable.

## Directory layout and pairing

The downloader creates a `literature/` directory, for example:

```text
literature/
  papers/
    cavallo-Denesting-cubic-radicals/
      arxiv-2403.04776v2/
        paper.pdf
        tex-source.tar.gz       [or .tex.gz/.tex, according to the response]
        source/
          ...original TeX/Bib/figure files...
        bibliography.json
    barbero-.../
      jis-2013/
        paper.pdf
        ...publisher-provided TeX...
    euclid-Elements/
      fitzpatrick-repository-snapshot/
        paper.pdf
        tex-pdf-bundle.zip
        source-snapshot/
  web_resources/
    ...HTML documentation, discussions, and program source...
  download_manifest.json
  download_status.csv
  request_log.json
  catalog_used.json
```

Nine arXiv entries have their PDF and source requests pinned to the same explicit version.
The JIS Barbero–Cerruti–Murru–Abrate paper uses the publisher's PDF and the LaTeX link on the
same article page. The Euclid source repository is resolved to one Git commit at download time;
its own bundled `Elements.pdf` is paired with the source snapshot. A separately hosted Euclid
PDF is kept in a different version directory rather than being asserted identical to the repository build.

Technical reports, preprints, publisher versions, scans, translations, and multipart articles
are labelled separately where identified. For Shanks's *Incredible identities*, the two scanned
parts are separate targets, not mirrors. Software source is never labelled as a paper's TeX source.

## Validation, resumption, and reporting

A PDF response must contain a PDF header and terminal EOF marker. HTML login/challenge pages
are not saved as `.pdf`. This is a basic response-format check, not full PDF parsing, a malware
scan, or an automated scholarly identity check. Review unfamiliar versions before citing them.

Source downloads may be a tar archive, compressed archive, gzipped single TeX file, or plain TeX.
The source response is retained; regular archive members are safely extracted without executing
or compiling anything. Path traversal, archive symlinks, oversized expansions, and archives with
no TeX are rejected. Binary font files are omitted from extracted source trees. No local system
fonts are included in this retrieval package.

Completed files receive SHA-256 receipts. Repeating the command resumes files only after their
stored hashes are checked. Requests are sequential, with bounded retries and rate limiting
(at least 3.2 seconds between arXiv requests). A failed source retrieval does not erase a PDF.
A source without a successfully obtained PDF is accurately reported, not called a complete pair.

`download_manifest.json` is the authoritative account of what was actually retrieved. The
resulting ZIP contains successfully received files and provenance, not dummy PDFs, summaries
substituted for papers, or empty folders for unavailable works. If zero assets succeed, no
literature ZIP is created. The exit code is 2 when any planned download fails, even when others
succeed; inspect the manifest. Interrupted runs can be resumed.

## Evidence and unresolved items

`browser_fulltext` means that the browser opened the actual PDF (and the work was identified).
`search_indexed_pdf` / `search_indexed_fulltext` mean a search service indexed the named full-text
resource; they do not prove current byte-level retrieval. `download_link_listed` means a relevant
repository or publication page advertises a download. `repository_pdf_and_source_links` means the
repository lists those formats. `candidate_unverified` includes old report URLs, unconfirmed
publisher endpoints, and a few explicitly labelled constructed routes. `cited_web_resource`
means that the URL came from one of the reports and has not necessarily been independently reopened.

A repository landing-page resolver follows only explicit PDF/TeX links or standard PDF metadata,
not a general crawl through references. JavaScript-only pages, anti-bot systems, expiring tokens,
or changed repository interfaces can require manual inspection. These failures are recorded.

The reports' bibliographic assertions have not all been independently verified. The original
annotations are preserved as input, not adopted as certified facts. One identified problem is
calling Fateman's 1972 MIT technical report an MIT PhD thesis; the catalog does not certify that
institutional attribution. Another is a Stockholm thesis-register PDF, which was excluded because
it is not the cited thesis. A related MathNet cubic-radical paper was not silently substituted for
an uncertain cited work. The RCSI link for Osipov's 2026 paper redirects to a subscription login.

Only public, unauthenticated retrieval is attempted. Free-to-read status is not a blanket licence
to republish a work. Respect the copyright and licence statements supplied by each author,
repository, publisher, or software project. No claim is made that every available work has been
located, or that all listed links will remain accessible.

## Tests and the transfer failure

Run the local tests with:

```text
python3 -m unittest -v test_downloader
```

Thirteen offline tests passed: PDF-format checks; plain/gzipped/archive TeX; malicious path and
symlink rejection; source-versus-PDF distinction; landing-link parsing; receipt checks; and catalog
consistency. No synthetic PDF/TeX fixture is shipped as a literature file; the tiny fixtures exist
only inside the test code.

The live probe of the Cavallo arXiv PDF and two source routes failed with
`Temporary failure in name resolution`. A direct-IP network probe also failed, and the separate
file-transfer tool failed. Consequently, the downloaded-PDF and downloaded-TeX counts for this
package are both **zero**. Live end-to-end success of the downloader has not been established here.
