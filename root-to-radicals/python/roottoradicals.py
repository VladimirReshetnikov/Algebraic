"""
roottoradicals.py -- radical expressions for algebraic numbers with a solvable
Galois group.

A Python counterpart of the Wolfram Language package RootToRadicals.wl,
answering Mathematica StackExchange question 34011 ("Why is ToRadicals not able
to handle all cases?").  Given an algebraic number a (a root of an irreducible
integer polynomial with a root index, see rootdecomp.AlgebraicNumber), the
function root_to_radicals(a) returns a SymPy expression built only from
rational numbers, I, +, * and rational powers (principal branches) that is
equal to a, or raises NotSolvable when the Galois group of the minimal
polynomial is not solvable.

Two layers, as in the Wolfram package:

* structural recognizers (short formulas): degree <= 4 by the classical
  formulas (SymPy), functional decomposition p = g1(g2(...(x))) (SymPy
  decompose), generalized reciprocal symmetry p(x) = x^m P(x + a/x), Dickson
  polynomials D_n(x, a) - b;

* the general Galois-Kummer descent (complete for solvable inputs): Galois
  group and splitting field from rootdecomp.galois_data (numerical resolvents
  in Arb ball arithmetic, tower basis, exact rational coordinates); the roots
  of unity zeta_q for the odd primes q dividing |G| are adjoined by running the
  same engine on p(x) * prod Phi_q(x); a composition series with prime
  quotients of H = Gal(L(zeta)/Q(zeta)) is read off the multiplication table;
  each prime step is inverted with Lagrange resolvents
  R_k = sum_j zeta_q^(-kj) sigma^j(v) whose q-th powers lie one level down.
  Either all resolvents are extracted ("fourier": v = (1/q) sum_k R_k) or one
  resolvent u = R_1 is extracted and R_k = c_k u^k with c_k one level down
  ("eigenvector"); "auto" keeps the shorter expression.

Branches are selected rigorously: the q candidates zeta^e Q^(1/q) are
evaluated as balls, and a candidate is accepted only when it is the unique one
whose ball overlaps the ball of the resolvent (which is computed independently
from the exact coordinates).  All identities between coordinate vectors are
exact; the final expression is checked again by ball arithmetic against all
conjugates of a (verify_numeric).  An exact symbolic verification in a Wolfram
kernel is provided by verify_wolfram.py.

Nonsolvability is proved by Frobenius cycle types (prime degree n: a solvable
transitive group of prime degree lies in AGL(1, n), whose elements have cycle
types 1^n, n, or 1 d^((n-1)/d)) or by the exact Galois group.

Requires python-flint >= 0.8, SymPy >= 1.14 and rootdecomp.py from the
sibling project root-decomposition/python (located automatically).
"""

from __future__ import annotations

import itertools
import math
import os
import sys
import time
from dataclasses import dataclass, field
from fractions import Fraction
from typing import Optional

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "root-decomposition", "python"))

import sympy as sp
from flint import acb, acb_poly, arb, ctx, fmpq, fmpq_mat, fmpz_poly, nmod_poly

import rootdecomp as rd
from rootdecomp import AlgebraicNumber, PrecisionError

X = sp.Symbol("x")
T = sp.Symbol("t")


class NotSolvable(Exception):
    """The Galois group of the minimal polynomial is not solvable."""


class NotFound(Exception):
    """The structural recognizers found nothing (Galois route disabled)."""


class ResourceLimit(Exception):
    """The Galois group is larger than the requested limit."""


class DescentError(Exception):
    """Internal inconsistency in the descent (should not happen)."""


# ---------------------------------------------------------------------------
# radical grammar and ball evaluation
# ---------------------------------------------------------------------------

def is_radical_expression(e) -> bool:
    """True if e is built from rationals, I, +, * and rational powers only."""
    e = sp.sympify(e)
    if e.is_Rational:
        return True
    if e is sp.I:
        return True
    if e.is_Add or e.is_Mul:
        return all(is_radical_expression(t) for t in e.args)
    if e.is_Pow:
        return e.exp.is_Rational and is_radical_expression(e.base)
    return False


def radical_depth(e) -> int:
    e = sp.sympify(e)
    if e.is_Rational or e is sp.I:
        return 0
    if e.is_Pow:
        return radical_depth(e.base) if e.exp.is_Integer else 1 + radical_depth(e.base)
    if e.is_Add or e.is_Mul:
        return max(radical_depth(t) for t in e.args)
    return 0


