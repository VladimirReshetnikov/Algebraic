# SystematicRadicals 0.1

Exact radical reconstruction for a selected algebraic number over Q.
Prepared for Vladimir Reshetnikov from the supplied `FindExtension.nb` and
Mathematica Stack Exchange question 34011.

## What is delivered

`article/SystematicRadicals.tex` and `.pdf` develop the constructive algorithm,
prove its mathematical completeness in an exact-arithmetic model, audit the
notebook, work through the original examples, and describe the implementation
and its limits. `python/systematic_radicals.py` is the executed implementation;
`Wolfram/SystematicRadicals.wl` is a corresponding Wolfram Language reference
port, with additional use of the built-in `ToRadicals` as a first shortcut.

**Validation distinction:** Python was executed with Python 3.13.5 and SymPy
1.14.0. Its actual test and benchmark records are in `validation/`. The Wolfram
connector returned HTTP 404; there was no local Wolfram kernel. The `.wl` port
received static delimiter checks, NOT Wolfram execution. Its `.wlt` regression
tests are supplied but were not run. They must be run on a real kernel before
relying on that port.

## Mathematical scope and limits

A rational-coefficient univariate polynomial together with an exact selected
root is the primary scope. The Wolfram entry point also accepts another exact
algebraic-number expression from which a rational minimal polynomial can be
computed. Symbolic parameters and inexact input are rejected. The Python
polynomial entry point requires Q-coefficients; algebraic coefficients must
first be eliminated to a rational minimal polynomial with the correct root
identified.

The finite general method constructs the splitting field, adjoins suitable
roots of unity, recovers **actual embedded automorphisms**, computes a
prime-index subnormal chain, and uses exact Kummer eigenprojections to build a
radical tower. It is not an enumeration of short guessed expressions and is
not restricted to a table of low-degree Galois groups. Mathematical completeness
assumes terminating exact number-field operations and unbounded finite
resources. This is a research implementation, not a claim of practical
all-degree coverage or independently verified CAS internals.

Default limits and CAS failures can produce `Inconclusive` even for an easy
solvable number. The splitting field can have degree n!, and its construction
can dominate everything. A field-degree cap is checked **after** the primitive
element is constructed, not before all allocation. Use a separate process for
a wall-clock limit. Forced complete reconstruction of x^5-2 timed out at 30
seconds in the included benchmark, although the automatic shortcut succeeds.
No shortest-expression or minimum-radical-depth guarantee is made.

Successful expressions use only rationals, I, arithmetic and rational powers.
There are no hidden Root/CRootOf, AlgebraicNumber, trigonometric or exponential
functions in a successful final expression. Branch decisions use exact
algebraic equality; numerical approximations only prioritize candidates.

## Python quick start

From the extracted archive directory:

```bash
python -m pip install -r requirements.txt
python examples/examples.py
python -m pytest -q tests
python python/systematic_radicals.py "x**6+x**4-x**3-x**2-1" --index 1 --method practical
```

The source has no dependency beyond SymPy for computation. Pytest is needed
only for the tests. Python >=3.10 is intended; only the version above was run.
Copy the module onto your Python path, or:

```python
import sys
sys.path.insert(0, "python")
import sympy as s
from systematic_radicals import solve_radical, verify_tower
x = s.Symbol("x")
r = solve_radical(x**6+x**4-x**3-x**2-1, 1, method="practical")
assert r.status == "Success"
print(r.expression)

# Bypass all practical shortcuts, to exercise the general construction:
t = solve_radical(x**3-2, 0, method="complete")
assert t.status == "Success"
assert verify_tower(t, s.CRootOf(x**3-2, 0))
print([step["prime"] for step in t.certificate["steps"]])
```

`solve_radical` itself has **no wall-clock bound**. For bounded execution use:

```python
from systematic_radicals import solve_with_timeout
if __name__ == "__main__":
    r = solve_with_timeout(x**5-x-1, 0, method="automatic", seconds=60)
    print(r.status)
```

The spawn-based wrapper should be called from a saved script under an
`if __name__ == "__main__"` guard. In interactive notebooks, use the direct
API with awareness that it may run for a long time, or run the CLI as a
subprocess. The CLI's expression parser is for **trusted local expressions**;
SymPy `sympify` is not a security sandbox.

### Root numbering

