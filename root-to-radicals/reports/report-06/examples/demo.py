"""Run from any directory: python /path/to/RootRadicals/examples/demo.py."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from rootradicals import radicalize
x=s.Symbol('x')
cases=[('Original sextic',x**6+x**4-x**3-x**2-1,1,'auto'),
       ('Original quintic',5*x**5-25*x**3+25*x+6,4,'auto'),
       ('Nonsolvable quintic',x**5-x-1,0,'auto'),
       ('Explicit Galois construction',x**3-2,0,'galois')]
for name,f,index,method in cases:
    result=radicalize(s.CRootOf(f,index),method=method)
    print('\n'+name+': '+result.status,flush=True)
    if result.status=='success':
        assert result.verify()
        print(result.program.wolfram())
    else: print(result.message,result.details)