def leaf_count(e) -> int:
    return sum(1 for _ in sp.preorder_traversal(sp.sympify(e)))


def _ball(e) -> acb:
    if e.is_Rational:
        return acb(int(e.p)) / acb(int(e.q))
    if e is sp.I:
        return acb(0, 1)
    if e.is_Add:
        s = acb(0)
        for t in e.args:
            s += _ball(t)
        return s
    if e.is_Mul:
        s = acb(1)
        for t in e.args:
            s *= _ball(t)
        return s
    if e.is_Pow:
        b = _ball(e.base)
        ex = e.exp
        if ex.is_Integer:
            return b ** int(ex)
        if ex.is_Rational:
            return b ** (acb(int(ex.p)) / acb(int(ex.q)))   # principal branch, as in Mathematica
    raise ValueError(f"not a radical expression: {e}")


def ball(e, prec_bits: int) -> acb:
    """Rigorous enclosure of the radical expression e (principal branches)."""
    with ctx.workprec(prec_bits):
        return _ball(sp.sympify(e))


def select_candidate(cands: list, target, prec_bits: int, max_attempts: int = 4):
    """The unique candidate whose ball overlaps the ball of the target.

    target is a callable prec -> acb (an independent enclosure of the value that
    is known to equal exactly one candidate).  Rigorous: the true candidate's
    ball always overlaps the target ball, so uniqueness identifies it.
    """
    prec = prec_bits
    for _ in range(max_attempts):
        tb = target(prec)
        matches = [i for i, c in enumerate(cands) if ball(c, prec).overlaps(tb)]
        if len(matches) == 1:
            return cands[matches[0]]
        if not matches:
            raise DescentError("no candidate matches the target")
        prec *= 2
    raise PrecisionError("candidates not separated at the working precision")


# ---------------------------------------------------------------------------
# principal roots of exactly real negative radicands
#
# A radicand that is exactly real but written as a sum of complex conjugate
# terms has a ball straddling the negative real axis, where the principal
# branch is discontinuous, and no precision separates the candidates.  When
# the exact data prove that the radicand E is real and negative, the principal
# root is written as (-1)^(1/q) (-E)^(1/q), whose ball evaluation is tight.
# ---------------------------------------------------------------------------

def principal_root(E, q: int, real_negative: bool):
    if q == 2:
        return sp.I * sp.sqrt(sp.expand(-E)) if real_negative else sp.sqrt(E)
    if real_negative:
        return sp.Pow(-1, sp.Rational(1, q)) * sp.Pow(sp.expand(-E), sp.Rational(1, q))
    return sp.Pow(E, sp.Rational(1, q))


def is_real_algebraic(a: AlgebraicNumber, prec_bits: int = 200) -> bool:
    """Rigorous: a real root is the unique root overlapping its own conjugate."""
    roots = rd.poly_roots(a.poly, prec_bits)
    z = roots[a.index - 1]
    return [j for j, w in enumerate(roots) if w.overlaps(z.conjugate())] == [a.index - 1]


def is_negative_real(a: AlgebraicNumber, prec_bits: int = 200) -> bool:
    if a.degree == 1:
        return a.as_fraction() < 0
    if not is_real_algebraic(a, prec_bits):
        return False
    prec = prec_bits
    for _ in range(4):
        z = a.value(prec)
        if z.real < 0:
            return True
        if z.real > 0:
            return False
        prec *= 2
    raise PrecisionError("sign of a real algebraic number not determined")


# ---------------------------------------------------------------------------
# polynomial helpers
# ---------------------------------------------------------------------------

def sympy_poly(p: fmpz_poly, var=X):
    return sum(int(c) * var ** i for i, c in enumerate(p.coeffs()))


def fmpz_poly_of(expr, var=X) -> fmpz_poly:
    """Primitive integer polynomial proportional to a rational polynomial expression."""
    P = sp.Poly(sp.expand(expr), var)
    coeffs = [Fraction(int(c.p), int(c.q)) for c in reversed(P.all_coeffs())]
    return rd.poly_from_fractions(coeffs)


