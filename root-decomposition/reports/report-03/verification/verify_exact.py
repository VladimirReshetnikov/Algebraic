#!/usr/bin/env python3
"""Independent exact checks for the accompanying mathematical article.

Requires Python >= 3.10 and SymPy. This is NOT a Wolfram Language execution
harness. It checks the identities, rational-coordinate constructions, lower-
degree counterexample, and bounded polynomial discovery independently.
Run from any directory: python verification/verify_exact.py
"""
from __future__ import annotations
import itertools
import json
import platform
from pathlib import Path
import sympy as sp

HERE = Path(__file__).resolve().parent
x, z, u, v = sp.symbols('x z u v')
f = x**3 + x + 1
g = x**3 - x + 1
P = z**9 + 2*z**7 - 3*z**6 + z**5 - z**4 + 3*z**3 - z - 1
S = z**9 + 6*z**6 + 3*z**5 - 15*z**3 + 24*z**2 - 4*z + 8
checks: list[dict[str, object]] = []


def check(name: str, condition: object, detail: object = None) -> None:
    ok = bool(condition)
    checks.append({'name': name, 'passed': ok, 'detail': str(detail) if detail is not None else None})
    if not ok:
        raise AssertionError(name)


def zero_mod(expr: sp.Expr, modulus: sp.Expr) -> bool:
    """A rational-function identity in Q[z]/(modulus), with denominator checked."""
    numerator, denominator = sp.fraction(sp.cancel(expr))
    if sp.gcd(denominator, modulus) != 1:
        return False
    return sp.rem(numerator, modulus, z) == 0


check('sum resultant', sp.expand(sp.resultant(f, g.subs(x, z-x), x)) == S)
check('product resultant', sp.expand(sp.resultant(f, z**3-z*x**2+x**3, x)) == P)
check('cubic discriminants', [sp.discriminant(f, x), sp.discriminant(g, x)] == [-31, -23])
for name, poly, variable in [('f', f, x), ('g', g, x), ('P', P, z), ('S', S, z)]:
    check(name + ' irreducible over Q', sp.Poly(poly, variable).is_irreducible)
    real_intervals = sp.polys.polytools.intervals(poly, eps=sp.Rational(1, 10**10))
    check(name + ' has exactly one real root', len(real_intervals) == 1 and real_intervals[0][1] == 1,
          real_intervals)

# Compact rational recovery formulas from the target alone.
delta = z**3 + z - 1
up = -(delta*z + 1)/(delta**2 + z + 1)
vp = up - delta
us = (3*z**5 - 5*z**3 - 3*z**2 + 2*z - 4)/(6*z**4 - 6*z + 4)
vs = z - us
for name, a, b, poly, operation in [('product', up, vp, P, 'product'), ('sum', us, vs, S, 'sum')]:
    check(name + ' recovered u satisfies f', zero_mod(f.subs(x, a), poly))
    check(name + ' recovered v satisfies g', zero_mod(g.subs(x, b), poly))
    expr = a*b-z if operation == 'product' else a+b-z
    check(name + ' recovery identity', zero_mod(expr, poly))

# Exact tensor-product arithmetic. The two cubic splitting fields are disjoint,
# so this quotient is a field of degree nine; no approximate root identification
# is needed for the following coordinate computations.
gb = sp.groebner([u**3+u+1, v**3-v+1], u, v, domain=sp.QQ)
basis = [u**i*v**j for i in range(3) for j in range(3)]


def vec(expr: sp.Expr) -> sp.Matrix:
    p = sp.Poly(gb.reduce(sp.expand(expr))[1], u, v, domain=sp.QQ)
    return sp.Matrix([p.coeff_monomial(b) for b in basis])


coordinates: dict[str, dict[str, str]] = {}
for name, a, expected_det in [('sum', u+v, -1339712), ('product', u*v, -8)]:
    matrix = sp.Matrix.hstack(*(vec(a**k) for k in range(9)))
    check(name + ' primitive-element determinant', matrix.det() == expected_det, matrix.det())
    coordinates[name] = {}
    for label, element in [('u', u), ('v', v)]:
        coefficients = matrix.inv()*vec(element)
        expression = sum(c*z**k for k, c in enumerate(coefficients))
        check(name + ' rational power-basis recovery of ' + label,
              vec(expression.subs(z, a)-element) == sp.zeros(9, 1))
        coordinates[name][label] = str(sp.factor(expression))

# Bounded discovery without supplying the desired cubic pair.
cubics = []
for c in itertools.product(range(-1, 2), repeat=3):
    candidate = x**3 + sum(c[j]*x**j for j in range(3))
    if sp.Poly(candidate, x).is_irreducible:
        cubics.append(candidate)
discoveries: dict[str, object] = {}
for operation, target in [('sum', S), ('product', P)]:
    found = None
    tested = 0
    for i, ff in enumerate(cubics):
        for gg in cubics[i:]:
            tested += 1
            if operation == 'sum':
                h = gg.subs(x, z-x)
            else:
                h = sum(sp.Poly(gg, x).nth(j)*z**j*x**(3-j) for j in range(4))
            if sp.expand(sp.resultant(ff, h, x)) == target:
                found = (str(ff), str(gg))
                break
        if found is not None:
            break
    check(operation + ' discovered in height-one cubic box', found is not None, found)
    discoveries[operation] = {'polynomials': found, 'pairs_tested': tested}

