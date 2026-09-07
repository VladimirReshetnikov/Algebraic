# Decomposing Algebraic Numbers into Low-Degree Roots

## Contents

- `article.pdf` and `article.tex`: the article, including complete proofs and the Wolfram Language source appendix.
- `RootDecomposition.wl`: exact-algebraic decomposition package.
- `examples.wl`: example calls, including discovery of the two cubic factors.
- `tests.wlt`: 28 native Wolfram Language regression tests.
- `slow-tests.wlt`: 4 potentially expensive global additive optimization tests.
- `verify.py`: independently executed exact SymPy and finite-group verification.
- `verification_results.json`: the resulting verification report.
- `build.sh`: PDF rebuild commands.

## Main results

Both degree-nine examples in the question have globally optimal maximum degree 3.
For sums, a proved conjugate-subset criterion gives a finite complete algorithm;
the implementation imposes explicit resource guards and can be expensive.
For a specified pair of embedded number fields, both sum and product splitting
are exactly decidable by rational linear algebra.

The unrestricted product routines are certified searches, not a claimed general
terminating optimizer. They distinguish a verified upper bound from proved global
optimality. No global negative conclusion follows from a failed bounded search.
The article proves that product factors can genuinely require fields outside the
target's normal closure, and explains why that distinction matters.

## Wolfram Language use

Set the working directory to this folder in a native kernel, then evaluate:

```wl
Get["examples.wl"]
TestReport["tests.wlt"]
TestReport["slow-tests.wlt"]
```

Or load only the package:

```wl
Get["RootDecomposition.wl"]
MinimumSumDecomposition[exactAlgebraicNumber]
```

Use exact input; machine-real numbers are rejected. The package's `Terms` list
contains individually normalized values. The `Expression` field uses an inactive
sum/product to preserve its displayed decomposition. `PolynomialRootList` removes
repeated factors and lists distinct roots in square-free polynomial Root order;
`SelectRootPair` returns polynomial/index metadata for those square-free versions.

`MinimumSumDecomposition` defaults to `"MaxConjugates" -> 10` and
`"MaxFieldDegree" -> 4096`. The field-degree guard is checked after constructing
the field. An outer `TimeConstrained` can limit the time spent constructing it.
A resource failure is not mathematical nonexistence.

## Validation status

The available Wolfram evaluator endpoint returned HTTP 404. Therefore neither the
WL package nor either native test suite was executed in a native Wolfram kernel
during preparation. The native test files are provided for that subsequent check;
no native pass count or kernel-version claim is made.

The independent verifier was executed with Python and SymPy 1.14.0. All 50 exact
mathematical assertions passed, including resultants, irreducibility, branch
isolation, reconstruction identities, coefficient-system Groebner bases,
finite-group orbit/span tests, all 110 subgroups of the order-32 counterexample
group, and positive/negative fixed-field linear-algebra tests. These independently
validate the mathematics, not every WL evaluation detail.

Run the checks again with:

```sh
python verify.py
```

The script requires SymPy and writes `verification_results.json` alongside itself.
No network access or numerical algebraic-number recognition is used.

## Rebuilding the PDF

Keep `RootDecomposition.wl` next to `article.tex`, because the TeX appendix includes
that file. A TeX distribution containing `newtx`, `tcolorbox`, `listings`, and the
other standard packages named in the source is required.

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

Run an additional pass after changes that alter the table of contents or page
references. The provided PDF was rendered and visually inspected.