def _eval_rational_poly(expr, z: acb) -> acb:
    """Exact-coefficient evaluation of a rational polynomial expression in X at the ball z."""
    P = sp.Poly(sp.expand(sp.sympify(expr)), X)
    acc = acb(0)
    for c in P.all_coeffs():            # high to low (Horner)
        acc = acc * z + acb(int(c.p)) / acb(int(c.q))
    return acc


def algebraic_of_rational_function(num, den, a: AlgebraicNumber, prec_bits: int = 300) -> AlgebraicNumber:
    """The exact algebraic number num(a)/den(a) for polynomials num, den in X with rational coefficients."""
    pt = sympy_poly(a.poly, T)
    numt, dent = sp.sympify(num).subs(X, T), sp.sympify(den).subs(X, T)
    res = sp.resultant(pt, sp.expand(X * dent - numt), T)
    r = fmpz_poly_of(res)
    prec = prec_bits
    for _ in range(6):
        try:
            with ctx.workprec(prec):
                z = a.value(prec)
                val = _eval_rational_poly(num, z) / _eval_rational_poly(den, z)
                # the resultant may be non-squarefree; identify the annihilating factor by a unique zero
                g = rd._matching_factor(r.factor()[1], val)
                return AlgebraicNumber.from_value(g, val, prec)
        except PrecisionError:
            prec *= 2
    raise PrecisionError("algebraic_of_rational_function failed")


def cyclotomic(q: int) -> fmpz_poly:
    return fmpz_poly_of(sp.cyclotomic_poly(q, X))


# ---------------------------------------------------------------------------
# Frobenius negative test (prime degree)
# ---------------------------------------------------------------------------

def _agl1_type(degs: list, n: int) -> bool:
    return degs == [n] or degs == [1] * n or (degs[0] == 1 and len(set(degs[1:])) == 1 and sum(degs) == n)


def _long_prime_cycle(degs: list, n: int) -> bool:
    """A single prime cycle of length > n/2 with the other points fixed: the group is primitive,
    and a solvable primitive group has prime-power degree."""
    m = degs[-1]
    return sp.isprime(m) and 2 * m > n and set(degs[:-1]) == {1}


def _is_prime_power(n: int) -> bool:
    return len(sp.factorint(n)) == 1


def frobenius_nonsolvable(p: fmpz_poly, max_primes: int = 60) -> bool:
    """True if some Frobenius cycle type proves that the Galois group is not solvable.

    Prime degree n: every cycle type must be of the AGL(1, n) shape.  Degree that is
    not a prime power: a long prime cycle is an obstruction.  Composite prime-power
    degrees are left to the exact group computation.
    """
    n = p.degree()
    prime_degree = bool(sp.isprime(n))
    if not prime_degree and _is_prime_power(n):
        return False
    disc = int(p.resultant(p.derivative()))
    lc = int(p.leading_coefficient())
    count, q = 0, 2
    while count < max_primes:
        q = int(sp.nextprime(q))
        if (disc * lc) % q == 0:
            continue
        count += 1
        f = nmod_poly([int(c) for c in p.coeffs()], q).factor()
        degs = sorted(g.degree() for g, _ in f[1] if g.degree() > 0)
        if prime_degree:
            if not _agl1_type(degs, n):
                return True
        elif _long_prime_cycle(degs, n):
            return True
    return False


# ---------------------------------------------------------------------------
# group theory on the multiplication table
# ---------------------------------------------------------------------------

def closure(mt, ident: int, gens) -> list:
    elems = {ident}
    frontier = [ident]
    while frontier:
        nxt = []
        for e in frontier:
            for g in gens:
                h = mt[e][g]
                if h not in elems:
                    elems.add(h)
                    nxt.append(h)
        frontier = nxt
    return sorted(elems)


def inverse(mt, ident: int, g: int) -> int:
    return mt[g].index(ident)


def commutator_subgroup(mt, ident: int, H) -> list:
    comms = set()
    inv = {g: inverse(mt, ident, g) for g in H}
    for g in H:
        for h in H:
            comms.add(mt[mt[inv[g]][inv[h]]][mt[g][h]])
    return closure(mt, ident, sorted(comms))


def is_solvable_group(mt, ident: int, H) -> bool:
    cur = sorted(H)
    while len(cur) > 1:
        nxt = commutator_subgroup(mt, ident, cur)
        if nxt == cur:
            return False
        cur = nxt
    return True


