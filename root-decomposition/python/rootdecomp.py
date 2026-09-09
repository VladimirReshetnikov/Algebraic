"""
rootdecomp.py -- additive and multiplicative decomposition of algebraic numbers
into components of the smallest possible maximum degree.

A Python/FLINT counterpart of the Wolfram Language package RootDecomposition.wl.

Given an algebraic number a of degree n (a root of an irreducible integer
polynomial, selected by an index with real roots first and then ordered
complex conjugate pairs), the module computes

    D+(a) = min max deg(b_i)   over all finite sums     a = b_1 + ... + b_r,
    Dx(a) = min max deg(b_i)   over all finite products a = b_1 * ... * b_r,

with the b_i ranging over all algebraic numbers.  See the accompanying article
for the theory:

* sums: trace descent to the splitting field L; D+(a) <= d iff a lies in the
  Q-span of the fixed fields L^H with [G:H] <= d (exact linear algebra);
* two-factor products: norm descent; a = bc with deg b, deg c <= d iff there
  are subfields E, F of L and t >= 1 with t[E:Q], t[F:Q] <= d and
  E \\cap a^t F != 0;
* many-factor products: two-factor criterion, rank-one tensor test, recursive
  splitting, lower bounds (no complete algorithm is known).

Engine.  The Galois group is computed as a permutation group on the roots by
numerical resolvents in Arb ball arithmetic: at each level the product of
(x - theta_tau) over all candidate partial tuples is a G-invariant monic
integer polynomial; it is rounded rigorously (each coefficient ball contains a
unique integer), factored exactly over Z, and the factor vanishing at the
identity tuple identifies the orbit.  Group closure is verified.  The splitting
field is represented in a tower monomial basis; rational coordinates come from
traces (rigorously rounded integers) and exact fmpq linear algebra.  All
returned identities hold exactly in that coordinate algebra and are also
checked numerically.

Requires python-flint >= 0.8 and SymPy >= 1.14.
"""

from __future__ import annotations

import itertools
import math
import random
from dataclasses import dataclass, field
from fractions import Fraction
from functools import lru_cache
from typing import Optional

from flint import (acb, acb_mat, acb_poly, arb, ctx, fmpq, fmpq_mat, fmpq_poly, fmpz,
                   fmpz_mat, fmpz_poly, nmod_poly)


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

class PrecisionError(Exception):
    """Raised when a rigorous rounding step fails at the current precision."""


def _retry_precision(compute, prec, message, exceptions=(PrecisionError,)):
    """Try six doubling precisions, restoring the caller's context after each attempt."""
    for _ in range(6):
        try:
            with ctx.workprec(prec):
                return compute(prec)
        except exceptions:
            prec *= 2
    raise PrecisionError(message)


def _fmpz_list(coeffs):
    return [int(c) for c in coeffs]


def primitive(p: fmpz_poly) -> fmpz_poly:
    """Primitive integer polynomial with positive leading coefficient."""
    content = p.content()
    if not content:
        return fmpz_poly()
    return p // (content if p.leading_coefficient() > 0 else -content)


def poly_from_fractions(coeffs) -> fmpz_poly:
    """Integer polynomial proportional to the rational polynomial with the given coefficients."""
    coeffs = [Fraction(c) for c in coeffs]
    return primitive(fmpq_poly([fmpq(c.numerator, c.denominator) for c in coeffs]).numer())


def _affine_polynomial(p: fmpz_poly, scale=Fraction(1), shift=Fraction(0)) -> fmpz_poly:
    """Primitive polynomial for scale*a + shift, with nonzero rational scale."""
    scale, shift = Fraction(scale), Fraction(shift)
    s = fmpq(scale.numerator, scale.denominator)
    t = fmpq(shift.numerator, shift.denominator)
    return primitive(fmpq_poly(p)(fmpq_poly([-t / s, 1 / s])).numer())


def _clear_denominators(values):
    """Return an integer vector and its common positive denominator."""
    values = [fmpq(v) for v in values]
    den = math.lcm(*(int(v.q) for v in values))
    return [int(v * den) for v in values], den


def height(p: fmpz_poly) -> int:
    return max(abs(int(c)) for c in p.coeffs())


def _unique_integer(z: acb) -> int:
    """Rigorous: return the unique integer in the real part of ball z."""
    if not z.imag.contains(0):
        raise PrecisionError("nonzero imaginary part")
    try:
        return int(z.real.unique_fmpz())
    except (ValueError, TypeError):
        raise PrecisionError("coefficient does not contain a unique integer") from None


def mat_round(m: acb_mat) -> fmpz_mat:
    rows, cols = m.nrows(), m.ncols()
    return fmpz_mat([[_unique_integer(m[i, j]) for j in range(cols)] for i in range(rows)])


def fmpq_mat_from_fmpz_scaled(m: fmpz_mat, den: int) -> fmpq_mat:
    return fmpq_mat(m) / den if den != 1 else fmpq_mat(m)


def fmpq_nullspace(m: fmpq_mat) -> list[list[fmpq]]:
    """Basis (list of vectors) of the right nullspace of a rational matrix."""
    rows = m.nrows()
    cols = m.ncols()
    if rows == 0:
        return [[fmpq(1) if k == j else fmpq(0) for k in range(cols)] for j in range(cols)]
    if rows >= cols and m.rank() == cols:
        return []
    introws = [_clear_denominators(row)[0] for row in m.tolist()]
    M = fmpz_mat(introws)
    ns, nullity = M.nullspace()
    return [[fmpq(ns[i, j]) for i in range(cols)] for j in range(nullity)]


def fmpq_solve(A: fmpq_mat, b: list[fmpq]):
    """Solve A x = b over Q (A may be non-square); returns list or None."""
    rows, cols = A.nrows(), A.ncols()
    # augmented rref
    aug = fmpq_mat(rows, cols + 1, [x for row, value in zip(A.tolist(), b) for x in row + [value]])
    R, rank = aug.rref()
    # check consistency: a pivot in the last column means inconsistent
    x = [fmpq(0)] * cols
    for i in range(rank):
        piv = next((j for j in range(cols + 1) if R[i, j] != 0), None)
        if piv is None:
            continue
        if piv == cols:
            return None
        x[piv] = R[i, cols]
    return x


def rowspace_basis(vectors: list[list[fmpq]], ncols: int) -> list[list[fmpq]]:
    if not vectors:
        return []
    M = fmpq_mat([[fmpq(v) for v in row] for row in vectors])
    R, rank = M.rref()
    return [[R[i, j] for j in range(ncols)] for i in range(rank)]


# ---------------------------------------------------------------------------
# algebraic numbers
# ---------------------------------------------------------------------------

def root_sort_key(z: acb):
    """An arbitrary-precision key; use _ordered_roots for certified ordering."""
    re = z.real.mid().fmpq()
    im = z.imag.mid().fmpq()
    is_real = z.imag.contains(0)
    if is_real:
        return (0, re, 0, 0)
    return (1, re, abs(im), 0 if im < 0 else 1)


def _ordered_roots(p, roots, prec_bits):
    """Real roots first, then conjugate pairs ordered by (Re, abs(Im)).

    Complex Root numbering can depend on Wolfram's isolation method. This
    deterministic convention is used throughout the Python implementation.
    A conjugate is identified by overlap with the isolated conjugate root,
    never by a floating-point tolerance.
    """
    real, pairs = [], []
    for i, z in enumerate(roots):
        conjugates = [j for j, w in enumerate(roots) if w.overlaps(z.conjugate())]
        if len(conjugates) != 1:
            raise PrecisionError("complex conjugate not uniquely isolated")
        j = conjugates[0]
        if j == i:
            real.append(z)
        elif z.imag > 0:
            pairs.append((z, roots[j]))
        elif not z.imag < 0:
            raise PrecisionError("imaginary sign not isolated")
    real.sort(key=lambda z: z.real.mid().fmpq())
    pairs.sort(key=lambda pair: pair[0].real.mid().fmpq())
    if any(not real[i].real < real[i + 1].real for i in range(len(real) - 1)):
        raise PrecisionError("real roots not separated")
    if any(not pairs[i][0].real < pairs[i + 1][0].real for i in range(len(pairs) - 1)):
        # Different conjugate pairs can have exactly the same real part. The
        # pair-sum polynomial identifies 2*c*Re(z) as a real algebraic number;
        # its isolated real roots distinguish equality from close separation.
        c = int(p.leading_coefficient())
        summed = _round_poly(_poly_from_roots([c * (x + y) for x in roots for y in roots]))
        squarefree = summed // summed.gcd(summed.derivative())
        sr = acb_poly(squarefree).roots(tol=arb(2) ** (-(prec_bits - 20)), maxprec=8 * prec_bits)
        real_sums = []
        for i, z in enumerate(sr):
            matches = [j for j, w in enumerate(sr) if w.overlaps(z.conjugate())]
            if len(matches) != 1:
                raise PrecisionError("pair-sum conjugate not uniquely isolated")
            if matches[0] == i:
                real_sums.append(z)
        sr = real_sums
        sr.sort(key=lambda z: z.real.mid().fmpq())
        if any(not sr[i].real < sr[i + 1].real for i in range(len(sr) - 1)):
            raise PrecisionError("real projections not separated")
        def projection(pair):
            matches = [i for i, z in enumerate(sr) if z.real.overlaps(2 * c * pair[0].real)]
            if len(matches) != 1:
                raise PrecisionError("real projection not uniquely identified")
            return matches[0], pair[0].imag.mid().fmpq()
        pairs.sort(key=projection)
        for i in range(len(pairs) - 1):
            if projection(pairs[i])[0] == projection(pairs[i + 1])[0] and not pairs[i][0].imag < pairs[i + 1][0].imag:
                raise PrecisionError("imaginary parts not separated")
    return real + [z for upper, lower in pairs for z in (lower, upper)]


