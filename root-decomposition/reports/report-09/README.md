# Decomposing algebraic numbers into low-degree sums and products

Prepared 6 September 2026 for Mathematica StackExchange question 105933.

## Contents

- `article.pdf`: the detailed article, proofs, examples, and full Wolfram source.
- `article.tex`: LaTeX source; requires `RootDecomposition.wl` beside it.
- `RootDecomposition.wl`: certificate-oriented Wolfram Language reference package.
- `examples.wl`: executable usage examples; optional expensive examples are commented.
- `tests.wlt`: Wolfram Language regression suite for local execution.
- `verify_exact.py`: independent, exact SymPy implementation and verification.
- `verification_results.json`: actual output of that independent verification.
- `build.sh`: builds the PDF with pdflatex.

## Mathematical guarantees

Both supplied degree-nine examples have globally optimal maximum degree 3.
The article gives exact polynomial remainder certificates for the two identities,
and a lower bound ruling out ANY finite collection of degree-at-most-two terms
or factors, including those outside the input field.

The subfield algorithm is complete for a finite ambient number field.
The additive algorithm is complete in that field. Passing to a normal closure
makes the additive optimization globally complete, as proved in the article.

The product algorithm is complete for two factors in the input field. It also
searches linearly disjoint multi-field tensor families. These are restricted
classes: this package is NOT a general unrestricted global multiplicative
minimax solver. A lower-bound certificate can nevertheless prove that a
returned product is globally optimal, as it does for both product examples.
The bounded enumeration routine is complete only inside its explicit degree,
primitive-polynomial coefficient-height, and length bounds.

Default resource limits can stop an otherwise complete mathematical procedure.
A resource failure or a bounded-search miss is never a general impossibility
certificate. Read `GlobalOptimalityCertified` and `OptimalityScope`, not just
`MaximumDegree`. A false global flag means “not certified,” not “nonoptimal.”
The algorithms optimize maximum absolute degree, not term count or typography.

## Wolfram Language use

    Get["/your/path/RootDecomposition.wl"];
    result = ProductDecomposition[alpha];
    DecompositionExpression[result]

For sums use `GlobalAdditiveDecomposition[alpha]`, or
`AdditiveDecomposition[alpha]` to restrict all terms to Q(alpha).
Load `examples.wl` for the concrete inputs.
Run the supplied Wolfram tests with:

    TestReport["/your/path/tests.wlt"]

Use exact algebraic inputs, not floating-point approximations. The package
rejects expressions containing approximate `Real` atoms. Rational factors or
terms can appear as ordinary numbers rather than unevaluated `Root` objects.

## Verification status

The Wolfram connector was actually tried and returned HTTP 404 before any
kernel evaluation. Therefore neither the package nor `tests.wlt` was executed
in Mathematica during preparation. The source was statically reviewed and its
brackets, nested comments, and strings checked for lexical balance; this is not
a substitute for a Wolfram runtime test.

The independent SymPy program WAS executed with SymPy 1.14.0. All its assertions
passed. It verifies resultants, irreducibility and real-root counts, all six
recovery congruences, principal-subfield recovery, closure of each computed
field under multiplication, additive and binary-product searches, a three-factor
tensor example, and both sextic counterexample field lattices. It does not test
Wolfram evaluation semantics or the normal-closure construction code.

Run independently with Python 3 and SymPy installed:

    python verify_exact.py

This rewrites `verification_results.json`, including the measured elapsed time.
There is no Mathematica timing claim.

## Build

Run `sh build.sh` in this directory. A standard TeX Live installation with
amsmath, amssymb, amsthm, geometry, microtype, lmodern, listings, xcolor,
fancyhdr, booktabs, longtable, array, xurl, hyperref, and enumitem is sufficient.
The archive contains no font files and no third-party paper copies.
