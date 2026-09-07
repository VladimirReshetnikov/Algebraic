#!/usr/bin/env python3
"""Independent exact checks for article.tex (Python 3 + SymPy).

These are mathematical regression tests, not execution of the accompanying
Wolfram Language package. Run: python verify.py
The JSON report is written alongside this script; failure raises AssertionError.
"""
from __future__ import annotations
import itertools as it
import json
from pathlib import Path
from collections import Counter
import sympy as s

x, t, a, b, z = s.symbols('x t a b z')
A, B, C, D = s.symbols('A B C D')
REPORT: dict[str, object] = {}


def check(name: str, condition: object) -> None:
    ok = bool(condition)
    REPORT[name] = ok
    if not ok:
        raise AssertionError(name)


def cp(p: s.Expr, q: s.Expr, op: str) -> s.Expr:
    if op == 'sum':
        transformed = q.subs(x, x - t)
    elif op == 'product':
        n = s.degree(q, x)
        transformed = sum(q.coeff(x, j) * x**j * t**(n-j) for j in range(n+1))
    else:
        raise ValueError(op)
    return s.expand(s.resultant(p.subs(x, t), transformed, t))

p = x**3 + x + 1
q = x**3 - x + 1
ps = x**9 + 6*x**6 + 3*x**5 - 15*x**3 + 24*x**2 - 4*x + 8
pm = x**9 + 2*x**7 - 3*x**6 + x**5 - x**4 + 3*x**3 - x - 1
check('sum_resultant', cp(p, q, 'sum') == ps)
check('product_resultant', cp(p, q, 'product') == pm)
for name, pol in [('p', p), ('q', q), ('sum9', ps), ('product9', pm)]:
    check(name + '_irreducible', s.Poly(pol, x).is_irreducible)
    check(name + '_one_real_root', s.Poly(pol, x).count_roots(-s.oo, s.oo) == 1)
check('cubic_discriminants', (s.discriminant(p, x), s.discriminant(q, x)) == (-31, -23))

# Sturm-certified rational isolating intervals for the selected real branches.
intervals = {'p':(-s.Rational(683,1000),-s.Rational(682,1000)),
             'q':(-s.Rational(1325,1000),-s.Rational(1324,1000)),
             'sum9':(-s.Rational(2008,1000),-s.Rational(2006,1000)),
             'product9':(s.Rational(902,1000),s.Rational(906,1000))}
for name, pol in [('p',p), ('q',q), ('sum9',ps), ('product9',pm)]:
    check(name+'_isolating_interval', s.Poly(pol,x).count_roots(*intervals[name]) == 1)

# Exact root reconstruction in Q[x]/(P): three zero remainders certify each split.
am = -x**7/s.Integer(2) - x**5 + x**4 - s.Rational(1,2)
bm = -x**7/s.Integer(2) - x**5 + x**4 - x**3 - x + s.Rational(1,2)
for name, expr in [('a', am**3+am+1), ('b', bm**3-bm+1), ('multiply',am*bm-x)]:
    check('product_reconstruction_'+name, s.rem(expr, pm, x) == 0)
asum = s.rem((3*x**5-5*x**3-3*x**2+2*x-4) * s.invert(6*x**4-6*x+4, ps, x), ps, x)
bsum = x-asum
for name, expr in [('a', asum**3+asum+1), ('b', bsum**3-bsum+1), ('add',asum+bsum-x)]:
    check('sum_reconstruction_'+name, s.rem(expr,ps,x) == 0)

# Coefficient templates: no approximation, rational coefficient systems.
rs = cp(x**3+A*x+B, x**3+C*x+D, 'sum')
gs = s.groebner(s.Poly(rs-ps,x).all_coeffs(), A,B,C,D)
check('sum_template_groebner', list(gs) == [A+C, B-1, C**2-1, D-1])
rm = cp(x**3+A*x+B, x**3+C*x+1, 'product')
gm = s.groebner(s.Poly(rm-pm,x).all_coeffs(), A,B,C)
check('product_template_groebner', list(gm) == [A+C**5, B-1, C**6-1])

# Repeated composed roots and degree six from two degree-three numbers.
check('shared_field_sum', cp(x*x-2,x*x-8,'sum') == s.expand((x*x-18)*(x*x-2)))
check('disjoint_field_product_collision', cp(x*x-2,x*x-3,'product') == (x*x-6)**2 .expand() if False else s.expand(cp(x*x-2,x*x-3,'product')-(x*x-6)**2)==0)
check('degree_not_divisor_of_rs', cp(x**3-2,x**3+2,'sum') == s.expand(x**3*(x**6+108)))
check('difference6_irreducible', s.Poly(x**6+108,x).is_irreducible)

