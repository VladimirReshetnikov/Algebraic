#!/usr/bin/env python3
"""Exact mathematical and source-structure checks; NOT a WL emulator/test run.
Requires Python >=3.10 and SymPy. Writes independent_results.json.
"""
from __future__ import annotations
from fractions import Fraction as F
from itertools import product
from math import gcd, isqrt
from pathlib import Path
import hashlib, json, platform, random
import sympy as S

ROOT=Path(__file__).resolve().parent
results=[]
def check(name, condition, **detail):
    if not condition: raise AssertionError(name)
    results.append({'name': name, 'passed': True, **detail})

# The archived baseline is byte-identical to the Git object reviewed.
b=(ROOT/'StradFixed2.original.wl').read_bytes()
check('baseline_git_blob', hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
      == '0bdeded347385a55a044fdd35883006d053685dc', bytes=len(b))

# Algebraic identities in a polynomial quotient ring, not numerical matching.
A,B,a,b,t=S.symbols('A B a b t')
N=B**2+t*A*B-t**2*A**2/2
G=S.groebner([A**3-a,B**3-b],A,B,domain=S.QQ.frac_field(a,b,t))
rem=G.reduce(S.expand(N**2-(A+B)*(b-t**3*a)))[1]
check('Honsbeek_quartic_identity', S.expand(rem-A*(a*t**4+4*a*t**3+8*b*t-4*b)/4)==0)
T,n,z=S.symbols('T n z')
D0,D1,S0,S1=S.Integer(2),T,S.Integer(0),S.Integer(1)
for q in range(2,12):
    D0,D1=D1,S.expand(T*D1-n*D0)
    S0,S1=S1,S.expand(T*S1-n*S0)
    check(f'Dickson_identity_q{q}', S.expand(D1**2-(T*T-4*n)*S1**2-4*n**q)==0)
for q in (3,5,7,9):
    for av,bv,c in ((2,1,2),(3,-1,2),(1,2,3),(-2,1,5),(F(3,2),F(1,3),7)):
        av,bv=S.Rational(av),S.Rational(bv)
        beta=av+bv*S.sqrt(c)
        alpha=S.expand(beta**q)
        aa=alpha.coeff(S.sqrt(c),0); bb=alpha.coeff(S.sqrt(c))
        nn=av*av-c*bv*bv; trace=2*av
        u0,u1=0,1
        for k in range(2,q+1): u0,u1=u1,S.expand(trace*u1-nn*u0)
        check(f'odd_reconstruction_{q}_{av}_{bv}_{c}',
              S.simplify(trace/2+bb*S.sqrt(c)/u1-beta)==0 and
              S.expand(aa*aa-c*bb*bb-nn**q)==0)
for degree in range(1,13):
    cs=[S.Integer(3)]+[S.Integer((-1)**i*(i+2)) for i in range(1,degree+1)]
    p=sum(cs[i]*z**i for i in range(degree+1))
    inverse=-sum(cs[i]*z**(i-1) for i in range(1,degree+1))/cs[0]
    check(f'Horner_inverse_degree_{degree}', S.rem(S.expand(z*inverse-1),p,z)==0)

# Exact multiquadratic arithmetic: squarefree positive integer -> coefficient.
Rad=dict[int,F]
def add(x:Rad,y:Rad)->Rad:
    r=x.copy()
    for d,c in y.items(): r[d]=r.get(d,F(0))+c
    return {d:c for d,c in r.items() if c}
def scale(x:Rad,c)->Rad: return {d:v*c for d,v in x.items() if v*c}
def mul(x:Rad,y:Rad)->Rad:
    r={}
    for d,c in x.items():
        for e,f in y.items():
            g=gcd(d,e); k=d*e//(g*g)
            r[k]=r.get(k,F(0))+c*f*g
    return {d:c for d,c in r.items() if c}
