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
from the exact coordinates).  A radicand that is exactly real and negative but
written as a sum of complex conjugate terms has a ball straddling the branch
cut; such radicands are recognized from the exact data and their principal
root is written as (-1)^(1/q) (-Q)^(1/q).  All identities between coordinate
vectors are exact; the final expression is checked again by ball arithmetic
against all conjugates of a (verify_numeric).  An exact symbolic verification
in a Wolfram kernel is provided by verify_wolfram.py.

Nonsolvability is proved by Frobenius cycle types (prime degree n: cycle types
outside AGL(1, n); other degrees: a single prime cycle longer than n/2, which
forces primitivity and is excluded for solvable groups unless the degree is a
prime power and the cycle has length n - 1) or by the exact Galois group.  The
lcm of the Frobenius element orders divides |G| and gives an early
ResourceLimit for large groups.

Requires python-flint >= 0.8, SymPy >= 1.14 and rootdecomp.py from the
sibling project root-decomposition/python (located automatically).
"""

from __future__ import annotations

import math
import os
import sys
import time
from dataclasses import dataclass
from fractions import Fraction
from functools import cache
from typing import Callable, Optional

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "root-decomposition", "python"))

import sympy as sp
from flint import acb, acb_poly, arb, ctx, fmpq, fmpq_mat, fmpq_poly, fmpz_poly

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
    if e.is_Rational or e is sp.I:
        return True
    if e.is_Add or e.is_Mul:
        return all(is_radical_expression(t) for t in e.args)
    return bool(e.is_Pow and e.exp.is_Rational and is_radical_expression(e.base))


def radical_depth(e) -> int:
    e = sp.sympify(e)
    if e.is_Pow:
        return radical_depth(e.base) + (0 if e.exp.is_Integer else 1)
    if e.is_Add or e.is_Mul:
        return max(radical_depth(t) for t in e.args)
    return 0


def leaf_count(e) -> int:
    return sum(1 for _ in sp.preorder_traversal(sp.sympify(e)))


def _rational_acb(p, q) -> acb:
    return acb(int(p)) / acb(int(q))


def _ball(e) -> acb:
    if e.is_Rational:
        return _rational_acb(e.p, e.q)
    if e is sp.I:
        return acb(0, 1)
    if e.is_Add:
        return sum((_ball(t) for t in e.args), acb(0))
    if e.is_Mul:
        return math.prod((_ball(t) for t in e.args), start=acb(1))
    if e.is_Pow and e.exp.is_Rational:
        b = _ball(e.base)
        return b ** int(e.exp) if e.exp.is_Integer else b ** _rational_acb(e.exp.p, e.exp.q)   # principal branch
    raise ValueError(f"not a radical expression: {e}")


def ball(e, prec_bits: int) -> acb:
    """Rigorous enclosure of the radical expression e (principal branches)."""
    with ctx.workprec(prec_bits):
        return _ball(sp.sympify(e))


def _escalate(fn: Callable[[int], object], prec_bits: int, attempts: int = 4, what: str = "precision"):
    """Call fn(prec) with doubling precision until it returns something other than None."""
    prec = prec_bits
    for _ in range(attempts):
        r = fn(prec)
        if r is not None:
            return r
        prec *= 2
    raise PrecisionError(f"{what} not decided at the working precision")


def select_candidate(cands: list, target: Callable[[int], acb], prec_bits: int):
    """The unique candidate whose ball overlaps the ball of the target (a callable prec -> acb giving an
    independent enclosure of a value known to equal exactly one candidate).  Rigorous: the true
    candidate's ball always overlaps the target ball, so uniqueness identifies it."""
    def attempt(prec):
        tb = target(prec)
        matches = [c for c in cands if ball(c, prec).overlaps(tb)]
        if not matches:
            raise DescentError("no candidate matches the target")
        return matches[0] if len(matches) == 1 else None
    return _escalate(attempt, prec_bits, what="candidates")


def _sign_negative(value: Callable[[int], acb], prec_bits: int) -> bool:
    """Rigorous sign of a real number given by an enclosure at any precision."""
    def attempt(prec):
        z = value(prec)
        return True if z.real < 0 else False if z.real > 0 else None
    return _escalate(attempt, prec_bits, what="sign")


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
    return is_real_algebraic(a, prec_bits) and _sign_negative(a.value, prec_bits)


