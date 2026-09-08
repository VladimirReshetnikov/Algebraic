"""Run from any working directory: python examples/demo.py."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from radical_roots import radicalize, verify_tower_result
x=s.Symbol('x')
cases=[('Question sextic',x**6+x**4-x**3-x*x-1,1,'auto'),
       ('Question quintic',5*x**5-25*x**3+25*x+6,4,'auto'),
       ('Cyclic quintic via Galois',x**5+x**4-4*x**3-3*x*x+3*x+1,4,'galois'),
       ('Nonsolvable quintic',x**5-x-1,0,'auto')]
for title,f,index,method in cases:
    result=radicalize(f,index,method=method)
    print('\n'+title+': '+result.status)
    if result.status=='Success':
        print(result.to_wolfram())
        if result.method=='Galois-Kummer':
            print('Independent tower check:',verify_tower_result(result,s.Poly(f,x)))
    else:
        print(result.data.get('message',''))
