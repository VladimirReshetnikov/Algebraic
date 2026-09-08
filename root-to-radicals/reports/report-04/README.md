# RadicalRoots 1.0

A systematic radical converter for exact algebraic numbers over Q.

The executable reference engine is Python/SymPy. The Wolfram Language package
is a front end that selects the same algebraic root, invokes that engine, and
checks the answer with `RootReduce`. Keep the extracted directory structure.

## What is complete, and what is tested?

The mathematical fallback is a complete constructive Galois algorithm with
exact algebraic primitives and no resource limits. It constructs the splitting
field, tests solvability, adjoins the required roots of unity, refines a
solvable series, finds Kummer generators by rational linear algebra, and emits
branch-correct radicals. It is not a polynomial-time implementation, an
optimized replacement for a commercial CAS, or a formally verified program.

The Python regression suite passed **46/46 tests** on Python 3.13.5 and SymPy
1.14.0. Eight nontrivial Galois-Kummer conversions also passed the separate
arithmetic-tower checker. Eleven conversion cases received an additional
minimal-polynomial check. A separate CLI/certificate suite passed **8/8**
checks (`python tests/test_cli.py`). Other positive cases rely on exact construction
identities and separation-bound matching, as recorded individually.

**The Wolfram front end and `wolfram/Tests.wlt` were not executed.** The available
Wolfram service failed with HTTP 404 and no local Wolfram kernel was installed.
The tested Python implementation can be used independently. See VALIDATION.md.

## Contents

- `article/RadicalRoots.pdf`: mathematical article.
- `article/RadicalRoots.tex` and `validation-summary.tex`: complete LaTeX source.
- `python/radical_roots.py`: standalone engine, CLI, root-rectangle selector,
  radical JSON grammar, and independent arithmetic-tower checker.
- `wolfram/RadicalRoots.wl`: Wolfram front end; `Tests.wlt`: integration tests.
- `tests/`: reproducible Python tests.
- `examples/`: runnable demonstrations and generated, exact result files.
- `validation/`: actual test reports, source fingerprints, and test evidence.
- `provenance/`: audit of the uploaded notebook and source provenance.

## Install

Use an ordinary Python environment, preferably a virtual environment:

```sh
python -m pip install -r requirements.txt
python tests/test_radical_roots.py
```

SymPy 1.14.0 is pinned because the implementation uses its exact number fields,
primitive elements, polynomial factorization, and internal bounded-error
algebraic evaluation API. Other SymPy versions have not been tested. The code
uses Python 3.10+ syntax; only Python 3.13.5 was executed in this environment.

## Python API

```python
import sys
sys.path.insert(0, "python")
import sympy as s
from radical_roots import radicalize, verify_tower_result

x = s.Symbol("x")
f = x**6 + x**4 - x**3 - x**2 - 1
result = radicalize(f, index=1)
if result.status == "Success":
    print(result.to_wolfram())  # a radical or nested With expressions
    print(result.expanded())   # optionally expand the local assignments
else:
    print(result.summary())

# Force an actual fifth-root Galois/Kummer step, bypassing shortcuts:
g = x**5 + x**4 - 4*x**3 - 3*x**2 + 3*x + 1
result = radicalize(g, index=4, method="galois")
assert result.status == "Success"
assert verify_tower_result(result, s.Poly(g, x))
```

`index` is **zero-based SymPy ordering of distinct roots**, after removing
multiplicities. It is NOT universally Mathematica's Root index minus one:
complex ordering can differ. The Wolfram bridge uses a certified rational
rectangle instead of index translation.

Only exact rational-coefficient univariate polynomials are accepted by Python.
The selected irreducible factor determines solvability. Floats and parameters
are rejected. The Wolfram front end obtains a rational minimal polynomial
from the exact algebraic input first.

`method="auto"` tries finite structural shortcuts before the complete fallback;
`"fast"` uses only those shortcuts; `"galois"` bypasses radical shortcuts.
An optional small-degree Galois decision may still prove nonsolvability early.

## Command line

```sh
python python/radical_roots.py --coefficients "[1,0,1,-1,-1,0,-1]" --index 1 --timeout 300
python python/radical_roots.py --coefficients "[5,0,-25,0,25,6]" --index 4 --method fast
```

Coefficients are highest degree first, as JSON integers or rational strings.
Arbitrary Python expression strings are not executed. Successful output is a
JSON object containing a safe arithmetic DAG and an optional Wolfram string.
Exit status is 0 for Success and 2 for a non-success mathematical result.

A rectangle selector uses `[xmin,xmax,ymin,ymax]` and overrides `--index`:

```sh
python python/radical_roots.py --coefficients "[1,0,4]" --rectangle '["-1/10","1/10","19/10","21/10"]'
```

This example selects +2 I. The displayed rectangle command uses a POSIX shell's
quoting; on Windows use the Wolfram front end or escape the JSON quotes as
appropriate for the chosen shell.

## Wolfram Language

```wl
Get["/full/path/to/RadicalRoots/wolfram/RadicalRoots.wl"];
r = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
a = RootToRadicals[r,
  "PythonExecutable" -> "/full/path/to/python"];
RootReduce[a - r]
```

For Windows use the full path to `python.exe` if necessary. The package defaults
to `python` on Windows and `python3` elsewhere. A successfully configured call
returns an expression; failures are explicit `Failure` objects.

Useful options:

```wl
RadicalRepresentation[r,
  Method -> "Galois",                 (* "Automatic", "Fast", or "Galois" *)
  TimeConstraint -> 300,               (* Python subprocess watchdog *)
  "MaxFieldDegree" -> 128,
  "NativeAttempt" -> False,           (* skip initial ToRadicals attempt *)
  "VerificationTimeConstraint" -> 60,
  "IsolationTimeConstraint" -> 30]
```

`TimeConstraint` is a backend watchdog, not a strict total time bound for all
native preprocessing and final verification. On a successful backend return,
the package independently checks `RootReduce[answer - original] === 0`.
The bridge does not evaluate Wolfram source strings from the JSON: it decodes
only rationals, I, arithmetic, rational powers, and earlier local variables.

Offline integration is also available:

```wl
ReadRadicalJSON["/full/path/to/RadicalRoots/examples/sextic.json", r]
TestReport["/full/path/to/RadicalRoots/wolfram/Tests.wlt"]
```

These Wolfram calls are supplied for the user's kernel, not represented as
having run in the preparation environment.

## Guarantees and limits

The output expression contains no unresolved Root/CRootOf, trigonometric
constants, or hidden algebraic coefficients. Audit metadata may mention the
internal primitive element; it is not part of the radical expression.

`NotSolvableByRadicals` is produced only by an exact nonsolvable Galois group.
`NotFound`, `ResourceLimit`, and `BackendFailure` mean something different and
must never be interpreted as impossibility proofs.

Default CLI budgets are 300 seconds and field degree 128. The degree check
happens AFTER an extension is constructed, so it is not a transient memory
cap. The Python library itself has no wall-clock watchdog; use the CLI for one.
`--max-degree 0 --timeout 0` removes both CLI caps; `max_degree=None` removes the
library field-degree cap. Unbounded computations can be very expensive.

Exactness is relative to SymPy's exact algebraic algorithms and bounded-error
root evaluation. The separate tower checker verifies positive answers using
rational polynomial remainders and root separation; it is not a Lean proof and
does not independently certify a negative Galois-group computation.

## Rebuild the article

From `article/`, run `pdflatex RadicalRoots.tex` twice (three times after a
substantial table-of-contents change). The supplied validation-summary.tex
records the completed main test run. No external figures or fonts are needed.