def poly_roots(p: fmpz_poly, prec_bits: int) -> list[acb]:
    """All roots as balls, with real roots first and ordered conjugate pairs."""
    p = primitive(p)
    return list(_cached_poly_roots(tuple(_fmpz_list(p.coeffs())), prec_bits))


@lru_cache(maxsize=256)
def _cached_poly_roots(coeffs, prec_bits):
    p = fmpz_poly(list(coeffs))
    if p.degree() < 1 or p.gcd(p.derivative()).degree() > 0:
        raise ValueError("root isolation requires a nonconstant squarefree polynomial")
    def isolate(work):
        rts = acb_poly(p).roots(tol=arb(2) ** (-(work - 20)), maxprec=8 * work)
        return tuple(_ordered_roots(p, rts, work))
    return _retry_precision(isolate, prec_bits, "root isolation failed", (ValueError, PrecisionError))


@lru_cache(maxsize=512)
def _minimal_polynomial_coeffs(coeffs):
    p = primitive(fmpz_poly(list(coeffs)))
    if p.degree() < 1:
        raise ValueError("an algebraic number requires a nonconstant minimal polynomial")
    factors = p.factor()[1]
    if len(factors) != 1 or factors[0][1] != 1:
        raise ValueError("the defining polynomial must be irreducible over Q")
    return tuple(_fmpz_list(p.coeffs()))


def _matching_factor(factors, value):
    """Identify an annihilating irreducible factor without accepting ambiguity."""
    matches = [g for g, _ in factors if g.degree() > 0 and acb_poly(g)(value).contains(0)]
    if len(matches) != 1:
        raise PrecisionError("annihilating factor is not uniquely identified")
    return matches[0]


@dataclass
class AlgebraicNumber:
    """An algebraic number given by its primitive irreducible minimal polynomial
    and a 1-based root index. Real roots are increasing; complex pairs are
    ordered by real part and positive imaginary part, negative member first.
    Wolfram's ordering of non-real roots can depend on its isolation method.
    """
    poly: fmpz_poly
    index: int
    _value: Optional[acb] = None

    def __post_init__(self):
        self.poly = fmpz_poly(list(_minimal_polynomial_coeffs(tuple(_fmpz_list(self.poly.coeffs())))))
        if not isinstance(self.index, int) or isinstance(self.index, bool) or not 1 <= self.index <= self.degree:
            raise ValueError("root index must be an integer between 1 and the polynomial degree")

    @property
    def degree(self) -> int:
        return self.poly.degree()

    def value(self, prec_bits: int = 200) -> acb:
        return poly_roots(self.poly, prec_bits)[self.index - 1]

    def __repr__(self):
        return f"Root[{wolfram_poly(self.poly)} &, {self.index}]"

    def wolfram(self) -> str:
        if self.degree == 1:
            c = _fmpz_list(self.poly.coeffs())
            return str(Fraction(-c[0], c[1]))
        return repr(self)

    def as_fraction(self) -> Optional[Fraction]:
        if self.degree == 1:
            c = _fmpz_list(self.poly.coeffs())
            return Fraction(-c[0], c[1])
        return None

    @staticmethod
    def from_rational(q) -> "AlgebraicNumber":
        q = Fraction(q)
        return AlgebraicNumber(fmpz_poly([-q.numerator, q.denominator]), 1)

    @staticmethod
    def from_value(p: fmpz_poly, z: acb, prec_bits: int = 200) -> "AlgebraicNumber":
        """Select the unique root of p whose isolating ball overlaps z.

        Callers computing an exact algebraic expression must establish that p
        annihilates it and that z encloses it. Ambiguous matching requires more
        precision, and is never resolved by nearest floating-point distance.
        """
        p = primitive(p)
        rts = poly_roots(p, prec_bits)
        matches = [i for i, root in enumerate(rts) if root.overlaps(z)]
        if len(matches) != 1:
            raise PrecisionError("root is not uniquely identified")
        return AlgebraicNumber(p, matches[0] + 1)


def wolfram_poly(p: fmpz_poly) -> str:
    c = _fmpz_list(p.coeffs())
    terms = []
    for i, a in enumerate(c):
        if a == 0:
            continue
        if i == 0:
            terms.append(f"{a}")
        elif i == 1:
            terms.append(f"{a} #" if a not in (1, -1) else ("#" if a == 1 else "-#"))
        else:
            terms.append(f"{a} #^{i}" if a not in (1, -1) else (f"#^{i}" if a == 1 else f"-#^{i}"))
    s = " + ".join(terms)
    return s.replace("+ -", "- ")


def parse_wolfram_root(s: str) -> AlgebraicNumber:
    """Parse expanded integer-polynomial Root syntax with # or #1.

    The polynomial must be irreducible. Non-real indices use this module's
    convention; certify their correspondence when exchanging Wolfram Roots.
    """
    import re as _re
    s = s.strip()
    m = _re.match(r"Root\[(.*)&\s*,\s*(\d+)\s*\]$", s, _re.S)
    if not m:
        raise ValueError("not a Root expression")
    body, k = m.group(1), int(m.group(2))
    body = _re.sub(r"\s+", "", body.replace("#1", "#"))
    body = body.replace("-", "+-")
    coeffs = {}
    for term in body.split("+"):
        if term == "":
            continue
        if "#" in term:
            match = _re.fullmatch(r"(-?\d*\*?)#(?:\^(\d+))?", term)
            if match is None:
                raise ValueError(f"invalid polynomial term: {term!r}")
            c = match.group(1)
            power = int(match.group(2)) if match.group(2) is not None else 1
            if c in ("", "*"):
                cval = 1
            elif c in ("-", "-*"):
                cval = -1
            else:
                cval = int(c.rstrip("*"))
        else:
            power, cval = 0, int(term)
        coeffs[power] = coeffs.get(power, 0) + cval
    if not coeffs:
        raise ValueError("empty polynomial")
    deg = max(coeffs)
    return AlgebraicNumber(primitive(fmpz_poly([coeffs.get(i, 0) for i in range(deg + 1)])), k)


# ---------------------------------------------------------------------------
# lower bounds
# ---------------------------------------------------------------------------

def largest_prime_factor(n: int) -> int:
    if n == 1:
        return 1
    return max(int(p) for p, _ in fmpz(n).factor())


def exponent_bound(e: int) -> int:
    """least d with e | lcm(1..d): the largest prime power dividing e"""
    if e == 1:
        return 1
    return max(int(p) ** int(k) for p, k in fmpz(e).factor())


def frobenius_cycle_types(p: fmpz_poly, max_primes: int = 40, start_prime: int = 2):
    """Yield sorted factor degrees at unramified primes, starting at start_prime."""
    from sympy import nextprime

    disc = int(fmpz_poly(p).resultant(p.derivative()))
    if p.degree() < 1 or disc == 0:
        raise ValueError("Frobenius cycle types require a nonconstant squarefree polynomial")
    bad_primes = disc * int(p.leading_coefficient())
    coeffs = _fmpz_list(p.coeffs())
    q = int(nextprime(start_prime - 1))
    count = 0
    while count < max_primes:
        if bad_primes % q != 0:
            factors = nmod_poly(coeffs, q).factor()[1]
            yield sorted(g.degree() for g, _ in factors if g.degree() > 0)
            count += 1
        q = int(nextprime(q))


def frobenius_exponent_multiple(p: fmpz_poly, max_primes: int = 40) -> int:
    return math.lcm(*(math.lcm(*degrees) for degrees in frobenius_cycle_types(p, max_primes)))


def lower_bound(p: fmpz_poly) -> int:
    """A global degree lower bound; p must be an irreducible minimal polynomial."""
    return _lower_bound_cached(_minimal_polynomial_coeffs(tuple(_fmpz_list(p.coeffs()))))


@lru_cache(maxsize=512)
def _lower_bound_cached(coeffs):
    p = fmpz_poly(list(coeffs))
    n = p.degree()
    bound = largest_prime_factor(n)
    return bound if bound == n else max(bound, exponent_bound(frobenius_exponent_multiple(p)))


# ---------------------------------------------------------------------------
# Galois group by rigorous numerical resolvents
# ---------------------------------------------------------------------------

