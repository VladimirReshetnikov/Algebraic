"""SystematicRadicals 0.1: exact radical reconstruction over Q.

Python >=3.10, SymPy >=1.13. Tested with SymPy 1.14.0.
The 'complete' method is a finite splitting-field/Kummer algorithm, not a
claim of practical polynomial-time performance. Use solve_with_timeout for
an actual wall-clock limit. Python root indices are ZERO-BASED and follow
SymPy, not Mathematica's complex-root ordering.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from functools import reduce
from math import gcd
from typing import Any, Iterable
import multiprocessing as mp
import queue
import sympy as s
from sympy.polys.numberfields import to_number_field
from sympy.polys.polyerrors import CoercionFailed, IsomorphismFailed

__version__ = "0.1.0"

@dataclass
class RadicalResult:
    status: str
    expression: Any = None
    method: str = ""
    certificate: dict[str, Any] = field(default_factory=dict)
    diagnostics: list[str] = field(default_factory=list)

class ResourceLimit(RuntimeError):
    pass

class ConstructionError(RuntimeError):
    pass


def radical_expression_q(e: Any) -> bool:
    """Strict grammar: rationals, I, +, *, and rational/integer powers."""
    e = s.sympify(e)
    if e.is_Rational or e == s.I:
        return True
    if e.is_Add or e.is_Mul:
        return all(radical_expression_q(a) for a in e.args)
    if e.is_Pow:
        return bool(e.exp.is_Rational and radical_expression_q(e.base))
    return False


def zeta(n: int) -> s.Expr:
    if not isinstance(n, int) or n < 1:
        raise ValueError("root-of-unity order must be a positive integer")
    return s.S.One if n == 1 else s.Pow(-s.S.One, s.Rational(2, n))


def exact_equal(a: s.Expr, b: s.Expr) -> bool:
    """Positive answers use exact number-field coordinates, never tolerance."""
    if a == b:
        return True
    if b.is_Rational:
        t = s.Dummy("t")
        return s.Poly(s.minpoly(a-b, t), t).monic() == s.Poly(t, t, domain=s.QQ)
    try:
        # Coordinates refer to the specified embedded generator b.
        return to_number_field(a, b).coeffs() == [s.S.One, s.S.Zero]
    except (IsomorphismFailed, CoercionFailed, NotImplementedError, ValueError):
        return False


def _near_order(candidates: Iterable[s.Expr], target: s.Expr) -> list[s.Expr]:
    """Numerical values ONLY order candidates; none are rejected this way."""
    cs = list(dict.fromkeys(candidates))
    try:
        v = complex(s.N(target, 35))
        return sorted(cs, key=lambda e: abs(complex(s.N(e, 35))-v))
    except (TypeError, ValueError, OverflowError):
        return cs


def dickson(n: int, x: s.Symbol, a: s.Expr) -> s.Expr:
    if n < 0:
        raise ValueError("degree must be nonnegative")
    d0, d1 = s.Integer(2), x
    if n == 0:
        return d0
    for _ in range(2, n+1):
        d0, d1 = d1, s.expand(x*d1-a*d0)
    return d1


def _rational_nth_roots(c: s.Rational, n: int) -> list[s.Rational]:
    if c == 0:
        return [s.S.Zero]
    if c < 0 and n % 2 == 0:
        return []
    p, p_exact = s.integer_nthroot(abs(int(c.p)), n)
    q, q_exact = s.integer_nthroot(int(c.q), n)
    if not (p_exact and q_exact):
        return []
    v = s.Rational(p, q)*(1 if c > 0 else -1)
    return [v, -v] if n % 2 == 0 else [v]


def pair_sum_resolvent(poly: s.Poly) -> s.Poly:
    """Return product_{i<j}(t-r_i-r_j), with multiplicities retained."""
    p = poly.monic()
    x, t = p.gen, s.Dummy("t")
    n = p.degree()
    resultant = s.resultant(p.as_expr(), p.as_expr().subs(x, t-x), x)
    diag = 2**n*p.as_expr().subs(x, t/2)
    squared = s.Poly(s.cancel(resultant/diag), t, domain=s.QQ).monic()
    out = s.S.One
    for q, e in squared.factor_list()[1]:
        if e % 2:
            raise ConstructionError("pair resolvent quotient is not a square")
        out *= q.as_expr()**(e//2)
    return s.Poly(out, t, domain=s.QQ).monic()


def _small_roots(p: s.Poly) -> list[s.Expr]:
    rr = s.roots(p.as_expr(), p.gen, cubics=True, quartics=True)
    if sum(rr.values()) != p.degree():
        return []
    return [r for r in rr if radical_expression_q(r)]


def structural_candidates(poly: s.Poly, *, depth: int = 0,
                          max_depth: int = 12) -> tuple[list[s.Expr], str]:
    """Exact polynomial identities generate candidates; not a complete search."""
    if depth > max_depth:
        return [], "depth-limit"
    p = poly.monic()
    x, n = p.gen, p.degree()
    if n < 1:
        return [], "constant"
    if n <= 4:
        return _small_roots(p), "degree<=4"
    # Handle reducible auxiliary polynomials without claiming all are solvable.
    fs = p.factor_list()[1]
    if len(fs) > 1 or fs[0][1] > 1:
        out = []
        for f, _ in fs:
            out.extend(structural_candidates(f, depth=depth+1,
                                              max_depth=max_depth)[0])
        return out, "rational-factorization"
    h = -p.nth(n-1)/n
    q = s.Poly(p.as_expr().subs(x, x+h).expand(), x, domain=s.QQ)
    es = [j[0] for j, c in q.terms() if j[0] > 0 and c != 0]
    g = reduce(gcd, es)
    if g > 1:
        y = s.Dummy("y")
        lower = s.Poly(sum(c*y**(j[0]//g) for j, c in q.terms()), y)
        rs, _ = structural_candidates(lower, depth=depth+1, max_depth=max_depth)
        if rs:
            return [h+zeta(g)**k*s.Pow(b, s.Rational(1,g))
                    for b in rs for k in range(g)], "shifted-power"
    # x^m Q(x+a/x): reciprocal and anti-reciprocal reductions.
    if n % 2 == 0 and q.nth(0) != 0:
        m, y = n//2, s.Dummy("y")
        for a in _rational_nth_roots(q.nth(0), m):
            if a == 0:
                continue
            lower_expr = q.nth(m)+sum(q.nth(m+k)*dickson(k,y,a)
                                     for k in range(1,m+1))
            identity = s.cancel(x**m*lower_expr.subs(y,x+a/x)-q.as_expr())
            if identity == 0:
                rs, _ = structural_candidates(s.Poly(lower_expr,y),
                                               depth=depth+1,max_depth=max_depth)
                if rs:
                    return [h+(b+sgn*s.sqrt(b*b-4*a))/2
                            for b in rs for sgn in (1,-1)], "reciprocal"
    # Monic depressed Dickson polynomial plus a constant.
    a = -q.nth(n-2)/n
    dn = dickson(n,x,a)
    c = q.nth(0)-s.Poly(dn,x).nth(0)
    if s.expand(q.as_expr()-dn-c) == 0:
        for t in ((-c+s.sqrt(c*c-4*a**n))/2,
                  (-c-s.sqrt(c*c-4*a**n))/2):
            if t == 0:
                continue
            u = s.Pow(t,s.Rational(1,n))
            return [h+zeta(n)**k*u+a/(zeta(n)**k*u)
                    for k in range(n)], "Dickson"
    # Rational functional decomposition with a small-degree inner factor.
    dec = s.decompose(p.as_expr(),x)
    if len(dec) > 1:
        inner = dec[-1]
        if s.degree(inner,x) <= 4:
            outer = dec[0]
            for d in dec[1:-1]:
                outer = outer.subs(x,d).expand()
            rs, _ = structural_candidates(s.Poly(outer,x),depth=depth+1,
                                           max_depth=max_depth)
            out = []
            for b in rs:
                rr = s.roots(inner-b,x,cubics=True,quartics=True)
                out.extend(r for r in rr if radical_expression_q(r))
            if out:
                return out, "composition"
    return [], "no-structural-match"


def pair_sum_candidates(poly: s.Poly, *, target: s.Expr | None = None) -> Iterable[s.Expr]:
    """Exact small resolvent fields, followed by relative linear--quartic roots.

    This is a finite shortcut, not a complete subfield search. Every coefficient
    is converted from the algebraic-field power basis into the SAME embedded
    radical generator before applying low-degree formulas. Yield lazily so a
    successful branch need not compute the remaining field factorizations.
    """
    resolvent = pair_sum_resolvent(poly)
    for factor, _ in resolvent.factor_list()[1]:
        if not 1 < factor.degree() <= 4:
            continue
        for b in _small_roots(factor):
            field = s.QQ.algebraic_field(b)
            generator = field.ext.root
            if not radical_expression_q(generator):
                continue
            fs = s.Poly(poly.as_expr(), poly.gen, domain=field).factor_list()[1]
            for f, _ in fs:
                if not 1 <= f.degree() <= 4:
                    continue
                coeffs = []
                for a in f.rep.to_list():
                    ac = a.to_list()
                    coeffs.append(sum(s.Rational(c)*generator**(len(ac)-1-i)
                                      for i, c in enumerate(ac)))
                expr = sum(c*poly.gen**(len(coeffs)-1-i)
                           for i, c in enumerate(coeffs))
                roots = _small_roots(s.Poly(expr, poly.gen))
                yield from (_near_order(roots, target) if target is not None else roots)


class QuotientField:
    """Q[t]/(m), with exact rational coefficient vectors in ascending order."""
    def __init__(self, modulus: s.Poly):
        self.t = modulus.gen
        self.m = modulus.set_domain(s.QQ).monic()
        self.d = self.m.degree()
        if not self.m.is_irreducible:
            raise ValueError("modulus must be irreducible over Q")
        self.zero = self.poly(0)
        self.one = self.poly(1)
        self.gen = self.poly(self.t)

    def poly(self, a: Any) -> s.Poly:
        if isinstance(a,s.Poly):
            a = a.as_expr()
        return s.Poly(a,self.t,domain=s.QQ).rem(self.m)

    def add(self,a:s.Poly,b:s.Poly)->s.Poly:
        return (a+b).rem(self.m)

    def mul(self,a:s.Poly,b:s.Poly)->s.Poly:
        return (a*b).rem(self.m)

    def pow(self,a:s.Poly,n:int)->s.Poly:
        if n < 0:
            a = s.invert(a,self.m)
            n = -n
        r = self.one
        while n:
            if n & 1:
                r = self.mul(r,a)
            a = self.mul(a,a)
            n >>= 1
        return r

    def compose(self,a:s.Poly,image:s.Poly)->s.Poly:
        r = self.zero
        for c in a.all_coeffs():
            r = self.add(self.mul(r,image),self.poly(c))
        return r

    def vector(self,a:s.Poly)->s.Matrix:
        return s.Matrix([a.nth(j) for j in range(self.d)])

    def key(self,a:s.Poly)->tuple:
        return tuple(a.nth(j) for j in range(self.d))

    def coords(self,a:s.Poly,basis:list[s.Poly])->s.Matrix:
        mat = s.Matrix.hstack(*(self.vector(b) for b in basis))
        try:
            c, pars = mat.gauss_jordan_solve(self.vector(a))
        except ValueError as exc:
            raise ConstructionError("element is not in the claimed subfield") from exc
        if pars.rows or mat*c != self.vector(a):
            raise ConstructionError("dependent or incorrect field basis")
        return c


class FiniteGroup:
    """Multiplication table of explicitly embedded field automorphisms."""
    def __init__(self, ring:QuotientField, images:list[s.Poly]):
        self.images = images
        lookup = {ring.key(a):i for i,a in enumerate(images)}
        if len(lookup) != len(images):
            raise ConstructionError("duplicate automorphisms")
        try:
            self.identity = lookup[ring.key(ring.gen)]
            # sigma_i sigma_j(theta) = image_j(image_i(theta)).
            self.table = [[lookup[ring.key(ring.compose(b,a))]
                           for b in images] for a in images]
        except KeyError as exc:
            raise ConstructionError("automorphisms are not closed") from exc
        self.elements = frozenset(range(len(images)))
        self.inverse = [next(j for j in self.elements
                             if self.table[i][j] == self.identity
                             and self.table[j][i] == self.identity)
                        for i in range(len(images))]

    def closure(self, gens:Iterable[int])->frozenset[int]:
        generators = set(gens)
        generators |= {self.inverse[g] for g in list(generators)}
        seen, todo = {self.identity}, [self.identity]
        while todo:
            a = todo.pop()
            for b in generators:
                c = self.table[a][b]
                if c not in seen:
                    seen.add(c); todo.append(c)
        return frozenset(seen)

    def derived(self,H:frozenset[int])->frozenset[int]:
        T, inv = self.table,self.inverse
        return self.closure(T[T[T[a][b]][inv[a]]][inv[b]]
                            for a in H for b in H)

    def derived_series(self)->list[frozenset[int]]:
        out = [self.elements]
        while len(out[-1]) > 1:
            d = self.derived(out[-1])
            out.append(d)
            if d == out[-2]:
                break
        return out

    def prime_step(self,H:frozenset[int])->tuple[frozenset[int],int,int]:
        K = self.derived(H)
        if K == H:
            raise ConstructionError("nontrivial perfect group has no prime step")
        # H/K is abelian. Greedily grow K to a maximal proper subgroup.
        for g in sorted(H):
            U = self.closure(set(K)|{g})
            if len(U) < len(H):
                K = U
        p = len(H)//len(K)
        if not s.isprime(p) or len(H) != p*len(K):
            raise ConstructionError("failed to obtain a prime-index subgroup")
        return K,next(g for g in sorted(H) if g not in K),p


def _anp_poly(a:Any, ring:QuotientField)->s.Poly:
    cs = a.to_list()
    return ring.poly(sum(s.Rational(c)*ring.t**(len(cs)-1-i)
                         for i,c in enumerate(cs)))


def _known_roots(poly:s.Poly)->list[s.Expr]:
    # roots() handles binomials and small degrees without expensive CRootOf
    # composita. all_roots is the exact, general fallback.
    r = s.roots(poly.as_expr(),poly.gen)
    if sum(r.values()) == poly.degree():
        return list(r)
    return poly.all_roots(radicals=True)


def complete_radical(target:s.Expr, poly:s.Poly, *,
                     max_field_degree:int|None=128)->RadicalResult:
    """Finite Galois/Kummer construction, assuming terminating exact CAS ops.

    max_field_degree is checked AFTER primitive-element construction, not a
    bound on intermediate allocation. For a hard limit use a worker process.
    """
    roots = _known_roots(poly)
    theta_L = to_number_field(roots)
    dL = theta_L.minpoly.degree()
    if max_field_degree is not None and dL > max_field_degree:
        raise ResourceLimit(f"splitting-field degree {dL} exceeds {max_field_degree}")
    M = int(s.prod(s.factorint(dL))) if dL > 1 else 1
    zz = zeta(M)
    primitive = to_number_field([theta_L.root,zz])
    theta = primitive.root
    t = s.Dummy("t")
    modulus = s.Poly(primitive.minpoly.as_expr().subs(primitive.minpoly.gen,t),t)
    R = QuotientField(modulus)
    if max_field_degree is not None and R.d > max_field_degree:
        raise ResourceLimit(f"cyclotomic compositum degree {R.d} exceeds {max_field_degree}")
    Kfield = s.QQ.algebraic_field(primitive)
    def emb(e:s.Expr)->s.Poly:
        return _anp_poly(Kfield.from_sympy(e),R)
    zp, ap = emb(zz),emb(target)
    # Since E/Q is normal, the minimal polynomial of theta splits in E.
    factors = s.Poly(R.m.as_expr(),t,domain=Kfield).factor_list()[1]
    if len(factors) != R.d or any(f.degree()!=1 or e!=1 for f,e in factors):
        raise ConstructionError("normal-field polynomial did not split completely")
    all_images = []
    for f,_ in factors:
        lead,constant = f.rep.to_list()
        all_images.append(_anp_poly(-constant/lead,R))
    images = [a for a in all_images if R.compose(zp,a) == zp]
    if len(images)*int(s.totient(M)) != R.d:
        raise ConstructionError("wrong cyclotomic stabilizer order")
    G = FiniteGroup(R,images)
    ds = G.derived_series()
    common = {"primitive_element":theta,"modulus":R.m,
              "splitting_degree":dL,"field_degree":R.d,
              "cyclotomic_order":M,"cyclotomic_polynomial":zp,
              "target_polynomial":ap,"automorphisms":images,
              "derived_orders":[len(h) for h in ds]}
    if len(ds[-1]) != 1:
        return RadicalResult("NotSolvable",method="Galois-Kummer",
                             certificate=common,
                             diagnostics=["The exact cyclotomic stabilizer has a nontrivial perfect derived subgroup."])
    zsym = s.Dummy("z")
    basis = [R.pow(zp,j) for j in range(int(s.totient(M)))]
    syntax = [zsym**j for j in range(len(basis))]
    steps,chain = [],[sorted(G.elements)]
    H = G.elements
    while len(H) > 1:
        sub,sigma,p = G.prime_step(H)
        eigen = R.zero
        spowers = [G.identity]
        for j in range(1,p):
            spowers.append(G.table[sigma][spowers[-1]])
        for k in range(R.d):
            tr = R.zero
            monomial = R.pow(R.gen,k)
            for g in sub:
                tr = R.add(tr,R.compose(monomial,images[g]))
            r = R.zero
            for j in range(p):
                weight = R.pow(zp,(-j*(M//p))%M)
                r = R.add(r,R.mul(weight,R.compose(tr,images[spowers[j]])))
            if not r.is_zero:
                eigen = r
                break
        if eigen.is_zero:
            raise ConstructionError("all Kummer eigenprojections vanished")
        if R.compose(eigen,images[sigma]) != R.mul(R.pow(zp,M//p),eigen):
            raise ConstructionError("Kummer eigenvalue identity failed")
        if any(R.compose(eigen,images[g]) != eigen for g in sub):
            raise ConstructionError("Kummer generator not fixed by subgroup")
        power = R.pow(eigen,p)
        coeffs = R.coords(power,basis)
        radicand = s.Add(*(c*b for c,b in zip(coeffs,syntax)))
        algebraic_power = power.as_expr().subs(t,theta)
        algebraic_eigen = eigen.as_expr().subs(t,theta)
        principal = s.Pow(algebraic_power,s.Rational(1,p))
        candidates = [zz**((M//p)*j)*principal for j in range(p)]
        branch = None
        # Ordering is numerical; acceptance is exact field membership/equality.
        for candidate in _near_order(candidates,algebraic_eigen):
            try:
                if emb(candidate) == eigen:
                    branch = candidates.index(candidate)
                    break
            except (IsomorphismFailed,CoercionFailed,ValueError,NotImplementedError):
                continue
        if branch is None:
            raise ConstructionError("could not certify the principal-root branch")
        rsym = s.Dummy(f"r{len(steps)+1}")
        steps.append({"symbol":rsym,"prime":p,"radicand":radicand,
                      "branch":branch,"generator_polynomial":eigen,
                      "power_polynomial":power,"radicand_coordinates":list(coeffs)})
        basis = [R.mul(b,R.pow(eigen,j)) for j in range(p) for b in basis]
        syntax = [b*rsym**j for j in range(p) for b in syntax]
        H = sub;chain.append(sorted(H))
    if len(basis) != R.d:
        raise ConstructionError("terminal tower does not span the whole field")
    coeffs = R.coords(ap,basis)
    formula = s.Add(*(c*b for c,b in zip(coeffs,syntax)))
    rules = {zsym:zz}
    for st in steps:
        a = st["radicand"].xreplace(rules)
        rules[st["symbol"]] = zz**((M//st["prime"])*st["branch"])*s.Pow(a,s.Rational(1,st["prime"]))
    expression = formula.xreplace(rules)
    if not radical_expression_q(expression):
        raise ConstructionError("expanded output is not in the strict radical grammar")
    common.update({"z_symbol":zsym,"steps":steps,"subgroup_chain":chain,
                   "formula":formula,"expression":expression,
                   "verification":"exact quotient identities and embedded branch checks"})
    result = RadicalResult("Success",expression,"Galois-Kummer",common)
    if not verify_tower(result,target,check_branches=False):
        raise ConstructionError("independent tower identity check failed")
    return result


def verify_tower(result:RadicalResult, target:s.Expr, *,check_branches:bool=True)->bool:
    """Recheck positive tower identities, optionally all exact branch choices.

    Does not re-run group theory, and does not certify a negative result.
    The embedded primitive element and target are checked when branches=True.
    """
    if result.status != "Success" or result.method != "Galois-Kummer":
        return False
    try:
        c = result.certificate
        R = QuotientField(c["modulus"])
        theta,M = c["primitive_element"],c["cyclotomic_order"]
        if check_branches:
            if s.Poly(s.minpoly(theta,R.t),R.t).monic() != R.m:
                return False
            K = s.QQ.algebraic_field(theta)
            emb = lambda e:_anp_poly(K.from_sympy(e),R)
            # SymPy Poly pickling may infer ZZ for integral coefficients.
            # Normalize every stored polynomial back into Q[t]/m before equality.
            if emb(target) != R.poly(c["target_polynomial"]) or emb(zeta(M)) != R.poly(c["cyclotomic_polynomial"]):
                return False
        polys = {c["z_symbol"]:c["cyclotomic_polynomial"].as_expr()}
        rules = {c["z_symbol"]:zeta(M)}
        for st in c["steps"]:
            p,j = st["prime"],st["branch"]
            if not s.isprime(p) or M % p or not 0 <= j < p:
                return False
            a = R.poly(st["radicand"].xreplace(polys))
            r = R.poly(st["generator_polynomial"])
            if R.pow(r,p) != a:
                return False
            if check_branches:
                val = a.as_expr().subs(R.t,theta)
                br = zeta(M)**((M//p)*j)*s.Pow(val,s.Rational(1,p))
                if emb(br) != r:
                    return False
            rules[st["symbol"]] = zeta(M)**((M//p)*j)*s.Pow(st["radicand"].xreplace(rules),s.Rational(1,p))
            polys[st["symbol"]] = r.as_expr()
        return (R.poly(c["formula"].xreplace(polys)) == R.poly(c["target_polynomial"])
                and c["formula"].xreplace(rules) == result.expression
                and radical_expression_q(result.expression))
    except (KeyError,TypeError,ValueError,ConstructionError,CoercionFailed,IsomorphismFailed):
        return False


def solve_radical(polynomial:Any, index:int=0, *, variable:s.Symbol|None=None,
                  method:str="automatic",max_field_degree:int|None=128,
                  max_depth:int=12, pair_resolvent:bool=True)->RadicalResult:
    """Solve one indexed root; indices are zero-based SymPy indices.

    method='practical': structural and small pair-resolvent search, then degree<=6
        solvability diagnosis. A solvable miss is Inconclusive.
    method='automatic': structural search followed by the general backend.
    method='complete': force the general backend (useful for testing).
    Set max_field_degree=None and use no external timeout for the unbounded
    mathematical algorithm. This is NOT a promise of feasible resource usage.
    """
    try:
        if method not in {"automatic","practical","complete"}:
            raise ValueError("method must be automatic, practical, or complete")
        if max_field_degree is not None and (not isinstance(max_field_degree,int) or isinstance(max_field_degree,bool) or max_field_degree < 1):
            raise ValueError("max_field_degree must be a positive integer or None")
        if not isinstance(max_depth,int) or isinstance(max_depth,bool) or max_depth < 0:
            raise ValueError("max_depth must be a nonnegative integer")
        if not isinstance(pair_resolvent,bool):
            raise ValueError("pair_resolvent must be True or False")
        if not isinstance(index,int) or isinstance(index,bool):
            raise ValueError("index must be an integer")
        p = polynomial if isinstance(polynomial,s.Poly) else s.Poly(polynomial,variable)
        if len(p.gens)!=1 or p.as_expr().has(s.Float):
            raise ValueError("require one-variable exact rational coefficients")
        p = p.set_domain(s.QQ)
        if p.degree()<1 or not 0 <= index < p.degree():
            raise ValueError("root index out of range")
        target = s.CRootOf(p.as_expr(),index)
        x = p.gen
        minimal = s.Poly(s.minpoly(target,x),x,domain=s.QQ).monic()
    except (ValueError,TypeError,s.PolynomialError,CoercionFailed) as exc:
        return RadicalResult("InvalidInput",diagnostics=[str(exc)])
    shortcut_errors = []
    try:
        if target.is_Rational:
            return RadicalResult("Success",target,"rational",
                                 {"target":target,"minimal_polynomial":minimal})
        if method != "complete":
            try:
                cs,which = structural_candidates(minimal,max_depth=max_depth)
                for c in _near_order(cs,target):
                    if radical_expression_q(c) and exact_equal(c,target):
                        return RadicalResult("Success",c,which,
                            {"target":target,"minimal_polynomial":minimal,
                             "verification":"exact embedded number-field equality"},
                            shortcut_errors)
            except Exception as exc:
                shortcut_errors.append(f"Structural shortcut failed: {type(exc).__name__}: {exc}")
            if pair_resolvent and minimal.degree() <= 12:
                try:
                    for c in pair_sum_candidates(minimal,target=target):
                        if radical_expression_q(c) and exact_equal(c,target):
                            return RadicalResult("Success",c,"pair-resolvent",
                                {"target":target,"minimal_polynomial":minimal,
                                 "verification":"exact embedded number-field equality"},
                                shortcut_errors)
                except Exception as exc:
                    shortcut_errors.append(f"Pair-resolvent shortcut failed: {type(exc).__name__}: {exc}")
            if minimal.degree() <= 6:
                try:
                    group, _ = s.polys.numberfields.galois_group(minimal)
                    if not group.is_solvable:
                        return RadicalResult("NotSolvable",method="SymPy-Galois",
                            certificate={"minimal_polynomial":minimal,
                                         "group_order":group.order()},
                            diagnostics=shortcut_errors)
                except Exception as exc:
                    shortcut_errors.append(f"Small-degree Galois shortcut failed: {type(exc).__name__}: {exc}")
            if method == "practical":
                return RadicalResult("Inconclusive",method="practical",
                    diagnostics=shortcut_errors + ["Practical methods did not produce a certified expression; this is not a nonsolvability proof."])
        result = complete_radical(target,minimal,max_field_degree=max_field_degree)
        result.diagnostics.extend(shortcut_errors)
        return result
    except ResourceLimit as exc:
        return RadicalResult("Inconclusive",method=method,
                             diagnostics=shortcut_errors+[str(exc)])
    except Exception as exc:
        # A CAS failure must never be promoted to a mathematical impossibility.
        return RadicalResult("Inconclusive",method=method,
                             diagnostics=shortcut_errors+[f"{type(exc).__name__}: {exc}"])


def _worker(out:Any,args:tuple,kwargs:dict)->None:
    out.put(solve_radical(*args,**kwargs))


def solve_with_timeout(polynomial:Any,index:int=0, *,seconds:float=60,
                       **kwargs:Any)->RadicalResult:
    """Portable process wall-clock bound; call scripts under __main__ on Windows."""
    if seconds <= 0:
        raise ValueError("seconds must be positive")
    ctx = mp.get_context("spawn")
    out = ctx.Queue()
    process = ctx.Process(target=_worker,args=(out,(polynomial,index),kwargs))
    process.start()
    # Read while the process is alive: joining first can deadlock on large output.
    try:
        result = out.get(timeout=seconds)
    except queue.Empty:
        process.terminate();process.join()
        return RadicalResult("Inconclusive",diagnostics=["Wall-clock limit exceeded; no mathematical conclusion."])
    finally:
        out.close()
    process.join(timeout=2)
    if process.is_alive():
        process.terminate();process.join()
    return result


def main()->None:
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("polynomial",help="trusted local SymPy expression in x")
    ap.add_argument("--index",type=int,default=0,help="ZERO-based SymPy index")
    ap.add_argument("--method",choices=["automatic","practical","complete"],default="automatic")
    ap.add_argument("--timeout",type=float,default=60)
    ap.add_argument("--max-field-degree",type=int,default=128,help="0 disables degree cap")
    a = ap.parse_args()
    x=s.Symbol("x")
    # sympify is NOT a sandbox. Only pass trusted local expressions.
    p=s.sympify(a.polynomial,locals={"x":x})
    result=solve_with_timeout(p,a.index,variable=x,seconds=a.timeout,method=a.method,
                              max_field_degree=a.max_field_degree or None)
    print("Status:",result.status," Method:",result.method)
    if result.expression is not None:
        print("Expression:",s.sstr(result.expression))
        print("Approximation:",s.N(result.expression,20))
    for message in result.diagnostics:
        print(message)

if __name__ == "__main__":
    main()