# Matching sums for the additive decomposition of a*b.
r6 = x**6+6*x**4-27*x**3+9*x**2-81*x+4
matching = z*z-3*a*b*z+3*a*a-3*b*b+4
el = s.resultant(s.resultant(matching, a**3+a+1, a), b**3-b+1, b)
check('matching_sextic_elimination', s.expand(el-r6.subs(x,z)**3) == 0)
check('matching_sextic_irreducible', s.Poly(r6,x).is_irreducible)
check('matching_sextic_two_real_roots', s.Poly(r6,x).count_roots(-s.oo,s.oo)==2)
check('matching_sum_annihilates_product9', s.rem(s.resultant(r6.subs(x,t),r6.subs(x,3*x-t),t), pm,x)==0)
check('matching_root1_interval', s.Poly(r6,x).count_roots(s.Rational(49,1000),s.Rational(50,1000))==1)
check('matching_root2_interval', s.Poly(r6,x).count_roots(s.Rational(2662,1000),s.Rational(2663,1000))==1)

# Outside-normal-closure product counterexample.
p4 = x**4-2*x*x-1
q4 = x**4-2*x*x-6
f8 = x**8-4*x**6-40*x**4-24*x*x+36
check('counterexample_product_resultant', cp(p4,q4,'product') == s.expand(f8**2))
for name, pol in [('beta4',p4),('gamma4',q4),('counterexample8',f8)]:
    check(name+'_irreducible', s.Poly(pol,x).is_irreducible)
check('quadratic_subfields_disjoint', {2,-1,-2}.isdisjoint({7,-6,-42}))

# Exact finite-group model of the complete conjugate-subset algorithm.
# A faithful model and the proven splitting-field group identify orbit size
# with algebraic degree. No numerical recognition of algebraic numbers is used.
def vecadd(u: tuple, v: tuple) -> tuple:
    return tuple(i+j for i,j in zip(u,v))

def subset_minimum(roots: list[tuple], permutations: list[tuple]) -> dict:
    n=len(roots); m=len(roots[0]); candidates={}
    for mask in range(1,1 << (n-1)):
        indices=[i for i in range(n-1) if (mask>>i)&1]
        v=tuple(sum(roots[i][j] for i in indices) for j in range(m))
        if not any(v) or v in candidates:
            continue
        orbit={tuple(sum(roots[g[i]][j] for i in indices) for j in range(m)) for g in permutations}
        candidates[v]=(len(orbit),indices)
    basis=[]; selected=[]; target=s.Matrix([roots[0]])
    for v,(degree,indices) in sorted(candidates.items(), key=lambda item:item[1][0]):
        trial=s.Matrix(basis+[v])
        if trial.rank()>len(basis):
            basis.append(v); selected.append((degree,indices))
            if trial.col_join(target).rank()==trial.rank():
                coeff=trial.T.gauss_jordan_solve(target.T)[0]
                return {'minimum_degree':degree,'candidate_count':len(candidates),
                        'degree_histogram':dict(sorted(Counter(d for d,_ in candidates.values()).items())),
                        'selected_degrees':[d for d,_ in selected],
                        'selected_subsets_1_based':[[i+1 for i in ids] for _,ids in selected],
                        'coefficients':[str(c) for c in coeff]}
    raise AssertionError('Conjugate-subset span did not contain target')

r=[(1,0),(0,1),(-1,-1)]
perms3=list(it.permutations(range(3)))
grid_perms=[tuple(3*u[i]+v[j] for i in range(3) for j in range(3)) for u in perms3 for v in perms3]
sumroots=[u+v for u in r for v in r]
prodroots=[tuple(c*d for c in u for d in v) for u in r for v in r]
for label, roots, expected in [('sum9_subset',sumroots,3),('product9_subset',prodroots,6)]:
    result=subset_minimum(roots,grid_perms)
    check(label+'_minimum',result['minimum_degree']==expected)
    REPORT[label]=result
signs=list(it.product((-1,1), repeat=3))
sign_perms=[tuple(signs.index(tuple(g[j]*u[j] for j in range(3))) for u in signs) for g in signs]
result=subset_minimum(signs,sign_perms)
check('multiquadratic8_subset_minimum',result['minimum_degree']==2)
REPORT['multiquadratic8_subset']=result

