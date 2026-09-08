# Validation status — 8 September 2026

## Executed Python regression suite

Environment: Linux x86_64; Python 3.13.5; SymPy 1.14.0; pytest 9.0.2.
Command from the archive root:

```
pytest -vv --durations=12 --junitxml=validation/pytest.xml
```

The repository's `tests/conftest.py` places its Python source on the import path.
Final recorded outcome: **48 passed, no failures or skips, 40.22 seconds**.
The exact successful console record is `pytest-output.txt`. The slowest test,
forced Galois/Kummer conversion for x^4-2, took 22.96 seconds in that run.

Selected assertions include:
- all five selected roots of 5*x^5-25*x^3+25*x+6 are radicalized and exactly rechecked;
- both real roots of x^6+x^4-x^3-x^2-1 are radicalized and exactly rechecked;
- the explicit general method succeeds for a quadratic, two cubic embeddings,
  a quartic cyclotomic field, and the degree-eight splitting field of x^4-2;
- the degree-eight notebook target is verified using a supplied sqrt(3)+sqrt(5) hint;
- pair-resolvent construction preserves the full resultant identity;
- prime-cyclic chains work on five finite solvable group fixtures, and A5 is rejected;
- x^5-x-1 is rejected through the exact degree-at-most-six SymPy Galois shortcut;
- the wrong sqrt(2) conjugate is rejected; bounds and bad inputs remain distinct.

These are finite regression tests, not an exhaustive correctness proof for the
CAS libraries or an empirical all-degree completeness claim.

## Additional checks

`examples-output.txt`: basic.py ran; exact final equality checks for the two
question targets and general cubic succeeded, and the nonsolvable quintic was
identified.

`identities-output.txt`: exact polynomial identities for the quintic, sextic,
and degree-eight transformed polynomial, including a resultant derivation, passed.

`cli-success.json`: the process-isolated CLI solved the question quintic.
`cli-timeout.json`: a deliberately 0.01-second worker limit returned
resource_limit, not not_solvable.

The article was compiled with pdflatex, rendered as 19 page images, and visually
inspected (contact sheet plus detailed mathematical/example/validation pages).
The final LaTeX log has no overfull-box, unresolved-reference, or compilation warnings.

## Wolfram Language

The discovered Wolfram service was attempted and returned HTTP 404 for both
context and evaluator calls. **No Wolfram kernel execution succeeded.**
`wolfram-static.txt` records a lexical check for balanced delimiters, strings,
and nested comments. This is not a WL syntax parser or runtime validation.
The 11 tests in `tests/RadicalRoot.wlt` must be run in a licensed local kernel.

## Development history and limitations

One early aggregate Python run exceeded its external time budget. Subsequent
runs exposed and corrected an uncaught GeneratorsNeeded exception for constant
input and a test-only QQ-versus-ZZ polynomial-domain comparison. Only the final
successful run supplies the reported pass count. Intermediate failing logs are
not included as final validation artifacts.

No benchmark was completed for every high-degree notebook experiment. The
normal-field construction can be costly before degree bounds are known.
The Python API itself has no wall-clock or memory limiter; use the CLI for a
worker-time limit. The Wolfram package uses TimeConstrained. Neither package
minimizes radical nesting or guarantees a small printed expression.
