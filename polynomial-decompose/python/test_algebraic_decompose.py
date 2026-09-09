"""Exact regression suite: python -m unittest -v test_algebraic_decompose."""

import copy
import random
import unittest
from unittest.mock import patch

import sympy as sp

import algebraic_decompose as ad


x = sp.Symbol("x")
r = sp.sqrt(2)
QUESTION = 3 + 3*r + (14 + 4*r)*x + (12 + 26*r)*x**2 + (56 + 8*r)*x**3 + (8 + 48*r)*x**4 + 48*x**5 + 16*r*x**6


class FunctionalDecompositionTests(unittest.TestCase):
    def assert_complete(self, p, chain):
        self.assertTrue(ad.verify_decomposition(p, chain, x, require_complete=True, require_normalized=True))
        # Separate public composition and exact domain subtraction.
        difference = sp.Poly(ad.compose(chain, x) - (p.as_expr() if isinstance(p, sp.Poly) else p), x, extension=True)
        self.assertTrue(difference.is_zero)

    def test_question(self):
        chain = ad.decompose(QUESTION, x)
        expected = [3 + 3*r + (8 + 14*r)*x + (8 + 24*r)*x**2 + 16*r*x**3, x**2 + r*x/2]
        self.assertEqual(chain, expected)
        self.assert_complete(QUESTION, chain)
        data = ad.decomposition_data(QUESTION, x)
        self.assertTrue(ad.verify_decomposition_data(QUESTION, data, x))

    def test_nested_degree_24(self):
        p = sp.Poly(QUESTION.subs(x, x**4 - x + 1), x, extension=r)
        chain = ad.decompose(p, x)
        self.assertEqual([sp.degree(f, x) for f in chain], [3, 2, 4])
        self.assert_complete(p, chain)
        self.assertTrue(ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x))

    def test_sparse_and_single_derivative_factor_cases(self):
        for p, expected in [((x**4+x)**2, [2, 4]),
                            ((x+1)**12, [3, 2, 2]),
                            ((x**3+x)**2, [3, 2]),
                            (x**12, [3, 2, 2])]:
            with self.subTest(p=p):
                chain = ad.decompose(p, x)
                self.assertEqual([sp.degree(f, x) for f in chain], expected)
                self.assert_complete(p, chain)
        self.assertIsNone(ad.right_decompose((x**4+x)**2, x, 2))
        self.assertEqual(ad.right_decompose((x**4+x)**2, x, 4), (x**2, x**4+x))

    def test_all_pairs(self):
        for n in (6, 12, 24, 30):
            pairs = ad.decomposition_pairs(x**n, x)
            self.assertEqual([int(sp.degree(h, x)) for _, h in pairs], ad._degrees(n))
            for outer, inner in pairs:
                self.assertTrue(ad.verify_decomposition(x**n, [outer, inner], x, require_normalized=True))
        self.assertEqual(ad.decomposition_pairs(x**16 + x, x), [])

    def test_monomial_and_chebyshev_collisions(self):
        for n, count in ((6, 2), (12, 3), (30, 6)):
            for p in (x**n, sp.chebyshevt(n, x)):
                with self.subTest(n=n, polynomial=p):
                    chains = ad.decompositions(p, x)
                    self.assertEqual(len(chains), count)
                    self.assertEqual(len({tuple(chain) for chain in chains}), count)
                    for chain in chains:
                        self.assert_complete(p, chain)
                    self.assertEqual(ad.decompositions(p, x, max_chains=count), chains)

    def test_enumeration_limit_truthfulness(self):
        full = ad.decompositions(x**30, x)
        for cap in (1, 3, 5):
            with self.assertRaises(ad.EnumerationLimitError) as caught:
                ad.decompositions(x**30, x, max_chains=cap)
            error = caught.exception
            self.assertFalse(error.complete)
            self.assertEqual(error.limit, cap)
            self.assertEqual(error.partial_chains, full[:cap])
        self.assertEqual(ad.decompositions(x**5 + x, x, max_chains=1), [[x**5+x]])
        for limit in (0, -1, 1.5, True):
            with self.assertRaises(ValueError):
                ad.decompositions(x**6, x, max_chains=limit)

    def test_quintic_root_and_algebraic_cancellation(self):
        t = sp.Symbol("t")
        alpha = sp.CRootOf(t**5-t-1, 0)
        field = sp.QQ.algebraic_field(alpha)
        p = sp.Poly((1+alpha)*(x**3+alpha*x)**2 + alpha**2*(x**3+alpha*x) + alpha, x, domain=field)
        pair = ad.right_decompose(p, x, 3)
        self.assertIsNotNone(pair)
        self.assert_complete(p, ad.decompose(p, x))
        cancelled = (alpha**5-alpha-1)*x**8 + x**2
        self.assertEqual(ad.decompose(cancelled, x), [x**2])
        self.assertEqual(ad.decomposition_data(cancelled, x)["input_degree"], 2)
        self.assertEqual(ad.decompose(sp.AlgebraicNumber(alpha)*x**2, x), [alpha*x**2])

    def test_exact_complex_coefficients(self):
        t = sp.Symbol("t")
        root = sp.CRootOf(t**3-t+1, 1)
        for generator in (sp.I, sp.sqrt(2)+sp.I, root):
            with self.subTest(generator=generator):
                field = sp.QQ.algebraic_field(generator)
                engine = ad._Engine(field)
                value = field.unit
                coefficients = engine.compose((field.one, value, field.zero, field.one),
                                              (field.zero, value, field.one))
                p = sp.Poly.from_dict({(i,): c for i, c in enumerate(coefficients)}, (x,), domain=field)
                self.assert_complete(p, ad.decompose(p, x))
                self.assertTrue(ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x))

    def test_root_bound_variable_matches_polynomial_variable(self):
        alpha = sp.CRootOf(x**5-x-1, 0)
        p = (x**2+alpha*x)**3 + alpha*(x**2+alpha*x) + 1
        chain = ad.decompose(p, x)
        self.assertTrue(ad.verify_decomposition(p, chain, x, require_complete=True, require_normalized=True))
        self.assertTrue(ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x))
        cancelled = (alpha**5-alpha-1)*x**6 + (x**2+x)**2
        self.assertEqual(ad.decompose(cancelled, x), [x**2, x**2+x])

    def test_conventions_and_options(self):
        self.assertEqual(ad.compose([], x), x)
        for p in (0, 7, sp.sqrt(3), x, 3*x+sp.I):
            with self.subTest(p=p):
                self.assertEqual(ad.decompose(p, x), [p])
                self.assertEqual(ad.decompositions(p, x), [[p]])
                self.assertTrue(ad.verify_decomposition(p, [p], x, require_complete=True))
                data = ad.decomposition_data(p, x)
                self.assertIsNone(data["indecomposable"])
                self.assertTrue(ad.verify_decomposition_data(p, data, x))
        self.assertTrue(ad.verify_decomposition(x, [], x))
        self.assertFalse(ad.verify_decomposition(x, [], x, require_complete=True))
        self.assertFalse(ad.verify_decomposition(x**6, [x**6], x, require_complete=True))
        self.assertTrue(ad.verify_decomposition(x**6, [x**3/8, 2*x**2], x, require_complete=True))
        self.assertFalse(ad.verify_decomposition(x**6, [x**3/8, 2*x**2], x, require_normalized=True))
        self.assertFalse(ad.verify_decomposition(x**6, [x**3, x, x**2], x, require_complete=True))
        self.assertFalse(ad.verify_decomposition(x**6, [x**2, x**2], x))

    def test_input_rejection(self):
        y = sp.Symbol("y")
        for p in (x**2 + 0.1, x**2 + sp.pi, x**2 + sp.E, x**2+y,
                  1/(x+1), sp.sqrt(x), sp.Poly(x**2+1, x, modulus=2), sp.oo*x+1):
            with self.subTest(p=p), self.assertRaises(ValueError):
                ad.decompose(p, x)
        for d in (0, 1, 4, 6, 7, 2.0, True):
            with self.subTest(d=d), self.assertRaises(ValueError):
                ad.right_decompose(x**6, x, d)
        with self.assertRaises(ValueError):
            ad.decompose(x**2, x+1)

    def test_generated_affine_normalization(self):
        rng = random.Random(206618)
        for generator in (sp.Integer(0), sp.sqrt(2), sp.I, sp.real_root(2, 3)):
            field = sp.QQ if generator == 0 else sp.QQ.algebraic_field(generator)
            for m, d in ((2, 2), (2, 3), (3, 4)):
                with self.subTest(generator=generator, degrees=(m, d)):
                    outer = sum((rng.randrange(-2, 3) + generator*rng.randrange(-1, 2))*x**j for j in range(m)) + x**m
                    inner = 2*x**d + sum(rng.randrange(-2, 3)*x**j for j in range(d)) + generator
                    p = sp.Poly(outer.subs(x, inner), x, domain=field)
                    actual_outer, actual_inner = ad.right_decompose(p, x, d)
                    self.assertTrue(sp.Poly(actual_inner - (inner-inner.subs(x, 0))/2, x, domain=field).is_zero)
                    self.assertTrue(sp.Poly(actual_outer-outer.subs(x, 2*x+inner.subs(x, 0)), x, domain=field).is_zero)
                    self.assertTrue(ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x))
                    self.assert_complete(p, ad.decompose(p, x))


