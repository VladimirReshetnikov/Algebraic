"""SystematicRadicals 1.0 -- exact radical towers over QQ (Python >=3.10).

Requires SymPy >=1.14. No Sage, PARI, network service, or numerical
recognition is needed for the general construction. See the accompanying
article for guarantees, branch conventions, and intentionally modest defaults.

The public solve_polynomial() input must be an irreducible polynomial over QQ.
solve_root() first selects the appropriate irreducible factor and uses SymPy's
zero-based CRootOf ordering, NOT Mathematica's Root ordering.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from functools import lru_cache
from itertools import count
from math import gcd, isfinite
import argparse
import json
import multiprocessing as mp
import sys
import time
from typing import Any, Optional

import sympy as s
from sympy.combinatorics import Permutation, PermutationGroup
from sympy.matrices.exceptions import NonInvertibleMatrixError
from sympy.polys.polyerrors import PolynomialError

__version__ = "1.0.0"
_X, _T = s.symbols("_x _theta")


class RadicalError(Exception):
    status = "BackendError"
    def __init__(self, message: str, **details: Any):
        super().__init__(message)
        self.details = details


class NotSolvable(RadicalError):
    status = "NotSolvable"


class ResourceLimit(RadicalError):
    status = "ResourceLimit"


class NotFound(RadicalError):
    status = "NotFound"


class InvalidInput(RadicalError):
    status = "InvalidInput"


class CertificateError(RadicalError):
    status = "CertificateError"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CertificateError(message)


@dataclass
class Limits:
    max_field_degree: Optional[int] = 48
    max_seconds: Optional[float] = 120.0
    start: float = field(default_factory=time.monotonic)

    def check(self, degree: Optional[int] = None) -> None:
        if self.max_field_degree is not None and degree is not None:
            if degree > self.max_field_degree:
                raise ResourceLimit("Field-degree budget exceeded", requested=degree,
                                    maximum=self.max_field_degree)
        if self.max_seconds is not None and time.monotonic()-self.start > self.max_seconds:
            raise ResourceLimit("Cooperative time budget exceeded")


def _poly(f: Any, x: Optional[s.Symbol] = None) -> s.Poly:
    try:
        p = f if isinstance(f, s.Poly) else s.Poly(f, x) if x is not None else s.Poly(f)
        if len(p.gens) != 1 or p.as_expr().has(s.Float):
            raise InvalidInput("Expected one variable and exact rational coefficients")
        p = p.set_domain(s.QQ)
    except (s.PolynomialError, s.CoercionFailed, s.GeneratorsNeeded, ValueError) as e:
        raise InvalidInput("Expected an exact univariate polynomial over QQ") from e
    if p.degree() < 1:
        raise InvalidInput("The polynomial must be nonconstant")
    return s.Poly.from_list(p.monic().all_coeffs(), _X, domain=s.QQ)


def _q(q: Any) -> s.Rational:
    return s.Rational(q.numerator, q.denominator)


def _qjson(q: Any) -> list[str]:
    q = s.Rational(q)
    return [str(q.p), str(q.q)]


def _parseq(q: Any) -> s.Rational:
    if not isinstance(q, list) or len(q) != 2:
        raise InvalidInput("A rational coefficient is [integer numerator, positive denominator]")
    if any(isinstance(v, bool) or not isinstance(v, (str, int)) for v in q):
        raise InvalidInput("Invalid rational coefficient")
    try:
        a, b = map(int, q)
    except (ValueError, TypeError) as e:
        raise InvalidInput("Invalid integer in rational coefficient") from e
    if b <= 0:
        raise InvalidInput("Denominators must be positive")
    return s.Rational(a, b)


def root_unity(n: int) -> s.Expr:
    """exp(2*pi*I/n), written using only a principal rational power."""
    if n < 1:
        raise InvalidInput("Root-of-unity order must be positive")
    return s.Pow(s.Integer(-1), s.Rational(2, n))


def radical_expression_q(e: s.Expr, symbols: set[s.Symbol] | None = None) -> bool:
    symbols = set() if symbols is None else symbols
    if e.is_Rational or e == s.I or e in symbols:
        return True
    if e.is_Add or e.is_Mul:
        return all(radical_expression_q(a, symbols) for a in e.args)
    return bool(e.is_Pow and e.exp.is_Rational and radical_expression_q(e.base, symbols))


def dickson(n: int, x: s.Expr, a: s.Expr) -> s.Expr:
    if n == 0:
        return s.Integer(2)
    u, v = s.Integer(2), x
    for _ in range(2, n+1):
        u, v = v, s.expand(x*v-a*u)
    return v


def _rational_roots_of_power(q: s.Rational, k: int) -> list[s.Rational]:
    if q < 0 and k % 2 == 0:
        return []
    a, ea = s.integer_nthroot(abs(int(q.p)), k)
    b, eb = s.integer_nthroot(int(q.q), k)
    if not (ea and eb):
        return []
    v = s.Rational(a, b)
    if q < 0:
        v = -v
    return [v, -v] if k % 2 == 0 and v != 0 else [v]


def _fast(p: s.Poly, limits: Limits, depth: int = 0) -> tuple[list[s.Expr], str] | None:
    """Recognized exact identities, never approximate radical recognition."""
    limits.check()
    n = p.degree()
    if depth > 32:
        return None
    if n <= 4:
        roots = s.roots(p.as_expr(), _X, multiple=True, cubics=True, quartics=True,
                        quintics=False)
        if len(roots) == n and all(radical_expression_q(r) for r in roots):
            return list(roots), "DegreeAtMostFour"
    shift = -p.nth(n-1)/n
    q = s.Poly(p.as_expr().subs(_X, _X+shift).expand(), _X, domain=s.QQ)
    # Power composition, including shifted binomials.
    exps = [mon[0] for mon, c in q.terms() if mon[0] > 0 and c != 0]
    m = 0
    for e in exps:
        m = gcd(m, e)
    if m > 1:
        g = s.Poly.from_dict({(mon[0]//m,): c for mon, c in q.terms()}, _X, domain=s.QQ)
        ans = _fast(g, limits, depth+1)
        if ans is not None:
            z = root_unity(m)
            return [shift+z**k*s.Pow(v, s.Rational(1, m))
                    for v in ans[0] for k in range(m)], "PowerComposition/"+ans[1]
    # A translated Dickson polynomial D_n(x,a)+b.
    if n >= 3:
        a = -q.nth(n-2)/n
        d = dickson(n, _X, a)
        rem = s.Poly(q.as_expr()-d, _X)
        if rem.degree() <= 0:
            b = rem.nth(0)
            z = (-b+s.sqrt(b*b-4*a**n))/2
            if z == 0:
                z = (-b-s.sqrt(b*b-4*a**n))/2
            if z != 0:
                u, w = s.Pow(z, s.Rational(1, n)), root_unity(n)
                return [shift+w**k*u+a/(w**k*u) for k in range(n)], "Dickson"
    # f(x)=x^m*g(x+a/x); work with the unshifted polynomial as well.
    for v, off in [(p, s.S.Zero), (q, shift)]:
        if n % 2 or v.nth(0) == 0:
            continue
        m = n//2
        candidates: list[s.Rational] = []
        for k in range(1, m+1):
            hi, lo = v.nth(m+k), v.nth(m-k)
            if hi:
                candidates = _rational_roots_of_power(s.Rational(lo/hi), k)
                break
        for a in candidates:
            if a == 0 or any(v.nth(m-k) != a**k*v.nth(m+k) for k in range(1, m+1)):
                continue
            g = s.Poly(v.nth(m)+sum(v.nth(m+k)*dickson(k, _X, a)
                                   for k in range(1, m+1)), _X, domain=s.QQ)
            ans = _fast(g, limits, depth+1)
            if ans is not None:
                return [off+(t+eps*s.sqrt(t*t-4*a))/2
                        for t in ans[0] for eps in [1, -1]], "Reciprocal/"+ans[1]
    return None


class NumberField:
    """Abstract QQ[t]/P, with no chosen complex embedding."""
    def __init__(self, polynomial: s.Poly):
        self.poly = s.Poly.from_list(polynomial.monic().all_coeffs(), _T, domain=s.QQ)
        self.degree = self.poly.degree()
        self.K = s.QQ.algebraic_field((self.poly, _T))
        self.zero, self.one, self.t = self.K.zero, self.K.one, self.K.unit

    def scalar(self, q: Any):
        return self.K.convert(q)

    def key(self, a) -> tuple:
        return tuple(a.to_list())

    def vector(self, a) -> s.Matrix:
        cs = list(reversed(a.to_list()))
        return s.Matrix([_q(c) for c in cs]+[s.S.Zero]*(self.degree-len(cs)))

    def from_vector(self, cs):
        return self.K.new([s.QQ.convert(c) for c in reversed(list(cs))])

    def evaluate(self, coeffs_desc, a):
        v = self.zero
        for c in coeffs_desc:
            v = v*a+self.scalar(c)
        return v

    def apply(self, image, a):
        return self.evaluate(a.to_list(), image)

    def factors(self, p: s.Poly):
        cs = [self.scalar(c) for c in p.all_coeffs()]
        P = s.Poly.from_dict({(len(cs)-1-i,): c for i, c in enumerate(cs)}, (_X,), domain=self.K)
        _, fs = P.rep.factor_list()
        return [(tuple(h.to_list()), m) for h, m in fs]

    def linear_roots(self, p: s.Poly):
        fs = self.factors(p)
        if any(len(h) != 2 for h, _ in fs):
            return None
        return sorted([-h[1]/h[0] for h, m in fs for _ in range(m)], key=self.key)

    def adjoin(self, h_desc, limits: Limits) -> "NumberField":
        """Adjoin a root of an irreducible monic h over this field.

        In the quotient basis t^i*y^j, find a primitive t+c*y by exact
        rational linear algebra. Irreducibility of h is supplied by factor().
        """
        m, d = len(h_desc)-1, self.degree
        N = m*d
        limits.check(N)
        hc = list(reversed([v/h_desc[0] for v in h_desc]))[:-1]
        zero = tuple(self.zero for _ in range(m))
        one = (self.one,)+zero[1:]
        tv = (self.t,)+zero[1:]
        def mul(a, b):
            c = [self.zero]*(2*m-1)
            for i in range(m):
                for j in range(m):
                    c[i+j] += a[i]*b[j]
            for k in range(2*m-2, m-1, -1):
                for j in range(m):
                    c[k-m+j] -= c[k]*hc[j]
            return tuple(c[:m])
        def vec(a):
            return s.Matrix.vstack(*(self.vector(v) for v in a))
        for c in count(1):
            limits.check(N)
            w = list(tv)
            w[1] = self.scalar(c)
            w = tuple(w)
            powers = [one]
            for _ in range(N):
                powers.append(mul(powers[-1], w))
            B = s.Matrix.hstack(*(vec(a) for a in powers[:-1]))
            try:
                C = B.inv(method="DM") * s.Matrix.hstack(vec(powers[-1]), vec(tv))
            except NonInvertibleMatrixError:
                continue
            P = s.Poly(_T**N-sum(C[k, 0]*_T**k for k in range(N)), _T, domain=s.QQ)
            out = NumberField(P)
            image_t = out.from_vector(C[:, 1])
            image_y = (out.t-image_t)/out.scalar(c)
            require(out.evaluate(self.poly.all_coeffs(), image_t) == out.zero,
                    "Primitive-element embedding failed")
            hnew = [out.evaluate(v.to_list(), image_t) for v in h_desc]
            r = out.zero
            for v in hnew:
                r = r*image_y+v
            require(r == out.zero, "Adjoined-root relation failed")
            return out
        raise CertificateError("Unreachable primitive-element search exit")


def _normal_closure(p: s.Poly, limits: Limits, log: list[dict]) -> NumberField:
    limits.check(p.degree())
    F = NumberField(p)
    while True:
        limits.check(F.degree)
        fs = F.factors(p)
        nonlinear = [h for h, _ in fs if len(h) > 2]
        log.append({"stage": "splitting", "field_degree": F.degree,
                    "factor_degrees": [len(h)-1 for h, _ in fs]})
        if not nonlinear:
            return F
        h = min(nonlinear, key=lambda h: (len(h), str(h)))
        F = F.adjoin(h, limits)


def _normalize_element(F: NumberField, r):
    cs = [_q(q) for q in r.to_list()]
    den = s.ilcm(*[int(c.q) for c in cs]) if len(cs) > 1 else int(cs[0].q)
    ints = [int(c*den) for c in cs]
    g = 0
    for c in ints:
        g = gcd(g, abs(c))
    return r*F.scalar(s.Rational(den, g))


@dataclass
class RadicalSolution:
    polynomial: s.Poly
    assignments: list[tuple[s.Symbol, s.Expr]]
    outputs: list[s.Expr]
    method: str
    diagnostics: dict = field(default_factory=dict)
    certificate: dict | None = None

    def expanded_roots(self) -> list[s.Expr]:
        env: dict = {}
        for symbol, rhs in self.assignments:
            env[symbol] = rhs.xreplace(env)
        return [e.xreplace(env) for e in self.outputs]

    def json(self, include_certificate: bool = False) -> dict:
        refs = {v: i for i, (v, _) in enumerate(self.assignments)}
        out = {"status": "Success", "version": __version__, "method": self.method,
               "coefficients": [_qjson(c) for c in self.polynomial.all_coeffs()],
               "assignments": [encode_expr(e, refs) for _, e in self.assignments],
               "roots": [encode_expr(e, refs) for e in self.outputs],
               "diagnostics": self.diagnostics}
        if include_certificate and self.certificate is not None:
            out["certificate"] = self.certificate
        return out


def encode_expr(e: s.Expr, refs: dict[s.Symbol, int]) -> list:
    if e in refs:
        return ["Ref", refs[e]]
    if e.is_Rational:
        return ["Q", str(e.p), str(e.q)]
    if e == s.I:
        return ["Pow", ["Q", "-1", "1"], "1", "2"]
    if e.is_Add or e.is_Mul:
        return ["Add" if e.is_Add else "Mul", *[encode_expr(a, refs) for a in e.args]]
    if e.is_Pow and e.exp.is_Rational:
        return ["Pow", encode_expr(e.base, refs), str(e.exp.p), str(e.exp.q)]
    raise CertificateError("Output is not in the radical grammar", expression=str(e))


def _tower(p: s.Poly, limits: Limits) -> RadicalSolution:
    log: list[dict] = []
    F = _normal_closure(p, limits, log)
    original_degree = F.degree
    M = int(s.prod(s.factorint(original_degree)))
    phi = s.Poly(s.cyclotomic_poly(M, _X), _X, domain=s.QQ)
    fs = F.factors(phi)
    linear = [h for h, _ in fs if len(h) == 2]
    if not linear:
        F = F.adjoin(min((h for h, _ in fs), key=lambda h: (len(h), str(h))), limits)
    zroots = F.linear_roots(phi)
    require(zroots is not None, "Cyclotomic polynomial did not split in compositum")
    z = zroots[0]
    roots = F.linear_roots(p)
    require(roots is not None and len(roots) == p.degree(), "Missing polynomial roots")
    autos = F.linear_roots(F.poly)
    require(autos is not None and len(autos) == F.degree, "Constructed field is not normal")
    autos = [a for a in autos if F.apply(a, z) == z]
    Horder = len(autos)
    require(Horder*phi.degree() == F.degree, "Wrong cyclotomic stabilizer size")
    limits.check(F.degree)
    key_to_i = {F.key(a): i for i, a in enumerate(autos)}
    identity = key_to_i[F.key(F.t)]
    table = []
    for a in autos:
        limits.check()
        table.append([key_to_i[F.key(F.apply(a, b))] for b in autos])
    perms = [Permutation([table[j][i] for j in range(Horder)]) for i in range(Horder)]
    G = PermutationGroup(perms)
    require(G.order() == Horder, "Regular representation has the wrong order")
    derived_orders = [int(g.order()) for g in G.derived_series()]
    if not G.is_solvable:
        raise NotSolvable("The exact cyclotomic stabilizer is nonsolvable",
                          group_order=Horder, derived_orders=derived_orders,
                          splitting_field_degree=original_degree)
    series = G.composition_series()
    groups = [sorted({g(identity) for g in H.generate_schreier_sims()}) for H in series]
    require(len(groups[-1]) == 1, "Composition series must end at the identity")
    rs, ps, sigmas = [], [], []
    for outer, inner in zip(groups, groups[1:]):
        limits.check()
        prime = len(outer)//len(inner)
        require(s.isprime(prime) and len(outer) == prime*len(inner), "Nonprime series factor")
        si = next(i for i in outer if i not in inner)
        sigma = autos[si]
        zp = z**(M//prime)
        r = F.zero
        for k in range(F.degree):
            b = sum((autos[h]**k for h in inner), F.zero)
            u = b
            r = F.zero
            for j in range(prime):
                r += zp**(-j)*u
                u = F.apply(sigma, u)
            if r != F.zero:
                r = _normalize_element(F, r)
                break
        require(r != F.zero, "All Lagrange projectors vanished")
        require(F.apply(sigma, r) == zp*r, "Wrong Lagrange eigenvalue")
        require(all(F.apply(autos[h], r) == r for h in inner), "Resolvent is not in fixed field")
        require(all(F.apply(autos[h], r**prime) == r**prime for h in outer),
                "Resolvent power did not descend")
        rs.append(r); ps.append(prime); sigmas.append(sigma)
    B = s.Matrix.hstack(*(F.vector(z**j) for j in range(phi.degree())))
    pivot_rows = list(B.T.rref()[1])
    require(len(pivot_rows) == phi.degree(), "Cyclotomic generator has wrong degree")
    Binv = B.extract(pivot_rows, list(range(phi.degree()))).inv(method="DM")
    zsymbol = s.Symbol("zeta")
    symbols = [s.Symbol(f"r{i+1}") for i in range(len(rs))]
    @lru_cache(maxsize=None)
    def express(level: int, key: tuple) -> s.Expr:
        limits.check()
        a = F.K.new(list(key))
        if len(a.to_list()) <= 1:
            return _q(a.to_list()[0]) if a.to_list() else s.S.Zero
        if level == 0:
            vec = F.vector(a)
            c = Binv*vec.extract(pivot_rows, [0])
            require(B*c == vec, "Element did not reach cyclotomic base")
            return s.Add(*(c[j]*zsymbol**j for j in range(phi.degree())))
        outer = groups[level-1]
        if all(F.apply(autos[h], a) == a for h in outer):
            return express(level-1, key)
        r, prime, sigma = rs[level-1], ps[level-1], sigmas[level-1]
        coeffs = []
        reconstructed = F.zero
        for j in range(prime):
            u = a/(r**j)
            c = F.zero
            for _ in range(prime):
                c += u
                u = F.apply(sigma, u)
            c = c/F.scalar(prime)
            reconstructed += c*r**j
            coeffs.append(express(level-1, F.key(c)))
        require(reconstructed == a, "Fourier-coordinate reconstruction failed")
        return s.Add(*(coeffs[j]*symbols[level-1]**j for j in range(prime)))
    assignments = [(zsymbol, root_unity(M))]
    radicands = []
    for i, (r, prime) in enumerate(zip(rs, ps)):
        rhs = express(i, F.key(r**prime))
        radicands.append(rhs)
        assignments.append((symbols[i], s.Pow(rhs, s.Rational(1, prime))))
    outputs = [express(len(rs), F.key(r)) for r in roots]
    refs = {a: i for i, (a, _) in enumerate(assignments)}
    def witness(a):
        return [_qjson(v) for v in F.vector(a)]
    cert = {
        "field_polynomial": [_qjson(c) for c in F.poly.all_coeffs()],
        "polynomial": [_qjson(c) for c in p.all_coeffs()],
        "cyclotomic_order": M, "zeta_witness": witness(z),
        "primes": ps, "radical_witnesses": [witness(r) for r in rs],
        "radicands": [encode_expr(v, refs) for v in radicands],
        "root_witnesses": [witness(r) for r in roots],
        "outputs": [encode_expr(v, refs) for v in outputs]
    }
    return RadicalSolution(p, assignments, outputs, "GaloisTower", {
        "splitting_field_degree": original_degree, "cyclotomic_order": M,
        "working_field_degree": F.degree, "stabilizer_order": Horder,
        "composition_orders": [len(g) for g in groups], "prime_steps": ps,
        "derived_orders": derived_orders, "field_construction": log,
        "verification": "Exact field identities; optional independent certificate checker"
    }, cert)


def verify_certificate(cert: dict, expected_polynomial: Any = None) -> bool:
    """Check a positive tower certificate without reconstructing the Galois group.

    This checker uses rational arithmetic, polynomial irreducibility, and linear
    independence. It verifies a complete SET of roots, not an external root index.
    """
    try:
        P = s.Poly.from_list([_parseq(q) for q in cert["field_polynomial"]], _T, domain=s.QQ)
        require(P.is_irreducible, "Certificate field polynomial is reducible")
        F = NumberField(P)
        p = s.Poly.from_list([_parseq(q) for q in cert["polynomial"]], _X, domain=s.QQ)
        require(p.degree() >= 1, "Certificate polynomial is constant")
        if expected_polynomial is not None:
            require(p.monic() == _poly(expected_polynomial), "Certificate is for a different polynomial")
        def element(v):
            require(len(v) == F.degree, "Incorrect witness vector length")
            return F.from_vector([_parseq(q) for q in v])
        M = int(cert["cyclotomic_order"])
        require(M >= 1, "Invalid cyclotomic order")
        z = element(cert["zeta_witness"])
        phi = s.Poly(s.cyclotomic_poly(M, _X), _X)
        require(F.evaluate(phi.all_coeffs(), z) == F.zero, "Invalid root of unity")
        env = [z]
        def ev(ast):
            tag = ast[0]
            if tag == "Q":
                return F.scalar(_parseq(ast[1:]))
            if tag == "Ref":
                require(isinstance(ast[1], int) and 0 <= ast[1] < len(env), "Forward reference")
                return env[ast[1]]
            if tag in ("Add", "Mul"):
                v = F.zero if tag == "Add" else F.one
                for child in ast[1:]:
                    v = v+ev(child) if tag == "Add" else v*ev(child)
                return v
            if tag == "Pow":
                e = _parseq(ast[2:])
                require(e.q == 1, "A coordinate body contains a noninteger power")
                return ev(ast[1])**int(e)
            raise CertificateError("Invalid certificate expression")
        basis = [z**j for j in range(phi.degree())]
        primes, witnesses, radicands = cert["primes"], cert["radical_witnesses"], cert["radicands"]
        require(len(primes) == len(witnesses) == len(radicands), "Inconsistent tower lengths")
        for prime, rw, rhs in zip(primes, witnesses, radicands):
            require(isinstance(prime, int) and s.isprime(prime), "Nonprime radical step")
            r = element(rw)
            require(r != F.zero and r**prime == ev(rhs), "Incorrect radical-power identity")
            basis = [b*r**j for j in range(prime) for b in basis]
            env.append(r)
        require(len(basis) == F.degree, "Tower degree does not equal field degree")
        require(s.Matrix.hstack(*(F.vector(v) for v in basis)).det(method="domain-ge") != 0,
                "Tower monomials are linearly dependent")
        roots = [element(v) for v in cert["root_witnesses"]]
        require(len(roots) == p.degree() == len(cert["outputs"]), "Wrong number of roots")
        require(len({F.key(v) for v in roots}) == p.degree(), "Repeated root witness")
        for a, ast in zip(roots, cert["outputs"]):
            require(ev(ast) == a, "Incorrect output coordinates")
            require(F.evaluate(p.all_coeffs(), a) == F.zero, "Output is not a root")
        return True
    except (KeyError, IndexError, TypeError, ValueError) as e:
        raise CertificateError("Malformed certificate") from e


def solve_polynomial(f: Any, x: Optional[s.Symbol] = None, *, method: str = "auto",
                     max_field_degree: Optional[int] = 48,
                     max_seconds: Optional[float] = 120.0,
                     verify: bool = False) -> RadicalSolution:
    """All roots of one irreducible QQ polynomial, as a radical straight-line program.

    method='auto': fast identities, then exact Galois construction.
    method='galois': force the general construction (except rational roots).
    method='fast': recognized identities only; a miss is NotFound, not NotSolvable.
    Set both limits to None for the ideal unbounded algorithm. The library time
    limit is cooperative; the JSON command-line wrapper uses a hard worker limit.
    """
    if method not in {"auto", "galois", "fast"}:
        raise InvalidInput("method must be auto, galois, or fast")
    if max_field_degree is not None and (isinstance(max_field_degree, bool) or not isinstance(max_field_degree, int) or max_field_degree < 1):
        raise InvalidInput("max_field_degree must be positive or None")
    if max_seconds is not None and (isinstance(max_seconds, bool) or not isinstance(max_seconds, (int, float)) or not isfinite(max_seconds) or max_seconds <= 0):
        raise InvalidInput("max_seconds must be positive or None")
    limits = Limits(max_field_degree, max_seconds)
    p = _poly(f, x)
    if not p.is_irreducible:
        raise InvalidInput("solve_polynomial expects an irreducible polynomial; use solve_root for a selected root")
    if p.degree() == 1:
        return RadicalSolution(p, [], [-p.nth(0)], "Rational")
    if method != "galois":
        ans = _fast(p, limits)
        if ans is not None:
            return RadicalSolution(p, [], ans[0], ans[1], {"verification": "Recognized exact polynomial identities"})
        if method == "fast":
            raise NotFound("No fast-path identity applies; this is not a nonsolvability result")
    # Cheap exact rejection for the degrees covered by SymPy's public routine.
    # Its second return value means 'contained in A_n', NOT 'is solvable'.
    if 2 <= p.degree() <= 6:
        try:
            G, _ = s.polys.numberfields.galois_group(p)
        except (ValueError, NotImplementedError, s.polys.numberfields.galoisgroups.MaxTriesException):
            G = None
        if G is not None and not G.is_solvable:
            raise NotSolvable("The irreducible polynomial has nonsolvable Galois group",
                              group_order=int(G.order()),
                              derived_orders=[int(h.order()) for h in G.derived_series()])
    result = _tower(p, limits)
    if verify and result.certificate:
        verify_certificate(result.certificate, p)
        result.diagnostics["independent_certificate_check"] = True
    return result


def solve_root(f: Any, index: int, x: Optional[s.Symbol] = None, **kwargs) -> s.Expr:
    """One root, using SymPy CRootOf's ZERO-BASED index, including reducible input.

    The minimal factor is selected before testing solvability. same_root uses a
    separation bound and bounded-error evaluation, not a fixed tolerance. Its
    input-root precondition is supplied by our algebraic construction.
    """
    p = _poly(f, x)
    if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index < p.degree():
        raise InvalidInput("Root index is outside the zero-based polynomial range")
    target = s.CRootOf(p.as_expr(), index)
    if target.is_Rational:
        return target
    q = s.Poly(s.minpoly(target, _X), _X, domain=s.QQ).monic()
    result = solve_polynomial(q, **kwargs)
    for r in result.expanded_roots():
        if q.same_root(r, target):
            return r
    raise CertificateError("No constructed root matched the selected root")


def _request(request: dict) -> dict:
    if not isinstance(request, dict):
        raise InvalidInput("Expected a JSON object")
    cs = request.get("coefficients")
    if not isinstance(cs, list) or len(cs) < 2:
        raise InvalidInput("coefficients must be a high-to-low list of rational pairs")
    p = s.Poly.from_list([_parseq(c) for c in cs], _X, domain=s.QQ)
    result = solve_polynomial(p, method=request.get("method", "auto"),
        max_field_degree=request.get("max_field_degree", 48),
        max_seconds=request.get("max_seconds", 120.0), verify=request.get("verify", False))
    return result.json(include_certificate=bool(request.get("certificate", False)))


def _worker(request: dict, conn) -> None:
    try:
        data = _request(request)
    except RadicalError as e:
        data = {"status": e.status, "message": str(e), "details": e.details}
    except Exception as e:
        data = {"status": "BackendError", "message": f"{type(e).__name__}: {e}"}
    try:
        conn.send(data)
    finally:
        conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Read one coefficient request from stdin")
    args = parser.parse_args()
    if not args.json:
        parser.print_help()
        return 0
    try:
        request = json.load(sys.stdin)
        timeout = request.get("max_seconds", 120.0)
        if timeout is not None and (isinstance(timeout, bool) or not isinstance(timeout, (int, float)) or not isfinite(timeout) or timeout <= 0):
            raise InvalidInput("max_seconds must be positive or null")
        ctx = mp.get_context("spawn")
        parent, child = ctx.Pipe(duplex=False)
        process = ctx.Process(target=_worker, args=(request, child))
        process.start(); child.close()
        if parent.poll(timeout):
            try:
                result = parent.recv()
            except EOFError:
                result = {"status": "BackendError", "message": "Worker exited without a result"}
            process.join(2)
        else:
            result = {"status": "ResourceLimit", "message": "Hard wall-clock limit exceeded"}
        if process.is_alive():
            process.terminate(); process.join(2)
        if process.is_alive():
            process.kill(); process.join()
        parent.close()
    except (RadicalError, ValueError, AttributeError, TypeError) as e:
        result = {"status": getattr(e, "status", "InvalidInput"), "message": str(e)}
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result.get("status") == "Success" else 2


if __name__ == "__main__":
    raise SystemExit(main())
