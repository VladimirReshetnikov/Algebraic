# Verification: precise scope

## Executed exact arithmetic

`verify_exact.py` was executed with Python and SymPy 1.14.0. The resulting
`report.json` records **PASS for the stated independent mathematical checks**.
This script uses explicit ascending polynomial coefficient vectors over
`QQ` or `QQ.algebraic_field(...)`, including exact ANP number-field elements.
It does not use floating-point equality and does not need a Wolfram kernel.

For every fixed-degree test, the formal-root recurrence is checked against
a **separate finite binomial expansion**. Leading-coefficient congruence,
base-inner digit reconstruction, and the equivalence of constant digits
with zero residual are checked exactly. Known composed pairs with arbitrary
nonzero inner leading coefficient and nonzero inner constant are recovered
in normalized form. Every recorded chain recomposes exactly, has atomic
components under exhaustive divisor tests, and has normalized inner factors.
Enumerated chain lists are checked for duplicates and the Ritt multiset
invariant.

The run contains 974 polynomial cases, 2,001 degree tests, 1,042 checked chains,
and 95 recovered known pairs. Inputs include 810 exhaustive monic rational
polynomials of degrees 4 and 6 with coefficients -1, 0, or 1 below the leading
term, 14 fixed examples, and 30 generated cases in each of five fields:
Q, Q(sqrt(2)), Q(i), Q(sqrt(2),sqrt(3)), and Q(alpha) for a root of
x^5-x-1. The pseudorandom seed is 206618. Runtime in the JSON is an observation
of this particular verification run, not a benchmark for the Wolfram package.

Reproduce with Python >= 3.10:

```sh
python -m pip install -r Verification/requirements.txt
python Verification/verify_exact.py --output Verification/report.json
```

## Differential comparison caveat

The script also called SymPy 1.14.0's `decompose` over QQ in 848 rational
cases. In 14 cases the degree patterns disagreed. No such disagreement is
silently reported as agreement, and the external decomposition routine is
not a correctness oracle. The first three discrepancies appear in the JSON.

One reproducible example is

```python
import sympy as s
x = s.symbols('x')
p = -8*x**6 + 24*x**5 - 34*x**4 + 38*x**3 - 29*x**2 + 14*x - 7
print(s.decompose(p, x, domain=s.QQ))
f = -8*x**2 + 14*x - 7
h = x**3 - s.Rational(3, 2)*x**2 + x
assert s.expand(f.subs(x, h) - p) == 0
```

In the tested version, the baseline returned a singleton `[p]`, whereas the
verified pair is `[f,h]`. The documented PASS status refers to the exact
identities and invariants in this script, not to 848 identical outputs.
Other versions can legitimately produce a different comparison count.

## Native Wolfram execution: NOT PERFORMED

The available Wolfram connector was discovered and called. Its context and
language-evaluator endpoints both failed with HTTP 404:
`MCP SSE probe returned 404 from wolfram.com`, endpoint
`https://agenttools.wolfram.com/mcp`. No local Wolfram kernel was present.
Consequently, the Wolfram implementation has not been loaded or executed in
a native kernel in this environment. No version number or native pass count
is claimed.

There are 60 authored native `VerificationTest` cases. One wraps 24 seeded
compositional property cases. They include algebraic representation tests,
complex quintic roots, degree cancellation, invalid inputs, and certificate
corruption (including a forged negative certificate with correct digit
reconstruction but an incorrect leading congruence).

Run them in a fresh Wolfram kernel:

```sh
wolframscript -file Tests/RunTests.wl
```

The runner prints `$Version`, the report, and returns an exit code based on
the available success property. The article and README deliberately retain
the native-execution limitation even though the independent checks pass.

## Source inspection: NOT a Wolfram parser

`check_source.py` checks balanced delimiters, nested comments, string escapes,
unique native test IDs, the absence of `Return` syntactically inside a loop,
and byte-for-byte agreement between the article's embedded package source
and the loadable implementation. Its `source_checks.json` is a packaging and
basic lexical report, not syntax validation by the Wolfram parser and not
execution of the package.

The source was reviewed for loop control semantics. Nested-loop exits use a
locally tagged `Catch`/`Throw`, and successful pair search sets a result and
uses `Break`. A loop-local `Return` is not used as if it were a multilevel
function exit. This is relevant to correct Wolfram control flow but is not
a substitute for running the supplied native tests.
