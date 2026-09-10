# Source-access and validation ledger

Inspection date: September 5, 2026.

## Repository evidence

1. Target source, recovered and inspected through rendered/raw web windows:
   https://github.com/VladimirReshetnikov/RadicalDenest/blob/main/src/corrected/StradFixed2.wl
   https://raw.githubusercontent.com/VladimirReshetnikov/RadicalDenest/main/src/corrected/StradFixed2.wl

2. Prior unified-B analysis, recovered and read across substantive windows:
   https://github.com/VladimirReshetnikov/RadicalDenest/tree/main/src/code-review/unified-B
   https://raw.githubusercontent.com/VladimirReshetnikov/RadicalDenest/main/src/code-review/unified-B/unified_analysis_B.tex

3. Current literature guide, substantive definitions, theory, software sections, corrections, and bibliography inspected:
   https://github.com/VladimirReshetnikov/RadicalDenest/tree/main/docs/report
   https://raw.githubusercontent.com/VladimirReshetnikov/RadicalDenest/main/docs/report/radical_denesting_unified.tex

4. Literature directory and available directory/README metadata inspected:
   https://github.com/VladimirReshetnikov/RadicalDenest/tree/main/docs/literature
   The child corpus and full manifest/catalog were not reliably retrievable. Relevant accessible primary copies were used instead. The entire downloaded literature corpus was NOT independently audited.

The repository snapshot was not resolved to an immutable commit. Direct container downloads/git retrieval failed. Some initial web fetches failed but later raw/rendered views succeeded. No local byte-identical upstream file or source hash is claimed. Web-rendered line numbers can differ from physical source line numbers; the article uses function names and code anchors instead.

The unified-B report's 116-case battery, 340 structured randomized cases, and 144 passing native regression tests are upstream-reported results. They were not rerun here, and their complete individual execution logs were not independently checked. They are not evidence of native correctness of StradFixed3.

## Relevant primary literature

- Borodin, Fagin, Hopcroft, Tompa (1985), Decreasing the Nesting Depth of Expressions Involving Square Roots:
  https://www.cs.toronto.edu/~bor/Papers/decreasing-nesting-depth-for-expressions.pdf
  Parsed text and page-image inspection used for the square-root/field context.
- Gkioulekas, On the denesting of nested square roots (2017; author manuscript 2016):
  https://faculty.utrgv.edu/eleftherios.gkioulekas/papers/submitted/denesting-square-roots.pdf
  Direct criterion and relevant page image inspected.
- Honsbeek (2005), Radical Extensions and Galois Groups:
  https://www.math.ru.nl/~bosma/students/honsbeek/M_Honsbeek_thesis.pdf
  Relevant Chapter 3 text, Theorem 104, Corollary 105, and formula (3.5) inspected; a relevant page image was successfully read. This is not a claim that the entire thesis was audited.
- Jeffrey and Rich (1999), Simplifying Square Roots of Square Roots by Denesting:
  https://cybertester.com/data/denest.pdf
  Accessible manuscript consulted as algorithmic context. No claim of a complete independent proof audit of this paper.

The mathematical proofs in the article are written out explicitly. The odd-index and square-class developments are derived for this audit; no historical novelty or priority claim is made.

## Official Wolfram documentation consulted

https://reference.wolfram.com/language/ref/Root.html
https://reference.wolfram.com/language/ref/PossibleZeroQ.html
https://reference.wolfram.com/language/ref/RootReduce.html
https://reference.wolfram.com/language/ref/Power.html
https://reference.wolfram.com/language/ref/Order.html
https://reference.wolfram.com/language/ref/TimeConstrained.html
https://reference.wolfram.com/language/ref/MemoryConstrained.html
https://reference.wolfram.com/language/ref/Solve.html

The Root documentation explicitly permits exact nonalgebraic numeric coefficients and symbolic coefficients. The zero-test documentation distinguishes exact algebraic testing from approximate evidence. The resource documentation describes cooperative controls and additional-memory accounting. These contracts are not native execution of the package.

## Execution evidence

Executed: `verification/verify_math.py` under Python 3.13.5 and SymPy 1.14.0. The actual output and package hash are in `verification/results.json` and `verification/results.txt`.

Not executed: all 52 tests in `tests/StradFixed3.wlt`, `tests/probe_original.wls`, and `tests/differential.wls`.

Reason: the installed Wolfram connector's context call and diagnostic evaluator call failed with HTTP 404 from its MCP SSE endpoint at `https://agenttools.wolfram.com/mcp`, before a kernel result was obtained. No local Wolfram kernel/wolframscript or usable alternate evaluator was available. No native log, pass count, runtime, or performance improvement is fabricated.

The GitHub connector was suggested as an alternate retrieval route but was not connected during this task. Source retrieval ultimately succeeded through public web views, not that connector.

## Artifact inspection

The LaTeX source was compiled with pdflatex via latexmk. The resulting PDF was rendered locally and visually inspected using page contact sheets and selected full-size pages. Final compilation has no overfull-box, unresolved-reference, or undefined-citation warnings. The archive does not include third-party source PDFs or font files.
