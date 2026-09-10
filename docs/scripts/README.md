# Literature download scripts

Three independently prepared packages for downloading the freely available
literature cited in the three unified literature reports (since merged into
`docs/report`). All three were produced in
environments without outbound network access, so none had been executed against
the live sites before 5 September 2026.

| Package | Groups with a route | Planned assets | Resolvers | Tests | Notes |
|---|---:|---:|---|---:|---|
| `radical_denesting_download_kit` | 84 / 107 | 94 (+7 optional publisher probes) | landing page (PDF/TeX links, `citation_pdf_url`) | 18 | Python 3.9+; writes output beside the script; crashes on a cp1252 console when printing titles with "√" |
| `radical_denesting_literature_partial` | 62 / 107 | 10 explicit + 10 arXiv pairs (only 24 items are literature with routes) | none (explicit URLs only) | 8 | writes downloads into its own directory; refers to five "recovered" PDFs that are not present; same console crash |
| `radical_literature_retrieval_package` | 79 / 105 | 115 (101 without `--include-candidates`) | landing page, NASA NTRS API, Internet Archive metadata API, GitHub commit API; safe redirects; per-asset receipts | 13 | Python 3.10+; enforces a separate output directory; evidence level recorded per route |

All three test suites pass under Python 3.14 on Windows.

## Choice

`radical_literature_retrieval_package` was selected: it has the widest set of
retrieval mechanisms, the most explicit provenance (evidence levels, receipts
with SHA-256, request log), the cleanest output separation, and the most planned
full-text assets. The download kit is a close second and knows a few routes the
retrieval package lacks; those were added by
`radical_literature_retrieval_package/add_supplementary_routes.py`
(Fateman's MIT-LCS-TR-095 from the CSAIL server, Antipov via MathNet, Krepkii
via the SPbU journal, and the arXiv version of Barbero et al.).

## Corrections made to the selected script

1. Console streams are reconfigured to UTF-8 so titles containing "√" do not
   crash the run on a Windows console.
2. Two new opt-in options: `--insecure-hosts host1,host2` skips TLS certificate
   verification for the listed hosts only, and `--insecure` skips it for all
   hosts. Either fact is recorded in each file's provenance
   (`tls_verification`). The first pass hit a chain on `web.cs.umass.edu`
   ending in an eMudhra root that Python's trust store does not contain; the
   second pass was run with `--insecure`.
3. A new `--user-agent` option (recorded in provenance); several public hosts
   reject the script's honest default agent with HTTP 403.

## Outcome (5 September 2026)

Pass 1: 80 assets retrieved, 35 failed (3 × HTTP 429, 3 × TLS chain, 16 × 403,
rest bot blocks, 404s, dead host). Pass 2 with the supplement, `--insecure`, more
retries and a browser agent: 94 of 120 assets retrieved (48 PDFs, 44 TeX files,
64 works with at least one file). The 26 remaining failures are ResearchGate,
IEEE, ScienceDirect and Taylor & Francis routes (bot blocks or paywalls), a dead
Berkeley host, a script-rendered landing page (Siegel), a NASA record with no
file, and web pages that refuse non-browser clients. Console logs of both passes
are `docs/literature/run_pass1.txt` and `run_pass2.txt`.

One file obtained by hand was then registered with
`radical_literature_retrieval_package/register_manual_file.py`, which copies a
file into the record's version folder and updates the manifest with its
SHA-256 and origin: the Internet Archive scan of Fateman's MIT-LCS-TR-095 (a
different scan from the CSAIL copy). The former `docs/articles/` directory was
then folded into the dataset: its four scans that were byte-identical to
downloaded files were dropped, the six corrected re-typesettings (LaTeX,
PDF, corrections log) were moved to `papers/<record>/retypeset-2026/`
(see `docs/literature/RETYPESET_ARTICLES.md`), and the Wikipedia snapshot to
`web_resources/wikipedia-Nested-radical/snapshot-pdf-2026/`. Final tally:
102 assets, 54 PDFs, 49 TeX files, 66 works.

## How the files were obtained

```text
cd docs/scripts/radical_literature_retrieval_package
python download_all.py --include-candidates --output ../../literature --timeout 45 --retries 1
python add_supplementary_routes.py
python download_all.py --include-candidates --output ../../literature --timeout 60 --retries 3 --delay 1.5 --insecure --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"
```

The second pass resumes every completed asset from its receipt and retries only
the failures (rate-limited hosts answered 429 on the first pass). The result is
in `docs/literature/`; `docs/literature/download_manifest.json` is the
authoritative record of what was retrieved and what failed, and why.
