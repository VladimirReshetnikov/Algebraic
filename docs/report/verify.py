#!/usr/bin/env python3
"""Exact checks accompanying Radical Denesting: A Unified Research Guide.

This script merges the verification suites of the three unified reports that
were consolidated into this guide. Requires Python 3.10+ and SymPy (recorded
run: SymPy 1.14.0). Run: python verify.py

Polynomial reductions prove the algebraic identities. Sign assertions are
checked separately where an even root is involved; numerical agreement is
never used as the proof. CAS output samples are observations, not claims of
completeness. This script does not implement general radical denesting.
It writes verification_results.json beside itself.
"""
from __future__ import annotations

import json
import platform
from fractions import Fraction
from pathlib import Path

import sympy as sp
from sympy.simplify.simplify import nthroot
from sympy.simplify.sqrtdenest import sqrtdenest

x, u, v, t, s, q, g = sp.symbols('x u v t s q g')
checks: list[str] = []
observations: list[dict[str, str]] = []


def check(name: str, condition: object) -> None:
    if condition is not True and condition != sp.true:
        raise AssertionError(f'{name}: {condition!r}')
    checks.append(name)
    print(f'PASS  {name}')


def zero(name: str, expression: sp.Expr) -> None:
    check(name, sp.expand(expression) == 0)


def remainder_zero(name: str, expression: sp.Expr,
                   relations: list[sp.Expr], variables: tuple[sp.Symbol, ...]) -> None:
    basis = sp.groebner(relations, *variables, domain=sp.QQ)
    check(name, basis.reduce(sp.expand(expression))[1] == 0)


def rational_nth_root(value: sp.Rational, n: int) -> sp.Rational | None:
    """Return the exact real rational nth root, or None. No integer factoring.

    Floats are rejected so that approximate data is never promoted to exact input.
    """
    value = sp.sympify(value)
    if not isinstance(value, sp.Rational):
        raise TypeError('value must be an exact rational number')
    if not isinstance(n, int) or isinstance(n, bool) or n < 2:
        raise ValueError('n must be an integer at least 2')
    if value < 0 and n % 2 == 0:
        return None
    num, den = value.as_numer_denom()
    rn, en = sp.integer_nthroot(abs(int(num)), n)
    rd, ed = sp.integer_nthroot(int(den), n)
    return sp.Rational((-rn if num < 0 else rn), rd) if en and ed else None


def rational_cuberoot(value: sp.Rational) -> sp.Rational | None:
    return rational_nth_root(value, 3)


def denest_cubic_in_quadratic(a: sp.Rational, b: sp.Rational,
                              p: sp.Rational) -> tuple[sp.Rational, sp.Rational] | None:
    """Decide cbrt(a+b*sqrt(p)) = A+B*sqrt(p) for rational a,b,p (real cube root).

    Enforces the nondegenerate domain of the theorem: p>0 nonsquare, b!=0.
    None means no root in the specified quadratic field, not that no other
    unnested radical representation exists. Rational roots are found by exact
    polynomial factorization over Q; divisors of integers are never enumerated.
    """
    a, b, p = map(sp.Rational, (a, b, p))
    if p <= 0 or b == 0 or sp.sqrt(p).is_Rational:
        raise ValueError('Require p>0 nonsquare and b!=0.')
    norm = a*a - b*b*p
    tr_norm = rational_cuberoot(norm)
    if tr_norm is None:
        return None
    poly = sp.Poly(x**3 - 3*tr_norm*x - 2*a, x, domain=sp.QQ)
    for factor, _mult in poly.factor_list()[1]:
        if factor.degree() == 1:
            root = -factor.nth(0)/factor.nth(1)
            A = root/2
            B = b/(root*root - tr_norm)
            # Complete exact certificate in the basis 1, sqrt(p).
            assert A**3 + 3*A*B**2*p == a
            assert 3*A**2*B + B**3*p == b
            return sp.Rational(A), sp.Rational(B)
    return None


print('Python:', platform.python_version())
print('SymPy:', sp.__version__)
print('All arithmetic below is exact.\n')

# ------------------------------------------------------------------ square roots
zero('direct example (sqrt(2)+sqrt(3))^2',
     (sp.sqrt(2)+sp.sqrt(3))**2 - (5+2*sp.sqrt(6)))