Python indices are **zero-based SymPy indices**. Mathematica indices are
one-based. The ordered real roots in the original examples match after
subtracting one: sextic WL index 2 -> Python index 1; quintic WL index 5 ->
Python index 4. **Do not transfer complex-root indices by subtraction alone.**
The two systems' complex-root order conventions need not agree. Match an exact
embedding (or a certified isolating region) when moving a complex target.

### Methods and statuses

| Method | Python | Wolfram |
|---|---|---|
| Practical | `"practical"` | `"Practical"` |
| Shortcuts, then general construction | `"automatic"` | `"Automatic"` |
| Force general construction | `"complete"` | `"Complete"` |

The methods use small-degree formulas, centered power reductions, generalized
reciprocal reductions, Dickson identities, rational functional decomposition,
and small pair-sum-resolvent fields. The pair stage tries base degree 2--4 and
relative factor degree <=4, for input degree <=12. Python additionally uses
SymPy's degree-at-most-six Galois routine to obtain cheap negative answers.
Wolfram instead first tries built-in `ToRadicals`; it does not contain that
SymPy shortcut. A finite practical search is not complete.

| Status | Meaning |
|---|---|
| `Success` | Strict radical syntax and exact selected-root equality were certified by CAS arithmetic. |
| `NotSolvable` | An exact Galois-group calculation establishes nonsolvability over Q. |
| `Inconclusive` | Search miss, time/degree limit, or CAS/construction failure; no impossibility claim. |
| `InvalidInput` | Unsupported domain, bad root index, parameters/inexact data, or invalid options. |

Python optional arguments: `max_field_degree=128`, `max_depth=12`,
`pair_resolvent=True`. Disable the extra resolvent search with
`pair_resolvent=False`. To run the mathematically unbounded backend, use
`method="complete", max_field_degree=None` with the direct API and no external
timeout. This may be entirely impractical.

A successful complete result contains an in-memory exact certificate. Use
`verify_tower(result, target)` (default `check_branches=True`) to recheck the
primitive embedding, all power identities, all principal-root branches, and
the final target coordinates. The optional `check_branches=False` is only a
cheaper algebraic consistency check, not a standalone selected-embedding
certificate. The checker does not verify negative certificates and is not a
formal proof-assistant kernel. Do not use unsafe pickle loading for untrusted
certificate data.

## Wolfram Language quick start (not executed here)

From the extracted archive directory:

```wl
Get["Wolfram/SystematicRadicals.wl"];
a = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
r = RadicalSolve[a, Method -> "Practical"];
If[r["Status"] === "Success", RadicalVerify[a, r["Expression"]]]

b = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
SystematicToRadicals[b, Method -> "Practical"]

c = Root[#^3 - 2 &, 1];
tower = RadicalSolve[c, Method -> "Complete", TimeConstraint -> 120];
RadicalTowerVerify[tower]
```

`SystematicToRadicals` returns an expression on success and a `Failure` on
other statuses; it never overrides the built-in function. `RadicalSolve`
returns a status association. The intended Wolfram baseline is a modern
kernel supporting Associations and `AlgebraicNumberPolynomial`; no minimum
version has been established by execution.

Additional options: `"MaxFieldDegree" -> 128`, `"MaxDepth" -> 12`,
`"PairResolvent" -> True`. The total default `TimeConstraint` is 60 seconds.
To remove limits use `Method -> "Complete", TimeConstraint -> Infinity,
"MaxFieldDegree" -> Infinity`. TimeConstrained is not a memory limit.

Run the supplied Wolfram tests with:

```bash
wolframscript -file Wolfram/run-tests.wls
```

Or after loading the package: `TestReport["Wolfram/tests.wlt"]`.

## Reproducibility, article, and provenance

`python tools/benchmark.py validation/benchmark.json` reruns the benchmark with
per-case process timeouts; timings include process startup and are environment
specific. `make article` rebuilds the article using pdfLaTeX twice. The LaTeX
source is self-contained and uses ordinary TeX Live packages.

The original notebook was inspected as text, not evaluated. It contains 220
Input cells, including historical and unfinished experiments. This archive
does not claim to have solved every notebook example. The notebook itself is
not redistributed or relicensed. `validation/notebook_audit.md` records the
source hash and inspected definitions; `tools/inspect_notebook.py` can produce
an inert transcription from the original notebook. It is deliberately not a
full Wolfram parser and must not be used as an executable notebook converter.

The new source code is MIT-licensed in `LICENSE`. The article is an original
technical exposition supplied with editable source. The original question and
notebook retain their existing rights; standard Galois/Kummer theory is not
claimed as a new discovery. The bibliography is in the article.