# ---------------------------------------------------------------------------
# polynomial helpers
# ---------------------------------------------------------------------------

def sympy_poly(p, var=X):
    return sum(sp.Rational(c) * var ** i for i, c in enumerate(p.coeffs()))


def _rational_poly(expr, var=X) -> fmpq_poly:
    return fmpq_poly([fmpq(int(c.p), int(c.q)) for c in reversed(sp.Poly(expr, var).all_coeffs())])


def fmpz_poly_of(expr, var=X) -> fmpz_poly:
    """Primitive integer polynomial proportional to a rational polynomial expression."""
    return rd.primitive(_rational_poly(expr, var).numer())


def algebraic_of_rational_function(num, den, a: AlgebraicNumber, prec_bits: int = 300) -> AlgebraicNumber:
    """The exact algebraic number num(a)/den(a) for polynomials num, den in X with rational coefficients:
    a resultant gives an annihilating polynomial, whose factor vanishing at the value is identified."""
    num, den = sp.sympify(num), sp.sympify(den)
    r = fmpz_poly_of(sp.resultant(sympy_poly(a.poly, T), sp.expand(X * den.subs(X, T) - num.subs(X, T)), T))
    factors = r.factor()[1]
    num_poly, den_poly = map(_rational_poly, (num, den))

    def attempt(prec):
        with ctx.workprec(prec):
            z = a.value(prec)
            val = acb_poly(num_poly)(z) / acb_poly(den_poly)(z)
            try:
                return AlgebraicNumber.from_value(rd._matching_factor(factors, val), val, prec)
            except PrecisionError:
                return None
    return _escalate(attempt, prec_bits, attempts=6, what="algebraic value")


def cyclotomic(q: int) -> fmpz_poly:
    return fmpz_poly_of(sp.cyclotomic_poly(q, X))


# ---------------------------------------------------------------------------
# Frobenius negative tests
# ---------------------------------------------------------------------------

def _is_prime_power(n: int) -> bool:
    return len(sp.factorint(n)) == 1


def _agl1_type(degs: list, n: int) -> bool:
    return degs == [n] or degs == [1] * n or (degs[0] == 1 and len(set(degs[1:])) == 1)


def _single_prime_cycle(degs: list, n: int) -> bool:
    """A single prime cycle of length l > n/2 (the rest fixed) makes a transitive group primitive; a
    solvable primitive group has prime-power degree n = p^k and lies in AGL(k, p), where an element
    fixing a point is conjugate into GL(k, p) with a subspace of fixed points, so p^k - p^j = l forces
    l = n - 1.  Such a cycle therefore proves nonsolvability unless n is a prime power and l = n - 1."""
    l = degs[-1]
    return bool(sp.isprime(l) and 2 * l > n and set(degs[:-1]) == {1} and not (_is_prime_power(n) and l == n - 1))


def frobenius_cycle_types(p: fmpz_poly, max_primes: int):
    """Cycle types at the first max_primes good odd primes."""
    yield from rd.frobenius_cycle_types(p, max_primes, start_prime=3)


def frobenius_nonsolvable(p: fmpz_poly, max_primes: int = 60) -> bool:
    """True if some Frobenius cycle type proves that the Galois group is not solvable (inconclusive otherwise)."""
    n = p.degree()
    bad = (lambda degs: not _agl1_type(degs, n)) if sp.isprime(n) else (lambda degs: _single_prime_cycle(degs, n))
    return any(bad(degs) for degs in frobenius_cycle_types(p, max_primes))


def frobenius_reason(n: int) -> str:
    if sp.isprime(n):
        return "cycle type outside AGL(1, n)"
    if _is_prime_power(n):
        return "a long prime cycle that no affine group of this degree contains"
    return "a long prime cycle in a non-prime-power degree"


def frobenius_order_multiple(p: fmpz_poly) -> int:
    """The lcm of the orders of the Frobenius elements found; it divides |G|."""
    return rd.frobenius_exponent_multiple(p, 40)


def _check_order_limit(p: fmpz_poly, maxorder: int):
    mult = frobenius_order_multiple(p)
    if mult > maxorder:
        raise ResourceLimit(f"a divisor {mult} of the Galois group order exceeds maxorder={maxorder}")


