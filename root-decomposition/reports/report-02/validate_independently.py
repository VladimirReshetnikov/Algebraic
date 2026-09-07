#!/usr/bin/env python3
"""Independent exact checks using SymPy; NOT execution of the WL package.
Run: python validate_independently.py
Requires Python 3 and SymPy. No network access is used.
"""
from __future__ import annotations
from collections import Counter
from itertools import permutations, product
from pathlib import Path
import json
import sympy as s

x, y, z = s.symbols('x y z')
checks: list[dict[str, object]] = []
def check(name: str, condition: object, detail: object = None) -> None:
    ok = bool(condition)
    checks.append({'name': name, 'passed': ok, 'detail': str(detail) if detail is not None else None})
    if not ok:
        raise AssertionError(name)

def monic(p, var=x):
    return s.Poly(p, var, domain=s.QQ).monic().as_expr()

def composed(f, g, op):
    if op == 'sum':
        h = g.subs(x, x-y)
    elif op == 'product':
        d = s.degree(g,x)
        h = sum(g.coeff(x,j)*x**j*y**(d-j) for j in range(d+1))
    else:
        raise ValueError(op)
    return monic(s.resultant(f.subs(x,y),h,y))

f=x**3+x+1
g=x**3-x+1
pM=x**9+2*x**7-3*x**6+x**5-x**4+3*x**3-x-1
pA=x**9+6*x**6+3*x**5-15*x**3+24*x**2-4*x+8
for name,p in [('f',f),('g',g),('product target',pM),('sum target',pA)]:
    check('irreducible: '+name,s.Poly(p,x).is_irreducible)
    check('exactly one real root: '+name,s.Poly(p,x).count_roots(-s.oo,s.oo)==1)
check('sum resultant identity',composed(f,g,'sum')==pA)
check('product resultant identity',composed(f,g,'product')==pM)
check('nonmonic sum',composed(2*x-1,3*x-1,'sum')==x-s.Rational(5,6))
check('nonmonic product',composed(2*x-1,3*x-1,'product')==x-s.Rational(1,6))
check('product zero root retained',composed(x,x**2-2,'product')==x**2)
check('composed polynomial need not be minimal',
      composed(x**2-2,x**2-2,'sum')==x**4-8*x**2)
for op,p in [('sum',pA),('product',pM)]:
    h=monic(s.resultant(f.subs(x,y),p.subs(x,z+y if op=='sum' else z*y),y),z)
    factors=s.factor_list(h,z)[1]
    check(op+' residual has second cubic with exponent three',
          any(monic(q,z)==g.subs(x,z) and e==3 for q,e in factors))
    check(op+' residual factor degree/exponent profile',
          sorted((int(s.degree(q,z)),e) for q,e in factors)==[(3,3),(18,1)])

# Third cubic: an exact counterexample to conflating two factors with any number.
c=x**3+x+3
p27=composed(pM,c,'product')
check('three-cubic product degree',s.degree(p27,x)==27)
check('three-cubic product irreducible',s.Poly(p27,x).is_irreducible)
check('three cubics cannot be replaced by two degree <=3 factors',27>3**2)
p8=composed(composed(x**2-2,x**2-3,'sum'),x**2-5,'sum')
check('three square-root sum degree eight',s.degree(p8,x)==8)
check('three square-root sum irreducible',s.Poly(p8,x).is_irreducible)

# Exact finite group enumeration, independent of WL implementation.
S3=list(permutations(range(3)))
G=list(product(S3,S3)); idx={v:i for i,v in enumerate(G)}
def compose(a,b):
    return tuple(a[b[i]] for i in range(3))
table=[[idx[(compose(a[0],b[0]),compose(a[1],b[1]))] for b in G] for a in G]
id_idx=idx[((0,1,2),(0,1,2))]
def closure(seed):
    h=frozenset(set(seed)|{id_idx})
    while True:
        new=h|frozenset(table[i][j] for i in h for j in h)
        if new==h:return h
        h=new
groups=[frozenset({id_idx})]; seen=set(groups)
for h in groups:
    for q in range(len(G)):
        if q not in h:
            k=closure(h|{q})
            if k not in seen:seen.add(k);groups.append(k)
distribution=dict(sorted(Counter(36//len(h) for h in groups).items()))
check('S3 x S3 subgroup count',len(groups)==60)
check('S3 x S3 fixed-field degree distribution',
      distribution=={1:1,2:3,3:6,4:1,6:20,9:9,12:4,18:15,36:1},distribution)

# Matrix model of Q(sqrt(2),sqrt(3)), basis 1,sqrt(2),sqrt(3),sqrt(6).
unit=[s.eye(4)[:,j] for j in range(4)]
quadratic_bases=[s.Matrix.hstack(unit[0],unit[j]) for j in range(1,4)]
target=unit[1]+unit[2]
span=s.Matrix.hstack(*[b[:,j] for b in quadratic_bases for j in range(2)])
check('additive subfield-span criterion in biquadratic field',
      span.rank()==span.row_join(target).rank())
# Multiplication by alpha=sqrt(2)+sqrt(3), columns in the chosen basis.
T=s.Matrix([[0,2,3,0],[1,0,0,3],[1,0,0,2],[0,1,1,0]])
E,F=quadratic_bases[0],quadratic_bases[2]
ns=E.row_join(-T*F).nullspace()
check('binary-product subspace intersection is nonzero',len(ns)>0)
w=E*ns[0][:2,0]
check('intersection witness nonzero',w!=s.zeros(4,1))
check('explicit quadratic product identity',
      s.expand(s.sqrt(2)/2*(2+s.sqrt(6)))==s.sqrt(2)+s.sqrt(3))

# Lightweight source delimiter check. This is NOT a Wolfram parser/type checker.
def balanced_source(text: str) -> bool:
    stack=[]; pairs={']':'[','}':'{',')':'('}; i=0; string=False; comment=0
    while i<len(text):
        if comment:
            if text[i:i+2]=='(*':comment+=1;i+=2;continue
            if text[i:i+2]=='*)':comment-=1;i+=2;continue
        elif string:
            if text[i]=='\\':i+=2;continue
            if text[i]=='"':string=False
        elif text[i:i+2]=='(*':comment=1;i+=2;continue
        elif text[i]=='"':string=True
        elif text[i] in '[{(':stack.append(text[i])
        elif text[i] in ']})':
            if not stack or stack.pop()!=pairs[text[i]]:return False
        i+=1
    return not stack and not string and not comment
base=Path(__file__).resolve().parent
for name in ['RootDecomposition.wl','examples.wl','tests.wlt']:
    check('balanced source delimiters: '+name,balanced_source((base/name).read_text()))

ra=s.CRootOf(f,0); rb=s.CRootOf(g,0)
report={
 'scope':'Independent exact mathematical checks. Wolfram Language tests were NOT executed.',
 'sympy_version':s.__version__,
 'checks_passed':len(checks),
 'checks':checks,
 'numerical_values':{name:str(expr.evalf(40)) for name,expr in
      [('a',ra),('b',rb),('a+b',ra+rb),('a*b',ra*rb)]},
 'real_root_isolating_intervals':{name:str(s.Poly(p,x).intervals(eps=s.Rational(1,10**15)))
      for name,p in [('sum_target',pA),('product_target',pM)]},
 'three_cubic_product_polynomial':str(p27),
 'three_square_root_sum_polynomial':str(p8),
 'subfield_degree_distribution_S3xS3':distribution,
}
out=base/'validation.json'
out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
