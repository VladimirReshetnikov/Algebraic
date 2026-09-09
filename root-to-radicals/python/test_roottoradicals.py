"""Regression tests and timings for roottoradicals.py (run: python test_roottoradicals.py)."""
import time
import unittest
from unittest.mock import patch

import sympy as sp
from flint import fmpz_poly

import roottoradicals as rt
import rootdecomp as rd


def alg(s):
    return rd.parse_wolfram_root(s)


def run(label, a, method_expected=None, **kw):
    t0 = time.perf_counter()
    r = rt.root_to_radicals(a, **kw)
    dt = time.perf_counter() - t0
    ok = r.verified and rt.is_radical_expression(r.expression) and (method_expected is None or r.method == method_expected)
    print(f"[{'OK' if ok else 'CHECK'}] {label} ({dt:.2f} s): method={r.method} depth={r.radical_depth} "
          f"leaves={r.leaf_count} galois={r.galois_order}", flush=True)
    if not ok:
        raise AssertionError(f"{label}: {r}")
    return r


A6 = "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]"
A5 = "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]"
C5 = "Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 1]"


class Grammar(unittest.TestCase):
    def test_grammar(self):
        x = sp.Symbol("x")
        self.assertTrue(rt.is_radical_expression((1 + sp.sqrt(5)) / 2))
        self.assertTrue(rt.is_radical_expression(sp.Pow(-1, sp.Rational(2, 5)) * sp.root(7, 5) + sp.I / 3))
        self.assertFalse(rt.is_radical_expression(sp.cos(sp.pi / 7)))
        self.assertFalse(rt.is_radical_expression(x))
        self.assertFalse(rt.is_radical_expression(sp.Pow(2, sp.sqrt(2))))
        self.assertEqual(rt.radical_depth(sp.sqrt(1 + sp.sqrt(2))), 2)
        self.assertEqual(rt.radical_depth(sp.sqrt(2) ** 3 + 1 / sp.sqrt(3)), 1)
        self.assertEqual(rt.radical_depth(sp.Rational(7, 3)), 0)

    def test_ball_principal_branches(self):
        # (-8)^(1/3) = 1 + sqrt(3) i, (-1)^(2/5) = exp(2 pi i / 5)
        with rt.ctx.workprec(200):
            z = rt.ball(sp.Pow(-8, sp.Rational(1, 3)), 200)
            self.assertTrue(z.real.contains(1) and z.imag.overlaps(rt.arb(3).sqrt()))
            w = rt.ball(sp.Pow(-1, sp.Rational(2, 5)), 200)
            self.assertTrue(w.real.overlaps((rt.arb.pi() * 2 / 5).cos()))
            self.assertTrue(w.imag > 0)


