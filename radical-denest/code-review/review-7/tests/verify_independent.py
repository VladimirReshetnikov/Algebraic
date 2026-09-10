#!/usr/bin/env python3
"""Exact independent algebra checks. Does NOT execute Wolfram Language."""
from collections import Counter, defaultdict
from fractions import Fraction as Q
from hashlib import sha1, sha256
from math import gcd, isqrt
from pathlib import Path
import json
import platform
import sympy as sp

ROOT = Path(__file__).resolve().parents[1]
counts = Counter()
def check(test, family):
    assert bool(test), family
    counts[family] += 1

# Direct quadratic formula, with rational u,v and both cross-term signs.
for u in range(2, 19):
    for v in range(1, u):
        c = u*v
        if isqrt(c)**2 == c:
            continue
        for b in (-2, 2):
            a = u+v; delta = u-v
            check(a*a-b*b*c == delta*delta, 'direct_norm')
            x = sp.sqrt(u) + (1 if b>0 else -1)*sp.sqrt(v)
            check(sp.expand(x*x-a-b*sp.sqrt(c)) == 0, 'direct_square')
            check(u > v > 0, 'direct_branch')

# Indirect criterion: exact rational parameter sweep, a can be negative.
for b in range(2, 9):
    for e in range(1, b):
        for a in range(-5, 6):
            if not a:
                continue
            c = Q(a*a, b*b-e*e)
            if isqrt(c.numerator)**2 == c.numerator and isqrt(c.denominator)**2 == c.denominator:
                continue
            D = Q(a*a)-b*b*c
            check(D < 0, 'indirect_norm_negative')
            check(-c*D == (c*e)**2, 'indirect_square_criterion')
            check(c*(b*b-e*e) == a*a and b+e > b-e > 0, 'indirect_identity_and_branch')

# Cubic trace-norm reconstruction, using exact coefficient arithmetic.
for c in (2,3,5,6,7,10,13):
    for A in range(-4,5):
        for B in range(-3,4):
            if not B:
                continue
            a=A*(A*A+3*B*B*c); b=B*(3*A*A+B*B*c)
            n=A*A-B*B*c; T=2*A; den=T*T-n
            check(a*a-b*b*c == n**3, 'cubic_norm')
            check(T**3-3*n*T-2*a == 0, 'cubic_trace')
            check(den != 0 and Q(b,den)==B and Q(T,2)==A, 'cubic_reconstruction')
            check((T*T-4*n)*(T*T-n)**2 == 4*b*b*c, 'cubic_denominator_identity')

