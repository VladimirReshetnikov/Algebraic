# Decomposing algebraic roots into low-degree sums and products

Prepared for Vladimir Reshetnikov, 6 September 2026.

Read `article.pdf`; its source is `article.tex`.
The article addresses Mathematica StackExchange question 105933:
https://mathematica.stackexchange.com/q/105933/7288

## Results and exact scope

The two requested degree-nine examples are solved globally: the indicated
product and sum each have optimal maximum component degree three, even
when arbitrarily many components from arbitrary algebraic extensions are
allowed.

The article develops a complete finite mathematical algorithm for arbitrary
finite sums, and a complete finite algorithm for TWO-factor products.
The latter includes factors outside the input's splitting field. General
arbitrary-length products are covered by exact bounded search and lower-bound
certificates, not a claimed terminating universal minimizer.

Two additional results are proved:

* The original degree-nine product has optimal additive degree SIX, and
  restricting its summands to Q(alpha) incorrectly raises that minimum to nine.
* alpha = sqrt((1+sqrt(2))(1+sqrt(3))) has optimal product degree FOUR and
  optimal additive degree EIGHT. No product of any number of degree-below-eight
  elements of its splitting field equals alpha. Thus a splitting-field-only
  multiplicative search is not complete. This also corrects the multiplicative
  descent assertion in Theorem 3.1 of Altamirano's 2017 paper; the article gives
  a full counterexample and identifies the zero-coefficient division in its proof.

All degrees are absolute degrees over Q. The components are not restricted to
real numbers or algebraic integers. Dictionary searches include nonmonic
primitive integer polynomials. A bounded miss is not an impossibility proof.

## Contents

- `article.tex`, `article.pdf`: main article, including the complete package listing.
- `code/RootDecomposition.wl`: Wolfram Language reference implementation.
- `code/Examples.wl`: sample calls; expensive splitting-field examples are commented out.
- `code/RootDecomposition.wlt`: basic native test suite.
- `code/ExtendedTests.wlt`: expensive native exact/Galois tests.
- `verification/verify.py`: independent exact polynomial and finite-group checks.
- `verification/results.json`: recorded exact-check results and tool versions.
- `verification/verification.log`: output from that run.
- `verification/check_wl_delimiters.py`: lexical delimiter check, not a native parser.
- `verification/wl_delimiters.log`: recorded lexical-check results.
- `build.sh`, `build.ps1`: PDF rebuild commands.

## Wolfram Language usage

From the extracted archive root:

```wl
Get["code/RootDecomposition.wl"];

ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

SearchRootDecomposition[ap, "Product", 3, 1, 2]
SearchRootDecomposition[as, "Sum",     3, 1, 2]

(* A small complete-field example: *)
g = BuildGaloisData[Sqrt[2]+Sqrt[3]];
CompleteSumDecomposition[Sqrt[2]+Sqrt[3], g]
CompleteTwoFactorDecomposition[Sqrt[2]+Sqrt[3], g]

TestReport["code/RootDecomposition.wlt"]
TestReport["code/ExtendedTests.wlt"]
```

The current directory must be the archive root for these relative paths.
Alternatively, use absolute paths. `Get["code/Examples.wl"]` locates the
package relative to the examples file itself.

A successful result includes `"Parts"`, `"Degrees"`, `"MaximumDegree"`, and
`"GlobalOptimal"`. The latter is true only when the routine establishes a
global lower bound matching its answer. False means "not established", not
necessarily "suboptimal". The complete two-factor routine separately reports
`"OptimalAmongTwoFactors"` and `"TwoFactorLowerBound"`.

Default guards: splitting-field degree 128, 10,000 subgroups, 100,000 polynomial
vectors, 100,000 search nodes. Resource failures are inconclusive. In particular,
`"MaxFieldDegree"` is checked after primitive-element construction and is not a
time limit. The package is intended for exact, reasonably small examples.

## Verification status

The available Wolfram evaluator returned HTTP 404. **Neither native test suite
nor the package has been executed in a Wolfram kernel during preparation.**
Expected outputs in the article are not a native transcript. Native testing is
the remaining implementation-validation step.

Independent exact verification DID execute successfully using Python 3.13.5
and SymPy 1.14.0. It checks resultants, irreducibility, exact real-root counts,
rational and polynomial recovery identities, the sextic pairing identity,
and the group/subgroup calculations used in the proofs. It is not an emulator
of Wolfram evaluation semantics and does not validate package performance.

To repeat:

```text
python verification/verify.py
python verification/check_wl_delimiters.py
```

The Python algebra checks require SymPy. No acceptance test uses floating-point
root matching; numerical values in the JSON output are for display only.

## Rebuilding the PDF

The article uses standard LaTeX packages including newtx, inconsolata,
amsmath, amsthm, listings, tcolorbox, and hyperref. The archive contains no font
binaries. With these packages installed, run from the archive root:

```text
latexmk -pdf -interaction=nonstopmode -halt-on-error article.tex
```

Alternatively run `pdflatex article.tex` twice, or use `build.sh` / `build.ps1`.
The source includes the companion `.wl` file via `\lstinputlisting`, so preserve
the directory layout when compiling.