def prime_series(mt, ident: int, H0) -> list:
    """Composition series with prime quotients from H0 down to 1: dicts group, normal, generator, prime."""
    H = sorted(H0)
    steps = []
    while len(H) > 1:
        D = commutator_subgroup(mt, ident, H)
        if D == H:
            raise NotSolvable("not solvable")
        N = D
        for g in H:
            if g not in N:
                J = closure(mt, ident, N + [g])
                if len(J) < len(H):
                    N = J
        p = len(H) // len(N)
        if len(H) % len(N) or not sp.isprime(p):
            raise DescentError("composition factor is not prime")
        sigma = next(g for g in H if g not in N)
        steps.append({"group": H, "normal": N, "generator": sigma, "prime": p})
        H = N
    return steps


# ---------------------------------------------------------------------------
# state of one computation
# ---------------------------------------------------------------------------

@dataclass
class _State:
    method: str = "auto"            # "auto", "structural", "galois"
    resolvents: str = "auto"        # "auto", "fourier", "eigenvector"
    maxorder: int = 400
    prec_bits: int = 300
    method_used: Optional[str] = None
    galois_order: Optional[int] = None
    extended_order: Optional[int] = None
    series_primes: Optional[list] = None
    primes: Optional[list] = None


# ---------------------------------------------------------------------------
# structural layer
# ---------------------------------------------------------------------------

def _value_fn(a: AlgebraicNumber):
    return lambda prec: a.value(prec)


def low_degree_roots(g_expr, rhs=0) -> Optional[list]:
    """Radical roots of g(x) = rhs for deg g <= 4 (SymPy formulas), or None."""
    P = sp.Poly(sp.expand(g_expr - rhs), X)
    if P.degree() > 4:
        return None
    try:
        sols = sp.roots(P, cubics=True, quartics=True, multiple=True)
    except Exception:
        return None
    sols = [s for s in sols if is_radical_expression(s)]
    return sols if len(sols) == P.degree() else None


def solve_with_radical_rhs(g_expr, v, v_exact: AlgebraicNumber, prec_bits: int = 300) -> Optional[list]:
    """Radical solutions of g(x) = v for a rational polynomial g and the radical expression v of the
    exact number v_exact: linear and quadratic g by formulas, binomials x^n + c by n-th roots.
    Cubic and quartic pieces with radical right-hand sides are left to the general descent."""
    P = sp.Poly(sp.expand(g_expr), X)
    n = P.degree()
    coeffs = P.all_coeffs()            # high to low
    lead = coeffs[0]
    if n == 1:
        return [(v - coeffs[1]) / lead]
    if n == 2:
        b, c0 = coeffs[1], coeffs[2]
        D = sp.expand(b ** 2 - 4 * lead * (c0 - v))
        D_exact = algebraic_of_rational_function(sp.expand(b ** 2 - 4 * lead * c0 + 4 * lead * X), 1, v_exact, prec_bits)
        s = principal_root(D, 2, is_negative_real(D_exact))
        return [(-b + s) / (2 * lead), (-b - s) / (2 * lead)]
    if all(c == 0 for c in coeffs[1:-1]):
        c0 = coeffs[-1]
        c = sp.expand((v - c0) / lead)
        c_exact = algebraic_of_rational_function(sp.expand((X - c0) / lead), 1, v_exact, prec_bits)
        root = principal_root(c, n, is_negative_real(c_exact))
        return [sp.Pow(-1, sp.Rational(2 * e, n)) * root for e in range(n)]
    return None


def structural_low_degree(a: AlgebraicNumber, st: _State, depth: int):
    if a.degree > 4:
        return None
    cands = low_degree_roots(sympy_poly(a.poly))
    if cands is None:
        return None
    return select_candidate(cands, _value_fn(a), st.prec_bits)


def structural_decompose(a: AlgebraicNumber, st: _State, depth: int):
    comp = sp.decompose(sympy_poly(a.poly))
    if len(comp) < 2:
        return None
    k = len(comp)
    vals = []
    for i in range(k - 1):
        h = X
        for g in reversed(comp[i + 1:]):
            h = g.subs(X, h)
        vals.append(algebraic_of_rational_function(sp.expand(h), 1, a, st.prec_bits))
    vals.append(a)
    rad = _radicals_of(vals[0], st, depth - 1)
    for i in range(1, k):
        cands = solve_with_radical_rhs(comp[i], rad, vals[i - 1], st.prec_bits)
        if cands is None:
            return None
        rad = select_candidate(cands, _value_fn(vals[i]), st.prec_bits)
    return rad


