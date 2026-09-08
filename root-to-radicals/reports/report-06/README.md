# RootRadicals 0.1.0

Convert a **specified exact algebraic number** into a **principal-branch radical expression**, with exact verification and explicit failure semantics.

The distribution contains a Wolfram Language package, an executed Python/SymPy reference implementation, and the article **From Root Objects to Certified Radical Towers** in both LaTeX and PDF. The motivating inputs are Vladimir Reshetnikov's Mathematica Stack Exchange question 34011 and the supplied `FindExtension.nb`.

## Start here

Read [`article/root-radicals.pdf`](article/root-radicals.pdf) for the theory and [`examples/demo.py`](examples/demo.py) for executable examples.

### Wolfram Language

```wl
Get["/path/to/RootRadicals/wolfram/RootRadicals.wl"];

a = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
b = RootToRadicals[a];
RootReduce[b - a] === 0

c = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
RootToRadicals[c]
```

Native structural routines cover both original examples without requiring Python. For the general Galois backend, install the Python component and set the interpreter path when needed:

```wl
r = RadicalizeRoot[a,
  "PythonExecutable" -> "C:\\Python311\\python.exe",
  "UseNative" -> False];

r["Status"]
(* Access r["Expression"] only after Status is "Success". *)
```

**Wolfram execution status:** the `.wl` source was statically reviewed and delimiter-checked, but it was **not executed in a Wolfram kernel** here. The available Wolfram service returned HTTP 404. The MUnit tests are provided for local validation. The Python implementation is the executed reference.

### Python

Python 3.10 or later is declared; the recorded tests used Python 3.13.5 and SymPy 1.14.0 (the exact environment is in the validation report).

From the extracted project root:

```sh
python -m pip install -e ./python
python examples/demo.py
python -m unittest discover -s tests -v
```

Alternatively, install `python/requirements.txt` and put the `python` directory on `PYTHONPATH`. The standalone driver resolves its own package path and does not require an editable install.

```python
import sympy as s
from rootradicals import radicalize

x = s.Symbol("x")
a = s.CRootOf(x**6 + x**4 - x**3 - x**2 - 1, 1)
r = radicalize(a)
assert r.status == "success"
assert r.verify()
print(r.expression)
print(r.program.wolfram())
```

The zero-based SymPy root index `1` above denotes the original sextic's positive real root. **Do not generally translate Wolfram complex root indices by subtracting one.** The Wolfram frontend sends an approximate embedding hint and independently proves the final identity with `RootReduce`.

## What is implemented

The automatic route tries low-degree formulas, translated binomials, power substitutions, Dickson substitutions, generalized reciprocal reductions, supported polynomial compositions, cyclotomic roots, maximal real cyclotomic traces, and optional radical extension hints. An exact good-prime factorization can prove nonsolvability in prime degree. SymPy's Galois routine is also used as an optional negative shortcut in its supported degrees.

The **general route is actual code**, not a stub: it constructs an embedded splitting field, adjoins the needed roots of unity, computes the automorphisms by exact factorization, constructs a prime-index subnormal series, finds nonzero Fourier/trace resolvents, reconstructs radicands by rational linear algebra, and chooses principal branches using exact sign decisions. Successful tower outputs have replayable in-memory certificates. Conjugation, the cyclotomic base, and the final target are independently checked against their specified embeddings.

The article proves that the unrestricted algorithm terminates under terminating exact algebraic primitives. That is **not** a claim that every solvable input is practical with the supplied absolute-field backend, or that the CAS implementation is universally validated. Full splitting fields and coefficient swell can make even modest-degree inputs expensive.

## Results and limits

| Result | Meaning |
|---|---|
| `success` | Verified radical expression/program for the selected algebraic number. |
| `not_solvable` | Exact negative Galois/Frobenius obstruction. |
| `resource_limit` | Degree or worker deadline reached; no solvability conclusion. |
| `unknown` | Recognizer/backend failure or inconclusive verification. |
| `invalid_input` | Invalid JSON/input options; direct Python calls normally raise exceptions. |

Python options:

```python
radicalize(a, method="auto", max_field_degree=64)
radicalize(a, method="structural", extension_hints=[s.sqrt(2), s.sqrt(3)])
radicalize(a, method="galois", max_field_degree=None)
```

