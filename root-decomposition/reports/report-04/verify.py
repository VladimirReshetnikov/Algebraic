#!/usr/bin/env python3
"""Independent exact-arithmetic checks for article.tex.

Requires Python 3 and SymPy. This is NOT execution of the Wolfram source.
All reported PASS checks below are exact except the explicitly labeled
illustrative decimal approximations.
"""
from __future__ import annotations
import itertools
import platform
import sympy as s

x, t = s.symbols('x t')
f = x**3+x+1
g = x**3-x+1
pm = x**9+2*x**7-3*x**6+x**5-x**4+3*x**3-x-1
ps = x**9+6*x**6+3*x**5-15*x**3+24*x**2-4*x+8
checks = 0

def check(label: str, condition: object) -> None:
    global checks
    if not bool(condition):
        raise AssertionError(label)
    checks += 1
    print(f'PASS {checks:02d}: {label}')

print(f'Python {platform.python_version()}; SymPy {s.__version__}')
print('Independent symbolic validation; Wolfram code was not kernel-executed.\n')
check('forward sum resultant', s.expand(s.resultant(f.subs(x,t), g.subs(x,x-t), t)-ps) == 0)
check('forward product resultant', s.expand(s.resultant(f.subs(x,t),x**3-x*t**2+t**3,t)-pm) == 0)
for name, p in [('f',f),('g',g),('Pm',pm),('Ps',ps)]:
    check(f'{name} irreducible over Q',s.Poly(p,x).is_irreducible)
    check(f'{name} has exactly one real root',s.Poly(p,x).count_roots(-s.oo,s.oo)==1)
check('cubic discriminants', [s.discriminant(p,x) for p in [f,g]]==[-31,-23])
for name, P, substitution in [('sum',ps,x+t),('product',pm,x*t)]:
    R=s.resultant(f.subs(x,t),P.subs(x,substitution),t)
    _, ff=s.factor_list(R,x)
    small=[s.Poly(q,x).monic().as_expr() for q,e in ff if s.degree(q,x)<=3]
    check(f'{name} inverse resultant recovers g',small==[g])
    check(f'{name} inverse resultant factor degrees and multiplicities',
          sorted([(s.degree(q,x),e) for q,e in ff])==[(3,3),(18,1)])

recovery = [
    ('sum',ps,3*x**5-5*x**3-3*x**2+2*x-4,6*x**4-6*x+4),
    ('product',pm,x**3-x**2-1,x**4+x**2-x+1)]
for name,P,num,den in recovery:
    check(f'{name} recovery denominator coprime to P',s.degree(s.gcd(den,P),x)==0)
    check(f'{name} recovered first root satisfies f',s.rem(num**3+num*den**2+den**3,P,x)==0)
    bn,bd=(x*den-num,den) if name=='sum' else (x*den,num)
    check(f'{name} second denominator coprime to P',s.degree(s.gcd(bd,P),x)==0)
    check(f'{name} recovered second root satisfies g',s.rem(bn**3-bn*bd**2+bd**3,P,x)==0)
    identity=num/den+bn/bd-x if name=='sum' else num*bn/(den*bd)-x
    check(f'{name} recovered roots combine to x',s.cancel(identity)==0)

check('sum branch: f has root between -683/1000 and -682/1000',
      f.subs(x,-s.Rational(683,1000))*f.subs(x,-s.Rational(682,1000))<0)
check('sum branch: g has root between -1325/1000 and -1324/1000',
      g.subs(x,-s.Rational(1325,1000))*g.subs(x,-s.Rational(1324,1000))<0)

# Reference version of exhaustive fixed-subspace enumeration for a V4 field.
pt=x**4-10*x**2+1
images=[x,-x,x**3-10*x,10*x-x**3]
def vec(q: s.Expr) -> s.Matrix:
    r=s.Poly(s.rem(q,pt,x),x)
    return s.Matrix([r.nth(i) for i in range(4)])
mats=[s.Matrix.hstack(*(vec(q**j) for j in range(4))) for q in images]
check('four exact biquadratic automorphisms',all(s.rem(pt.subs(x,q),pt,x)==0 for q in images))
check('automorphisms all have exponent dividing 2',all(A*A==s.eye(4) for A in mats))

def canonical(M:s.Matrix)->s.Matrix:
    rr,_=M.rref()
    rows=[list(rr.row(i)) for i in range(rr.rows) if any(rr.row(i))]
    return s.Matrix(rows)
def key(M:s.Matrix)->tuple:
    return (M.rows,M.cols,tuple(M))
spaces=[s.eye(4)]; seen={key(spaces[0])}; pos=0
while pos<len(spaces):
    W=spaces[pos]; pos+=1
    for A in mats:
        ns=((A-s.eye(4))*W.T).nullspace()
        B=s.Matrix.vstack(*(v.T for v in ns))
        V=canonical(B*W)
        if key(V) not in seen:
            seen.add(key(V));spaces.append(V)