def _rational_roots(q: Fraction, m: int) -> list:
    r, ok1 = sp.integer_nthroot(abs(q.numerator), m)
    s, ok2 = sp.integer_nthroot(q.denominator, m)
    if not (ok1 and ok2):
        return []
    return [c for c in (Fraction(int(r), int(s)), Fraction(-int(r), int(s))) if c ** m == q]


def reciprocal_decomposition(p: fmpz_poly):
    """(a, P) with p(x) = x^m P(x + a/x) (monic normalization), or None."""
    n = p.degree()
    if n % 2 or n < 4:
        return None
    m = n // 2
    Q = sp.Poly(sympy_poly(p), X).monic()
    c0 = Fraction(int(Q.all_coeffs()[-1].p), int(Q.all_coeffs()[-1].q))
    if c0 == 0:
        return None
    for av in _rational_roots(c0, m):
        rem = Q.as_expr()
        P = 0
        for k in range(m, -1, -1):
            cf = sp.Poly(rem, X).coeff_monomial(X ** (m + k)) if rem != 0 else 0
            P += cf * X ** k
            rem = sp.expand(rem - cf * X ** m * (X + sp.Rational(av.numerator, av.denominator) / X) ** k)
        if rem == 0:
            return av, P
    return None


def structural_reciprocal(a: AlgebraicNumber, st: _State, depth: int):
    rdp = reciprocal_decomposition(a.poly)
    if rdp is None:
        return None
    av, P = rdp
    avs = sp.Rational(av.numerator, av.denominator)
    y = algebraic_of_rational_function(X ** 2 + avs, X, a, st.prec_bits)     # a + av/a, a root of P
    yrad = _radicals_of(y, st, depth - 1)
    D_exact = algebraic_of_rational_function(X ** 2 - 4 * avs, 1, y, st.prec_bits)
    s = principal_root(sp.expand(yrad ** 2 - 4 * avs), 2, is_negative_real(D_exact))
    cands = [(yrad + s) / 2, (yrad - s) / 2]
    return select_candidate(cands, _value_fn(a), st.prec_bits)


def dickson(n: int, av):
    d0, d1 = sp.Integer(2), X
    if n == 0:
        return d0
    for _ in range(n - 1):
        d0, d1 = d1, sp.expand(X * d1 - av * d0)
    return d1


def structural_dickson(a: AlgebraicNumber, st: _State, depth: int):
    n = a.degree
    if n < 3:
        return None
    Q = sp.Poly(sympy_poly(a.poly), X).monic()
    c = -Q.coeff_monomial(X ** (n - 1)) / n
    Q = sp.Poly(sp.expand(Q.as_expr().subs(X, X + c)), X)
    av = -Q.coeff_monomial(X ** (n - 2)) / n
    if av == 0:
        return None
    diff = sp.Poly(sp.expand(Q.as_expr() - dickson(n, av)), X)
    if diff.degree() > 0:
        return None
    b = -diff.as_expr()
    s = (b + sp.sqrt(b ** 2 - 4 * av ** n)) / 2
    t = sp.Pow(s, sp.Rational(1, n))
    zeta = sp.Pow(-1, sp.Rational(2, n))
    cands = [c + zeta ** j * t + av / (zeta ** j * t) for j in range(n)]
    return select_candidate(cands, _value_fn(a), st.prec_bits)


STRUCTURAL_METHODS = [
    ("LowDegree", structural_low_degree),
    ("Decompose", structural_decompose),
    ("Reciprocal", structural_reciprocal),
    ("Dickson", structural_dickson),
]


def _structural(a: AlgebraicNumber, st: _State, depth: int):
    if depth <= 0:
        return None
    for name, fn in STRUCTURAL_METHODS:
        try:
            r = fn(a, st, depth)
        except (PrecisionError, DescentError, NotSolvable, NotFound, ResourceLimit):
            r = None
        if r is not None and is_radical_expression(r):
            st.method_used = name
            return r
    return None


