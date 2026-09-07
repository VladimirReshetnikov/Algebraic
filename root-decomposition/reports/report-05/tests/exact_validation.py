"""Exact independent validation of the algorithms in root_decomposition.tex.
Requires SymPy. This is not a Wolfram Language runtime test.
All identity, subfield and degree checks below use rational arithmetic.
Floating-point numbers are printed only to identify the selected real roots.
"""
from __future__ import annotations
import json
from pathlib import Path
import sympy as s

x, y, z = s.symbols('x y z')
P = x**3+x+1
Q = x**3-x+1
FP = x**9+2*x**7-3*x**6+x**5-x**4+3*x**3-x-1
FS = x**9+6*x**6+3*x**5-15*x**3+24*x**2-4*x+8


def canonical_rows(M: s.Matrix) -> s.Matrix:
    R, _ = M.rref()
    rows = [list(R.row(i)) for i in range(R.rows) if any(R.row(i))]
    return s.Matrix(rows) if rows else s.zeros(0, M.cols)


def null_rows(M: s.Matrix) -> s.Matrix:
    V = M.nullspace()
    return s.Matrix.vstack(*(v.T for v in V)) if V else s.zeros(0, M.cols)


def intersection(A: s.Matrix, B: s.Matrix) -> s.Matrix:
    return canonical_rows(null_rows(s.Matrix.vstack(null_rows(A), null_rows(B))))


def qsolve(A: s.Matrix, b: s.Matrix) -> s.Matrix | None:
    R, piv = A.row_join(b).rref()
    if A.cols in piv:
        return None
    sol = s.zeros(A.cols, 1)
    for i, p in enumerate(piv):
        sol[p] = R[i, -1]
    assert A*sol == b
    return sol


class Field:
    def __init__(self, f: s.Expr):
        self.f = s.Poly(f, x, domain=s.QQ)
        assert self.f.is_irreducible
        self.n = self.f.degree()
        self.theta = s.CRootOf(f, 0)
        self.K = s.QQ.algebraic_field(self.theta)
        self.a = self.K.from_sympy(self.theta)
        self.fac = s.Poly(f.subs(x, y), y, domain=self.K).factor_list()[1]

    def vector(self, a) -> s.Matrix:
        vals = [s.Rational(c.numerator, c.denominator) for c in reversed(a.to_list())]
        return s.Matrix(vals + [s.S.Zero]*(self.n-len(vals)))

    def element(self, v):
        vals = [self.K.dom.convert(c) for c in reversed(list(v))]
        return self.K.new(vals)

    def polynomial(self, a) -> s.Expr:
        return s.expand(sum(v*x**i for i,v in enumerate(self.vector(a))))

    def degree(self, a) -> int:
        V = [self.vector(self.K.one)]
        apow = self.K.one
        for j in range(1, self.n+1):
            apow *= a
            W = s.Matrix.hstack(*V, self.vector(apow))
            if W.rank() < len(V)+1:
                return j
            V.append(self.vector(apow))
        raise AssertionError('degree calculation failed')

    def minpoly(self, a) -> s.Expr:
        V = [self.vector(self.K.one)]
        apow = self.K.one
        for j in range(1, self.n+1):
            apow *= a
            sol = qsolve(s.Matrix.hstack(*V), -self.vector(apow))
            if sol is not None:
                return s.expand(z**j + sum(sol[i]*z**i for i in range(j)))
            V.append(self.vector(apow))
        raise AssertionError('minimal polynomial calculation failed')

    def principal(self, g: s.Poly) -> s.Matrix:
        r = g.degree()
        cols = []
        for j in range(self.n):
            rem = s.Poly(y**j, y, domain=self.K).rem(g)
            co = rem.rep.to_dict()
            col = []
            for k in range(r):
                c = co.get((k,), self.K.zero)
                if k == 0:
                    c -= self.a**j
                col.extend(self.vector(c))
            cols.append(s.Matrix(col))
        return canonical_rows(null_rows(s.Matrix.hstack(*cols)))

    def subfields(self) -> list[s.Matrix]:
        fields = [s.eye(self.n)]
        for g, multiplicity in self.fac:
            assert multiplicity == 1
            B = self.principal(g)
            for F in list(fields):
                C = intersection(F, B)
                if C not in fields:
                    fields.append(C)
        fields.sort(key=lambda M: M.rows)
        # Every computed row space contains 1 and is closed under multiplication.
        for B in fields:
            assert qsolve(B.T, self.vector(self.K.one)) is not None
            for i in range(B.rows):
                for j in range(i, B.rows):
                    a = self.element(B.row(i)) * self.element(B.row(j))
                    assert qsolve(B.T, self.vector(a)) is not None
        return fields

    def pair(self, fields: list[s.Matrix], op: str):
        pairs = [(F,G) for i,F in enumerate(fields) for G in fields[i:]]
        pairs.sort(key=lambda FG: (max(FG[0].rows, FG[1].rows), FG[0].rows+FG[1].rows))
        for F,G in pairs:
            if op == 'Sum':
                w = qsolve(s.Matrix.hstack(F.T,G.T), self.vector(self.a))
                if w is None:
                    continue
                b = self.element(F.T*w[:F.rows, :])
                c = self.element(G.T*w[F.rows:, :])
                assert b+c == self.a
            else:
                AG = s.Matrix.hstack(*(self.vector(self.a*self.element(G.row(i))) for i in range(G.rows)))
                ker = s.Matrix.hstack(F.T, -AG).nullspace()
                if not ker:
                    continue
                w = ker[0]
                b = self.element(F.T*w[:F.rows, :])
                invc = self.element(G.T*w[F.rows:, :])
                assert invc != self.K.zero
                c = self.K.one/invc
                assert b*c == self.a
            return b,c
        raise AssertionError('trivial decomposition should always exist')


