# Decomposing polynomial roots into low-degree sums and products

The article is `algebraic_root_decomposition.pdf`; its editable source is
`algebraic_root_decomposition.tex`. Both original degree-nine examples have
**globally optimal maximum operand degree 3**, even allowing arbitrarily many
operands and complex algebraic numbers.

## Wolfram Language package

Load `code/RootDecomposition.wl` with `Get`, or run `code/Examples.wl`.

```wl
Get["/absolute/path/to/code/RootDecomposition.wl"];
FindRootPairByHeight[alpha, "Product", "MaximumDegree" -> 3,
  "CoefficientHeight" -> 1]
MinimumRootSum[alpha]
MinimumRootProductPair[alpha]
SearchRootProducts[alpha, candidateFactors, "MaximumDegree" -> 3,
  "MaximumFactors" -> 4]
```

The `Terms` field contains the exact factors or summands. Inspect
`MaximumDegree`, `GlobalMinimumProved`, and, for the binary product solver,
`TwoFactorMinimumProved`. A `Failure` or `NotFoundInBounds` is not a proof of
nonexistence. Finite resource budgets are deliberate; a partial subfield list
never justifies a global negative result.

`MinimumRootSum` is a complete global minimizer when it has a Galois ambient
field and an exhaustive subfield list. Use `"NormalClosure" -> True` to request
one. Setting `"MaximumAmbientDegree" -> Infinity`, `"MaxNodes" -> Infinity`,
and `"TimeConstraint" -> Infinity` removes the practical limits; the algorithm
is finite but potentially very expensive. `MinimumRootProductPair` has the
corresponding completeness guarantee **only for two factors**. The arbitrary-
arity product routine is a certified bounded search, not an unconditional
terminating global minimizer. The article proves why binary recursion is not
a substitute for arbitrary arity.

## Verification status

**No native Wolfram kernel execution is claimed.** The available Wolfram
connector returned HTTP 404. `code/Tests.wlt` contains 23 regression tests to run
with `TestReport["/absolute/path/to/code/Tests.wlt"]` in Mathematica.

The independent exact SymPy verifier **was executed**: 40 checks passed using
Python 3.13.5 and SymPy 1.14.0. These check resultants, irreducibility, real-root
isolation, rational recovery formulas, power-basis coordinates, bounded cubic
discovery, and the two-versus-three-factor counterexample. They do not certify
native Wolfram evaluation behavior. A lightweight source delimiter check is
also included; it is not a full parser.

Run it again with:

```sh
python verification/verify_exact.py
```

Results are in `verification/verification_results.{json,txt}`.

## Rebuilding the article

From this directory, with a standard TeX Live installation:

```sh
latexmk -pdf -interaction=nonstopmode -halt-on-error algebraic_root_decomposition.tex
```

The source uses ordinary LaTeX packages and does not require shell escape,
network access, or any external images. Code listings are included directly
from the accompanying source files. No font files are distributed.
