"""Exact radical conversion over Q, with a constructive Galois fallback.

Python 3.10+; SymPy 1.14.  Root indices are ZERO-based SymPy indices,
not Mathematica's ordering of nonreal roots.  See README and the article.
The algebraic kernel (SymPy), not a floating tolerance, is trusted.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from functools import reduce
from math import gcd
from typing import Any, Iterable, Optional
import argparse
import json
import time
import sympy as sp
from sympy.polys.polyerrors import CoercionFailed, IsomorphismFailed

X = sp.Symbol("x")

class RadicalError(Exception):
    """A failed backend operation, not a proof of nonsolvability."""

class ResourceLimit(RadicalError):
    pass


def radical_expression_q(e: sp.Expr) -> bool:
    e = sp.sympify(e)
    if e.is_Rational or e == sp.I:
        return True
    if e.func in (sp.Add, sp.Mul):
        return all(radical_expression_q(a) for a in e.args)
    if e.func == sp.Pow:
        return bool(e.exp.is_Rational) and radical_expression_q(e.base)
    return False


def zeta(n: int) -> sp.Expr:
    """A genuine principal-power radical, with no trigonometric constants."""
    if n < 1:
        raise ValueError("The order must be positive")
    return sp.S.One if n == 1 else sp.Pow(-1, sp.Rational(2, n))


def _annihilates(f: sp.Poly, e: sp.Expr) -> bool:
    """Exact minimal-polynomial divisibility, including rational inputs."""
    m = sp.Poly(sp.minpoly(e, f.gen), f.gen, domain=sp.QQ)
    return f.rem(m).is_zero


def _dyadic_value(v: Any) -> sp.Rational:
    """An exact rational interpretation of a finite internal mpf tuple."""
    if v is None:
        return sp.S.Zero
    sign,mantissa,exponent,_=v
    return (-1 if sign else 1)*sp.Integer(mantissa)*sp.Pow(2,int(exponent))


def same_algebraic_root(f: sp.Poly, a: sp.Expr, b: sp.Expr,
                        *, both_known_roots: bool = False) -> bool:
    """Compare two known roots using separation and bounded evaluation.

    Both inputs must be roots of f. If delta is a separation lower bound,
    evaluate each within epsilon < delta/8 and compare their dyadic squared
    distance to delta^2/4. Equal roots are closer than delta/4; distinct
    roots are farther than 3*delta/4. No arbitrary tolerance is accepted.
    SymPy 1.14 supplies the exact Mignotte bound and bounded-error evaluator.
    """
    f = f.sqf_part().monic()
    if not both_known_roots and not (_annihilates(f, a) and _annihilates(f, b)):
        return False
    if f.degree() == 1:
        return True
    if f.degree()<1:
        raise ValueError("Root comparison needs a nonconstant polynomial")
    from sympy.core.evalf import _evalf_with_bounded_error
    f=f.clear_denoms(convert=True)[1]
    delta_sq=f.domain.get_field().to_sympy(f.rep.mignotte_sep_bound_squared())
    bits=16
    while sp.Rational(1,2**(2*bits))>=delta_sq/64:
        bits*=2
    A=_evalf_with_bounded_error(a,m=bits)
    B=_evalf_with_bounded_error(b,m=bits)
    distance_sq=sum((_dyadic_value(A[j])-_dyadic_value(B[j]))**2 for j in (0,1))
    return bool(distance_sq<delta_sq/4)


def radical_ast(e: sp.Expr) -> list[Any]:
    """Non-executable JSON syntax; references use the explicit Var tag."""
    e=sp.sympify(e)
    if e.is_Rational:
        return ["Q",str(e.p),str(e.q)]
    if e==sp.I:
        return ["I"]
    if isinstance(e,sp.Symbol):
        return ["Var",str(e)]
    if e.func in (sp.Add,sp.Mul):
        return ["Add" if e.func==sp.Add else "Mul",*[radical_ast(a) for a in e.args]]
    if e.func==sp.Pow and e.exp.is_Rational:
        return ["Pow",radical_ast(e.base),str(e.exp.p),str(e.exp.q)]
    raise RadicalError("Nonradical node in output syntax")


def expression_from_ast(node: list[Any],variables: Optional[dict[str,sp.Symbol]]=None) -> sp.Expr:
    """Decode the finite arithmetic JSON grammar; never evaluate source code."""
    variables={} if variables is None else variables
    if not isinstance(node,list) or not node:
        raise ValueError("Invalid radical AST")
    tag=node[0]
    if tag=="Q" and len(node)==3:
        return sp.Rational(int(node[1]),int(node[2]))
    if tag=="I" and len(node)==1:
        return sp.I
    if tag=="Var" and len(node)==2 and node[1] in variables:
        return variables[node[1]]
    if tag in ("Add","Mul"):
        cls=sp.Add if tag=="Add" else sp.Mul
        return cls(*(expression_from_ast(a,variables) for a in node[1:]))
    if tag=="Pow" and len(node)==4:
        return expression_from_ast(node[1],variables)**sp.Rational(int(node[2]),int(node[3]))
    raise ValueError("Unknown node or unbound variable in radical AST")


def select_root_rectangle(f: sp.Poly, rectangle: Iterable[Any]) -> int:
    """Translate a rational isolating rectangle to a SymPy root index.

    Order: [xmin,xmax,ymin,ymax]. The rectangle must have exactly one
    root strictly inside and none on its boundary. Root counts are exact;
    bounded-error evaluation only locates the already isolated root.
    """
    from sympy.core.evalf import _evalf_with_bounded_error
    box=list(rectangle)
    if len(box)!=4 or not all(sp.sympify(v).is_Rational for v in box):
        raise ValueError("Four exact rational rectangle endpoints are required")
    l,u,b,t=map(sp.Rational,box)
    if not (l<u and b<t):
        raise ValueError("The rectangle must have positive width and height")
    f=f.set_domain(sp.QQ).sqf_part()
    y=sp.Dummy("y",real=True)
    # Boundary roots are rejected, including real roots on a horizontal edge.
    for expr,lo,hi in [(l+sp.I*y,b,t),(u+sp.I*y,b,t),
                       (y+sp.I*b,l,u),(y+sp.I*t,l,u)]:
        val=sp.expand(f.as_expr().subs(f.gen,expr))
        a,c=val.as_real_imag()
        g=sp.gcd(sp.Poly(a,y,domain=sp.QQ),sp.Poly(c,y,domain=sp.QQ))
        if g.degree()>0 and g.count_roots(lo,hi):
            raise ValueError("A polynomial root lies on the rectangle boundary")
    if f.count_roots(l+sp.I*b,u+sp.I*t)!=1:
        raise ValueError("The rectangle does not isolate exactly one root")
    roots=f.all_roots(radicals=False)
    pending=list(enumerate(roots));bits=16
    while pending:
        eps=sp.Rational(1,2**bits);nxt=[]
        for i,r in pending:
            re,im,_,_=_evalf_with_bounded_error(r,m=bits)
            re,im=_dyadic_value(re),_dyadic_value(im)
            if l<re-eps and re+eps<u and b<im-eps and im+eps<t:
                return i
            if re+eps<l or re-eps>u or im+eps<b or im-eps>t:
                continue
            nxt.append((i,r))
        pending=nxt;bits*=2
    raise RadicalError("Root isolation and bounded-error evaluation disagreed")


def _small_roots(f: sp.Poly, *, require_radicals: bool=True) -> Optional[list[sp.Expr]]:
    if f.degree() > 4:
        return None
    try:
        out = list(sp.roots(f.as_expr(), f.gen, cubics=True, quartics=True))
    except Exception:
        return None
    return out if len(out) == f.sqf_part().degree() and (not require_radicals or all(
        radical_expression_q(v) for v in out)) else None


def _rational_nth_roots(q: sp.Rational, n: int) -> list[sp.Rational]:
    if q == 0:
        return [sp.S.Zero]
    if q < 0 and n % 2 == 0:
        return []
    a, ok1 = sp.integer_nthroot(abs(int(q.p)), n)
    b, ok2 = sp.integer_nthroot(int(q.q), n)
    if not (ok1 and ok2):
        return []
    r = sp.Rational(a if q > 0 else -a, b)
    return [r, -r] if n % 2 == 0 else [r]


def _dickson(n: int, a: sp.Expr, x: sp.Symbol) -> sp.Expr:
    d0, d1 = sp.Integer(2), x
    if n == 0:
        return d0
    for _ in range(2, n + 1):
        d0, d1 = d1, sp.expand(x*d1 - a*d0)
    return d1


def cyclotomic_order(f: sp.Poly) -> Optional[int]:
    """Recover the order of an exactly cyclotomic rational polynomial.

    phi(m)^2 >= m/2 gives the finite search bound m <= 2*degree(f)^2.
    """
    if not all(c.is_Rational for c in f.all_coeffs()):
        return None
    f=f.set_domain(sp.QQ).monic()
    if not f.is_cyclotomic:
        return None
    for m in range(1,2*f.degree()**2+1):
        if sp.totient(m)==f.degree() and sp.Poly(sp.cyclotomic_poly(m,f.gen),f.gen,domain=sp.QQ)==f:
            return m
    raise RadicalError("Cyclotomic order bound failed")


def fast_candidates(f: sp.Poly, *, pair_resolvent: bool = True,
                    _depth: int = 0) -> Optional[tuple[list[sp.Expr], str]]:
    """Finite shortcuts returning roots certified by their construction.

    The base case trusts SymPy's exact degree <= 4 formulas. Higher cases
    check exact polynomial identities, then use power and Dickson identities.
    Thus every returned value is already known to annihilate f, without
    recomputing its sometimes much more expensive minimal polynomial.
    Failure here has no Galois meaning.
    """
    if _depth > 32:
        return None
    x = f.gen
    f = f.monic()
    n = f.degree()
    if n <= 4:
        r = _small_roots(f)
        return (r, "degree-at-most-four") if r is not None else None
    # Roots of unity and their real traces, of arbitrary input degree.
    m=cyclotomic_order(f)
    if m is not None:
        return [zeta(m)**k for k in range(1,m+1) if gcd(k,m)==1],"cyclotomic"
    if all(c.is_Rational for c in f.all_coeffs()):
        lift=sp.Poly(sp.expand(x**n*f.as_expr().subs(x,x+1/x)),x)
        m=cyclotomic_order(lift)
        if m is not None:
            return [zeta(m)**k+zeta(m)**(-k) for k in range(1,(m+1)//2)
                    if gcd(k,m)==1],"real-cyclotomic-trace"
    shift = -f.nth(n-1)/n
    q = sp.Poly(sp.expand(f.as_expr().subs(x, x + shift)), x, extension=True).monic()
    exps = [k for (k,), c in q.terms() if c and k]
    g = reduce(gcd, exps)
    if g > 1:
        h = sp.Poly(sum(c*x**(k//g) for (k,), c in q.terms()), x, extension=True)
        rr = fast_candidates(h, pair_resolvent=False, _depth=_depth+1)
        if rr:
            vals = [shift + zeta(g)**k*sp.Pow(v, sp.Rational(1,g))
                    for v in rr[0] for k in range(g)]
            return vals, "centered-power-composition"
    # D_n(x,a)-b: correlated nth roots, never independent choices of u and v.
    a = -q.nth(n-2)/n
    b = -q.nth(0) + sp.Poly(_dickson(n,a,x),x).nth(0)
    if sp.Poly(q.as_expr() - _dickson(n,a,x) + b, x).is_zero:
        disc = sp.sqrt(b*b - 4*a**n)
        v = (b + disc)/2
        if v == 0:
            v = (b - disc)/2
        if v != 0:
            u = sp.Pow(v, sp.Rational(1,n))
            return [shift + zeta(n)**k*u + a/(zeta(n)**k*u)
                    for k in range(n)], "Dickson"
    # Reciprocal lift: q(x)=x^m h(x+a/x), n=2m, rational a.
    if n % 2 == 0 and q.nth(0).is_Rational:
        m = n//2
        for a in _rational_nth_roots(sp.Rational(q.nth(0)), m):
            rem = q.as_expr()
            hh = 0
            for j in range(m,-1,-1):
                c = sp.Poly(rem,x).nth(m+j)
                hh += c*x**j
                rem = sp.expand(rem - c*x**m*(x+a/x)**j)
            if rem == 0:
                rr = fast_candidates(sp.Poly(hh,x,extension=True),
                                     pair_resolvent=False,_depth=_depth+1)
                if rr:
                    return [shift+(v+sgn*sp.sqrt(v*v-4*a))/2
                            for v in rr[0] for sgn in (1,-1)], "reciprocal-lift"
    # Polynomial decomposition over Q. Every recursive degree decreases.
    if f.domain == sp.QQ or all(c.is_Rational for c in f.all_coeffs()):
        pieces = sp.decompose(f.as_expr(),x)
        if len(pieces)>1:
            composed=pieces[-1]
            for piece in reversed(pieces[:-1]):
                composed=piece.subs(x,composed)
            if not sp.Poly(sp.expand(composed-f.as_expr()),x).is_zero:
                raise RadicalError("Polynomial decomposition identity failed")
            rr=fast_candidates(sp.Poly(pieces[0],x),pair_resolvent=False,_depth=_depth+1)
            if rr:
                values=rr[0]
                for h in pieces[1:]:
                    nxt=[]
                    for v in values:
                        ss=fast_candidates(sp.Poly(h-v,x,extension=True),
                                           pair_resolvent=False,_depth=_depth+1)
                        if ss is None:
                            return None
                        nxt.extend(ss[0])
                    values=nxt
                return values,"polynomial-decomposition"
        if pair_resolvent and n <= 8:
            out = pair_sum_candidates(sp.Poly(f.as_expr(),x,domain=sp.QQ))
            if out:
                return out,"pair-sum-resolvent"
    return None


def pair_sum_resolvent(f: sp.Poly) -> sp.Poly:
    """prod_{i<j}(s-alpha_i-alpha_j), with multiplicities retained."""
    f = f.monic()
    x = f.gen
    s = sp.Dummy("s")
    n = f.degree()
    R = sp.Poly(sp.resultant(f.as_expr(),f.as_expr().subs(x,s-x),x),s)
    diagonal = sp.Poly(2**n*f.as_expr().subs(x,s/2),s)
    quotient = R.exquo(diagonal)
    c, factors = quotient.factor_list()
    if c != 1 or any(e % 2 for _,e in factors):
        raise RadicalError("The pair-resolvent square identity failed")
    out = sp.Poly(1,s)
    for h,e in factors:
        out *= h**(e//2)
    return out.monic()


def pair_sum_candidates(f: sp.Poly) -> list[sp.Expr]:
    x = f.gen
    S = pair_sum_resolvent(f)
    out=[]
    for h,_ in S.factor_list()[1]:
        if h.degree()>4:
            continue
        ss=_small_roots(h)
        if not ss:
            continue
        for a in ss:
            K=sp.QQ if a.is_Rational else sp.QQ.algebraic_field(a)
            g=sp.gcd(f.set_domain(K),sp.Poly(f.as_expr().subs(x,a-x),x,domain=K))
            if 1 <= g.degree() <= 4:
                rr=_small_roots(g)
                if rr:
                    out.extend(rr)
    return out


class FiniteGroup:
    """Exact finite multiplication table, identity deliberately numbered 0."""
    def __init__(self, table: list[list[int]]):
        self.table=table
        self.n=len(table)
        if any(len(r)!=self.n for r in table):
            raise RadicalError("Nonsquare multiplication table")
        if any(table[0][i]!=i or table[i][0]!=i for i in range(self.n)):
            raise RadicalError("Wrong identity")
        self.inv=[next(j for j in range(self.n)
                       if table[i][j]==0 and table[j][i]==0) for i in range(self.n)]

    def closure(self, generators: Iterable[int]) -> frozenset[int]:
        gens=set(generators)
        gens |= {self.inv[g] for g in list(gens)}
        found={0}; todo=[0]
        while todo:
            a=todo.pop()
            for b in gens:
                c=self.table[a][b]
                if c not in found:
                    found.add(c);todo.append(c)
        return frozenset(found)

    def generators(self, H: Iterable[int]) -> list[int]:
        H=set(H);found=frozenset([0]);gens=[]
        for a in sorted(H):
            if a not in found:
                gens.append(a);found=self.closure(gens)
        if found!=H:
            raise RadicalError("Input is not a subgroup")
        return gens

    def derived(self,H: Iterable[int]) -> frozenset[int]:
        H=sorted(H);t=self.table;iv=self.inv
        return self.closure(t[t[t[a][b]][iv[a]]][iv[b]] for a in H for b in H)

    def derived_series(self,H: Optional[Iterable[int]]=None) -> list[frozenset[int]]:
        current=frozenset(range(self.n) if H is None else H);out=[current]
        while len(current)>1:
            nxt=self.derived(current);out.append(nxt)
            if nxt==current:
                break
            current=nxt
        return out

    def prime_chain(self,H: Iterable[int]) -> list[frozenset[int]]:
        H=frozenset(H);out=[H]
        while len(H)>1:
            D=self.derived(H)
            if D==H:
                raise RadicalError("A nonsolvable group was passed to prime_chain")
            J=D
            # H/D is abelian; greedily build a maximal proper subgroup.
            for a in sorted(H):
                if a not in J:
                    trial=self.closure(list(J)+[a])
                    if trial!=H:
                        J=trial
            p=len(H)//len(J)
            if not sp.isprime(p):
                raise RadicalError("Nonprime quotient in a refined solvable series")
            out.append(J);H=J
        return out


def _field_degree(K: Any) -> int:
    return 1 if K==sp.QQ else K.mod.degree()


def _check_degree(K: Any, bound: Optional[int]) -> None:
    if bound is not None and _field_degree(K)>bound:
        raise ResourceLimit(f"Field degree {_field_degree(K)} exceeds {bound}")


def splitting_field(f: sp.Poly, max_degree: Optional[int] = 128) -> Any:
    """Build a concrete splitting field by successive exact factorization.

    Low-degree residual factors are solved first. For a larger residual,
    adjoin an original rational-polynomial CRootOf not yet in the field.
    Each adjunction is inside the splitting field and strictly increases it.
    """
    K=sp.QQ
    all_original=None
    while True:
        fac=f.set_domain(K).factor_list()[1]
        nonsplit=sorted((g for g,e in fac if g.degree()>1),key=lambda g:g.degree())
        if not nonsplit:
            return K
        h=nonsplit[0]
        rr=_small_roots(h,require_radicals=False)
        b=min(rr,key=sp.count_ops) if rr else None
        if b is None:
            if all_original is None:
                all_original=f.all_roots(radicals=False)
            for r in all_original:
                try:
                    K.from_sympy(r)
                except (CoercionFailed,IsomorphismFailed,ValueError):
                    b=r;break
            if b is None:
                raise RadicalError("A nonsplit factor has no missing original root")
        old=_field_degree(K)
        K=sp.QQ.algebraic_field(b) if K==sp.QQ else sp.QQ.algebraic_field(K.ext,b)
        _check_degree(K,max_degree)
        if _field_degree(K)<=old:
            raise RadicalError("A splitting-field adjunction made no progress")


class FieldModel:
    """Rational power coordinates and all automorphisms of a normal field."""
    def __init__(self,K: Any,images: Optional[list[Any]]=None):
        if K==sp.QQ:
            raise RadicalError("Use the rational special case")
        self.K=K;self.d=K.mod.degree()
        self.theta=K.unit
        self.powers=[K.one]
        for _ in range(1,self.d):
            self.powers.append(self.powers[-1]*self.theta)
        t=sp.Dummy("t")
        self.modulus=sp.Poly.from_list(K.mod.to_list(),t,domain=sp.QQ)
        if images is None:
            fac=self.modulus.set_domain(K).factor_list()[1]
            if len(fac)!=self.d or any(p.degree()!=1 or e!=1 for p,e in fac):
                raise RadicalError("The field is not a splitting field (not normal)")
            images=[]
            for p,e in fac:
                c=p.rep.to_list();images.append(-c[1]/c[0])
        else:
            images=list(images)
        if len(set(images))!=len(images):
            raise RadicalError("Duplicate automorphism images")
        images.remove(self.theta);self.images=[self.theta]+images
        look={a:i for i,a in enumerate(self.images)}
        table=[[look[self.apply_image(a,b)] for b in self.images] for a in self.images]
        self.group=FiniteGroup(table)
        self._matrices={}

    def vector(self,a: Any) -> sp.Matrix:
        c=list(reversed(a.to_list()))
        return sp.Matrix([sp.QQ.to_sympy(v) for v in c]+[0]*(self.d-len(c)))

    def element(self,v: Iterable[sp.Rational]) -> Any:
        out=self.K.zero
        for c,b in zip(v,self.powers):
            out+=self.K.convert(c)*b
        return out

    def apply_image(self,image: Any,a: Any) -> Any:
        out=self.K.zero
        for c in a.to_list():
            out=out*image+self.K.convert(c)
        return out

    def apply(self,i: int,a: Any) -> Any:
        return self.apply_image(self.images[i],a)

    def automorphism_matrix(self,i: int) -> sp.Matrix:
        if i not in self._matrices:
            self._matrices[i]=sp.Matrix.hstack(*[self.vector(self.apply(i,b)) for b in self.powers])
        return self._matrices[i]

    def multiplication_matrix(self,a: Any) -> sp.Matrix:
        return sp.Matrix.hstack(*[self.vector(a*b) for b in self.powers])

    def minpoly(self,a: Any) -> sp.Poly:
        # charpoly(M_a) is a positive power of the minimal polynomial.
        t=sp.Dummy("t")
        cp=self.multiplication_matrix(a).charpoly(t)
        return sp.Poly(cp.as_expr(),cp.gen,domain=sp.QQ).sqf_part().monic()

    def coordinates(self,basis: list[Any],a: Any) -> list[sp.Rational]:
        B=sp.Matrix.hstack(*[self.vector(b) for b in basis])
        sol,params=B.gauss_jordan_solve(self.vector(a))
        if params.rows:
            raise RadicalError("Dependent tower basis")
        if B*sol!=self.vector(a):
            raise RadicalError("Tower-coordinate certificate failed")
        return list(sol)

    def branch(self,r: Any,p: int,m: int,z: Any) -> int:
        a=r**p
        mp=self.minpoly(a)
        t=mp.gen
        test=sp.Poly(mp.as_expr().subs(t,t**p),t).sqf_part().monic()
        re=self.K.to_sympy(r);ae=self.K.to_sympy(a)
        base=sp.Pow(ae,sp.Rational(1,p))
        # Every candidate is known algebraically to annihilate test.
        for k in range(p):
            candidate=zeta(p)**k*base
            if same_algebraic_root(test,re,candidate,both_known_roots=True):
                return k
        raise RadicalError("No principal-power branch matched the embedded generator")


@dataclass
class RadicalResult:
    status: str
    method: str
    target: Optional[sp.Expr] = None
    expression: Optional[sp.Expr] = None
    assignments: list[tuple[sp.Symbol,sp.Expr]] = field(default_factory=list)
    final: Optional[sp.Expr] = None
    data: dict[str,Any] = field(default_factory=dict)

    def expanded(self) -> sp.Expr:
        if self.status!="Success":
            raise RadicalError(self.data.get("message",self.status))
        if self.expression is not None:
            return self.expression
        env={}
        for name,expr in self.assignments:
            env[name]=expr.xreplace(env)
        out=sp.sympify(self.final).xreplace(env)
        if not radical_expression_q(out):
            raise RadicalError("The output contains something other than radicals")
        return out

    def to_wolfram(self, *, held: bool=False) -> str:
        from sympy.printing.mathematica import mathematica_code
        if self.status!="Success":
            raise RadicalError(self.status)
        if self.expression is not None:
            code=mathematica_code(self.expression)
        else:
            code=mathematica_code(self.final)
            for name,expr in reversed(self.assignments):
                code="With[{"+str(name)+"="+mathematica_code(expr)+"},"+code+"]"
        return "HoldComplete["+code+"]" if held else code

    def summary(self) -> dict[str,Any]:
        out={"status":self.status,"method":self.method,**self.data}
        if self.status=="Success":
            out["wolfram"]=self.to_wolfram(held=True)
            out["radical_dag"]={"assignments":[[str(a),radical_ast(b)] for a,b in self.assignments],
                                "result":radical_ast(self.expression if self.expression is not None else self.final)}
            out["assignments"]=[(str(a),str(b)) for a,b in self.assignments]
            out["final"]=str(self.expression if self.expression is not None else self.final)
        return out


def _dot(coeff: Iterable[Any],expressions: Iterable[sp.Expr]) -> sp.Expr:
    return sp.Add(*(c*e for c,e in zip(coeff,expressions) if c))


def cyclotomic_compositum(first: FieldModel,m: int,max_degree: Optional[int]) -> tuple[FieldModel,Any]:
    """Construct Aut(E(zeta_m)/Q(zeta_m)) without refactoring a larger modulus.

    For each automorphism of E, test its unique possible extension fixing
    zeta_m. A primitive generator is a rational linear combination of the
    two original generators. Checking its modulus and both generator images
    is an exact extension certificate. The expected order proves completeness.
    """
    E=first.K;ze=zeta(m);t=sp.Dummy("t")
    mp,cs=sp.polys.numberfields.primitive_element([E.ext,ze],t,polys=True)
    theta=sp.Add(*(c*a for c,a in zip(cs,[E.ext,ze])))
    L=sp.QQ.algebraic_field((mp,theta))
    _check_degree(L,max_degree)
    z=L.from_sympy(ze)
    c0,c1=map(L.convert,cs)
    e=(L.unit-c1*z)/c0 if c0 else L.from_sympy(E.ext.as_expr())
    def eval_coeff(coefficients: Iterable[Any],at: Any) -> Any:
        out=L.zero
        for a in coefficients:
            out=out*at+L.convert(a)
        return out
    images=[]
    for old_image in first.images:
        e_image=eval_coeff(old_image.to_list(),e)
        candidate=c0*e_image+c1*z
        if eval_coeff(L.mod.to_list(),candidate):
            continue
        if eval_coeff(e.to_list(),candidate)!=e_image:
            continue
        if eval_coeff(z.to_list(),candidate)!=z:
            continue
        if candidate not in images:
            images.append(candidate)
    expected=L.mod.degree()//int(sp.totient(m))
    if len(images)!=expected:
        raise RadicalError("Relative automorphism count did not match the degree")
    model=FieldModel(L,images)
    model.original_generator=e
    model.original_degree=first.d
    return model,z


def galois_radicalize(f: sp.Poly, target: sp.Expr,
                     max_degree: Optional[int]=128) -> RadicalResult:
    """Complete classical construction, subject to the explicit resource cap."""
    E=splitting_field(f,max_degree)
    if E==sp.QQ:
        return RadicalResult("Success","rational",target,target,data={"verified":True})
    first=FieldModel(E)
    ds=first.group.derived_series()
    if len(ds[-1])!=1:
        return RadicalResult("NotSolvableByRadicals","Galois",target,data={
            "group_order":first.d,"derived_orders":[len(h) for h in ds],
            "message":"The selected irreducible polynomial has a nonsolvable Galois group."})
    m=int(sp.prod(sp.factorint(first.d)))
    zexpr=zeta(m)
    model,z=cyclotomic_compositum(first,m,max_degree)
    L=model.K;G=model.group
    root=L.from_sympy(target)
    # Verify the target conversion has the same complex embedding.
    if not same_algebraic_root(f,L.to_sympy(root),target,both_known_roots=True):
        raise RadicalError("The target embedding was not preserved")
    H=frozenset(range(G.n))
    if any(model.apply(i,z)!=z for i in H):
        raise RadicalError("The relative group does not fix the cyclotomic base")
    chain=G.prime_chain(H)
    zsym=sp.Symbol("rrz")
    assignments=[(zsym,zexpr)]
    basis=[z**j for j in range(int(sp.totient(m)))]
    expressions=[zsym**j for j in range(len(basis))]
    if model.d//len(H)!=len(basis):
        raise RadicalError("Cyclotomic base degree mismatch")
    steps=[]
    for i,(prev,nxt) in enumerate(zip(chain,chain[1:]),1):
        # Stop as soon as the selected root is already in the current field.
        if all(model.apply(g,root)==root for g in prev):
            break
        p=len(prev)//len(nxt)
        tau=min(prev-nxt)
        eig=model.automorphism_matrix(tau)-model.multiplication_matrix(z**(m//p))
        constraints=[eig]
        constraints += [model.automorphism_matrix(g)-sp.eye(model.d)
                        for g in G.generators(nxt)]
        null=sp.Matrix.vstack(*constraints).nullspace()
        if not null:
            raise RadicalError("The nonzero Kummer eigenspace is missing")
        # Nullspace vectors certify existence. Two finite trace/projector
        # candidates often give far smaller radicands than an arbitrary
        # power-basis null vector (notably for cyclic quintics).
        candidates=[model.element(v) for v in null]
        zp=z**(m//p)
        for j in range(1,min(model.original_degree,3)):
            b=model.original_generator**j
            tr=sum((model.apply(g,b) for g in nxt),L.zero)
            projected=L.zero;phase=L.one
            for _ in range(p):
                projected+=phase*tr
                tr=model.apply(tau,tr);phase/=zp
            if projected and projected not in candidates:
                candidates.append(projected)
        choices=[]
        for candidate in candidates:
            power=candidate**p
            cc=model.coordinates(basis,power)
            score=sum(abs(int(c.p)).bit_length()+int(c.q).bit_length() for c in cc)
            choices.append((score,candidate,power,cc))
        _,r,a,ac=min(choices,key=lambda v:v[0])
        if (not r or any(model.apply(g,r)!=r for g in nxt) or
                model.apply(tau,r)!=zp*r or any(model.apply(g,a)!=a for g in prev)):
            raise RadicalError("Kummer fixed-field certificate failed")
        radicand=_dot(ac,expressions)
        k=model.branch(r,p,m,z)
        name=sp.Symbol(f"rru{i}")
        assignments.append((name,zsym**((m//p)*k)*sp.Pow(radicand,sp.Rational(1,p))))
        steps.append({"prime":p,"phase":k,"previous_order":len(prev),
                      "next_order":len(nxt),"radicand_coordinates":[str(c) for c in ac],
                      "radicand_ast":radical_ast(radicand),
                      "generator_coordinates":[str(c) for c in model.vector(r)]})
        basis=[b*r**j for j in range(p) for b in basis]
        expressions=[b*name**j for j in range(p) for b in expressions]
        if len(basis)!=model.d//len(nxt):
            raise RadicalError("Tower degree invariant failed")
    coords=model.coordinates(basis,root)
    final=_dot(coords,expressions)
    return RadicalResult("Success","Galois-Kummer",target,
                         assignments=assignments,final=final,data={
        "verified":True,"group_order":first.d,"augmented_field_degree":model.d,
        "cyclotomic_order":m,"relative_group_order":G.n,"derived_orders":[len(h) for h in ds],
        "chain_orders":[len(h) for h in chain],"steps":steps,
        "target_coordinates":[str(c) for c in model.vector(root)],
        "field_modulus_coefficients":[str(c) for c in model.modulus.all_coeffs()],
        "primitive_element":str(L.ext.as_expr()),
        "trace_kind":"arithmetic tower certificate plus Galois audit trace; not a formal proof object",
        "trust":"SymPy exact number fields, rational linear algebra, and separation-bound root matching"})


def verify_tower_result(result: RadicalResult,f: sp.Poly) -> bool:
    """Independently check an emitted tower by rational polynomial reduction.

    This checker does not construct a number field or use the discovered
    automorphisms. It verifies the emitted assignments, reduces f(final)
    modulo the triangular tower relations, and checks the selected embedding
    using the root-separation bound. It can be more expensive than conversion.
    """
    if result.status!="Success" or result.method!="Galois-Kummer":
        raise ValueError("An emitted Galois-Kummer result is required")
    m=result.data["cyclotomic_order"]
    names={str(a):a for a,b in result.assignments}
    zsym=result.assignments[0][0]
    if result.assignments[0][1]!=zeta(m):
        return False
    steps=result.data["steps"]
    if len(steps)!=len(result.assignments)-1:
        return False
    relations=[];seen={str(zsym):zsym}
    for (name,rhs),step in zip(result.assignments[1:],steps):
        p=step["prime"];k=step["phase"]
        if not sp.isprime(p) or m%p or not 0<=k<p:
            return False
        a=expression_from_ast(step["radicand_ast"],seen)
        if rhs!=zsym**((m//p)*k)*sp.Pow(a,sp.Rational(1,p)):
            return False
        relations.append((name,name**p-a));seen[str(name)]=name
    if not sp.sympify(result.final).free_symbols<=set(seen.values()):
        return False
    phi=sp.cyclotomic_poly(m,zsym)
    def reduce_tower(e: sp.Expr) -> sp.Expr:
        for variable,relation in reversed(relations):
            e=sp.rem(sp.expand(e),relation,variable)
        return sp.rem(sp.expand(e),phi,zsym)
    value=sp.S.Zero
    for c in f.all_coeffs():
        value=reduce_tower(value*result.final+c)
    if value!=0:
        return False
    # The preceding exact identities establish the comparison precondition.
    return same_algebraic_root(f,result.expanded(),result.target,both_known_roots=True)


def radicalize(polynomial: Any, index: int=0, *, variable: sp.Symbol=X,
               method: str="auto", max_degree: Optional[int]=128,
               pair_resolvent: bool=True) -> RadicalResult:
    """Convert one selected root. Infinity is represented by max_degree=None.

    Only exact rational-coefficient univariate polynomials are accepted.
    Repeated roots are removed before ZERO-based SymPy root indexing.
    The selected irreducible factor, not the whole reducible polynomial,
    determines solvability. Errors and resource limits are distinct statuses.
    """
    started=time.monotonic()
    if max_degree is not None and (not isinstance(max_degree,int) or isinstance(max_degree,bool) or max_degree<1):
        raise ValueError("max_degree must be a positive integer or None")
    if method not in ("auto","galois","fast"):
        raise ValueError("method must be auto, galois, or fast")
    if not isinstance(index,int) or isinstance(index,bool):
        raise ValueError("index must be an integer")
    if isinstance(polynomial,sp.Poly):
        if len(polynomial.gens)!=1:
            raise ValueError("Expected a univariate polynomial")
        variable=polynomial.gen
    raw=sp.Poly(polynomial,variable)
    if raw.as_expr().has(sp.Float) or not all(c.is_Rational for c in raw.all_coeffs()):
        raise ValueError("Only exact rational coefficients are supported")
    f=sp.Poly(raw.as_expr(),variable,domain=sp.QQ)
    if f.degree()<1:
        raise ValueError("Expected a nonconstant polynomial")
    f=f.sqf_part().monic()
    if not 0<=index<f.degree():
        raise ValueError("index is outside the distinct-root range")
    try:
        target=f.all_roots(radicals=False)[index]
        mp=sp.Poly(sp.minpoly(target,variable),variable,domain=sp.QQ).monic()
    except Exception as e:
        return RadicalResult("BackendFailure",method,data={
            "message":f"Root preprocessing: {type(e).__name__}: {e}",
            "seconds":round(time.monotonic()-started,6)})
    try:
        if mp.degree()==1:
            result=RadicalResult("Success","rational",target,-mp.nth(0),data={"verified":True})
        else:
            result=None
            if method!="galois":
                try:
                    rr=fast_candidates(mp,pair_resolvent=pair_resolvent)
                except Exception:
                    # A shortcut failure is not a failure of the general method.
                    rr=None
                if rr:
                    # Approximation schedules work only; it never certifies it.
                    cand=sorted(rr[0],key=lambda a:abs(complex(sp.N(a-target,25))))
                    for a in cand:
                        if radical_expression_q(a) and same_algebraic_root(mp,a,target,both_known_roots=True):
                            result=RadicalResult("Success",rr[1],target,a,data={"verified":True,
                                "verification":"exact structural identities, trusted low-degree formulas, and root separation"})
                            break
            if result is None and method=="fast":
                result=RadicalResult("NotFound","fast",target,data={
                    "message":"Finite shortcuts found no certified expression; solvability is unknown."})
            if result is None:
                # This is an optimization only. The general backend has no
                # degree-six restriction and computes all automorphisms itself.
                if mp.degree()<=6:
                    try:
                        gg,_=sp.polys.numberfields.galois_group(mp)
                    except Exception:
                        # An optional accelerator must never block fallback.
                        gg=None
                    if gg is not None and not gg.is_solvable:
                        result=RadicalResult("NotSolvableByRadicals","Galois-decision",target,data={
                            "group_order":int(gg.order()),
                            "message":"The selected irreducible factor has a nonsolvable Galois group."})
                if result is None:
                    result=galois_radicalize(mp,target,max_degree)
    except ResourceLimit as e:
        result=RadicalResult("ResourceLimit",method,target,data={"message":str(e)})
    except Exception as e:
        result=RadicalResult("BackendFailure",method,target,data={
            "message":f"{type(e).__name__}: {e}"})
    result.data["seconds"]=round(time.monotonic()-started,6)
    result.data["minimal_polynomial"]=str(mp.as_expr())
    return result


def _worker(coefficients: list[str],index: int,method: str,bound: Optional[int],
            rectangle: Optional[list[str]],conn: Any) -> None:
    try:
        coeff=[sp.Rational(c) for c in coefficients]
        p=sp.Poly.from_list(coeff,X,domain=sp.QQ)
        if rectangle is not None:
            index=select_root_rectangle(p,[sp.Rational(c) for c in rectangle])
        conn.send(radicalize(p,index,method=method,max_degree=bound).summary())
    except Exception as e:
        conn.send({"status":"InvalidInput","message":str(e)})
    finally:
        conn.close()


def main() -> int:
    """Coefficients, not eval/sympify of an untrusted code string, are accepted."""
    import multiprocessing as mp
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--coefficients",required=True,
                        help='JSON array of rational coefficient strings, highest degree first')
    parser.add_argument("--index",type=int,default=0)
    parser.add_argument("--rectangle",help="JSON [xmin,xmax,ymin,ymax] of rational strings; overrides index")
    parser.add_argument("--method",choices=("auto","fast","galois"),default="auto")
    parser.add_argument("--max-degree",type=int,default=128,help="0 means no degree cap")
    parser.add_argument("--timeout",type=float,default=300,help="seconds; 0 disables the watchdog")
    args=parser.parse_args()
    coeff=json.loads(args.coefficients)
    if not isinstance(coeff,list) or not all(isinstance(a,(str,int)) and not isinstance(a,bool) for a in coeff):
        parser.error("Coefficients must be a JSON list of integers or rational strings")
    # Rational() is restricted to a small rational-literal grammar here.
    import re
    if not all(re.fullmatch(r"[+-]?\d+(?:/[1-9]\d*)?",str(c)) for c in coeff):
        parser.error("A coefficient is not a rational literal")
    rectangle=json.loads(args.rectangle) if args.rectangle is not None else None
    if rectangle is not None and (not isinstance(rectangle,list) or len(rectangle)!=4 or
        not all(isinstance(c,(str,int)) and not isinstance(c,bool) and
                re.fullmatch(r"[+-]?\d+(?:/[1-9]\d*)?",str(c)) for c in rectangle)):
        parser.error("Rectangle endpoints must be four rational literals")
    if args.max_degree<0 or args.timeout<0:
        parser.error("Resource limits must be nonnegative")
    ctx=mp.get_context("spawn")
    parent,child=ctx.Pipe(duplex=False)
    process=ctx.Process(target=_worker,args=([str(c) for c in coeff],args.index,args.method,
                        args.max_degree or None,rectangle,child))
    process.start();child.close()
    # Read while the worker is alive, so a large certificate cannot fill a
    # pipe and deadlock process.join().
    if parent.poll(args.timeout if args.timeout else None):
        try:
            result=parent.recv()
        except EOFError:
            result={"status":"BackendFailure","message":"Worker exited without a result"}
        process.join(2)
    else:
        process.terminate();process.join()
        result={"status":"ResourceLimit","message":"External wall-clock watchdog expired"}
    if process.is_alive():
        process.terminate();process.join()
    print(json.dumps(result,indent=2))
    return 0 if result["status"]=="Success" else 2

if __name__=="__main__":
    raise SystemExit(main())