zero('indirect example [2^(1/4)*(1+sqrt(2))]^2',
     (2**sp.Rational(1, 4)*(1+sp.sqrt(2)))**2 - (4+3*sp.sqrt(2)))
check('sqrt(2+sqrt(2)): direct norm not a rational square',
      not sp.sqrt(2).is_Rational)
check('sqrt(2+sqrt(2)): indirect norm negative', -sp.Integer(2)*2 < 0)
# A wrong branch passes a squared-identity test: the sign must be checked.
zero('sign example: (1-sqrt(2))^2 = 3-2*sqrt(2)', (1-sp.sqrt(2))**2-(3-2*sp.sqrt(2)))
check('sign example: 1-sqrt(2) is negative, so sqrt(3-2*sqrt(2)) = sqrt(2)-1', 1-sp.sqrt(2) < 0)
# Multiquadratic and cancellation identities.
zero('multiquadratic identity: (5+4*sqrt(2)+3*sqrt(5)+sqrt(10))^2',
     sp.expand((5+4*sp.sqrt(2)+3*sp.sqrt(5)+sp.sqrt(10))**2) - (112+70*sp.sqrt(2)+(46+34*sp.sqrt(2))*sp.sqrt(5)))
zero('cancellation: sqrt(3+3*sqrt(3)) = sqrt(3)*sqrt(1+sqrt(3)) (squares)',
     (sp.sqrt(3)*sp.sqrt(1+sp.sqrt(3)))**2 - (3+3*sp.sqrt(3)))
zero('cancellation: sqrt(10+6*sqrt(3)) = (1+sqrt(3))*sqrt(1+sqrt(3)) (squares)',
     sp.expand(((1+sp.sqrt(3))*sp.sqrt(1+sp.sqrt(3)))**2) - (10+6*sp.sqrt(3)))
# (sqrt(5)+sqrt(11-2*sqrt(29)))^2 = 16-2*sqrt(29)+2*sqrt(5)*sqrt(11-2*sqrt(29)); the cross
# term equals sqrt(55-10*sqrt(29)) because both are positive with the same square.
zero('partial denesting: cross term squared, 5*(11-2*sqrt(29)) = 55-10*sqrt(29)',
     sp.expand((sp.sqrt(5)*sp.sqrt(11-2*sp.sqrt(29)))**2) - (55-10*sp.sqrt(29)))
zero('partial denesting: remaining terms 5+11-2*sqrt(29) = 16-2*sqrt(29)',
     sp.expand((sp.sqrt(5))**2+(sp.sqrt(11-2*sp.sqrt(29)))**2) - (16-2*sp.sqrt(29)))
check('partial denesting: 11-2*sqrt(29) > 0', sp.Integer(121) > 116)

# ------------------------------------------------------------------ Ramanujan identities
remainder_zero('Ramanujan cubic: (1-t+t^2)^3=9(t-1)',
               (1-t+t*t)**3 - 9*(t-1), [t**3-2], (t,))
zero('Ramanujan cubic: positive quadratic decomposition',
     1-t+t*t - ((t-sp.Rational(1, 2))**2+sp.Rational(3, 4)))
# u=cbrt(2), v=cbrt(7). Candidate=(u*v^2-u^2*v-1)/3.
remainder_zero('sqrt(cbrt(28)-3): square identity',
               (u*v*v-u*u*v-1)**2 - 9*(u*u*v-3), [u**3-2, v**3-7], (u, v))
check('sqrt(cbrt(28)-3): candidate sign by rational bounds',
      sp.Rational(9, 2)**3 < 98 and sp.Rational(31, 10)**3 > 28
      and sp.Rational(9, 2)-sp.Rational(31, 10)-1 > 0)
# u=cbrt(2), v=cbrt(5); cbrt(20)=u^2*v.
remainder_zero('sqrt(cbrt(5)-cbrt(4)): square identity',
               (u+u*u*v-v*v)**2 - 9*(v-u*u), [u**3-2, v**3-5], (u, v))
check('sqrt(cbrt(5)-cbrt(4)): candidate positive by rational bounds',
      sp.Rational(5, 4)**3 < 2 and sp.Rational(27, 10)**3 < 20
      and sp.Rational(3)**3 > 25 and sp.Rational(5, 4)+sp.Rational(27, 10)-3 > 0)
