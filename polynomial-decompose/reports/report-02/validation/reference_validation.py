#!/usr/bin/env python3
"""Independent exact-arithmetic validation of the mathematical algorithm.

This is NOT an execution of the Wolfram Language package. It uses SymPy's
exact rational/algebraic number fields and a separate polynomial engine.
Run: python validation/reference_validation.py
The JSON report is written beside this script. No numerical zero tests occur.
"""
from __future__ import annotations
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
import json
import platform
import random
import time
import sympy as sp

x = sp.Symbol("x")

@dataclass
class Engine:
    field: object

    def trim(self, a):
        a = list(a) or [self.field.zero]
        while len(a) > 1 and a[-1] == self.field.zero:
            a.pop()
        return tuple(a)

    def vec(self, p):
        return self.trim(reversed(sp.Poly(p, x, domain=self.field).rep.to_list()))

    def expr(self, a):
        return sp.Add(*(self.field.to_sympy(v)*x**i for i, v in enumerate(a)))

    def add(self, a, b):
        z = self.field.zero
        return self.trim((a[k] if k < len(a) else z) +
                         (b[k] if k < len(b) else z)
                         for k in range(max(len(a), len(b))))

    def mul(self, a, b):
        c = [self.field.zero]*(len(a)+len(b)-1)
        for i, ai in enumerate(a):
            for j, bj in enumerate(b):
                c[i+j] += ai*bj
        return self.trim(c)

    def compose(self, a, b):
        r = (a[-1],)
        for v in reversed(a[:-1]):
            r = self.add(self.mul(r, b), (v,))
        return r

    @staticmethod
    def divisors(a):
        n = len(a)-1
        return [d for d in sp.divisors(n) if 1 < d < n] if n > 1 else []

    def candidate(self, c, d):
        n = len(c)-1
        if d not in self.divisors(c):
            raise ValueError("right degree must be a proper divisor")
        m = n//d
        F = self.field
        b = [F.one] + [c[n-i]/c[n] for i in range(1, d)]
        u = [F.one]+[F.zero]*(d-1)
        for j in range(1, d):
            u[j] = sum((F.convert(sp.Rational((m+1)*i-m*j, m))*b[i]*u[j-i]
                        for i in range(1, j+1)), F.zero)/F.convert(j)
        return (F.zero,)+tuple(reversed(u))

    def triangular_candidate(self, c, d):
        """Different recurrence: compare powers, dividing only by outer degree."""
        n, F = len(c)-1, self.field
        m = n//d
        h = [F.zero]*d+[F.one]
        for j in range(1, d):
            power = (F.one,)
            for _ in range(m):
                power = self.mul(power, h)
            h[d-j] = (c[n-j]/c[n]-power[n-j])/F.convert(m)
        return tuple(h)

    def attempt(self, c, d):
        n, F = len(c)-1, self.field
        m = n//d
        h = self.candidate(c, d)
        powers = [(F.one,)]
        for _ in range(m):
            powers.append(self.mul(powers[-1], h))
        r, g = list(c), [F.zero]*(m+1)
        for k in range(m, -1, -1):
            a = r[k*d]
            g[k] = a
            for i, v in enumerate(powers[k]):
                r[i] -= a*v
        return self.trim(g), h, self.trim(r)

    def pairs(self, c):
        return [(g, h) for d in self.divisors(c)
                for g, h, r in [self.attempt(c, d)] if r == (self.field.zero,)]

    def one(self, c):
        for d in self.divisors(c):
            g, h, r = self.attempt(c, d)
            if r == (self.field.zero,):
                return self.one(g)+(h,)
        return (c,)

    def all(self, c, limit=None):
        @lru_cache(None)
        def visit(v):
            pairs = self.pairs(v)
            if not pairs:
                return ((v,),)
            ans = []
            for g, h in pairs:
                if not self.pairs(h):
                    for prefix in visit(g):
                        ans.append(prefix+(h,))
                        if limit is not None and len(ans) > limit:
                            return tuple(ans)
            return tuple(ans)
        return visit(c)

    def compose_chain(self, chain):
        r = chain[0]
        for a in chain[1:]:
            r = self.compose(r, a)
        return r

    def assert_chain(self, c, chain):
        assert self.compose_chain(chain) == c
        if len(c) > 2:
            assert all(len(v) > 2 and not self.pairs(v) for v in chain)
        assert all(h[0] == self.field.zero and h[-1] == self.field.one
                   for h in chain[1:])