# Biquadratic counterexample: a flat product of three quadratics, but no product
# of two numbers of degree <= 3, even with factors outside the biquadratic field.
a, b = sp.symbols('a b')
gb4 = sp.groebner([a*a-2, b*b-3], a, b, domain=sp.QQ)
basis4 = [1, a, b, a*b]


def vec4(expr: sp.Expr) -> sp.Matrix:
    p = sp.Poly(gb4.reduce(sp.expand(expr))[1], a, b, domain=sp.QQ)
    return sp.Matrix([p.coeff_monomial(mon) for mon in basis4])


def expr4(vect: sp.Matrix) -> sp.Expr:
    return sum(vect[i]*basis4[i] for i in range(4))


w = 7+4*a+3*b+2*a*b
W = z**4-28*z**3+128*z**2-200*z+100
check('three-quadratic identity', vec4(w-(1+a)*(1+b)*(1+a*b)) == sp.zeros(4, 1))
check('counterexample polynomial', vec4(W.subs(z, w)) == sp.zeros(4, 1))
check('counterexample irreducible', sp.Poly(W, z).is_irreducible)
for matrix, det in [([[7, 3], [4, 2]], 2), ([[7, 2], [4, sp.Rational(3, 2)]], sp.Rational(5, 2)),
                    ([[7, 2], [3, sp.Rational(4, 3)]], sp.Rational(10, 3))]:
    check('rank-one obstruction ' + str(det), sp.Matrix(matrix).det() == det)

fields = [sp.Matrix.hstack(vec4(1)), sp.Matrix.hstack(vec4(1), vec4(a)),
          sp.Matrix.hstack(vec4(1), vec4(b)), sp.Matrix.hstack(vec4(1), vec4(a*b)), sp.eye(4)]
for d in [2, 3]:
    intersections = 0
    for t in range(1, d+1):
        eligible = [F for F in fields if t*F.cols <= d]
        for i, F in enumerate(eligible):
            for E in eligible[i:]:
                multiplied = sp.Matrix.hstack(*(vec4(w**t * expr4(E[:, j])) for j in range(E.cols)))
                intersections += len(F.row_join(-multiplied).nullspace())
    check('global two-factor criterion rejects degree bound ' + str(d), intersections == 0)
span = sp.Matrix.hstack(*fields[:-1])
check('quadratic subfields span the biquadratic field', span.rank() == 4)

# The compact product recovery is also reduced to simple degree-seven polynomials.
up_poly = -(z**7+2*z**5-2*z**4+1)/2
vp_poly = -(z**7+2*z**5-2*z**4+2*z**3+2*z-1)/2
check('polynomial and rational product u formulas agree', zero_mod(up-up_poly, P))
check('polynomial and rational product v formulas agree', zero_mod(vp-vp_poly, P))

# A concrete vanishing-linear-coefficient case in the product-descent audit.
alpha_norm = sp.sqrt(sp.sqrt(2)*(1+sp.sqrt(3)))
beta_norm = 2**sp.Rational(1, 4)
gamma_norm = sp.sqrt(1+sp.sqrt(3))
check('zero-linear-coefficient example target degree eight',
      sp.minimal_polynomial(alpha_norm, z) == z**8-16*z**4+16)
check('zero-linear-coefficient example first factor degree four',
      sp.minimal_polynomial(beta_norm, z) == z**4-2)
check('zero-linear-coefficient example second factor degree four',
      sp.minimal_polynomial(gamma_norm, z) == z**4-2*z**2-2)

# Lightweight source integrity check, not a full Wolfram parser or evaluator.
def balanced_wolfram_source(path: Path) -> bool:
    text = path.read_text(encoding='utf-8')
    stack: list[str] = []
    match = {')': '(', ']': '[', '}': '{'}
    i = 0
    in_string = False
    comment_depth = 0
    while i < len(text):
        pair = text[i:i+2]
        if comment_depth:
            if pair == '(*': comment_depth += 1; i += 2; continue
            if pair == '*)': comment_depth -= 1; i += 2; continue
            i += 1; continue
        if in_string:
            if text[i] == '\\': i += 2; continue
            if text[i] == '"': in_string = False
            i += 1; continue
        if pair == '(*': comment_depth = 1; i += 2; continue
        if text[i] == '"': in_string = True; i += 1; continue
        if text[i] in '([{': stack.append(text[i])
        elif text[i] in ')]}':
            if not stack or stack.pop() != match[text[i]]: return False
        i += 1
    return not stack and not in_string and not comment_depth

check('Wolfram package delimiter/string/comment balance', balanced_wolfram_source(HERE.parent/'code'/'RootDecomposition.wl'))
report = {'python': platform.python_version(), 'sympy': sp.__version__,
          'passed': len(checks), 'failed': 0, 'checks': checks,
          'power_basis_coordinates': coordinates, 'bounded_discoveries': discoveries,
          'native_wolfram_tests_executed': False,
          'native_wolfram_status': 'Connector returned HTTP 404; Tests.wlt is supplied, not reported as passed.'}
(HERE/'verification_results.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
lines = [f'Independent exact verification: {len(checks)} checks passed.',
         f'Python {platform.python_version()}; SymPy {sp.__version__}.',
         'This is not a native Wolfram Language test run.', '']
lines += [f"PASS  {r['name']}" + (f"\n      {r['detail']}" if r['detail'] else '') for r in checks]
(HERE/'verification_results.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print('\n'.join(lines))
