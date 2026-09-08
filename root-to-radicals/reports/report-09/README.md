# Systematic Root-to-Radicals — version 0.1.0

An exact radical-conversion reference implementation, with a Wolfram Language
interface and an executable Python/SymPy backend. The accompanying **25-page
article** develops the mathematics, analyzes the supplied experimental notebook,
explains branch certification, and separates mathematical completeness from
practical resource limits.

## Start here

- Theory and implementation: `article/root-to-radicals.pdf` and its `.tex` source.
- Executed implementation: `python/radical_roots/`.
- Wolfram interface: `wolfram/SystematicRadicals.wl`.
- Actual test record: `validation/test-results.json` and `validation/regression.log`.

**Validation boundary:** the Python implementation was executed with SymPy 1.14.0
and Python 3.13.5. The Wolfram source was inspected statically, but the `.wlt` tests
were **not executed in a Wolfram kernel**: the available evaluator returned HTTP
404 and there was no local kernel. Native WL and the WL/Python bridge should be
validated locally using the supplied prospective tests.

## What is implemented

The automatic solver first uses exact degree-at-most-four formulas, recognizes
shifted Dickson polynomials (including binomials of any degree), and searches
pair-sum resolvent fields for quadratic factors. It then falls back to a general
Galois–Kummer constructor:

1. Construct the exact embedded splitting field and a suitable cyclotomic base.
2. Enumerate automorphisms, test solvability, and obtain a cyclic prime composition
   series of the relative Galois group.
3. Find nonzero Kummer generators by a finite trace-and-Fourier search, express
   their powers by exact rational linear algebra, and certify their principal
   radical branches with root separation.
4. Return a radical tower, expanded expressions, and a replayable positive
   certificate. No `Root`, `CRootOf`, `AlgebraicNumber`, or trigonometric placeholder
   occurs in the radical output; exact isolated roots are permitted only in the
   certificate's internal embedding anchor.

The general mathematical construction has no input-degree ceiling when bounds
are removed, conditional on the exact algebraic primitives. It is **not** an
assertion that arbitrary inputs are computationally feasible. A splitting field
can have factorial degree, coefficient growth can be severe, and this is a
transparent reference algorithm rather than a specialized high-performance CAS.
The default maximum intermediate field degree is 96.

`Success`, `NotSolvable`, `SearchExhausted`, `ResourceLimit`, and
`VerificationFailure` have different meanings. Only `NotSolvable` is a mathematical
negative answer. The small-degree Galois precheck uses SymPy's degree-at-most-six
routine, but the general construction does not depend on that restriction.

## Python

Requires Python 3.10+; the tested dependency is pinned:

```shell
python -m pip install -r requirements.txt
python -m pip install -e .
python examples/original_examples.py
python tools/run_validation.py
```

The tests and examples also work without editable installation when the pinned
SymPy dependency is already available; they add the local source directory to
`sys.path`.

```python
from sympy import symbols
from radical_roots import solve_root, solve_polynomial, build_tower, Limits

x = symbols("x")
a = solve_root(x**6 + x**4 - x**3 - x**2 - 1, 1)
b = solve_root(5*x**5 - 25*x**3 + 25*x + 6, 4)
print(a.expression())
print(b.expression())

# Force the general construction, not the cubic/quartic front end.
t = build_tower(x**3 - x - 1)
assert t.verify()
print(t.metadata)
print(t.steps)          # compact, shared radical definitions
print(t.expressions())  # expanded expressions for all conjugates
```

`solve_root` uses a **zero-based SymPy root index**, counting input multiplicities.
`solve_polynomial` returns distinct roots in SymPy's real-first ordering. It tries
to solve every factor. To select a solvable root of a reducible polynomial having
other nonsolvable factors, use `solve_root` instead.

Methods for `solve_polynomial` / `solve_root` are `"auto"`, `"fast"`, and `"galois"`.
The `build_tower` function always invokes the general constructor and requires an
irreducible rational polynomial. Its cubic and binomial splitting-field
optimizations do **not** skip Kummer synthesis.

The new `verify_certificate(cert, expected_polynomial=f)` option binds a standalone
certificate to a caller-supplied polynomial. `RadicalTower.verify()` also checks
that the live object's tower definitions and outputs agree with its certificate,
so mutating a step cannot leave the object appearing verified.

### Hard time limits and JSON

Direct Python calls have cooperative checks between stages. A single library
factorization can therefore overrun `Limits(seconds=...)`. The CLI puts all algebra
in a subprocess and can terminate that worker at a hard wall-clock deadline:

