"""Rational rectangles, exact signs, and principal-power branch certificates.

All interval endpoints are rational.  The only SymPy private API is localized
in RootBox: CRootOf._get_interval() and the root-isolator's refine_size().
Tested with SymPy 1.14.0; an incompatible API is an error, never evidence of
insolvability.  No decimal approximation is an acceptance criterion.
"""
from __future__ import annotations
from fractions import Fraction as Q
from dataclasses import dataclass
from math import gcd
import sympy as s


def frac(v):
    if isinstance(v,Q): return v
    if hasattr(v,'p'): return Q(int(v.p),int(v.q))
    if hasattr(v,'numerator'): return Q(int(v.numerator),int(v.denominator))
    return Q(v)

def imul(a,b):
    p=[a[0]*b[0],a[0]*b[1],a[1]*b[0],a[1]*b[1]]
    return min(p),max(p)
def iadd(a,b): return a[0]+b[0],a[1]+b[1]
def ineg(a): return -a[1],-a[0]

@dataclass(frozen=True)
class Box:
    re: tuple
    im: tuple
    @classmethod
    def rational(cls,a):
        a=frac(a);return cls((a,a),(Q(0),Q(0)))
    def __add__(self,b): return Box(iadd(self.re,b.re),iadd(self.im,b.im))
    def __mul__(self,b):
        return Box(iadd(imul(self.re,b.re),ineg(imul(self.im,b.im))),
                   iadd(imul(self.re,b.im),imul(self.im,b.re)))
    def conjugate(self): return Box(self.re,ineg(self.im))
    def overlaps(self,b):
        return all(max(a[0],c[0])<=min(a[1],c[1]) for a,c in [(self.re,b.re),(self.im,b.im)])
    def json(self): return [[str(v) for v in self.re],[str(v) for v in self.im]]

class RootBox:
    def __init__(self,r):
        self.r=r
        self.interval=None if r.is_Rational else r._get_interval()
        self.bits=0
    def at(self,bits):
        if self.interval is None: return Box.rational(self.r)
        if bits>self.bits:
            eps=s.QQ(1,2**bits)
            self.interval=self.interval.refine_size(eps)
            self.bits=bits
        iv=self.interval
        if self.r.is_real: return Box((frac(iv.a),frac(iv.b)),(Q(0),Q(0)))
        return Box((frac(iv.ax),frac(iv.bx)),(frac(iv.ay),frac(iv.by)))

class Embedding:
    def __init__(self,F):
        self.F=F;self.theta=RootBox(F.embedding)
        self.conjugate_image=None
        self.sign_cache={}
    def box(self,a,bits=32):
        b=self.theta.at(bits); v=Box.rational(0)
        for c in a.to_list(): v=v*b+Box.rational(c)
        return v
    def match_roots(self,values,poly):
        """Match exact known roots to CRootOf indices, by unique intersection.

        Preconditions (checked): all supplied values satisfy the squarefree
        rational polynomial.  Isolation plus unique intersection proves the
        identity, not merely proximity to a numerical approximation.
        """
        f=s.Poly(poly,domain=s.QQ).sqf_part()
        targets=f.all_roots(radicals=False)
        for a in values:
            r=self.F.zero
            for c in f.all_coeffs(): r=r*a+self.F.rational(c)
            if r: raise ArithmeticError('Root matching was given a non-root')
        boxes=[RootBox(r) for r in targets]
        pending=set(range(len(values))); matched={}; witnesses={}; bits=8
        while pending:
            bs=[r.at(bits) for r in boxes]
            for i in list(pending):
                b=self.box(values[i],bits)
                hit=[j for j,t in enumerate(bs) if b.overlaps(t)]
                if len(hit)==1:
                    matched[i]=hit[0];witnesses[i]=b.json();pending.remove(i)
                elif not hit:
                    raise ArithmeticError('Inconsistent rational root enclosures')
            bits*=2
        return matched,witnesses
    def setup_conjugation(self,original_poly,roots,zeta):
        order,_=self.match_roots(roots,original_poly)
        target=s.Poly(original_poly).all_roots(radicals=False)
        inv={j:roots[i] for i,j in order.items()}
        lookup={a:i for i,a in enumerate(roots)}
        result=self.F.zero
        for w,a in zip(self.F.root_weights,self.F.selected_roots):
            idx=order[lookup[a]]
            r=target[idx];cr=s.conjugate(r)
            if cr.is_Rational: j=target.index(cr)
            else: j=int(cr.index)
            result+=self.F.rational(w)*inv[j]
        result+=self.F.rational(self.F.unity_coefficient)/zeta if self.F.unity_coefficient else self.F.zero
        # The defining polynomial test proves this is a field automorphism.
        test=self.F.zero
        for c in self.F.poly.all_coeffs(): test=test*result+self.F.rational(c)
        if test: raise ArithmeticError('Conjugation is not an automorphism')
        if self.F.eval_at(result,result)!=self.F.theta:
            raise ArithmeticError('Conjugation does not square to the identity')
        self.conjugate_image=result
        return order
    def conjugate(self,a):
        if self.conjugate_image is None: raise RuntimeError('Conjugation not initialized')
        return self.F.eval_at(a,self.conjugate_image)
    def sign(self,a,component='re'):
        key=(a,component)
        if key in self.sign_cache: return self.sign_cache[key]
        c=self.conjugate(a)
        # Exact zero tests prevent infinite refinement on a boundary.
        if (a+c if component=='re' else a-c)==self.F.zero:
            self.sign_cache[key]=0;return 0
        bits=8
        while True:
            b=self.box(a,bits)
            lo,hi=b.re if component=='re' else b.im
            if lo>0: ans=1;break
            if hi<0: ans=-1;break
            bits*=2
        self.sign_cache[key]=ans;return ans
    def unity_exponent(self,zeta,N):
        if N==1: return 0
        if N==2:
            if zeta!=-self.F.one: raise ArithmeticError('Bad second root of unity')
            return 1
        p=s.Poly(s.cyclotomic_poly(N,s.Dummy('z')))
        idx=self.match_roots([zeta],p)[0][0]
        # SymPy orders complex roots by real part, then imaginary part.
        # cos(2*pi*a/N) decreases with min(a,N-a); conjugate lower half first.
        exponents=sorted((a for a in range(1,N) if gcd(a,N)==1),
                         key=lambda a:(-min(a,N-a),0 if 2*a>N else 1))
        return exponents[idx]
    def principal_branch(self,beta,p,zeta,N,a):
        """Return k with beta = (zeta^(N/p))^k * PrincipalRoot(beta^p,p)."""
        if not beta: raise ValueError('Kummer generator must be nonzero')
        eigen=zeta**(N//p)
        if p>2:
            standard=eigen**pow(a,-1,p)
            upper=-standard**((p+1)//2)  # exp(pi*i/p), within M for odd p.
        for k in range(p):
            gamma=beta/eigen**k
            sr=self.sign(gamma,'re')
            if p==2:
                si=self.sign(gamma,'im') if sr==0 else None
                good=sr>0 or (sr==0 and si>0)
                witness={'real_sign':sr,'imaginary_sign_on_boundary':si}
            else:
                below=self.sign(gamma/upper,'im')
                above=self.sign(gamma*upper,'im')
                good=sr>0 and below<=0 and above>0
                witness={'real_sign':sr,'upper_boundary_cross_sign':below,'lower_boundary_cross_sign':above}
            if good: return k,witness
        raise ArithmeticError('No principal branch met the exact sector conditions')
