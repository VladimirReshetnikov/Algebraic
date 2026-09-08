# Validation record

Date: 2026-09-07. Release: 1.0.0.

## Executed

`run_reference_tests.py` ran successfully: **574 checks passed, zero failed**, Python 3.13.5, SymPy 1.14.0, deterministic seed 206618. See `reference_results.json` for individual check names, runtime, environments, and observed external-oracle disagreements. `worked_examples.txt` contains exact example results.

The reference implementation uses exact elements of QQ, QQ(sqrt(2)), a quintic number field, and the degree-eight field QQ(sqrt(2),sqrt(3),i). It is a separate Python implementation, not a translation engine or evaluator for Wolfram Language. Validation includes constructed decompositions with arbitrary affine normalization, explicit composite-degree indecomposable cases, enumeration and cap behavior, independent polynomial division, and formal-binomial-series checks of the coefficient recurrence.

`wl_static_check.py` checked the six WL/WLT/WLS/M files for balanced delimiters, nested comments, and strings. It also checked that the package core does not call Factor, FactorList, Solve, built-in Decompose, PossibleZeroQ, N, Chop, Rationalize, or RootApproximant. See `wl_static_results.json`. This check is deliberately described as lexical, not as a parser or runtime test.

## Not executed

The **107 MUnit tests** in `Tests/AlgebraicDecomposition.wlt` were generated and statically inspected but **not run in a Wolfram Language kernel**. The available Wolfram connector was attempted for context and evaluation; both attempts failed with HTTP 404 at its MCP endpoint. No local Wolfram kernel was available. Native runtime, message behavior, option dispatch, and version compatibility therefore remain to be confirmed.

`Tests/RunTests.wls` loads the package, prints the kernel version, invokes TestReport, and exits nonzero unless the report succeeds. Its compatibility handling prefers the modern ReportSucceeded property and otherwise uses older test-count properties. That runner is also unexecuted.

The supplied package and examples must not be described as native-kernel tested. The number 574 concerns executed independent reference assertions; 107 concerns prepared native tests. They are not additive counts of executed tests.

## Independent-oracle caveat

The installed SymPy 1.14.0 polynomial decomposition code missed some known decompositions when an explicit field domain was used. Eighteen of 24 selected constructed-composite comparisons disagreed in degree multiset. The discrepancies are retained in the JSON output and explained in `ORACLE_NOTE.md`. They are not failures of the 574 independent assertions; those assertions use directly known normalized factors, exact recomposition, or separately implemented operations. This observation reinforces the need to run the native MUnit suite rather than rely solely on a second CAS.

## Reproduction

From the archive root:

```
python validation/run_reference_tests.py
python validation/wl_static_check.py
wolframscript -file Tests/RunTests.wls
```

The first two commands reproduce the executed checks. The third is the native validation still to perform. `make_native_tests.py` regenerates the frozen native suite, using the Python reference to serialize some fixtures. Known analytic fixtures and negative/input-contract cases are separately specified.
