# RadicalSolve 0.1.0

A branch-aware radical converter for exact algebraic numbers over **Q**.

The archive contains a native Wolfram Language package for structural cases,
an executable Python/SymPy reference implementation of general constructive
Galois descent, and a detailed mathematical article in LaTeX and PDF.

## What is implemented

`Method -> "Native"` in Wolfram Language handles classical low-degree formulas,
shifted power compositions, Dickson-polynomial equations, and generalized
reciprocal compositions. Both examples from the original Mathematica question
have structural solutions; they do not require Python when using this route.

The Python general engine constructs the splitting field by exact factorization
and resultants, recovers its actual automorphisms, constructs a prime-index
subnormal series, and performs Fourier resolvent descent. The associated finite
algorithm is complete for rational polynomials when resource bounds are removed
and the exact algebra/embedding primitives terminate correctly. It is not a
promise that every large solvable input will finish in practical time. The
normal-closure degree can be much larger than the input degree.

The implementation does not merely enumerate guessed radical expressions, and
does not use `RootApproximant`, `PossibleZeroQ`, `Chop`, or `PowerExpand` as a
proof of correctness. Python embedding comparisons use SymPy's `Poly.same_root`
only after an exact argument supplies a common annihilating polynomial. This
uses root separation and bounded-error evaluation, not a chosen numeric tolerance.
The Wolfram frontend additionally insists on exact `RootReduce[answer-input] === 0`.

## Wolfram Language

Keep the extracted directory structure intact:

```wl
Get["C:\\path\\to\\RadicalSolve\\wolfram\\RadicalSolve.wl"];

r6 = Root[-1-#^2-#^3+#^4+#^6&, 2];
r5 = Root[6+25#-25#^3+5#^5&, 5];

a6 = Radicalize[r6, Method -> "Native"];
a5 = Radicalize[r5, Method -> "Native"];
VerifyRadical[r6, a6]
VerifyRadical[r5, a5]
RadicalReport[r6, Method -> "Native"]
```

For the general Python backend, first install its dependency in the interpreter
that Wolfram Language will run:

```text
python -m pip install -r requirements.txt
```

Then:

```wl
RadicalReport[Root[#^3-3#+1&, 1],
  Method -> "Galois",
  "PythonExecutable" -> "python",
  "MaxFieldDegree" -> 96,
  TimeConstraint -> 120,
  "VerificationTimeConstraint" -> 120]
```

`"PythonExecutable"` can be an absolute path to `python.exe`. It is an executable
path, not a shell command with arguments. No package installation is required
when using the bundled `python/cli.py` through this frontend.

`Method -> Automatic` tries the native methods first and then the Python backend.
`Method -> "Native"` never launches Python. `Method -> "Galois"` forces general
descent, except for inputs already expressed in radicals. The default field-degree
limit is 96. Set `"MaxFieldDegree" -> Infinity` to remove it.

`TimeConstraint` bounds each native candidate-generation attempt and gives the
Python worker a hard subprocess deadline. It is **not** a global deadline for
the entire Wolfram call: final verification has its own per-candidate option,
`"VerificationTimeConstraint"`, whose default is `Infinity`.

The Python backend returns **all conjugates of the minimal polynomial**. Wolfram
Language selects the requested one by exact equality. No conversion between
Mathematica and SymPy root-index conventions is assumed.

## Python

Python 3.10 or later and SymPy 1.14.0 are the declared requirements. The executed
tests used Python 3.13 and SymPy 1.14.0. From the archive root:

```text
python -m pip install -e .
python -m unittest discover -s tests -v
```

A built pure-Python wheel is also included in `dist/`; installing it avoids a
local package build:

```text
python -m pip install dist/radicalsolve_reference-0.1.0-py3-none-any.whl
```

Alternatively, add `python/` to `PYTHONPATH`, without installing this package.

```python
from sympy import symbols, Poly
from radicalsolve import Solver, radicalize, verify

x = symbols("x")
p = Poly(x**6+x**4-x**3-x**2-1, x)
r = radicalize(p, index=1)  # zero-based SymPy CRootOf ordering
print(r.expression)
print(r.method)
assert verify(p, r.expression, index=1)

# Force the general algorithm, bypassing the structural shortcuts.
session = Solver(method="galois", max_field_degree=96)
roots = session.all_roots(Poly(x**5+x**4-4*x**3-3*x**2+3*x+1, x))
print(roots[0].expression)
print(session.events)
```