# ---------------------------------------------------------------------------
# general Galois-Kummer descent
# ---------------------------------------------------------------------------

def _apply(M: fmpq_mat, v):
    return rd.apply_matrix(M, v)


def _is_zero(v) -> bool:
    return all(q == 0 for q in v)


def _fixed_by(gd, v, elems) -> bool:
    return all(_apply(gd.automorphisms[s], v) == v for s in elems)


def _vec_add(u, v):
    return [a + b for a, b in zip(u, v)]


def _value_at_identity(gd, v):
    """prec -> ball of the element with coordinates v at the identity embedding"""
    def fn(prec):
        with ctx.workprec(prec):
            if prec <= gd.prec:
                return rd.conj_vector(gd, v)[gd.identity]
            return rd._conj_vector_at(gd, v, prec)[gd.identity]
    return fn


def _rational(q: fmpq):
    return sp.Rational(int(q.p), int(q.q))


def _conjugation_automorphism(gd) -> Optional[int]:
    """Index of the automorphism acting as complex conjugation on the roots, or None."""
    with ctx.workprec(gd.prec):
        perm = []
        for z in gd.roots:
            matches = [j for j, w in enumerate(gd.roots) if w.overlaps(z.conjugate())]
            if len(matches) != 1:
                return None
            perm.append(matches[0])
    perm = tuple(perm)
    for s, p in enumerate(gd.perms):
        if tuple(p) == perm:
            return s
    return None


def _negative_real_element(gd, conj: Optional[int], v) -> bool:
    """Rigorous: v is fixed by complex conjugation and its value is negative."""
    if conj is None or _apply(gd.automorphisms[conj], v) != v:
        return False
    fn = _value_at_identity(gd, v)
    prec = gd.prec
    for _ in range(4):
        z = fn(prec)
        if z.real < 0:
            return True
        if z.real > 0:
            return False
        prec *= 2
    raise PrecisionError("sign of a real element not determined")


def _descend(gd, a: AlgebraicNumber, primes: list, st: _State):
    """The descent on the Galois data of p(x) prod Phi_q(x); may raise PrecisionError."""
    order = gd.order
    c = gd.scale
    target = rd.locate_target(gd, a)
    va = [q / c for q in gd.root_coords[target]]
    zeta_idx = {}
    with ctx.workprec(gd.prec):
        for q in primes:
            z = acb(c) * (acb(0, 2) * acb(arb.pi()) / acb(q)).exp()
            matches = [i for i, r in enumerate(gd.roots) if r.overlaps(z)]
            if len(matches) != 1:
                raise PrecisionError("root of unity not uniquely located")
            zeta_idx[q] = matches[0]
        zeta_coord = {q: [v / c for v in gd.root_coords[i]] for q, i in zeta_idx.items()}
        zeta_mult = {q: rd.multiplication_matrix_of(gd, zeta_coord[q]) for q in primes}
    conj = _conjugation_automorphism(gd)
    H = [s for s in range(order) if all(gd.perms[s][i] == i for i in zeta_idx.values())]
    steps = prime_series(gd.mult_table, gd.identity, H)
    one = [fmpq(1)] + [fmpq(0)] * (order - 1)
    base_basis = []
    for exps in itertools.product(*[range(q - 1) for q in primes]):
        sym = sp.Integer(1)
        vec = one
        for q, e in zip(primes, exps):
            sym *= sp.Pow(-1, sp.Rational(2 * e, q))
            for _ in range(e):
                vec = _apply(zeta_mult[q], vec)
        base_basis.append((sym, vec))
    B = fmpq_mat(order, len(base_basis))
    for j, (_, vec) in enumerate(base_basis):
        for i in range(order):
            B[i, j] = vec[i]
    memo = {}

    def rad(v, level):
        key = (tuple(v), level)
        if key not in memo:
            memo[key] = rad_compute(v, level)
        return memo[key]

    def rad_compute(v, level):
        if level == 0:
            sol = rd.fmpq_solve(B, v)
            if sol is None:
                raise DescentError("element not in the base cyclotomic field")
            return sp.expand(sum(_rational(s) * sym for s, (sym, _) in zip(sol, base_basis)))
        if _is_zero(v):
            return sp.Integer(0)
        step = steps[level - 1]
        M, sigma, q = step["group"], step["generator"], step["prime"]
        if _fixed_by(gd, v, M):
            return rad(v, level - 1)
        with ctx.workprec(gd.prec):
            aut = gd.automorphisms[sigma]
            if q == 2:
                zm = -fmpq_mat(order, order)
                for i in range(order):
                    zm[i, i] = -1
            else:
                zm = zeta_mult[q]
            sv = [v]
            for _ in range(q - 1):
                sv.append(_apply(aut, sv[-1]))
            zpows = [zm ** j for j in range(q)]
            R = []
            for k in range(q):
                acc = [fmpq(0)] * order
                for j in range(q):
                    acc = _vec_add(acc, _apply(zpows[(-k * j) % q], sv[j]))
                R.append(acc)
            zsym = sp.Integer(-1) if q == 2 else sp.Pow(-1, sp.Rational(2, q))

            def branch(Rk):
                Mk = rd.multiplication_matrix_of(gd, Rk)
                Qk = _apply(Mk ** (q - 1), Rk)
                qrad = rad(Qk, level - 1)
                root = principal_root(qrad, q, _negative_real_element(gd, conj, Qk))
                cands = [zsym ** e * root for e in range(q)]
                return select_candidate(cands, _value_at_identity(gd, Rk), gd.prec)

            R0 = rad(R[0], level - 1)
            choices = []
            if st.resolvents != "eigenvector" or q == 2:
                total = R0
                for k in range(1, q):
                    if not _is_zero(R[k]):
                        total = total + branch(R[k])
                choices.append(total / q)
            if st.resolvents != "fourier" and q > 2:
                k1 = next(k for k in range(1, q) if not _is_zero(R[k]))
                u = branch(R[k1])
                total = R0 + u
                Mk1 = rd.multiplication_matrix_of(gd, R[k1])
                for k in range(1, q):
                    if k == k1 or _is_zero(R[k]):
                        continue
                    m = (k * pow(k1, -1, q)) % q
                    ck = rd.fmpq_solve(Mk1 ** m, R[k])
                    if ck is None or not _fixed_by(gd, ck, M):
                        raise DescentError("eigenvector ratio is not in the lower field")
                    total = total + rad(ck, level - 1) * u ** m
                choices.append(total / q)
            return min(choices, key=leaf_count)

    expr = rad(va, len(steps))
    return expr, order, [s["prime"] for s in steps]