The **direct Python API has no automatic time limit**. The CLI uses a killable worker with a default 180-second deadline. `max_field_degree=None` removes the field-degree guard. Use the CLI for cancellation of expensive CAS primitives; a degree guard only checks a constructed field after the construction returns. This release has no hard memory limit.

Wolfram options include:

```wl
RadicalizeRoot[a,
  Method -> "Galois",             (* Automatic, "Structural", or "Galois" *)
  "TimeLimit" -> 180,             (* backend worker seconds; Infinity allowed *)
  "MaxFieldDegree" -> 64,         (* Infinity removes the field-degree guard *)
  "VerificationTimeLimit" -> 60, (* separate Wolfram RootReduce deadline *)
  "NativeTimeLimit" -> 15,
  "ExtensionHints" -> {},
  "MaxEmbeddingRetries" -> 4,
  "InitialEmbeddingDigits" -> 80]
```

`RootToRadicals` returns a `Failure` instead of an unverified expression when conversion does not succeed. Use `RadicalizeRoot` to inspect the details.

## Two compact formulas

For the original sextic, set

```wl
v = ((9 + Sqrt[849])/18)^(1/3);
t = v - 4/(3 v);
(t + Sqrt[t^2 + 4])/2
```

The exact substitution is `t = x - 1/x`, giving `t^3 + 4 t - 1 = 0`.

For the original quintic:

```wl
u = ((-3 + 4 I)/5)^(1/5);
u + 1/u
```

The coupled reciprocal ensures the two fifth-root contributions use compatible branches.

## JSON protocol and expression sharing

```json
{
  "coefficients": [["1","1"],["0","1"],["-2","1"]],
  "root_index": 1,
  "method": "auto",
  "max_field_degree": 64,
  "time_limit": 180
}
```

Coefficients are in **descending** order, each a pair of decimal-string numerator and positive denominator. Send the request to standard input of `python python/driver.py`. Set `time_limit` or `max_field_degree` to JSON `null` to remove the corresponding guard. `root_index` is a zero-based SymPy index including multiplicities of the input polynomial; normalization then uses the chosen root's minimal polynomial.

Results contain a whitelisted `rootradicals-dag-v1` arithmetic DAG. This is the machine interface; `wolfram_program` is human-readable source only. The frontend never evaluates returned source strings. The direct Python API accepts trusted SymPy expressions, not untrusted expression text.

For large answers use `r.program.assignments`, `r.program.output`, `r.program.to_json()`, or `r.program.wolfram()` instead of expanding `r.expression`. `r.program.expression(max_nodes=None)` removes the expansion-size convenience check. That check runs after substitution and is not a memory sandbox.

`r.verify()` replays an in-memory tower certificate. The JSON `certificate` field is a **diagnostic summary, not a standalone portable proof certificate**. In another process, recompute/replay, verify the expanded expression, or run the Wolfram exact equality check.

## Validation

`validation/test-report.json` and `validation/test-output.txt` record the final Python suite. The separate extended-smoke run covers 27 conversions, including all six conjugates of the original sextic, all five roots of the original quintic, all seven branches of a translated septic, and forced Galois examples. Every one of those conversions passed tower/identity verification and an independent minimal-polynomial/selected-root check.

A forced Galois run for `x^8 + 1` succeeded with field degree eight, three quadratic steps, and a 14-node DAG. A forced general run for the real-cyclotomic quintic `x^5+x^4-4*x^3-3*x^2+3*x+1` hit a 90-second worker limit; its structural cyclotomic-trace route is tested separately. This known-solvable timeout is retained as a performance limitation, not reported as nonsolvability.

The selected high-degree notebook fixtures in `notes/notebook-fixtures.json` are **not** marked as solved. The original notebook is not redistributed; hashes and inspection notes identify the source.

To regenerate the final machine-readable report:

```sh
python tests/run_validation.py
```

For Wolfram tests, load the package and run `TestReport["/path/to/tests/RootRadicals.wlt"]`, or use `wolframscript -file tests/RunWolframTests.wls` with the Python backend installed.

## Build the article

```sh
cd article
pdflatex -interaction=nonstopmode -halt-on-error root-radicals.tex
pdflatex -interaction=nonstopmode -halt-on-error root-radicals.tex
```

The article uses standard LaTeX packages and Latin Modern fonts supplied by the TeX installation. No font files are distributed.

## License

New code and documentation are provided under **MIT-0**, in `LICENSE`. Third-party software and cited literature retain their own licenses. The supplied source notebook is acknowledged, not relicensed or redistributed.
