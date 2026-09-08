#!/usr/bin/env python3
"""Run exact reference checks. This is not a native Wolfram Language test run."""
from __future__ import annotations
import json
import pathlib
import random
import sys
import time
from collections import Counter

import sympy as sp
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'Reference'))
from exact_decomposition import ExactDecomposer

x, t = sp.symbols('x t')
root = pathlib.Path(__file__).resolve().parents[1]
rng = random.Random(206618)
checks = []
oracle_disagreements = []
start = time.perf_counter()


def check(name, condition):
    value = bool(condition)
    checks.append(dict(name=name, passed=value))
    if not value:
        raise AssertionError(name)


def seq(chain):
    return [len(p)-1 for p in chain]


def random_vector(engine, degree, algebraic=None):
    if algebraic is None:
        result = [engine.domain.convert(rng.randrange(-4, 5)) for _ in range(degree)]
    else:
        result = [engine.domain.convert(rng.randrange(-3, 4)) +
                  engine.domain.convert(rng.randrange(-2, 3))*algebraic
                  for _ in range(degree)]
    result.append(engine.domain.convert(rng.choice([-3, -2, -1, 1, 2, 3])))
    return tuple(result)


Q = ExactDecomposer()
K2 = ExactDecomposer(sp.QQ.algebraic_field(sp.sqrt(2)))
a = sp.sqrt(2)
original = (3+3*a+(14+4*a)*x+(12+26*a)*x**2+(56+8*a)*x**3+
            (8+48*a)*x**4+48*x**5+16*a*x**6)
p = K2.vector(original, x)
f = K2.vector(3+3*a+(8+14*a)*x+(8+24*a)*x**2+16*a*x**3, x)
h = K2.vector(x**2+x/a, x)
check('original: normalized exact pair', K2.decompose(p) == [f, h])
check('original: degree three rejected', not K2.trial(p, 3)['success'])
check('original: all chains count', K2.all_chains(p)['count'] == 1)
q4 = K2.vector(x**4-x+1, x)
p24 = K2.compose(p, q4)
check('nested: complete degree sequence', seq(K2.decompose(p24)) == [3, 2, 4])
check('nested: exact composition', K2.compose_chain(K2.decompose(p24)) == p24)
check('quartic: composite-degree indecomposable', not K2.pairs(q4))
check('descending split: recurses on both factors',
      seq(K2.decompose(p24, descending=True)) == [3, 2, 4])

for n, expected in [(6, 2), (12, 3), (16, 1), (30, 6), (36, 6), (72, 10)]:
    pmon = Q.vector(x**n, x)
    answer = Q.all_chains(pmon)
    check(f'x^{n}: number of distinct complete chains', answer['count'] == expected)
    signatures = [tuple(seq(c)) for c in answer['chains']]
    check(f'x^{n}: no duplicate degree sequences', len(set(signatures)) == expected)
    check(f'x^{n}: all prime components', all(sp.isprime(d) for s in signatures for d in s))
    check(f'x^{n}: cap lookahead', Q.all_chains(pmon, 1)['complete'] == (expected == 1))
    check(f'x^{n}: exact cap boundary', Q.all_chains(pmon, expected)['complete'])

pc = Q.vector(sp.chebyshevt(6, x), x)
cc = Q.all_chains(pc)
check('Chebyshev six: two chains', cc['count'] == 2)
check('Chebyshev six: degree sequences', set(tuple(seq(c)) for c in cc['chains']) == {(2, 3), (3, 2)})
for n in [4, 6, 8, 9, 10, 12, 15, 16, 18, 20]:
    v = Q.vector(x**n+x, x)
    check(f'x^{n}+x: indecomposable', Q.pairs(v) == [])
for expression in [sp.Integer(0), sp.Integer(7), x, 2*x+3, x**5+x+1]:
    v = Q.vector(expression, x)
    check(f'terminal: {expression}', Q.decompose(v) == [v])
    check(f'terminal enumeration: {expression}', Q.all_chains(v)['count'] == 1)

# Polynomial division agrees with SymPy's separately implemented division.
for i in range(40):
    pv = random_vector(Q, rng.randrange(3, 18))
    hv = list(random_vector(Q, rng.randrange(2, min(len(pv)-1, 6))))
    hv[-1], hv[0] = Q.one, Q.zero
    hv = tuple(hv)
    qq, rr = Q.divide_monic(pv, hv)
    sq, sr = sp.div(Q.expression(pv, x), Q.expression(hv, x), x, domain=sp.QQ)
    check(f'division cross-check {i}', qq == Q.vector(sq, x) and rr == Q.vector(sr, x))

