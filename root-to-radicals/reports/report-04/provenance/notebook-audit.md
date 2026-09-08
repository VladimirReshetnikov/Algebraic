# Uploaded notebook: inspection provenance

Input archive: FindExtension.zip. Its single notebook entry is
FindExtension.nb (986,737 bytes).

Notebook SHA-256:
`d70951fdb88128556ee7ea762652413b6f8b5e970c4437c2f3293d9b07eac007`

The notebook was read as text and parsed with an inert box-expression reader.
No notebook cells, initialization code, Dynamic expressions, or external calls
were evaluated. The extraction recovered 220 Input cells (75,270 bytes of
human-readable input text). It is an inspection aid, not a lossless executable
conversion of arbitrary Mathematica boxes.

Observed algorithm families:

- radicalDepth: estimates radical nesting and related expression complexity.
- findExtension / findExtension3: seek quadratic/cubic factor coefficients
  through polynomial remainders and elimination.
- project: inspect lower-degree real or imaginary parts of conjugates.
- factor / solve: select factors or roots using PossibleZeroQ tests.
- fuzz: random conjugate-subset sums, high-precision RootApproximant proposals,
  and an unbounded While[True] search.
- simplify: private simplifier complexity functions and increasing time budgets.

The text includes a Simplify`SimpifyCount spelling as well as references to
Simplify`SimplifyCount. No undocumented Wolfram simplifier is used by the new
engine. The new code does not treat RootApproximant or a small numerical
residual as a certificate. It does not claim to have solved every large number
occurring among the 220 experimental cells.

The uploaded original is not redistributed in this package. The included
extract_notebook.py is the inspection utility; it is not required by the solver.
Usage: `python extract_notebook.py /path/to/FindExtension.nb --output inputs.txt`.

Original question: Mathematica Stack Exchange question 34011,
“Why is ToRadicals not able to handle all cases? Is there a workaround?”
The article includes full primary-source references.