class CertificateTests(unittest.TestCase):
    def test_positive_negative_and_exhaustive(self):
        for p in (QUESTION, x**16+x, x**12, (x**4+x)**2):
            with self.subTest(p=p):
                data = ad.decomposition_data(p, x)
                self.assertTrue(ad.verify_decomposition_data(p, data, x))
                for test in data["tests"]:
                    self.assertTrue(ad.verify_decomposition_data(p, test, x))
                    if not test["decomposable"]:
                        witness = test["obstruction"]
                        self.assertNotEqual(witness["coefficient"], 0)
                        self.assertGreater(witness["power"], 0)

    def test_independent_verifier(self):
        p = (x**4+x)**2
        data = ad.decomposition_data(p, x)
        with patch.object(ad._Engine, "candidate", side_effect=AssertionError("recurrence used")), \
             patch.object(ad._Engine, "divide_monic", side_effect=AssertionError("division used")), \
             patch.object(ad._Engine, "base_digits", side_effect=AssertionError("digit search used")), \
             patch.object(ad._Engine, "attempt", side_effect=AssertionError("search used")):
            self.assertTrue(ad.verify_decomposition_data(p, data, x))

    def test_short_circuit_and_portable_arithmetic(self):
        p = (x**4 + x)**2
        expected = ad.decomposition_data(p, x)
        # Exercise the exact-domain arithmetic even when FLINT is installed.
        with patch.object(ad, "fmpq", None):
            self.assertEqual(ad.decomposition_data(p, x), expected)
            self.assertTrue(ad.verify_decomposition_data(p, expected, x))
            self.assertEqual(ad.decompose(p, x), [x**2, x**4 + x])
        engine, (c,) = ad._prepare([x**120 + x], x)
        with patch.object(engine, "divide_monic", wraps=engine.divide_monic) as divide:
            self.assertIsNone(engine.attempt(c, 2))
            self.assertEqual(divide.call_count, 1)
        certificate = engine.certificate(c, 2, x)
        self.assertEqual(len(certificate["digits"]), 61)
        self.assertTrue(ad.verify_decomposition_data(x**120 + x, certificate, x))

    def test_fixed_degree_does_not_enumerate_divisors(self):
        with patch.object(ad, "_degrees", side_effect=AssertionError("divisors enumerated")):
            self.assertEqual(ad.right_decompose(x**12, x, 4), (x**3, x**4))
            data = ad.decomposition_data(x**12, x, 4)
            self.assertTrue(ad.verify_decomposition_data(x**12, data, x))

    def test_tampered_fixed_degree_certificates(self):
        p = (x**4+x)**2
        source = ad.decomposition_data(p, x, 2)
        modifications = {
            "right_degree": 4, "outer_degree": 3, "inner": x**2+x,
            "outer_candidate": source["outer_candidate"]+1, "digits": [0]*5,
            "decomposable": True, "obstruction": None, "residual": 0,
        }
        for key, value in modifications.items():
            with self.subTest(key=key):
                data = copy.deepcopy(source)
                data[key] = value
                self.assertFalse(ad.verify_decomposition_data(p, data, x))
        for key, value in (("digit_index", 0), ("power", 2), ("coefficient", 0)):
            data = copy.deepcopy(source)
            data["obstruction"][key] = value
            self.assertFalse(ad.verify_decomposition_data(p, data, x))
        for data in (None, {}, {"type": "DegreeTest"}):
            self.assertFalse(ad.verify_decomposition_data(p, data, x))
        for key in ("right_degree", "outer_degree"):
            data = copy.deepcopy(source)
            data[key] = float(data[key])
            self.assertFalse(ad.verify_decomposition_data(p, data, x))
        data = copy.deepcopy(source)
        data["inner"] = x**2 + sp.Float(0.0)
        # Explicit floating coefficient in a genuinely nonzero position.
        data["inner"] = 1.0*x**2
        self.assertFalse(ad.verify_decomposition_data(p, data, x))

    def test_exhaustiveness_cannot_be_forged(self):
        p = x**12+x
        source = ad.decomposition_data(p, x)
        for key, value in (("tests", source["tests"][:-1]),
                           ("tests", source["tests"][:-1]+[source["tests"][0]]),
                           ("tested_right_degrees", [2]), ("accepted_right_degrees", [2]),
                           ("indecomposable", False), ("input_degree", 6)):
            with self.subTest(key=key):
                data = copy.deepcopy(source)
                data[key] = value
                self.assertFalse(ad.verify_decomposition_data(p, data, x))
        for key in ("input_degree", "tested_right_degrees"):
            data = copy.deepcopy(source)
            data[key] = float(data[key]) if key == "input_degree" else [float(d) for d in data[key]]
            self.assertFalse(ad.verify_decomposition_data(p, data, x))


if __name__ == "__main__":
    unittest.main(verbosity=2)
