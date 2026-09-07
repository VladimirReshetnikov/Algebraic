# Decomposing algebraic numbers into low-degree Roots

This archive accompanies the article `root_decomposition.pdf`.

## Contents

- `root_decomposition.tex`: complete LaTeX article, including mathematical proofs,
  examples, documented scope, and the Wolfram Language listings.
- `root_decomposition.pdf`: compiled article.
- `code/RootDecomposition.wl`: Wolfram Language package.
- `code/RunTests.wl`: local Mathematica verification suite.
- `tests/exact_validation.py`: independently executed exact-arithmetic reference
  implementation using SymPy.
- `tests/validation_results.json` and `tests/validation_log.txt`: recorded results.
- `requirements.txt`: Python dependency used for the independent validation.
- `build.sh`: rebuild the PDF with pdfLaTeX.

## What is proved

Both ninth-degree examples in the question decompose into the stated cubic roots.
The maximum component degree 3 is globally optimal, even with arbitrarily many
summands or factors. The article gives explicit rational recovery formulas.

The package contains a complete subfield enumeration algorithm and complete
optimizers for two components in a specified ambient number field. Both addition
and multiplication reduce to exact rational linear algebra. It also gives a
complete global algorithm for arbitrary finite sums, via a normal closure and a
normalized-trace theorem.

For arbitrary finite products in the full algebraic closure, the package provides
bounded exhaustive discovery and exact upper/lower-bound certificates. It does
NOT claim a general terminating global optimizer in that unrestricted setting.
A negative bounded-search result is not a proof of mathematical impossibility.

## Execution status

The Wolfram connector returned HTTP 404 in the authoring session. Consequently,
`RootDecomposition.wl` and `RunTests.wl` have NOT been executed in a Mathematica
kernel. The tests and example comments are expected outputs, not a Mathematica
execution transcript. Run the local test suite before integrating the package
into another automated workflow.

The independent SymPy implementation WAS executed successfully using SymPy
1.14.0. It checks resultants, irreducibility, real-root counts, complete subfield
lists, exact pair decompositions, degrees, rational normalization, the explicit
recovery formulas, and the sextic example where the original ambient field is
too small. All acceptance checks use exact arithmetic. Printed numerical values
only identify real roots. This is independent mathematical validation, not a
substitute for executing the Wolfram Language port.

## Running the code

From the extracted archive directory:

```sh
python -m pip install -r requirements.txt
python tests/exact_validation.py
wolframscript -file code/RunTests.wl
```

Alternatively, open Mathematica and evaluate:

```wl
Get["/absolute/path/to/code/RootDecomposition.wl"];
alpha = Root[-1-#+3#^3-#^4+#^5-3#^6+2#^7+#^9&,1];
answer = RootPairDecompose[alpha, "Product"];
answer["Components"]
answer["MaximumDegree"]
answer["GlobalOptimalityProved"]
```

For an arbitrary algebraic input `alpha`, use
`RootGlobalSumDecompose[alpha]` for unrestricted finite sums. This can be
computationally expensive: a normal closure may have degree as large as the
factorial of the input degree. Use `TimeConstrained` as appropriate; a timeout
provides no nonexistence conclusion.

## Rebuilding the article

```sh
sh build.sh
```

A standard LaTeX installation with pdfLaTeX and the packages named in the source
is required. Keep the `code` directory alongside the `.tex` file: the article
includes those files directly, so the appendix and standalone code remain in sync.
No font files are distributed with this archive.
