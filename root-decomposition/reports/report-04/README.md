# Decomposing Algebraic Numbers into Low-Degree Roots

Prepared 6 September 2026 for the problem at
https://mathematica.stackexchange.com/q/105933/7288.

## Contents

- `article.pdf`: the complete mathematical and implementation article.
- `article.tex`: self-contained LaTeX source, with an embedded bibliography.
- `RootDecomposition.wl`: Wolfram Language reference implementation.
- `tests.wlt`: 17 practical Wolfram regression tests.
- `global-tests.wlt`: 4 optional tests, including expensive normal-closure computations.
- `verify.py`: independent exact-arithmetic verification with SymPy.
- `validation.txt`: the actual execution log of `verify.py`; all 50 checks passed.
- `build.sh`: a minimal PDF rebuild script.

No external images, fonts, bibliography databases, or proprietary packages are
needed to compile the article. The Wolfram implementation uses built-in exact
algebraic-number and linear-algebra operations.

## What is solved and what is certified

The two degree-nine examples are recovered as the product and sum of the real
roots of x^3+x+1 and x^3-x+1. Their optimal largest component degree is exactly
three, even allowing arbitrarily many complex components.

The practical inverse-resultant method is complete for a prescribed polynomial
of the first component. The height-bounded catalog makes this a finite search
through a precisely specified class of two-component decompositions. The
finite-pool method handles any specified number of components.

For sums, normalized trace reduces the unrestricted problem to the normal
closure of the input. `RDGlobalSum` implements the resulting finite fixed-field
and rational-span algorithm, with explicit resource guards.

For products, the implementation supplies certified bounded searches, upper
bounds, and elementary global lower bounds. A successful decomposition matching
a proven lower bound is globally optimal. An unsuccessful bounded search is NOT
a proof of global impossibility. This is NOT a claimed universal terminating
optimizer for arbitrary products. The article proves additional obstructions
and the strict separation: the additive minimum of 1+sqrt(2)+sqrt(3) is two,
whereas its multiplicative minimum is four.

`RDSumInFields` minimizes a threshold on the degrees of the supplied fields,
not the actual degrees of all elements that might lie inside larger supplied
fields. See the article's explicit explanation and regression test.

## Mathematica quick start

Set the working directory to this extracted directory, or use absolute paths.
In a notebook:

```wl
Get["RootDecomposition.wl"];
Clear[x];
alphaProduct = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 +
                    2 #^7 + #^9 &, 1];
alphaSum = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 +
                6 #^6 + #^9 &, 1];

rp = RDBoundedSplit[alphaProduct, 3, 1, "Product"];
rs = RDBoundedSplit[alphaSum, 3, 1, "Sum"];
{RDVerify[alphaProduct, rp], RDVerify[alphaSum, rs]}
(* Expected: {True, True} *)

rp["Terms"]
rs["Terms"]
{rp["MaximumDegree"], rs["MaximumDegree"]}
(* Expected: {3, 3} *)
```

A faster search when the first cubic is supplied:

```wl
RDSplitWithPolynomial[alphaProduct, x^3+x+1, x, 3, "Product"]
RDSplitWithPolynomial[alphaSum, x^3+x+1, x, 3, "Sum"]
```

Global additive mode:

```wl
RDGlobalSum[Sqrt[2] + Sqrt[3]]
RDGlobalSum[alphaSum, "TimeLimit" -> 1800, "MaxFieldDegree" -> 48]
```

The first example should give maximum degree two. The second can be expensive;
normal-closure construction is deliberately not the recommended first method
for the two degree-nine examples.

## Validation status

The Wolfram source and `.wlt` suites were NOT executed in a Wolfram kernel during
preparation: the available connector returned HTTP 404 and no local kernel was
installed. The expected outputs are test specifications, not kernel transcripts.

The independent script was executed with Python 3.13.5 and SymPy 1.14.0. It
passed 50 exact checks covering resultants, irreducibility, real-root counts,
recovery identities, subfield enumeration for a biquadratic field, coefficient
ansatz solutions, and the auxiliary examples. Decimal approximations at the end
of the log are illustrative, not certificates. These checks do not substitute
for testing the Wolfram implementation itself.

Run in Mathematica:

```wl
TestReport["tests.wlt"]
TestReport["global-tests.wlt"]
```

The second suite may require substantial time. Timeouts and resource-limit
failures make no nonexistence assertion.

To repeat independent verification:

```sh
python -m pip install sympy
python verify.py
```

The article contains complete mathematical proofs; the Python checks supplement
those proofs rather than replacing them.

## Rebuilding the PDF

With a conventional TeX Live or MiKTeX installation:

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

Or run `sh build.sh` on systems with a POSIX shell. The third pass stabilizes
page references after the table of contents is inserted.
