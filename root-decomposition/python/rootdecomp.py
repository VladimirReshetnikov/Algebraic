"""
rootdecomp.py -- additive and multiplicative decomposition of algebraic numbers
into components of the smallest possible maximum degree.

A Python/FLINT counterpart of the Wolfram Language package RootDecomposition.wl.

Given an algebraic number a of degree n (a root of an irreducible integer
polynomial, selected by an index in the same order Mathematica uses for
Root objects), the module computes

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

Requires python-flint >= 0.7.
"""

from __future__ import annotations

import itertools
import math
import random
from dataclasses import dataclass, field
from fractions import Fraction
from typing import Optional

import flint
from flint import (acb, acb_mat, acb_poly, arb, ctx, fmpq, fmpq_mat, fmpz,
                   fmpz_mat, fmpz_poly, nmod_poly)


# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

class PrecisionError(Exception):
    """Raised when a rigorous rounding step fails at the current precision."""


def _fmpz_list(coeffs):
    return [int(c) for c in coeffs]


def primitive(p: fmpz_poly) -> fmpz_poly:
    """Primitive integer polynomial with positive leading coefficient."""
    c = _fmpz_list(p.coeffs())
    g = 0
    for a in c:
        g = math.gcd(g, abs(a))
    if g == 0:
        return fmpz_poly([0])
    c = [a // g for a in c]
    if c[-1] < 0:
        c = [-a for a in c]
    return fmpz_poly(c)


def poly_from_fractions(coeffs) -> fmpz_poly:
    """Integer polynomial proportional to the rational polynomial with the given coefficients."""
    coeffs = [Fraction(c) for c in coeffs]
    den = 1
    for c in coeffs:
        den = den * c.denominator // math.gcd(den, c.denominator)
    return primitive(fmpz_poly([int(c * den) for c in coeffs]))


def height(p: fmpz_poly) -> int:
    return max(abs(int(c)) for c in p.coeffs())


def _unique_integer(z: acb) -> int:
    """Rigorous: return the unique integer in the real part of ball z."""
    if not z.imag.contains(0):
        raise PrecisionError("nonzero imaginary part")
    re = z.real
    if float(re.rad()) >= 0.5:
        raise PrecisionError("radius too large")
    # candidate from midpoint
    mid = re.mid()
    fl = mid.floor()
    try:
        c = int(fl.unique_fmpz())
    except (ValueError, TypeError):
        raise PrecisionError("floor not exact")
    for cand in (c, c + 1, c - 1):
        if re.contains(cand):
            # uniqueness: radius < 0.5 guarantees at most one integer
            return cand
    raise PrecisionError("no integer in ball")


def mat_round(m: acb_mat) -> fmpz_mat:
    rows, cols = m.nrows(), m.ncols()
    return fmpz_mat([[_unique_integer(m[i, j]) for j in range(cols)] for i in range(rows)])


def fmpq_mat_from_fmpz_scaled(m: fmpz_mat, den: int) -> fmpq_mat:
    return fmpq_mat(m) / den if den != 1 else fmpq_mat(m)


def fmpq_nullspace(m: fmpq_mat) -> list[list[fmpq]]:
    """Basis (list of vectors) of the right nullspace of a rational matrix."""
    rows = m.nrows()
    cols = m.ncols()
    # clear denominators row-wise
    introws = []
    for i in range(rows):
        den = 1
        for j in range(cols):
            den = den * int(m[i, j].q) // math.gcd(den, int(m[i, j].q))
        introws.append([int(m[i, j] * den) for j in range(cols)])
    if rows == 0:
        return [[fmpq(1) if k == j else fmpq(0) for k in range(cols)] for j in range(cols)]
    M = fmpz_mat(introws)
    ns, nullity = M.nullspace()
    vecs = []
    for j in range(nullity):
        vecs.append([fmpq(int(ns[i, j])) for i in range(cols)])
    return vecs


def fmpq_solve(A: fmpq_mat, b: list[fmpq]):
    """Solve A x = b over Q (A may be non-square); returns list or None."""
    rows, cols = A.nrows(), A.ncols()
    # augmented rref
    aug = fmpq_mat(rows, cols + 1)
    for i in range(rows):
        for j in range(cols):
            aug[i, j] = A[i, j]
        aug[i, cols] = b[i]
    R, rank = aug.rref()
    # check consistency: a pivot in the last column means inconsistent
    x = [fmpq(0)] * cols
    for i in range(rank):
        piv = None
        for j in range(cols + 1):
            if R[i, j] != 0:
                piv = j
                break
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
    """Mathematica's Root ordering: real roots ascending, then conjugate pairs by
    increasing real part and |Im|, the root with negative imaginary part first."""
    re = float(z.real.mid())
    im = float(z.imag.mid())
    is_real = z.imag.contains(0) and abs(im) < 1e-12
    if is_real:
        return (0, re, 0.0, 0)
    return (1, re, abs(im), 0 if im < 0 else 1)


def poly_roots(p: fmpz_poly, prec_bits: int) -> list[acb]:
    """All roots of a squarefree integer polynomial in Mathematica order, as balls."""
    work = prec_bits
    for attempt in range(6):
        try:
            with flint.ctx.workprec(work):
                rts = acb_poly(p).roots(tol=arb(2) ** (-(prec_bits - 20)), maxprec=8 * work)
                return sorted(rts, key=root_sort_key)
        except ValueError:
            work *= 2
    raise PrecisionError("root isolation failed")


@dataclass
class AlgebraicNumber:
    """An algebraic number given by its primitive irreducible minimal polynomial
    and the index (1-based) of the root in Mathematica's ordering."""
    poly: fmpz_poly
    index: int
    _value: Optional[acb] = None

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
        """The root of the irreducible polynomial p closest to the ball z."""
        p = primitive(p)
        rts = poly_roots(p, prec_bits)
        best = min(range(len(rts)), key=lambda i: float(abs(rts[i] - z).mid()))
        return AlgebraicNumber(p, best + 1)


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
    """Parse 'Root[c0 + c1 # + ... &, k]' (Mathematica InputForm with # or #1)."""
    import re as _re
    s = s.strip()
    m = _re.match(r"Root\[(.*)&\s*,\s*(\d+)\s*\]$", s, _re.S)
    if not m:
        raise ValueError("not a Root expression")
    body, k = m.group(1), int(m.group(2))
    body = body.replace("#1", "#").replace(" ", "")
    body = body.replace("-", "+-")
    coeffs = {}
    for term in body.split("+"):
        if term == "":
            continue
        if "#" in term:
            c, _, rest = term.partition("#")
            power = 1
            if rest.startswith("^"):
                power = int(rest[1:])
            if c in ("", "*"):
                cval = 1
            elif c in ("-", "-*"):
                cval = -1
            else:
                cval = int(c.rstrip("*"))
        else:
            power, cval = 0, int(term)
        coeffs[power] = coeffs.get(power, 0) + cval
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


def frobenius_exponent_multiple(p: fmpz_poly, max_primes: int = 40) -> int:
    disc = int(fmpz_poly(p).resultant(p.derivative()))
    lc = int(p.leading_coefficient())
    e = 1
    q = 2
    count = 0

    def next_prime(m):
        m += 1
        while True:
            if all(m % r for r in range(2, math.isqrt(m) + 1)):
                return m
            m += 1
    while count < max_primes:
        if (disc * lc) % q != 0:
            f = nmod_poly(_fmpz_list(p.coeffs()), q).factor()
            degs = [g.degree() for g, _ in f[1] if g.degree() > 0]
            o = 1
            for d in degs:
                o = o * d // math.gcd(o, d)
            e = e * o // math.gcd(e, o)
            count += 1
        q = next_prime(q)
    return e


def lower_bound(p: fmpz_poly) -> int:
    n = p.degree()
    if n == 1:
        return 1
    return max(largest_prime_factor(n), exponent_bound(frobenius_exponent_multiple(p)))


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
    p = acb_poly([1])
    for v in vals:
        p = p * acb_poly([-v, 1])
    return p


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


def _subgroup_lattice(mt, ident, order):
    def closure(gens):
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
        return frozenset(elems)

    seen = {frozenset([ident]): []}
    for g in range(order):
        J = closure([g])
        if J not in seen:
            seen[J] = [g]
    queue = list(seen)
    while queue:
        H = queue.pop(0)
        for g in range(order):
            if g in H:
                continue
            J = closure(seen[H] + [g])
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


def build_galois_data(poly: fmpz_poly, prec_bits: int = 300, maxorder: int = 400, seed: int = 1) -> GaloisData:
    """Complete Galois/field data for the roots of a monic squarefree integer polynomial."""
    rng = random.Random(seed)
    prec = prec_bits
    for attempt in range(6):
        try:
            with ctx.workprec(prec):
                return _build_at_precision(poly, prec, maxorder, rng)
        except PrecisionError:
            prec *= 2
    raise PrecisionError("precision escalation failed")


def _build_at_precision(poly, prec, maxorder, rng) -> GaloisData:
    roots = poly_roots(poly, prec)
    n = len(roots)
    perms, tower = galois_group(roots, maxorder, rng)
    order = len(perms)
    gens = [g for g, _ in tower]
    expo = [e for _, e in tower]
    basis_exp = list(itertools.product(*[range(e) for e in expo])) if gens else [()]
    maxe = max(expo) if expo else 1
    pw = [[roots[i] ** e for e in range(maxe + 1)] for i in range(n)]
    values = acb_mat(order, order)
    for s, perm in enumerate(perms):
        for b, ex in enumerate(basis_exp):
            v = acb(1)
            for j, g in enumerate(gens):
                v *= pw[perm[g]][ex[j]]
            values[s, b] = v
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
    root_coords = [[rc[j, i] for j in range(order)] for i in range(n)]
    # automorphisms
    auts = []
    for s in range(order):
        vs = acb_mat(order, order)
        for t in range(order):
            row = mt[t][s]
            for b in range(order):
                vs[t, b] = values[row, b]
        auts.append(gram_inv * fmpq_mat(mat_round(vt * vs)))
    # consistency: automorphisms permute root coordinates
    for s, perm in enumerate(perms):
        A = auts[s]
        for i in range(n):
            img = [sum(A[r, c] * root_coords[i][c] for c in range(order)) for r in range(order)]
            if img != root_coords[perm[i]]:
                raise PrecisionError("automorphism consistency failed")
    subs = _subgroup_lattice(mt, ident, order)
    I = fmpq_mat(order, order)
    for i in range(order):
        I[i, i] = 1
    for sub in subs:
        if sub["order"] == 1:
            sub["fixed"] = [[fmpq(1) if k == j else fmpq(0) for k in range(order)] for j in range(order)]
        else:
            rows = []
            for g in sub["gens"]:
                D = auts[g] - I
                for r in range(order):
                    rows.append([D[r, c] for c in range(order)])
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
    n = p.degree()
    c = int(p.leading_coefficient())
    # monic polynomial for c*root
    coeffs = _fmpz_list(p.coeffs())
    mon = fmpz_poly([coeffs[i] * c ** (n - 1 - i) for i in range(n)] + [1])
    key = (tuple(_fmpz_list(mon.coeffs())), prec_bits)
    if key in _cache:
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
    out = []
    for s in range(gd.order):
        acc = acb(0)
        for j in range(gd.order):
            if v[j] != 0:
                acc += gd.values[s, j] * acb(fmpq(v[j]).p) / acb(fmpq(v[j]).q)
        out.append(acc)
    return out


def _fmpq_to_acb(q: fmpq) -> acb:
    return acb(int(q.p)) / acb(int(q.q))


def coords_from_conjugates(gd: GaloisData, yv: list[acb]) -> list[fmpq]:
    rhs = acb_mat(gd.order, 1)
    for l in range(gd.order):
        acc = acb(0)
        for s in range(gd.order):
            acc += yv[s] * gd.values[s, l]
        rhs[l, 0] = acc
    r = gd.gram_inv * fmpq_mat(mat_round(rhs))
    return [r[i, 0] for i in range(gd.order)]


def multiplication_matrix(gd: GaloisData, yv: list[acb]) -> fmpq_mat:
    """matrix of multiplication by the algebraic integer with conjugate vector yv"""
    scaled = acb_mat(gd.order, gd.order)
    for s in range(gd.order):
        for j in range(gd.order):
            scaled[s, j] = yv[s] * gd.values[s, j]
    return gd.gram_inv * fmpq_mat(mat_round(gd.values.transpose() * scaled))


def multiplication_matrix_of(gd: GaloisData, v) -> fmpq_mat:
    den = 1
    for q in v:
        den = den * int(fmpq(q).q) // math.gcd(den, int(fmpq(q).q))
    yv = conj_vector(gd, [fmpq(q) * den for q in v])
    return multiplication_matrix(gd, yv) / den


def apply_matrix(M: fmpq_mat, v):
    col = fmpq_mat(M.ncols(), 1)
    for c in range(M.ncols()):
        if v[c] != 0:
            col[c, 0] = v[c]
    r = M * col
    return [r[i, 0] for i in range(M.nrows())]


def element_degree(gd: GaloisData, v) -> int:
    v = _vec_fmpq(v)
    cnt = sum(1 for A in gd.automorphisms if apply_matrix(A, v) == v)
    return gd.order // cnt


def mean_trace(gd: GaloisData, v) -> fmpq:
    return sum((fmpq(v[j]) * int(gd.gram[j, 0]) for j in range(gd.order)), fmpq(0)) / gd.order


def element_to_algebraic(gd: GaloisData, v) -> AlgebraicNumber:
    """Minimal polynomial and root index of the element with coordinates v."""
    v = _vec_fmpq(v)
    if all(q == 0 for q in v):
        return AlgebraicNumber.from_rational(0)
    d = element_degree(gd, v)
    if d == 1:
        return AlgebraicNumber.from_rational(Fraction(int(v[0].p), int(v[0].q)))
    den = 1
    for q in v:
        den = den * int(q.q) // math.gcd(den, int(q.q))
    w = [q * den for q in v]
    # distinct conjugates: orbit of the coordinate vector
    seen = set()
    reps = []
    for s, A in enumerate(gd.automorphisms):
        img = tuple(apply_matrix(A, w))
        if img not in seen:
            seen.add(img)
            reps.append(s)
    assert len(reps) == d
    prec = gd.prec
    for attempt in range(6):
        try:
            with ctx.workprec(prec):
                vals = conj_vector(gd, w) if prec == gd.prec else _conj_vector_at(gd, w, prec)
                p = _round_poly(_poly_from_roots([vals[s] for s in reps]))
                # polynomial of y = w/den:  p(den x)
                q = poly_from_fractions([Fraction(int(c)) * Fraction(den) ** i for i, c in enumerate(_fmpz_list(p.coeffs()))])
                val = vals[gd.identity] / den
                return AlgebraicNumber.from_value(q, val, prec)
        except PrecisionError:
            prec *= 2
    raise PrecisionError("element_to_algebraic failed")


def _conj_vector_at(gd: GaloisData, w, prec):
    roots = poly_roots(gd.poly, prec)
    gens = [g for g, _ in gd.tower]
    out = []
    for perm in gd.perms:
        acc = acb(0)
        for b, ex in enumerate(gd.basis_exp):
            if w[b] == 0:
                continue
            m = acb(1)
            for j, g in enumerate(gens):
                m *= roots[perm[g]] ** ex[j]
            acc += m * _fmpq_to_acb(fmpq(w[b]))
        out.append(acc)
    return out



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
        n = self.n
        coeffs = _fmpz_list(self.poly.coeffs())
        cols = []
        cur = [fmpq(x) for x in v]
        for k in range(n):
            cols.append(cur)
            # multiply by theta: shift and reduce
            nxt = [fmpq(0)] + cur[:-1]
            top = cur[-1]
            if top != 0:
                nxt = [nxt[i] - top * coeffs[i] for i in range(n)]
            cur = nxt
        M = fmpq_mat(n, n)
        for j, col in enumerate(cols):
            for i in range(n):
                M[i, j] = col[i]
        return M

    def mean_trace(self, v) -> fmpq:
        return sum((fmpq(v[j]) * int(self.traces[j]) for j in range(self.n)), fmpq(0)) / self.n

    def to_algebraic(self, v) -> "AlgebraicNumber":
        v = _vec_fmpq(v)
        if all(q == 0 for q in v):
            return AlgebraicNumber.from_rational(0)
        if all(q == 0 for q in v[1:]):
            return AlgebraicNumber.from_rational(Fraction(int(v[0].p), int(v[0].q)))
        M = self.mult_matrix(v)
        cp = M.charpoly()                       # fmpq_poly, = minpoly^(n/d)
        den = 1
        for c in cp.coeffs():
            den = den * int(c.q) // math.gcd(den, int(c.q))
        ip = fmpz_poly([int(c * den) for c in cp.coeffs()])
        with ctx.workprec(self.prec):
            th = self.theta.value(self.prec)
            val = acb(0)
            for j in range(self.n - 1, -1, -1):
                val = val * th + _fmpq_to_acb(v[j])
            for g, _ in ip.factor()[1]:
                if g.degree() > 0 and acb_poly(g)(val).contains(0):
                    return AlgebraicNumber.from_value(g, val, self.prec)
        raise PrecisionError("minimal polynomial not identified")


def power_sums(P: fmpz_poly, n: int):
    c = _fmpz_list(P.coeffs())
    e = lambda k: (-1) ** k * c[n - k]
    s = {0: n}
    for k in range(1, n):
        acc = sum((-1) ** (i - 1) * e(i) * s[k - i] for i in range(1, min(k - 1, n) + 1))
        if k <= n:
            acc += (-1) ** (k - 1) * k * e(k)
        s[k] = acc
    return [s[j] for j in range(n)]


def _canonical_rows(rows, n):
    return rowspace_basis(rows, n)


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
    n = p.degree()
    c = int(p.leading_coefficient())
    coeffs = _fmpz_list(p.coeffs())
    mon = fmpz_poly([coeffs[i] * c ** (n - 1 - i) for i in range(n)] + [1])
    key = tuple(_fmpz_list(mon.coeffs()))
    theta = AlgebraicNumber.from_value(mon, a.value(prec_bits) * c, prec_bits)
    if key in _ifcache:
        d = _ifcache[key]
        return InputFieldData(d.poly, c, n, theta, d.factor_degrees, d.galois, d.subgroups, d.traces, prec_bits)
    x, y = sp.symbols('x y')
    P = sum(sp.Integer(int(mon[i])) * x ** i for i in range(n + 1))
    root = sp.CRootOf(P, 0)
    K = sp.QQ.algebraic_field(root)
    fac = sp.Poly(P.subs(x, y), y, domain=K).factor_list()[1]

    def vec(el):
        el = K.convert(el)
        vals = [Fraction(int(q.numerator), int(q.denominator)) for q in reversed(el.to_list())]
        return [fmpq(v.numerator, v.denominator) for v in vals] + [fmpq(0)] * (n - len(vals))

    factor_degrees = sorted(g.degree() for g, _ in fac)
    galois = all(g.degree() == 1 for g, _ in fac)
    principal = []
    theta_el = K.from_sympy(root)
    for g, _ in fac:
        m = g.degree()
        if m == 1:
            continue
        rows = []
        thpow = K.one
        for j in range(n):
            r = sp.Poly(y ** j, y, domain=K) - sp.Poly(thpow, y, domain=K)
            r = r.rem(g)
            coeffs_r = list(reversed(r.rep.to_list()))  # low to high, domain elements
            coeffs_r = coeffs_r + [K.zero] * (m - len(coeffs_r))
            rows.append([vec(cc) for cc in coeffs_r])
            thpow = thpow * theta_el
        eqs = []
        for i in range(m):
            for k in range(n):
                eqs.append([rows[j][i][k] for j in range(n)])
        principal.append(_canonical_rows(fmpq_nullspace(fmpq_mat(eqs)), n))
    ident = [[fmpq(1) if i == j else fmpq(0) for j in range(n)] for i in range(n)]
    subfields = [ident]
    for V in principal:
        new = list(subfields)
        for S in subfields:
            new.append(_canonical_rows(_intersect_rowspaces(S, V, n), n))
        uniq = []
        seen = set()
        for S in new:
            key2 = tuple(tuple(str(q) for q in r) for r in S)
            if key2 not in seen:
                seen.add(key2)
                uniq.append(S)
        subfields = uniq
    one = [[fmpq(1)] + [fmpq(0)] * (n - 1)]
    if not any(len(S) == 1 for S in subfields):
        subfields.append(one)
    subs = [dict(index=len(S), fixed=S, elements=None, order=n // len(S)) for S in subfields]
    d = InputFieldData(mon, c, n, theta, factor_degrees, galois, subs, power_sums(mon, n), prec_bits)
    _ifcache[key] = d
    return d


def _galois_mult_matrix(gd, v):
    return multiplication_matrix_of(gd, v)


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
    """index of scale*a among gd.roots (same ordering as Mathematica for the scaled polynomial)"""
    z = a.value(gd.prec) * gd.scale
    best = min(range(gd.n), key=lambda i: float(abs(gd.roots[i] - z).mid()))
    if not (gd.roots[best] - z).contains(0):
        raise PrecisionError("target root not located")
    return best


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
        if not any(K["index"] > H["index"] and field_contains(K["fixed"], H["fixed"], n) for K in subs):
            out.append(H)
    return out


def solve_in_spaces(spaces, v):
    if not spaces:
        return None
    cols = []
    for sp in spaces:
        cols.extend(sp["basis"])
    n = len(v)
    A = fmpq_mat(n, len(cols))
    for j, c in enumerate(cols):
        for i in range(n):
            A[i, j] = c[i]
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
    for k in range(1, limit + 1):
        for s in itertools.combinations(spaces, k):
            r = solve_in_spaces(list(s), v)
            if r is not None:
                return r
    if max_terms is None:
        return solve_in_spaces(spaces, v)
    return None


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
            terms.append(AlgebraicNumber.from_rational(Fraction(int(rational.p), int(rational.q))))
        degs = [t.degree for t in terms]
        return Decomposition("Plus", terms, degs, max(degs), lb,
                             dmax is None and (complete or max(degs) == lb), dmax is None, scope, method, extra)
    if dmax is None:
        return Decomposition("Plus", [a], [n], n, lb, complete, True, scope, "CompleteSearch", extra)
    return None


def sum_decomposition(a: AlgebraicNumber, dmax: Optional[int] = None, scope: str = "Global",
                      max_terms: Optional[int] = None, prec_bits: int = 300, maxorder: int = 400,
                      engine: str = "auto") -> Decomposition:
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1

    def trivial(method="Trivial", optimal=None):
        opt = (lb == n) if optimal is None else optimal
        return Decomposition("Plus", [a], [n], n, lb, opt, opt, scope, method)

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
            return trivial("CompleteSearch", True)
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
                es.append(-((v) // (d - i)) if v <= 0 else -(v // (d - i)))
                # ceil(-v/(d-i))
                es[-1] = -((v) // (d - i)) if False else math.ceil(Fraction(-v, d - i))
        if es:
            q *= Fraction(pr) ** max(es)
    return q


def nice_scale(p: fmpz_poly) -> Fraction:
    """rational q minimizing the height of the minimal polynomial of q*u, where p = minpoly(u)"""
    d = p.degree()
    coeffs = [Fraction(int(c)) for c in p.coeffs()]
    q0 = integral_scale(p)
    best, hb = q0, None
    cands = set()
    for k in range(1, 13):
        for l in range(1, 13):
            for s in (1, -1):
                cands.add(Fraction(s * k, l))
                cands.add(Fraction(s * l, k))
    for q in cands:
        qq = q * q0
        g = poly_from_fractions([coeffs[i] * qq ** (d - i) for i in range(d + 1)])
        gc = _fmpz_list(g.coeffs())
        h = (height(g), -(gc[0] > 0) + (gc[0] < 0), abs(math.log(abs(q))))
        if hb is None or h < hb:
            hb, best = h, qq
    return best


def scale_algebraic(u: AlgebraicNumber, q: Fraction, prec_bits: int) -> AlgebraicNumber:
    d = u.degree
    coeffs = [Fraction(int(c)) for c in u.poly.coeffs()]
    g = poly_from_fractions([coeffs[i] * q ** (d - i) for i in range(d + 1)])
    return AlgebraicNumber.from_value(g, u.value(prec_bits) * _fmpq_to_acb(fmpq(q.numerator, q.denominator)), prec_bits)


def root_of_algebraic(u: AlgebraicNumber, t: int, prec_bits: int) -> AlgebraicNumber:
    """principal t-th root of u as an algebraic number (irreducible factor of minpoly_u(x^t))"""
    if t == 1:
        return u
    coeffs = _fmpz_list(u.poly.coeffs())
    inflated = fmpz_poly([coeffs[i // t] if i % t == 0 else 0 for i in range(t * len(coeffs) - t + 1)])
    with ctx.workprec(prec_bits):
        uv = u.value(prec_bits)
        val = acb_poly([-uv] + [acb(0)] * (t - 1) + [acb(1)]).roots(tol=arb(2) ** (-(prec_bits - 20)))[0]
    for g, _ in inflated.factor()[1]:
        if g.degree() > 0 and acb_poly(g)(val).contains(0):
            return AlgebraicNumber.from_value(g, val, prec_bits)
    raise PrecisionError("t-th root not identified")


def quotient_algebraic(a: AlgebraicNumber, b: AlgebraicNumber, bt_over_field_poly: fmpz_poly, t: int, prec_bits: int) -> AlgebraicNumber:
    """c = a/b where c^t is known to have minimal polynomial bt_over_field_poly"""
    coeffs = _fmpz_list(bt_over_field_poly.coeffs())
    inflated = fmpz_poly([coeffs[i // t] if i % t == 0 else 0 for i in range(t * len(coeffs) - t + 1)])
    val = a.value(prec_bits) / b.value(prec_bits)
    for g, _ in inflated.factor()[1]:
        if g.degree() > 0 and acb_poly(g)(val).contains(0):
            return AlgebraicNumber.from_value(g, val, prec_bits)
    raise PrecisionError("quotient not identified")


def two_factor_search(fd, va, a: AlgebraicNumber, n: int, d: int, stab):
    tmax = min(d, d * d // n) if (stab is None and fd_is_galois(fd)) else 1
    Ma = fd_mult_matrix(fd, va)
    for t in range(1, tmax + 1):
        subs = [H for H in fd.subgroups if t * H["index"] <= d]
        if stab is not None:
            subs = [H for H in subs if stab <= H["elements"]]
        if not subs:
            continue
        Mt = Ma
        for _ in range(t - 1):
            Mt = Mt * Ma
        pairs = [(subs[i], subs[j]) for i in range(len(subs)) for j in range(i, len(subs))
                 if n <= t * subs[i]["index"] * subs[j]["index"]]
        pairs.sort(key=lambda pr: (max(pr[0]["index"], pr[1]["index"]), pr[0]["index"] + pr[1]["index"]))
        for E, F in pairs:
            res = _try_pair(fd, E, F, Mt, Ma, t, a, d, va)
            if res is not None:
                return res
    return None


def shortest_vector(ns, length):
    """LLL-reduce the integer nullspace basis and return the vector with the shortest E-part."""
    rows = []
    for v in ns:
        den = 1
        for q in v:
            den = den * int(q.q) // math.gcd(den, int(q.q))
        rows.append([int(q * den) for q in v])
    if len(rows) > 1:
        red = fmpz_mat(rows).lll()
        rows = [[int(red[i, j]) for j in range(red.ncols())] for i in range(red.nrows())]
    rows.sort(key=lambda r: sum(x * x for x in r[:length]))
    return [fmpq(x) for x in rows[0]]


def _try_pair(fd, E, F, Mt, Ma, t, a, d, va):
    ord_ = fd.order
    BE, BF = E["fixed"], F["fixed"]
    cols = len(BE) + len(BF)
    M = fmpq_mat(ord_, cols)
    for j, e in enumerate(BE):
        for i in range(ord_):
            M[i, j] = e[i]
    MF = [apply_matrix(Mt, f) for f in BF]
    for j, f in enumerate(MF):
        for i in range(ord_):
            M[i, len(BE) + j] = -f[i]
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
    at = va
    for _ in range(t - 1):
        at = apply_matrix(Ma, at)
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


def tensor_search(gd, va, d, stab):
    subs = [H for H in gd.subgroups if 1 < H["index"] <= d]
    if stab is not None:
        subs = [H for H in subs if stab <= H["elements"]]
    subs.sort(key=lambda H: H["index"])
    fams = families_with_product(subs, gd.order, 3)
    cache = {}
    for count, fam in enumerate(fams):
        if count > 400:
            break
        res = tensor_test(gd, fam, va, cache)
        if res is not None:
            return res
    return None


def _col_matrix(vectors, nrows):
    M = fmpq_mat(nrows, len(vectors))
    for j, v in enumerate(vectors):
        for i in range(nrows):
            if v[i] != 0:
                M[i, j] = v[i]
    return M


def _hstack(mats, nrows):
    cols = sum(m.ncols() for m in mats)
    out = fmpq_mat(nrows, cols)
    c = 0
    for m in mats:
        for j in range(m.ncols()):
            for i in range(nrows):
                out[i, c + j] = m[i, j]
        c += m.ncols()
    return out


def tensor_test(gd, fam, va, cache):
    ord_ = gd.order
    bases = [H["fixed"] for H in fam]
    dims = [len(B) for B in bases]
    mats = []
    for B in bases:
        row = []
        for b in B:
            key = tuple(b)
            if key not in cache:
                cache[key] = fd_mult_matrix(gd, b)
            row.append(cache[key])
        mats.append(row)
    # product basis: columns ordered lexicographically by (i_1, ..., i_r)
    current = _col_matrix([[fmpq(1)] + [fmpq(0)] * (ord_ - 1)], ord_)
    for j in range(len(fam)):
        current = _hstack([mats[j][i] * current for i in range(dims[j])], ord_)
    # columns are in order i_1-major with the FIRST factor varying slowest? we built (i_j outer, previous inner)
    # so column index = i_1 * (prod of later dims) ... reconstruct by recomputing the order:
    idx = list(itertools.product(*[range(k) for k in dims]))
    # current columns: for field j applied last, the outer loop is over i_j... rebuild mapping explicitly
    P = current
    if P.rank() < ord_:
        return None
    coords = fmpq_solve(P, _vec_fmpq(va))
    if coords is None:
        return None
    # column c corresponds to tuple: the hstack at stage j puts blocks by i_j with inner index from previous stage,
    # hence the LAST field index is the most significant digit.
    def col_of(tup):
        c = 0
        for j in range(len(fam)):
            c = c + tup[j] * (1 if j == 0 else 1)
        # compute explicitly: after stage j, column = i_j * (size before stage) + previous column
        col = 0
        size = 1
        for j in range(len(fam)):
            col = tup[j] * size + col
            size *= dims[j]
        return col
    tensor = {t: coords[col_of(t)] for t in idx}
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
    for d in dlist:
        two = two_factor_search(fd, va, a, n, d, stab)
        if two is not None:
            break
    best = None
    if two is not None:
        degs = [t.degree for t in two["terms"]]
        best = Decomposition("Times", two["terms"], degs, max(degs), lb, max(degs) == lb, dmax is None, scope,
                             "NormIntersection", dict(two_factor_optimal=(dmax is None and complete), t=two["t"], **extra))
    elif dmax is None:
        best = Decomposition("Times", [a], [n], n, lb, False, True, scope, "CompleteTwoFactorSearch",
                             dict(two_factor_optimal=complete, t=1, **extra))
    if max_factors == 2:
        return best
    if best is not None and best.max_degree == lb:
        return best
    if tensor:
        for d in dlist:
            if best is not None and d >= best.max_degree:
                break
            tens = tensor_search(fd, va, d, stab)
            if tens is not None:
                terms = clean_product_terms([fd_to_algebraic(fd, e) for e in tens], prec_bits)
                degs = [t.degree for t in terms]
                if best is None or max(degs) < best.max_degree:
                    best = Decomposition("Times", terms, degs, max(degs), lb, max(degs) == lb, False, scope,
                                         "TensorRankOne", dict(two_factor_optimal=False, t=1, **extra))
                break
    if best is not None and best.max_degree == lb:
        return best
    if best is not None and depth > 0 and len(best.terms) >= 2:
        terms = []
        for f in best.terms:
            if f.degree > lb:
                sub = product_decomposition(f, depth=depth - 1, tensor=tensor, prec_bits=prec_bits, maxorder=maxorder, engine=engine)
                terms.extend(sub.terms if sub is not None else [f])
            else:
                terms.append(f)
        degs = [t.degree for t in terms]
        if max(degs) < best.max_degree:
            best = Decomposition("Times", terms, degs, max(degs), lb, max(degs) == lb, False, scope,
                                 "RecursiveSplitting", dict(two_factor_optimal=False, t=1, **extra))
    if best is not None and best.max_degree > lb:
        for dd in range(lb, min(3, best.max_degree - 1) + 1):
            res = bounded_decomposition(a, "Times", dd, 3, 3)
            if res is not None and res.max_degree < best.max_degree:
                res.scope = scope
                best = res
                break
    return best


def product_decomposition(a: AlgebraicNumber, dmax: Optional[int] = None, scope: str = "Global",
                          max_factors: Optional[int] = None, depth: int = 3, tensor: bool = True,
                          prec_bits: int = 300, maxorder: int = 400, engine: str = "auto") -> Decomposition:
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1

    def trivial(method="Trivial", optimal=None):
        opt = (lb == n) if optimal is None else optimal
        return Decomposition("Times", [a], [n], n, lb, opt, opt, scope, method, {"two_factor_optimal": opt, "t": 1})

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
            return trivial("Trivial", True)
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
    q = nice_scale(rest[0].poly)
    rest[0] = scale_algebraic(rest[0], q, prec_bits)
    if q != 1:
        rest.append(AlgebraicNumber.from_rational(1 / q))
    return rest




# ---------------------------------------------------------------------------
# exact arithmetic on algebraic numbers via numerically computed composed
# polynomials (rigorously rounded), and the bounded dictionary search
# ---------------------------------------------------------------------------

def _integral_form(a: AlgebraicNumber):
    """(monic polynomial, scale c) with c*a a root of the monic polynomial"""
    p = a.poly
    n = p.degree()
    c = int(p.leading_coefficient())
    coeffs = _fmpz_list(p.coeffs())
    mon = fmpz_poly([coeffs[i] * c ** (n - 1 - i) for i in range(n)] + [1])
    return mon, c


def combine_algebraic(a: AlgebraicNumber, b: AlgebraicNumber, op: str, prec_bits: int = 300) -> AlgebraicNumber:
    """a+b, a-b, a*b or a/b as an algebraic number"""
    if op == "/":
        # b^{-1}: reverse the polynomial
        coeffs = _fmpz_list(b.poly.coeffs())[::-1]
        binv = AlgebraicNumber.from_value(primitive(fmpz_poly(coeffs)), 1 / b.value(prec_bits), prec_bits)
        return combine_algebraic(a, binv, "*", prec_bits)
    if op == "-":
        coeffs = _fmpz_list(b.poly.coeffs())
        neg = fmpz_poly([(-1) ** i * coeffs[i] for i in range(len(coeffs))])
        bneg = AlgebraicNumber.from_value(primitive(neg), -b.value(prec_bits), prec_bits)
        return combine_algebraic(a, bneg, "+", prec_bits)
    ma, ca = _integral_form(a)
    mb, cb = _integral_form(b)
    prec = prec_bits
    for attempt in range(6):
        try:
            with ctx.workprec(prec):
                ra = poly_roots(ma, prec)
                rb = poly_roots(mb, prec)
                if op == "+":
                    vals = [cb * x + ca * y for x in ra for y in rb]   # ca*cb*(a_i + b_j)
                    scale = ca * cb
                else:
                    vals = [x * y for x in ra for y in rb]             # ca*cb*(a_i*b_j)
                    scale = ca * cb
                comp = _round_poly(_poly_from_roots(vals))
                target = (a.value(prec) + b.value(prec)) if op == "+" else a.value(prec) * b.value(prec)
                tv = target * scale
                for g, _ in comp.factor()[1]:
                    if g.degree() > 0 and acb_poly(g)(tv).contains(0):
                        # descale: g(scale*x)
                        gc = _fmpz_list(g.coeffs())
                        q = poly_from_fractions([Fraction(gc[i]) * Fraction(scale) ** i for i in range(len(gc))])
                        cand = AlgebraicNumber.from_value(q, target, prec)
                        if (cand.value(prec) - target).contains(0):
                            return cand
                raise PrecisionError("factor not identified")
        except PrecisionError:
            prec *= 2
    raise PrecisionError("combine_algebraic failed")


def catalog(d: int, h: int) -> list:
    """roots of all irreducible primitive integer polynomials of degree <= d and height <= h"""
    out = []
    for m in range(1, d + 1):
        for coeffs in itertools.product(range(-h, h + 1), repeat=m + 1):
            if coeffs[-1] <= 0:
                continue
            g = 0
            for c in coeffs:
                g = math.gcd(g, abs(c))
            if g != 1:
                continue
            p = fmpz_poly(list(coeffs))
            fac = p.factor()[1]
            if len(fac) != 1 or fac[0][1] != 1:
                continue
            for k in range(1, m + 1):
                out.append(AlgebraicNumber(p, k))
    return out


def bounded_decomposition(a: AlgebraicNumber, op: str, d: int, h: int, r: int, prec_bits: int = 300):
    """Decomposition of a into at most r components of degree <= d, all but the last from the catalog."""
    n = a.degree
    lb = lower_bound(a.poly) if n > 1 else 1
    if n <= d:
        return Decomposition(op, [a], [n], n, lb, lb == n, True, "Bounded", "Trivial")
    cat = [c for c in catalog(d, h) if c.degree > 1]
    if op == "Times":
        cat = [c for c in cat if c.as_fraction() != 0]

    def residual(prefix):
        res = a
        for b in prefix:
            res = combine_algebraic(res, b, "-" if op == "Plus" else "/", prec_bits)
        return res

    def search(prefix, start, slots):
        res = residual(prefix)
        deg = res.degree
        if deg <= d:
            return prefix + [res]
        if slots <= 1 or deg > d ** slots or largest_prime_factor(deg) > d:
            return None
        for i in range(start, len(cat)):
            found = search(prefix + [cat[i]], i, slots - 1)
            if found is not None:
                return found
        return None

    found = search([], 0, r)
    if found is None:
        return None
    degs = [t.degree for t in found]
    return Decomposition(op, found, degs, max(degs), lb, max(degs) == lb, False, "Bounded", "DictionarySearch")

# ---------------------------------------------------------------------------
# numeric verification
# ---------------------------------------------------------------------------

def verify_numeric(a: AlgebraicNumber, dec: Decomposition, prec_bits: int = 300) -> bool:
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


# ---------------------------------------------------------------------------
# command line demo
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
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