# Honsbeek's quartic condition: the algebraic certificate behind the formula.
zero('Honsbeek quartic identity',
     (-s*s/2+s*u+u*u)**2-(u**3-s**3)*(1+u)-(s**4+4*s**3+8*s*u**3-4*u**3)/4)
rem = sp.rem(sp.expand((-t*t/2+t*u+u*u)**2-(g-t**3)*(1+u)), u**3-g, u)
zero('Honsbeek certificate as a polynomial identity in the ratio g',
     rem-(t**4+4*t**3+8*g*t-4*g)/4)
check('Honsbeek (-4,5) ratio has rational quartic root 1',
      (s**4+4*s**3+8*q*s-4*q).subs({q: sp.Rational(-5, 4), s: 1}) == 0)
check('Honsbeek swapped (5,-4) ratio has rational quartic root -2',
      (s**4+4*s**3+8*q*s-4*q).subs({q: sp.Rational(-4, 5), s: -2}) == 0)
check('Honsbeek (28,-27) ratio has rational quartic root -3',
      (s**4+4*s**3+8*q*s-4*q).subs({q: sp.Rational(-27, 28), s: -3}) == 0)
# Fourth-root identity, t=5^(1/4); 1<t<3/2 since 1<5<(3/2)^4.
remainder_zero('Ramanujan fourth-root identity: cross multiplication',
               (t+1)**4*(3-2*t)-(t-1)**4*(3+2*t), [t**4-5], (t,))
remainder_zero('Ramanujan fourth-root identity: rationalized form',
               2*(t+1)-(3+t+t*t+t**3)*(t-1), [t**4-5], (t,))
check('Ramanujan fourth-root identity: denominator positive', 1 < 5 < sp.Rational(3, 2)**4)
# Sixth-root identity with u=cbrt(5/3), v=cbrt(2/3), so cbrt(20)=3*u*v^2.
remainder_zero('Ramanujan sixth-root identity',
               (u-v)**6-(21*u*v*v-19),
               [u**3-sp.Rational(5, 3), v**3-sp.Rational(2, 3)], (u, v))
check('Ramanujan sixth-root identity: positive candidate', sp.Rational(5, 3) > sp.Rational(2, 3) > 0)
remainder_zero('Ramanujan sixth-root identity (integral form): (u-2)^6=144(7u-19), u=cbrt(20)',
               (u-2)**6-144*(7*u-19), [u**3-20], (u,))
# Fifth-root real-branch example and Cardan-Dickson data.
zero('real fifth root of 41-29*sqrt(2)', (1-sp.sqrt(2))**5-(41-29*sp.sqrt(2)))
check('real fifth-root candidate is negative', sp.sqrt(2) > 1)
check('Cardan-Dickson D_5(2,-1) = 82 = 2*41',
      (t**5-5*q*t**3+5*q*q*t).subs({t: 2, q: -1}) == 82)
# Cube roots of the golden ratio and its inverse.
phi = (1+sp.sqrt(5))/2
zero('phi^3 = 2+sqrt(5)', sp.expand(phi**3)-(2+sp.sqrt(5)))
zero('(phi-1)^3 = sqrt(5)-2', sp.expand((phi-1)**3)-(sp.sqrt(5)-2))

# ------------------------------------------------------------------ cubic in a quadratic field
zero('trace-norm certificate polynomial',
     (x**3-3*t*x)**2-4*t**3-(x*x-t)**2*(x*x-4*t))
check('restricted cubic denesting 7+5*sqrt(2)', denest_cubic_in_quadratic(7, 5, 2) == (1, 1))
check('restricted cubic denesting 85+62*sqrt(7)', denest_cubic_in_quadratic(85, 62, 7) == (1, 2))
check('restricted cubic denesting 90+34*sqrt(7)', denest_cubic_in_quadratic(90, 34, 7) == (3, 1))
check('restricted cubic denesting -7-5*sqrt(2)', denest_cubic_in_quadratic(-7, -5, 2) == (-1, -1))
check('cube norm alone is insufficient (1+sqrt(2))',
      rational_cuberoot(sp.Rational(-1)) == -1 and denest_cubic_in_quadratic(1, 1, 2) is None)