def main():
    start = time.perf_counter()
    rng = random.Random(206618)
    counts = {}
    cases = []
    E = Engine(sp.QQ.algebraic_field(sp.sqrt(2)))
    s = sp.sqrt(2)
    p = 3+3*s+(14+4*s)*x+(12+26*s)*x**2+(56+8*s)*x**3 \
        +(8+48*s)*x**4+48*x**5+16*s*x**6
    expected = (E.vec(3+3*s+(8+14*s)*x+(8+24*s)*x**2+16*s*x**3),
                E.vec(x**2+x/s))
    assert E.one(E.vec(p)) == expected
    E.assert_chain(E.vec(p), expected)
    cases.append({"name": "user sextic", "chain": [str(E.expr(c)) for c in expected]})
    nested = E.vec(sp.expand(p.subs(x, x**4-x+1)))
    nc = E.one(nested)
    E.assert_chain(nested, nc)
    assert [len(c)-1 for c in nc] == [3, 2, 4]
    cases.append({"name": "user degree-24 example", "chain": [str(E.expr(c)) for c in nc]})
    counts["user_examples"] = 2

    Q = Engine(sp.QQ)
    for n, expected_count in [(6, 2), (12, 3), (30, 6)]:
        for p0 in [x**n, sp.chebyshevt(n, x)]:
            c = Q.vec(p0)
            all_chains = Q.all(c)
            assert len(all_chains) == expected_count
            assert len(set(all_chains)) == len(all_chains)
            for chain in all_chains:
                Q.assert_chain(c, chain)
            assert Q.all(c, limit=1) == all_chains[:2]
    counts["power_and_Chebyshev_enumerations"] = 6

    alpha = sp.CRootOf(x**5-x-1, 0)
    R = Engine(sp.QQ.algebraic_field(alpha))
    a = R.field.convert(alpha)
    assert a**5-a-R.field.one == R.field.zero
    g = (a*a, a*a, R.field.one+a)
    h = (R.field.zero, a, R.field.zero, R.field.one)
    c = R.compose(g, h)
    assert R.one(c) == (g, h)
    R.assert_chain(c, (g, h))
    counts["quintic_Root_example"] = 1

    # The exact mixed-field fixture in the article and Wolfram tests.
    M = Engine(sp.QQ.algebraic_field(alpha, sp.sqrt(3)))
    am, sm, Fm = M.field.convert(alpha), M.field.convert(sp.sqrt(3)), M.field
    gm = (sm, am*am, Fm.one+am)
    hm = (Fm.zero, am, Fm.zero, Fm.one)
    cm = M.compose(gm, hm)
    assert M.one(cm) == (gm, hm)
    M.assert_chain(cm, (gm, hm))
    counts["mixed_quintic_Root_and_sqrt3_example"] = 1

    fields = [("Q", sp.QQ, sp.Integer(0)),
              ("Q(sqrt(2))", sp.QQ.algebraic_field(s), s),
              ("Q(i)", sp.QQ.algebraic_field(sp.I), sp.I),
              ("Q(cuberoot(2))", sp.QQ.algebraic_field(2**sp.Rational(1,3)), 2**sp.Rational(1,3)),
              ("Q(sqrt(2),sqrt(3))", sp.QQ.algebraic_field(s, sp.sqrt(3)), s+sp.sqrt(3)),
              ("Q(alpha), alpha^5-alpha-1=0", R.field, alpha)]
    generated = 0
    triangular = 0
    residuals = 0
    for label, F, generator in fields:
        engine = Engine(F)
        theta = F.convert(generator)
        def draw():
            return F.convert(rng.randint(-3, 3))+F.convert(rng.randint(-2,2))*theta
        for m in range(2, 5):
            for d in range(2, 6):
                for repetition in range(2):
                    gg = [draw() for _ in range(m)]+[F.one+theta*theta]
                    if gg[-1] == F.zero:
                        gg[-1] = F.one
                    hh = [draw() for _ in range(d)]+[F.convert(2)]
                    pvec = engine.compose(gg, hh)
                    out, inner, r = engine.attempt(pvec, d)
                    wanted_h = (F.zero,)+tuple(v/hh[-1] for v in hh[1:])
                    wanted_g = engine.compose(gg, (hh[0], hh[-1]))
                    assert inner == wanted_h and out == wanted_g and r == (F.zero,)
                    assert engine.compose(out, inner) == pvec
                    engine.assert_chain(pvec, engine.one(pvec))
                    generated += 1
                    if repetition == 0:
                        assert inner == engine.triangular_candidate(pvec, d)
                        triangular += 1
                    # Every candidate, including rejected candidates, must
                    # satisfy the exact residual identity and pivot conditions.
                    for dd in engine.divisors(pvec):
                        og, ih, res = engine.attempt(pvec, dd)
                        assert engine.add(engine.compose(og, ih), res) == pvec
                        assert all((res[k] if k < len(res) else F.zero) == F.zero
                                   for k in range(0, len(pvec), dd))
                        residuals += 1
    counts["generated_exact_composites"] = generated
    counts["independent_triangular_recurrence_comparisons"] = triangular
    counts["all_degree_residual_checks"] = residuals

    for n in range(4, 31):
        c = Q.vec(x**n+x)
        assert not Q.pairs(c)
        for d in Q.divisors(c):
            _, h, r = Q.attempt(c, d)
            assert h == Q.vec(x**d) and r == Q.vec(x)
    counts["absolute_indecomposability_family"] = 27

    # Independent public SymPy decomposition implementation on random
    # rational inputs, and on explicitly generated compositions.
    oracle_count = 0
    for n in range(4, 17):
        p0 = x**n+sum(rng.randint(-3, 3)*x**j for j in range(n))
        ours = Q.one(Q.vec(p0))
        oracle = sp.decompose(p0, x)
        assert sorted(len(v)-1 for v in ours) == sorted(sp.degree(v, x) for v in oracle)
        Q.assert_chain(Q.vec(p0), ours)
        oracle_count += 1
    for _ in range(15):
        d, m = rng.randint(2,4), rng.randint(2,4)
        p0 = sp.expand((x**m+rng.randint(-3,3)*x+1).subs(x, x**d+2*x+3))
        ours = Q.one(Q.vec(p0))
        oracle = sp.decompose(p0, x)
        assert sorted(len(v)-1 for v in ours) == sorted(sp.degree(v, x) for v in oracle)
        Q.assert_chain(Q.vec(p0), ours)
        oracle_count += 1
    counts["independent_SymPy_decompose_comparisons"] = oracle_count

    for p0 in [0, 7, 2*x+3, (x+1)**6, x**4+1, x**4+x]:
        c = Q.vec(p0)
        Q.assert_chain(c, Q.one(c))
    counts["boundary_and_regression_polynomials"] = 6

    report = {"status": "PASS", "validation_scope":
              "Independent Python/SymPy exact-field implementation; NOT a Wolfram kernel run.",
              "seed": 206618, "python": platform.python_version(),
              "sympy": sp.__version__, "counts": counts, "examples": cases,
              "seconds": round(time.perf_counter()-start, 3)}
    target = Path(__file__).with_name("validation_results.json")
    target.write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
