# Root to radicals

Expressing algebraic numbers (`Root` objects) by radicals whenever this is possible, and
proving that it is impossible otherwise, answering
[Mathematica StackExchange question 34011](https://mathematica.stackexchange.com/q/34011/7288),
*Why is `ToRadicals` not able to handle all cases? Is there a workaround?*

A `Root` object has a radical expression exactly when the Galois group of its minimal
polynomial is solvable.  The built-in `ToRadicals` is complete only through degree four
plus a few special shapes; it returns both examples of the question unchanged.  The
article [`article/root-to-radicals.pdf`](article/root-to-radicals.pdf) contains the
theory with proofs (criterion, structural reductions, the general Galois–Kummer descent
with a completeness theorem, Frobenius negative tests, an analysis of the question's
notebook, and a comparison of the nine reports); this file documents the software.

## Contents

| File | Purpose |
| --- | --- |
| `RootToRadicals.wl` | Wolfram Language package (Wolfram 15.0.1). Requires `../root-decomposition/RootDecomposition.wl`, loaded automatically. |
| `RootToRadicals.wlt`, `RunTests.wl` | Regression tests (`wolfram -script RunTests.wl`). |
| `NotebookTarget.wl` | Reproduces the notebook's target (a degree-27 number) and assembles its radical expression (`wolfram -script NotebookTarget.wl`, about 15 minutes). |
| `python/roottoradicals.py` | Python implementation on python-flint and SymPy, reusing `../root-decomposition/python/rootdecomp.py`. |
| `python/test_roottoradicals.py` | Python regression suite with timings; failures exit nonzero. |
| `python/verify_wolfram.py` | Exact verification of Python's expressions in a native Wolfram kernel (`RootReduce`). |
| `python/requirements.txt` | Python dependencies (tested with python-flint 0.8 and SymPy 1.14). |
| `article/` | The unified article (`.tex`, `.pdf`). |
| `reports/report-01` … `report-09` | The nine original reports, unpacked verbatim. |
| `PLAN.md` | The plan of the project and its status. |
| [`../WOLFRAM-NOTES.md`](../WOLFRAM-NOTES.md) | Subtle Wolfram Language (and Arb) behaviour found while developing the packages. |

## Wolfram Language package

```wolfram
Get["RootToRadicals.wl"];
RootToRadicals[Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]]
(* (-4 (2/(3 (9 + Sqrt[849])))^(1/3) + ((9 + Sqrt[849])/2)^(1/3)/3^(2/3) + Sqrt[4 + (...)^2])/2 *)
RootToRadicals[Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]]
(* (-3/5 + (4 I)/5)^(-1/5) + (-3/5 + (4 I)/5)^(1/5) *)
RootRadicalReport[Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 1]]
(* <|"Expression" -> ..., "Verified" -> True, "Method" -> "Galois", "GaloisGroupOrder" -> 5, ...|> *)
RootToRadicals[Root[#^5 - # - 1 &, 1]]
(* Failure["NotSolvable", ...]  (Frobenius cycle types) *)
```

Functions:

- `RootToRadicals[a]`: a radical expression equal to `a` (rational numbers, `I`, `Plus`,
  `Times`, `Power` with rational exponents, principal branches), or a `Failure` with tag
  `NotSolvable` (proved), `NotFound` (structural search exhausted; only with
  `Method -> "Structural"`), `ResourceLimit`, `VerificationFailed`, `Inexact`,
  `NotAlgebraic` or `InvalidOptions`.
- `RootRadicalReport[a]`: association with `"Expression"`, `"Verified"` (`True` by
  `RootReduce`, or `Indeterminate` when the exact check exceeded its time limit and only a
  200-digit numerical check passed), `"Method"` (`"ToRadicals"`, `"Decompose"`,
  `"Reciprocal"`, `"Dickson"`, `"PairSum"`, `"Galois"`), `"Degree"`, `"RadicalDepth"`,
  `"LeafCount"`, `"GaloisGroupOrder"`, `"ExtendedGroupOrder"`, `"SeriesPrimes"`, `"Time"`.
- `RootSolvableQ[a]`: solvability of the Galois group (Frobenius tests first, then the exact
  group).
- `RadicalExpressionQ[e]`, `RadicalDepth[e]`: the radical grammar and its nesting depth.

Options: `Method -> Automatic | "Structural" | "Galois"`, `"Resolvents" -> Automatic |
"Fourier" | "Eigenvector"` (the form of the Kummer step; `Automatic` keeps the shorter
expression), `"MaxGroupOrder"` (default 400), `"WorkingPrecision"` (80),
`"VerificationTimeLimit"` (60 s), `"MaxDepth"` (6), and `"Extension" -> {gens...}`: exact
algebraic numbers generating a subfield over which the minimal polynomial is factored
first; the factor containing the input is solved by the classical formulas after the
generators are expressed in radicals themselves (the notebook's method, made a one-line
option; see `NotebookTarget.wl`).

Nonsolvability is proved without the group whenever a Frobenius cycle type allows it:
prime degree (AGL(1, n) shapes), composite prime-power degree (a single prime cycle of
length strictly between n/2 and n−1), other degrees (a single prime cycle longer than
n/2).  The lcm of the Frobenius element orders divides the group order and gives an
early `ResourceLimit` for large groups.

The structural layer (built-in `ToRadicals`, functional decomposition, generalized
reciprocal symmetry `p(x) = x^m P(x + c/x)`, Dickson polynomials `D_n(x, c) - b`, and the
pair-sum resolvent) produces short formulas; the general descent (splitting field with
the roots of unity adjoined, composition series with prime quotients, Lagrange resolvents,
numerically selected branches, exact verification) is complete for every solvable input.

## Python implementation

```powershell
python -m pip install -r python/requirements.txt
python python/test_roottoradicals.py
python python/verify_wolfram.py   # optional: exact check in a Wolfram kernel
```

```python
import roottoradicals as rt
r = rt.root_to_radicals("Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]")
r.expression      # SymPy expression
r.method          # 'Reciprocal'
r.verified        # True: rigorous ball check against all conjugates
r.wolfram()       # the expression in Wolfram syntax
rt.root_to_radicals("Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 1]", method="galois")
rt.is_solvable("Root[-1 - # + #^5 &, 1]")   # False
```

`root_to_radicals(a, method="auto"|"structural"|"galois", resolvents="auto"|"fourier"|"eigenvector", maxorder=400, prec_bits=300, max_depth=6)`
returns a `RadicalResult` or raises `NotSolvable`, `NotFound`, `ResourceLimit` or
`PrecisionError`.  Branches are selected rigorously in Arb ball arithmetic (unique
overlap among separated candidates), all identities between coordinate vectors are exact,
and radicands that are proved real and negative are written as `(-1)^(1/q) (-Q)^(1/q)`
so that their enclosures stay away from the branch cut.  The Python structural layer has
the classical formulas for degree ≤ 4, decomposition, reciprocal symmetry and Dickson
polynomials; the pair-sum reduction (factorization over a number field) is Wolfram-only,
and the general descent covers those cases.

Both implementations reconstruct resolvent powers and eigenvector quotients directly
from conjugates using the companion package's integer-trace coordinate checks. The
shared `power_divider` / `powerDivider` helper fixes one denominator: after clearing
denominators, an integral element `B` has integral `Norm(B)/B`, so a quotient can be
recovered from integer traces as well. If the norm or a trace cannot be recovered at
the working precision, the helper falls back to the exact matrix calculation and
retains its precision escalation behavior. That matrix is built only when needed and
reused for subsequent powers of the same denominator.

Root indices of non-real roots are exchanged between the two systems by value, not by
index (see the companion project's README).

Descent reuses branches common to the Fourier and eigenvector forms and checks fixed
fields using the remaining composition-series generators, which generate the whole
subgroup. Composition chains solve each suffix over the smaller-degree algebraic value
already obtained at the previous step.

## Refactoring validation (9 September 2026)

Validation accumulated through solver revision `f3fceb2` passed **28 Python test
methods**, **73 native Wolfram tests**, and **13 independent cross-language
checks**. Additional exact comparisons cover all resolvent forms, complete
result metadata, matrix and coordinate arithmetic, and real/complex branches.
Forced precision tests check both successful recovery and exhaustion; the
Wolfram descent now refreshes field data at each retry even when no odd-prime
roots of unity are needed.

The [shared benchmark](../benchmarks/README.md) records current Python workloads
with immutable baselines, exact-output checks, source hashes, and raw samples.
It states which field data and dependencies are shared between the versions.

## Historical article measurements

The following measurements were retained in baseline `204c97f` from the article's
"Measurements" section. They describe the original implementation on its
development machine (Wolfram 15.0.1, Python 3.14, python-flint 0.8). Both examples
of the question were solved by the structural layer in under 0.2 s; the forced
general descent took 41 s (sextic, group orders 24 → 48) and 18 s (quintic, 20 → 40)
in Wolfram, 24 s and 12 s in
Python; the cyclic quintic (which needs the descent) took 8 s in Wolfram and 0.4 s in
Python; nonsolvable prime-degree inputs are refused in milliseconds by Frobenius cycle
types, whereas the exact group of `x^5 - x - 1` (order 120) takes 18 minutes in Wolfram.
The notebook's own target, a degree-27 number, is expressed by radicals in 11 minutes
through the `"Extension"` option (depth 5, about 107 000 leaves, equal to the inverse beta
value to 300 digits; the exact `RootReduce` check exceeds the time cap, so the report is
honest about `"Verified" -> Indeterminate`).
