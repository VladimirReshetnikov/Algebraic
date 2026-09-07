#!/usr/bin/env python3
"""Independent exact checks for the accompanying article.

Requires Python >= 3.10 and SymPy. This is NOT a Mathematica runtime test.
The principal-subfield, additive, binary-product, and tensor-product algorithms
are independently implemented over SymPy's exact algebraic field domain.
"""
from __future__ import annotations
import itertools
import json
import time
from pathlib import Path
import sympy as s

x, t, z = s.symbols("x t z")


def canonical(rows: s.Matrix, n: int) -> s.Matrix:
    if rows.rows == 0:
        return s.zeros(0, n)
    rr, _ = rows.rref()
    nonzero = [list(rr.row(i)) for i in range(rr.rows) if any(rr.row(i))]
    return s.Matrix(nonzero) if nonzero else s.zeros(0, n)


def kernel_rows(matrix: s.Matrix) -> s.Matrix:
    ns = matrix.nullspace()
    return s.Matrix.vstack(*(v.T for v in ns)) if ns else s.zeros(0, matrix.cols)


def intersection(a: s.Matrix, b: s.Matrix) -> s.Matrix:
    annihilator = kernel_rows(a).col_join(kernel_rows(b))
    if annihilator.rows == 0:
        return s.eye(a.cols)
    return canonical(kernel_rows(annihilator), a.cols)


def matrix_key(a: s.Matrix) -> tuple:
    return (a.rows, a.cols, tuple(a))