@dataclass
class GaloisData:
    poly: fmpz_poly                   # monic integer polynomial (roots are algebraic integers)
    scale: int                        # original roots = these roots / scale
    roots: list                       # acb balls (Mathematica order)
    prec: int
    perms: list                       # list of tuples (0-based permutations)
    order: int
    tower: list                       # [(root index, relative degree)]
    basis_exp: list                   # exponent vectors
    values: acb_mat                   # rows: group elements, cols: basis monomials
    gram: fmpz_mat
    gram_inv: fmpq_mat
    mult_table: list                  # mult_table[i][j] = index of perms[i] o perms[j]
    identity: int
    root_coords: list                 # list of coordinate vectors (lists of fmpq)
    automorphisms: list               # list of fmpq_mat acting on coordinate columns
    subgroups: list                   # list of dicts: elements (frozenset), gens, order, index, fixed (rows)
    exponent: int

    @property
    def n(self):
        return len(self.roots)


def _poly_from_roots(vals: list[acb]) -> acb_poly:
    # Balanced products use FLINT's fast polynomial multiplication and avoid
    # successively multiplying a large polynomial by one linear factor.
    level = [acb_poly([-v, 1]) for v in vals]
    while len(level) > 1:
        level = [level[i] * level[i + 1] if i + 1 < len(level) else level[i]
                 for i in range(0, len(level), 2)]
    return level[0] if level else acb_poly([1])


def _round_poly(p: acb_poly) -> fmpz_poly:
    return fmpz_poly([_unique_integer(c) for c in p.coeffs()])