def _galois_data(p: fmpz_poly, prec_bits: int, maxorder: int):
    try:
        return rd.galois_data(p, prec_bits, maxorder)
    except ValueError as e:
        raise ResourceLimit(str(e)) from None


# ---------------------------------------------------------------------------
# group theory on the multiplication table
# ---------------------------------------------------------------------------

def closure(mt, ident: int, gens) -> list:
    return sorted(rd.group_closure(mt, ident, gens))


def commutator_subgroup(mt, ident: int, H) -> list:
    inv = {g: mt[g].index(ident) for g in H}
    return closure(mt, ident, sorted({mt[mt[inv[g]][inv[h]]][mt[g][h]] for g in H for h in H}))


def is_solvable_group(mt, ident: int, H) -> bool:
    cur = sorted(H)
    while len(cur) > 1:
        nxt = commutator_subgroup(mt, ident, cur)
        if nxt == cur:
            return False
        cur = nxt
    return True


def prime_series(mt, ident: int, H0) -> list:
    """Composition series with prime quotients from H0 down to 1: at each step a normal subgroup of prime
    index containing the commutator subgroup (enlarged while staying proper)."""
    H, steps = sorted(H0), []
    while len(H) > 1:
        N = commutator_subgroup(mt, ident, H)
        if N == H:
            raise NotSolvable("not solvable")
        for g in H:
            if g not in N:
                J = closure(mt, ident, N + [g])
                if len(J) < len(H):
                    N = J
        p = len(H) // len(N)
        if len(H) % len(N) or not sp.isprime(p):
            raise DescentError("composition factor is not prime")
        steps.append({"group": H, "normal": N, "generator": next(g for g in H if g not in N), "prime": p})
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

    def pick(self, cands: list, target: AlgebraicNumber):
        """the candidate equal to the exact number target"""
        return select_candidate(cands, target.value, self.prec_bits)

    def sub(self, a: AlgebraicNumber, depth: int):
        """radical expression of a smaller piece"""
        return _radicals_of(a, self, depth)


# ---------------------------------------------------------------------------
# structural layer
# ---------------------------------------------------------------------------

def low_degree_roots(g_expr, rhs=0) -> Optional[list]:
    """Radical roots of g(x) = rhs for deg g <= 4 (SymPy formulas), or None."""
    P = sp.Poly(sp.expand(g_expr - rhs), X)
    if P.degree() > 4:
        return None
    try:
        sols = [s for s in sp.roots(P, cubics=True, quartics=True, multiple=True) if is_radical_expression(s)]
    except Exception:
        return None
    return sols if len(sols) == P.degree() else None


def solve_with_radical_rhs(g_expr, v, v_exact: AlgebraicNumber, prec_bits: int = 300) -> Optional[list]:
    """Radical solutions of g(x) = v for a rational polynomial g and the radical expression v of the
    exact number v_exact: linear and quadratic g by formulas, binomials x^n + c by n-th roots.
    Cubic and quartic pieces with radical right-hand sides are left to the general descent."""
    coeffs = sp.Poly(sp.expand(g_expr), X).all_coeffs()            # high to low
    n, lead, c0 = len(coeffs) - 1, coeffs[0], coeffs[-1]

    def exact(expr):     # exact value of a rational polynomial expression in v
        return algebraic_of_rational_function(sp.expand(expr), 1, v_exact, prec_bits)

    if n == 1:
        return [(v - c0) / lead]
    if n == 2:
        b = coeffs[1]
        s = principal_root(sp.expand(b ** 2 - 4 * lead * (c0 - v)), 2, is_negative_real(exact(b ** 2 - 4 * lead * (c0 - X))))
        return [(-b + s) / (2 * lead), (-b - s) / (2 * lead)]
    if all(c == 0 for c in coeffs[1:-1]):
        root = principal_root(sp.expand((v - c0) / lead), n, is_negative_real(exact((X - c0) / lead)))
        return [sp.Pow(-1, sp.Rational(2 * e, n)) * root for e in range(n)]
    return None


def structural_low_degree(a: AlgebraicNumber, st: _State, depth: int):
    cands = low_degree_roots(sympy_poly(a.poly)) if a.degree <= 4 else None
    return None if cands is None else st.pick(cands, a)


