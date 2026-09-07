# Decomposing algebraic Roots into sums and products of minimum degree

This archive accompanies the article answering Mathematica Stack Exchange
question 105933. The degree cost of a component is its absolute degree over
Q, not its degree over an algebraic coefficient field.

## Contents

- `article.pdf`: 18-page article with proofs, exact algorithms, implementation
  contracts, examples, counterexamples, and bibliography.
- `article.tex`: self-contained LaTeX source; no external bibliography required.
- `RootDecomposition.wl`: Wolfram Language reference package.
- `Examples.wl`: direct certification and bounded automatic discovery for the
  two degree-nine examples.
- `Tests.wlt`: 27 Wolfram Language regression specifications.
- `verify.py`: independently executable exact SymPy checks.
- `verification_results.json`: recorded results of 30 passed independent checks.

## Main guarantees

Both supplied degree-nine numbers have a globally optimal maximum component
**degree 3**. The article proves the identities, irreducibility, selected real
branches, and optimality against any finite number of lower-degree components.

For sums, `GlobalSumDecompose` implements a finite normal-closure/fixed-space
method justified by a degree-preserving normalized-trace theorem. A completed
call certifies the unrestricted minimum over complex algebraic summands. Its
default resource caps are practical interruptions, not mathematical negative
answers. The underlying uncapped method is finite but can be very expensive.

For products, the delivered implementation is an exact bounded search combined
with global lower bounds. It is **not** advertised as a terminating unrestricted
product minimizer. Failure to find a decomposition inside stated bounds does
not establish impossibility outside those bounds.

All success results retain the component list, absolute degrees, exact equality
residual, search scope, and whether a global optimality certificate was obtained.
The elementary largest-prime lower bound applies to any finite component count.
The stronger Galois-exponent bound is proved in the article but is not an
additional public lower-bound function in this package.

## Mathematica usage

Start in a fresh kernel, set the working directory to the extracted archive,
and evaluate:

```wl
Get["RootDecomposition.wl"];
Clear[x, z];
f = x^3 + x + 1;
g = x^3 - x + 1;

rTimes = Root[
  -1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
rSum = Root[
  8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

rp = RootPairFromPolynomials[rTimes, {f, g}, x, "Product"];
rs = RootPairFromPolynomials[rSum, {f, g}, x, "Sum"];
KeyTake[rp, {"Components", "MaximumDegree", "GloballyOptimal"}]

(* Discover polynomial pairs without supplying f and g. *)
BoundedPairDecompose[rTimes, "Product", 3, 1]
BoundedPairDecompose[rSum, "Sum", 3, 1]

(* A small complete additive example. *)
GlobalSumDecompose[Sqrt[2] + Sqrt[3]]
```

The bounded searches may return the simultaneous negative of the requested
product factors, or exchange the two factors. These are equally valid optimal
representations. Supplying the original two cubics selects the requested pair.

Additional entry points:

```wl
AlgebraicDegree[alpha]
DegreeLowerBound[alpha]
ComposedPolynomial[p, q, x, z, "Sum"]
ComposedPolynomial[p, q, x, z, "Product"]
PairCoefficientEquations[alpha, {m, n}, "Product"]
BoundedDecompose[alpha, "Sum", d, height, maximumComponentCount]
SumOverSubfields[alpha, theta, {eta1, eta2}]
GlobalSumDecompose[alpha,
  "MaxFieldDegree" -> Infinity, "MaxSubgroups" -> Infinity]
```

`ComposedPolynomial` accepts exact symbolic coefficients, which are needed for
inverse coefficient equations. Candidate Root polynomials passed to
`RootPairFromPolynomials` must have exact rational coefficients. The degree and
height bounds are positive integers. Height is the largest absolute coefficient
of the primitive integer minimal polynomial with positive leading coefficient;
nonmonic polynomials are included. 

A `"NotFoundWithinBounds"` result applies only to the finite catalog searched.
A trivial one-component fallback can be returned when the allowed degree is at
least the degree of the target; this does not certify global optimality unless
the attained degree meets a lower bound. The package does not minimize the
number of components or coefficient height as secondary objectives.

`GlobalSumDecompose` defaults to `"MaxFieldDegree" -> 72` and
`"MaxSubgroups" -> 10000`. The field-degree cap is checked after initial common
field construction, so an outer `TimeConstrained` is needed to limit that step.
The algorithm enumerates every embedded fixed subfield, not only abstract
isomorphism classes or subfields of Q(alpha).

## Verification status

The mathematical verification script was executed using Python 3.13.5 and
SymPy 1.14.0. All 30 checks passed. They include exact resultants, irreducibility,
real-root counts, sparse coefficient formulas, companion-matrix identities,
bounded catalog discovery, a biquadratic fixed-space calculation, and the
counterexamples in the article.

**No Wolfram Language kernel execution succeeded during authoring.** The
available Wolfram connector returned HTTP 404 on both discovery-context and
kernel-evaluation attempts. The package was reviewed against official Wolfram
documentation and checked for balanced source delimiters, but those checks and
SymPy verification are not a substitute for running the Mathematica tests.
In particular, the full normal-closure Wolfram implementation is kernel-untested.
The tests are regression specifications, not recorded Mathematica output.

Run Mathematica tests from the extracted directory:

```wl
TestReport["Tests.wlt"]
```

Run the independent verification (requires SymPy):

```sh
python -m pip install sympy==1.14.0
python verify.py
```

The latter command rewrites `verification_results.json` with its execution
results. It raises an exception immediately on a failed mathematical check.

## Rebuilding the PDF

Use an ordinary TeX Live or MiKTeX installation with the packages named in the
preamble. No custom font files, BibTeX step, or external source assets are needed.

```sh
pdflatex -interaction=nonstopmode -halt-on-error article.tex
pdflatex -interaction=nonstopmode -halt-on-error article.tex
```

The PDF contains a complete embedded bibliography of the original question,
official Wolfram documentation, Galois-theory background, and the related
norm-descent result. The mathematical scope and execution limitations are also
stated in the article itself.