class ExactField:
    """Embedded number field with rational power-basis coordinates."""
    def __init__(self, polynomial: s.Expr):
        self.f = s.Poly(polynomial, x, domain=s.QQ)
        assert self.f.is_irreducible
        self.n = self.f.degree()
        self.root = s.CRootOf(self.f.as_expr().subs(x, t), 0)
        self.K = s.QQ.algebraic_field(self.root)
        self.theta = self.K.unit
        self.one = self.K.one
        self.zero = self.K.zero
        self.F = s.Poly(self.f.as_expr(), x, domain=self.K)
        self.factors = [p.monic() for p, e in self.F.factor_list()[1] if e == 1]
        assert sum(p.degree() for p in self.factors) == self.n

    def vector(self, a) -> s.Matrix:
        low = [s.Rational(c.numerator, c.denominator) for c in reversed(a.to_list())]
        return s.Matrix([low + [s.S.Zero] * (self.n-len(low))])

    def element(self, v):
        return self.K([s.QQ.convert(c) for c in reversed(list(v))])

    def mul(self, u, v) -> s.Matrix:
        return self.vector(self.element(u) * self.element(v))

    def expression(self, v) -> s.Expr:
        return sum(c*t**i for i, c in enumerate(list(v)))

    def principal_fields(self) -> list[s.Matrix]:
        result = []
        for factor in self.factors:
            m = factor.degree()
            # Remainders have coefficients in K. Keep the domain representation,
            # avoiding numerical evaluation or symbolic root recognition.
            cols = []
            power = s.Poly(1, x, domain=self.K)
            for k in range(self.n):
                rem = power.rem(factor)
                coeffs = list(reversed(rem.rep.to_list()))
                coeffs += [self.zero] * (m-len(coeffs))
                coeffs[0] -= self.theta**k
                cols.append(s.Matrix.vstack(*(self.vector(c).T for c in coeffs)))
                power = (power * s.Poly(x, x, domain=self.K)).rem(factor)
            matrix = s.Matrix.hstack(*cols)
            result.append(canonical(kernel_rows(matrix), self.n))
        return result

    def subfields(self) -> list[s.Matrix]:
        known = {matrix_key(s.eye(self.n)): s.eye(self.n)}
        for principal in self.principal_fields():
            additions = [intersection(v, principal) for v in list(known.values())]
            for v in additions:
                known[matrix_key(v)] = v
        fields = sorted(known.values(), key=lambda m: (m.rows, str(tuple(m))))
        # Independently certify that each recovered vector space is a subfield.
        one = self.vector(self.one)
        for B in fields:
            assert self.n % B.rows == 0
            assert B.col_join(one).rank() == B.rows
            for i in range(B.rows):
                for j in range(B.rows):
                    assert B.col_join(self.mul(B.row(i), B.row(j))).rank() == B.rows
        return fields

    def minimum_sum(self, target, fields):
        av = self.vector(target)
        for d in sorted({b.rows for b in fields}):
            eligible = [b for b in fields if b.rows <= d]
            B = s.Matrix.vstack(*eligible)
            if B.T.row_join(av.T).rank() != B.rank():
                continue
            solution, free = B.T.gauss_jordan_solve(av.T)
            solution = solution.subs({q: 0 for q in free})
            terms, pos = [], 0
            for E in eligible:
                u = (solution[pos:pos+E.rows, 0].T * E)
                if any(u):
                    terms.append(self.element(u))
                pos += E.rows
            assert sum(terms, self.zero) == target
            return d, terms
        raise AssertionError("Full field must contain the target")

    def binary_product(self, target, fields, d):
        av = self.vector(target)
        eligible = [b for b in fields if b.rows <= d]
        for i, E in enumerate(eligible):
            aE = s.Matrix.vstack(*(self.mul(av, E.row(k)) for k in range(E.rows)))
            for F in eligible[i:]:
                ns = (aE.col_join(-F).T).nullspace()
                if not ns:
                    continue
                v = ns[0]
                e = self.element(v[:E.rows, 0].T*E)
                assert e != self.zero
                factors = [self.one/e, target*e]
                assert factors[0]*factors[1] == target
                return factors
        return None

    def tensor_product(self, target, family):
        dims = [B.rows for B in family]
        if s.prod(dims) != self.n:
            return None
        tuples = list(itertools.product(*(range(d) for d in dims)))
        bproducts = []
        for index in tuples:
            elt = self.one
            for B, j in zip(family, index):
                elt *= self.element(B.row(j))
            bproducts.append(self.vector(elt))
        matrix = s.Matrix.vstack(*bproducts).T
        if matrix.rank() != self.n:
            return None
        coeff = list(matrix.inv()*self.vector(target).T)
        k0 = next(i for i, q in enumerate(coeff) if q)
        pivot, ip = coeff[k0], tuples[k0]
        by_index = dict(zip(tuples, coeff))
        vectors = []
        for k, d in enumerate(dims):
            vv = []
            for i in range(d):
                idx = list(ip); idx[k] = i
                vv.append(by_index[tuple(idx)]/pivot)
            vectors.append(vv)
        for index in tuples:
            predicted = pivot*s.prod(vectors[k][index[k]] for k in range(len(dims)))
            if predicted != by_index[index]:
                return None
        factors = [self.element(s.Matrix([v])*B) for B, v in zip(family, vectors)]
        factors[0] *= self.K.convert(pivot)
        product = self.one
        for a in factors: product *= a
        assert product == target
        return factors


