# SystematicRadicals 1.0.0

Exact radical expressions for algebraic numbers over the rationals, with a
Wolfram Language interface and an executable Python/SymPy reference backend.

Read **article/SystematicRadicals.pdf** for the mathematics, proofs, the notebook
analysis, branch conventions, and implementation boundaries. The editable source
is **article/SystematicRadicals.tex**.

## What is implemented

The fast layer recognizes centered power compositions, Dickson polynomials, and
weighted reciprocal reductions, and uses ordinary exact formulas through degree
four. In particular, it handles both examples from the motivating question
without constructing a large splitting field.

The general Python layer actually constructs an abstract splitting field by
successive exact root adjunctions, computes its automorphism group, adjoins the
necessary roots of unity, and converts a prime-factor composition series into a
radical tower using Lagrange resolvents. The necessary field/group operations are
implemented, not left as mathematical pseudocode or a missing Galois backend.
It does not require SageMath, PARI/GP, or a Wolfram kernel.

A general result includes a positive certificate. Its independent checker uses
rational arithmetic, irreducibility, radical-power identities, and a full-rank
tower basis. It does not repeat the Galois-group search. The certificate proves
the **whole root set**, not an external root index. Root selection is a separate
step.

**Completeness versus a bounded run.** With limits removed, this is a finite
constructive algorithm for every irreducible polynomial over Q, assuming correct
terminating underlying exact-arithmetic primitives. It is not an efficient
universal solver. Defaults cap the working field at degree 48 and request 120
seconds. `ResourceLimit` means inconclusive, never nonsolvable. There is no
claim to minimize radical depth, expression length, or coefficient height.

## Validation status

**All 36 Python regression tests passed**, under Python 3.13.5 and SymPy 1.14.0 on
Linux. The actual run took about 81.38 seconds. Tests include the original sextic
and quintic, branch-sensitive root matching, forced general constructions for
six solvable examples (including nonabelian cases), a nonsolvable quintic,
reducible-input factor selection, certificate tampering, invalid input, field
budgets, and the command-line worker timeout. See `validation/python_validation.*`
and `validation/certificates/`.

**The Wolfram Language interface has NOT been kernel-executed.** A lexical
bracket/string/comment scan passed, but that is not a substitute for executing
it. The available Wolfram service returned HTTP 404 and no local Wolfram kernel
was available. A `.wlt` test suite is included for a real kernel. The executed
Python implementation is the reference implementation in this release.

## Install and run Python

Python 3.10 or later is required by the source syntax. The exact tested SymPy
version is pinned; re-run validation before changing it.

```sh
cd SystematicRadicals
python -m pip install -r requirements.txt
python examples/quickstart.py
python tests/run_validation.py
```

For an interactive session, put this distribution's `python` directory on
`sys.path` (or on `PYTHONPATH`):

```python
import sys
sys.path.insert(0, "/path/to/SystematicRadicals/python")
import sympy as s
from systematic_radicals import solve_root, solve_polynomial, verify_certificate
x = s.symbols("x")

f = x**6 + x**4 - x**3 - x**2 - 1
alpha = solve_root(f, 1, x)  # ZERO-based SymPy CRootOf index: positive real root
print(alpha)

# Exercise the actual general algorithm rather than a cubic formula.
answer = solve_polynomial(x**3 - 2, x, method="galois", verify=True)
print(answer.assignments)  # ordered (symbol, radical expression) pairs
print(answer.outputs)      # all roots in those shared symbols
assert verify_certificate(answer.certificate, x**3 - 2)
```

`solve_polynomial` expects one irreducible rational polynomial and returns every
root. `solve_root` first selects the correct minimal factor of a potentially
reducible polynomial. Its index uses **SymPy's zero-based CRootOf ordering, not
Wolfram Language ordering**.

The returned `RadicalSolution` has `polynomial`, `assignments`, `outputs`,
`method`, `diagnostics`, and (for a general construction) `certificate`.
`expanded_roots()` substitutes the assignments, potentially increasing size
substantially. Reuse the same assignment value everywhere it occurs: do not
independently alter radical branches or use branch-unsafe power simplifications.

`method="auto"` tries the fast layer then the general layer; `method="fast"`
returns a `NotFound` exception when no identity applies; `method="galois"`
forces the general path, except for rational roots. To remove both construction
budgets explicitly:

```python
answer = solve_polynomial(f, x, method="galois",
                          max_field_degree=None, max_seconds=None, verify=True)
```

This can require extreme resources. The in-process library time checks are
**cooperative** and do not interrupt an individual SymPy call or bound all
selected-root preprocessing/evaluation. Use the JSON CLI worker for an externally
enforced construction timeout.

The selected-root comparison uses `Poly.same_root`: its root precondition comes
from the construction, and the comparison uses a separation bound and
bounded-error evaluation in the tested SymPy implementation. This additionally
trusts SymPy's numerical evaluation contract; it is not an independently
verified interval-arithmetic certificate. The positive root-set certificate is
exact rational arithmetic.

## Wolfram Language

Keep `SystematicRadicals.wl` beside the bundled `python` directory.

