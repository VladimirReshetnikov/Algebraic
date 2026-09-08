# Validation record — 7 September 2026

## Executed successfully

`reference_validation.py` implements the mathematics independently with
Python/SymPy exact rational and algebraic number fields. It uses no numerical
zero tests. The saved report is `validation_results.json`.

Environment: Python 3.13.5; SymPy 1.14.0. Random seed: 206618.

| Category | Checks |
|---|---:|
| User sextic and degree-24 nested example | 2 |
| Power and Chebyshev complete enumerations | 6 |
| Quintic algebraic coefficient fixture | 1 |
| Quintic coefficient with independent square root of 3 | 1 |
| Generated exact composites over six coefficient fields | 144 |
| Independent triangular-recurrence comparisons | 72 |
| Exact residual identities and pivot conditions over all candidate degrees | 348 |
| Members of the absolutely indecomposable family x^n+x | 27 |
| Comparisons against SymPy's separate rational decomposition routine | 28 |
| Boundary and structural regression inputs | 6 |

These categories overlap and should not be summed as independent trials.
The generated cases include nonmonic/nonzero-constant right components so
that affine normalization is checked, not assumed. Every generated designated
pair is compared against its exactly known normalized pair. Every generated
complete chain is recomposed and its factors are tested for indecomposability.
The rational oracle comparisons check degree multisets and exact identities.

`check_wl_structure.py` also passed on the six Wolfram source files. It checks
balanced delimiters, strings, and nested comments only. It is **not** a Wolfram
parser, semantic checker, evaluator, or proof of package correctness.

## Not executed in a Wolfram kernel

The connected Wolfram evaluator was actually invoked but its MCP endpoint
returned HTTP 404. No local Wolfram executable was available. Thus:

- The 53 `VerificationTest` specifications are supplied but not claimed to pass.
- There is no native Wolfram timing or compatibility benchmark in this release.
- Python validation supports the algorithm and examples, not every Wolfram
  evaluation detail or algebraic-number representation issue.
- The latest Wolfram sources were reviewed and lexically checked, but source
  review does not replace execution of the supplied test suite.

Run `wolframscript -file Tests/RunTests.wls` in a working Wolfram environment.
The runner prints the kernel version, checks report properties appropriate to
that kernel, requires success and exactly 53 observed tests, and exports a
native WXF report. Inspect failing tests and unexpected messages before use.

## PDF and archive checks

The LaTeX article was compiled with pdfLaTeX/latexmk. Its final build had no
undefined references or overfull boxes. The PDF was rendered and its page
layouts inspected. These are document-production checks, not mathematical or
software-execution verification. The archive's SHA256SUMS file covers all
other distributed files.

## Mathematical proof versus experiments

The article proves the fixed-degree candidate theorem, exact residual test,
field descent, complete enumeration, and the right-component poset claims.
The experiments are supplementary finite checks. They do not replace those
proofs, and neither the mathematical proofs nor the Python checks constitute
a formal verification of Wolfram's algebraic arithmetic or this package.