def _galois_radicals(a: AlgebraicNumber, st: _State):
    p = a.poly
    try:
        gd0 = rd.galois_data(p, st.prec_bits, st.maxorder)
    except ValueError as e:
        raise ResourceLimit(str(e)) from None
    st.galois_order = gd0.order
    if not is_solvable_group(gd0.mult_table, gd0.identity, range(gd0.order)):
        raise NotSolvable(f"Galois group of order {gd0.order} is not solvable")
    primes = sorted(q for q in sp.factorint(gd0.order) if q % 2)
    poly = p
    for q in primes:
        cq = cyclotomic(q)
        if poly.gcd(cq).degree() == 0:
            poly = poly * cq
    prec = st.prec_bits
    for attempt in range(3):
        try:
            if primes:
                try:
                    gd = rd.galois_data(poly, prec, st.maxorder * math.prod(q - 1 for q in primes))
                except ValueError as e:
                    raise ResourceLimit(str(e)) from None
            else:
                gd = gd0 if prec == st.prec_bits else rd.galois_data(p, prec, st.maxorder)
            expr, ext_order, series = _descend(gd, a, primes, st)
            st.extended_order, st.series_primes, st.primes = ext_order, series, primes
            st.method_used = "Galois"
            return expr
        except PrecisionError:
            prec *= 2
    raise PrecisionError("precision escalation failed in the descent")


# ---------------------------------------------------------------------------
# driver
# ---------------------------------------------------------------------------

def _radicals_of(a: AlgebraicNumber, st: _State, depth: int):
    if a.degree == 1:
        f = a.as_fraction()
        return sp.Rational(f.numerator, f.denominator)
    if st.method != "galois":
        r = _structural(a, st, depth)
        if r is not None:
            return r
    if st.method == "structural":
        raise NotFound("no structural radical form was found")
    if frobenius_nonsolvable(a.poly):
        st.method_used = "Frobenius"
        raise NotSolvable("Frobenius cycle type outside AGL(1, n): not solvable")
    return _galois_radicals(a, st)


