# RadicalRoot 1.0.0

Convert an **exact selected algebraic root over Q** to arithmetic radicals, with branch and conjugate verification. Includes an executable Python/SymPy implementation, a Wolfram Language adapter, and a 24-page theoretical article.

## Status and scope

The Python implementation was executed: **all 20 named regression tests passed**, including multiple polynomial subcases. Both original examples from Mathematica Stack Exchange question 34011, all their conjugates, and a degree-eight example from the supplied notebook were solved and checked. The general Galois constructor was also exercised on nontrivial cyclic and pure quintics in degree-20 absolute fields.

The **Wolfram adapter was source-reviewed but not runtime-tested**: the available Wolfram evaluation service returned HTTP 404, and no local kernel was available. It calls the tested Python implementation and adds a final `RootReduce[answer-input] === 0` check. Its `.wlt` tests are included for execution in a local Wolfram installation.

The uncapped **general mathematical algorithm is finite and complete over Q**, assuming the exact computational primitives described in the article. This is not a claim that every input will finish in practical time, that every code path has been exhaustively tested, or that the output is a shortest radical formula. The default program has resource limits. Forced general runs on the two original examples did not finish within 480 seconds; their compact structural paths succeeded. See `validation/VALIDATION.md`.

Radicals may be complex and may have arbitrary integer orders. The result contains no hidden `Root`, `CRootOf`, trigonometric function, or algebraic-number placeholder. The certificate does contain defining polynomials and exact field data for checking the result. Numerical inputs, symbolic parameters, real-radical-only constraints, and expression minimization are outside this version's contract.

## Install and run

Tested dependency: **SymPy 1.14.0**; tested interpreter: **Python 3.13**. No external CAS, Sage, GAP, or Mathematica is required by the Python implementation. It may work on other modern Python releases, but those were not tested here.

From the extracted `RadicalRoot` directory:

```sh
python -m pip install -r requirements.txt
python -m unittest discover -s tests -v
python examples/demo.py
```

Using a virtual environment is optional. On systems where the interpreter is named `python3`, substitute that command. The source is ordinary Python and can also be imported into a notebook.

### Selected-root Python API

```python
import sys
sys.path.insert(0, "/path/to/RadicalRoot/python")
import sympy as s
from api import root_radicals, all_radicals, verify, selected_expression

x = s.Symbol("x")
r = root_radicals(x**6 + x**4 - x**3 - x**2 - 1, 1)
assert r["status"] == "Success"
assert verify(r)
a = selected_expression(r)
print(a)
```

Indices are **zero-based SymPy `CRootOf` indices**, not Wolfram indices. The positive root of the original sextic is index 1; the largest root of the original quintic is index 4. For reducible or repeated-root input, `root_radicals` first selects the irreducible factor of the requested root. Its `roots` list then contains all conjugates of that selected factor, not necessarily all roots of the supplied polynomial.

`all_radicals(f)` requires an irreducible rational polynomial and returns all conjugates. Its methods are:

- `method="auto"`: compact structural methods followed by the general Galois constructor.
- `method="general"`: the actual constructive Galois algorithm, without structural shortcuts.
- `method="structural"`: only compact patterns; an unrecognized case is `Unknown`.

To remove the general search caps:

```python
r = all_radicals(f, method="general",
                 max_field_degree=None, max_candidates=None)
```

The Python API has no wall-clock limit. Very large fields and coefficients can consume substantial time and memory. The CLI provides a killable worker.

### Command-line interface

Coefficients are in **high-to-low order**. Quote rational coefficients as fraction strings, for example `["1", "0", "-2/3"]`; decimals are rejected. Enter each command on one line:

```sh
python python/cli.py --coefficients "[1,0,1,-1,-1,0,-1]" --index 1 --output sextic.json
python python/cli.py --coefficients "[5,0,-25,0,25,6]" --index 4 --output quintic.json
python python/cli.py --verify-file sextic.json
```

For an irreducible polynomial, `--all` returns all roots without selecting one. `--method general` forces the Galois constructor. Add `--progress` to send stage reports to standard error. Standard output remains JSON.

Default limits: **120 seconds**, general absolute-field degree **128**, and **1,000,000** possible primitive-generator images. `--timeout 0`, `--max-field-degree 0`, and `--max-candidates 0` remove the respective limits. Field and candidate caps apply to the general construction, not to every intermediate operation of a structural formula. There is no hard memory limit.

The CLI independently verifies positive and negative certificates by default. `--no-verify` skips only that additional recheck; construction still performs exact checks. `--json` reads one request from standard input; this is the Wolfram bridge protocol:

