"""RadicalRoot: exact radical conversion and an explicit Galois/Kummer reference solver.

Python indices are SymPy's ZERO-based CRootOf indices, not Mathematica indices.
The reference algorithm is finite with exact arithmetic and no resource bounds,
but constructing the splitting field can be prohibitively expensive.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from functools import reduce
from math import gcd
from typing import Any, Iterable, Iterator
import sympy as s
from sympy.polys.numberfields import to_number_field
from sympy.polys.polyerrors import CoercionFailed, NotAlgebraic, IsomorphismFailed, PolynomialError, GeneratorsNeeded


class RadicalError(Exception):
    def __init__(self, status: str, message: str, **details: Any):
        super().__init__(message)
        self.status, self.details = status, details


@dataclass
class RadicalResult:
    status: str
    expression: s.Expr | None = None
    method: str = ""
    target: s.Expr | None = None
    certificate: dict[str, Any] = field(default_factory=dict)
    message: str = ""

    @property
    def success(self) -> bool:
        return self.status == "success"


def zeta(n: int) -> s.Expr:
    """The primitive root exp(2*pi*i/n), written using principal powers only."""
    return s.S.One if n == 1 else s.Pow(-s.S.One, s.Rational(2, n))


def radical_expression_q(e: s.Expr) -> bool:
    e = s.sympify(e)
    if e.is_Rational or e == s.I:
        return True
    if e.is_Add or e.is_Mul:
        return all(radical_expression_q(a) for a in e.args)
    return bool(e.is_Pow and e.exp.is_Rational and radical_expression_q(e.base))


def same_algebraic(a: s.Expr, b: s.Expr) -> bool:
    """Exact embedded-number equality. Numerical agreement is never accepted."""
    a, b = s.sympify(a), s.sympify(b)
    if a == b:
        return True
    if a.is_Rational and b.is_Rational:
        return False
    try:
        bb = to_number_field(b)
        aa = to_number_field(a, bb)
        return aa.coeffs() == bb.coeffs()
    except (CoercionFailed, NotAlgebraic, IsomorphismFailed, ValueError, NotImplementedError):
        return False


def dickson(n: int, x: s.Symbol, a: s.Expr) -> s.Expr:
    if n == 0:
        return s.Integer(2)
    u, v = s.Integer(2), x
    for _ in range(2, n + 1):
        u, v = v, s.expand(x*v-a*u)
    return v


def pair_sum_resolvent(poly: s.Poly, y: s.Symbol | None = None) -> s.Poly:
    """Product over i<j of (y-r_i-r_j), with multiplicities preserved."""
    p = s.Poly(poly, domain=s.QQ).monic()
    x = p.gen
    y = y or s.Dummy("pair_sum")
    n = p.degree()
    res = s.Poly(s.resultant(p.as_expr(), p.as_expr().subs(x, y-x), x), y,
                 domain=s.QQ)
    diag = s.Poly(2**n*p.as_expr().subs(x, y/2), y, domain=s.QQ)
    q, rem = res.div(diag)
    if not rem.is_zero:
        raise RadicalError("backend_failure", "Pair-sum diagonal division failed")
    c, fs = q.factor_list()
    if c != 1 or any(k % 2 for _, k in fs):
        raise RadicalError("backend_failure", "Pair-sum square extraction failed")
    out = s.Poly(1, y, domain=s.QQ)
    for g, k in fs:
        out *= g**(k//2)
    if out.degree() != n*(n-1)//2:
        raise RadicalError("backend_failure", "Wrong pair-sum resolvent degree")
    return out


def _rational_coefficients(p: s.Poly) -> bool:
    return all(c.is_Rational for c in p.all_coeffs())


def _fast(poly: s.Poly, depth: int = 0, pair_limit: int = 8) -> Iterator[tuple[s.Expr, str]]:
    """Lazy candidate stream. Soundness is enforced by the caller's equality test."""
    p = s.Poly(poly)
    x, n = p.gen, p.degree()
    if n < 1 or depth > 10:
        return
    if n <= 4:
        # SymPy may return fewer than n roots; an empty/partial answer is not a proof.
        for r in s.roots(p.as_expr(), x, cubics=True, quartics=True):
            if radical_expression_q(r):
                yield r, "low_degree"
        return
    if not _rational_coefficients(p):
        return
    p = s.Poly(p, domain=s.QQ).monic()
    shift = -p.nth(n-1)/n
    g = s.Poly(p.as_expr().subs(x, x+shift).expand(), x, domain=s.QQ)
    support = [j for j in range(1, n+1) if g.nth(j) != 0]
    d = reduce(gcd, support)
    if d > 1:
        q = s.Poly(sum(g.nth(j)*x**(j//d) for j in range(0, n+1, d)), x)
        for b, method in _fast(q, depth+1, pair_limit):
            for k in range(d):
                yield shift+zeta(d)**k*b**s.Rational(1, d), "power/"+method
        return
    a = -g.nth(n-2)/n
    c = g.nth(0)
    if a != 0 and s.Poly(g.as_expr()-dickson(n, x, a)-c, x).is_zero:
        U = (-c+s.sqrt(c*c-4*a**n))/2
        if U == 0:
            U = (-c-s.sqrt(c*c-4*a**n))/2
        for k in range(n):
            u = zeta(n)**k*U**s.Rational(1, n)
            yield shift+u+a/u, "dickson"
        return
    if n % 2 == 0 and p.nth(0) != 0:
        m = n//2
        # The first nonzero upper coefficient gives finitely many rational a's.
        j = next(j for j in range(1, m+1) if p.nth(m+j) != 0)
        t = s.Dummy("a")
        choices = s.Poly(t**j-p.nth(m-j)/p.nth(m+j), t).ground_roots()
        for a in choices:
            if a == 0 or any(p.nth(m-k) != a**k*p.nth(m+k) for k in range(1, m+1)):
                continue
            q = s.Poly(p.nth(m)+sum(p.nth(m+k)*dickson(k, x, a)
                                   for k in range(1, m+1)), x)
            for b, method in _fast(q, depth+1, pair_limit):
                for sign in (1, -1):
                    yield (b+sign*s.sqrt(b*b-4*a))/2, "reciprocal/"+method
    if depth == 0 and n <= pair_limit:
        R = pair_sum_resolvent(p)
        factors = sorted(R.factor_list()[1], key=lambda t: t[0].degree())
        for q, _ in factors:
            if not 1 < q.degree() < min(n, 5):
                continue
            for beta, _ in _fast(q, depth+1, 0):
                fp = s.Poly(p.as_expr(), x, extension=beta)
                fs = sorted(fp.factor_list()[1], key=lambda t: t[0].degree())
                for h, _ in fs:
                    # Cubic/quadratic lifting is deliberately preferred to large quartics.
                    if 0 < h.degree() < min(n, 4):
                        for r, method in _fast(h, depth+1, 0):
                            yield r, "pair_resolvent/"+method


class FiniteGroup:
    """A finite group represented by its fully checked multiplication table."""
    def __init__(self, table: list[list[int]], identity: int = 0, check: bool = True):
        self.table, self.identity = table, identity
        self.order = len(table)
        h = self.order
        if not h or any(len(row) != h for row in table):
            raise RadicalError("backend_failure", "Malformed group table")
        if any(set(row) != set(range(h)) for row in table):
            raise RadicalError("backend_failure", "Group row is not a permutation")
        if any(table[identity][j] != j or table[j][identity] != j for j in range(h)):
            raise RadicalError("backend_failure", "Wrong identity")
        self.inverse = [next(j for j in range(h) if table[i][j] == identity)
                        for i in range(h)]
        if check and any(table[table[i][j]][k] != table[i][table[j][k]]
                         for i in range(h) for j in range(h) for k in range(h)):
            raise RadicalError("backend_failure", "Nonassociative group table")

    def closure(self, generators: Iterable[int]) -> list[int]:
        gen = sorted(set(generators))
        seen, todo = {self.identity}, [self.identity]
        while todo:
            a = todo.pop()
            for b in gen:
                c = self.table[a][b]
                if c not in seen:
                    seen.add(c); todo.append(c)
        return sorted(seen)

    def derived(self, group: list[int]) -> list[int]:
        t, inv = self.table, self.inverse
        comm = {t[t[t[a][b]][inv[a]]][inv[b]] for a in group for b in group}
        return self.closure(comm)

    def derived_series(self) -> list[list[int]]:
        series = [list(range(self.order))]
        while len(series[-1]) > 1:
            d = self.derived(series[-1])
            series.append(d)
            if d == series[-2]:
                break
        return series

    def cyclic_prime_chain(self) -> list[tuple[list[int], list[int], int, int]]:
        series = self.derived_series()
        if len(series[-1]) > 1:
            raise RadicalError("not_solvable", "The derived series stabilizes nontrivially",
                               derived_series=series, group_order=self.order,
                               multiplication_table=self.table)
        S = list(range(self.order)); out = []
        while len(S) > 1:
            N = self.derived(S)
            for g in S:
                if g in N:
                    continue
                candidate = self.closure(N+[g])
                if len(candidate) < len(S):
                    N = candidate
            p = len(S)//len(N)
            if len(S) != p*len(N) or not s.isprime(p):
                raise RadicalError("backend_failure", "Nonprime chain index")
            sigma = next(g for g in S if g not in N)
            # Verify normality rather than relying only on the construction.
            for g in S:
                for u in N:
                    if self.table[self.table[g][u]][self.inverse[g]] not in N:
                        raise RadicalError("backend_failure", "Nonnormal chain step")
            out.append((S, N, sigma, p)); S = N
        return out


class ExactField:
    """Arithmetic in Q(theta) using SymPy's exact ANP quotient-field elements."""
    def __init__(self, primitive: s.AlgebraicNumber):
        self.primitive = primitive
        self.K = s.QQ.algebraic_field(primitive)
        self.degree = primitive.minpoly.degree()
        self.zero, self.one = self.K.zero, self.K.one
        self.theta = self.K.unit

    def encode(self, e: s.Expr):
        return self.K.from_sympy(e)

    def expr(self, a) -> s.Expr:
        return self.K.to_sympy(a)

    def key(self, a) -> tuple:
        return tuple(a.to_list())

    def vector(self, a) -> s.Matrix:
        vals = [s.Rational(c) for c in reversed(a.to_list())]
        return s.Matrix(vals+[s.S.Zero]*(self.degree-len(vals)))

    def apply(self, a, image):
        v = self.zero
        for c in a.to_list():
            v = v*image+self.K.convert(c)
        return v

    def coordinates(self, a, basis: list) -> list[s.Rational]:
        A = s.Matrix.hstack(*(self.vector(b) for b in basis))
        try:
            c, parameters = A.gauss_jordan_solve(self.vector(a))
        except ValueError as exc:
            raise RadicalError("backend_failure", "Element is outside claimed lower field") from exc
        if parameters.rows or A*c != self.vector(a):
            raise RadicalError("backend_failure", "Invalid field coordinates")
        return list(c)

    def automorphisms(self) -> list:
        x = s.Dummy("X")
        pol = s.Poly.from_list(self.primitive.minpoly.all_coeffs(), x, domain=self.K)
        _, fs = pol.factor_list()
        if len(fs) != self.degree or any(g.degree() != 1 or k != 1 for g,k in fs):
            raise RadicalError("backend_failure", "Constructed field is not normal")
        ans=[]
        for g, _ in fs:
            a,b = g.rep.to_list()
            image = -b/a
            ans.append(image)
        ans.sort(key=lambda a: (a != self.theta, tuple(map(str, self.key(a)))))
        return ans


def _make_field(poly: s.Poly, max_degree: int | None) -> tuple[ExactField, int, s.Expr, int]:
    """Construct exactly the splitting field, then adjoin needed roots of unity."""
    # Known cubic/quartic formulas accelerate construction, not the Kummer solver.
    known = s.roots(poly.as_expr(), poly.gen) if poly.degree() <= 4 else {}
    roots = list(known) if len(known) == poly.degree() else poly.all_roots(radicals=False)
    prim = to_number_field(roots)
    dL = prim.minpoly.degree()
    if max_degree is not None and dL > max_degree:
        raise RadicalError("resource_limit", "Splitting-field degree exceeds the configured bound",
                           splitting_field_degree=dL, bound=max_degree)
    m = int(s.prod(s.factorint(dL))) if dL > 1 else 1
    zz = zeta(m)
    prim = to_number_field([prim.root, zz])
    F = ExactField(prim)
    if max_degree is not None and F.degree > max_degree:
        raise RadicalError("resource_limit", "Cyclotomic compositum exceeds the degree bound",
                           field_degree=F.degree, bound=max_degree)
    return F, m, zz, dL


def kummer_solve_field(F: ExactField, target: s.Expr, m: int, *,
                       max_group_order: int | None = 96) -> RadicalResult:
    """Construct a radical tower inside an already normal, embedded number field.

    Precondition checked here: zeta(m) is in F and all prime divisors of [F:Q]
    need not divide m, but every prime index in the computed relative chain MUST.
    This public low-level routine is useful for reproducible exact-field fixtures.
    """
    zz = zeta(m); z = F.encode(zz); target_value = F.encode(target)
    all_aut = F.automorphisms()
    aut = [a for a in all_aut if F.apply(z, a) == z]
    h = len(aut); d0 = int(s.totient(m))
    if h*d0 != F.degree:
        raise RadicalError("backend_failure", "Incorrect cyclotomic stabilizer order")
    if max_group_order is not None and h > max_group_order:
        raise RadicalError("resource_limit", "Relative Galois group exceeds order bound",
                           group_order=h, bound=max_group_order)
    keys = {F.key(a):i for i,a in enumerate(aut)}
    if len(keys) != h:
        raise RadicalError("backend_failure", "Duplicate automorphisms")
    table = [[keys[F.key(F.apply(b,a))] for b in aut] for a in aut]
    G = FiniteGroup(table, keys[F.key(F.theta)], check=False)  # associativity follows from composition
    chain = G.cyclic_prime_chain()
    zs = s.Symbol("z0")
    basis = [z**j for j in range(d0)]
    basis_expr = [zs**j for j in range(d0)]
    definitions: list[tuple[s.Symbol, s.Expr]] = [(zs, zz)]
    records = []
    for i, (S, N, sig, p) in enumerate(chain, 1):
        if m % p:
            raise RadicalError("unsupported_input", "Cyclotomic base lacks a needed prime root of unity",
                               prime=p, conductor=m)
        zp = z**(m//p)
        r = F.zero; chosen_k = None
        for k in range(F.degree):
            a = sum((aut[g]**k for g in N), F.zero)
            r = F.zero; b = a
            for j in range(p):
                r += zp**((-j) % p)*b
                b = F.apply(b, aut[sig])
            if r != F.zero:
                chosen_k = k; break
        if r == F.zero:
            raise RadicalError("backend_failure", "All basis resolvents vanished")
        if F.apply(r, aut[sig]) != zp*r or any(F.apply(r,aut[g]) != r for g in N):
            raise RadicalError("backend_failure", "Kummer eigenvector check failed")
        power = r**p
        if any(F.apply(power,aut[g]) != power for g in S):
            raise RadicalError("backend_failure", "Radicand is not fixed by upper group")
        coeff = F.coordinates(power,basis)
        radicand = sum((c*b for c,b in zip(coeff,basis_expr)), s.S.Zero)
        # Principal-root choice is computed in the concrete complex embedding.
        # All roots lie in F because zeta_p is already present.
        principal = F.encode(F.expr(power)**s.Rational(1,p))
        branch = next((k for k in range(p) if zp**k*principal == r), None)
        if branch is None:
            raise RadicalError("backend_failure", "No exact branch match for a Kummer generator")
        sym = s.Symbol(f"r{i}")
        definition = zs**(branch*(m//p))*radicand**s.Rational(1,p)
        definitions.append((sym, definition))
        old_basis, old_expr = basis, basis_expr
        basis = [b*r**j for j in range(p) for b in old_basis]
        basis_expr = [b*sym**j for j in range(p) for b in old_expr]
        if len(basis) != F.degree//len(N):
            raise RadicalError("backend_failure", "Tower dimension mismatch")
        records.append(dict(prime=p, branch=branch, symbol=str(sym), radicand=radicand,
                            trace_power=chosen_k, upper_order=len(S), lower_order=len(N),
                            eigenvector_coordinates=list(F.vector(r)),
                            radicand_coordinates=list(F.vector(power))))
    coeff = F.coordinates(target_value,basis)
    value = sum((c*b for c,b in zip(coeff,basis_expr)), s.S.Zero)
    expanded = {}
    for symbol, definition in definitions:
        expanded[symbol] = definition.xreplace(expanded)
    expr = value.xreplace(expanded)
    if not radical_expression_q(expr):
        raise RadicalError("backend_failure", "Output did not pass the radical grammar")
    # Each step has already been checked exactly in F, including its principal branch.
    # Independent full-expression verification remains available via verify_result.
    return RadicalResult("success", expr, "galois_kummer", target,
                         dict(field_degree=F.degree, cyclotomic_conductor=m,
                              relative_group_order=h, chain_indices=[c[3] for c in chain],
                              definitions=definitions, value=value, steps=records,
                              multiplication_table=table,
                              exact_verification="quotient-field identities and exact branch equality"))


def verify_result(result: RadicalResult) -> bool:
    """Independent exact recheck; can be substantially slower than constructing a tower."""
    return bool(result.success and result.expression is not None and result.target is not None
                and radical_expression_q(result.expression)
                and same_algebraic(result.expression,result.target))


def radicalize(poly: s.Poly | s.Expr, index: int = 0, *, variable: s.Symbol | None = None,
               method: str = "auto", max_field_degree: int | None = 48,
               max_group_order: int | None = 96, pair_limit: int = 8,
               extensions: Iterable[s.Expr] = ()) -> RadicalResult:
    """Express a selected exact algebraic root in radicals.

    method: 'auto' (fast paths then complete reference backend), 'fast', or 'galois'.
    Bounds are resource limits, NEVER evidence of nonsolvability. None disables a bound.
    Call the CLI for an enforceable whole-process timeout.
    """
    target = None
    try:
        if method not in {"auto", "fast", "galois"}:
            raise RadicalError("unsupported_input", "Unknown method")
        if not isinstance(index,int) or isinstance(index,bool):
            raise RadicalError("unsupported_input", "Index must be an integer")
        if any(v is not None and (not isinstance(v,int) or isinstance(v,bool) or v < 1)
               for v in (max_field_degree,max_group_order)):
            raise RadicalError("unsupported_input", "Degree and group bounds must be positive integers or None")
        if not isinstance(pair_limit,int) or isinstance(pair_limit,bool) or pair_limit < 0:
            raise RadicalError("unsupported_input", "pair_limit must be a nonnegative integer")
        try:
            p = s.Poly(poly, variable) if variable is not None else s.Poly(poly)
        except (PolynomialError, GeneratorsNeeded, TypeError, ValueError) as exc:
            raise RadicalError("unsupported_input", "Expected a nonconstant univariate polynomial over Q") from exc
        if len(p.gens) != 1 or p.degree() < 1 or not _rational_coefficients(p):
            raise RadicalError("unsupported_input", "Expected a nonconstant univariate polynomial over Q")
        if p.as_expr().has(s.Float):
            raise RadicalError("unsupported_input", "Inexact coefficients are not accepted")
        if not 0 <= index < p.degree():
            raise RadicalError("unsupported_input", "Root index is out of range")
        target = s.CRootOf(p,index)
        if target.is_Rational:
            return RadicalResult("success",target,"rational",target,
                                 {"exact_verification":"rational identity"})
        # RootOf factor selection avoids diagnosing an unrelated irreducible factor.
        p = s.Poly(target.poly.as_expr(),target.poly.gen,domain=s.QQ).monic()
        if method != "galois":
            candidates = _fast(p,pair_limit=pair_limit)
            for e,name in candidates:
                if radical_expression_q(e) and same_algebraic(e,target):
                    return RadicalResult("success",e,name,target,
                                         {"exact_verification":"embedded algebraic-number equality"})
            for ext in extensions:
                if not radical_expression_q(s.sympify(ext)):
                    continue
                fs = s.Poly(p.as_expr(),p.gen,extension=ext).factor_list()[1]
                for q,_ in sorted(fs,key=lambda t:t[0].degree()):
                    if q.degree() <= 4:
                        for e,name in _fast(q,pair_limit=0):
                            if radical_expression_q(e) and same_algebraic(e,target):
                                return RadicalResult("success",e,"extension/"+name,target,
                                    {"exact_verification":"embedded algebraic-number equality"})
            if method == "fast":
                return RadicalResult("not_found",method="fast",target=target,
                    message="Fast paths exhausted; this does not imply nonsolvability")
        if p.degree() <= 6:
            try:
                group, _ = s.polys.numberfields.galois_group(p)
                if not group.is_solvable:
                    return RadicalResult("not_solvable",method="sympy_galois",target=target,
                        certificate={"galois_group_order":int(group.order()),
                                     "generators":[g.array_form for g in group.generators],
                                     "derived_orders":[int(g.order()) for g in group.derived_series()]},
                        message="Exact Galois-group computation proves nonsolvability")
            except (NotImplementedError, ValueError):
                pass  # A failed optional shortcut does not block the general algorithm.
        F,m,_,dL = _make_field(p,max_field_degree)
        result = kummer_solve_field(F,target,m,max_group_order=max_group_order)
        result.certificate["splitting_field_degree"] = dL
        return result
    except RadicalError as exc:
        return RadicalResult(exc.status,method=method,target=target,
                             certificate=exc.details,message=str(exc))
    except (NotImplementedError, CoercionFailed, NotAlgebraic, IsomorphismFailed, PolynomialError, ValueError) as exc:
        return RadicalResult("backend_failure",method=method,target=target,
                             message=f"{type(exc).__name__}: {exc}")
