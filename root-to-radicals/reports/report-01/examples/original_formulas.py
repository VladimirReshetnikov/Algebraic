"""Compact original formulas, independently checked with exact polynomial roots."""
import sympy as s
x=s.Symbol('x')
u=((9+s.sqrt(849))/18)**s.Rational(1,3)
y=u-4/(3*u)
sextic_answer=(y+s.sqrt(y*y+4))/2
v=((-3+4*s.I)/5)**s.Rational(1,5)
quintic_answer=v+1/v
for f,a,k in [(x**6+x**4-x**3-x**2-1,sextic_answer,1),
              (5*x**5-25*x**3+25*x+6,quintic_answer,4)]:
    f=s.Poly(f,x,domain=s.QQ).monic()
    p=s.Poly(s.minpoly(a,x),x,domain=s.QQ).monic()
    assert p==f
    assert p.same_root(a,s.CRootOf(f,k))
    print(a,'\n',a.evalf(30),'\nVerified.\n')
