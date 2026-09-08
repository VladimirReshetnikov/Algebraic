"""Exact radicals for rational polynomials (reference implementation).

Fast structural reductions precede a finite splitting-field / Fourier algorithm.
All numerical root comparisons have a proved common annihilating polynomial;
SymPy's root-separation-bounded same_root is not used as an identity guesser.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from math import gcd, isfinite
from functools import reduce
from itertools import permutations
from typing import Any, Iterable
import time
import sympy as s
from sympy.polys.polyerrors import PolynomialError

X, U, T, Z, V = s.symbols('_x _u _t _z _v')

class RadicalError(Exception):
    """A status-bearing error. ResourceLimit is not NotSolvable."""
    status = 'Error'
    def __init__(self, message: str, **details: Any):
        super().__init__(message)
        self.details = details

class ResourceLimit(RadicalError):
    status = 'ResourceLimit'

class NotSolvable(RadicalError):
    status = 'NotSolvable'

class InvalidInput(RadicalError):
    status = 'InvalidInput'

@dataclass
class Budget:
    max_field_degree: int | None = 96
    max_seconds: float | None = None
    start: float = field(default_factory=time.monotonic)
    def check(self, degree: int | None = None) -> None:
        if degree is not None and self.max_field_degree is not None and degree > self.max_field_degree:
            raise ResourceLimit('The exact field-degree budget was exceeded.',
                                required_degree=degree, limit=self.max_field_degree)
        if self.max_seconds is not None and time.monotonic()-self.start > self.max_seconds:
            raise ResourceLimit('The cooperative time budget was exceeded.',
                                limit=self.max_seconds)

@dataclass
class Result:
    expression: s.Expr
    method: str
    record: dict[str, Any]
    def wolfram(self) -> str:
        from sympy.printing.mathematica import mathematica_code
        return mathematica_code(self.expression)

def rational_poly(poly: Any, variable: s.Symbol | None = None) -> s.Poly:
    try:
        p = poly if isinstance(poly, s.Poly) else (
            s.Poly(poly,variable) if variable is not None else s.Poly(poly))
        if len(p.gens) != 1 or p.degree() < 1:
            raise InvalidInput('A nonconstant univariate polynomial is required.')
        if not all(c.is_Rational for c in p.all_coeffs()):
            raise InvalidInput('Coefficients must be exact rational numbers; floats are rejected.')
        return s.Poly.from_list(p.all_coeffs(), X, domain=s.QQ).monic()
    except (s.CoercionFailed, PolynomialError, TypeError, ValueError) as exc:
        raise InvalidInput('Coefficients must be exact rational numbers.') from exc

def radical_expression_q(e: s.Expr) -> bool:
    if e.is_Rational or e == s.I:
        return True
    if e.func in (s.Add, s.Mul):
        return all(radical_expression_q(a) for a in e.args)
    return e.func == s.Pow and e.exp.is_Rational and radical_expression_q(e.base)

def same_known_root(poly: s.Poly, a: s.Expr, b: s.Expr) -> bool:
    """PRECONDITION: both a and b are roots of poly, by an exact argument."""
    if a == b:
        return True
    p = poly.sqf_part()
    if p.degree() == 1:
        return True                 # There is exactly one root, under the precondition.
    return bool(p.same_root(a, b))   # Mignotte separation + bounded-error evaluation.

def root_of_unity(n: int, k: int = 1) -> s.Expr:
    if n < 1:
        raise ValueError('positive order required')
    k %= n
    if k == 0:
        return s.S.One
    if n == 2:
        return s.S.NegativeOne
    if n == 3:
        return -s.Rational(1,2) + (1 if k == 1 else -1)*s.I*s.sqrt(3)/2
    if n == 4:
        return s.I**k
    return s.Pow(s.Integer(-1), s.Rational(2*k, n))

def _rational_nth_roots(q: s.Rational, n: int) -> list[s.Rational]:
    if q == 0:
        return [s.S.Zero]
    if q < 0 and n % 2 == 0:
        return []
    a, ok1 = s.integer_nthroot(abs(int(q.p)), n)
    b, ok2 = s.integer_nthroot(int(q.q), n)
    if not (ok1 and ok2):
        return []
    r = s.Rational(a, b) * (-1 if q < 0 else 1)
    return [r, -r] if n % 2 == 0 else [r]

def _dedupe_known(poly: s.Poly, values: Iterable[s.Expr]) -> list[s.Expr]:
    out = []
    for a in values:
        if not any(same_known_root(poly, a, b) for b in out):
            out.append(a)
    return out

class Solver:
    """One session; subproblems, field construction and descent share caches.

    method='auto': exact structural algorithms then the general method.
    method='galois': force the general method (useful for testing).
    """
    def __init__(self, *, method: str = 'auto', max_field_degree: int | None = 96,
                 max_seconds: float | None = None):
        if method not in ('auto', 'galois'):
            raise InvalidInput('method must be auto or galois')
        if max_field_degree is not None and (type(max_field_degree) is not int or max_field_degree < 1):
            raise InvalidInput('max_field_degree must be a positive integer or None')
        if max_seconds is not None and (isinstance(max_seconds,bool) or
                not isinstance(max_seconds,(int,float)) or
                not isfinite(max_seconds) or max_seconds <= 0):
            raise InvalidInput('max_seconds must be positive or None')
        self.method = method
        self.budget = Budget(max_field_degree, max_seconds)
        self.cache: dict[tuple, list[Result]] = {}
        self.events: list[dict[str, Any]] = []

    def all_roots(self, poly: Any, variable: s.Symbol | None = None) -> list[Result]:
        p = rational_poly(poly, variable).sqf_part().monic()
        self.budget.check()
        key = tuple(p.all_coeffs())
        if key in self.cache:
            return self.cache[key]
        if p.degree() == 1:
            out = [Result(-p.nth(0), 'rational', {'polynomial': str(p.as_expr())})]
        elif not p.is_irreducible:
            # Solvability belongs to each irreducible factor, not their product.
            out = []
            for f, _ in p.factor_list()[1]:
                out.extend(self.all_roots(f))
        else:
            out = self._fast(p) if self.method == 'auto' else None
            if out is None:
                self._negative_test(p)
                engine = GaloisEngine(p, self.budget, self.events)
                out = [Result(engine.radical(r), 'galois-fourier', engine.report())
                       for r in engine.roots]
        if len(out) != p.degree() or not all(radical_expression_q(r.expression) for r in out):
            raise RadicalError('Internal invariant: incomplete roots or non-radical output.')
        self.cache[key] = out
        return out

    def root(self, poly: Any, index: int, variable: s.Symbol | None = None) -> Result:
        p = rational_poly(poly, variable)
        if type(index) is not int or not 0 <= index < p.degree():
            raise InvalidInput('index is zero-based in SymPy CRootOf ordering, with multiplicity')
        target = s.CRootOf(p, index)
        if target.is_Rational:
            return Result(target, 'rational', {'input_index': index})
        # Select a factor before solving: other factors can be nonsolvable.
        q = p.sqf_part()
        selected = None
        for f, _ in q.factor_list()[1]:
            if any(same_known_root(q, target, s.CRootOf(f, j)) for j in range(f.degree())):
                selected = f
                break
        assert selected is not None
        for result in self.all_roots(selected):
            if same_known_root(selected, target, result.expression):
                return result
        raise RadicalError('Internal invariant: target embedding was not found.')

    def _negative_test(self, p: s.Poly) -> None:
        # SymPy implements exact resolvent-based Galois classification through degree six.
        if 3 <= p.degree() <= 6:
            try:
                group, _ = s.polys.numberfields.galois_group(p)
            except (NotImplementedError, s.polys.numberfields.galoisgroups.MaxTriesException):
                return
            self.events.append({'stage': 'galois-classification', 'order': int(group.order()),
                                'solvable': bool(group.is_solvable)})
            if not group.is_solvable:
                raise NotSolvable('The irreducible polynomial has a nonsolvable Galois group.',
                                  polynomial=str(p.as_expr()), group_order=int(group.order()),
                                  generators=[list(g.array_form) for g in group.generators],
                                  backend='sympy.polys.numberfields.galois_group')

    def _fast(self, p: s.Poly) -> list[Result] | None:
        n = p.degree()
        center = -p.nth(n-1)/n
        q = s.Poly(p.as_expr().subs(X, X+center), X, domain=s.QQ)
        cert = {'polynomial': str(p.as_expr()), 'center': str(center),
                'verification': 'exact polynomial identity; embeddings by root separation'}
        # Polynomial decomposition after removing the x^(n-1) coefficient.
        exponents = [j for j in range(1, n+1) if q.nth(j) != 0]
        power = reduce(gcd, exponents)
        if power > 1:
            inner = s.Poly(sum(q.nth(j)*X**(j//power) for j in range(0,n+1,power)), X)
            values = [center+root_of_unity(power,k)*s.Pow(r.expression,s.Rational(1,power))
                      for r in self.all_roots(inner) for k in range(power)]
            values = _dedupe_known(p, values)
            return [Result(v, 'power-composition', dict(cert, power=power)) for v in values]
        # Dickson polynomial D_n(y,a), D_0=2, D_1=y.
        a = -q.nth(n-2)/n if n > 2 else s.S.Zero
        d0, d1 = s.Integer(2), X
        for _ in range(2,n+1):
            d0, d1 = d1, s.expand(X*d1-a*d0)
        diff = s.Poly(d1-q.as_expr(), X)
        if diff.degree() <= 0:
            b = diff.nth(0)
            t = s.Pow((b+s.sqrt(b*b-4*a**n))/2, s.Rational(1,n))
            if a == 0:
                values = [center+root_of_unity(n,k)*s.Pow(b,s.Rational(1,n)) for k in range(n)]
            else:
                values = [center+(u := root_of_unity(n,k)*t)+a/u for k in range(n)]
            return [Result(v, 'dickson', dict(cert, a=str(a), b=str(b), order=n)) for v in values]
        # Generalized reciprocal polynomial: q(y)=y^m P(y+a/y), deg q=2m.
        if n % 2 == 0 and q.nth(0) != 0:
            m = n//2
            for a in _rational_nth_roots(q.nth(0), m):
                residual = q.as_expr()
                coeffs = {}
                for j in range(m,-1,-1):
                    c = s.Poly(residual,X).nth(m+j)
                    coeffs[j] = c
                    residual = s.expand(residual-c*s.expand(X**m*(X+a/X)**j))
                if residual == 0:
                    inner = s.Poly(sum(c*X**j for j,c in coeffs.items()), X)
                    values = []
                    for r in self.all_roots(inner):
                        y = r.expression
                        values += [center+(y+s.sqrt(y*y-4*a))/2,
                                   center+(y-s.sqrt(y*y-4*a))/2]
                    values = _dedupe_known(p, values)
                    return [Result(v, 'reciprocal-composition', dict(cert,a=str(a),inner=str(inner.as_expr())))
                            for v in values]
        # SymPy's explicit low-degree formulas; no quintic heuristic here.
        if n <= 4:
            rr = s.roots(p.as_expr(), X, cubics=True, quartics=True)
            if sum(rr.values()) == n and all(radical_expression_q(e) for e in rr):
                return [Result(v, 'classical-formula', cert) for v in rr]
        return None

# ---------- Exact normal closure and its automorphisms ----------

def anp_expr(a: Any, variable: s.Symbol) -> s.Expr:
    return s.Poly.from_list([s.QQ.to_sympy(c) for c in a.to_list()], variable).as_expr()

def anp_key(a: Any) -> tuple:
    return tuple(a.to_list())

def substitute(a: Any, image: Any, K: Any) -> Any:
    value = K.zero
    for c in a.to_list():
        value = value*image+K.convert(c, s.QQ)
    return value

class GaloisEngine:
    def __init__(self, p: s.Poly, budget: Budget, events: list[dict[str,Any]]):
        self.p, self.budget, self.events = p, budget, events
        self.h = s.Poly(p.as_expr().subs(X,T), T, domain=s.QQ).monic()
        self.primitive_weights = [1]
        self._normal_closure()
        self._automorphisms()
        self._chain()
        self.memo: dict[tuple, s.Expr] = {}
        self.norm_cache: dict[tuple,s.Poly] = {}
        self.branch_checks = 0
        self.descent_nodes = 0

    def _field(self, h: s.Poly) -> Any:
        self.budget.check(h.degree())
        # Supplying the already proved minimal polynomial avoids minpoly(CRootOf).
        return s.QQ.algebraic_field((h, s.CRootOf(h,0)))

    def _normal_closure(self) -> None:
        while True:
            self.K = self._field(self.h)
            factors = s.Poly(self.p.as_expr(), X, domain=self.K).factor_list()[1]
            nonlin = [g for g,m in factors if g.degree()>1]
            self.events.append({'stage':'splitting-field', 'degree':self.h.degree(),
                                'factor_degrees':[g.degree() for g,m in factors]})
            if not nonlin:
                self.roots = [-g.rep.to_list()[-1]/g.rep.to_list()[0] for g,m in factors]
                self.theta = self.K.ext.root
                return
            g = min(nonlin, key=lambda a:a.degree())
            e = g.degree()
            self.budget.check(e*self.h.degree())
            gu = sum(anp_expr(c,U)*X**(e-j) for j,c in enumerate(g.rep.to_list()))
            hu = self.h.as_expr().subs(T,U)
            c = 1
            while True:
                self.budget.check()
                transformed = s.Poly(c**e*gu.subs(X,(T-U)/c), U,T).as_expr()
                H = s.Poly(s.resultant(hu,transformed,U), T, domain=s.QQ).monic()
                if H.degree() == self.h.degree()*e and H.is_sqf:
                    self.events.append({'stage':'primitive-element', 'coefficient':c,
                                        'old_degree':self.h.degree(), 'new_degree':H.degree()})
                    self.h = H
                    self.primitive_weights.append(c)
                    break
                c += 1

    def _automorphisms(self) -> None:
        K = self.K
        # Every primitive element constructed above is a weighted sum of distinct
        # original roots. Enumerate their possible images, testing h(image)=0.
        # This avoids factoring a degree-d polynomial over a degree-d field.
        hc = [K.convert(c) for c in self.h.all_coeffs()]
        weights = [K.convert(c) for c in self.primitive_weights]
        images = {}
        seen = set()
        tested = 0
        for indices in permutations(range(len(self.roots)),len(weights)):
            self.budget.check()
            image = sum((w*self.roots[j] for w,j in zip(weights,indices)),K.zero)
            key = anp_key(image)
            if key in seen:
                continue
            seen.add(key)
            value = K.zero
            for c in hc:
                value = value*image+c
            tested += 1
            if value == K.zero:
                images[key] = image
                if len(images) == self.h.degree():
                    break
        self.images = list(images.values())
        self.d = len(self.images)
        if self.d != self.h.degree():
            raise RadicalError('Internal invariant: not all primitive conjugates were recovered.')
        lookup = {anp_key(a):j for j,a in enumerate(self.images)}
        self.identity = lookup[anp_key(K.unit)]
        self.mul = []
        for a in self.images:
            self.budget.check()
            self.mul.append([lookup[anp_key(substitute(b,a,K))] for b in self.images])
        self.inv = [next(j for j in range(self.d) if self.mul[i][j]==self.identity) for i in range(self.d)]
        self.events.append({'stage':'automorphisms','order':self.d,
                            'primitive_weights':self.primitive_weights,
                            'candidates_tested':tested})

    def _closure(self, generators: Iterable[int]) -> set[int]:
        gens = sorted(set(generators))
        out, todo = {self.identity}, [self.identity]
        while todo:
            a = todo.pop()
            for b in gens:
                c = self.mul[a][b]
                if c not in out:
                    out.add(c); todo.append(c)
        return out

    def _chain(self) -> None:
        H = set(range(self.d))
        self.groups = [H]
        self.steps = []
        while len(H)>1:
            self.budget.check()
            comm = {self.mul[self.mul[self.mul[a][b]][self.inv[a]]][self.inv[b]] for a in H for b in H}
            D = self._closure(comm)
            if D == H:
                raise NotSolvable('The splitting-field Galois group has a nontrivial perfect subgroup.',
                                  group_order=self.d, perfect_subgroup_order=len(H),
                                  primitive_polynomial=str(self.h.as_expr()))
            N = D
            for g in sorted(H):
                if g not in N:
                    new = self._closure(N|{g})
                    if len(new)<len(H):
                        N = new
            p = len(H)//len(N)
            if len(H)%len(N) or not s.isprime(p):
                raise RadicalError('Internal invariant: quotient is not of prime order.')
            if any(self.mul[self.mul[a][b]][self.inv[a]] not in N for a in H for b in N):
                raise RadicalError('Internal invariant: subgroup is not normal.')
            sigma = min(H-N)
            self.steps.append((int(p),sigma))
            self.groups.append(N)
            H = N
        self.events.append({'stage':'composition-series','orders':[len(g) for g in self.groups],
                            'prime_indices':[p for p,sigma in self.steps]})

    def action(self, a: Any, sigma: int) -> Any:
        return substitute(a,self.images[sigma],self.K)

    def fixed(self, a: Any, group: Iterable[int]) -> bool:
        return all(self.action(a,g)==a for g in group)

    # Tensor elements are (p-1)-tuples over K. There is deliberately no division.
    def tmul(self, a: tuple, b: tuple, p: int) -> tuple:
        zero = self.K.zero
        v = [zero]*(2*p-3)
        for i,ai in enumerate(a):
            for j,bj in enumerate(b):
                v[i+j] += ai*bj
        for k in range(len(v)-1,p-2,-1):
            c = v[k]
            for j in range(k-p+1,k):
                v[j] -= c
        return tuple(v[:p-1])

    def tpow(self, a: tuple, n: int, p: int) -> tuple:
        out = (self.K.one,)+(self.K.zero,)*(p-2)
        while n:
            if n&1:
                out = self.tmul(out,a,p)
            n >>= 1
            if n:
                a = self.tmul(a,a,p)
        return out

    def resolvent(self, a: Any, p: int, sigma: int, k: int) -> tuple:
        v = [self.K.zero]*(p-1)
        b = a
        for j in range(p):
            exp = (-k*j)%p
            if exp == p-1:
                v = [c-b for c in v]
            else:
                v[exp] += b
            b = self.action(b,sigma)
        if b != a:
            raise RadicalError('Internal invariant: quotient orbit did not close.')
        return tuple(v)

    def norm_polynomial(self, R: tuple, p: int) -> s.Poly:
        key = (p,tuple(anp_key(a) for a in R))
        if key in self.norm_cache:
            return self.norm_cache[key]
        self.budget.check()
        re = sum(anp_expr(a,U)*Z**j for j,a in enumerate(R))
        phi = sum(Z**j for j in range(p))
        nz = s.resultant(phi,V-re,Z)
        nn = s.resultant(self.h.as_expr().subs(T,U),nz,U)
        norm = s.Poly(nn,V,domain=s.QQ).sqf_part().monic()
        assert norm.degree() >= 1
        self.norm_cache[key] = norm
        return norm

    def radical(self, a: Any, level: int | None = None) -> s.Expr:
        if level is None:
            level = len(self.steps)
        key = (anp_key(a),level)
        if key in self.memo:
            return self.memo[key]
        self.budget.check()
        self.descent_nodes += 1
        if not self.fixed(a,self.groups[level]):
            raise RadicalError('Internal invariant: descent element is not fixed by its subgroup.')
        coeff = a.to_list()
        if len(coeff)<=1:
            out = s.QQ.to_sympy(coeff[0]) if coeff else s.S.Zero
        elif level == 0:
            raise RadicalError('Internal invariant: fixed field of full Galois group is not Q.')
        elif self.fixed(a,self.groups[level-1]):
            out = self.radical(a,level-1)
        else:
            p,sigma = self.steps[level-1]
            zeta = root_of_unity(p)
            trace = self.K.zero
            b = a
            for j in range(p):
                trace += b
                b = self.action(b,sigma)
            pieces = [self.radical(trace,level-1)]
            for k in range(1,p):
                R = self.resolvent(a,p,sigma,k)
                if all(c==self.K.zero for c in R):
                    pieces.append(s.S.Zero)
                    continue
                norm = self.norm_polynomial(R,p)
                actual = sum(anp_expr(c,self.theta)*zeta**j for j,c in enumerate(R))
                if norm.degree() == 1:
                    pieces.append(-norm.nth(0)/norm.nth(1))
                    continue
                if norm.nth(0)==0 and same_known_root(norm,actual,s.S.Zero):
                    pieces.append(s.S.Zero)
                    self.branch_checks += 1
                    continue
                q = self.tpow(R,p,p)
                if not all(self.fixed(c,self.groups[level-1]) for c in q):
                    raise RadicalError('Internal invariant: resolvent power failed to descend.')
                qexpr = sum(self.radical(c,level-1)*zeta**j for j,c in enumerate(q))
                if p <= 3:
                    # Distribute only this level's products, never denest powers.
                    qexpr = s.expand(qexpr, deep=False, power_base=False,
                                     power_exp=False, multinomial=False)
                principal = s.Pow(qexpr,s.Rational(1,p))
                found = None
                # Each candidate is a known root of norm: sigma rotates R by zeta^k.
                for e in range(p):
                    candidate = root_of_unity(p,e)*principal
                    self.branch_checks += 1
                    if same_known_root(norm,actual,candidate):
                        found = candidate
                        break
                if found is None:
                    raise RadicalError('Internal invariant: no exact resolvent branch matched.')
                pieces.append(found)
            out = s.Add(*pieces)/p
        if not radical_expression_q(out):
            raise RadicalError('Internal invariant: a non-radical expression escaped descent.')
        self.memo[key] = out
        return out

    def report(self) -> dict[str,Any]:
        return {'primitive_polynomial':str(self.h.as_expr()),'field_degree':self.d,
                'subgroup_orders':[len(g) for g in self.groups],
                'prime_indices':[p for p,sigma in self.steps],
                'descent_nodes':self.descent_nodes,'branch_checks':self.branch_checks,
                'verification':'exact field identities and separation-bounded embedding checks',
                'formal_proof_assistant_checked':False}

def radicalize(poly: Any, index: int = 0, variable: s.Symbol | None = None, **options: Any) -> Result:
    return Solver(**options).root(poly,index,variable)

def verify(poly: Any, expression: s.Expr, *, index: int | None = None,
           variable: s.Symbol | None = None) -> bool:
    """Independent verification: minimal polynomial divisibility, then embedding.

    Can be substantially more expensive than certificate-preserving construction.
    A timeout must be enforced externally if a hard runtime limit is needed.
    """
    p = rational_poly(poly,variable)
    if not radical_expression_q(expression):
        return False
    m = s.Poly(s.minpoly(expression,X),X,domain=s.QQ)
    if not p.rem(m).is_zero:
        return False
    if index is None:
        return True
    if not 0 <= index < p.degree():
        raise InvalidInput('root index out of range')
    return same_known_root(p,s.CRootOf(p,index),expression)