def structural_decompose(a: AlgebraicNumber, st: _State, depth: int):
    comp = sp.decompose(sympy_poly(a.poly))          # outer piece first
    if len(comp) < 2:
        return None
    vals = [a]                                      # each component acts on the preceding, smaller-degree value
    for g in reversed(comp[1:]):
        vals.append(algebraic_of_rational_function(g, 1, vals[-1], st.prec_bits))
    vals.reverse()
    rad = st.sub(vals[0], depth - 1)
    for i in range(1, len(comp)):
        cands = solve_with_radical_rhs(comp[i], rad, vals[i - 1], st.prec_bits)
        if cands is None:
            return None
        rad = st.pick(cands, vals[i])
    return rad


def _rational_roots(q: Fraction, m: int) -> list:
    r, ok1 = sp.integer_nthroot(abs(q.numerator), m)
    s, ok2 = sp.integer_nthroot(q.denominator, m)
    if not (ok1 and ok2):
        return []
    return [c for c in (Fraction(int(r), int(s)), Fraction(-int(r), int(s))) if c ** m == q]


def reciprocal_decomposition(p: fmpz_poly):
    """(c, P) with p(x) = x^m P(x + c/x) (monic normalization), or None; c^m is the constant term."""
    n = p.degree()
    if n % 2 or n < 4:
        return None
    m = n // 2
    Q = fmpq_poly(p) / p.leading_coefficient()
    c0 = Q[0]
    for c in _rational_roots(Fraction(int(c0.p), int(c0.q)), m):
        cs = fmpq(c.numerator, c.denominator)
        rem, P = fmpq_poly(Q), fmpq_poly()
        for k in range(m, -1, -1):
            P[k] = rem[m + k]
            rem -= P[k] * (fmpq_poly([cs, 0, 1]) ** k).left_shift(m - k)
        if not rem:
            return sp.Rational(cs), sympy_poly(P)
    return None


def structural_reciprocal(a: AlgebraicNumber, st: _State, depth: int):
    rdp = reciprocal_decomposition(a.poly)
    if rdp is None:
        return None
    c = rdp[0]
    y = algebraic_of_rational_function(X ** 2 + c, X, a, st.prec_bits)     # a + c/a, a root of P
    yrad = st.sub(y, depth - 1)
    s = principal_root(sp.expand(yrad ** 2 - 4 * c), 2,
                       is_negative_real(algebraic_of_rational_function(X ** 2 - 4 * c, 1, y, st.prec_bits)))
    return st.pick([(yrad + s) / 2, (yrad - s) / 2], a)


def dickson(n: int, c):
    d0, d1 = sp.Integer(2), X
    for _ in range(n - 1):
        d0, d1 = d1, sp.expand(X * d1 - c * d0)
    return d0 if n == 0 else d1


def structural_dickson(a: AlgebraicNumber, st: _State, depth: int):
    n = a.degree
    if n < 3:
        return None
    Q = sp.Poly(sympy_poly(a.poly), X).monic()
    t = -Q.coeff_monomial(X ** (n - 1)) / n
    Q = sp.Poly(sp.expand(Q.as_expr().subs(X, X + t)), X)
    c = -Q.coeff_monomial(X ** (n - 2)) / n
    diff = sp.Poly(sp.expand(Q.as_expr() - dickson(n, c)), X)
    if c == 0 or diff.degree() > 0:
        return None
    b = -diff.as_expr()
    u = sp.Pow((b + sp.sqrt(b ** 2 - 4 * c ** n)) / 2, sp.Rational(1, n))
    zeta = sp.Pow(-1, sp.Rational(2, n))
    return st.pick([t + zeta ** j * u + c / (zeta ** j * u) for j in range(n)], a)


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

_apply = rd.apply_matrix


def _iterate(M: fmpq_mat, v, times: int) -> list:
    """[v, M v, M^2 v, ..., M^times v]"""
    out = [v]
    for _ in range(times):
        out.append(_apply(M, out[-1]))
    return out


def _fixed_by(gd, v, elems) -> bool:
    return all(_apply(gd.automorphisms[s], v) == v for s in elems)


def _value_at_identity(gd, v) -> Callable[[int], acb]:
    """prec -> ball of the element with coordinates v at the identity embedding"""
    def fn(prec):
        with ctx.workprec(prec):
            if prec > gd.prec:
                return rd._conj_vector_at(gd, v, prec)[gd.identity]
            return sum((gd.values[gd.identity, j] * rd._fmpq_to_acb(fmpq(q))
                        for j, q in enumerate(v) if q), acb(0))
    return fn


