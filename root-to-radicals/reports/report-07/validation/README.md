# Validation record

Python 3.13.5 / SymPy 1.14.0: **61 tests passed, zero failures, zero errors,
zero skipped**, in 51.72 seconds in the final test run. The JUnit file and
plain log are supplied. Timings vary by environment and load.

The 13-case bounded benchmark contains 11 successful reconstructions, one
exact nonsolvability diagnosis, and one 30-second timeout. All five successful
forced-general small-degree cases passed the independent tower verifier with
embedding and branch checks enabled, including after interprocess transfer.

The 30-second timeout is forced complete reconstruction of x^5-2. Automatic
reconstruction of that same input succeeds through a power reduction. A timeout
is recorded as Inconclusive, never NotSolvable. No full traversal of the
notebook's many historical examples is claimed.

Separate table-based finite-group unit tests exercise S3, S4, A5 and S5. They
test group subroutines, not the construction of embedded S5 splitting fields.
The negative quintic's group is diagnosed by the exact SymPy Galois shortcut.

The Wolfram connector returned HTTP 404. No Wolfram kernel tests were run.
`static_checks.json` records only balanced delimiters and source hashes for the
Wolfram files; these checks do not establish correct Wolfram evaluation.
`Wolfram/tests.wlt` contains the unexecuted kernel tests.

The PDF was built with pdfLaTeX, rendered page by page with pdftoppm and visually
inspected. The final build has no overfull boxes. The article's displayed
benchmark table is generated from these JSON/XML records by
`tools/build_validation_table.py`.
