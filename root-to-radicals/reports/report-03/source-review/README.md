# Inspection of the supplied notebook

Source: `FindExtension.zip`, supplied by Vladimir Reshetnikov in this conversation.
The original archive was inspected without evaluating its contents. It contains
`FindExtension.nb` (986,737 bytes). A non-executing box transcription located 220
Input cells. `notebook_inputs.txt` records those cells with source notebook line
numbers. It is **diagnostic text, not an executable reconstruction**: some special
boxes, quantifiers and formatting survive, and outputs are not reproduced.

SHA-256 of the original archive:
`381e80382e8736aa00e18d8fd48c6f391b9ba0b15e80ff7621e7589147174930`

SHA-256 of the original notebook:
`d70951fdb88128556ee7ea762652413b6f8b5e970c4437c2f3293d9b07eac007`

## Main observations

* Input cells 2 and 3 (`findExtension`, `findExtension3`, notebook lines 65 and
  126) eliminate the coefficients of quadratic/cubic candidate factors and
  choose a low-complexity coefficient. This is useful subfield discovery, but
  it does not enumerate a complete Galois-theoretic radical tower.
* Cell 1 includes `Sin` and `Cos` in a depth cost. A small such cost does not
  certify that an expression consists only of radicals.
* The name `Simplify\`SimpifyCount` occurs literally in cells 2 and 3. It differs
  from `Simplify\`SimplifyCount` used later; neither is a public API on which the
  replacement package relies.
* Cells 4--7 inspect real/imaginary parts, factor over guessed extensions and
  select solutions using `PossibleZeroQ`. They assume particular Root internal
  forms and often index the first candidate without a separate empty-result
  status. The replacement always retains the exact selected value, uses its
  minimal polynomial and returns explicit status data.
* Cell 8 samples subsets of roots, recognizes a polynomial numerically using
  `RootApproximant[N[sum,400],max]`, and loops with `While[True]`. Recognition is
  a proposal, not a termination proof or standalone equality certificate.
* Cell 9 increases simplification timeouts and uses session-defined transforms.
  Later cells contain `%`, `%%`, accumulated definitions and manual extension
  choices. The notebook is a research session, not an isolated package.
* The inverse-beta numerical experiments cannot establish equality of a
  transcendental-looking input with its RootApproximant by themselves. The
  delivered package accepts an exact algebraic input, not this recognition task.

## How these ideas enter the replacement

The Wolfram front end accepts explicit radical `ExtensionHints`, factors over
their compositum, and certifies the selected factor/root. Rational reciprocal
symmetry, Dickson structure and composition automate several useful patterns.
A separate splitting-field/Fourier backend removes the *mathematical* restriction
to finding quadratic or cubic factors. It does not claim the whole experimental
notebook was reproduced within a practical resource budget.

The notebook-derived text remains attributed to its original contributor. The
new-code MIT license does not relicense that source material.
