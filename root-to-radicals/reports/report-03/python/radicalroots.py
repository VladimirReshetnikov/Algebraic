"""Exact radical conversion over QQ; Python 3.10+, SymPy 1.14.

Root indices are SymPy's ZERO-based indices, NOT Mathematica indices.
The fast layer is independent of the general (expensive) splitting-field layer.
Successful conversions use exact minimal polynomials and certified root separation.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from functools import reduce, lru_cache
from math import gcd
from typing import Any, Iterable
import sympy as s


class RadicalError(Exception):
    """A backend failure, never evidence of nonsolvability."""


class ResourceLimit(RadicalError):
    pass


class NotSolvable(RadicalError):
    """Raised only after an exact nonsolvable-group calculation."""


@dataclass
class RadicalResult:
    status: str
    expression: s.Expr | None = None
    method: str = ""
    verified: bool = False
    details: dict[str, Any] = field(default_factory=dict)


def radical_q(a: s.Expr) -> bool:
    """Strict syntax: rationals, I, arithmetic, rational powers; no RootOf/trig."""
    a = s.sympify(a)
    if a.is_Rational or a == s.I:
        return True
    if isinstance(a, (s.Add, s.Mul)):
        return all(radical_q(v) for v in a.args)
    return isinstance(a, s.Pow) and a.exp.is_Rational and radical_q(a.base)


def plain_expression(a: s.Expr) -> s.Expr:
    """Remove AlgebraicNumber wrappers without changing the chosen embedding."""
    a = s.sympify(a)
    return a.replace(lambda t: isinstance(t, s.AlgebraicNumber),
                     lambda t: t.as_expr())


_MP_VARIABLE = s.Dummy("minimal_polynomial_variable")


@lru_cache(maxsize=512)
def _minimal_polynomial(a: s.Expr) -> s.Poly:
    return s.Poly(s.minpoly(a, _MP_VARIABLE), _MP_VARIABLE, domain=s.QQ).monic()


def exact_equal(a: s.Expr, b: s.Expr) -> bool:
    """CAS-certified algebraic equality, not a fixed-tolerance comparison.

    Equal minimal polynomials are necessary but insufficient. Poly.same_root
    then uses a polynomial root-separation bound and bounded-error evaluation
    to distinguish embeddings. This avoids treating the default real PSLQ
    path of to_number_field as an independent branch certificate.
    Unexpected backend failures propagate rather than becoming False.
    """
    a, b = plain_expression(a), plain_expression(b)
    if a == b:
        return True
    if a.is_Rational and b.is_Rational:
        return False
    f, g = _minimal_polynomial(a), _minimal_polynomial(b)
    if f != g:
        return False
    if f.degree() == 1:
        return True
    return bool(f.same_root(a, b))


def zeta(n: int) -> s.Expr:
    if n < 1:
        raise ValueError("The root-of-unity order must be positive")
    return s.Pow(-1, s.Rational(2, n))


def dickson(n: int, x: s.Symbol, a: s.Expr) -> s.Expr:
    """D_n(u+a/u,a)=u^n+(a/u)^n, D_0=2, D_1=x."""
    if n < 0:
        raise ValueError("Negative Dickson index")
    u, v = s.Integer(2), x
    if not n:
        return u
    for _ in range(1, n):
        u, v = v, s.expand(x * v - a * u)
    return v


def _rational_nth_roots(c: s.Expr, n: int) -> list[s.Expr]:
    if not c.is_Rational or not c or (c < 0 and n % 2 == 0):
        return []
    p, okp = s.integer_nthroot(abs(int(c.p)), n)
    q, okq = s.integer_nthroot(int(c.q), n)
    if not (okp and okq):
        return []
    r = s.Rational(p, q)
    if c < 0:
        r = -r
    return [r, -r] if n % 2 == 0 else [r]


def _low_degree(p: s.Poly) -> list[s.Expr] | None:
    n, x = p.degree(), p.gen
    p = p.monic()
    if n == 1:
        return [-p.nth(0)]
    if n == 2:
        b, c = p.nth(1), p.nth(0)
        return [(-b + e * s.sqrt(b*b - 4*c))/2 for e in (1, -1)]
    if n == 3:
        a, b, c = p.nth(2), p.nth(1), p.nth(0)
        P = s.expand(b - a*a/3)
        Q = s.expand(2*a**3/27 - a*b/3 + c)
        if P == 0 and Q == 0:
            return [-a/3] * 3
        delta = s.expand(Q**2/4 + P**3/27)
        t = -Q/2 + s.sqrt(delta)
        if exact_equal(t, 0):
            t = -Q/2 - s.sqrt(delta)
        u = t**s.Rational(1, 3)
        return [zeta(3)**k*u - P/(3*zeta(3)**k*u) - a/3
                for k in range(3)]
    if n == 4:
        rr = s.roots(p.as_expr(), x, cubics=True, quartics=True)
        values = [r for r, count in rr.items() for _ in range(count)]
        if len(values) == 4 and all(radical_q(r) for r in values):
            return values
    return None


def fast_candidates(poly: s.Poly, depth: int = 0,
                    max_depth: int | None = 30) -> tuple[list[s.Expr], str] | None:
    """Generate complete candidate lists for supported structural families.

    This is a proposal engine, NOT a root-index certificate. Public to_radicals
    performs an exact selected-root comparison before returning success.
    """
    if max_depth is not None and depth > max_depth:
        raise ResourceLimit("Fast-transformation recursion limit")
    p = s.Poly(poly, poly.gen).monic()
    x, n = p.gen, p.degree()
    low = _low_degree(p)
    if low is not None:
        return low, "Degree<=4"
    shift = -p.nth(n-1)/n
    if shift:
        shifted = s.Poly(s.expand(p.as_expr().subs(x, x + shift)), x)
        result = fast_candidates(shifted, depth + 1, max_depth)
        if result:
            return [r + shift for r in result[0]], "Shift/" + result[1]
        return None
    # Powers and binomials, including zero constants.
    support = [k for (k,), c in p.terms() if k and c]
    g = reduce(gcd, support)
    if g > 1:
        q = s.Poly(sum(c*x**(k//g) for (k,), c in p.terms()), x)
        result = fast_candidates(q, depth + 1, max_depth)
        if result:
            return [zeta(g)**k * r**s.Rational(1, g)
                    for r in result[0] for k in range(g)], "Power/"+result[1]
    # Dickson/Chebyshev form after depression.
    a = -p.nth(n-2)/n
    D = s.Poly(dickson(n, x, a), x)
    rem = p - D
    if rem.degree() <= 0 and a != 0:
        c = rem.nth(0)
        t = (-c + s.sqrt(c*c - 4*a**n))/2
        if exact_equal(t, 0):
            t = (-c - s.sqrt(c*c - 4*a**n))/2
        u = t**s.Rational(1, n)
        return [zeta(n)**k*u + a/(zeta(n)**k*u) for k in range(n)], "Dickson"
    # Generalized reciprocal: p(x)=x^m q(x+a/x).
    if n % 2 == 0 and p.nth(0):
        m = n//2
        for a in _rational_nth_roots(p.nth(0), m):
            if all(s.expand(p.nth(m-j) - a**j*p.nth(m+j)) == 0
                   for j in range(1, m+1)):
                q = s.Poly(p.nth(m) + sum(p.nth(m+j)*dickson(j, x, a)
                                         for j in range(1, m+1)), x)
                result = fast_candidates(q, depth + 1, max_depth)
                if result:
                    return [(r + e*s.sqrt(r*r-4*a))/2
                            for r in result[0] for e in (1, -1)], "Reciprocal/"+result[1]
    # Rational polynomial composition; intermediate equations may have
    # radical coefficients. No claim is made for decomposition over EX.
    if all(c.is_Rational for c in p.all_coeffs()):
        ds = s.decompose(p.as_expr(), x)
        if len(ds) > 1:
            result = fast_candidates(s.Poly(ds[0], x), depth+1, max_depth)
            if result:
                candidates = result[0]
                for inner in ds[1:]:
                    new = []
                    for r in candidates:
                        sub = fast_candidates(s.Poly(inner-r, x), depth+1, max_depth)
                        if sub is None:
                            return None
                        new.extend(sub[0])
                    candidates = new
                return candidates, "Composition/"+result[1]
    return None


def _numeric_order(candidates: Iterable[s.Expr], target: s.Expr) -> list[s.Expr]:
    values = list(candidates)
    try:
        z = complex(s.N(target, 40))
        return sorted(values, key=lambda c: abs(complex(s.N(c, 40))-z))
    except (ValueError, TypeError, OverflowError):
        return values  # Numerics only schedule exact tests; they never reject.


def to_radicals(poly: s.Poly | s.Expr, index: int = 0, *,
                variable: s.Symbol | None = None, method: str = "auto",
                max_field_degree: int | None = 64,
                max_nodes: int | None = 10000,
                max_depth: int | None = 30) -> RadicalResult:
    """Convert one QQ-polynomial root, retaining its exact complex embedding.

    method='fast' stops with Unknown if structural transformations miss.
    method='galois' forces the splitting-field construction.
    method='auto' tries fast transformations then the general construction.
    None disables an individual resource limit (there is no wall-clock limit).
    """
    for name, limit in (("max_field_degree", max_field_degree),
                        ("max_nodes", max_nodes), ("max_depth", max_depth)):
        if limit is not None and (not isinstance(limit, int) or
                                  isinstance(limit, bool) or limit < 1):
            raise ValueError(f"{name} must be a positive integer or None")
    if method not in {"auto", "fast", "galois"}:
        raise ValueError("method must be auto, fast, or galois")
    if not isinstance(index, int) or isinstance(index, bool):
        raise ValueError("index must be a zero-based integer")
    original = s.Poly(poly, variable) if variable is not None else s.Poly(poly)
    if not original.gens or len(original.gens) != 1 or original.degree() < 1:
        raise ValueError("A nonconstant univariate polynomial is required")
    if any(not c.is_Rational for c in original.all_coeffs()):
        raise ValueError("Only exact rational coefficients are accepted")
    if not 0 <= index < original.degree():
        raise ValueError("Root index out of range")
    target = s.CRootOf(original, index)
    if target.is_Rational:
        return RadicalResult("Success", target, "Rational", True)
    x = original.gen
    p = s.Poly(s.minpoly(target, x), x, domain=s.QQ).monic()
    try:
        if method != "galois":
            result = fast_candidates(p, max_depth=max_depth)
            if result:
                candidates, route = result
                for candidate in _numeric_order(candidates, target):
                    if radical_q(candidate) and exact_equal(candidate, target):
                        return RadicalResult("Success", candidate, route, True,
                                             {"minimal_polynomial": str(p.as_expr())})
            if method == "fast":
                return RadicalResult("Unknown", method="Fast",
                                     details={"reason": "No certified structural match"})
        # The small-degree group routine is a decision accelerator only.
        # Its permutation labels are NEVER assigned to numerical root labels.
        if p.degree() <= 6:
            try:
                G, _ = s.polys.numberfields.galois_group(p)
            except (ValueError, s.polys.numberfields.galoisgroups.MaxTriesException):
                G = None
            if G is not None and not G.is_solvable:
                return RadicalResult("NotSolvable", method="ExactGaloisDecision",
                                     details={"group_order": int(G.order())})
        from galois_core import automatic_model, radicals_from_model, prime_chain, embed_exact
        model = automatic_model(p, max_field_degree=max_field_degree)
        # For THIS automatic compositum, nonsolvability is equivalent to
        # nonsolvability of the minimal polynomial (see the article).
        prime_chain(model.table, model.identity, model.group)
        # Select a conjugate by exact equality, not by a cross-CAS root index.
        root_element = embed_exact(model.K, target)
        expression, details = radicals_from_model(model, root_element,
                                                  max_nodes=max_nodes)
        # This final comparison is deliberately independent of Fourier descent.
        if not radical_q(expression) or not exact_equal(expression, target):
            raise RadicalError("Final exact selected-root verification failed")
        return RadicalResult("Success", expression, "GaloisFourier", True, details)
    except ResourceLimit as error:
        return RadicalResult("ResourceLimit", method=method,
                             details={"reason": str(error)})
    except NotSolvable as error:
        return RadicalResult("NotSolvable", method="GaloisFourier",
                             details={"reason": str(error)})
    except Exception as error:
        # Preserve a diagnostic rather than confusing implementation errors
        # with an impossibility theorem. Invalid public input was checked above.
        return RadicalResult("BackendError", method=method,
                             details={"exception": type(error).__name__,
                                      "reason": str(error)})
