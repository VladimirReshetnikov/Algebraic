#!/usr/bin/env python3
"""Independent exact number-field verification of the supplied mathematics.

Requires Python >=3.10 and SymPy >=1.12. No floating-point arithmetic is
used. This is NOT execution of the Wolfram Language package. See report.json.
SPDX-License-Identifier: MIT
"""
from __future__ import annotations
import argparse
import itertools
import json
import math
import random
import time
from pathlib import Path
from typing import Any
import sympy as sp
from sympy import QQ

X = sp.Symbol('x')

class ExactPolynomialEngine:
    def __init__(self, field: Any):
        self.K = field
        self.zero, self.one = field.zero, field.one

    def trim(self, c):
        c = list(c)
        while len(c) > 1 and c[-1] == self.zero:
            c.pop()
        return c or [self.zero]

    def from_expr(self, expression):
        p = sp.Poly(expression, X, domain=self.K)
        return self.trim(list(reversed(p.rep.to_list())))

    def to_expr(self, c):
        return sp.Add(*(self.K.to_sympy(a)*X**i for i, a in enumerate(c)))

    def add(self, a, b):
        c = [self.zero]*max(len(a), len(b))
        for i, v in enumerate(a): c[i] += v
        for i, v in enumerate(b): c[i] += v
        return self.trim(c)

    def sub(self, a, b):
        return self.add(a, [-v for v in b])

    def mul(self, a, b):
        c = [self.zero]*(len(a)+len(b)-1)
        for i, v in enumerate(a):
            for j, w in enumerate(b):
                c[i+j] += v*w
        return self.trim(c)

    def power(self, a, n):
        r = [self.one]
        for _ in range(n): r = self.mul(r, a)
        return r

    def compose(self, f, h):
        c = [self.zero]
        for a in reversed(f): c = self.add(self.mul(c, h), [a])
        return c

    def divisors(self, n):
        return [d for d in sp.divisors(n) if 1 < d < n] if n >= 4 else []

    def candidate_recurrence(self, c, d):
        n = len(c)-1
        if d not in self.divisors(n): raise ValueError('Invalid right degree')
        m = n//d
        s = [c[n-k]/c[n] for k in range(d)]
        u = [self.one]+[self.zero]*(d-1)
        for k in range(1, d):
            u[k] = sum((self.K.convert((m+1)*i-m*k)*s[i]*u[k-i]
                        for i in range(1, k+1)), self.zero)/self.K.convert(m*k)
        return [self.zero]+list(reversed(u))

    def candidate_binomial(self, c, d):
        """Independent construction: finite binomial sum, not the recurrence."""
        n, m = len(c)-1, (len(c)-1)//d
        w = [self.zero]+[c[n-k]/c[n] for k in range(1, d)]
        u = [self.zero]*d
        power = [self.one]
        for j in range(d):
            scalar = self.K.from_sympy(sp.binomial(sp.Rational(1, m), j))
            for i, v in enumerate(power): u[i] += scalar*v
            power = self.mul(power, w)[:d]
        return [self.zero]+list(reversed(u))

    def divide(self, c, h):
        n, d = len(c)-1, len(h)-1
        if h[-1] != self.one: raise ValueError('Divisor must be monic')
        if n < d: return [self.zero], c[:]
        r = c[:]
        q = [self.zero]*(n-d+1)
        for k in range(n-d, -1, -1):
            q[k] = r[k+d]
            for j in range(d): r[k+j] -= q[k]*h[j]
            r[k+d] = self.zero
        return self.trim(q), self.trim(r[:d])

    def test(self, c, d):
        h = self.candidate_recurrence(c, d)
        q, digits = c[:], []
        while q != [self.zero]:
            q, r = self.divide(q, h)
            digits.append(r)
        g = [r[0] for r in digits]
        accepted = all(len(r) == 1 for r in digits)
        return {'inner': h, 'outer': g, 'digits': digits, 'accepted': accepted}

    def verify_test(self, c, d, t):
        # Distinct candidate formula; no division inside this verifier.
        h, g, digits = t['inner'], t['outer'], t['digits']
        assert h == self.candidate_binomial(c, d)
        n, m = len(c)-1, (len(c)-1)//d
        assert len(digits) == m+1 and all(len(r) <= d for r in digits)
        hp = self.power(h, m)
        assert all(c[n-k]/c[-1] == hp[n-k] for k in range(d))
        rebuilt = [self.zero]
        for r in reversed(digits): rebuilt = self.add(self.mul(rebuilt, h), r)
        assert rebuilt == c
        residual = self.sub(c, self.compose(g, h))
        assert t['accepted'] == (residual == [self.zero])
        assert t['accepted'] == all(len(r) == 1 for r in digits)

    def pairs(self, c):
        return [(t['outer'], t['inner']) for d in self.divisors(len(c)-1)
                if (t := self.test(c, d))['accepted']]

    def chain(self, c):
        out = []
        while True:
            pair = next((self.test(c, d) for d in self.divisors(len(c)-1)
                         if self.test(c, d)['accepted']), None)
            if pair is None: return [c]+out
            out.insert(0, pair['inner']); c = pair['outer']

    def all_chains(self, c):
        pairs = self.pairs(c)
        if not pairs: return [[c]]
        out = []
        for g, h in pairs:
            if not self.pairs(h):
                out.extend(chain+[h] for chain in self.all_chains(g))
        return out

    def verify_chain(self, c, chain):
        r = [self.zero, self.one]
        for p in reversed(chain): r = self.compose(p, r)
        assert r == c
        for p in chain:
            assert not self.pairs(p)
        for p in chain[1:]:
            assert p[0] == self.zero and p[-1] == self.one


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=Path(__file__).with_name('report.json'))
    args = parser.parse_args()
    start = time.time()
    rng = random.Random(206618)
    counts = {'polynomial_cases': 0, 'degree_tests': 0, 'complete_chains_checked': 0,
              'known_pairs_recovered': 0, 'rational_sympy_comparisons': 0,
              'rational_sympy_degree_disagreements': 0}
    groups = []
    examples = {}
    baseline_disagreements = []

    def check_case(E, c, group, enumerate_all=False, sympy_compare=False):
        counts['polynomial_cases'] += 1
        for d in E.divisors(len(c)-1):
            t = E.test(c, d); E.verify_test(c, d, t)
            counts['degree_tests'] += 1
        chain = E.chain(c); E.verify_chain(c, chain)
        counts['complete_chains_checked'] += 1
        if enumerate_all:
            chains = E.all_chains(c)
            strings = [tuple(str(E.to_expr(a)) for a in ch) for ch in chains]
            assert len(set(strings)) == len(strings)
            for ch in chains:
                E.verify_chain(c, ch)
                assert sorted(len(a)-1 for a in ch) == sorted(len(a)-1 for a in chain)
                counts['complete_chains_checked'] += 1
        if sympy_compare:
            other = sp.decompose(E.to_expr(c), X, domain=QQ)
            rebuilt = X
            for f in reversed(other): rebuilt = sp.expand(f.subs(X, rebuilt))
            assert sp.expand(rebuilt-E.to_expr(c)) == 0
            if sorted(sp.degree(f, X) for f in other) != sorted(len(f)-1 for f in chain):
                counts['rational_sympy_degree_disagreements'] += 1
                if len(baseline_disagreements) < 3:
                    baseline_disagreements.append({
                        'polynomial': str(E.to_expr(c)),
                        'sympy_chain': [str(f) for f in other],
                        'verified_chain': [str(E.to_expr(f)) for f in chain]})
            counts['rational_sympy_comparisons'] += 1
        return chain

    s = sp.sqrt(2)
    E = ExactPolynomialEngine(QQ.algebraic_field(s))
    p = 3+3*s+(14+4*s)*X+(12+26*s)*X**2+(56+8*s)*X**3+(8+48*s)*X**4+48*X**5+16*s*X**6
    c = E.from_expr(p)
    chain = check_case(E, c, 'original', enumerate_all=True)
    examples['original'] = [str(E.to_expr(a)) for a in chain]
    assert E.to_expr(chain[-1]) == X**2+s*X/2
    c2 = E.from_expr(sp.expand(p.subs(X, X**4-X+1)))
    ch2 = check_case(E, c2, 'nested', enumerate_all=True)
    assert [len(a)-1 for a in ch2] == [3,2,4]
    examples['nested'] = [str(E.to_expr(a)) for a in ch2]
    examples['original_degree3_rejection'] = {
        'inner': str(E.to_expr(E.test(c,3)['inner'])),
        'digits': [str(E.to_expr(a)) for a in E.test(c,3)['digits']]}

    R = ExactPolynomialEngine(QQ)
    for p0 in [0, 7, X, 3*X+1, X**4, (X-1)**6, X**12,
               sp.chebyshevt(6,X), X**4+X, X**6+X, (X**4+X)**2,
               X*(X**2+1)**2]:
        pc = R.from_expr(p0)
        ch = check_case(R, pc, 'fixed rational', enumerate_all=True,
                        sympy_compare=sp.degree(p0, X)>1)
        examples[str(p0)] = [str(R.to_expr(a)) for a in ch]
    assert len(R.all_chains(R.from_expr(X**12))) == 3
    assert len(R.all_chains(R.from_expr(sp.chebyshevt(6,X)))) == 2
    assert len(R.pairs(R.from_expr(X**4+X))) == 0
    groups.append({'name': 'fixed examples', 'cases': counts['polynomial_cases']})

    initial = counts['polynomial_cases']
    for degree in (4,6):
        for coeffs in itertools.product((-1,0,1), repeat=degree):
            c = [QQ.convert(v) for v in coeffs]+[QQ.one]
            check_case(R, c, 'exhaustive rational', sympy_compare=True)
    groups.append({'name': 'exhaustive monic rational degree 4 and 6, lower coefficients -1/0/1',
                   'cases': counts['polynomial_cases']-initial})

    alpha = sp.CRootOf(X**5-X-1, 0)
    fields = [('Q', QQ), ('Q(sqrt(2))', QQ.algebraic_field(s)),
              ('Q(i)', QQ.algebraic_field(sp.I)),
              ('Q(sqrt(2),sqrt(3))', QQ.algebraic_field(s,sp.sqrt(3))),
              ('Q(alpha), alpha=CRootOf(x^5-x-1,0)', QQ.algebraic_field(alpha))]
    for name, K in fields:
        E = ExactPolynomialEngine(K)
        initial = counts['polynomial_cases']
        def rc():
            if K == QQ: return K.convert(rng.randint(-3,3))
            theta = K.unit
            return sum((K.convert(rng.randint(-2,2))*theta**j
                        for j in range(min(3,K.mod.degree()))), K.zero)
        for m,d in [(2,2),(3,2),(2,3),(4,2),(2,4),(3,3),
                    (5,2),(2,5),(4,3),(3,4),(5,3),(3,5),
                    (4,4),(6,3),(3,6),(5,4),(4,5),(6,4),(4,6)]:
            f = [rc() for _ in range(m)]+[K.convert(rng.choice((-2,1,2)))]
            g = [rc() for _ in range(d)]+[K.convert(rng.choice((-2,1,2)))]
            p0 = E.compose(f,g)
            t = E.test(p0,d)
            norm = [(v if i else K.zero)/g[-1] for i,v in enumerate(g)]
            adjusted = E.compose(f,[g[0],g[-1]])
            assert t['accepted'] and t['inner'] == norm and t['outer'] == adjusted
            counts['known_pairs_recovered'] += 1
            check_case(E,p0,name, enumerate_all=(m*d<=12), sympy_compare=K==QQ)
        for degree in (4,6,8,9,10,12,15,16,18,20,24):
            p0 = [rc() for _ in range(degree)]+[K.one]
            check_case(E,p0,name, sympy_compare=K==QQ)
        groups.append({'name':name, 'cases':counts['polynomial_cases']-initial})

    report = {'status':'PASS', 'scope':'Independent Python exact number-field implementation; NOT Wolfram Language execution',
              'python_sympy_version':sp.__version__, 'seed':206618, 'counts':counts,
              'groups':groups, 'examples':examples,
              'sympy_baseline_disagreements':baseline_disagreements,
              'checks':['formal-root recurrence equals finite binomial expansion',
                        'leading-coefficient congruence', 'exact base-inner digit reconstruction',
                        'zero residual iff every digit is constant',
                        'known pairs recovered with exact affine normalization',
                        'complete chains recompose, have indecomposable factors, and are normalized',
                        'all enumerated chains are distinct and obey Ritt degree-multiset invariant',
                        'rational differential comparisons with SymPy decompose; disagreements are recorded, not used as a correctness oracle'],
              'wolfram_kernel_tests': 'NOT EXECUTED: Wolfram connector returned HTTP 404; no local Wolfram kernel was present',
              'elapsed_seconds':round(time.time()-start,3)}
    args.output.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:report[k] for k in ('status','counts','elapsed_seconds')},indent=2))

if __name__ == '__main__': main()
