import sys,time,json,traceback
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from rootradicals import radicalize
from rootradicals.solver import certify_expression,prime_degree_obstruction
x=s.Symbol('x')
cases=[('sextic',x**6+x**4-x**3-x**2-1,range(6),'auto'),('quintic',5*x**5-25*x**3+25*x+6,range(5),'auto'),('binomial', (x-3)**7+2,range(7),'auto'),('cyclotomic11',s.cyclotomic_poly(11,x),[0,9],'auto'),('D4',x**4-2,[0,2,3],'galois'),('cyclic3',x**3-3*x+1,[0,2],'galois'),('cube',x**3-2,[1,2],'galois')]
for name,f,inds,method in cases:
 for i in inds:
  t=time.time();print('START',name,i,flush=True)
  try:
   r=radicalize(s.CRootOf(f,i),method=method)
   print(name,i,r.status,'replay',r.verify(),'independent',certify_expression(r.expression,r.target,r.polynomial) if r.status=='success' else None,'seconds',time.time()-t,flush=True)
  except Exception:traceback.print_exc()
print('OBSTRUCTIONS',flush=True)
for f in [x**5-x-1,x**7-x-1,x**7-x**6-12*x**5+7*x**4+28*x**3-14*x**2-9*x-1]:
 print(f,prime_degree_obstruction(s.Poly(f,x,domain=s.QQ)),flush=True)