class Examples(unittest.TestCase):
    def test_question_examples(self):
        r6 = run("sextic example", A6, "Reciprocal")
        self.assertEqual(r6.degree, 6)
        r5 = run("quintic example", A5, "Dickson")
        self.assertEqual(r5.radical_depth, 1)
        closed = sp.Pow(sp.Rational(-3, 5) + sp.Rational(4, 5) * sp.I, sp.Rational(1, 5)) + \
            sp.Pow(sp.Rational(-3, 5) - sp.Rational(4, 5) * sp.I, sp.Rational(1, 5))
        self.assertTrue(rt.ball(r5.expression - closed, 300).contains(0))
        for k in range(1, 7):
            run(f"sextic conjugate {k}", f"Root[-1 - #^2 - #^3 + #^4 + #^6 &, {k}]")
        for k in range(1, 6):
            run(f"quintic conjugate {k}", f"Root[6 + 25 # - 25 #^3 + 5 #^5 &, {k}]")

    def test_cyclic_quintic(self):
        r = run("cyclic quintic", C5, "Galois")
        self.assertEqual((r.galois_order, r.extended_order, r.series_primes), (5, 20, [5]))
        run("cyclic quintic fourier", C5, "Galois", resolvents="fourier")
        run("cyclic quintic eigenvector", C5, "Galois", resolvents="eigenvector")
        run("cyclic quintic conjugate 3", "Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 3]", "Galois")

    def test_forced_descent(self):
        for label, s in [("x^3-2", "Root[-2 + #^3 &, 2]"), ("x^3-3x+1", "Root[1 - 3 # + #^3 &, 1]"),
                         ("x^4-2", "Root[-2 + #^4 &, 4]"), ("x^4-10x^2+1", "Root[1 - 10 #^2 + #^4 &, 4]"),
                         ("x^5-2", "Root[-2 + #^5 &, 3]"), ("x^8+1", "Root[1 + #^8 &, 1]"),
                         ("Phi_7", "Root[1 + # + #^2 + #^3 + #^4 + #^5 + #^6 &, 1]"),
                         ("x^6-2x^3-1", "Root[-1 - 2 #^3 + #^6 &, 1]"),
                         ("x^4-x-1 (S4)", "Root[-1 - # + #^4 &, 1]")]:
            run("descent " + label, s, "Galois", method="galois")

    def test_examples_by_descent(self):
        r6 = run("sextic example by descent", A6, "Galois", method="galois")
        self.assertEqual((r6.galois_order, r6.extended_order), (24, 48))
        r5 = run("quintic example by descent", A5, "Galois", method="galois")
        self.assertEqual((r5.galois_order, r5.extended_order), (20, 40))

    def test_structural_families(self):
        run("decomposition", "Root[1 + 3 #^2 - 3 #^4 - 4 #^6 + #^8 + #^10 &, 5]", "Decompose")
        run("Dickson D_7", "Root[-3 - 7 # + 14 #^3 - 7 #^5 + #^7 &, 1]", "Dickson")
        run("low degree", "Root[-1 - # + #^4 &, 2]", "LowDegree")
        with self.assertRaises(rt.NotFound):
            rt.root_to_radicals(C5, method="structural")

    def test_decomposition_with_three_components(self):
        # All branches of ((x^2)^2)^2 - 2 exercise the shared composition suffixes.
        for k in range(1, 9):
            run(f"three-component decomposition conjugate {k}", f"Root[-2 + #^8 &, {k}]", "Decompose")

    def test_identity_embedding_precision(self):
        gd = rd.galois_data(fmpz_poly([-2, 0, 0, 1]), 200, 20)
        v = [a + b / 3 for a, b in zip(gd.root_coords[0], gd.root_coords[1])]
        value = rt._value_at_identity(gd, v)
        for prec in (gd.prec, 2 * gd.prec):
            with rt.ctx.workprec(prec):
                expected = (rd.conj_vector(gd, v) if prec == gd.prec else rd._conj_vector_at(gd, v, prec))[gd.identity]
                self.assertTrue(value(prec).overlaps(expected))

    def test_dense_composition_chain(self):
        h = rt.X
        for _ in range(4):
            h = sp.expand(h ** 2 + h)
        p = rt.fmpz_poly_of(h + 2)
        for k in (1, 8, 16):
            run(f"dense degree-16 decomposition conjugate {k}", rd.AlgebraicNumber(p, k), "Decompose")