def run() -> dict:
    started = time.time()
    p, q = x**3+x+1, x**3-x+1
    fp = x**9+2*x**7-3*x**6+x**5-x**4+3*x**3-x-1
    fs = x**9+6*x**6+3*x**5-15*x**3+24*x**2-4*x+8
    report = {"sympy_version": s.__version__, "mathematica_runtime_tested": False}
    assert s.expand(s.resultant(p, s.expand(x**3*q.subs(x,z/x)), x)-fp.subs(x,z)) == 0
    assert s.expand(s.resultant(p, q.subs(x,z-x), x)-fs.subs(x,z)) == 0
    assert s.discriminant(p,x) == -31 and s.discriminant(q,x) == -23
    report["resultants"] = "both exact identities passed"
    for label, f in [("product", fp), ("sum", fs)]:
        assert s.Poly(f,x).is_irreducible
        assert s.Poly(f,x).count_roots(-s.oo,s.oo) == 1
        field = ExactField(f)
        fields = field.subfields()
        degrees = [E.rows for E in fields]
        assert degrees == [1,3,3,9]
        if label == "sum":
            d, terms = field.minimum_sum(field.theta, fields)
            assert d == 3
            report[label] = {"subfield_degrees": degrees, "minimum_sum_degree": d,
                             "coordinate_terms": [str(field.expression(field.vector(a))) for a in terms]}
        else:
            assert field.binary_product(field.theta,fields,2) is None
            factors = field.binary_product(field.theta,fields,3)
            assert factors is not None
            report[label] = {"subfield_degrees": degrees, "binary_product_degree": 3,
                             "coordinate_factors": [str(field.expression(field.vector(a))) for a in factors]}
    # Compact modular certificates for recovering the specified cubic roots.
    Ap = -(x**7+2*x**5-2*x**4+1)/2
    Bp = -(x**7+2*x**5-2*x**4+2*x**3+2*x-1)/2
    As = -(2025*x**8+750*x**7-4374*x**6+10530*x**5+9975*x**4
           -28868*x**3-51921*x**2-12496*x+39992)/83732
    Bs = x-As
    for f,A,B,op in [(fp,Ap,Bp,"product"),(fs,As,Bs,"sum")]:
        assert s.rem(A**3+A+1,f,x) == 0
        assert s.rem(B**3-B+1,f,x) == 0
        assert s.rem((A*B if op=="product" else A+B)-x,f,x) == 0
    report["recovery_certificates"] = "six exact polynomial remainder tests passed"
    # A genuinely three-term additive example.
    alpha = s.sqrt(2)+s.sqrt(3)+s.sqrt(6)
    f4 = s.minpoly(alpha,x)
    field4 = ExactField(f4)
    fields4 = field4.subfields()
    d4, terms4 = field4.minimum_sum(field4.theta,fields4)
    assert d4 == 2 and len(terms4) == 3
    report["three_term_sum"] = {"polynomial":str(f4),"minimum_degree":2,"term_count":3}
    # A genuinely three-factor product. Any conjugate is a product of three
    # quadratic factors, and the degree is eight, excluding two such factors.
    alpha8 = (1+s.sqrt(2))*(1+s.sqrt(3))*(1+s.sqrt(5))
    f8 = s.minpoly(alpha8,x)
    field8 = ExactField(f8)
    fields8 = field8.subfields()
    assert field8.n == 8
    assert field8.binary_product(field8.theta,fields8,2) is None
    quadratics = [E for E in fields8 if E.rows == 2]
    tf = None
    for family in itertools.combinations(quadratics,3):
        tf = field8.tensor_product(field8.theta,family)
        if tf: break
    assert tf and len(tf)==3
    report["three_factor_product"] = {"polynomial":str(f8),"subfield_count":len(fields8),
                                     "minimum_degree":2,"factor_count":3}
    # Non-Galois input-field restriction counterexamples (sum and product).
    fs6 = x**6+4*x**2-1
    fp6 = x**6+x**4-x**3-x**2-1
    for label,f in [("sum",fs6),("product",fp6)]:
        field6=ExactField(f); fields6=field6.subfields()
        assert [E.rows for E in fields6]==[1,3,6]
        if label=="sum":
            d,_=field6.minimum_sum(field6.theta,fields6)
            assert d==6
        else:
            assert field6.binary_product(field6.theta,fields6,4) is None
        report["external_"+label] = {"polynomial":str(f),"subfield_degrees":[1,3,6]}
    report["elapsed_seconds"] = round(time.time()-started,3)
    report["status"] = "all assertions passed"
    return report

if __name__ == "__main__":
    report = run()
    text = json.dumps(report, indent=2)
    print(text)
    Path(__file__).with_name("verification_results.json").write_text(text+"\n")
