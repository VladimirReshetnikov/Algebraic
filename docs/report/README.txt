RADICAL DENESTING: A UNIFIED RESEARCH GUIDE
Research cutoff: September 5, 2026

This directory (docs/report) is the single unified report on the
radical-denesting literature. It was originally one of three unified reports
prepared independently from the same four-report corpus (then
docs/reports/report-1, report-2 and report-3). On September 5, 2026 the other
two were merged into this one: their overlapping exposition was consolidated,
their unique material, bibliography entries and verification checks were
retained, and the two source directories were deleted; the survivor was then
moved to docs/report. Section 1.4 of the report lists what was folded in from
each.

CONTENTS

radical_denesting_unified.pdf
    The unified report, with annotated bibliography (103 entries).

radical_denesting_unified.tex
    Complete, self-contained LaTeX source. Bibliographic entries are embedded
    in the source; no external .bib file, images, or source-report files are
    needed to compile it.

verify.py
    Merged exact-check script: the checks of all three unified reports
    (polynomial-remainder certificates for the identities, the restricted
    cubic-in-quadratic criterion with a 210-case constructed sweep, Honsbeek's
    quartic certificate, minimal-polynomial checks) plus recorded SymPy
    sqrtdenest and nthroot observations. Not a general denesting implementation.

verification_results.txt
    Execution transcript of verify.py (Python 3.14.4, SymPy 1.14.0).

verification_results.json
    Machine-readable record of the same run, including the observed SymPy outputs.

source_inventory.tsv
    Names, byte lengths, SHA-256 hashes, and roles of all 10 non-directory
    members of the supplied reports.zip archive (four reports plus alternate
    renderings and illustrations).

source_links.tsv
    A deduplicated provenance register of literal HTTP(S) links found in the
    four supplied Markdown reports. Inclusion is NOT independent endorsement
    or a successful-link test.

quality_checks.txt
    Build, citation, and computation checks performed for this edition.

BUILDING THE PDF

From the directory containing the .tex file, run pdflatex three times:

    pdflatex -interaction=nonstopmode -halt-on-error radical_denesting_unified.tex

Alternatively: latexmk -pdf radical_denesting_unified.tex

The source uses the standard article class and packages including newpxtext,
newpxmath, amsmath, amsthm, mathtools, geometry, microtype, booktabs, longtable,
enumitem, xcolor, fancyhdr, titlesec, listings, xurl, hyperref, bookmark, and
etoolbox. No shell escape or network access is required.

RUNNING THE EXACT CHECKS

Python 3.10 or later and SymPy are required (recorded run: SymPy 1.14.0):

    python verify.py

Polynomial reduction proves the selected algebraic identities; separate
rational inequalities select the even-root branches. The non-denesting
interpretation of some cases relies on the cited structural theorems, not
on a claim that the script implements those theorems. A None result of the
cubic-in-quadratic routine means that the specified quadratic-field
representation fails, not that every unnested radical representation is
impossible.

EDITORIAL AND EVIDENCE NOTES

The four AI-generated reports were treated as discovery leads. Overlapping
exposition and publication versions were consolidated. Mathematical mistakes,
misdated bibliography entries, and overbroad complexity or software claims
were corrected or qualified. The report distinguishes finite denesting from
infinite-radical convergence, equality from comparison, field normalization
from minimum-depth optimization, and real from complex branch conventions.

Access labels in the bibliography distinguish inspected relevant full text,
authoritative metadata or abstracts, documentation or author source, and
retained background or unresolved leads. Full-text inspection does not mean
that every theorem in a source was independently verified. The report is not
claimed to be an exhaustive bibliography. Only SymPy was executed; other CAS
examples are documented usage, explicitly labeled unexecuted.

The freely available literature cited here has been collected separately in
docs/literature (see docs/scripts/README.md for how it was obtained).

INPUT ARCHIVE

Filename: reports.zip
SHA-256: 807612a46993418ac6340c18f751b318a63dd1b5f4eee68e99de003af355fe97