check('cube norm alone is insufficient (3+sqrt(10))',
      rational_cuberoot(sp.Rational(-1)) == -1 and denest_cubic_in_quadratic(3, 1, 10) is None)
check('rational root helper: (-8/27)^(1/3) = -2/3', rational_nth_root(sp.Rational(-8, 27), 3) == sp.Rational(-2, 3))
check('rational root helper: sqrt(2) not rational', rational_nth_root(sp.Rational(2), 2) is None)
check('rational root helper: 0', rational_nth_root(sp.Rational(0), 3) == 0)
count = 0
for p in (2, 3, 5, 6, 7):
    for A in range(-3, 4):
        for B in (-3, -2, -1, 1, 2, 3):
            a = A**3 + 3*A*B*B*p
            b = 3*A*A*B + B**3*p
            assert denest_cubic_in_quadratic(a, b, p) == (A, B), (a, b, p)
            count += 1
check(f'constructed quadratic-field examples recovered exactly: {count} cases', count == 210)

# ------------------------------------------------------------------ minimal polynomials
check('minimal polynomial of sqrt(2)+sqrt(3)', sp.minpoly(sp.sqrt(2)+sp.sqrt(3), x) == x**4-10*x*x+1)
check('that quartic is irreducible over Q', sp.Poly(x**4-10*x*x+1, x).is_irreducible)
check('different conjugate has same minimal polynomial', sp.minpoly(sp.sqrt(3)-sp.sqrt(2), x) == x**4-10*x*x+1)

# ------------------------------------------------------------------ observed SymPy outputs
print('\nObserved SymPy outputs (reproducibility checks, not completeness claims):')
sq = sp.sqrt
for name, expression, expected in [
    ('direct square roots', sq(5+2*sq(6)), sq(2)+sq(3)),
    ('principal-root sign', sq(3-2*sq(2)), sq(2)-1),
    ('fourth roots', sq(4+3*sq(2)), 2**sp.Rational(1, 4)*(sq(2)+1)),
    ('depth three to two', sq(16-2*sq(29)+2*sq(55-10*sq(29))), sq(5)+sq(11-2*sq(29))),
    ('multiquadratic input', sq(112+70*sq(2)+(46+34*sq(2))*sq(5)), 5+4*sq(2)+3*sq(5)+sq(10)),
    ('cancellation across terms', sq(1+sq(3))+sq(3+3*sq(3))-sq(10+6*sq(3)), sp.Integer(0)),
]:
    out = sqrtdenest(expression)
    check(f'sqrtdenest agrees with the certified value: {name}', sp.simplify(out-expected) == 0)
    observations.append({'test': name, 'function': 'sqrtdenest', 'input': str(expression), 'output': str(out)})
    print(' sqrtdenest:', expression, '->', out)
expression = sq(2+sq(2))
out = sqrtdenest(expression)
check('sqrtdenest leaves sqrt(2+sqrt(2)) unchanged (observation, not a proof)', out == expression)
observations.append({'test': 'unchanged example', 'function': 'sqrtdenest', 'input': str(expression), 'output': str(out)})
for name, radicand, n, expected in [
    ('cubic in quadratic 1', 7+5*sq(2), 3, 1+sq(2)),
    ('cubic in quadratic 2', 85+62*sq(7), 3, 1+2*sq(7)),
    ('cubic in quadratic 3', 90+34*sq(7), 3, 3+sq(7)),
    ('negative real fifth root', 41-29*sq(2), 5, 1-sq(2)),
]:
    out = nthroot(radicand, n)
    check(f'nthroot agrees with the certified value: {name}',
          sp.expand(out**n-radicand) == 0 and sp.simplify(out-expected) == 0)
    observations.append({'test': name, 'function': 'nthroot', 'input': f'({radicand}, {n})', 'output': str(out)})
    print(' nthroot:', (radicand, n), '->', out)

print(f'\n{len(checks)} exact checks passed.')
result = {'python': platform.python_version(), 'sympy': sp.__version__,
          'status': 'all exact assertions passed', 'checks': len(checks),
          'observations': observations}
Path(__file__).with_name('verification_results.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