@dataclass
class RadicalResult:
    expression: sp.Expr
    method: str
    verified: bool
    degree: int
    galois_order: Optional[int] = None
    extended_order: Optional[int] = None
    series_primes: Optional[list] = None
    time: float = 0.0

    @property
    def radical_depth(self) -> int:
        return radical_depth(self.expression)

    @property
    def leaf_count(self) -> int:
        return leaf_count(self.expression)

    def wolfram(self) -> str:
        return sp.mathematica_code(self.expression)

    def __repr__(self):
        return (f"RadicalResult({self.expression}; method={self.method}, verified={self.verified}, "
                f"degree={self.degree}, depth={self.radical_depth}, leaves={self.leaf_count}, "
                f"galois_order={self.galois_order}, time={self.time:.2f}s)")


def verify_numeric(expr, a: AlgebraicNumber, prec_bits: int = 300) -> bool:
    """Rigorous ball check: the expression encloses a and no other conjugate of a."""
    prec = prec_bits
    for _ in range(4):
        with ctx.workprec(prec):
            z = ball(expr, prec)
            roots = rd.poly_roots(a.poly, prec)
            matches = [i for i, r in enumerate(roots) if r.overlaps(z)]
        if len(matches) == 1:
            return matches[0] == a.index - 1
        if not matches:
            return False
        prec *= 2
    raise PrecisionError("verification inconclusive")


def _as_algebraic(a) -> AlgebraicNumber:
    if isinstance(a, AlgebraicNumber):
        return a
    if isinstance(a, str):
        return rd.parse_wolfram_root(a)
    return AlgebraicNumber.from_rational(Fraction(a))


def root_to_radicals(a, method: str = "auto", resolvents: str = "auto", maxorder: int = 400,
                     prec_bits: int = 300, max_depth: int = 6) -> RadicalResult:
    """Radical expression for the algebraic number a (AlgebraicNumber, Wolfram Root string or rational).

    method: "auto" (structural recognizers, then the general descent), "structural", "galois".
    resolvents: "auto", "fourier", "eigenvector".
    Raises NotSolvable, NotFound (method="structural"), ResourceLimit, PrecisionError.
    """
    if method not in ("auto", "structural", "galois"):
        raise ValueError("method must be 'auto', 'structural' or 'galois'")
    if resolvents not in ("auto", "fourier", "eigenvector"):
        raise ValueError("resolvents must be 'auto', 'fourier' or 'eigenvector'")
    if not (isinstance(maxorder, int) and maxorder > 0 and isinstance(prec_bits, int) and prec_bits >= 64
            and isinstance(max_depth, int) and max_depth > 0):
        raise ValueError("invalid resource options")
    a = _as_algebraic(a)
    t0 = time.perf_counter()
    st = _State(method=method, resolvents=resolvents, maxorder=maxorder, prec_bits=prec_bits)
    expr = _radicals_of(a, st, max_depth)
    if not is_radical_expression(expr):
        raise DescentError("the result is not a radical expression")
    ok = verify_numeric(expr, a, prec_bits)
    return RadicalResult(expression=expr, method=st.method_used or "Rational", verified=ok, degree=a.degree,
                         galois_order=st.galois_order, extended_order=st.extended_order,
                         series_primes=st.series_primes, time=time.perf_counter() - t0)


def is_solvable(a, maxorder: int = 400, prec_bits: int = 300) -> bool:
    """Solvability of the Galois group of the minimal polynomial of a."""
    a = _as_algebraic(a)
    if a.degree <= 4:
        return True
    if frobenius_nonsolvable(a.poly):
        return False
    try:
        gd = rd.galois_data(a.poly, prec_bits, maxorder)
    except ValueError as e:
        raise ResourceLimit(str(e)) from None
    return is_solvable_group(gd.mult_table, gd.identity, range(gd.order))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python roottoradicals.py \"Root[poly &, k]\" [auto|structural|galois]")
        sys.exit(2)
    meth = sys.argv[2] if len(sys.argv) > 2 else "auto"
    try:
        res = root_to_radicals(sys.argv[1], method=meth)
        print(res)
        print("Wolfram:", res.wolfram())
    except NotSolvable as e:
        print("not solvable:", e)
        sys.exit(1)