class FieldPowers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gd = rd.galois_data(fmpz_poly([-2, 0, 0, 1]), 300, 20)

    def matrix_power(self, v, exponent):
        with rt.ctx.workprec(self.gd.prec):
            matrix = rd.multiplication_matrix_of(self.gd, v)
        one = [rt.fmpq(1)] + [rt.fmpq(0)] * (self.gd.order - 1)
        return rd.apply_matrix(matrix ** exponent, one)

    def test_coordinate_powers(self):
        gd = self.gd
        vectors = [[rt.fmpq(0)] * gd.order, gd.root_coords[1],
                   [a / 3 + b / 7 for a, b in zip(gd.root_coords[0], gd.root_coords[1])]]
        for v in vectors:
            for exponent in (0, 1, 2, 3, 5):
                with self.subTest(vector=v, exponent=exponent):
                    self.assertEqual(rd.power_coordinates(gd, v, exponent), self.matrix_power(v, exponent))
        with self.assertRaises(ValueError):
            rd.power_coordinates(gd, vectors[1], -1)

    def test_coordinate_power_precision_fallback(self):
        gd = self.gd
        v = [rt.fmpq(10 ** 40)] + [rt.fmpq(1, 7)] * (gd.order - 1)
        with rt.ctx.workprec(gd.prec):
            integers, _ = rd._clear_denominators(v)
            with self.assertRaises(rd.PrecisionError):
                rd.coords_from_conjugates(gd, [z ** 5 for z in rd.conj_vector(gd, integers)])
        self.assertEqual(rd.power_coordinates(gd, v, 5), self.matrix_power(v, 5))

    def test_power_divider(self):
        gd = self.gd
        one = [rt.fmpq(1)] + [rt.fmpq(0)] * (gd.order - 1)
        mixed = [a / 3 + b / 7 for a, b in zip(gd.root_coords[0], gd.root_coords[1])]
        numerators = [[rt.fmpq(0)] * gd.order, one, gd.root_coords[1], mixed]
        denominators = [one, gd.root_coords[1], mixed, [c / 10 ** 100 for c in one]]
        for denominator in denominators:
            divide = rd.power_divider(gd, denominator)
            with rt.ctx.workprec(gd.prec):
                matrix = rd.multiplication_matrix_of(gd, denominator)
            for numerator in numerators:
                for exponent in (0, 1, 2, 3, 5):
                    self.assertEqual(divide(numerator, exponent), rd.fmpq_solve(matrix ** exponent, numerator))
        with self.assertRaises(ZeroDivisionError):
            rd.power_divider(gd, numerators[0])
        with self.assertRaises(ValueError):
            divide(one, -1)

    def test_power_divider_norm_fallback_reuses_matrix(self):
        gd = self.gd
        denominator = [rt.fmpq(10 ** 40)] + [rt.fmpq(1, 7)] * (gd.order - 1)
        numerator = gd.root_coords[1]
        with rt.ctx.workprec(gd.prec):
            integers, _ = rd._clear_denominators(denominator)
            with self.assertRaises(rd.PrecisionError):
                rd._unique_integer(rt.math.prod(rd.conj_vector(gd, integers), start=rt.acb(1)))
            matrix = rd.multiplication_matrix_of(gd, denominator)
        with patch.object(rd, "multiplication_matrix_of", wraps=rd.multiplication_matrix_of) as reconstruct:
            divide = rd.power_divider(gd, denominator)
            denominator[:] = [rt.fmpq(0)] * gd.order  # the lazy fallback owns its denominator snapshot
            self.assertEqual(divide(iter(numerator), 0), numerator)
            self.assertEqual(reconstruct.call_count, 0)
            for exponent in (1, 3, 5):
                self.assertEqual(divide(iter(numerator), exponent), rd.fmpq_solve(matrix ** exponent, numerator))
            self.assertEqual(reconstruct.call_count, 1)

    def test_power_divider_trace_fallback(self):
        gd = self.gd
        denominator = gd.root_coords[1]
        numerator = [rt.fmpq(10 ** 100)] + [rt.fmpq(1)] * (gd.order - 1)
        with rt.ctx.workprec(gd.prec):
            values = rd.conj_vector(gd, denominator)
            norm = rd._unique_integer(rt.math.prod(values, start=rt.acb(1)))
            with self.assertRaises(rd.PrecisionError):
                rd.coords_from_conjugates(gd, [z * (rt.acb(norm) / w) ** 3
                    for z, w in zip(rd.conj_vector(gd, numerator), values)])
            expected = rd.fmpq_solve(rd.multiplication_matrix_of(gd, denominator) ** 3, numerator)
        with patch.object(rd, "multiplication_matrix_of", wraps=rd.multiplication_matrix_of) as reconstruct:
            self.assertEqual(rd.power_divider(gd, iter(denominator))(iter(numerator), 3), expected)
            self.assertEqual(reconstruct.call_count, 1)

    def test_power_divider_negative_norm(self):
        gd = rd.galois_data(fmpz_poly([1, -3, 0, 1]), 300, 20)
        denominator = gd.root_coords[0]
        numerator = [rt.fmpq(i == 0, 5) + c / 7 for i, c in enumerate(gd.root_coords[1])]
        with rt.ctx.workprec(gd.prec):
            self.assertEqual(rd._unique_integer(rt.math.prod(rd.conj_vector(gd, denominator), start=rt.acb(1))), -1)
            matrix = rd.multiplication_matrix_of(gd, denominator)
        divide = rd.power_divider(gd, denominator)
        for exponent in (1, 2, 3, 5):
            self.assertEqual(divide(numerator, exponent), rd.fmpq_solve(matrix ** exponent, numerator))


