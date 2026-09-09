# Plan: `root-to-radicals`

Answering Mathematica StackExchange question 34011, *Why is `ToRadicals` not
able to handle all cases? Is there a workaround?*  Given a `Root` object whose
minimal polynomial has a solvable Galois group, produce an explicit expression
in radicals; otherwise prove that none exists.

Deliverables mirror the `root-decomposition/` project: one Wolfram package, one
Python port, one unified article, tests that are actually executed, and notes.

## 0. Status of the inputs (done)

* Nine reports unpacked into `reports/report-01 … report-09` (ZIPs and checksum
  ledgers removed), committed.
* Three parallel reviews of the nine articles completed; findings summarised in
  section 5 below.
* The user's original notebook is in
  `docs/mathematica.stackexchange.com/why-is-toradicals-.../FindExtension.nb`
  and, as an inert text transcription, in `reports/report-09/original/`.
* Baseline measured in Wolfram 15.0.1: built-in `ToRadicals` fails on both
  examples of the question, on the cyclic quintic `x^5+x^4-4x^3-3x^2+3x+1`, and
  succeeds on `x^3-3x+1`, `x^4-x-1`, `x^5-2`, `x^6-2x^3-1`, `x^8+1`.
* Galois data for the examples, from the existing `RootDecomposition.wl`
  engine: sextic `|G| = 24`, exponent 12, 5.1 s; quintic `|G| = 20`,
  exponent 20, 2.3 s; with the needed roots of unity adjoined (multiply by the
  cyclotomic factors) `|G| = 48` in 33 s and `|G| = 40` in 10 s.  Both groups
  are solvable, so both examples are in reach of the general algorithm, not
  only of the structural shortcuts.

## 1. Mathematical content of the article

1. **Statement of the problem.**  Radical grammar (rationals, `I`, `+`, `*`,
   rational powers, principal branches; `ζ_m = (-1)^(2/m)`), the difference
   between *deciding*, *constructing* and *identifying the requested
   conjugate*, and why the criterion applies to the minimal polynomial of the
   selected number rather than to any annihilating polynomial.
2. **Why `ToRadicals` fails.**  Documented behaviour: complete through degree
   four, plus special forms.  Measured failures above.  The obstruction is not
   undecidability: solvability of the Galois group is decidable, and Landau and
   Miller (1985) put solvability by radicals in polynomial time.  What is
   expensive is the *construction*.
3. **Criterion.**  Galois' theorem, with the reduction to the splitting field
   and the roots-of-unity base: `m = rad(|G|)`, `B = Q(ζ_m)`, `M = L·B`,
   `H = Gal(M/B) ≅ Gal(L/L∩B)` is solvable iff `G` is, and every prime dividing
   `|H|` divides `m`.  Proof.
4. **Structural reductions** (short formulas, no splitting field): translation
   and power composition, functional decomposition `f = g∘h`, generalized
   reciprocal `f(x) = x^m P(x + a/x)`, Dickson polynomials
   `D_n(u + a/u, a) = u^n + (a/u)^n`, pair-sum resolvents
   `Res_x(f(x), f(y-x)) = 2^n f(y/2) R_2(y)^2`.  Each with a proof and with the
   branch-coupling argument (the reciprocal term `a/u` must be carried, not
   re-extracted).
5. **The two examples worked out.**  Sextic: `f = x^3((x-1/x)^3 + 4(x-1/x) - 1)`,
   `u = ((9+√849)/18)^(1/3)`, `y = u - 4/(3u)`, `α = (y + √(y²+4))/2`.
   Quintic: `5(D_5(x,1) + 6/5)`, `u = ((-3+4i)/5)^(1/5)`, `β = u + 1/u`.
   Proofs that these are the requested branches (monotonicity of `x - 1/x`;
   `|(-3+4i)/5| = 1` so the roots are `2cos((θ+2πj)/5)`).
6. **General Galois–Kummer descent.**  Splitting field and automorphisms;
   solvability and a composition series with prime quotients; the Lagrange
   resolvent `R_k = Σ_j ζ_p^{-kj} σ^j(β)` with `σ R_k = ζ_p^k R_k`,
   `R_k^p` one level down and `pβ = Σ_k R_k`; branch selection; termination and
   completeness theorem, with the resource caveat.
