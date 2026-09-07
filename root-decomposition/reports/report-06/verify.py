"""Independent exact SymPy checks; no Wolfram Language kernel is called.
Run from any directory: python path/to/verify.py
All assertions are exact. Decimal roots are printed only for orientation.
"""
import sympy as s


def main():
    x, t = s.symbols('x t')
    p = t**3 + t + 1
    q = t**3 - t + 1
    product_polynomial = x**9 + 2*x**7 - 3*x**6 + x**5 - x**4 + 3*x**3 - x - 1
    sum_polynomial = x**9 + 6*x**6 + 3*x**5 - 15*x**3 + 24*x**2 - 4*x + 8
    product_resultant = s.resultant(p, x**3 - x*t**2 + t**3, t)
    sum_resultant = s.resultant(p, q.subs(t, x-t), t)
    assert s.expand(product_resultant - product_polynomial) == 0
    assert s.expand(sum_resultant - sum_polynomial) == 0
    assert s.discriminant(p, t) == -31
    assert s.discriminant(q, t) == -23
    print('SymPy version:', s.__version__)
    print('Both requested resultant identities: PASSED')
    print('Cubic discriminants: -31, -23')
    for name, f in [('Product', product_polynomial), ('Sum', sum_polynomial)]:
        fp = s.Poly(f, x)
        assert fp.is_irreducible
        real_count = fp.count_roots(-s.oo, s.oo)
        assert real_count == 1
        print(f'{name} input: degree {fp.degree()}, irreducible, {real_count} real root')
        print(f'  Real root (orientation only): {s.CRootOf(f, x, 0).evalf(20)}')

    sextic = x**6 + 6*x**4 - 27*x**3 + 9*x**2 - 81*x + 4
    assert s.Poly(sextic, x).is_irreducible
    assert s.Poly(sextic, x).count_roots(-s.oo, s.oo) == 2
    print('Matching-sum sextic: irreducible, exactly two real roots')
    for i in range(2):
        print('  Real root (orientation only):', s.CRootOf(sextic, x, i).evalf(20))

    degree_six_example = s.I*s.sqrt(3)*s.real_root(2, 3)
    assert s.expand(s.minpoly(degree_six_example, x) - (x**6+108)) == 0
    print('Counterexample to degree-product divisibility: minpoly x^6 + 108')
    gamma = (1+s.sqrt(2))*(1+s.sqrt(3))*(1+s.sqrt(5))
    gamma_poly = s.minpoly(gamma, x)
    assert s.degree(gamma_poly, x) == 8
    print('Three quadratic factors example: degree 8')
    print('  Minimal polynomial:', gamma_poly)
    print('All exact elementary checks PASSED')


if __name__ == '__main__':
    main()
