"""Run: python examples/demo.py (from any working directory)."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from api import root_radicals,selected_expression,verify
x=s.Symbol('x')
for f,k in [(x**6+x**4-x**3-x**2-1,1),(5*x**5-25*x**3+25*x+6,4)]:
    result=root_radicals(f,k)
    print('\nPolynomial:',f,'\nStatus:',result['status'])
    print('Verified:',verify(result))
    print('Radical:',selected_expression(result))
    print('Approximation (diagnostic only):',selected_expression(result).evalf(30))