def _cache_by_coordinates(fn):
    """Memoize a local field computation, treating coordinate lists and tuples alike."""
    @cache
    def cached(v, *args):
        return fn(list(v), *args)
    return lambda v, *args: cached(tuple(v), *args)


def _conjugation_automorphism(gd) -> Optional[int]:
    """Index of the automorphism acting as complex conjugation on the roots, or None."""
    perm = []
    with ctx.workprec(gd.prec):
        for z in gd.roots:
            matches = [j for j, w in enumerate(gd.roots) if w.overlaps(z.conjugate())]
            if len(matches) != 1:
                return None
            perm.append(matches[0])
    return next((s for s, p in enumerate(gd.perms) if list(p) == perm), None)


def _negative_real_element(gd, conj: Optional[int], v) -> bool:
    """Rigorous: v is fixed by complex conjugation and its value is negative."""
    return conj is not None and _apply(gd.automorphisms[conj], v) == v and _sign_negative(_value_at_identity(gd, v), gd.prec)


def _descend(gd, a: AlgebraicNumber, primes: list, st: _State):
    """The descent on the Galois data of p(x) prod Phi_q(x); may raise PrecisionError."""
    order, c = gd.order, gd.scale
    va = [q / c for q in gd.root_coords[rd.locate_target(gd, a)]]
    # roots of unity zeta_q = exp(2 pi i/q) among the (scaled) roots, as multiplication matrices and as
    # radical symbols; zeta_2 = -1 is handled by the same tables
    zeta_idx, zeta_mult = {}, {}
    with ctx.workprec(gd.prec):
        for q in primes:
            z = acb(c) * (acb(0, 2) * acb(arb.pi()) / acb(q)).exp()
            matches = [i for i, r in enumerate(gd.roots) if r.overlaps(z)]
            if len(matches) != 1:
                raise PrecisionError("root of unity not uniquely located")
            zeta_idx[q] = matches[0]
            zeta_mult[q] = rd.multiplication_matrix_of(gd, [v / c for v in gd.root_coords[matches[0]]])
    zeta_mult[2] = fmpq_mat(order, order)
    for i in range(order):
        zeta_mult[2][i, i] = -1
    zeta_sym = {q: sp.Pow(-1, sp.Rational(2, q)) for q in primes}
    zeta_sym[2] = sp.Integer(-1)
    conj = _conjugation_automorphism(gd)
    H = [s for s in range(order) if all(gd.perms[s][i] == i for i in zeta_idx.values())]
    steps = prime_series(gd.mult_table, gd.identity, H)
    # basis of Q(zeta_m): monomials prod zeta_q^e_q, 0 <= e_q <= q-2, as symbols and as coordinate vectors
    one = [fmpq(1)] + [fmpq(0)] * (order - 1)
    base_basis = [(sp.Integer(1), one)]
    for q in primes:
        base_basis = [(sym * zeta_sym[q] ** e, w) for sym, v in base_basis
                      for e, w in enumerate(_iterate(zeta_mult[q], v, q - 2))]
    B = rd._col_matrix([vec for _, vec in base_basis], order)

    @_cache_by_coordinates
    def branch(Rk, q, level):
        """the q-th root of Rk^q (one level down) with the branch equal to Rk"""
        Qk = rd.power_coordinates(gd, Rk, q)
        root = principal_root(rad(Qk, level - 1), q, _negative_real_element(gd, conj, Qk))
        return select_candidate([zeta_sym[q] ** e * root for e in range(q)], _value_at_identity(gd, Rk), gd.prec)

    @_cache_by_coordinates
    def rad(v, level):
        if level == 0:                                   # the element lies in Q(zeta_m)
            sol = rd.fmpq_solve(B, v)
            if sol is None:
                raise DescentError("element not in the base cyclotomic field")
            return sp.expand(sum(sp.Rational(s) * sym for s, (sym, _) in zip(sol, base_basis)))
        if not any(v):
            return sp.Integer(0)
        step = steps[level - 1]
        generators, q = [s["generator"] for s in steps[level - 1:]], step["prime"]
        if _fixed_by(gd, v, generators):
            return rad(v, level - 1)
        with ctx.workprec(gd.prec):
            # zw[j][e] = zeta^e sigma^j(v): q^2 matrix-vector products instead of matrix powers
            zw = [_iterate(zeta_mult[q], w, q - 1) for w in _iterate(gd.automorphisms[step["generator"]], v, q - 1)]
            R = [[sum(zw[j][(-k * j) % q][i] for j in range(q)) for i in range(order)] for k in range(q)]
            nonzero = [k for k in range(1, q) if any(R[k])]
            R0 = rad(R[0], level - 1)
            choices = []
            if st.resolvents != "eigenvector" or q == 2:
                choices.append((R0 + sum(branch(R[k], q, level) for k in nonzero)) / q)
            if st.resolvents != "fourier" and q > 2:
                k1 = nonzero[0]
                u = branch(R[k1], q, level)
                divide = rd.power_divider(gd, R[k1])
                total = R0 + u
                for k in nonzero[1:]:
                    m = (k * pow(k1, -1, q)) % q
                    ck = divide(R[k], m)                     # c_k = R_k / R_k1^m lies one level down
                    if ck is None or not _fixed_by(gd, ck, generators):
                        raise DescentError("eigenvector ratio is not in the lower field")
                    total += rad(ck, level - 1) * u ** m
                choices.append(total / q)
            return min(choices, key=leaf_count)

    return rad(va, len(steps)), order, [s["prime"] for s in steps]