def galois_group(roots: list[acb], maxorder: int, rng: random.Random):
    """Returns (perms, tower) with rigorous ball arithmetic; raises PrecisionError."""
    n = len(roots)
    orbit = [()]
    vals = [acb(0)]
    tower = []
    for k in range(n):
        ok = False
        used = set()
        for _ in range(12):
            w = rng.randint(1, 60)
            while w in used:
                w = rng.randint(1, 60)
            used.add(w)
            cand = []
            cvals = []
            for tup, v in zip(orbit, vals):
                for j in range(n):
                    if j in tup:
                        continue
                    cand.append(tup + (j,))
                    cvals.append(v + w * roots[j])
            F = _round_poly(_poly_from_roots(cvals))
            # squarefree test (exact)
            if F.gcd(F.derivative()).degree() != 0:
                continue
            fac = F.factor()[1]
            idval = cvals[cand.index(tuple(range(k + 1)))]
            mk = None
            for g, _mult in fac:
                gv = acb_poly(g)(idval)
                if gv.contains(0):
                    if mk is not None:
                        raise PrecisionError("ambiguous factor")
                    mk = g
            if mk is None:
                raise PrecisionError("no factor vanishes at theta")
            md = mk.degree()
            last = len(orbit)
            if md % last != 0:
                continue
            if md > maxorder:
                raise ValueError(f"Galois group order {md} exceeds the limit {maxorder}")
            mkp = acb_poly(mk)
            matched = [(t, v) for t, v in zip(cand, cvals) if mkp(v).contains(0)]
            if len(matched) != md:
                if len(matched) < md:
                    raise PrecisionError("orbit undercount")
                raise PrecisionError("orbit overcount")
            orbit = [t for t, _ in matched]
            vals = [v for _, v in matched]
            if md > last:
                tower.append((k, md // last))
            ok = True
            break
        if not ok:
            raise PrecisionError("could not find non-degenerate weights")
    perms = orbit
    pset = set(perms)
    ident = tuple(range(n))
    if ident not in pset:
        raise PrecisionError("identity missing")
    for s in perms:
        for t in perms:
            comp = tuple(s[t[i]] for i in range(n))
            if comp not in pset:
                raise PrecisionError("closure failed")
    return perms, tower


def group_closure(mt, ident, gens, visit=None):
    """Subgroup generated by gens; optionally visit each discovery edge (parent, generator, element)."""
    elems = {ident}
    queue = [ident]
    for e in queue:
        for g in gens:
            h = mt[e][g]
            if h not in elems:
                elems.add(h)
                queue.append(h)
                if visit is not None:
                    visit(e, g, h)
    return frozenset(elems)


def _subgroup_lattice(mt, ident, order):
    seen = {frozenset([ident]): []}
    for g in range(order):
        J = group_closure(mt, ident, [g])
        if J not in seen:
            seen[J] = [g]
    queue = list(seen)
    for H in queue:
        for g in range(order):
            if g in H:
                continue
            J = group_closure(mt, ident, seen[H] + [g])
            if J not in seen:
                seen[J] = seen[H] + [g]
                queue.append(J)
    return [dict(elements=H, gens=gens, order=len(H), index=order // len(H)) for H, gens in seen.items()]


def _element_order(mt, g, ident):
    h, k = g, 1
    while h != ident:
        h = mt[h][g]
        k += 1
    return k


def _basis_values(roots, perms, tower, basis_exp):
    """Evaluate the selected tower monomials at each root permutation."""
    gens = [g for g, _ in tower]
    maxe = max((e for ex in basis_exp for e in ex), default=0)
    powers = [[root ** e for e in range(maxe + 1)] for root in roots]
    values = acb_mat(len(perms), len(basis_exp))
    for s, perm in enumerate(perms):
        for b, ex in enumerate(basis_exp):
            value = acb(1)
            for j, g in enumerate(gens):
                value *= powers[perm[g]][ex[j]]
            values[s, b] = value
    return values


def build_galois_data(poly: fmpz_poly, prec_bits: int = 300, maxorder: int = 400, seed: int = 1) -> GaloisData:
    """Complete Galois/field data for the roots of a monic squarefree integer polynomial."""
    rng = random.Random(seed)
    return _retry_precision(lambda prec: _build_at_precision(poly, prec, maxorder, rng),
                            prec_bits, "precision escalation failed")


def _build_at_precision(poly, prec, maxorder, rng) -> GaloisData:
    roots = poly_roots(poly, prec)
    n = len(roots)
    perms, tower = galois_group(roots, maxorder, rng)
    order = len(perms)
    basis_exp = list(itertools.product(*(range(e) for _, e in tower)))
    values = _basis_values(roots, perms, tower, basis_exp)
    vt = values.transpose()
    gram = mat_round(vt * values)
    if gram.det() == 0:
        raise PrecisionError("singular Gram matrix")
    gram_inv = fmpq_mat(gram).inv()
    index = {p: i for i, p in enumerate(perms)}
    mt = [[index[tuple(perms[i][perms[j][k]] for k in range(n))] for j in range(order)] for i in range(order)]
    ident = index[tuple(range(n))]
    # root coordinates
    nums_perm = acb_mat(order, n)
    for s, perm in enumerate(perms):
        for i in range(n):
            nums_perm[s, i] = roots[perm[i]]
    rc = gram_inv * fmpq_mat(mat_round(vt * nums_perm))
    root_coords = rc.transpose().tolist()
    # Reconstruct generators from traces, then propagate the exact group action.
    subs = _subgroup_lattice(mt, ident, order)
    group_gens = next(sub["gens"] for sub in subs if sub["order"] == order)
    I = fmpq_mat(order, order)
    for i in range(order):
        I[i, i] = 1
    auts = [None] * order
    auts[ident] = I
    for s in group_gens:
        vs = acb_mat(order, order, [values[mt[t][s], b] for t in range(order) for b in range(order)])
        auts[s] = gram_inv * fmpq_mat(mat_round(vt * vs))
    def propagate(parent, generator, element):
        if auts[element] is None:
            auts[element] = auts[parent] * auts[generator]
    group_closure(mt, ident, group_gens, propagate)
    # consistency: automorphisms permute root coordinates
    for s, perm in enumerate(perms):
        A = auts[s]
        if (A * rc).transpose().tolist() != [root_coords[i] for i in perm]:
            raise PrecisionError("automorphism consistency failed")
    for sub in subs:
        if sub["order"] == 1:
            sub["fixed"] = I.tolist()
        else:
            rows = [row for g in sub["gens"] for row in (auts[g] - I).tolist()]
            sub["fixed"] = fmpq_nullspace(fmpq_mat(rows))
    exponent = 1
    for g in range(order):
        o = _element_order(mt, g, ident)
        exponent = exponent * o // math.gcd(exponent, o)
    return GaloisData(poly=poly, scale=1, roots=roots, prec=prec, perms=perms, order=order,
                      tower=tower, basis_exp=basis_exp, values=values, gram=gram, gram_inv=gram_inv,
                      mult_table=mt, identity=ident, root_coords=root_coords, automorphisms=auts,
                      subgroups=subs, exponent=exponent)


_cache: dict = {}


def galois_data(p: fmpz_poly, prec_bits: int = 300, maxorder: int = 400) -> GaloisData:
    """Galois data for a primitive integer polynomial (roots scaled to algebraic integers)."""
    p = primitive(p)
    mon, c = _integral_model(p)
    key = (tuple(_fmpz_list(mon.coeffs())), c, prec_bits)
    if key in _cache:
        if _cache[key].order > maxorder:
            raise ValueError(f"Galois group order {_cache[key].order} exceeds the limit {maxorder}")
        return _cache[key]
    gd = build_galois_data(mon, prec_bits, maxorder)
    gd.scale = c
    _cache[key] = gd
    return gd


# ---------------------------------------------------------------------------
# field element utilities
# ---------------------------------------------------------------------------

def _vec_fmpq(v):
    return [fmpq(x) for x in v]


def conj_vector(gd: GaloisData, v) -> list[acb]:
    """values of all conjugates (rows of the value matrix) of the element with coordinates v"""
    column = acb_mat(gd.order, 1, [_fmpq_to_acb(fmpq(q)) for q in v])
    return (gd.values * column).entries()


def _fmpq_to_acb(q: fmpq) -> acb:
    return acb(int(q.p)) / acb(int(q.q))


def coords_from_conjugates(gd: GaloisData, yv: list[acb]) -> list[fmpq]:
    rhs = gd.values.transpose() * acb_mat(gd.order, 1, yv)
    return (gd.gram_inv * fmpq_mat(mat_round(rhs))).entries()


def multiplication_matrix(gd: GaloisData, yv: list[acb]) -> fmpq_mat:
    """matrix of multiplication by the algebraic integer with conjugate vector yv"""
    scaled = acb_mat(gd.order, gd.order)
    for s in range(gd.order):
        for j in range(gd.order):
            scaled[s, j] = yv[s] * gd.values[s, j]
    return gd.gram_inv * fmpq_mat(mat_round(gd.values.transpose() * scaled))


def _try_lower_precision(compute):
    """Try cheaper recovery of known integer traces, then the caller's precision."""
    for prec in (min(64, ctx.prec), ctx.prec):
        try:
            with ctx.workprec(prec):
                return compute()
        except PrecisionError:
            if prec == ctx.prec:
                raise


def multiplication_matrix_of(gd: GaloisData, v) -> fmpq_mat:
    """Exact multiplication by rational coordinates in a basis of algebraic integers."""
    integers, den = _clear_denominators(v)
    values = conj_vector(gd, integers)
    # Clearing denominators makes the product traces integers.
    return _try_lower_precision(lambda: multiplication_matrix(gd, values) / den)


def power_coordinates(gd: GaloisData, v, exponent: int) -> list[fmpq]:
    """Exact nonnegative power, reconstructing one coordinate vector instead of a matrix."""
    if not isinstance(exponent, int) or exponent < 0:
        raise ValueError("the exponent must be a nonnegative integer")
    if exponent == 0:
        return [fmpq(1)] + [fmpq(0)] * (gd.order - 1)
    if exponent == 1:
        return _vec_fmpq(v)
    integers, den = _clear_denominators(v)
    with ctx.workprec(gd.prec):
        try:
            powers = [z ** exponent for z in conj_vector(gd, integers)]
            # Integer coefficients in the integral monomial basis make these powers integral.
            coordinates = _try_lower_precision(lambda: coords_from_conjugates(gd, powers))
            return [c / den ** exponent for c in coordinates]
        except PrecisionError:
            # Large powers can exhaust trace precision even when a single matrix is recoverable.
            matrix = multiplication_matrix_of(gd, v)
            result = _vec_fmpq(v)
            for _ in range(exponent - 1):
                result = apply_matrix(matrix, result)
            return result


def power_divider(gd: GaloisData, denominator):
    """Prepare exact division by powers of one nonzero field element, reusing its norm or matrix."""
    denominator = _vec_fmpq(denominator)
    integers, den = _clear_denominators(denominator)
    if not any(integers):
        raise ZeroDivisionError("the field denominator is zero")
    matrix = None
    with ctx.workprec(gd.prec):
        try:
            values = conj_vector(gd, integers)
            norm = _unique_integer(math.prod(values, start=acb(1)))
            if norm == 0 or any(z.contains(0) for z in values):
                raise PrecisionError("the nonzero denominator is not resolved")
            reciprocals = [acb(norm) / z for z in values]
        except PrecisionError:
            reciprocals = None

    def divide(numerator, exponent: int):
        nonlocal matrix
        if not isinstance(exponent, int) or exponent < 0:
            raise ValueError("the exponent must be a nonnegative integer")
        numerator = _vec_fmpq(numerator)
        if exponent == 0:
            return numerator
        with ctx.workprec(gd.prec):
            if reciprocals is not None:
                try:
                    integers, num_den = _clear_denominators(numerator)
                    # For integral B, Norm(B)/B is integral, so these traces are integers.
                    values = [z * w ** exponent for z, w in zip(conj_vector(gd, integers), reciprocals)]
                    scale = fmpq(den ** exponent, num_den * norm ** exponent)
                    return [scale * c for c in coords_from_conjugates(gd, values)]
                except PrecisionError:
                    pass
            if matrix is None:
                matrix = multiplication_matrix_of(gd, denominator)
            return fmpq_solve(matrix ** exponent, numerator)

    return divide


def apply_matrix(M: fmpq_mat, v):
    return (M * fmpq_mat(M.ncols(), 1, v)).entries()


def element_degree(gd: GaloisData, v) -> int:
    v = _vec_fmpq(v)
    cnt = sum(1 for A in gd.automorphisms if apply_matrix(A, v) == v)
    return gd.order // cnt


def mean_trace(gd: GaloisData, v) -> fmpq:
    return sum((fmpq(v[j]) * int(gd.gram[j, 0]) for j in range(gd.order)), fmpq(0)) / gd.order


def element_to_algebraic(gd: GaloisData, v) -> AlgebraicNumber:
    """Minimal polynomial and root index of the element with coordinates v."""
    v = _vec_fmpq(v)
    if not any(v[1:]):
        return AlgebraicNumber.from_rational(Fraction(int(v[0].p), int(v[0].q)))
    w, den = _clear_denominators(v)
    # distinct conjugates: orbit of the coordinate vector
    seen = set()
    reps = []
    for s, A in enumerate(gd.automorphisms):
        img = tuple(apply_matrix(A, w))
        if img not in seen:
            seen.add(img)
            reps.append(s)
    def reconstruct(prec):
        vals = conj_vector(gd, w) if prec == gd.prec else _conj_vector_at(gd, w, prec)
        p = _round_poly(_poly_from_roots([vals[s] for s in reps]))
        q = _affine_polynomial(p, Fraction(1, den))
        return AlgebraicNumber.from_value(q, vals[gd.identity] / den, prec)
    return _retry_precision(reconstruct, gd.prec, "element_to_algebraic failed")


def _conj_vector_at(gd: GaloisData, w, prec, rows=None):
    roots = poly_roots(gd.poly, prec)
    indices = [i for i, q in enumerate(w) if q]
    perms = gd.perms if rows is None else [gd.perms[i] for i in rows]
    values = _basis_values(roots, perms, gd.tower, [gd.basis_exp[i] for i in indices])
    return (values * acb_mat(len(indices), 1, [_fmpq_to_acb(fmpq(w[i])) for i in indices])).entries()



# ---------------------------------------------------------------------------
# input-field engine: subfields of K = Q(a) via principal subfields (SymPy
# factorization over K), no Galois group.  Elements are coordinate vectors in
# the power basis of theta = scale * a.
# ---------------------------------------------------------------------------

@dataclass
class InputFieldData:
    poly: fmpz_poly            # monic integer polynomial of theta
    scale: int
    n: int
    theta: "AlgebraicNumber"   # the actual root (theta = scale * a)
    factor_degrees: list
    galois: bool
    subgroups: list            # dicts: index (= degree), fixed (rows), elements None
    traces: list               # power sums p_0..p_{n-1}
    prec: int = 300
    kind: str = "InputField"

    @property
    def order(self):
        return self.n

    def mult_matrix(self, v) -> fmpq_mat:
        """matrix of multiplication by sum v_j theta^j in the power basis"""
        current, modulus, columns = fmpq_poly(_vec_fmpq(v)), fmpq_poly(self.poly), []
        for _ in range(self.n):
            columns.append(current.coeffs() + [fmpq(0)] * (self.n - len(current)))
            current = current.left_shift(1) % modulus
        return _col_matrix(columns, self.n)

    def mean_trace(self, v) -> fmpq:
        return sum((fmpq(v[j]) * int(self.traces[j]) for j in range(self.n)), fmpq(0)) / self.n

    def to_algebraic(self, v) -> "AlgebraicNumber":
        v = _vec_fmpq(v)
        if not any(v[1:]):
            q = v[0] if v else fmpq(0)
            return AlgebraicNumber.from_rational(Fraction(int(q.p), int(q.q)))
        ip = self.mult_matrix(v).charpoly().numer()  # minpoly^(n/d), with denominators cleared
        with ctx.workprec(self.prec):
            val = acb_poly(fmpq_poly(v))(self.theta.value(self.prec))
            g = _matching_factor(ip.factor()[1], val)
            return AlgebraicNumber.from_value(g, val, self.prec)


def power_sums(P: fmpz_poly, n: int):
    c = _fmpz_list(P.coeffs())
    s = [n]
    for k in range(1, n):
        s.append(-k * c[n - k] - sum(c[n - i] * s[k - i] for i in range(1, k)))
    return s[:n]


def _intersect_rowspaces(A, B, n):
    ca = fmpq_nullspace(fmpq_mat([[fmpq(x) for x in r] for r in A])) if A else None
    cb = fmpq_nullspace(fmpq_mat([[fmpq(x) for x in r] for r in B])) if B else None
    if not ca:
        return B
    if not cb:
        return A
    return fmpq_nullspace(fmpq_mat([[fmpq(x) for x in r] for r in ca + cb]))


_ifcache: dict = {}


def input_field_data(p: fmpz_poly, a: "AlgebraicNumber", prec_bits: int = 300) -> InputFieldData:
    import sympy as sp
    p = primitive(p)
    if p != a.poly:
        raise ValueError("p must be the minimal polynomial of a")
    n = p.degree()
    mon, c = _integral_model(p)
    key = tuple(_fmpz_list(mon.coeffs()))
    # Positive scaling preserves the root order, including complex conjugates.
    theta = AlgebraicNumber(mon, a.index)
    if key in _ifcache:
        d = _ifcache[key]
        return InputFieldData(d.poly, c, n, theta, d.factor_degrees, d.galois, d.subgroups, d.traces, prec_bits)
    x, y = sp.symbols('x y')
    P = sum(sp.Integer(int(mon[i])) * x ** i for i in range(n + 1))
    root = sp.CRootOf(P, 0)
    K = sp.QQ.algebraic_field(root)
    fac = sp.Poly(P.subs(x, y), y, domain=K).factor_list()[1]

    def vec(el):
        vals = [fmpq(int(q.numerator), int(q.denominator)) for q in reversed(K.convert(el).to_list())]
        return vals + [fmpq(0)] * (n - len(vals))

    factor_degrees = sorted(g.degree() for g, _ in fac)
    galois = all(g.degree() == 1 for g, _ in fac)
    principal = []
    theta_el = K.from_sympy(root)
    for g, _ in fac:
        m = g.degree()
        if m == 1:
            const = K.convert(g.rep.to_list()[-1])
            if const == -theta_el:
                continue                      # the factor y - theta gives K itself
        rows = []
        thpow = K.one
        for j in range(n):
            r = sp.Poly(y ** j, y, domain=K) - sp.Poly(thpow, y, domain=K)
            r = r.rem(g)
            coeffs_r = list(reversed(r.rep.to_list()))  # low to high, domain elements
            coeffs_r = coeffs_r + [K.zero] * (m - len(coeffs_r))
            rows.append([vec(cc) for cc in coeffs_r])
            thpow = thpow * theta_el
        eqs = [list(column) for coefficients in zip(*rows) for column in zip(*coefficients)]
        principal.append(rowspace_basis(fmpq_nullspace(fmpq_mat(eqs)), n))
    ident = [[fmpq(1) if i == j else fmpq(0) for j in range(n)] for i in range(n)]
    subfields = {tuple(map(tuple, ident)): ident}
    for V in principal:
        for S in list(subfields.values()):
            rows = rowspace_basis(_intersect_rowspaces(S, V, n), n)
            subfields.setdefault(tuple(map(tuple, rows)), rows)
    subfields = list(subfields.values())
    one = [[fmpq(1)] + [fmpq(0)] * (n - 1)]
    if not any(len(S) == 1 for S in subfields):
        subfields.append(one)
    subs = [dict(index=len(S), fixed=S, elements=None, order=n // len(S)) for S in subfields]
    d = InputFieldData(mon, c, n, theta, factor_degrees, galois, subs, power_sums(mon, n), prec_bits)
    _ifcache[key] = d
    return d


def fd_mult_matrix(fd, v):
    return fd.mult_matrix(v) if isinstance(fd, InputFieldData) else multiplication_matrix_of(fd, v)


def fd_to_algebraic(fd, v):
    return fd.to_algebraic(v) if isinstance(fd, InputFieldData) else element_to_algebraic(fd, v)


def fd_mean_trace(fd, v):
    return fd.mean_trace(v) if isinstance(fd, InputFieldData) else mean_trace(fd, v)


def fd_is_galois(fd):
    return fd.galois if isinstance(fd, InputFieldData) else True

# ---------------------------------------------------------------------------
# results
# ---------------------------------------------------------------------------

@dataclass
class Decomposition:
    op: str
    terms: list                 # AlgebraicNumber (or (coefficient, AlgebraicNumber) in Gaussian mode)
    degrees: list
    max_degree: int
    lower_bound: int
    optimal: bool
    scope_optimal: bool
    scope: str
    method: str
    extra: dict = field(default_factory=dict)

    def wolfram(self) -> str:
        sym = " + " if self.op == "Plus" else " * "
        return sym.join(t.wolfram() for t in self.terms)

    def __repr__(self):
        return (f"Decomposition({self.op}: {self.wolfram()}; degrees={self.degrees}, max={self.max_degree}, "
                f"lower_bound={self.lower_bound}, optimal={self.optimal}, method={self.method})")


def locate_target(gd: GaloisData, a: AlgebraicNumber) -> int:
    """Locate scale*a among the splitting-field roots by a unique ball overlap."""
    z = a.value(gd.prec) * gd.scale
    matches = [i for i, root in enumerate(gd.roots) if root.overlaps(z)]
    if len(matches) != 1:
        raise PrecisionError("target root not uniquely located")
    return matches[0]


def stabilizer(gd: GaloisData, target: int):
    return frozenset(i for i, p in enumerate(gd.perms) if p[target] == target)


def field_contains(big, small, n):
    M = fmpq_mat([[fmpq(x) for x in r] for r in big + small])
    return M.rank() == len(big)


def candidate_fields(gd, d: int, stab=None):
    subs = [H for H in gd.subgroups if H["index"] <= d]
    if stab is not None:
        subs = [H for H in subs if stab <= H["elements"]]
    n = gd.order
    out = []
    for H in subs:
        if not any(K["index"] > H["index"] and
                   (K["elements"] <= H["elements"] if H["elements"] is not None
                    else field_contains(K["fixed"], H["fixed"], n)) for K in subs):
            out.append(H)
    return out


def solve_in_spaces(spaces, v):
    if not spaces:
        return None
    n = len(v)
    A = _col_matrix([col for sp in spaces for col in sp["basis"]], n)
    sol = fmpq_solve(A, _vec_fmpq(v))
    if sol is None:
        return None
    out = []
    pos = 0
    for sp in spaces:
        k = len(sp["basis"])
        chunk = sol[pos:pos + k]
        pos += k
        contrib = [sum((chunk[i] * sp["basis"][i][j] for i in range(k)), fmpq(0)) for j in range(n)]
        if any(x != 0 for x in contrib):
            out.append((sp, contrib))
    return out


def find_sum_representation(spaces, v, max_terms):
    limit = min(3, len(spaces)) if max_terms is None else min(max_terms, len(spaces))
    full = None
    if max_terms is None and len(spaces) > limit:
        full = solve_in_spaces(spaces, v)
        if full is None:
            return None
    for k in range(1, limit + 1):
        for s in itertools.combinations(spaces, k):
            r = solve_in_spaces(list(s), v)
            if r is not None:
                return r
    return full


def _sum_search(fd, a, va, stab, n, lb, dmax, scope, max_terms, method, complete):
    extra = {"ambient_degree": fd.order} if isinstance(fd, InputFieldData) else {"group_order": fd.order}
    dlist = range(lb, n) if dmax is None else [dmax]
    for d in dlist:
        cf = candidate_fields(fd, d, stab)
        spaces = [dict(index=H["index"], basis=H["fixed"]) for H in cf]
        rep = find_sum_representation(spaces, va, max_terms)
        if rep is None:
            continue
        rational = fmpq(0)
        terms = []
        for sp_, e in rep:
            m = fd_mean_trace(fd, e)
            rational += m
            t = list(e)
            t[0] = t[0] - m
            if any(x != 0 for x in t):
                terms.append(fd_to_algebraic(fd, t))
        if rational != 0:
            if max_terms is not None and len(terms) >= max_terms:
                # Trace centering may not turn a two-term answer into three
                # terms. Keep the rational part in its original field.
                terms = [fd_to_algebraic(fd, e) for _, e in rep]
            else:
                terms.append(AlgebraicNumber.from_rational(Fraction(int(rational.p), int(rational.q))))
        if not terms:
            terms = [AlgebraicNumber.from_rational(0)]
        degs = [t.degree for t in terms]
        optimal = max(degs) == lb or (dmax is None and complete and max_terms is None)
        return Decomposition("Plus", terms, degs, max(degs), lb,
                             optimal, optimal or (dmax is None and (complete or scope == "InputField")), scope, method, extra)
    if dmax is None:
        return Decomposition("Plus", [a], [n], n, lb, complete and max_terms is None,
                             complete or scope == "InputField", scope, "CompleteSearch", extra)
    return None


def _positive_integer(value, name):
    if not isinstance(value, int) or isinstance(value, bool) or value < 1:
        raise ValueError(f"{name} must be a positive integer")


def _search_options(dmax, scope, limit, limit_name, prec_bits, maxorder, engine):
    if dmax is not None:
        _positive_integer(dmax, "dmax")
    if limit is not None:
        _positive_integer(limit, limit_name)
    _positive_integer(prec_bits, "prec_bits")
    _positive_integer(maxorder, "maxorder")
    if scope not in ("Global", "InputField"):
        raise ValueError("scope must be 'Global' or 'InputField'")
    aliases = {"auto": "auto", "Automatic": "auto", "input": "input", "InputField": "input",
               "splitting": "splitting", "SplittingField": "splitting"}
    if engine not in aliases:
        raise ValueError("engine must be 'auto', 'input', or 'splitting'")
    return aliases[engine]


def sum_decomposition(a: AlgebraicNumber, dmax: Optional[int] = None, scope: str = "Global",
                      max_terms: Optional[int] = None, prec_bits: int = 300, maxorder: int = 400,
                      engine: str = "auto") -> Optional[Decomposition]:
    engine = _search_options(dmax, scope, max_terms, "max_terms", prec_bits, maxorder, engine)
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1

    def trivial(method="Trivial", optimal=None):
        opt = (lb == n) if optimal is None else optimal
        return Decomposition("Plus", [a], [n], n, lb, opt, opt or max_terms == 1, scope, method)

    if dmax is not None and dmax < lb:
        return None
    if max_terms == 1:
        return trivial() if dmax is None or dmax >= n else None
    if n == 1 or (dmax is not None and dmax >= n) or lb == n:
        return trivial()
    res = None
    if engine != "splitting":
        fd = input_field_data(a.poly, a, prec_bits)
        va = [fmpq(0), fmpq(1, fd.scale)] + [fmpq(0)] * (n - 2)
        method = "GaloisInputField" if fd.galois else "InputFieldSubfields"
        res = _sum_search(fd, a, va, None, n, lb, dmax, scope, max_terms, method, fd.galois)
        if fd.galois or scope == "InputField" or engine == "input" or (res is not None and res.max_degree == lb):
            return res
    gd = galois_data(a.poly, prec_bits, maxorder)
    with ctx.workprec(gd.prec):
        target = locate_target(gd, a)
        va = [q / gd.scale for q in gd.root_coords[target]]
        stab = stabilizer(gd, target) if scope == "InputField" else None
        lb = max(lb, exponent_bound(gd.exponent))
        if lb >= n:
            return trivial("CompleteSearch", True) if dmax is None or dmax >= n else None
        method = "SplittingFieldFixedSpaces" if scope == "Global" else "InputFieldSubfields"
        return _sum_search(gd, a, va, stab, n, lb, dmax, scope, max_terms, method, scope == "Global")


# ---------------------------------------------------------------------------
# products
# ---------------------------------------------------------------------------

def _valuation(r: int, p: int) -> int:
    if r == 0:
        return 10 ** 9
    v = 0
    while r % p == 0:
        r //= p
        v += 1
    return v


def integral_scale(p: fmpz_poly) -> Fraction:
    """p-adically minimal rational q > 0 such that q*u is an algebraic integer (p = minpoly(u))."""
    d = p.degree()
    c = [Fraction(int(a)) for a in p.coeffs()]
    lc = c[-1]
    c = [a / lc for a in c]
    primes = set()
    for a in c:
        for r in (a.numerator, a.denominator):
            r = abs(r)
            if r > 1:
                for q_, _ in fmpz(r).factor():
                    primes.add(int(q_))
    q = Fraction(1)
    for pr in sorted(primes):
        es = []
        for i in range(d):
            if c[i] != 0:
                v = _valuation(c[i].numerator, pr) - _valuation(c[i].denominator, pr)
                es.append(-(v // (d - i)))  # ceil(-v/(d-i)), using exact division
        if es:
            q *= Fraction(pr) ** max(es)
    return q


def nice_scale(p: fmpz_poly) -> Fraction:
    """rational q minimizing the height of the minimal polynomial of q*u, where p = minpoly(u)"""
    q0 = integral_scale(p)
    best, hb = q0, None
    cands = {q for k in range(1, 13) for l in range(1, 13) for s in (1, -1)
             for q in (Fraction(s * k, l), Fraction(s * l, k))}
    for q in cands:
        qq = q * q0
        g = _affine_polynomial(p, qq)
        gc = _fmpz_list(g.coeffs())
        h = (height(g), -(gc[0] > 0) + (gc[0] < 0), abs(math.log(abs(q))))
        if hb is None or h < hb:
            hb, best = h, qq
    return best


def scale_algebraic(u: AlgebraicNumber, q: Fraction, prec_bits: int) -> AlgebraicNumber:
    q = Fraction(q)
    if q == 0:
        return AlgebraicNumber.from_rational(0)
    g = _affine_polynomial(u.poly, q)
    # Positive scaling preserves real order and the order of conjugate pairs.
    if q > 0:
        return AlgebraicNumber(g, u.index)
    with ctx.workprec(prec_bits):
        return AlgebraicNumber.from_value(g, u.value(prec_bits) * _fmpq_to_acb(fmpq(q.numerator, q.denominator)), prec_bits)


def root_of_algebraic(u: AlgebraicNumber, t: int, prec_bits: int) -> AlgebraicNumber:
    """A t-th root of u, selected by certified factor and root matching."""
    _positive_integer(t, "t")
    if t == 1:
        return u
    inflated = u.poly.inflate(t)
    with ctx.workprec(prec_bits):
        uv = u.value(prec_bits)
        val = acb_poly([-uv] + [acb(0)] * (t - 1) + [acb(1)]).roots(tol=arb(2) ** (-(prec_bits - 20)))[0]
        g = _matching_factor(inflated.factor()[1], val)
        return AlgebraicNumber.from_value(g, val, prec_bits)


def quotient_algebraic(a: AlgebraicNumber, b: AlgebraicNumber, bt_over_field_poly: fmpz_poly, t: int, prec_bits: int) -> AlgebraicNumber:
    """c = a/b where c^t is known to have minimal polynomial bt_over_field_poly"""
    inflated = bt_over_field_poly.inflate(t)
    with ctx.workprec(prec_bits):
        val = a.value(prec_bits) / b.value(prec_bits)
        g = _matching_factor(inflated.factor()[1], val)
        return AlgebraicNumber.from_value(g, val, prec_bits)


def compositum_degree_bound(fd, fields):
    """Exact for fixed fields in Galois data; an upper bound in an input field."""
    if fields[0]["elements"] is not None:
        intersection = frozenset.intersection(*(h["elements"] for h in fields))
        return fd.order // len(intersection)
    return math.prod(h["index"] for h in fields)


def two_factor_search(fd, va, a: AlgebraicNumber, n: int, d: int, stab,
                      allow_radicals=True, cache=None):
    tmax = min(d, d * d // n) if (allow_radicals and stab is None and fd_is_galois(fd)) else 1
    cache = {} if cache is None else cache
    if "Ma" not in cache:
        cache["Ma"] = fd_mult_matrix(fd, va)
        cache["powers"] = {1: cache["Ma"]}
        cache["failed_pairs"] = set()
    Ma = cache["Ma"]
    for t in range(1, tmax + 1):
        subs = [H for H in fd.subgroups if t * H["index"] <= d]
        if stab is not None:
            subs = [H for H in subs if stab <= H["elements"]]
        if not subs:
            continue
        if t not in cache["powers"]:
            cache["powers"][t] = cache["powers"][t - 1] * Ma
        Mt = cache["powers"][t]
        pairs = [(subs[i], subs[j]) for i in range(len(subs)) for j in range(i, len(subs))
                 if n <= t * compositum_degree_bound(fd, [subs[i], subs[j]])]
        pairs.sort(key=lambda pr: (max(pr[0]["index"], pr[1]["index"]), pr[0]["index"] + pr[1]["index"]))
        for E, F in pairs:
            key = (t, id(E), id(F))
            if key in cache["failed_pairs"]:
                continue
            res = _try_pair(fd, E, F, Mt, t, a, d)
            if res is not None:
                return res
            cache["failed_pairs"].add(key)
    return None


def shortest_vector(ns, length):
    """LLL-reduce the integer nullspace basis and return the vector with the shortest E-part."""
    rows = [_clear_denominators(v)[0] for v in ns]
    if len(rows) > 1:
        red = fmpz_mat(rows).lll()
        rows = [[int(red[i, j]) for j in range(red.ncols())] for i in range(red.nrows())]
    return _vec_fmpq(min(rows, key=lambda r: sum(x * x for x in r[:length])))


def _try_pair(fd, E, F, Mt, t, a, d):
    ord_ = fd.order
    BE, BF = E["fixed"], F["fixed"]
    MF = [apply_matrix(Mt, f) for f in BF]
    M = _col_matrix(BE + [[-x for x in f] for f in MF], ord_)
    ns = fmpq_nullspace(M)
    if not ns:
        return None
    x = shortest_vector(ns, len(BE))
    u = [sum((x[i] * BE[i][j] for i in range(len(BE))), fmpq(0)) for j in range(ord_)]
    u_alg = fd_to_algebraic(fd, u)
    q = nice_scale(u_alg.poly)
    qu = scale_algebraic(u_alg, q, fd.prec)
    b = root_of_algebraic(qu, t, fd.prec)
    # c^t = a^t / (q u)
    # Both bases start with 1, so the first column of Mt already contains a^t.
    at = [Mt[i, 0] for i in range(ord_)]
    Mqu = fd_mult_matrix(fd, [fmpq(q.numerator, q.denominator) * ui for ui in u])
    z = fmpq_solve(Mqu, at)
    ct_alg = fd_to_algebraic(fd, z)
    cc = quotient_algebraic(a, b, ct_alg.poly, t, fd.prec)
    if max(b.degree, cc.degree) <= d:
        return dict(terms=[b, cc], t=t, fields=(E["index"], F["index"]))
    return None


def families_with_product(subs, target, min_size):
    out = []

    def rec(start, remaining, acc):
        if remaining == 1:
            if len(acc) >= min_size:
                out.append(list(acc))
            return
        for i in range(start, len(subs)):
            if remaining % subs[i]["index"] == 0:
                rec(i + 1, remaining // subs[i]["index"], acc + [subs[i]])
    rec(0, target, [])
    return out


def tensor_search(gd, va, d, stab, max_factors=None, cache=None):
    subs = [H for H in gd.subgroups if 1 < H["index"] <= d]
    if stab is not None:
        subs = [H for H in subs if stab <= H["elements"]]
    subs.sort(key=lambda H: H["index"])
    fams = families_with_product(subs, gd.order, 3)
    cache = {} if cache is None else cache
    failed = cache.setdefault("failed_families", set())
    matrices = cache.setdefault("matrices", {})
    for count, fam in enumerate(fams):
        if max_factors is not None and len(fam) > max_factors:
            continue
        if count > 400:
            break
        key = tuple(id(H) for H in fam)
        if key in failed:
            continue
        res = tensor_test(gd, fam, va, matrices)
        if res is not None:
            return res
        failed.add(key)
    return None


def _col_matrix(vectors, nrows):
    return fmpq_mat(vectors).transpose() if vectors else fmpq_mat(nrows, 0)


def _hstack(mats, nrows):
    columns = [col for m in mats for col in m.transpose().tolist()]
    return _col_matrix(columns, nrows)


def _tensor_conjugates_possible(gd, fam, va, cache):
    """Reject only rigorously nonzero minors; inconclusive balls need the exact test."""
    # Embeddings of L^H are right cosets gH. The caller has proved that the
    # tuple of these cosets bijects G with the product of the embedding sets.
    cosets = []
    for field in fam:
        labels = [None] * gd.order
        for g in range(gd.order):
            if labels[g] is None:
                for h in field["elements"]:
                    labels[gd.mult_table[g][h]] = g
        cosets.append(labels)
    indices = list(zip(*cosets))
    positions = {index: g for g, index in enumerate(indices)}
    identity = indices[gd.identity]
    with ctx.workprec(gd.prec):
        key = ("conjugates", tuple(va))
        if key not in cache:
            cache[key] = conj_vector(gd, va)
        values = cache[key]
        pivot_power = values[gd.identity] ** (len(fam) - 1)
        for index, value in zip(indices, values):
            fibers = (identity[:j] + (index[j],) + identity[j + 1:] for j in range(len(fam)))
            product = math.prod(values[positions[fiber]] for fiber in fibers)
            if not (value * pivot_power - product).contains(0):
                return False
    return True


def tensor_test(gd, fam, va, cache):
    """Test a product basis whose factor dimensions multiply to the ambient degree."""
    ord_ = gd.order
    bases = [H["fixed"] for H in fam]
    dims = [len(B) for B in bases]
    if math.prod(dims) != ord_ or compositum_degree_bound(gd, fam) < ord_:
        return None
    if isinstance(gd, GaloisData) and not _tensor_conjugates_possible(gd, fam, va, cache):
        return None
    mats = []
    for B in bases:
        row = []
        for b in B:
            key = tuple(b)
            if key not in cache:
                cache[key] = fd_mult_matrix(gd, b)
            row.append(cache[key])
        mats.append(row)
    # Each new factor contributes the outer blocks, so the first index varies fastest.
    current = _col_matrix([[fmpq(1)] + [fmpq(0)] * (ord_ - 1)], ord_)
    for matrices in mats:
        current = _hstack([matrix * current for matrix in matrices], ord_)
    # The family degrees multiply to ord_: invertibility proves that the products
    # form a basis. A single exact solve tests this and obtains the coordinates.
    try:
        coords = current.solve(_col_matrix([va], ord_)).entries()
    except ZeroDivisionError:
        return None
    idx = list(itertools.product(*[range(k) for k in dims]))
    columns = (tuple(reversed(t)) for t in itertools.product(*[range(k) for k in reversed(dims)]))
    tensor = dict(zip(columns, coords))
    piv_pos = next((i for i in idx if tensor[i] != 0), None)
    if piv_pos is None:
        return None
    piv = tensor[piv_pos]
    vecs = []
    for j in range(len(fam)):
        vj = []
        for i in range(dims[j]):
            pos = list(piv_pos)
            pos[j] = i
            vj.append(tensor[tuple(pos)] / piv)
        vecs.append(vj)
    for i in idx:
        prod = piv
        for j in range(len(fam)):
            prod *= vecs[j][i[j]]
        if prod != tensor[i]:
            return None
    elems = []
    for j in range(len(fam)):
        e = [sum((vecs[j][i] * bases[j][i][k] for i in range(dims[j])), fmpq(0)) for k in range(ord_)]
        elems.append(e)
    elems[0] = [piv * x for x in elems[0]]
    return elems


def _product_search(fd, a, va, stab, n, lb, dmax, scope, max_factors, depth, tensor, prec_bits, maxorder, engine, complete):
    extra = {"ambient_degree": fd.order, "ambient_galois": fd.galois} if isinstance(fd, InputFieldData) else {"group_order": fd.order}
    dlist = list(range(max(lb, math.isqrt(n - 1) + 1), n)) if dmax is None else [dmax]
    two = None
    pair_cache = {}
    for d in dlist:
        two = two_factor_search(fd, va, a, n, d, stab, scope != "InputField", pair_cache)
        if two is not None:
            break
    best = None
    if two is not None:
        degs = [t.degree for t in two["terms"]]
        scoped_pair_optimal = max(degs) == lb or (dmax is None and (complete or scope == "InputField"))
        best = Decomposition("Times", two["terms"], degs, max(degs), lb, max(degs) == lb,
                             max(degs) == lb or (max_factors == 2 and scoped_pair_optimal), scope,
                             "NormIntersection", dict(two_factor_optimal=scoped_pair_optimal, t=two["t"], **extra))
    elif dmax is None:
        best = Decomposition("Times", [a], [n], n, lb, False,
                             max_factors == 2 and (complete or scope == "InputField"), scope, "CompleteTwoFactorSearch",
                             dict(two_factor_optimal=complete or scope == "InputField", t=1, **extra))
    if max_factors == 2:
        return best
    if best is not None and best.max_degree == lb:
        return best
    if tensor:
        tensor_cache = {}
        # The binary degree bound n <= d^2 does not constrain three or more
        # factors. Start the tensor search at the unrestricted lower bound.
        for d in (range(lb, n) if dmax is None else [dmax]):
            if best is not None and d >= best.max_degree:
                break
            tens = tensor_search(fd, va, d, stab, max_factors, tensor_cache)
            if tens is not None:
                terms = clean_product_terms([fd_to_algebraic(fd, e) for e in tens], prec_bits)
                degs = [t.degree for t in terms]
                if best is None or max(degs) < best.max_degree:
                    best = Decomposition("Times", terms, degs, max(degs), lb, max(degs) == lb, max(degs) == lb, scope,
                                         "TensorRankOne", dict(two_factor_optimal=False, t=1, **extra))
                break
    if best is not None and best.max_degree == lb:
        return best
    if best is not None and depth > 0 and len(best.terms) >= 2:
        terms = []
        for f in best.terms:
            if f.degree > lb:
                sub = product_decomposition(f, scope=scope, max_factors=max_factors, depth=depth - 1,
                                            tensor=tensor, prec_bits=prec_bits, maxorder=maxorder, engine=engine)
                terms.extend(sub.terms if sub is not None else [f])
            else:
                terms.append(f)
        degs = [t.degree for t in terms]
        if max(degs) < best.max_degree and (max_factors is None or len(terms) <= max_factors):
            best = Decomposition("Times", terms, degs, max(degs), lb, max(degs) == lb, max(degs) == lb, scope,
                                 "RecursiveSplitting", dict(two_factor_optimal=False, t=1, **extra))
    if scope != "InputField" and (best is None or best.max_degree > lb):
        upper = best.max_degree - 1 if best is not None else dmax
        for dd in range(lb, min(2, upper) + 1):
            res = bounded_decomposition(a, "Times", dd, 2, min(3, max_factors or 3), prec_bits)
            if res is not None and (best is None or res.max_degree < best.max_degree):
                res.scope = scope
                best = res
                break
    return best


def product_decomposition(a: AlgebraicNumber, dmax: Optional[int] = None, scope: str = "Global",
                          max_factors: Optional[int] = None, depth: int = 3, tensor: bool = True,
                          prec_bits: int = 300, maxorder: int = 400, engine: str = "auto") -> Optional[Decomposition]:
    engine = _search_options(dmax, scope, max_factors, "max_factors", prec_bits, maxorder, engine)
    if not isinstance(depth, int) or isinstance(depth, bool) or depth < 0:
        raise ValueError("depth must be a nonnegative integer")
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1

    def trivial(method="Trivial", optimal=None):
        opt = (lb == n) if optimal is None else optimal
        return Decomposition("Times", [a], [n], n, lb, opt, opt or max_factors == 1, scope, method, {"two_factor_optimal": opt, "t": 1})

    if dmax is not None and dmax < lb:
        return None
    if max_factors == 1:
        return trivial() if dmax is None or dmax >= n else None
    if n == 1 or (dmax is not None and dmax >= n) or lb == n:
        return trivial()
    res = None
    if engine != "splitting":
        fd = input_field_data(a.poly, a, prec_bits)
        va = [fmpq(0), fmpq(1, fd.scale)] + [fmpq(0)] * (n - 2)
        with ctx.workprec(prec_bits):
            res = _product_search(fd, a, va, None, n, lb, dmax, scope, max_factors, depth, tensor, prec_bits, maxorder, engine, fd.galois)
        if fd.galois or scope == "InputField" or engine == "input" or (res is not None and res.max_degree == lb):
            return res
    gd = galois_data(a.poly, prec_bits, maxorder)
    with ctx.workprec(gd.prec):
        target = locate_target(gd, a)
        va = [q / gd.scale for q in gd.root_coords[target]]
        stab = stabilizer(gd, target) if scope == "InputField" else None
        lb = max(lb, exponent_bound(gd.exponent))
        if lb >= n:
            return trivial("Trivial", True) if dmax is None or dmax >= n else None
        return _product_search(gd, a, va, stab, n, lb, dmax, scope, max_factors, depth, tensor, prec_bits, maxorder, engine, True)


def clean_product_terms(terms, prec_bits):
    """Merge rational factors and rescale each factor to a small representative."""
    rat = Fraction(1)
    rest = []
    for t in terms:
        f = t.as_fraction()
        if f is not None:
            rat *= f
        else:
            rest.append(t)
    if not rest:
        return [AlgebraicNumber.from_rational(rat)]
    for j in range(1, len(rest)):
        q = nice_scale(rest[j].poly)
        rest[j] = scale_algebraic(rest[j], q, prec_bits)
        rat /= q
    rest[0] = scale_algebraic(rest[0], rat, prec_bits)
    # Absorb every rational multiplier into a factor so normalization preserves
    # the number of factors (and any user-supplied max_factors bound).
    return rest




# ---------------------------------------------------------------------------
# exact arithmetic on algebraic numbers via numerically computed composed
# polynomials (rigorously rounded), and the bounded dictionary search
# ---------------------------------------------------------------------------

def _integral_model(p: fmpz_poly):
    """Monic polynomial for c*a, where p(a)=0 and c is the leading coefficient."""
    n = p.degree()
    c = int(p.leading_coefficient())
    coeffs = _fmpz_list(p.coeffs())
    mon = fmpz_poly([coeffs[i] * c ** (n - 1 - i) for i in range(n)] + [1])
    return mon, c


def combine_algebraic(a: AlgebraicNumber, b: AlgebraicNumber, op: str, prec_bits: int = 300) -> AlgebraicNumber:
    """a+b, a-b, a*b or a/b as an algebraic number"""
    if op not in ("+", "-", "*", "/"):
        raise ValueError("op must be '+', '-', '*', or '/'")
    aq, bq = a.as_fraction(), b.as_fraction()
    if op == "/" and bq == 0:
        raise ZeroDivisionError("division by the algebraic number zero")
    if a.poly == b.poly and a.index == b.index:
        if op in ("-", "/"):
            return AlgebraicNumber.from_rational(0 if op == "-" else 1)
    if bq is not None:
        if op in ("*", "/"):
            return scale_algebraic(a, bq if op == "*" else 1 / bq, prec_bits)
        shift = bq if op == "+" else -bq
        # Real translation preserves every part of the root ordering.
        return AlgebraicNumber(_affine_polynomial(a.poly, shift=shift), a.index)
    if aq is not None and op in ("+", "*"):
        return combine_algebraic(b, a, op, prec_bits)
    if op == "/":
        # b^{-1}: reverse the polynomial
        coeffs = _fmpz_list(b.poly.coeffs())[::-1]
        with ctx.workprec(prec_bits):
            binv = AlgebraicNumber.from_value(primitive(fmpz_poly(coeffs)), 1 / b.value(prec_bits), prec_bits)
        return combine_algebraic(a, binv, "*", prec_bits)
    if op == "-":
        return combine_algebraic(a, scale_algebraic(b, -1, prec_bits), "+", prec_bits)
    ma, ca = _integral_model(a.poly)
    mb, cb = _integral_model(b.poly)
    scale = ca * cb
    def combine(prec):
        ra = poly_roots(ma, prec)
        rb = poly_roots(mb, prec)
        # Conjugates of the scaled sum/product are algebraic integers.
        vals = [cb * x + ca * y if op == "+" else x * y for x in ra for y in rb]
        comp = _round_poly(_poly_from_roots(vals))
        target = (a.value(prec) + b.value(prec)) if op == "+" else a.value(prec) * b.value(prec)
        g = _matching_factor(comp.factor()[1], target * scale)
        # Exact annihilation plus unique factor/root isolation identifies the result.
        return AlgebraicNumber.from_value(_affine_polynomial(g, Fraction(1, scale)), target, prec)
    return _retry_precision(combine, prec_bits, "combine_algebraic failed")


@lru_cache(maxsize=16, typed=True)
def catalog(d: int, h: int) -> tuple:
    """roots of all irreducible primitive integer polynomials of degree <= d and height <= h"""
    _positive_integer(d, "d")
    _positive_integer(h, "h")
    out = []
    for m in range(1, d + 1):
        for coeffs in itertools.product(*([range(-h, h + 1)] * m + [range(1, h + 1)])):
            if math.gcd(*coeffs) != 1:
                continue
            p = fmpz_poly(list(coeffs))
            fac = p.factor()[1]
            if len(fac) != 1 or fac[0][1] != 1:
                continue
            for k in range(1, m + 1):
                out.append(AlgebraicNumber(p, k))
    return tuple(out)


def bounded_decomposition(a: AlgebraicNumber, op: str, d: int, h: int, r: int, prec_bits: int = 300):
    """Decomposition of a into at most r components of degree <= d, all but the last from the catalog."""
    if op not in ("Plus", "Times"):
        raise ValueError("op must be 'Plus' or 'Times'")
    for name, value in (("d", d), ("h", h), ("r", r), ("prec_bits", prec_bits)):
        _positive_integer(value, name)
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1
    if d < lb:
        return None
    if n <= d:
        return Decomposition(op, [a], [n], n, lb, lb == n, lb == n or r == 1, "Bounded", "Trivial")
    # Reject impossible component counts before allocating the height box.
    if n > d ** r:
        return None
    cat = [c for c in catalog(d, h) if c.degree > 1]
    if op == "Times":
        cat = [c for c in cat if c.as_fraction() != 0]

    def search(prefix, res, start, slots):
        deg = res.degree
        if deg <= d:
            return prefix + [res]
        if slots <= 1 or deg > d ** slots or largest_prime_factor(deg) > d:
            return None
        for i in range(start, len(cat)):
            residual = combine_algebraic(res, cat[i], "-" if op == "Plus" else "/", prec_bits)
            found = search(prefix + [cat[i]], residual, i, slots - 1)
            if found is not None:
                return found
        return None

    found = search([], a, 0, r)
    if found is None:
        return None
    degs = [t.degree for t in found]
    return Decomposition(op, found, degs, max(degs), lb, max(degs) == lb, max(degs) == lb, "Bounded", "DictionarySearch")

# ---------------------------------------------------------------------------
# numeric verification
# ---------------------------------------------------------------------------

def verify_numeric(a: AlgebraicNumber, dec: Decomposition, prec_bits: int = 300) -> bool:
    """Check numerical consistency by ball overlap; this alone is not a proof."""
    if dec.op not in ("Plus", "Times"):
        raise ValueError("decomposition operation must be 'Plus' or 'Times'")
    with ctx.workprec(prec_bits):
        av = a.value(prec_bits)
        if dec.op == "Plus":
            s = acb(0)
            for t in dec.terms:
                s += t.value(prec_bits)
        else:
            s = acb(1)
            for t in dec.terms:
                s *= t.value(prec_bits)
        return (s - av).contains(0)


def verify_exact(a: AlgebraicNumber, dec: Decomposition, prec_bits: int = 300) -> bool:
    """Prove a returned identity using exact composed-polynomial arithmetic.

    Every arithmetic step constructs an annihilating integer polynomial,
    factors it exactly, and isolates the uniquely selected root. Equality is
    then equality of normalized minimal polynomials and root indices. A
    PrecisionError is an inconclusive computation, never a successful check.
    This can cost more than the field-coordinate search itself.
    """
    if dec.op not in ("Plus", "Times"):
        raise ValueError("decomposition operation must be 'Plus' or 'Times'")
    result = AlgebraicNumber.from_rational(0 if dec.op == "Plus" else 1)
    for term in dec.terms:
        result = combine_algebraic(result, term, "+" if dec.op == "Plus" else "*", prec_bits)
    return result.poly == a.poly and result.index == a.index


# ---------------------------------------------------------------------------
# command line demo
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import time

    ap = parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
    as_ = parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")
    for label, fn, arg in [("product example", product_decomposition, ap),
                           ("sum example", sum_decomposition, as_),
                           ("sum of the product root", sum_decomposition, ap),
                           ("product of the sum root", product_decomposition, as_)]:
        t0 = time.perf_counter()
        r = fn(arg)
        dt = time.perf_counter() - t0
        print(f"{label} ({dt:.2f} s): {r}  numeric check: {verify_numeric(arg, r)}")
