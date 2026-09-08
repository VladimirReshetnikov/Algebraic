"""RootRadicals: structural shortcuts plus an explicit splitting-field algorithm.

The Galois route has no degree cutoff in its mathematical algorithm.  Its default
field-degree guard is a resource policy, not a test for nonsolvability.  It uses
only SymPy; no Sage, GAP, Magma, undocumented Wolfram functions, or group tables.
"""
from __future__ import annotations
from dataclasses import dataclass, field as datafield
from functools import lru_cache
from math import gcd
from typing import Any
import sympy as s
from sympy.polys.polyerrors import CoercionFailed, IsomorphismFailed
from .program import RadicalProgram, radical_expression
from .field import ExactField

X = s.Symbol("x")

class ResourceLimit(Exception):
    pass

@dataclass
class RadicalResult:
    status: str
    method: str
    target: s.Expr | None = None
    polynomial: s.Poly | None = None
    program: RadicalProgram | None = None
    message: str = ""
    details: dict[str, Any] = datafield(default_factory=dict)
    certificate: Any = None

    @property
    def expression(self) -> s.Expr:
        if self.status != "success" or self.program is None:
            raise ValueError(f"No radical expression: {self.status}: {self.message}")
        return self.program.expression()

    def verify(self) -> bool:
        if self.status != "success" or self.program is None:
            return False
        if isinstance(self.certificate, TowerCertificate):
            return self.certificate.verify(self.program, self.target)
        return certify_expression(self.expression, self.target, self.polynomial)

    def to_json(self) -> dict[str, Any]:
        obj: dict[str, Any] = {"status": self.status, "method": self.method,
                              "message": self.message, "details": self.details}
        if self.polynomial is not None:
            obj["polynomial"] = [str(c) for c in self.polynomial.all_coeffs()]
        if self.program is not None:
            obj["program"] = self.program.to_json()
            obj["wolfram_program"] = self.program.wolfram()
        if isinstance(self.certificate, TowerCertificate):
            obj["certificate"] = self.certificate.summary()
        elif self.certificate is not None:
            obj["certificate"] = self.certificate
        return obj

@lru_cache(maxsize=256)
def _minimal(expr: s.Expr) -> s.Poly:
    return s.Poly(s.minpoly(expr, X), X, domain=s.QQ).monic()

def certify_expression(expr: s.Expr, target: s.Expr, polynomial: s.Poly | None = None) -> bool:
    """Prove annihilation FIRST, then use a certified root-separation comparison.

    Poly.same_root by itself is NOT an equality test for arbitrary expressions:
    its inputs must already be known to be roots of the same polynomial.
    """
    if not radical_expression(expr) or expr.has(s.zoo, s.nan, s.oo, -s.oo):
        return False
    f = _minimal(target) if polynomial is None else polynomial.monic()
    if _minimal(expr) != f:
        return False
    if f.degree() == 1:
        return s.cancel(expr - target) == 0
    return bool(f.same_root(expr, target))

def zeta_expr(n: int, k: int = 1) -> s.Expr:
    if n < 1: raise ValueError("Positive root-of-unity order required")
    return s.Pow(s.S.NegativeOne, s.Rational(2*(k % n), n), evaluate=False)

def zeta_algebraic(n: int) -> s.Expr:
    if n == 1: return s.S.One
    if n == 2: return s.S.NegativeOne
    # With real roots first, then complex roots in lexicographic order, the
    # last primitive root is exp(2*pi*I/n): it has maximal real part and Im>0.
    return s.Poly(s.cyclotomic_poly(n, X), X).all_roots(radicals=True)[-1]

def dickson(n: int, variable: s.Expr, a: s.Expr) -> s.Expr:
    if n == 0: return s.Integer(2)
    p, q = s.Integer(2), variable
    for _ in range(2, n+1): p, q = q, s.expand(variable*q-a*p)
    return q

def _rational_nth_roots(a: s.Rational, n: int) -> list[s.Rational]:
    if a == 0: return [s.S.Zero]
    if a < 0 and n % 2 == 0: return []
    num, en = s.integer_nthroot(abs(int(a.p)), n)
    den, ed = s.integer_nthroot(int(a.q), n)
    if not en or not ed: return []
    q = s.Rational(num, den)
    if a < 0: q = -q
    return [q, -q] if n % 2 == 0 else [q]

