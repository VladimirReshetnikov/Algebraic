"""Certified algebraic shortcuts in front of the general Kummer constructor."""
from __future__ import annotations
from dataclasses import dataclass
import sympy as S
from .core import (X,Z,rational_poly,zeta,same_root_known,build_tower,Limits,
                   RadicalError,VerificationError,expression_ast)

@dataclass
class RadicalSolution:
    polynomial:S.Poly
    expressions:list
    metadata:dict
    tower:object=None

    def expression(self,index=0):return self.expressions[index]


def order_known_roots(f,candidates):
    """Order already-proved roots; do not use this to test arbitrary guesses."""
    targets=f.all_roots(radicals=True)
    result=[]
    for r in targets:
        # Ranking is only an optimization; acceptance is separation-certified.
        ranked=sorted(candidates,key=lambda e:abs(complex(S.N(e,25))-complex(S.N(r,25))))
        found=next((e for e in ranked if same_root_known(f,e,r)),None)
        if found is None:raise VerificationError('Known-root candidates are incomplete')
        result.append(found)
    return result


def dickson(n,x,a):
    d0,d1=S.Integer(2),x
    if n==0:return d0
    for _ in range(2,n+1):d0,d1=d1,S.expand(x*d1-a*d0)
    return d1


def dickson_candidates(f):
    """Recognize D_n(x+h,a)+c exactly; solve using paired nth roots."""
    f=f.monic();n=f.degree()
    if n<2:return None
    h=f.nth(n-1)/n
    q=S.Poly(f.as_expr().subs(X,X-h).expand(),X,domain=S.QQ)
    a=-q.nth(n-2)/n
    c=q.nth(0)-S.Poly(dickson(n,X,a),X).nth(0)
    if S.Poly(dickson(n,X,a)+c,X,domain=S.QQ)!=q:return None
    disc=c*c-4*a**n
    t=(-c+S.sqrt(disc))/2
    if t==0:t=(-c-S.sqrt(disc))/2
    if t==0:return None # x^n: handled by rational factorization
    u=S.Pow(t,S.Rational(1,n))
    ans=[zeta(n)**k*u+a/(zeta(n)**k*u)-h for k in range(n)]
    # Exact structural witness: recognition above, and t^2+c*t+a^n=0.
    if S.simplify(t*t+c*t+a**n)!=0:
        raise VerificationError('Dickson auxiliary quadratic identity failed')
    return ans,{'method':'Dickson','degree':n,'a':str(a),'c':str(c),'shift':str(h),
                'identity':'D_n(u+a/u,a)=u^n+(a/u)^n'}