class RationalPolynomials(unittest.TestCase):
    def test_native_polynomial_conversion_and_evaluation(self):
        for degree in (0, 2, 8, 32):
            expr = sum(sp.Rational(i + 1, i + 2) * rt.X ** i for i in range(degree + 1))
            poly = rt._rational_poly(expr)
            self.assertEqual(rt.sympy_poly(poly), expr)
            for prec in (80, 300):
                with rt.ctx.workprec(prec):
                    z = rt.acb(1, 2) / 3
                    expected = rt.acb(0)
                    for coefficient in sp.Poly(expr, rt.X).all_coeffs():
                        expected = expected * z + rt._rational_acb(coefficient.p, coefficient.q)
                    self.assertTrue(rt.acb_poly(poly)(z).overlaps(expected))
        self.assertEqual(rt.fmpz_poly_of(-(rt.X + 1) ** 2 / 6), fmpz_poly([1, 2, 1]))
        self.assertEqual(rt.fmpz_poly_of(0), fmpz_poly())

    def test_reciprocal_rational_families_and_near_misses(self):
        for m in range(2, 10):
            outer = rt.X ** m + sum((j + 1) * rt.X ** j for j in range(m))
            for c in (0, -1, sp.Rational(2, 3), sp.Rational(-3, 2)):
                p = rt.fmpz_poly_of(sp.expand(rt.X ** m * outer.subs(rt.X, rt.X + c / rt.X)))
                result = rt.reciprocal_decomposition(p)
                self.assertIsNotNone(result)
                cs, reduced = result
                self.assertEqual(sp.expand(rt.X ** m * reduced.subs(rt.X, rt.X + cs / rt.X)),
                                 rt.sympy_poly(p) / int(p.leading_coefficient()))
                if c:
                    p[2 * m - 1] += 1
                    self.assertIsNone(rt.reciprocal_decomposition(p))

    def test_cyclotomic_base_with_two_primes(self):
        p = rt.cyclotomic(15)
        a = rd.AlgebraicNumber(p, 1)
        gd = rd.galois_data(p * rt.cyclotomic(3) * rt.cyclotomic(5), 300, 50)
        expression, order, steps = rt._descend(gd, a, [3, 5], rt._State())
        self.assertEqual((order, steps), (8, []))
        self.assertTrue(rt.is_radical_expression(expression) and rt.verify_numeric(expression, a))


class Negative(unittest.TestCase):
    def test_not_solvable(self):
        for s in ["Root[-1 - # + #^5 &, 1]", "Root[-1 - # + #^7 &, 1]", "Root[-1 - # + #^6 &, 1]",
                  "Root[5 - 2 # + 3 #^2 + #^4 + #^6 &, 1]", "Root[-1 - # + #^8 &, 1]", "Root[-1 - # + #^9 &, 1]"]:
            with self.assertRaises(rt.NotSolvable):
                rt.root_to_radicals(s)
            self.assertFalse(rt.is_solvable(s))
        self.assertTrue(rt.is_solvable(C5))
        self.assertTrue(rt.is_solvable(A6))
        self.assertTrue(rt.is_solvable("Root[-1 - # + #^4 &, 1]"))

    def test_limits_and_input(self):
        with self.assertRaises(rt.ResourceLimit):
            rt.root_to_radicals("Root[-1 - # + #^4 &, 1]", method="galois", maxorder=10)
        with self.assertRaises(ValueError):
            rt.root_to_radicals(A6, method="nope")
        r = rt.root_to_radicals(sp.Rational(3, 4))
        self.assertEqual(r.expression, sp.Rational(3, 4))
        self.assertEqual(rt.root_to_radicals(rd.AlgebraicNumber(fmpz_poly([-2, 0, 1]), 2)).expression, sp.sqrt(2))

    def test_frobenius(self):
        self.assertTrue(rt.frobenius_nonsolvable(fmpz_poly([-1, -1, 0, 0, 0, 1])))
        self.assertFalse(rt.frobenius_nonsolvable(fmpz_poly([1, 3, -3, -4, 1, 1])))
        self.assertTrue(rt.frobenius_nonsolvable(fmpz_poly([-1, -1, 0, 0, 0, 0, 1])))
        self.assertFalse(rt.frobenius_nonsolvable(fmpz_poly([-1, 0, 0, 0, 0, 0, 0, 0, 1])))   # x^8-1: solvable, no obstruction
        self.assertTrue(rt.frobenius_nonsolvable(fmpz_poly([-1, -1, 0, 0, 0, 0, 0, 0, 0, 1])))  # x^9-x-1: a 5- or 7-cycle
        self.assertFalse(rt.frobenius_nonsolvable(fmpz_poly([1, 3, -3, -4, 1, 1])))
        self.assertTrue(rt.frobenius_order_multiple(fmpz_poly([-1, -1, 0, 0, 0, 1])) % 60 == 0)   # S5 element orders


if __name__ == "__main__":
    unittest.main(verbosity=2)
