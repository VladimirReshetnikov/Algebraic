"""Run from archive root: python examples/examples.py"""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from systematic_radicals import solve_with_timeout,verify_tower,exact_equal

if __name__=='__main__':
    x=s.Symbol('x')
    for p,i,method in [
        (x**6+x**4-x**3-x**2-1,1,'practical'),
        (5*x**5-25*x**3+25*x+6,4,'practical'),
        (x**5-x-1,0,'automatic'),
        (x**3-2,0,'complete')]:
        r=solve_with_timeout(p,i,method=method,seconds=60)
        print('\nPolynomial:',p,'; zero-based index:',i)
        print('Status:',r.status,'; method:',r.method)
        if r.status=='Success':
            print('Radicals:',r.expression)
            print('Approximation:',s.N(r.expression,16))
            if r.method=='Galois-Kummer':
                print('Tower primes:',[st['prime'] for st in r.certificate['steps']])
                print('Full certificate verification:',verify_tower(r,s.CRootOf(p,i)))
            else:
                print('Exact selected-root equality:',exact_equal(r.expression,s.CRootOf(p,i)))
        else:
            print(r.diagnostics or r.certificate)