```shell
python python/radical_roots/cli.py < examples/quintic-request.json
```

Example request (ascending exact rational coefficients):

```json
{"coefficients":["6","25","0","-25","0","5"],
 "method":"auto", "seconds":300, "max_field_degree":96}
```

Add `"root_index":4` to request a particular SymPy root. Set `seconds` and/or
`max_field_degree` to `null` to remove the corresponding bound. JSON responses
include status, whitelisted radical ASTs, metadata, and—on the general path—the
compact tower and positive certificate. General certificates are replayed by
default; `"verify":false` explicitly skips that separate replay, not the
construction's own exact checks.

The JSON interface never evaluates caller-provided source code. It accepts exact
rational strings, not symbolic expressions. Positive certificate replay trusts
SymPy exact arithmetic and bounded-error root identification; it is not a
formally verified proof kernel. Certificates from untrusted sources can still be
computationally expensive and should be replayed in a resource-limited process.

## Wolfram Language

Keep the distribution directory layout intact:

```wl
Get["path/to/rootradicals/wolfram/SystematicRadicals.wl"];

a = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
b = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
SystematicToRadicals[a]
SystematicToRadicals[b]
RadicalData[a]
```

`Automatic` tries native shortcuts and then invokes Python. Other methods are
`"Native"` (shortcuts only), `"Python"` (automatic Python solver), `"PythonFast"`,
and `"Galois"` (force the general Python constructor).

On Windows, select the interpreter where SymPy is installed:

```wl
SystematicToRadicals[a, Method -> "Python",
  "PythonCommand" -> {"py", "-3"}, TimeConstraint -> 300]

(* Or use the exact interpreter path as one argument: *)
SystematicToRadicals[a, Method -> "Python",
  "PythonCommand" -> {"C:\\path\\to\\venv\\Scripts\\python.exe"}]
```

All candidates are decoded from a safe arithmetic AST and selected by
`RootReduce[candidate - original] === 0`. No equivalence between SymPy's and
Wolfram's complex-root orderings is assumed. To remove the backend degree guard,
use `"MaxFieldDegree" -> Infinity`.

Prospective native/bridge tests:

```wl
TestReport["path/to/rootradicals/wolfram/SystematicRadicals.wlt"]
```

The wrapper uses public WL functions. It rejects approximate and parametric
inputs rather than guessing an exact algebraic value. The native auxiliary-field
shortcut currently uses fields of degree at most four; Python can also solve
recognized higher-degree Dickson auxiliary polynomials.

## The original examples in compact form

For the sextic, put

```wl
v = (1/2 + Sqrt[849]/18)^(1/3);
s = v - 4/(3 v);
alpha = (s + Sqrt[s^2 + 4])/2;
```

The exact identity is
`x^6+x^4-x^3-x^2-1 == x^3 ((x-1/x)^3+4(x-1/x)-1)`.
For the quintic:

```wl
u = ((-3 + 4 I)/5)^(1/5);
beta = u + 1/u;
```

These give approximately `1.13068544546204059` and `1.80705999508542450`,
respectively. The package uses exact algebraic identities and root separation,
not these decimal approximations, to accept them.

## Tested scope and limitations

The regression suite includes both original examples, all conjugates of a
seventh-degree binomial, a tenth-degree pair-sum example, forced general
constructions through degree 20 in the splitting field, a genuinely nonabelian
relative-group example, nonsolvability, hard timeouts, malformed input, and
certificate corruption. `validation/test-results.json` is the authority for the
final test count and recorded execution status.

There is no promise of minimal radical depth or smallest expression size, no
portable hard memory limit, no generic symbolic-parameter support, and no claim
that every larger example in the supplied notebook was executed or solved.
The degree guard is checked after field construction, so it is not a pre-allocation
memory bound. Unrestricted mode may be impractical even for modest input degrees.

## Article, provenance, and licensing

Build the article with two `pdflatex` passes in `article/`; its only additional
local source file is `validation-table.tex`. The compiled PDF is included.

The original notebook is preserved unchanged in `original/`. Its text extraction
is **display-oriented, not guaranteed executable WL**. `tools/extract_notebook.py`
never evaluates notebook contents. Hashes and provenance are recorded in
`validation/provenance.json`; `SHA256SUMS.txt` covers the final distribution.

New code and the accompanying report are released under **MIT No Attribution
(MIT-0)**. This does not relicense the supplied original notebook, copied excerpts
from it, or the separately installed SymPy dependency. See `LICENSE` and
`original/PROVENANCE.md`.
