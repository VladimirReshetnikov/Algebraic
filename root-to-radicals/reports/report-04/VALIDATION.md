# Validation record

## Executed

Main regression suite: **46/46 passed**.
Additional CLI/certificate smoke tests: **8/8 passed**.
Environment: Python 3.13.5, SymPy 1.14.0.

Tested engine SHA-256:
`bc94b920eebba950fac0d68b0896ac0d372c9cc94250b9ad3f1ff35b0e724cea`

Both reports fingerprint exactly the delivered engine file. The main suite
contains 8 nontrivial Galois-Kummer conversions checked separately by
triangular polynomial reduction and root separation. It also records
11 additional minimal-polynomial checks. Structural cases not given
that additional check are marked explicitly in test-report.json.

The CLI tests cover process execution, arithmetic-DAG decoding, exact complex
rectangle selection, a nonsolvable group, watchdog expiry, and an invalid
index. They also reject a tampered final tower expression and phase, and
distinguish exact roots separated by 10^(-40).

The four JSON examples were generated with the delivered command-line engine.
Their Wolfram expressions were exported from those JSON results. The generated
Wolfram text was checked for balanced delimiters, not evaluated.

## Not executed or not established

The Wolfram front end and Tests.wlt were not run. Both attempted Wolfram
connector actions failed with HTTP 404; no local kernel was available.
Static delimiter checks are not a substitute for kernel integration tests.

No benchmark against current Mathematica, SageMath, or Magma was run. The 220
notebook input cells were inspected but not executed or exhaustively solved.
There is no formal verification of SymPy, the Galois-group algorithm, the
bounded-error evaluator, or the Python checker. The arithmetic-tower checker
provides an exact independently executable check of positive answers, not a
proof-assistant certificate of every implementation component.

## Reproduce

```sh
python -m pip install -r requirements.txt
python tests/test_radical_roots.py
python tests/test_cli.py
```

Reports are written into validation/. Per-case timings in the JSON are local
observations, not controlled benchmark figures. The main run took about
210.1 seconds in total.
