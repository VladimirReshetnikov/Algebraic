# Decomposing Algebraic Numbers into Low-Degree Roots

Prepared for Vladimir Reshetnikov, September 6, 2026.

## Read first

`article.pdf` is the complete article; `article.tex` is its editable LaTeX
source. Both degree-nine examples in the question have globally optimal
largest part-degree **3**, even allowing arbitrarily many summands/factors.

The article and package carefully separate three guarantees:

* The normal-field additive method is complete for **all finite sums**.
* The norm/intersection product method is complete for **at most two factors**,
  allowing factors in arbitrary algebraic extensions, not just the model field.
* Arbitrary-length product search is bounded by a dictionary and part count.
  A general terminating global optimizer for arbitrary-length products is NOT
  supplied. A result meeting an independent lower bound is globally optimal.

## Files

- `article.tex`, `article.pdf`: article and compiled PDF.
- `RootDecomposition.wl`: Wolfram Language package, also printed in the article.
- `examples.wl`: example session, including both requested inputs.
- `tests.wlt`: Wolfram Language regression tests.
- `validate_independently.py`: independent mathematical checks using SymPy.
- `validation.json`, `validation.txt`: results of the independent checks.
- `Makefile`: convenience commands for rebuilding and independent validation.

## Mathematica usage

Set the working directory to the extracted directory, then evaluate:

```wolfram
Get["examples.wl"]
TestReport["tests.wlt"]
```

To load only the package:

```wolfram
Get["RootDecomposition.wl"]
```

The main calls for the supplied targets are:

```wolfram
FindRootPair[productTarget, Times, 3, 1, "TimeLimit" -> 120]
FindRootPair[sumTarget, Plus, 3, 1, "TimeLimit" -> 120]
```

`3` bounds absolute degree over Q. `1` bounds the coefficient height of the
first part's primitive integer minimal polynomial. The other polynomial has
no height bound. Input must be exact; unassign polynomial variables before use.

For the expensive complete methods:

```wolfram
model = BuildNormalFieldModel[sumTarget,
  "TimeLimit" -> 1800, "MaxNormalDegree" -> 48];
If[! FailureQ[model],
  CompleteSumDecomposition[sumTarget, model]
]
If[! FailureQ[model],
  CompleteProductPairDecomposition[productTarget, model]
]
```

The two example targets generate the same degree-nine field and have a common
normal closure of degree 36. A full model can therefore be reused. Do not
hand-modify a model or assert that an incomplete subfield list is complete.
The constructor's normal-degree limit is checked AFTER primitive-element
construction; it does not avoid the cost of that construction. Its time limit
covers construction, but later exact searches can also be expensive.

A `TimedOut`, `CandidateLimit`, or normal-field construction `Failure` is not a
proof of nonexistence. A `NotFoundWithinBounds` or dictionary-negative status
has only the bounded scope described in the article.

## Validation status — important

The Wolfram evaluation connector returned HTTP 404, and no Wolfram kernel was
available locally. **The Wolfram package and its .wlt tests were not executed
in a Wolfram kernel here.** Do not interpret the independent results as a
Wolfram test report or a timing/compatibility benchmark.

The Python validator was executed with SymPy 1.14.0. All 32 independent checks
passed. They check the exact algebraic identities, degrees, branch-related
real-root counts, resultant factor profiles, larger examples, a group lattice,
and small linear-algebra models. Delimiter checks on the Wolfram source are
only basic static checks, not a Wolfram syntax or execution test.

Run the independent checks with:

```sh
python validate_independently.py
```

## Rebuild the article

A standard TeX Live installation with newtx, amsmath/amsthm, microtype, listings,
and the other packages in the preamble is required. Keep the .wl file beside
article.tex because the appendix includes it directly.

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

The bibliography is embedded in the TeX source; BibTeX is not required. The PDF
was rendered and visually inspected, and the final build has no overfull-box
or unresolved-reference warnings.