check('complete V4 fixed-space enumeration has five subfields',len(spaces)==5)
check('subfield dimensions',sorted(W.rows for W in spaces)==[1,2,2,2,4])
av=s.Matrix([[1,1,0,0]]) # 1 + sqrt(2) + sqrt(3)
for d,expected in [(1,False),(2,True)]:
    rows=s.Matrix.vstack(*(W for W in spaces if W.rows<=d))
    found=rows.col_join(av).rank()==rows.rank()
    check(f'additive span membership at degree threshold {d}',found==expected)

h=x**4-4*x**3-4*x**2+16*x-8
check('1+sqrt(2)+sqrt(3) minimal polynomial',s.minpoly(1+s.sqrt(2)+s.sqrt(3),x)==h)
check('biquadratic norm is -8',h.subs(x,0)==-8)
check('biquadratic has four real conjugates',s.Poly(h,x).count_roots(-s.oo,s.oo)==4)
quartic=x**4-x-1
pair=x**6+4*x**2-1
check('quartic pair-sum resultant factorization',
      s.expand(s.resultant(quartic.subs(x,t),quartic.subs(x,x-t),t)
               -(x**4-8*x-16)*pair**2)==0)
check('quartic and pair-sum polynomials irreducible',
      s.Poly(quartic,x).is_irreducible and s.Poly(pair,x).is_irreducible)
check('quartic discriminant is -283',s.discriminant(quartic,x)==-283)
check('quartic irreducible modulo two',s.Poly(quartic,x,modulus=2).is_irreducible)
resolvent=x**3+4*x-1
check('quartic resolvent irreducible with the same discriminant',
      s.Poly(resolvent,x).is_irreducible and s.discriminant(resolvent,x)==-283)
zeta=(-1+s.I*s.sqrt(3))/2
check('two cubic summands can have degree-six sum',
      s.minpoly(2**s.Rational(1,3)*(1-zeta),x)==x**6+108)
Rn=s.resultant(2*t*t-1,(16*x**4-40*x**2+1).subs(x,x+t),t)
_,ffn=s.factor_list(Rn,x)
check('nonmonic first polynomial yields the correct quadratic complement',
      [s.Poly(q,x).monic().as_expr() for q,e in ffn if s.degree(q,x)<=2]
      == [x*x-s.Rational(3,4)])
check('quartic has two real roots and pair-sum polynomial has two',
      s.Poly(quartic,x).count_roots(-s.oo,s.oo)==2 and s.Poly(pair,x).count_roots(-s.oo,s.oo)==2)
check('degree-eight three-summand example',s.degree(s.minpoly(s.sqrt(2)+s.sqrt(3)+s.sqrt(5),x),x)==8)
check('degree-eight three-factor example',s.degree(s.minpoly((1+s.sqrt(2))*(1+s.sqrt(3))*(1+s.sqrt(5)),x),x)==8)
check('composed sum can have repeated roots',s.expand(s.resultant(t*t-2,(x-t)**2-2,t)-x*x*(x*x-8))==0)
check('composed product can have repeated roots',s.expand(s.resultant(t*t-2,x*x-2*t*t,t)-(x*x-4)**2)==0)

# Check the coefficient ansatz used in the paper, including nonrational branches.
a,b,c,e=s.symbols('a b c e')
RM=s.resultant(t**3+a*t+b,x**3+c*x*t**2+e*t**3,t)
RS=s.resultant(t**3+a*t+b,(x-t)**3+c*(x-t)+e,t)
solM=s.solve(s.Poly(RM.subs(b,1)-pm,x).all_coeffs(),[a,c,e])
ratM=[q for q in solM if all(z.is_Rational for z in q)]
check('two rational normalized product ansatz solutions',set(ratM)=={(s.Integer(-1),s.Integer(1),s.Integer(1)),(s.Integer(1),s.Integer(-1),s.Integer(1))})
solS=s.solve(s.Poly(RS-ps,x).all_coeffs(),[a,b,c,e])
check('two rational depressed-cubic sum solutions',set(solS)=={(-1,1,1,1),(1,1,-1,1)})

print(f'\nAll {checks} exact checks passed.')
print('Illustrative decimals (not certificates):')
u=s.polys.polytools.intervals(f,eps=s.Rational(1,10**20))[0][0]
v=s.polys.polytools.intervals(g,eps=s.Rational(1,10**20))[0][0]
U=sum(u)/2;V=sum(v)/2
for label,z in [('a',U),('b',V),('a*b',U*V),('a+b',U+V)]:
    print(f'  {label} = {s.N(z,18)}')