def pair_sum_resolvent(f):
    """Product over unordered pairs, with multiplicities retained."""
    f=f.monic();n=f.degree();Y=S.Symbol('y')
    resultant=S.resultant(f.as_expr(),f.as_expr().subs(X,Y-X),X)
    diagonal=S.expand(2**n*f.as_expr().subs(X,Y/2))
    quotient,remainder=S.div(resultant,diagonal,Y)
    if remainder!=0:raise VerificationError('Pair-sum diagonal division failed')
    unit,factors=S.factor_list(quotient,Y)
    # The result is monic; every multiplicity of the square is even.
    if unit!=1 or any(e%2 for _,e in factors):
        raise VerificationError('Pair-sum resultant is not an exact monic square')
    return S.Poly(S.prod(q**(e//2) for q,e in factors).subs(Y,X),X,domain=S.QQ)


def low_degree_candidates(f):
    if f.degree()>4:return None
    r=S.roots(f.as_expr(),X,cubics=True,quartics=True)
    if sum(r.values())!=f.degree():return None
    # Formulas returned by the exact polynomial solver, not numerical fitting.
    return list(r)


def pair_sum_candidates(f,limits,max_extension_degree=6):
    limits.check('pair-sum resolvent')
    R=pair_sum_resolvent(f)
    candidates=[];used=[]
    for q,_ in R.factor_list()[1]:
        if q.degree()>max_extension_degree:continue
        qrad=low_degree_candidates(q)
        if qrad is None:
            recognized=dickson_candidates(q)
            qrad=recognized[0] if recognized else None
        if qrad is None:continue
        for b in q.all_roots(radicals=False):
            limits.check('factor over a pair-sum field',q.degree())
            br=next(e for e in qrad if same_root_known(q,e,b))
            K=S.QQ.algebraic_field(b)
            factors=S.Poly(f.as_expr(),X,domain=K).factor_list()[1]
            for fac,_ in factors:
                # Quadratics are the intended pair trace. Do not inflate the
                # expression by applying generic quartic formulas to a complement.
                if fac.degree()>2:continue
                coeff=fac.rep.to_list()
                def coeff_expr(a):
                    # Express in the selected primitive b, then substitute its
                    # already branch-certified radical expression.
                    return sum(S.Rational(c)*br**j for j,c in enumerate(a.to_list()[::-1]))
                cs=[coeff_expr(a) for a in coeff]
                if fac.degree()==1:
                    candidates.append(-cs[1]/cs[0])
                else:
                    A,B,C=cs
                    delta=B*B-4*A*C
                    candidates.extend([(-B+S.sqrt(delta))/(2*A),(-B-S.sqrt(delta))/(2*A)])
                used.append(str(q.as_expr()))
        if len(candidates)>=f.degree():
            try:
                return order_known_roots(f,candidates),{
                    'method':'PairSum','resolvent':str(R.as_expr()),
                    'extension_polynomials':sorted(set(used)),
                    'identity':'Exact factorization over each selected pair-sum field'}
            except VerificationError:
                pass
    return None


def solve_polynomial(poly,variable=None,*,method='auto',limits=None,
                     pair_sum_max_degree=10,max_extension_degree=6):
    """All DISTINCT roots, real first in SymPy's own canonical ordering.

    method='galois' forces the general construction, apart from exact field
    construction optimizations. method='fast' never calls the general engine.
    Input may be reducible; nonsolvability of one factor does not describe
    unrelated factors. solve_root is preferable when only one root is needed.
    """
    if method not in ('auto','fast','galois'):raise ValueError('Unknown method')
    limits=limits or Limits()
    f=rational_poly(poly,variable).sqf_part().monic()
    factors=f.factor_list()[1]
    if len(factors)>1:
        ans=[];methods=[]
        for q,_ in factors:
            s=solve_polynomial(q,method=method,limits=limits,
                               pair_sum_max_degree=pair_sum_max_degree,
                               max_extension_degree=max_extension_degree)
            ans.extend(s.expressions);methods.append(s.metadata)
        return RadicalSolution(f,order_known_roots(f,ans),{'method':'rational factorization','factors':methods})
    if f.degree()==1:return RadicalSolution(f,[-f.nth(0)],{'method':'linear'})
    if method!='galois':
        low=low_degree_candidates(f)
        if low is not None:return RadicalSolution(f,order_known_roots(f,low),{'method':'degree-at-most-four'})
        ds=dickson_candidates(f)
        if ds:
            return RadicalSolution(f,order_known_roots(f,ds[0]),ds[1])
        if f.degree()<=pair_sum_max_degree:
            ps=pair_sum_candidates(f,limits,max_extension_degree)
            if ps:return RadicalSolution(f,ps[0],ps[1])
        if method=='fast':raise RadicalError('Fast paths exhausted; solvability is undetermined')
    t=build_tower(f,limits=limits)
    return RadicalSolution(f,t.expressions(),t.metadata,t)


def solve_root(poly,index=0,variable=None,**options):
    """Select a root's irreducible factor before testing solvability.

    The index is zero-based in SymPy CRootOf order and counts multiplicities,
    unlike solve_polynomial, which returns distinct roots.
    """
    f=rational_poly(poly,variable)
    if not isinstance(index,int) or not 0<=index<f.degree():raise ValueError('Root index out of range')
    target=S.CRootOf(f,index)
    if target.is_Rational:return RadicalSolution(S.Poly(X-target,X),[target],{'method':'rational target'})
    q=rational_poly(target.poly)
    result=solve_polynomial(q,**options)
    chosen=next(e for e in result.expressions if same_root_known(q,e,target))
    return RadicalSolution(q,[chosen],{**result.metadata,'selected_input_index':index},result.tower)
