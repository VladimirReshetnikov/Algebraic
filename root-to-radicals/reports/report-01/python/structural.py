"""Compact radical constructions, with exact minimal-polynomial certification.

The final conjugate test is SymPy Poly.same_root: a root-separation bound and
bounded-error algebraic evaluation, NOT an arbitrary decimal tolerance.
The general Galois backend has its separate rational-rectangle verifier.
"""
from __future__ import annotations
import time,math
import sympy as s
import radical_ast as A


def dickson(n,x,c):
    if n==0:return s.S(2)
    p,q=s.S(2),x
    for _ in range(2,n+1):p,q=q,s.expand(x*q-c*p)
    return q


def rational_nth_roots(a,n):
    a=s.Rational(a)
    if a<0 and n%2==0:return []
    u,ok=s.integer_nthroot(abs(int(a.p)),n)
    v,ok2=s.integer_nthroot(int(a.q),n)
    if not(ok and ok2):return []
    c=s.Rational(u,v)*(-1 if a<0 else 1)
    return [c,-c] if n%2==0 and c else [c]


def reciprocal_reduction(f):
    """Find f(x)=x^m h(x+c/x), c in Q*, by coefficient comparison."""
    f=s.Poly(f,domain=s.QQ).monic();x=f.gen;n=f.degree()
    if n%2 or n<4 or not f.TC():return None
    m=n//2;y=s.Dummy('y')
    for c in rational_nth_roots(f.TC(),m):
        rem=f.as_expr();h=s.S.Zero
        for j in range(m,-1,-1):
            coeff=s.Poly(rem,x).nth(m+j)
            term=s.expand(x**m*(x+c/x)**j)
            rem=s.expand(rem-coeff*term);h+=coeff*y**j
        if rem==0:return s.Poly(h,y,domain=s.QQ),c
    return None