def sqrt_int(d:int)->Rad:
    sf=1; factor=1
    for p,e in S.factorint(d).items():
        factor*=int(p)**(int(e)//2)
        if e%2: sf*=int(p)
    return {sf:F(factor)}
def exact_sign(x:Rad)->int:
    # Certified outward rational bounds, with a 10^-60 grid.
    k=10**60; lo=F(0); hi=F(0)
    for d,c in x.items():
        r=isqrt(d*k*k); l=F(r,k); u=F(r+(r*r!=d*k*k),k)
        lo+=c*(l if c>0 else u); hi+=c*(u if c>0 else l)
    if lo>0:return 1
    if hi<0:return -1
    if not x:return 0
    raise ArithmeticError('Increase sign-isolation precision')
def mask(d):
    return sum((1<<i) for i,p in enumerate([2,3,5,7]) if d%p==0)
def conjugate(x,w):
    return {d:c*(-1)**((w&mask(d)).bit_count()) for d,c in x.items()}
def plus(xs):
    r={}
    for x in xs:r=add(r,x)
    return r

beta={6:F(1),10:F(1),21:F(1)}
rho=mul(beta,beta)
check('sparse_ansatz_counterexample_square',rho=={1:F(37),15:F(4),14:F(6),210:F(2)})
old_basis={1,2,3,5,7,14,15,210}
check('sparse_ansatz_support_exclusion',set(beta).isdisjoint(old_basis))
# Automorphisms of K=Q(sqrt(14),sqrt(15)), lifted while fixing sqrt(6).
lifts=[]
for i in range(4):
    lifts.append(next(w for w in range(16)
        if (w&mask(14)).bit_count()%2 == (i&1)
        and (w&mask(15)).bit_count()%2 == ((i>>1)&1)
        and (w&mask(6)).bit_count()%2 == 0))
H=[[(-1)**((i&j).bit_count()) for j in range(4)] for i in range(4)]
check('Hadamard_orthogonality',all(sum(H[i][k]*H[j][k] for k in range(4))==(4 if i==j else 0)
    for i in range(4) for j in range(4)))
def reconstruct(beta:Rad):
    if exact_sign(beta)<0:beta=scale(beta,-1)
    conjugates=[conjugate(beta,w) for w in lifts]
    lambdas=[scale(v,exact_sign(v)) for v in conjugates]
    for tail in product([1,-1],repeat=3):
        signs=(1,)+tail
        coeff=[scale(plus(scale(lambdas[i],H[j][i]*signs[i]) for i in range(4)),F(1,4))
               for j in range(4)]
        if all(set(mul(c,c)) <= {1} for c in coeff):
            if plus(coeff)!=beta: raise AssertionError('Wrong reconstruction')
            return signs,coeff
    raise AssertionError('Exhaustive rank-two reconstruction failed')
signs,pieces=reconstruct(beta)
check('Hadamard_counterexample_reconstruction',plus(pieces)==beta,signs=list(signs))
rng=random.Random(20260905)
for case in range(48):
    coeff=[rng.choice([-3,-2,-1,1,2,3]) for _ in range(4)]
    rad=plus(scale(sqrt_int(6*g),c) for g,c in zip([1,14,15,210],coeff))
    signs,pieces=reconstruct(rad)
    check(f'Hadamard_rank2_coset_case_{case}',all(set(mul(v,v))<={1} for v in pieces))

# Exact loop models, explicitly not execution of the WL package.
def batch(q:int,np:int,cap:int,patched:bool)->int:
    n=0
    for _ in range(np):
        if n>=cap:break
        for _ in range(1,q):
            if patched and n>=cap:break
            n+=1
    return n
worst=(0,0)
for q in range(2,33):
    for np in range(9):
        old=batch(q,np,24,False); new=batch(q,np,24,True)
        check(f'batch_model_q{q}_primes{np}',new<=24)
        if old>worst[0]:worst=(old,q)
check('old_batch_maximum_46',worst==(46,24),maximum=worst[0],root_index=worst[1])
for cap in [0,1,2,7,24,25,100]:
    admitted=0
    for _ in range(1000):
        if admitted<cap:admitted+=1
    check(f'global_admission_cap_{cap}',admitted==cap)

# Exact partial denesting and already-useful index reduction.
s=S.sqrt(29); u=11-2*s
# Squaring the partial form gives rho, because 5*u = 55-10*sqrt(29).
check('partial_denesting_polynomial_identity',S.expand((16-2*s)-(5+u))==0 and S.expand(5*u-(55-10*s))==0)
check('index_reduction_identity',S.expand((1+S.sqrt(2))**2-(3+2*S.sqrt(2)))==0)
check('quadratic_square_obstruction_norm',S.expand((1+S.sqrt(2))*(1-S.sqrt(2)))==-1)

# Structural checks: strings and nested comments are removed before delimiters.
def lexical_balance(text:str)->bool:
    stack=[]; i=0; comment=0; string=False
    pairs={')':'(',']':'[','}':'{'}
    while i<len(text):
        a=text[i:i+2]; c=text[i]
        if comment:
            if a=='(*':comment+=1;i+=2;continue
            if a=='*)':comment-=1;i+=2;continue
            i+=1;continue
        if string:
            if c=='\\':i+=2;continue
            if c=='"':string=False
            i+=1;continue
        if a=='(*':comment=1;i+=2;continue
        if c=='"':string=True;i+=1;continue
        if c in '([{':stack.append(c)
        if c in ')]}':
            if not stack or stack.pop()!=pairs[c]:return False
        i+=1
    return not stack and not comment and not string
for name in ['StradFixed2.original.wl','StradFixed3.wl','revision_definitions.wl','StradFixed3Tests.wlt','run_tests.wls']:
    p=ROOT/name
    if p.exists():check('lexical_balance_'+name,lexical_balance(p.read_text()))
new=(ROOT/'StradFixed3.wl').read_text()
check('no_unconditional_negative_cache', 'If[! expiredQ[], AssociateTo[$memo, key -> best]]' not in new)
check('incumbent_threading_negative','negativeRadicandCandidate[target, rho, p, q, best]' in new)
check('incumbent_threading_Kummer','kummerCandidates[target, rho, p, q, best]' in new)
check('direct_index_reduction_gate','"IndexReduction/Direct"' in new)
check('no_heuristic_Different_return','bump["NumericRejections"]; bump["CertificatesDifferent"]' not in new)
report={'kind':'Independent exact mathematics and lexical/source checks; not native Wolfram tests',
        'python':platform.python_version(),'sympy':S.__version__,'native_wolfram_executed':False,
        'passed':len(results),'failed':0,'checks':results}
(ROOT/'independent_results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
