"""Regression tests and timings for roottoradicals.py (run: python test_roottoradicals.py)."""
import time
import unittest

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


class Negative(unittest.TestCase):
    def test_not_solvable(self):
        for s in ["Root[-1 - # + #^5 &, 1]", "Root[-1 - # + #^7 &, 1]", "Root[-1 - # + #^6 &, 1]",
                  "Root[5 - 2 # + 3 #^2 + #^4 + #^6 &, 1]"]:
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
        self.assertFalse(rt.frobenius_nonsolvable(fmpz_poly([-1, 0, 0, 0, 0, 0, 0, 0, 1])))   # prime-power degree: no test


if __name__ == "__main__":
    unittest.main(verbosity=2)