7. **Two refinements worth stating.**  (a) The tensor algebra
   `L[z]/Φ_p(z) ≅ L ⊗ Q(ζ_p)` has zero divisors when `ζ_p ∈ L`; the descent
   must avoid inversion there (report-05's observation).  (b) Fourier inversion
   over *all* components needs no nonzero-generator search (report-03/05),
   whereas a single Kummer eigenvector gives shorter formulas (report-04).
   The implementation uses the eigenvector when it is cheap and falls back to
   full inversion.
8. **Negative results.**  Frobenius cycle types: a prime-degree polynomial with
   a factorization pattern outside `1^n`, `n`, `1·d^{(n-1)/d}` is not solvable
   (Galois: solvable transitive of prime degree ⊆ AGL(1,n)).  Exact group
   computation otherwise.  `x^5-x-1` and `x^7-x-1` as examples.
9. **What the notebook did.**  `findExtension` eliminates `p, q` from
   `PolynomialRemainder[mp, x²+px+q]`, i.e. searches symmetric functions of
   pairs of conjugates: exactly the pair-sum resolvent, discovered ad hoc.
   `project` uses real and imaginary parts; `fuzz` guesses subset sums with
   `RootApproximant` and checks with `PossibleZeroQ`; `simplify` iterates
   `FullSimplify` with a custom complexity function.  These are useful
   discovery devices; the systematic replacement is stated per device.
10. **Comparison of the nine reports** (table): what each contributed beyond
    the common core, where they disagree, and which claims were executed.

## 2. Wolfram package `RootToRadicals.wl`

Reuses `root-decomposition/RootDecomposition.wl` (numerical resolvents for the
Galois group, tower monomial basis, trace-form coordinates) instead of
`ToNumberField[roots, All]`, which the nine reports all propose and which takes
14 minutes on a degree-36 field in this kernel.

Public functions:

| Function | Purpose |
| --- | --- |
| `RootToRadicals[a]` | radical expression, or a `Failure` |
| `RootRadicalReport[a]` | association: expression, method, verification, group order, timing |
| `RootSolvableQ[a]` | solvability of the Galois group |
| `RadicalExpressionQ[e]`, `RadicalDepth[e]` | grammar predicate and nesting depth |

Options: `Method -> Automatic | "Structural" | "Galois"`, `"MaxGroupOrder"`,
`"WorkingPrecision"`, `"VerificationTimeLimit"`, `"MaxDepth"`.
Statuses kept distinct: success, `NotSolvable` (proved), `NotFound`
(structural search exhausted), `ResourceLimit`, `VerificationFailed`.
Every returned expression is checked with `RootReduce[expr - a] === 0`.

A first draft exists (committed with this plan) and is **not yet tested**.

## 3. Python port `python/roottoradicals.py`

Same algorithms on python-flint plus SymPy, reusing
`root-decomposition/python/rootdecomp.py` for the Galois data (Arb ball
arithmetic, rigorous integer rounding, FLINT factorization and linear algebra).
Same root ordering as Mathematica, so results can be exchanged.  A regression
script with timings, as in the sibling project.

## 4. Tests and validation

* `RootToRadicals.wlt` executed with `wolfram -script RunTests.wl`: both
  question examples with all their conjugates; structural families (Dickson,
  reciprocal, power composition, decomposition); forced general descent on
  `x^3-2`, `x^3-3x+1`, `x^4-2`, `x^4-10x^2+1`, `x^5-2`, and the cyclic quintic
  `x^5+x^4-4x^3-3x^2+3x+1` (the case built-in `ToRadicals` misses and which
  exercises a prime-5 Kummer step); nonsolvable `x^5-x-1`, `x^7-x-1`;
  invalid input; resource limits.
* Python suite with the same cases.
* Timing table in the article and both READMEs; the honest statement of what
  was executed, as in `root-decomposition/`.

## 5. What the nine reports give us (input to the article)

Common core in all nine: the solvability criterion on the minimal polynomial;
cyclotomic base `rad(|G|)`; prime composition series; Lagrange/Fourier
resolvents; exact branch selection; the same two closed forms for the question's
examples; and the same completeness theorem conditional on exact primitives.

Distinctive contributions to carry into the unified treatment:

* 01: Kummer generators as a rational nullspace; certified rectangle
  embeddings; the only forced general run on the original examples (did not
  finish in 480 s).
* 02: pair-sum resolvent as the systematic form of the notebook's
  `findExtension`; trace–Fourier basis search with a termination proof.
* 03: Fourier inversion `a = (1/p)ΣR_j` needing no generator search; the
  clearest account of SymPy embedding pitfalls; the "oversized supplied field
  does not prove nonsolvability" point.
* 04: relative-automorphism recovery avoiding a second factorization;
  trace-projector scoring for small radicands; independent tower checker.
* 05: division-free tensor algebra `L ⊗ Q(ζ_p)` with zero divisors; resultant
  primitive elements with a square-free certificate; norm-polynomial
  justification of branch comparisons.
* 06: exact Frobenius negative test; principal-sector branch predicate with
  conjugation-based zero tests; straight-line register programs.
* 07: the only native Wolfram implementation of the general algorithm
  (untested); notebook audit with line numbers.
* 08: coherent-branch theorem (any consistent branch assignment reproduces the
  full root set); purely rational certificate checker.
* 09: five-status taxonomy; replayable certificates with an embedding anchor;
  the only executed prime-5 Kummer step; the most detailed notebook critique.

Points to correct or verify independently: report-07 cites Milne "Theorem 3.28"
for the solvability criterion (it is in Chapter 5); several reports claim
`MANIFEST`/`SHA256SUMS` files that were removed here by repository policy; and
no report executed any Wolfram code, so every Wolfram claim in them is
unvalidated.

## 6. Order of work

1. Plan and current state committed.
2. Finish and debug `RootToRadicals.wl`; run it on the two examples. — done
3. Structural layer hardened (pair-sum method added; decomposition chains peeled from the
   outside); general descent with Fourier and eigenvector forms, precision escalation,
   Frobenius negative tests (prime degree, and long prime cycles in non-prime-power
   degree). — done
4. Wolfram test suite: 67 tests, all pass (`wolfram -script RunTests.wl`, 89 s). — done
5. Python port and its suite: 48 cases in 39 s, all pass; `verify_wolfram.py` re-verifies
   13 expressions exactly in a kernel (conjugates identified by value). — done
8. Later additions: the prime-power-degree Frobenius rule (a single prime cycle of length
   strictly between n/2 and n-1), the early `ResourceLimit` from the lcm of Frobenius
   element orders, and the `"Extension"` option (user-supplied subfield generators), used
   by `NotebookTarget.wl` to assemble the notebook's degree-27 number. — done
6. Article written against measured results, compiled to PDF. — done
7. README, `WOLFRAM-NOTES.md` additions, final timings. — done

## 7. Corrections to section 5 found while writing the article

* Report 07 is not the only native Wolfram implementation of the general algorithm:
  reports 02 (`kummerSolve`) and 03 (`galoisConvert`) also ship one; none of the three
  was executed by its author.
* Report 09 is not the only one that executed a prime-5 Kummer step: 01 (twice), 04
  and 05 did too.  Report 01 remains the only one that forced the general descent on the
  original examples (and did not finish).
* Report 01's own term is "rational rectangles", not "certified rectangle embeddings".
* Only reports 08 and 09 claim checksum files that are absent.

## 8. The notebook's actual target

`FindExtension.nb` works on $\beta_0 = I^{-1}_{1/9}(1/3, 1/3)$ (inverse regularized
beta), recognized by `RootApproximant` as an algebraic number of degree 27 (minimal
polynomial found in 7 s; equality holds to 400 digits).  Over $\mathbb{Q}(3^{1/6})$ its
minimal polynomial factors into degrees 9 and 18.  Degree 27 is a prime power, so the
Frobenius tests do not apply, and `RootSolvableQ` on the degree-27 number did not finish
in 15 minutes with `"MaxGroupOrder" -> 3000`.  The notebook's degree-9 number θ (third
root of x^9-657x^8+6111x^7+3318x^6+19647x^5-12033x^4+3972x^3-684x^2+9x-1) has Galois
group of order 18, exponent 6; `RootRadicalReport[θ]` returns a verified radical
expression in 43 s (series primes {3, 3}, depth 3, 111 leaves).  The degree-9 factor
over Q(3^(1/6)) vanishing at β0 splits over Q(3^(1/6), θ) into three cubics (237 s), so
β0 is expressible by radicals.  `NotebookTarget.wl` assembles the expression with
`RootRadicalReport[root, "Extension" -> {3^(1/6), theta}]`: depth 5, LeafCount 107067,
11 minutes, equal to β0 to 300 digits; `RootReduce` did not finish within the 300 s cap,
so the report says `"Verified" -> Indeterminate` (exact by construction).  The expression
is saved in `NotebookTarget-expression.m`.  Pitfalls met: (a) `N` of an exact zero emits
`N::meprec`; (b) factoring the degree-27 polynomial over the degree-54 field in one step
did not finish in an hour, cumulative factoring takes 4 minutes; (c) recognizing the
factor that vanishes at β0 needs a scale-aware zero test, because its coefficients have
height 10^100 and a 40-digit evaluation cancels catastrophically; (d) substituting the
radical form of θ into degree-8 polynomial coefficients and expanding blows up; keep θ
atomic through the cubic formula and substitute once at the end.