# Higher odd-index Dickson identities and exact quadratic-field sweeps.
T,N=sp.symbols('T N')
for m in range(3,16,2):
    D=sum(sp.Rational(m,m-j)*sp.binomial(m-j,j)*(-N)**j*T**(m-2*j)
          for j in range(m//2+1))
    U=sum(sp.binomial(m-1-j,j)*(-N)**j*T**(m-1-2*j)
          for j in range((m-1)//2+1))
    check(sp.expand(D*D-4*N**m-(T*T-4*N)*U*U)==0,'dickson_symbolic_identity')
    if m==3:
        continue
    for c in (2,3,5):
        for A in range(-3,4):
            for B in (-2,-1,1,2):
                a,b=1,0
                for _ in range(m):
                    a,b=a*A+b*B*c,a*B+b*A
                n=A*A-c*B*B; t=2*A
                d=sum(Q(m,m-j)*int(sp.binomial(m-j,j))*(-n)**j*t**(m-2*j)
                      for j in range(m//2+1))
                u=sum(int(sp.binomial(m-1-j,j))*(-n)**j*t**(m-1-2*j)
                      for j in range((m-1)//2+1))
                check(a*a-b*b*c==n**m,'higher_odd_norm')
                check(d==2*a,'higher_odd_trace')
                check(u!=0 and Q(b,u)==B and Q(t,2)==A,'higher_odd_reconstruction')

# Polynomial inverse (Horner identity); valid before any branch choice.
x=sp.Symbol('x')
for degree in range(1,13):
    cs=[(-1)**j*(j+1) for j in range(degree+1)]
    p=sum(cs[j]*x**j for j in range(degree+1))
    inv=-sum(sp.Rational(cs[j],cs[0])*x**(j-1) for j in range(1,degree+1))
    check(sp.expand(x*inv-1+p/cs[0]) == 0,'horner_inverse')

u,s=sp.symbols('u s')
identity=sp.expand((-s*s/2+s*u+u*u)**2-(u**3-s**3)*(1+u)
                  -(s**4+4*s**3+8*u**3*s-4*u**3)/4)
check(identity == 0,'honsbeek_polynomial')
check(Q(16-32)+8*Q(-4,5)*(-2)-4*Q(-4,5) == 0,'honsbeek_parameter')
check(-4-(-2)**3*5 == 36,'honsbeek_denominator')

# Phase enumeration over Q*pi, exact modular arithmetic only.
def wrap(a):
    z=(a+1)%2-1
    return Q(1) if z == -1 else z
for q in range(2,17):
    for k in range(2,q+1):
        if q%k:
            continue
        rest=q//k
        for angle in map(Q, ('-3/4','-1/2','-1/3','0','1/3','1/2','3/4','1')):
            expected={wrap((angle+2*j)/q) for j in range(q)}
            for g in range(k):
                gamma=wrap((angle+2*g)/k)
                actual={wrap(wrap(gamma+Q(2*j,k))/rest+Q(2*l,rest))
                        for j in range(k) for l in range(rest)}
                check(actual==expected,'kummer_orbit')
                for p in (-5,-3,-1,1,3,5):
                    if gcd(abs(p),q)==1:
                        check(wrap(Q(p,q)*angle) in {wrap(p*a) for a in actual},'rational_power_branch')

# Multiquadratic counterexample: sqrt(u)*sqrt(v) for squarefree positive u,v.
def square(coefficients):
    out=defaultdict(Q)
    for u,a in coefficients.items():
        for v,b in coefficients.items():
            g=gcd(u,v)
            out[(u//g)*(v//g)] += a*b*g
    return {d:a for d,a in out.items() if a}
beta={30:Q(1),42:Q(1),70:Q(1)}
rho={1:Q(142),15:Q(28),21:Q(20),35:Q(12)}
check(square(beta)==rho,'multisurd_square')
check(all(d%2 for d in rho),'multisurd_fixed_field')
check(all(d%2==0 for d in beta),'multisurd_coset')
eta={15:Q(2),21:Q(2),35:Q(2)}
check(square(eta)=={d:2*a for d,a in rho.items()},'multisurd_multiplier_two')

# A field norm does not supply all useful rational multipliers.
check(2**2-3==1,'unit_norm')
check(sp.expand(((sp.sqrt(6)+sp.sqrt(2))/2)**2-(2+sp.sqrt(3)))==0,'unit_denesting')

# Byte provenance and static lexical checks; not a WL parser or native test.
raw=(ROOT/'code/StradFixed2.pinned.wl').read_bytes()
check(sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
      =='0bdeded347385a55a044fdd35883006d053685dc','pinned_git_blob')
def balanced(text):
    stack=[]; depth=0; string=False; i=0; opens='([{'; closes=')]}'; pair=dict(zip(closes,opens))
    while i<len(text):
        c=text[i]; two=text[i:i+2]
        if depth:
            if two=='(*': depth+=1; i+=2; continue
            if two=='*)': depth-=1; i+=2; continue
        elif string:
            if c=='\\': i+=2; continue
            if c=='"': string=False
        else:
            if two=='(*': depth=1; i+=2; continue
            if c=='"': string=True
            elif c in opens: stack.append(c)
            elif c in closes:
                if not stack or stack.pop()!=pair[c]: return False
        i+=1
    return not stack and depth==0 and not string
for f in sorted((ROOT/'code').glob('*.wl'))+sorted((ROOT/'tests').glob('*.wlt'))+sorted((ROOT/'tests').glob('*.wls')):
    check(balanced(f.read_text()),'wl_lexical_balance')
new=(ROOT/'code/StradFixed3.wl').read_text()
for token in ('best = negativeRadicandCandidate[target, rho, p, q, best]',
              'best = kummerCandidates[target, rho, p, q, best]',
              'key = memoKey[target,', '"NumericHints"', '"CertificateKind"',
              'primes = bounded[', 'sq = bounded[Expand[cand^2]]'):
    check(token in new,'static_patch_presence')
report={'python':platform.python_version(),'sympy':sp.__version__,
        'native_wolfram_executed':False,'assertions_passed':sum(counts.values()),
        'families':dict(counts),'original_git_blob':'0bdeded347385a55a044fdd35883006d053685dc',
        'improved_sha256':sha256((ROOT/'code/StradFixed3.wl').read_bytes()).hexdigest(),
        'limitations':'Exact algebra and lexical checks; no Wolfram evaluation, branch implementation benchmark, or native regression claim.'}
(ROOT/'evidence/independent_results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