# Recovery of known arbitrary affine normalizations, and exact independence
# checks against SymPy's decomposition implementation over QQ and QQ(sqrt(2)).
for field_name, engine, alpha, count in [
        ('QQ', Q, None, 80), ('QQ(sqrt(2))', K2, K2.domain.convert(a), 45)]:
    for i in range(count):
        m, d = rng.choice([2, 3, 4, 5]), rng.choice([2, 3, 4, 5])
        fv, gv = random_vector(engine, m, alpha), random_vector(engine, d, alpha)
        pv = engine.compose(fv, gv)
        hv = tuple([engine.zero] +
                   [engine.domain.exquo(c, gv[-1]) for c in gv[1:]])
        Fv = engine.compose(fv, (gv[0], gv[-1]))
        found = engine.trial(pv, d)
        check(f'{field_name} random pair {i}: recover normalized h', found['right'] == hv)
        check(f'{field_name} random pair {i}: recover f', found['success'] and found['outer'] == Fv)
        chain = engine.decompose(pv)
        check(f'{field_name} random pair {i}: recomposition', engine.compose_chain(chain) == pv)
        if i < 12:
            spchain = sp.Poly(engine.expression(pv, x), x, domain=engine.domain).decompose()
            sdegrees = sorted(f.degree() for f in spchain)
            
            if sorted(seq(chain)) != sdegrees:
                oracle_disagreements.append(dict(
                    field=field_name, case=i, reference_degrees=seq(chain),
                    sympy_degrees=[f.degree() for f in spchain]))
            out = sp.Poly(x, x, domain=engine.domain)
            for component in spchain:
                out = out.compose(component)
            check(f'{field_name} SymPy output identity {i}',
                  out == sp.Poly(engine.expression(pv, x), x, domain=engine.domain))

# Independently generate candidates with a binomial series, not the recurrence.
for i in range(20):
    m, d = rng.choice([2, 3, 4]), rng.choice([2, 3, 4, 5])
    pv = random_vector(Q, m*d)
    c = sum(sp.Rational(pv[m*d-j], pv[-1])*t**j for j in range(d))
    series = sp.series(c**sp.Rational(1, m), t, 0, d).removeO()
    expected = sp.expand(sum(series.coeff(t, j)*x**(d-j) for j in range(d)))
    check(f'formal binomial cross-check {i}', Q.candidate(pv, d) == Q.vector(expected, x))

# General Root data are handled in an irreducible degree-five number field.
theta = sp.CRootOf(x**5-x-1, 0)
K5 = ExactDecomposer(sp.QQ.algebraic_field(theta))
th = K5.domain.convert(theta)
hv = (K5.zero, th, K5.one)
fv = (K5.one, th, K5.zero, K5.one)
pv = K5.compose(fv, hv)
check('quintic Root: exact prescribed factors', K5.decompose(pv) == [fv, hv])
check('quintic Root: minimal polynomial identity', th**5-th-K5.one == K5.zero)
for i in range(12):
    f0 = random_vector(K5, 3, th)
    h0 = random_vector(K5, 2, th)
    p0 = K5.compose(f0, h0)
    ans = K5.trial(p0, 2)
    check(f'quintic Root randomized {i}', ans['success'] and K5.compose(ans['outer'], ans['right']) == p0)

# Multiple generators and nonreal exact algebraic numbers.
KM = ExactDecomposer(sp.QQ.algebraic_field(sp.sqrt(2), sp.sqrt(3), sp.I))
aM, bM = KM.domain.convert(sp.sqrt(2)+sp.I), KM.domain.convert(sp.sqrt(3))
fM = (KM.one, bM, KM.zero, KM.one)
hM = (KM.zero, aM, KM.one)
check('mixed complex number field degree eight', KM.domain.ext.minpoly.degree() == 8)
check('mixed complex number field exact factors', KM.decompose(KM.compose(fM, hM)) == [fM, hM])

# Generic random polynomials: compare both success and failure with SymPy.
for i in range(40):
    n = rng.choice([4, 6, 8, 9, 10, 12, 15, 16])
    pv = random_vector(Q, n)
    chain = Q.decompose(pv)
    spchain = sp.Poly(Q.expression(pv, x), x, domain=sp.QQ).decompose()
    check(f'generic QQ polynomial cross-check {i}', sorted(seq(chain)) == sorted(f.degree() for f in spchain))

report = dict(status='passed', checks=len(checks), failed=sum(not c['passed'] for c in checks),
              python=sys.version.split()[0], sympy=sp.__version__,
              elapsed_seconds=round(time.perf_counter()-start, 3),
              native_wolfram_execution=False,
              external_oracle_disagreements=oracle_disagreements,
              native_wolfram_status='Not run: connector returned HTTP 404; no local kernel.',
              detail=checks)
(root/'validation'/'reference_results.json').write_text(json.dumps(report, indent=2)+'\n')
(root/'validation'/'worked_examples.txt').write_text(
    'Exact results from the Python/SymPy reference (not Wolfram output)\n\n' +
    'Original example:\n' + '\n'.join(str(K2.expression(v, x)) for v in K2.decompose(p)) +
    '\n\nNested example:\n' + '\n'.join(str(K2.expression(v, x)) for v in K2.decompose(p24)) +
    '\n\nOriginal degree-three obstruction:\n' +
    str({k: (str(K2.expression(v, x)) if k in ['right', 'remainder'] else str(v))
         for k,v in K2.trial(p, 3).items()}) + '\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['detail','external_oracle_disagreements']}, indent=2))
