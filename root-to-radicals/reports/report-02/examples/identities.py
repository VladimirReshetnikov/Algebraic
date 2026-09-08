"""Reproduce polynomial identities in the article, without numerical fitting."""
import sympy as s
x,t,a,u=s.symbols('x t a u')
f5=5*x**5-25*x**3+25*x+6
assert s.cancel(f5.subs(x,u+1/u)-5*(u**5+u**-5)-6)==0
f6=x**6+x**4-x**3-x**2-1
assert s.expand(x**3*((x-1/x)**3+4*(x-1/x)-1)-f6)==0
f8=x**8+8*x**7+20*x**6+8*x**5-36*x**4-48*x**3-15*x**2+2*x+1
p8=t**8-32*t**6+224*t**4-448*t**2+256
assert s.expand(256*f8.subs(x,t/2-1)-p8)==0
assert s.expand(s.resultant(a*a-3,((t-a)**2-5)**2-20,a)-p8)==0
assert s.Poly(f8,x).is_irreducible
print('Quintic, sextic, and degree-eight polynomial identities: exact checks passed.')
