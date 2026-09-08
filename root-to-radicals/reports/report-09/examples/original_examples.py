"""Run from any directory after installing the pinned SymPy dependency."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as S
from radical_roots import solve_root
x=S.Symbol('x')
examples=[('Original sextic',x**6+x**4-x**3-x**2-1,1),
          ('Original quintic',5*x**5-25*x**3+25*x+6,4)]
for name,poly,index in examples:
    sol=solve_root(poly,index)
    print('\n'+name)
    print('Method:',sol.metadata['method'])
    print('Radicals:',sol.expression())
    print('Approximation:',S.N(sol.expression(),30))
