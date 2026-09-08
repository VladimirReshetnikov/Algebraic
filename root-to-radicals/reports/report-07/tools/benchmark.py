"""Reproducible, time-bounded benchmark; JSON is a record, not a speed promise."""
from pathlib import Path
import sys,time,json,platform
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from systematic_radicals import solve_with_timeout,verify_tower,exact_equal
x=s.Symbol('x')
CASES=[
 ('question-sextic',x**6+x**4-x**3-x**2-1,1,'practical',30),
 ('question-quintic',5*x**5-25*x**3+25*x+6,4,'practical',30),
 ('nonsolvable-quintic',x**5-x-1,0,'automatic',30),
 ('general-quadratic',x**2-2,1,'complete',30),
 ('general-cubic',x**3-2,0,'complete',30),
 ('general-binomial-quartic',x**4-2,1,'complete',60),
 ('general-cyclotomic-8',x**4+1,0,'complete',30),
 ('general-cyclotomic-5',x**4+x**3+x**2+x+1,0,'complete',30),
 ('notebook-octic-A',x**8+8*x**7+20*x**6+8*x**5-36*x**4-48*x**3-15*x**2+2*x+1,0,'practical',30),
 ('notebook-octic-B',x**8+8*x**7+10*x**6-52*x**5-131*x**4-28*x**3+100*x**2+32*x+16,0,'practical',30),
 ('notebook-octic-C',x**8+8*x**7+16*x**6-4*x**5-68*x**4-28*x**3+49*x**2+14*x+1,0,'practical',30),
 ('automatic-binomial-quintic',x**5-2,0,'automatic',30),
 ('general-binomial-quintic',x**5-2,0,'complete',30),
]
if __name__=='__main__':
    out=Path(sys.argv[1] if len(sys.argv)>1 else 'benchmark.json')
    data={'python':platform.python_version(),'sympy':s.__version__,
          'platform':platform.platform(),'index_convention':'zero-based SymPy',
          'notes':['Each solve is a spawned process; elapsed time includes startup.',
                   'Success means exact internal verification, not a tolerance test.',
                   'Additional full branch verifier run only for small complete cases.'],
          'cases':[]}
    for name,p,i,method,seconds in CASES:
        start=time.perf_counter()
        r=solve_with_timeout(p,i,variable=x,method=method,seconds=seconds)
        duration=time.perf_counter()-start
        row={'name':name,'polynomial':s.sstr(p),'index':i,'requested_method':method,
             'timeout_seconds':seconds,'status':r.status,'method':r.method,
             'elapsed_seconds':round(duration,4),'diagnostics':r.diagnostics}
        if r.expression is not None:
            row['expression']=s.sstr(r.expression)
            row['approximation']=str(s.N(r.expression,20))
            row['operation_count']=int(s.count_ops(r.expression))
        if r.method=='Galois-Kummer':
            row['splitting_degree']=r.certificate['splitting_degree']
            row['field_degree']=r.certificate['field_degree']
            row['cyclotomic_order']=r.certificate['cyclotomic_order']
            row['derived_orders']=r.certificate['derived_orders']
            if r.status=='Success':
                row['tower_primes']=[st['prime'] for st in r.certificate['steps']]
                if s.degree(p,x)<=4:
                    v=time.perf_counter()
                    row['independent_full_verifier']=verify_tower(r,s.CRootOf(p,i))
                    row['verifier_seconds']=round(time.perf_counter()-v,4)
        if 'group_order' in r.certificate:row['group_order']=int(r.certificate['group_order'])
        data['cases'].append(row)
        out.write_text(json.dumps(data,indent=2)+'\n')
        print(name,r.status,r.method,round(duration,2),r.diagnostics,flush=True)
