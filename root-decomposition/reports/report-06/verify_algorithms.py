"""Independent exact checks with SymPy, not an execution of the WL package."""
import sympy as s
from itertools import combinations
from functools import reduce
from operator import mul
import json
from pathlib import Path
x,t = s.symbols('x t')
P=x**9+2*x**7-3*x**6+x**5-x**4+3*x**3-x-1
S=x**9+6*x**6+3*x**5-15*x**3+24*x**2-4*x+8

def run(f,label):
    a=s.CRootOf(f,x,0); n=s.degree(f,x); dom=s.QQ.algebraic_field(a)
    def coord(z):
        v=[s.Rational(c) for c in z.to_list()][::-1]
        return v+[s.S.Zero]*(n-len(v))
    def poly(v): return sum(v[i]*x**i for i in range(n))
    def multiply(u,v):
        p=s.Poly(s.rem(poly(u)*poly(v),f,x),x)
        return [p.nth(i) for i in range(n)]
    def basis(vs):
        R=s.Matrix(vs).rref()[0]
        return [list(R.row(i)) for i in range(R.rows) if any(R.row(i))]
    def closure(gs):
        b=[[1]+[0]*(n-1)]
        while True:
            c=basis(b+[multiply(u,v) for u in b for v in gs])
            if len(c)==len(b): return c
            b=c
    print('Starting',label,flush=True)
    fac=s.Poly(f.subs(x,t),t,domain=dom).factor_list()[1]
    factors=[p for p,e in fac]
    linear=next(p for p in factors if p.degree()==1 and p.rep.to_list()[1]==-dom.unit)
    rest=[p for p in factors if p!=linear]
    fields=[]
    for r in range(len(rest)+1):
        for subset in combinations(rest,r):
            g=reduce(mul,subset,linear)
            k=g.degree()
            if n%k: continue
            gs=[coord(c) for c in g.rep.to_list()[1:]]
            b=closure(gs)
            if len(b)==n//k and b not in fields: fields.append(b)
    fields.sort(key=len)
    print(label,'factor degrees',[p.degree() for p in factors],flush=True)
    print(label,'subfield degrees',list(map(len,fields)),flush=True)
    target=[0,1]+[0]*(n-2)
    sum_data=None
    for d in sorted(set(map(len,fields))):
        chosen=[b for b in fields if len(b)<=d]
        rows=sum(chosen,[]); R=s.Matrix(rows)
        if s.Matrix(rows+[target]).rank()>R.rank(): continue
        sol,params=R.T.gauss_jordan_solve(s.Matrix(target))
        sol=sol.subs({p:0 for p in params})
        terms=[]; cursor=0
        for b in chosen:
            z=(s.Matrix(1,len(b),list(sol)[cursor:cursor+len(b)])*s.Matrix(b))
            cursor+=len(b)
            if any(z): terms.append(list(z))
        assert sum((s.Matrix(v) for v in terms),s.zeros(n,1))==s.Matrix(target)
        print(label,'minimum additive in Q(a)',d,'terms',[str(poly(v)) for v in terms],flush=True)
        sum_data={'max_degree':int(d),'terms_in_a':[str(poly(v)) for v in terms]}
        break
    for i,j in sorted(((i,j) for i in range(len(fields)) for j in range(i,len(fields))),key=lambda ij:max(len(fields[ij[0]]),len(fields[ij[1]]))):
        E,F=fields[i],fields[j]
        scaled=[multiply(target,v) for v in F]
        mat=s.Matrix(E+[[-c for c in v] for v in scaled]).T
        ns=mat.nullspace()
        if not ns: continue
        w=ns[0]
        u=list(s.Matrix(1,len(E),list(w)[:len(E)])*s.Matrix(E))
        v=list(s.Matrix(1,len(F),list(w)[len(E):])*s.Matrix(F))
        assert multiply(target,v)==u and any(v)
        beta=poly(u); gamma=s.rem(s.invert(poly(v),f,x),f,x)
        assert s.rem(beta*gamma-x,f,x)==0
        bp=s.Poly(s.resultant(f,beta-t,x),t).sqf_part().monic().as_expr()
        gp=s.Poly(s.resultant(f,gamma-t,x),t).sqf_part().monic().as_expr()
        print(label,'minimum two-factor in Q(a)',max(len(E),len(F)),flush=True)
        print(' factor1 polynomial in a',beta,flush=True)
        print(' factor2 polynomial in a',gamma,flush=True)
        print(' factor minimal polynomials',bp,gp,flush=True)
        product_data={'max_degree':int(max(len(E),len(F))), 'first_in_a':str(beta), 'second_in_a':str(gamma),'minimal_polynomials':[str(bp),str(gp)]}
        break
    return {'factor_degrees':[p.degree() for p in factors],'subfield_degrees':list(map(len,fields)),'sum':sum_data,'product_pair':product_data}

if __name__=='__main__':
    results={}
    for f,label in [(P,'ProductInput'),(S,'SumInput')]:
        results[label]=run(f,label)
        assert sorted(results[label]['factor_degrees']) == [1, 2, 2, 4]
        assert results[label]['subfield_degrees'] == [1, 3, 3, 9]
    assert results['ProductInput']['sum']['max_degree'] == 9
    assert results['ProductInput']['product_pair']['max_degree'] == 3
    assert results['SumInput']['sum']['max_degree'] == 3
    assert results['SumInput']['product_pair']['max_degree'] == 9
    u,v,z=s.symbols('u v z')
    R=z**6+6*z**4-27*z**3+9*z**2-81*z+4
    r=s.resultant(u**3+u+1,s.resultant(v**3-v+1,z**2-3*u*v*z+3*u**2-3*v**2+4,v),u)
    assert s.expand(r-R**3)==0 and s.Poly(R,z).is_irreducible
    print('matching-sum sextic and irreducibility checked',flush=True)
    print('all exact checks passed',flush=True)
    with Path(__file__).with_name('algorithm_verification.json').open('w') as out:
        json.dump(results,out,indent=2)
