import pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from radicalroots import to_radicals
x=s.Symbol('x')
# These are real roots: the explicit mapping is justified for these examples.
# Do not map complex WL root indices to SymPy by blindly subtracting one.
for f,i in [(x**6+x**4-x**3-x**2-1,1),(5*x**5-25*x**3+25*x+6,4)]:
    r=to_radicals(f,i,method='fast')
    print(r.status,r.method,r.verified)
    print(r.expression)
    if r.expression is not None: print(s.N(r.expression,25))