def run() -> dict:
    report = {'sympy_version': s.__version__, 'wolfram_runtime_tested': False}
    assert s.expand(s.resultant(P.subs(x,y), Q.subs(x,x-y), y)-FS) == 0
    assert s.expand(s.resultant(P.subs(x,y), x**3-x*y**2+y**3, y)-FP) == 0
    report['resultants_equal_input_polynomials'] = True
    # Root index 1 in Mathematica is the unique real root in these examples.
    assert s.Poly(P,x).count_roots(-s.oo,s.oo) == 1
    assert s.Poly(Q,x).count_roots(-s.oo,s.oo) == 1
    for label, f, op in [('sum',FS,'Sum'), ('product',FP,'Product')]:
        F = Field(f)
        fields = F.subfields()
        assert [B.rows for B in fields] == [1,3,3,9]
        b,c = F.pair(fields,op)
        assert [F.degree(b),F.degree(c)] == [3,3]
        assert s.Poly(f,x).count_roots(-s.oo,s.oo) == 1
        report[label] = {
            'irreducible': True,
            'real_root_count': 1,
            'factor_degrees_over_input_field': [g.degree() for g,e in F.fac],
            'all_subfield_degrees': [B.rows for B in fields],
            'component_degrees': [F.degree(b),F.degree(c)],
            'component_minimal_polynomials': [str(F.minpoly(b)),str(F.minpoly(c))],
            'component_polynomials_in_input_root': [str(F.polynomial(b)),str(F.polynomial(c))],
            'identity_verified_exactly': True,
            'input_real_approximation': str(F.theta.evalf(25)),
        }
        # Explicit short rational recovery formulas, not guessed branches.
        t = F.a
        if op == 'Product':
            aa = (t**3-t**2-F.K.one)/(t**4+t**2-t+F.K.one)
            bb = t/aa
        else:
            denom = 6*t**4-6*t+4
            aa = (3*t**5-5*t**3-3*t**2+2*t-4)/denom
            bb = t-aa
        assert aa**3+aa+F.K.one == F.K.zero
        assert bb**3-bb+F.K.one == F.K.zero
        assert (aa+bb if op=='Sum' else aa*bb) == t
        report[label]['short_rational_recovery_verified'] = True
        # The same rational normalization used in the Wolfram package.
        mb = s.Poly(F.minpoly(b), z)
        if op == 'Sum':
            mu = -mb.nth(mb.degree()-1)/mb.degree()
            bn, cn = b-F.K.from_sympy(mu), c+F.K.from_sympy(mu)
        else:
            c0 = mb.nth(0)
            k = s.real_root(c0, mb.degree())
            assert k.is_Rational
            kk = F.K.from_sympy(k)
            bn, cn = b/kk, c*kk
        normalized = [s.Poly(F.minpoly(bn),z).as_expr(),
                      s.Poly(F.minpoly(cn),z).as_expr()]
        assert set(normalized) == {P.subs(x,z),Q.subs(x,z)}
        assert (bn+cn if op=='Sum' else bn*cn) == t
        report[label]['normalized_component_minimal_polynomials'] = [str(v) for v in normalized]
        report[label]['rational_normalization_verified'] = True
    # The input-field restriction can increase the additive optimum.
    sextic = x**6+4*x**2-1
    S = Field(sextic)
    sextic_fields = S.subfields()
    assert [B.rows for B in sextic_fields] == [1,3,6]
    smaller = [B for B in sextic_fields if B.rows < 6]
    assert qsolve(s.Matrix.vstack(*smaller).T, S.vector(S.a)) is None
    quartic = x**4-x-1
    h2 = s.Poly(quartic,x, modulus=2)
    assert h2.is_irreducible
    degrees7 = sorted(g.degree() for g,e in s.Poly(quartic,x,modulus=7).factor_list()[1])
    assert degrees7 == [1,3]
    diag = s.expand(16*quartic.subs(x,x/2))
    rr = s.resultant(quartic.subs(x,y),quartic.subs(x,x-y),y)
    assert s.expand(rr-diag*sextic**2) == 0
    report['sextic_ambient_field_counterexample'] = {
        'polynomial': str(sextic),
        'all_subfield_degrees': [B.rows for B in sextic_fields],
        'not_in_sum_of_proper_subfields': True,
        'pair_sum_resultant_identity': True,
        'quartic_irreducible_mod_2': True,
        'quartic_factor_degrees_mod_7': degrees7,
        'internal_additive_optimum': 6,
        'global_additive_optimum_proved_in_article': 4
    }
    return report


if __name__ == '__main__':
    result = run()
    out = Path(__file__).with_name('validation_results.json')
    out.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
    print('PASS: exact independent checks; Wolfram Language not executed.')