def _elementary_roots(f: s.Poly) -> list[s.Expr] | None:
    if f.degree() > 4: return None
    roots = s.roots(f.as_expr(), f.gen, cubics=True, quartics=True)
    if sum(roots.values()) != f.degree(): return None
    ans = [r for r, mult in roots.items() for _ in range(mult)]
    return ans if all(radical_expression(e) for e in ans) else None

def _structural_roots(f: s.Poly, depth: int = 16) -> tuple[list[s.Expr], list[str]] | None:
    if depth < 0: return None
    f = f.monic(); x = f.gen; n = f.degree()
    elementary = _elementary_roots(f)
    if elementary is not None: return elementary, ["degree-at-most-four"]
    shift = -f.nth(n-1)/n
    q = s.Poly(s.expand(f.as_expr().subs(x, x+shift)), x, domain=s.QQ)
    nonconstant = [j for j in range(1, n+1) if q.nth(j) != 0]
    # Translated pure powers, including arbitrarily large degrees.
    if nonconstant == [n]:
        u = s.Pow(-q.nth(0), s.Rational(1, n))
        return [shift+zeta_expr(n, k)*u for k in range(n)], ["translated-binomial"]
    # Dickson/Chebyshev-type equations; the two radicals are coupled by uv=a.
    a = -q.nth(n-2)/n
    D = dickson(n, x, a)
    b = s.expand(D-q.as_expr())
    if not b.has(x) and a != 0:
        U = (b+s.sqrt(b*b-4*a**n))/2
        u = s.Pow(U, s.Rational(1, n))
        ans = []
        for k in range(n):
            v = zeta_expr(n, k)*u
            ans.append(shift+v+a/v)
        return ans, ["Dickson substitution x=u+a/u"]
    # x^d h(x+a/x), including ordinary reciprocal and skew-reciprocal forms.
    if n % 2 == 0:
        d = n//2
        for a in _rational_nth_roots(q.nth(0), d):
            if a == 0: continue
            if all(q.nth(d-j) == a**j*q.nth(d+j) for j in range(1, d+1)):
                h = q.nth(d)+sum(q.nth(d+j)*dickson(j, x, a) for j in range(1, d+1))
                sub = _structural_roots(s.Poly(h, x, domain=s.QQ), depth-1)
                if sub is not None:
                    ans = [shift+(t+sign*s.sqrt(t*t-4*a))/2 for t in sub[0] for sign in (1, -1)]
                    return ans, [f"reciprocal reduction with a={a}"]+sub[1]
    # f(x)=h((x-shift)^g).  Reduction happens over Q, then all g-th-root phases.
    g = 0
    for j in nonconstant: g = gcd(g, j)
    if g > 1:
        h = sum(q.nth(j)*x**(j//g) for j in range(0, n+1, g))
        sub = _structural_roots(s.Poly(h, x, domain=s.QQ), depth-1)
        if sub is not None:
            ans = [shift+zeta_expr(g, k)*s.Pow(t, s.Rational(1, g))
                   for t in sub[0] for k in range(g)]
            return ans, [f"power substitution of degree {g}"]+sub[1]
    # More general polynomial compositions; inversion of inner components is
    # currently accelerated only when their degrees are at most four.
    parts = q.decompose()
    if len(parts) > 1 and all(p.degree() <= 4 for p in parts[1:]):
        sub = _structural_roots(parts[0], depth-1)
        if sub is not None:
            ans = sub[0]
            for inner in parts[1:]:
                nxt = []
                for t in ans:
                    rr = _elementary_roots(s.Poly(inner.as_expr()-t, x, domain=s.EX))
                    if rr is None: return None
                    nxt.extend(rr)
                ans = nxt
            return [shift+r for r in ans], ["polynomial composition"]+sub[1]
    # Pure cyclotomic recognition.  phi(m)>=sqrt(m/2) bounds the finite search.
    if f.is_cyclotomic:
        for m in range(1, 2*n*n+1):
            if s.totient(m) == n and s.Poly(s.cyclotomic_poly(m, x), x, domain=s.QQ) == f:
                return [zeta_expr(m, k) for k in range(m) if gcd(k, m) == 1], [f"cyclotomic order {m}"]
    # Maximal real cyclotomic subfields. Elimination gives the square of the
    # minimal polynomial because k and -k have the same trace z+1/z.
    z = s.Dummy("z")
    for m in range(3, 8*n*n+1):
        if s.totient(m) != 2*n: continue
        resultant = s.resultant(s.cyclotomic_poly(m, z), z*z-x*z+1, z)
        real_poly = s.Poly(resultant, x, domain=s.QQ).sqf_part().monic()
        if real_poly == f:
            return [zeta_expr(m, k)+zeta_expr(m, -k)
                    for k in range(1, (m+1)//2) if gcd(k, m) == 1], [f"real cyclotomic trace of order {m}"]
    return None

def _ordered_candidates(candidates: list[s.Expr], target: s.Expr) -> list[s.Expr]:
    # Heuristic ordering only: no candidate is accepted on numerical proximity.
    tr, ti = s.N(target, 45).as_real_imag()
    def score(e):
        try:
            re, im = s.N(e, 45).as_real_imag()
            return s.N((re-tr)**2+(im-ti)**2, 40)
        except Exception:
            return s.oo
    return sorted(dict.fromkeys(candidates), key=score)

def _choose(candidates: list[s.Expr], target: s.Expr, f: s.Poly) -> s.Expr | None:
    for c in _ordered_candidates(candidates, target):
        if certify_expression(c, target, f): return c
    return None

def _hint_candidates(f: s.Poly, target: s.Expr, hints: list[s.Expr]) -> list[s.Expr]:
    if not hints: return []
    if not all(radical_expression(h) for h in hints):
        raise ValueError("Extension hints must themselves be exact radical expressions")
    K = s.QQ.algebraic_field(*hints)
    try:
        value = K.from_sympy(target)
        expr = K.to_sympy(value)
        if radical_expression(expr): return [expr]
    except (CoercionFailed, IsomorphismFailed): pass
    factors = s.Poly(f.as_expr(), f.gen, domain=K).factor_list()[1]
    out = []
    for factor, _ in factors:
        rr = _elementary_roots(s.Poly(factor.as_expr(), f.gen, domain=s.EX))
        if rr is not None: out.extend(rr)
    return out

def _eval_rational(expr: s.Expr, env: dict[s.Symbol, Any], F: ExactField):
    if expr in env: return env[expr]
    if expr.is_Rational: return F.K.from_sympy(expr)
    if expr == s.I: return F.K.from_sympy(s.I)
    if expr.is_Add:
        out = F.zero
        for arg in expr.args: out += _eval_rational(arg, env, F)
        return out
    if expr.is_Mul:
        out = F.one
        for arg in expr.args: out *= _eval_rational(arg, env, F)
        return out
    if expr.is_Pow and expr.exp.is_Integer:
        return _eval_rational(expr.base, env, F)**int(expr.exp)
    raise ValueError("Expected a rational expression in prior registers")

@dataclass
class TowerCertificate:
    F: ExactField
    zeta_order: int
    zeta_value: Any
    step_values: list[Any]
    step_primes: list[int]
    raw_phases: list[int]
    group_orders: list[int]
    sources: list[s.Expr]

    def verify(self, program: RadicalProgram, target: s.Expr) -> bool:
        """Replay radical equations and exact principal-sector tests independently
        of the Galois construction.  A successful replay proves the selected root.
        """
        F = self.F
        if len(program.assignments) != len(self.step_values)+1: return False
        if len(self.step_primes) != len(self.step_values): return False
        if len(set(name for name, _ in program.assignments)) != len(program.assignments): return False
        name, rhs = program.assignments[0]
        if rhs != zeta_expr(self.zeta_order): return False
        z = zeta_algebraic(self.zeta_order)
        if self.zeta_value != F.K.from_sympy(z): return False
        cp = s.Poly(s.cyclotomic_poly(self.zeta_order, X), X, domain=s.QQ)
        if not F.matches_embedding(self.zeta_value, z, cp): return False
        env = {name: self.zeta_value}
        for (name, rhs), value, p in zip(program.assignments[1:], self.step_values, self.step_primes):
            if p < 2 or not s.isprime(p) or self.zeta_order % p: return False
            if not (rhs.is_Pow and rhs.exp == s.Rational(1, p)): return False
            radicand = _eval_rational(rhs.base, env, F)
            if value**p != radicand: return False
            zp = self.zeta_value**(self.zeta_order//p)
            if not F.principal_sector(value, p, zp): return False
            env[name] = value
        out = _eval_rational(program.output, env, F)
        return (out == F.K.from_sympy(target) and
                F.matches_embedding(out, target, _minimal(target)))

    def summary(self) -> dict[str, Any]:
        return {"kind": "exact-field-tower-replay", "field_degree": self.F.degree,
                "field_modulus": [str(c) for c in self.F.K.ext.minpoly.all_coeffs()],
                "field_primitive_expression": str(self.F.K.ext.root),
                "zeta_order": self.zeta_order, "prime_indices": self.step_primes,
                "subgroup_orders": self.group_orders, "projector_phases": self.raw_phases,
                "generator_vectors": [[str(c) for c in self.F.vector(v)] for v in self.step_values],
                "note": "Summary, not a standalone serialized proof. Use Result.verify() for replay."}

def _check_degree(K: Any, maximum: int | None, stage: str):
    d = int(K.mod.degree())
    if maximum is not None and d > maximum:
        raise ResourceLimit(f"{stage}: field degree {d} exceeds the configured limit {maximum}")

def _normal_field(f: s.Poly, maximum: int | None) -> tuple[Any, list[s.Expr]]:
    # Explicit low-degree formulas avoid expensive RootOf composita when the
    # exact same embeddings already have compact expressions.
    roots = f.all_roots(radicals=True)
    sources = [roots[0]]
    K = s.QQ.algebraic_field(*sources)
    _check_degree(K, maximum, "root field")
    for r in roots[1:]:
        try: K.from_sympy(r)
        except (CoercionFailed, IsomorphismFailed):
            sources.append(r)
            K = s.QQ.algebraic_field(*sources)
            _check_degree(K, maximum, "splitting-field construction")
    # Containment of all roots proves normality; explicitly check every one.
    values = [K.from_sympy(r) for r in roots]
    if len(set(values)) != f.degree():
        raise ArithmeticError("Splitting field did not contain all distinct roots")
    for value in values:
        v = K.zero
        for c in f.all_coeffs(): v = v*value+K.from_sympy(c)
        if v != K.zero: raise ArithmeticError("Invalid root embedding")
    return K, sources

def _normalize_vector(value: Any, F: ExactField):
    coeffs = [c for c in F.vector(value) if c]
    if not coeffs: return value
    den = s.ilcm(*[int(c.q) for c in coeffs]) if len(coeffs) > 1 else int(coeffs[0].q)
    numerators = [int(c*den) for c in coeffs]
    g = 0
    for c in numerators: g = gcd(g, abs(c))
    scale = s.Rational(den, g)
    if coeffs[0] < 0: scale = -scale
    return value*F.K.from_sympy(scale)

def _galois_radicalize(target: s.Expr, f: s.Poly, maximum: int | None) -> RadicalResult:
    L, sources = _normal_field(f, maximum)
    degree_L = int(L.mod.degree())
    m = 1
    for p in s.factorint(degree_L): m *= int(p)
    z = zeta_algebraic(m)
    try: L.from_sympy(z); M = L
    except (CoercionFailed, IsomorphismFailed):
        sources = sources+[z]
        M = s.QQ.algebraic_field(*sources)
    _check_degree(M, maximum, "cyclotomic splitting field")
    F = ExactField(M)
    zv = M.from_sympy(z)
    autos, group = F.automorphisms_fixing(zv)
    if len(autos)*int(s.totient(m)) != F.degree:
        raise ArithmeticError("Cyclotomic fixed-field degree mismatch")
    chain = group.prime_chain()
    if chain is None:
        series = group.derived_series()
        return RadicalResult("not_solvable", "explicit-Galois", target, f,
            message="The exact Galois kernel has a nontrivial stable derived subgroup.",
            details={"splitting_field_degree": degree_L, "cyclotomic_field_degree": F.degree,
                     "kernel_order": group.order, "derived_orders": [len(h) for h in series]})
    r0 = s.Symbol("r0")
    assignments = [(r0, zeta_expr(m))]
    phi = int(s.totient(m))
    basis = [zv**j for j in range(phi)]
    basis_expr = [r0**j for j in range(phi)]
    values, primes, phases = [], [], []
    for level, (H, N) in enumerate(zip(chain, chain[1:]), start=1):
        p = len(H)//len(N)
        sigma = min(H-N)
        zp = zv**(m//p)
        # Trace images of the absolute power basis span the next fixed field.
        # The primitive-character projector is nonzero on at least one image.
        raw = F.zero
        power = F.one
        chosen_k = None
        for k in range(F.degree):
            trace = F.zero
            for h in sorted(N): trace += F.apply(autos[h], power)
            image = trace
            projector = F.zero
            for j in range(p):
                projector += (zp**(-j))*image
                image = F.apply(autos[sigma], image)
            if projector != F.zero:
                raw = _normalize_vector(projector, F); chosen_k = k; break
            power *= F.theta
        if chosen_k is None:
            raise ArithmeticError("Nonzero Kummer eigenspace was not found")
        if F.apply(autos[sigma], raw) != zp*raw:
            raise ArithmeticError("Kummer eigenvector identity failed")
        a = raw**p
        coords = F.rational_coordinates(basis, a)
        rhs = s.Add(*[c*b for c, b in zip(coords, basis_expr)])
        # Replace the raw eigenvector by the principal pth root of its pth
        # power. All possibilities already lie in M because zeta_p is in B.
        principal = None
        phase = None
        for k in range(p):
            candidate = raw*(zp**(-k))
            if F.principal_sector(candidate, p, zp):
                principal = candidate; phase = k; break
        if principal is None:
            raise ArithmeticError("No principal radical branch found")
        name = s.Symbol(f"r{level}")
        assignments.append((name, s.Pow(rhs, s.Rational(1, p), evaluate=False)))
        basis = [b*(principal**e) for e in range(p) for b in basis]
        basis_expr = [b*(name**e) for e in range(p) for b in basis_expr]
        values.append(principal); primes.append(p); phases.append(phase)
        expected = F.degree//len(N)
        if len(basis) != expected:
            raise ArithmeticError("Tower basis dimension mismatch")
    target_value = M.from_sympy(target)
    coordinates = F.rational_coordinates(basis, target_value)
    output = s.Add(*[c*b for c, b in zip(coordinates, basis_expr)])
    program = RadicalProgram(assignments, output)
    program.to_json()  # whitelist and topological validation
    cert = TowerCertificate(F, m, zv, values, primes, phases,
                            [len(h) for h in chain], sources)
    if not cert.verify(program, target):
        raise ArithmeticError("Independent radical-tower replay failed")
    return RadicalResult("success", "explicit-Galois", target, f, program,
        "Exact radical tower and principal branches verified.",
        {"splitting_field_degree": degree_L, "cyclotomic_field_degree": F.degree,
         "kernel_order": group.order, "prime_indices": primes,
         "dag_nodes": len(program.to_json()["nodes"])}, cert)

def prime_degree_obstruction(f: s.Poly, prime_count: int = 12) -> dict[str, Any] | None:
    """Exact Frobenius-cycle obstruction for irreducible prime-degree inputs.

    A solvable transitive group of prime degree n is a subgroup of AGL(1,n).
    Its cycle types are 1^n, n, and 1 d^((n-1)/d). A good modular factorization
    exhibiting any other type proves nonsolvability, without constructing L.
    This function requires irreducibility over Q (the caller uses a minpoly).
    """
    n = f.degree()
    if n < 5 or not s.isprime(n): return None
    _, primitive = f.clear_denoms(convert=True)
    for ell in list(s.primerange(2, 200))[:prime_count]:
        if int(primitive.LC()) % ell == 0: continue
        mod = s.Poly(primitive.as_expr(), primitive.gen, modulus=ell)
        if mod.gcd(mod.diff()).degree() != 0: continue
        factors = mod.factor_list()[1]
        degrees = sorted(g.degree() for g, e in factors for _ in range(e))
        allowed = degrees == [n] or degrees == [1]*n
        if not allowed and degrees.count(1) == 1:
            tail = degrees[1:]
            allowed = bool(tail and len(set(tail)) == 1 and (n-1) % tail[0] == 0)
        if not allowed:
            return {"modular_prime": ell, "cycle_type": degrees,
                    "factor_coefficients_mod_prime":
                        [[int(c) % ell for c in g.all_coeffs()] for g, _ in factors],
                    "reason": "cycle type is impossible in an affine group of prime degree"}
    return None

def radicalize(target: s.Expr, *, method: str = "auto", max_field_degree: int | None = 64,
               extension_hints: list[s.Expr] | None = None, galois_precheck: bool = True) -> RadicalResult:
    """Convert a specified exact algebraic number to radicals over Q.

    method='auto': structural recognition, extension hints, then explicit Galois.
    method='structural': bounded recognizers only (failure means unknown).
    method='galois': force the constructive splitting-field route.
    max_field_degree=None removes the field-degree resource guard.

    There is no implicit time limit in this direct API. Use the CLI's subprocess
    time limit for cancellable operations; it can interrupt CAS primitives too.
    """
    if method not in ("auto", "structural", "galois"):
        raise ValueError("method must be auto, structural, or galois")
    if max_field_degree is not None and (type(max_field_degree) is not int or max_field_degree < 1):
        raise ValueError("max_field_degree must be a positive integer or None")
    target = s.sympify(target)
    if target.free_symbols or target.has(s.Float, s.zoo, s.oo, -s.oo, s.nan):
        raise ValueError("Input must be a finite exact algebraic number without parameters")
    f = _minimal(target)
    if f.degree() == 1:
        expr = -f.nth(0)/f.nth(1)
        return RadicalResult("success", "rational", target, f, RadicalProgram.from_expr(expr),
                             certificate={"kind": "rational-equality"})
    if method != "galois":
        structural = _structural_roots(f)
        if structural is not None:
            expr = _choose(structural[0], target, f)
            if expr is not None:
                return RadicalResult("success", "structural", target, f, RadicalProgram.from_expr(expr),
                    "Minimal polynomial and selected embedding verified.",
                    {"transformations": structural[1]},
                    {"kind": "minimal-polynomial-and-root-separation"})
        candidates = _hint_candidates(f, target, extension_hints or [])
        expr = _choose(candidates, target, f) if candidates else None
        if expr is not None:
            return RadicalResult("success", "extension-hints", target, f, RadicalProgram.from_expr(expr),
                "Hint-field factorization followed by exact root verification.",
                certificate={"kind": "minimal-polynomial-and-root-separation"})
        if method == "structural":
            return RadicalResult("unknown", method, target, f,
                                 message="The bounded recognizers found no certified expression.")
    # This is an optional exact negative shortcut, NOT the universal algorithm.
    # SymPy's abstract permutation labeling must not be applied to numerical
    # root order; the constructive route computes its own embedded action.
    if galois_precheck:
        obstruction = prime_degree_obstruction(f)
        if obstruction is not None:
            return RadicalResult("not_solvable", "prime-degree-Frobenius", target, f,
                message="An exact good-prime factorization excludes every solvable prime-degree Galois group.",
                details=obstruction)
    if galois_precheck and 2 <= f.degree() <= 6:
        try:
            G, _ = s.polys.numberfields.galois_group(f)
            if not G.is_solvable:
                return RadicalResult("not_solvable", "SymPy-Galois-precheck", target, f,
                    message="The minimal polynomial has a nonsolvable Galois group.",
                    details={"group_order": int(G.order()),
                             "derived_orders": [int(H.order()) for H in G.derived_series()]})
        except (ValueError, NotImplementedError, s.polys.numberfields.galoisgroups.MaxTriesException):
            pass
    try:
        return _galois_radicalize(target, f, max_field_degree)
    except ResourceLimit as exc:
        return RadicalResult("resource_limit", "explicit-Galois", target, f, message=str(exc))
