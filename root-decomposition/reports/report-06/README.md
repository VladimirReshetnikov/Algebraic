# Low-degree decompositions of algebraic numbers

This archive accompanies **Decomposing Algebraic Roots into Low-Degree Sums and Products** (6 September 2026).

## Files

- `article.pdf` and `article.tex`: the article, proofs, examples, bibliography, and complete implementation appendix.
- `RootDecomposition.wl`: the Wolfram Language reference package.
- `demo.wl`: a self-contained session for the two requested examples.
- `tests.wlt`: native Wolfram Language verification tests, supplied but not executed during preparation.
- `verify.py`, `verify_algorithms.py`: independently executed exact SymPy checks.
- `verification.txt`, `algorithm_verification.txt`, `algorithm_verification.json`: results of those independent checks.

## Main results and scope

Both original degree-nine examples have globally optimal maximum component degree **3**. This remains optimal even when arbitrarily many components in arbitrary algebraic extensions are permitted.

The additive problem has a complete finite mathematical algorithm: pass to the normal closure, enumerate its embedded subfields, and test membership in sums of their rational vector spaces. The article proves the normalized-trace descent theorem that justifies this reduction. The elementary subfield enumeration can be extremely expensive; explicit resource caps are enabled by default.

For multiplication, the implemented field-based optimizer is complete for **at most two factors in a specified number field**. Its criterion is `E intersect alpha F != {0}`. The implementation does not claim a universally terminating optimizer for arbitrary-length products in arbitrary extensions. Bounded candidate and catalog searches are provided with their scopes explicitly stated.

An additional example proves that the product input has additive minimum 9 inside its own degree-nine field, but global additive minimum 6. The article gives an explicit sextic decomposition and a proof of its optimality.

## Wolfram Language usage

From the extracted directory:

```wl
Get["demo.wl"]
TestReport["tests.wlt"]
```

Or load only the package:

```wl
Get["RootDecomposition.wl"];
MinTwoFactorInField[alphaProduct]
MinSumGlobally[alphaSum]
```

`demo.wl` defines `alphaProduct` and `alphaSum` explicitly. Results contain the component list, degrees, exact identity check, scope, and any global optimality certificate. Use `"AmbientGenerator" -> theta` with the internal field routines to specify a different field.

A `Failure` caused by a resource limit, an unsupported input, or an arithmetic/checking failure is **not a proof of nonexistence**. The finite catalog and coefficient-height searches do not certify unrestricted nonexistence either. Disabling caps is a mathematical exhaustive-search option, not a performance recommendation. The normal-closure degree guard is checked after construction of the common field; use an outer `TimeConstrained` when a time budget is needed.

## Validation status

No native Wolfram Language execution is claimed. The available Wolfram service returned HTTP 404, and there was no local Wolfram kernel. The `.wl` implementation was reviewed and syntax delimiters were checked. The `.wlt` tests remain to be run in Mathematica.

Independent exact algorithms were executed using **Python 3 and SymPy 1.14.0**. They verified the requested resultants, irreducibility and real-root counts, embedded subfields, rational row-space and nullspace algorithms, internal minima, the sextic elimination identity, and additional degree counterexamples. These checks support the mathematics and algorithm design; they are not a substitute for native regression testing of every Wolfram Language interface.

Rerun them with:

```sh
python verify.py
python verify_algorithms.py
```

SymPy is required. The second script writes `algorithm_verification.json` next to itself. To refresh the text logs, redirect standard output to the corresponding `.txt` files. Decimal roots in `verification.txt` are only orientation aids; the assertions are exact.

## Rebuilding the PDF

Keep `article.tex` and `RootDecomposition.wl` in the same directory, because the article includes the package directly as its appendix.

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

The source uses standard LaTeX packages including AMS mathematics, Latin Modern, microtype, listings, hyperref, geometry, fancyhdr, and booktabs. No separate bibliography processor is needed.