def compact_candidates(f,depth=0):
    """Return (expressions, a construction trace), or None (not a negative result)."""
    f=s.Poly(f,domain=s.QQ).monic();x=f.gen;n=f.degree()
    if n==1:return [-f.TC()],{'kind':'Linear'}
    if f.is_cyclotomic:
        # phi(N)^2 >= N/2 follows by multiplying the prime-power factors.
        for N in range(2,2*n*n+1):
            if s.totient(N)==n and s.Poly(s.cyclotomic_poly(N,x),x,domain=s.QQ)==f:
                return [s.Pow(-1,s.Rational(2*k,N)) for k in range(1,N) if math.gcd(k,N)==1],{'kind':'Cyclotomic','order':N}
        raise ArithmeticError('Cyclotomic order bound was inconsistent')
    # A rational translation exposes shifted binomials and Dickson polynomials.
    shift=f.nth(n-1)/n;y=s.Dummy('y')
    g=s.Poly(f.as_expr().subs(x,y-shift),y,domain=s.QQ)
    if g.as_expr()==y**n+g.TC():
        u=s.Pow(-g.TC(),s.Rational(1,n));z=s.Pow(-1,s.Rational(2,n))
        return [z**k*u-shift for k in range(n)],{'kind':'ShiftedBinomial','shift':str(shift)}
    if n>=3:
        c=-g.nth(n-2)/n;b=g.TC()
        # D_n may itself have a constant term when n is even.
        dn=s.Poly(dickson(n,y,c),y);b=g.TC()-dn.TC()
        if c and g.as_expr()==dn.as_expr()+b:
            U=(-b+s.sqrt(b*b-4*c**n))/2
            if U==0:U=(-b-s.sqrt(b*b-4*c**n))/2
            if U!=0 and b*b!=4*c**n:
                u=s.Pow(U,s.Rational(1,n));z=s.Pow(-1,s.Rational(2,n))
                return [z**k*u+c/(z**k*u)-shift for k in range(n)],{
                    'kind':'ShiftedDickson','order':n,'c':str(c),'b':str(b),'shift':str(shift)}
    exponents=[k[0] for k,c0 in g.terms() if k[0]>0]
    power=math.gcd(*exponents)
    if power>1:
        t=s.Dummy('t');h=s.Poly(sum(c0*t**(k[0]//power) for k,c0 in g.terms()),t,domain=s.QQ)
        lower=compact_candidates(h,depth+1)
        if lower is not None:
            ys,trace=lower;z=s.Pow(-1,s.Rational(2,power))
            return [z**k*s.Pow(a,s.Rational(1,power))-shift for a in ys for k in range(power)],{
                'kind':'MonomialSubstitution','power':power,'shift':str(shift),
                'reduced_polynomial':[str(a) for a in h.all_coeffs()],'child':trace}
    reduction=reciprocal_reduction(g)
    if reduction is not None:
        h,c=reduction;lower=compact_candidates(h,depth+1)
        if lower is not None:
            ys,trace=lower
            return [(a+sign*s.sqrt(a*a-4*c))/2-shift for a in ys for sign in [-1,1]],{
                'kind':'ReciprocalQuadratic','c':str(c),'shift':str(shift),
                'reduced_polynomial':[str(a) for a in h.all_coeffs()],'child':trace}
    if n<=4:
        roots=s.roots(f.as_expr(),x,cubics=True,quartics=True,quintics=False)
        out=[a for a,m in roots.items() for _ in range(m)]
        if len(out)==n:
            try:
                for a in out:A.from_sympy(a)
            except ValueError:return None
            return out,{'kind':'LowDegreeFormula','degree':n}
    return None


def certify_candidates(f,candidates,trace=None):
    """Prove membership in the root set, then select the exact conjugate.

    MinimalPolynomial is computed for EACH expression, independently of the
    construction. This also verifies all principal-power choices.
    """
    start=time.monotonic();f=s.Poly(f,domain=s.QQ).monic();x=f.gen
    targets=f.all_roots(radicals=False);out=[];seen=set()
    for expr in candidates:
        ast=A.from_sympy(expr)
        # Certify the actual transported AST, not only the source expression.
        expr=A.sympy_expr(ast)
        mp=s.Poly(s.minpoly(expr,x),x,domain=s.QQ).sqf_part().monic()
        # Some SymPy radical inputs yield a reducible annihilator. Retain it
        # for the separation test; never assume the returned polynomial is minimal.
        if not mp.rem(f).is_zero:raise ArithmeticError('Annihilator does not contain the target minimal polynomial')
        if f.degree()==1:idx=0
        else:
            hits=[i for i,r in enumerate(targets) if mp.same_root(expr,r)]
            if len(hits)!=1:raise ArithmeticError('Conjugate not uniquely certified')
            idx=hits[0]
        if idx in seen:raise ArithmeticError('Duplicate structural root')
        seen.add(idx)
        out.append({'index':idx,'expression':ast,
                    'minimal_polynomial':[str(a) for a in f.all_coeffs()],
                    'computed_annihilator':[str(a) for a in mp.all_coeffs()]})
    if len(out)!=f.degree():raise ArithmeticError('Incomplete structural construction')
    out.sort(key=lambda r:r['index'])
    return {'status':'Success','method':'Structural','version':'1.0.0',
            'polynomial':[str(c) for c in f.all_coeffs()], 'definitions':[], 'roots':out,
            'certificate':{'type':'AnnihilatorAndSeparation','construction':trace},
            'statistics':{'input_degree':f.degree(),'elapsed_seconds':time.monotonic()-start}}


def try_structural(f):
    found=compact_candidates(f)
    return None if found is None else certify_candidates(f,*found)


def verify_structural(result):
    if result.get('status')!='Success' or result.get('method')!='Structural':
        raise ValueError('Expected a structural success certificate')
    x=s.Dummy('x');f=s.Poly.from_list([s.Rational(c) for c in result['polynomial']],x,domain=s.QQ)
    if result.get('definitions')!=[]:raise ValueError('Unexpected structural definitions')
    if sorted(r['index'] for r in result['roots'])!=list(range(f.degree())):
        raise ValueError('Missing or duplicate indices')
    if not f.is_irreducible:raise ValueError('Target must be a minimal polynomial')
    roots=f.all_roots(radicals=False)
    for r in result['roots']:
        A.validate(r['expression']);a=A.sympy_expr(r['expression'])
        p=s.Poly(s.minpoly(a,x),x,domain=s.QQ).sqf_part().monic()
        if not p.rem(f).is_zero or [str(c) for c in f.monic().all_coeffs()]!=r['minimal_polynomial']:
            raise ValueError('Incorrect minimal-polynomial identity')
        if [str(c) for c in p.all_coeffs()]!=r.get('computed_annihilator',r['minimal_polynomial']):
            raise ValueError('Incorrect annihilating polynomial')
        if f.degree()>1 and not p.same_root(a,roots[r['index']]):raise ValueError('Wrong conjugate')
    return True