def _galois_radicals(a: AlgebraicNumber, st: _State):
    p = a.poly
    _check_order_limit(p, st.maxorder)
    gd0 = _galois_data(p, st.prec_bits, st.maxorder)
    st.galois_order = gd0.order
    if not is_solvable_group(gd0.mult_table, gd0.identity, range(gd0.order)):
        raise NotSolvable(f"Galois group of order {gd0.order} is not solvable")
    primes = sorted(q for q in sp.factorint(gd0.order) if q % 2)
    poly = p
    for q in primes:                        # adjoin the roots of unity (a cyclotomic factor equal to p is already present)
        cq = cyclotomic(q)
        if poly.gcd(cq).degree() == 0:
            poly = poly * cq
    prec = st.prec_bits
    for _ in range(3):
        try:
            gd = _galois_data(poly, prec, st.maxorder * math.prod(q - 1 for q in primes)) if primes else \
                (gd0 if prec == st.prec_bits else _galois_data(p, prec, st.maxorder))
            expr, st.extended_order, st.series_primes = _descend(gd, a, primes, st)
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
        raise NotSolvable(f"Frobenius element with {frobenius_reason(a.degree)}: not solvable")
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
    def attempt(prec):
        with ctx.workprec(prec):
            z = ball(expr, prec)
            matches = [i for i, r in enumerate(rd.poly_roots(a.poly, prec)) if r.overlaps(z)]
        return (matches[0] == a.index - 1) if len(matches) == 1 else (False if not matches else None)
    return _escalate(attempt, prec_bits, what="verification")


def _as_algebraic(a) -> AlgebraicNumber:
    if isinstance(a, AlgebraicNumber):
        return a
    return rd.parse_wolfram_root(a) if isinstance(a, str) else AlgebraicNumber.from_rational(Fraction(a))


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
    return RadicalResult(expression=expr, method=st.method_used or "Rational", verified=verify_numeric(expr, a, prec_bits),
                         degree=a.degree, galois_order=st.galois_order, extended_order=st.extended_order,
                         series_primes=st.series_primes, time=time.perf_counter() - t0)


def is_solvable(a, maxorder: int = 400, prec_bits: int = 300) -> bool:
    """Solvability of the Galois group of the minimal polynomial of a."""
    a = _as_algebraic(a)
    if a.degree <= 4:
        return True
    if frobenius_nonsolvable(a.poly):
        return False
    _check_order_limit(a.poly, maxorder)
    gd = _galois_data(a.poly, prec_bits, maxorder)
    return is_solvable_group(gd.mult_table, gd.identity, range(gd.order))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python roottoradicals.py \"Root[poly &, k]\" [auto|structural|galois]")
        sys.exit(2)
    try:
        res = root_to_radicals(sys.argv[1], method=sys.argv[2] if len(sys.argv) > 2 else "auto")
        print(res)
        print("Wolfram:", res.wolfram())
    except NotSolvable as e:
        print("not solvable:", e)
        sys.exit(1)
