# RadicalRoot 0.1.0

An exact Root-to-radicals reference solver, with a constructive Galois–Kummer
backend and practical structural fast paths. Prepared for Vladimir Reshetnikov
from the supplied `FindExtension.zip` and the motivating Mathematica Stack
Exchange question.

**Start with `article/radicalroot.pdf` (19 pages).** Its editable sources are
`article/radicalroot.tex` and `article/validation_summary.tex`.

## What is implemented

The general backend constructs an embedded splitting field and a sufficient
cyclotomic compositum, computes automorphisms by exact number-field factoring,
checks group solvability, constructs a prime-cyclic subgroup chain, and obtains
Kummer generators by a finite trace/Fourier basis search. Every principal-power
branch is matched to the embedded target. It is implemented, not just pseudocode.

The fast paths cover low degree, affine power composition, Dickson polynomials,
generalized reciprocal polynomials, pair-sum resolvents, and supplied radical
extension fields. They solve both polynomials in the motivating question.

The mathematical algorithm is complete with unbounded resources and terminating
exact number-field operations. **The software is a bounded reference release,
not a practical all-input guarantee or an industrial Galois-group implementation.**
Large primitive fields can be prohibitively expensive. A failure, timeout, or
exhausted fast path is not reported as mathematical nonsolvability.

Output uses rational arithmetic, `I`, and principal rational powers. There are no
remaining `Root`, `CRootOf`, free parameters, or trigonometric placeholders in an
accepted expression. Real targets can have complex intermediate radicals.

## Wolfram Language

```wolfram
Get["wolfram/RadicalRoot.wl"];
a = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
e = RootToRadicals[a, Method -> "Fast"];
VerifyRadical[a, e]

b = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
RootToRadicals[b, Method -> "Fast"]

r = RadicalSolve[Root[#^3 - 2 &, 1],
  Method -> "Galois", TimeConstraint -> 300];
```

Methods are the strings `"Automatic"` (default), `"Fast"`, and `"Galois"`.
`RadicalSolve` returns an Association on success or a `Failure`.
`RootToRadicals` extracts the successful expression, otherwise propagates failure.
Other public functions are `VerifyRadical`, `RadicalExpressionQ`, and
`PairSumResolvent[f,x,y]`.

Default options:

```wolfram
TimeConstraint -> 120
"MaxFieldDegree" -> 48
"MaxGroupOrder" -> 96
"PairResolventLimit" -> 8
"Extensions" -> {}
```

For the notebook's degree-eight example, an extension hint is
`"Extensions" -> {{Sqrt[3], Sqrt[5]}}`; set `"PairResolventLimit" -> 0` to skip
pair-resolvent search before trying that hint. See `examples/basic.wl`.

`Infinity` disables the corresponding time, field-degree, or group-order bound.
A degree limit is checked *after* the primitive field has been constructed, so
it is not a substitute for a time limit. No explicit memory limit is implemented.

Run the Wolfram tests locally:

```wolfram
TestReport["tests/RadicalRoot.wlt"]
```

**Validation caveat:** the available Wolfram service returned HTTP 404. No Wolfram
runtime tests were executed here. The package has a lexical delimiter check and
11 local test cases, but those are not a substitute for a successful kernel run.

## Python

Python 3.10+ and SymPy 1.14.x are required. The recorded test environment was
Python 3.13.5, SymPy 1.14.0, pytest 9.0.2.

```bash
python -m pip install ./python
python -m pip install pytest
python -m pytest tests/test_radicalroot.py -v
python examples/basic.py
python examples/identities.py
```

```python
import sympy as s
from radicalroot import radicalize, verify_result
x = s.Symbol("x")
r = radicalize(5*x**5 - 25*x**3 + 25*x + 6, index=4, method="fast")
assert r.success and verify_result(r)
print(r.expression)

# Force the explicit Galois/Kummer backend, bypassing structural formulas.
r = radicalize(x**3 - 2, index=0, method="galois")
assert r.success and verify_result(r)
print(r.certificate["chain_indices"])
```

Python methods are `"auto"`, `"fast"`, and `"galois"`. API options:
`max_field_degree=48`, `max_group_order=96`, `pair_limit=8`, `extensions=()`.
Use `None` to disable the two mathematical size bounds. A single primitive radical
such as `extensions=[s.sqrt(3)+s.sqrt(5)]` can supply the notebook hint.

**Indices:** Python uses zero-based SymPy `CRootOf` indices. Wolfram's indices
are one-based, and nonreal-root orderings must not be assumed to agree. The
real roots of the two motivating examples correspond to Python indices 4 and 1.
No arbitrary WL-to-Python index translation is provided.

The API accepts a nonconstant univariate polynomial over Q, including reducible
polynomials; it selects the target's irreducible factor. Inexact input and free
parameters are rejected. `RadicalResult` fields are `status`, `expression`,
`method`, `target`, `certificate`, and `message`; `.success` checks the status.

Python API calls have no hard wall-clock limit. Use the CLI to isolate and bound
the worker process:

```bash
python -m radicalroot --coefficients "5,0,-25,0,25,6" --index 4 --method fast --timeout 30
python -m radicalroot --coefficients "1,0,0,-2" --index 0 --method galois --timeout 120
```

Coefficients are descending rational numbers. The parser does not use `eval`.
The CLI prints JSON. `--timeout 0`, `--max-field-degree 0`, and
`--max-group-order 0` disable their limits. Exit status is 0 for success, 2 for
other outcomes. Construction data in JSON are human-readable audit data, not a
round-trippable independently verified certificate format.

## Outcomes

`success` is a radical construction with exact checks. `not_solvable` requires
an exact nonsolvable group computation. `not_found` only means fast paths were
exhausted. `resource_limit`, `backend_failure`, and `unsupported_input` are
separate outcomes; none proves nonsolvability.

The generic Python path checks all exact field identities and branch choices;
`verify_result` independently rechecks the final expression against the selected
root. The Wolfram path always performs the final `RootReduce` equality check.
Both trust their CAS algebraic-number/embedding backend, not a formally verified
kernel developed in this project.

## Validation actually performed

The final Python regression run: **48 passed, 0 failed, 40.22 seconds**.
It includes every root of the motivating quintic, both real sextic roots,
five forced general-path fixtures, finite-group chain tests, a nonsolvable
quintic, wrong-conjugate rejection, bounds, invalid input, and a supplied-extension
solution of the notebook degree-eight example. Additional example, polynomial
identity, CLI-success, and CLI-timeout checks were run.

See `validation/STATUS.md`, `validation/pytest.xml`, and the console logs.
Timings are local observations, not promised performance. The full notebook's
higher-degree experimental corpus was not benchmarked. Radical depth and
expression length are not minimized.

## Article and provenance

Run `make pdf` or two `pdflatex radicalroot.tex` passes in `article/`.
The PDF was rendered and visually inspected; no external image/font files are
needed to build it with a standard LaTeX installation.

`provenance/notebook_inputs.txt` and `.json` are **inspection-only** box extractions,
not executable WL translations. The exact supplied ZIP/notebook hashes and
extraction caveats are in `provenance/README.md`. The original notebook is not
repackaged or relicensed. New code is provided under the MIT license; see LICENSE.