`Solver.root(p,index)` selects the relevant irreducible factor before testing
solvability. Thus a solvable root of a reducible polynomial is not rejected just
because a different factor has a nonsolvable Galois group. Indices follow
`CRootOf(p,index)`, including multiplicities. `all_roots` returns distinct roots,
with no promised ordering, and requires every irreducible factor to be solvable.

`Result.expression` is the radical expression, `Result.method` names the route,
and `Result.record` holds construction metadata. **The record is an audit record,
not a standalone replayable formal proof certificate.** The general method checks
its algebraic invariants while constructing the expression. `verify` independently
reconstructs the expression's minimal polynomial and then checks the embedding;
that independent reconstruction can be much more expensive than construction.

`max_field_degree=None` removes the degree budget. `max_seconds` on the in-process
Python API is cooperative: one SymPy operation may run past it. For a hard deadline,
use `python/cli.py` with `hard_timeout_seconds`, which supervises an isolated worker.
The `python -m radicalsolve` and installed `radicalsolve` entry points do not add
that subprocess supervisor.

## JSON protocol

The CLI reads one JSON object on stdin and writes one JSON object on stdout.
Coefficients are descending rational pairs of signed decimal strings:

```json
{
  "action": "root",
  "coefficients": [["1","1"],["0","1"],["-2","1"]],
  "index": 0,
  "method": "galois",
  "max_field_degree": 96,
  "hard_timeout_seconds": 30
}
```

Each successful result contains a topologically ordered expression DAG with
`Q`, `I`, `Add`, `Mul`, and `Pow` nodes. A `Q` node carries numerator and denominator
strings. Other operation arguments are zero-based references to earlier nodes;
a `Pow` exponent must decode to a rational number. This preserves common
subexpressions and needs neither Python `eval` nor Wolfram `ToExpression`.

## Failure semantics

`NotSolvable` means a nonsolvable Galois group was established for the relevant
irreducible polynomial. `ResourceLimit` means a degree or time budget was exceeded,
not that no radical exists. `InvalidInput` rejects floats, parameters, invalid
indices, and malformed data. `BackendError` or `VerificationFailed` is also not a
nonsolvability result. A native-only unresolved input returns `Failure["Unresolved",…]`.

The public Python exceptions are `NotSolvable`, `ResourceLimit`, `InvalidInput`,
and their base `RadicalError`. CLI results use analogous status strings.

## Verification status and known limits

The checked-in `tests/python-test-results.txt` is the actual test transcript:
35 tests were discovered, 34 passed, and one optional integration test was skipped.
The suite exercises both original examples, every original conjugate, forced
Galois descent with groups C2, C3, S3, V4, C4, D4 and C5, zero divisors in the
cyclotomic tensor algebra, factor-specific solvability, bad inputs, wrong
conjugates, serialization, and subprocess deadlines.

Independent minimal-polynomial verification is executed on the two selected
original roots and several general-method families. The C5 test checks internal
exact invariants and high-precision residuals; it deliberately omits costly
independent minimal-polynomial reconstruction. The optional forced S4 integration
test is skipped by default. An exploratory S4 run constructed the degree-24 field
and subgroup chain but reached `ResourceLimit` during descent after a slow
embedding comparison; its transcript in `tests/s4-resource-limit.txt`
is included separately and is not counted as a success.

**No Wolfram kernel was available for an execution test.** The native package and
`.wlt` tests are supplied, with source-level review but no claim of executed
Wolfram tests. The Python implementation is the executed reference.

The package does not optimize radical depth, discover all useful subfields before
building the normal closure, or guarantee a small printed formula. Large notebook
examples are retained as provenance rather than claimed solved benchmarks. The
article explains the finite completeness argument and the practical limitations.

## Archive contents

`article/radicalsolve.tex` and `.pdf` contain the theory and implementation guide.
`python/radicalsolve/` is the general solver; `wolfram/` contains the frontend and
native reductions. `tests/` contains runnable tests and actual transcripts.
`examples/demo.py` reproduces both original examples and a forced general C5 run;
`examples/results.json` and `demo-output.txt` record an actual execution. `provenance/FindExtension.nb`
is the unchanged input notebook, not a runtime dependency. Its readable box
extraction is explicitly non-executable and best-effort.

Build the article with `latexmk -pdf article/radicalsolve.tex` from the archive root,
or run `latexmk -pdf radicalsolve.tex` inside `article/`.

New code and report are under MIT-0. The original notebook retains its existing
rights; third-party dependency licenses are unchanged.