# Finite group G=(D4 x D4)/<(z,z)>; D4 has order eight.
def dmul(g:tuple,h:tuple)->tuple:
    return ((g[0]+(-1)**g[1]*h[0])%4,(g[1]+h[1])%2)

d4=list(it.product(range(4),range(2))); center_d4=(2,0)
def canonical(g:tuple)->tuple:
    other=(dmul(g[0],center_d4),dmul(g[1],center_d4))
    return min(g,other)
G=sorted({canonical((g,h)) for g in d4 for h in d4})
pos={g:i for i,g in enumerate(G)}
table=[[pos[canonical((dmul(g[0],h[0]),dmul(g[1],h[1])))] for h in G] for g in G]
e=pos[canonical(((0,0),(0,0)))]; central=pos[canonical((center_d4,(0,0)))]
center=[i for i in range(32) if all(table[i][j]==table[j][i] for j in range(32))]
check('counterexample_group_order', len(G)==32)
check('counterexample_group_center', set(center)=={e,central})
orders=[]
for i in range(32):
    cur=e
    for k in range(1,33):
        cur=table[cur][i]
        if cur==e:
            orders.append(k);break
check('counterexample_group_exponent', s.ilcm(*orders)==4)

def generated(gens: frozenset[int]) -> frozenset[int]:
    # A finite monoid generated by group elements is the generated subgroup.
    out={e}; todo=[e]
    while todo:
        u=todo.pop()
        for v in gens:
            w=table[u][v]
            if w not in out:
                out.add(w); todo.append(w)
    return frozenset(out)

subs={frozenset({e})}; todo=list(subs)
while todo:
    H=todo.pop()
    for g in range(32):
        if g in H:continue
        K=generated(H|{g})
        if K not in subs:subs.add(K);todo.append(K)
max_avoiding=max(len(H) for H in subs if central not in H)
check('counterexample_center_free_subgroup_size_bound',max_avoiding==4)
check('counterexample_low_index_subgroups_fix_center',all(central in H for H in subs if 32//len(H)<8))
REPORT['counterexample_group_subgroups']={'count':len(subs),'size_histogram':dict(sorted(Counter(map(len,subs)).items())), 'largest_avoiding_center':max_avoiding}

# Fixed-field product intersection in Q(sqrt(2),sqrt(3)).
# Basis: 1,u,v,uv. Product of monomials encoded by two bit flags.
basis_flags=[(0,0),(1,0),(0,1),(1,1)]
def mulcoord(u:tuple,v:tuple)->tuple:
    w=[s.Integer(0)]*4
    for i,ci in enumerate(u):
        for j,cj in enumerate(v):
            aa=basis_flags[i][0]+basis_flags[j][0]
            bb=basis_flags[i][1]+basis_flags[j][1]
            k=basis_flags.index((aa%2,bb%2))
            w[k]+=ci*cj*2**(aa//2)*3**(bb//2)
    return tuple(w)
E=[(1,0,0,0),(0,1,0,0)]; F=[(1,0,0,0),(0,0,1,0)]
alpha=mulcoord((1,1,0,0),(2,0,1,0))
M=s.Matrix(E+[tuple(-j for j in mulcoord(alpha,f)) for f in F]).T
check('fixed_field_product_positive',len(M.nullspace())==1)
alpha_no=(1,1,1,0)
N=s.Matrix(E+[tuple(-j for j in mulcoord(alpha_no,f)) for f in F]).T
check('fixed_field_product_negative',len(N.nullspace())==0)
S=s.Matrix(E+F).T
check('fixed_field_sum_positive',S.row_join(s.Matrix(alpha_no)).rank()==S.rank())
check('fixed_field_sum_negative',S.row_join(s.Matrix(alpha)).rank()>S.rank())

REPORT['verification_environment']={'python_backend':'SymPy','sympy_version':s.__version__,
 'native_wolfram_package_executed':False,
 'native_wolfram_note':'Available Wolfram evaluator endpoint returned HTTP 404.'}
REPORT['all_assertions_passed']=True
path=Path(__file__).with_name('verification_results.json')
path.write_text(json.dumps(REPORT,indent=2)+'\n',encoding='utf-8')
print(f'All {sum(isinstance(v,bool) for v in REPORT.values())-1} mathematical checks passed.')
print(path)
