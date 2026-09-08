# Supplied notebook audit

Original archive: `FindExtension.zip`.
Member: `FindExtension.nb`, 986737 bytes.
SHA-256: `d70951fdb88128556ee7ea762652413b6f8b5e970c4437c2f3293d9b07eac007`
The inert extractor found 220 Input cells. The original was not evaluated.

Inspected definitions (line numbers refer to original notebook source text):

| Source line | Definition | Observation |
|---:|---|---|
| 21 | `radicalDepth` | Counts nested rational powers and also trigonometric forms; this is not the strict radical grammar used in the new package. |
| 65 | `findExtension` | Uses divisibility by a symbolic quadratic and elimination to propose an extension. A low-degree coefficient field is a useful witness, not a complete search. |
| 126 | `findExtension3` | Analogous symbolic cubic-factor elimination. |
| 182 | `project` | Examines real/imaginary projections and their algebraic degrees. |
| 252 | `factor` | Factors over a proposed extension, and uses PossibleZeroQ for target-dependent selection. |
| 315 | `solve` | Chooses a factor/root using realness and equality heuristics; depends on surrounding definitions. |
| 375 | `roots` | Enumerates conjugates by inspecting Root expressions. |
| 436 | `fuzz` | Random subsets, high-precision sums, RootApproximant and an unbounded search loop. Such guesses require exact post-verification. |
| 560 | `simplify` | Repeated simplification with private complexity helpers, transformations and a special-case exclusion. |

The notebook includes `%`/history references, experimental redefinitions,
unfinished input cells and large examples. Treat it as research material, not
as a clean regression suite. Names from private implementation contexts
(including a misspelled `Simplify` helper occurrence) are not public stable APIs.
The new package does not depend on them.

All three explicitly selected octics below were tested in Python; this is a
small, named sample, not a census of all notebook problems. The target is the
least real root, Python index 0 (Wolfram index 1).

A: x^8+8x^7+20x^6+8x^5-36x^4-48x^3-15x^2+2x+1.

B: x^8+8x^7+10x^6-52x^5-131x^4-28x^3+100x^2+32x+16.

C: x^8+8x^7+16x^6-4x^5-68x^4-28x^3+49x^2+14x+1.

A and B use centering followed by a power reduction. C uses an exact pair-sum
resolvent containing (t^2+4t+1)^2, a quadratic coefficient field and quartic
factorization. Actual statuses, expressions and timings are recorded in
`benchmark.json` and the corresponding tests.

To independently regenerate an inert transcription from the original:

    python tools/inspect_notebook.py /path/to/FindExtension.nb audit.txt

Unsupported boxes are retained visibly; the original notebook is authoritative.