```json
{
  "action": "all",
  "coefficients": ["1", "0", "1", "-1", "-1", "0", "-1"],
  "method": "auto",
  "timeout": 120,
  "max_field_degree": 128,
  "max_candidates": 1000000,
  "verify": true
}
```

JSON coefficients are parsed as integers/fractions with a strict grammar, not evaluated as Python code. General API callers should pass trusted SymPy polynomial objects; the API is not a sandbox for arbitrary Python expression strings. Checking untrusted, extremely large certificates can itself be resource-intensive.

### Wolfram Language

Install SymPy into the same interpreter selected by `"PythonExecutable"`, then load:

```wolfram
Get["/path/to/RadicalRoot/wolfram/RadicalRoot.wl"];
r = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
a = RadicalRoot[r,
  "UseNative" -> False,
  "PythonExecutable" -> "/path/to/python"];
RootReduce[a - r]
```

On Windows, supply an absolute `python.exe` path when necessary. By default `"UseNative" -> True` first tries `ToRadicals` and accepts it only if its output is an arithmetic radical and exact equality is proved. Disabling it forces the delivered Python solver.

Available options:

| Option | Default | Meaning |
|---|---:|---|
| `"PythonExecutable"` | `"python"` | Executable used for the backend |
| `"BackendFile"` | `Automatic` | Delivered `python/cli.py` relative to the package |
| `"Method"` | `"Automatic"` | `"Automatic"`, `"General"`, or `"Structural"` |
| `"UseNative"` | `True` | Try native `ToRadicals` first |
| `"NativeTimeLimit"` | `5` | Native conversion time budget |
| `"TimeLimit"` | `120` | Backend worker timeout, including backend verification |
| `"VerificationTimeLimit"` | `120` | Wolfram equality-check budget per candidate |
| `"MaximumFieldDegree"` | `128` | General field-degree cap |
| `"MaximumCandidates"` | `1000000` | General generator-image enumeration cap |
| `"Return"` | `"Expression"` | `"Data"` also returns backend certificate information |

`Infinity` removes backend time/degree/candidate limits. The backend timeout is not a single global deadline for all Wolfram normalization and all final candidate comparisons. No Python/Wolfram nonreal-root ordering correspondence is assumed: the adapter checks candidate equality directly.

After loading the package, run the **supplied but unexecuted** Wolfram tests with:

```wolfram
TestReport["/path/to/RadicalRoot/tests/RadicalRoot.wlt"]
```

## Result semantics

`Success` means a radical program was constructed; default CLI output also has `verified: true` after an independent recheck. `NotSolvable` means an exact group-theoretic obstruction was found. `Unknown` means a resource limit or a missing structural pattern, **not** insolvability. `Error` identifies invalid input or a backend/implementation failure. The Wolfram adapter maps these to expressions or distinguishable `Failure` objects.

For large outputs, retain the sequential JSON definitions rather than repeatedly expanding every subexpression. `selected_expression` produces a full SymPy expression and can be much larger than the program representation.

## Theory and implementation

Read `article/RadicalRoot.pdf` or edit `article/RadicalRoot.tex`. The general algorithm constructs an exact splitting field, adjoins a squarefree-order cyclotomic base, computes the relative Galois action, and solves rational invariance/eigenvector systems along a prime-index normal series. Principal branches are certified by exact conjugation, rational root isolation, and algebraic sign tests. The structural path uses independent annihilating-polynomial and root-separation checks.

The structural verifier defensively handles a SymPy 1.14 edge case: `minpoly(-(-1)**Rational(1,11))` returns the reducible annihilator `x**11-1`. It does **not** assume irreducibility of that result; it proves membership in the intended factor by a root-separation test. This is covered by the cyclotomic regression.

The general root-isolation adapter uses a small private SymPy interface, localized in `certified_embedding.py`; future dependency versions need retesting. The checks are exact-computation certificates under the documented backend assumptions, not proof-assistant formalizations.

## Archive contents and licensing

`python/` contains the implementation; `wolfram/` the adapter; `tests/` regression suites; `examples/` demonstrations; and `validation/` completed certificates, logs, and notebook-audit material. The original notebook was not executed or modified. Its reconstructed input-cell text is an audit aid, not a runnable replacement notebook.

The new code is provided under the MIT license in `LICENSE`. The user-provided notebook material and third-party dependencies retain their own rights and licenses. No dependency source, font file, or third-party paper is bundled.

To rebuild the article, run `pdflatex RadicalRoot.tex` three times from `article/`; no external bibliography file or image asset is required.
