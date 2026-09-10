"""Outward-rounded integer fixed-point interval certificates; no floats used.
Every endpoint is an integer divided by Q. Basic operations and root bounds
use integer floor/ceiling. Trigonometric Taylor tails and Machin's formula
are bounded explicitly. This is an independent check, not paper source code.
"""
from math import isqrt, factorial
Q=10**180
def ceildiv(a,b): return -((-a)//b)
def iroot(n,k):
    assert n>=0
    if k==2:return isqrt(n)
    lo,hi=0,1<<((n.bit_length()+k-1)//k)
    while lo+1<hi:
        mid=(lo+hi)//2
        if mid**k<=n:lo=mid
        else:hi=mid
    return hi if hi**k==n else lo
class I:
    def __init__(self,l,u=None,raw=False):
        if not raw:l*=Q;u=l if u is None else u*Q
        self.l,self.u=l,l if u is None else u
        assert self.l<=self.u
    @staticmethod
    def cast(x):return x if isinstance(x,I) else I(x)
    def __add__(self,x):x=I.cast(x);return I(self.l+x.l,self.u+x.u,True)
    __radd__=__add__
    def __neg__(self):return I(-self.u,-self.l,True)
    def __sub__(self,x):return self+-I.cast(x)
    def __rsub__(self,x):return I.cast(x)+-self
    def __mul__(self,x):
        x=I.cast(x);v=[a*b for a in (self.l,self.u) for b in (x.l,x.u)]
        return I(min(v)//Q,ceildiv(max(v),Q),True)
    __rmul__=__mul__
    def __truediv__(self,x):
        x=I.cast(x);assert not x.l<=0<=x.u
        if x.u<0:return (-self)/(-x)
        vals=[(a*Q,b) for a in (self.l,self.u) for b in (x.l,x.u)]
        return I(min(a//b for a,b in vals),max(ceildiv(a,b) for a,b in vals),True)
    def __rtruediv__(self,x):return I.cast(x)/self
    def root(self,k=2):
        assert self.l>=0
        l=iroot(self.l*Q**(k-1),k);u=iroot(self.u*Q**(k-1),k)
        if u**k<self.u*Q**(k-1):u+=1
        return I(l,u,True)
    def __pow__(self,n):
        assert isinstance(n,int) and n>=0
        z=I(1)
        for _ in range(n):z=z*self
        return z
    def error(self):return max(abs(self.l),abs(self.u))
    def check(self,e):assert self.error()<10**(180-e),(e,self.error())
def atan_inv(n,N=180):
    # Alternating series: its next term bounds the remainder.
    x=I(1)/n;x2=x*x;t=x;s=I(0)
    for k in range(N):
        s=s+((-1)**k)*t/(2*k+1);t=t*x2
    b=(t/(2*N+1)).u
    return I(s.l-b,s.u+b,True)
def asin(x,N=150):
    assert 0<=x.l<=x.u<Q
    # a_(n+1)/a_n = (2n+1)^2/[2(n+1)(2n+3)] < 1;
    # hence tail after N terms <= next/(1-x^2).
    t=x;s=I(0);x2=x*x
    for n in range(N):
        s+=t;t=t*x2*((2*n+1)**2)/(2*(n+1)*(2*n+3))
    tail=t/(1-x2)
    return I(s.l,s.u+tail.u,True)
def sincos(x,is_sin=False,N=150):
    assert -Q<=x.l<=x.u<=Q
    t=x if is_sin else I(1);s=I(0)
    for n in range(N):
        s+=t
        k=2*n+(1 if is_sin else 0)
        t=-t*x*x/((k+1)*(k+2))
    # Degree 2N-1 or 2N-2; all real derivatives <=1, |x|<=1.
    degree=2*N-1 if is_sin else 2*N-2
    err=ceildiv(Q,factorial(degree+1))
    return I(s.l-err,s.u+err,True)
r2=I(2).root();r3=I(3).root();r6=I(6).root();r7=I(7).root();r13=I(13).root()
a=r2+(5-2*r6).root()-r3;a.check(170)
z=(5*r13-18).root(3);p=z*z+3*z-1;p.check(170)
y=r2+(5-2*r6).root();p2=y*y-3;p2.check(170)
pi=16*atan_inv(5)-4*atan_inv(239)
theta=(pi/2-asin(1/(2*r7)))/3
alpha=2*sincos(pi/7);beta=2*r7*sincos(theta);gamma=2*r7*r3*sincos(theta,True)
zeta=6*alpha-2-beta-gamma;zeta.check(170)
for name,v in [('student residual',a),('cubic recognition residual',p),('student polynomial residual',p2),('trigonometric residual',zeta)]:
    print(name,': exact enclosure [',v.l,',',v.u,'] / 10^180; |residual| < 10^-170')