```wl
Get["/path/to/SystematicRadicals/SystematicRadicals.wl"];

alpha = Root[#^6 + #^4 - #^3 - #^2 - 1 &, 2];
r = Radicalize[alpha, Method -> "Native"];
VerifyRadical[alpha, r]

beta = Root[5 #^5 - 25 #^3 + 25 # + 6 &, 5];
RadicalReport[beta, Method -> "Native"]

RadicalReport[Root[#^3 - 3 # + 1 &, 1], Method -> "Galois",
              "TimeLimit" -> 120, "MaxFieldDegree" -> 48]
```

Set `"PythonExecutable"` to an absolute executable path when needed, particularly
on Windows or in a virtual environment. `Automatic` chooses `python` on Windows
and `python3` elsewhere. Paths containing spaces are passed as single arguments,
not interpolated into a shell string.

`Method -> Automatic` tries native methods then Python; `"Native"` never starts
Python; `"Python"` skips the native layer but allows Python fast paths;
`"Galois"` forces the general Python construction. An input already in radical
form is returned without unnecessary reconstruction.

`Radicalize` returns the expression or `Failure`; `RadicalReport` returns a
success association with expression, method, minimal polynomial, and diagnostics.
A candidate is accepted only after `RootReduce[candidate - input] === 0`.
Approximate distances only prioritize candidates. No cross-system root-index
assumption is used. `VerifyRadical` returns False on a timeout; that is not a
proof of inequality.

Options and defaults are `"TimeLimit" -> 120`,
`"VerificationTimeLimit" -> 30`, `"MaxFieldDegree" -> 48`, and
`"VerifyCertificate" -> True`. Set all three bounds to `Infinity` for an
unbounded general attempt. Native operations have time constraints and the
Python worker has its own boundary; process startup/shutdown and scheduling mean
these options do not promise a hard real-time deadline for the whole WL call.

Execute the Wolfram tests in a real kernel with:

```wl
TestReport["/path/to/SystematicRadicals/tests/SystematicRadicals.wlt"]
```

## Failure semantics

| Status / exception | Meaning |
|---|---|
| `NotSolvable` | An exact nonsolvable Galois group was obtained. |
| `ResourceLimit` | Construction was stopped or rejected by a budget. No solvability conclusion. |
| `NotFound` | The requested fast/native-only method found no accepted answer. |
| `InvalidInput` | The exact rational-algebraic input contract was not met. |
| `VerificationFailed` | WL could not exactly match a candidate within its budget. |
| `CertificateError` | A required exact relation or certificate check failed. |
| `BackendUnavailable`, `BackendError`, `ProtocolError` | An operational or protocol failure, not a mathematical conclusion. |

Positive certificates do not constitute exported negative certificates for
nonsolvability. Negative results trust the finite-group computations. Fast
structural results are justified by their exact recognition identities but do
not currently carry a general number-field certificate.

## JSON worker

```sh
python python/systematic_radicals.py --json < request.json
```

The request supplies high-to-low rational coefficients, never executable source:

```json
{"coefficients":[["1","1"],["0","1"],["0","1"],["-2","1"]],
 "method":"galois","max_field_degree":48,"max_seconds":120,
 "verify":true,"certificate":true}
```

Integer strings preserve exactness across JSON implementations. Optional
`max_field_degree` and `max_seconds` can be `null` to remove the corresponding
limit. The radical AST uses `Q`, `Ref`, `Add`, `Mul`, and `Pow`; references are
zero-based and assignments must be evaluated in order. The WL decoder never
uses `ToExpression` on backend data. The parent process terminates a worker
that exceeds its wait limit; startup/shutdown overhead is outside that wait.
A success exits with code 0; another status exits with code 2.

## The original examples in small formulas

For the sextic, set

```
t = ((9 + sqrt(849))/18)^(1/3) - ((sqrt(849) - 9)/18)^(1/3)
alpha = (t + sqrt(t^2 + 4))/2
```

Both cube-root radicands are positive. The identity is
`f(x) = x^3 ((x - 1/x)^3 + 4 (x - 1/x) - 1)`.

The largest root of `5 x^5 - 25 x^3 + 25 x + 6` is

```
((-3 + 4 I)/5)^(1/5) + ((-3 - 4 I)/5)^(1/5)
```

with principal powers. These are general identity recognitions in the software,
not polynomial-specific table entries. Detailed derivations are in the article.

## Contents and provenance

- `article/SystematicRadicals.tex` and `.pdf`: theory, proofs, API, tests, references.
- `SystematicRadicals.wl`: WL interface and native fast paths.
- `python/systematic_radicals.py`: executed general reference implementation and CLI.
- `examples/`: Python and WL examples plus a JSON request.
- `tests/`: 36 Python tests, validation runner, and unexecuted WL tests.
- `validation/`: actual execution logs and six positive certificates.
- `requirements.txt`, `LICENSE`, `MANIFEST.sha256`: dependency pin, license, file hashes.

The original `FindExtension.nb` was inspected but not executed or redistributed.
Its SHA-256 is
`d70951fdb88128556ee7ea762652413b6f8b5e970c4437c2f3293d9b07eac007`.
The supplied archive SHA-256 is
`381e80382e8736aa00e18d8fd48c6f391b9ba0b15e80ff7621e7589147174930`.

Build the article by running `pdflatex SystematicRadicals.tex` twice from the
`article` directory, or use `latexmk -pdf`. The bibliography identifies the
original question, the Galois-theoretic sources, and the documentation consulted.
