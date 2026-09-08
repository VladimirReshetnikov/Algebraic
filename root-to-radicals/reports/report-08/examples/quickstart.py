from pathlib import Path
import sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"python"))
import sympy as s
from systematic_radicals import solve_root,solve_polynomial,verify_certificate,NotSolvable
x=s.symbols("x")
f=x**6+x**4-x**3-x*x-1
# Python uses zero-based CRootOf ordering. This is the positive real root.
a=solve_root(f,1,x)
print("Sextic positive root:",a)
print("Numerical check:",s.N(a,30))

# Force the general field/group construction, rather than the cubic formula.
tower=solve_polynomial(x**3-2,x,method="galois",verify=True)
print("Assignments:",tower.assignments)
print("Outputs in those assignments:",tower.outputs)
print("Independent certificate:",verify_certificate(tower.certificate,x**3-2))
print("Diagnostics:",tower.diagnostics)

try:
    solve_polynomial(x**5-x-1,x)
except NotSolvable as e:
    print("Nonsolvable:",e.details)
