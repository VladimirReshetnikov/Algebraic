"""Regression tests and timings for rootdecomp.py (run: python test_rootdecomp.py)."""
import time
import unittest
import random
from unittest.mock import patch
from fractions import Fraction

from flint import acb, arb, ctx, fmpq, fmpz_poly

import rootdecomp as rd


def alg(s):
    return rd.parse_wolfram_root(s)


def run(label, fn, a, expect_max=None, **kw):
    t0 = time.perf_counter()
    r = fn(a, **kw)
    dt = time.perf_counter() - t0
    ok = rd.verify_exact(a, r) if r is not None else None
    if expect_max == "none":
        status = "OK" if r is None else "CHECK"
    else:
        status = "OK" if (r is not None and (expect_max is None or r.max_degree == expect_max) and ok) else "CHECK"
    print(f"[{status}] {label} ({dt:.2f} s): {r}  exact={ok}", flush=True)
    if status != "OK":
        raise AssertionError(f"{label}: expected maximum degree {expect_max}, got {r}; exact={ok}")
    if r is not None:
        assert r.degrees == [term.degree for term in r.terms]
        assert r.max_degree == max(r.degrees)
        assert r.lower_bound <= r.max_degree
        assert not r.optimal or r.scope_optimal
        if kw.get("dmax") is not None:
            assert r.max_degree <= kw["dmax"]
        limit = kw.get("max_terms") if r.op == "Plus" else kw.get("max_factors")
        if limit is not None:
            assert len(r.terms) <= limit
    return r


ap = alg("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
as_ = alg("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")
e3 = alg("Root[-23 - 48 # - 22 #^2 + #^4 &, 4]")          # sqrt2+sqrt3+sqrt6
eta = alg("Root[4096 + 4096 # - 16384 #^2 + 6144 #^3 + 3008 #^4 - 768 #^5 - 256 #^6 - 8 #^7 + #^8 &, 8]")  # (1+r2)(1+r3)(1+r5)
w = alg("Root[100 - 200 # + 128 #^2 - 28 #^3 + #^4 &, 4]")   # (1+r2)(1+r3)(1+r6)
q = alg("Root[-8 + 16 # - 4 #^2 - 4 #^3 + #^4 &, 4]")        # 1+r2+r3
ext = alg("Root[4 - 8 #^2 - 16 #^4 - 4 #^6 + #^8 &, 4]")     # sqrt((1+r2)(1+r3))
s6 = alg("Root[-1 + 4 #^2 + #^6 &, 3]")                     # pair sum of roots of x^4-x-1
z5 = alg("Root[1 + # + #^2 + #^3 + #^4 &, 4]")

class ArticleExamples(unittest.TestCase):
    def test_examples(self):
        cases = [
            ("product example", rd.product_decomposition, ap, 3, {}),
            ("sum example", rd.sum_decomposition, as_, 3, {}),
            ("sum of product root", rd.sum_decomposition, ap, 6, {}),
            ("sum of product root in Q(a)", rd.sum_decomposition, ap, 9, {"scope": "InputField"}),
            ("sqrt2+sqrt3+sqrt6 sum", rd.sum_decomposition, e3, 2, {}),
            ("sqrt2+sqrt3+sqrt6 sum, two terms", rd.sum_decomposition, e3, "none", {"dmax": 3, "max_terms": 2}),
            ("sqrt2+sqrt3+sqrt6 product", rd.product_decomposition, e3, 4, {}),
            ("eta product", rd.product_decomposition, eta, 2, {}),
            ("eta two factors", rd.product_decomposition, eta, 4, {"max_factors": 2}),
            ("w product", rd.product_decomposition, w, 2, {}),
            ("1+r2+r3 sum", rd.sum_decomposition, q, 2, {}),
            ("1+r2+r3 product", rd.product_decomposition, q, 4, {}),
            ("sqrt((1+r2)(1+r3)) product", rd.product_decomposition, ext, 4, {}),
            ("sqrt((1+r2)(1+r3)) sum", rd.sum_decomposition, ext, 8, {}),
            ("zeta5 sum", rd.sum_decomposition, z5, 4, {}),
            ("x^4-x-1 pair sum", rd.sum_decomposition, s6, 4, {}),
            ("x^4-x-1 pair sum in Q(a)", rd.sum_decomposition, s6, 6, {"scope": "InputField"}),
            ("product of sum root", rd.product_decomposition, as_, 9, {}),
        ]
        for label, fn, target, degree, options in cases:
            with self.subTest(label=label):
                run(label, fn, target, degree, **options)


class CorrectnessRegressions(unittest.TestCase):
    def test_precision_retry_context_limits_and_exception_filter(self):
        with ctx.workprec(97):
            attempts = []
            def succeeds(prec):
                attempts.append(prec)
                self.assertEqual(ctx.prec, prec)
                if prec < 80:
                    raise rd.PrecisionError("retry")
                return "done"
            self.assertEqual(rd._retry_precision(succeeds, 20, "exhausted"), "done")
            self.assertEqual(attempts, [20, 40, 80])
            self.assertEqual(ctx.prec, 97)
            attempts.clear()
            def fails(prec):
                attempts.append(prec)
                self.assertEqual(ctx.prec, prec)
                raise ValueError("invalid")
            with self.assertRaisesRegex(ValueError, "invalid"):
                rd._retry_precision(fails, 20, "exhausted")
            self.assertEqual(attempts, [20])
            self.assertEqual(ctx.prec, 97)
            attempts.clear()
            with self.assertRaisesRegex(rd.PrecisionError, "exhausted"):
                rd._retry_precision(fails, 20, "exhausted", (ValueError, rd.PrecisionError))
            self.assertEqual(attempts, [20, 40, 80, 160, 320, 640])
            self.assertEqual(ctx.prec, 97)

    def test_galois_retry_preserves_random_state(self):
        draws = []
        def build(poly, prec, maxorder, rng):
            draws.append(rng.randrange(10 ** 6))
            if len(draws) < 3:
                raise rd.PrecisionError("retry")
            return "built"
        with patch.object(rd, "_build_at_precision", side_effect=build):
            self.assertEqual(rd.build_galois_data(fmpz_poly([-2, 0, 1]), seed=123), "built")
        rng = random.Random(123)
        self.assertEqual(draws, [rng.randrange(10 ** 6) for _ in range(3)])

    def test_prime_degree_bound_needs_no_modular_factorization(self):
        polynomial = fmpz_poly([-2] + [0] * 30 + [1])  # Eisenstein: degree 31.
        rd._lower_bound_cached.cache_clear()
        with patch.object(rd, "frobenius_exponent_multiple", side_effect=AssertionError("bound is already sharp")):
            self.assertEqual(rd.lower_bound(polynomial), 31)

    def test_shared_group_and_frobenius_helpers(self):
        cyclic_four = [[(i + j) % 4 for j in range(4)] for i in range(4)]
        self.assertEqual(rd.group_closure(cyclic_four, 0, []), frozenset({0}))
        self.assertEqual(rd.group_closure(cyclic_four, 0, [2]), frozenset({0, 2}))
        self.assertEqual(rd.group_closure(cyclic_four, 0, [1]), frozenset(range(4)))
        edges = []
        self.assertEqual(rd.group_closure(cyclic_four, 0, [1], lambda *edge: edges.append(edge)), frozenset(range(4)))
        self.assertEqual(edges, [(0, 1, 1), (1, 1, 2), (2, 1, 3)])
        self.assertEqual(len(rd._subgroup_lattice(cyclic_four, 0, 4)), 3)
        golden_ratio = fmpz_poly([-1, -1, 1])
        self.assertEqual(list(rd.frobenius_cycle_types(golden_ratio, 4)), [[2], [2], [2], [1, 1]])
        self.assertEqual(list(rd.frobenius_cycle_types(golden_ratio, 2, start_prime=7)), [[2], [1, 1]])
        self.assertEqual(rd.frobenius_exponent_multiple(golden_ratio), 2)
        self.assertEqual(list(rd.frobenius_cycle_types(golden_ratio, 0)), [])
        with self.assertRaises(ValueError):
            list(rd.frobenius_cycle_types(fmpz_poly([1, -2, 1])))

    def test_automorphisms_preserve_field_multiplication(self):
        # Check multiplication on the whole basis, independently of generator propagation.
        gd = rd.galois_data(fmpz_poly([-1, -1, 0, 0, 1]), 300, 24)
        with ctx.workprec(gd.prec):
            root_matrices = [rd.multiplication_matrix_of(gd, v) for v in gd.root_coords]
        one = [fmpq(i == 0) for i in range(gd.order)]
        for action, perm in zip(gd.automorphisms, gd.perms):
            self.assertEqual(rd.apply_matrix(action, one), one)
            for i, j in enumerate(perm):
                self.assertEqual(action * root_matrices[i], root_matrices[j] * action)
        index = {p: i for i, p in enumerate(gd.perms)}
        noncommuting = False
        for s, left in enumerate(gd.perms):
            for t, right in enumerate(gd.perms):
                product = tuple(left[right[i]] for i in range(len(left)))
                noncommuting |= product != tuple(right[left[i]] for i in range(len(left)))
                self.assertEqual(gd.automorphisms[s] * gd.automorphisms[t], gd.automorphisms[index[product]])
        self.assertTrue(noncommuting)
        trivial = rd.galois_data(fmpz_poly([-2, 1]))
        self.assertEqual(trivial.order, 1)
        self.assertEqual(trivial.automorphisms[0].tolist(), [[1]])

    def test_degree_bounds_and_single_component(self):
        for fn, name in ((rd.sum_decomposition, "max_terms"), (rd.product_decomposition, "max_factors")):
            with self.subTest(operation=fn.__name__):
                self.assertIsNone(fn(z5, dmax=3))
                self.assertIsNone(fn(ap, dmax=2))
                self.assertIsNone(fn(ap, dmax=8, **{name: 1}))
                result = fn(ap, **{name: 1})
                self.assertEqual(len(result.terms), 1)
                self.assertTrue(result.scope_optimal)
                self.assertFalse(result.optimal)

    def test_affine_two_term_sum(self):
        result = run("two affine quadratic summands", rd.sum_decomposition, q, 2, max_terms=2)
        self.assertEqual(len(result.terms), 2)

    def test_constrained_optimality(self):
        result = rd.sum_decomposition(e3, max_terms=2)
        self.assertEqual(result.max_degree, 4)
        self.assertTrue(result.scope_optimal)
        self.assertFalse(result.optimal)
        result = rd.sum_decomposition(ap, engine="input")
        self.assertFalse(result.scope_optimal)
        self.assertFalse(result.optimal)
        result = rd.sum_decomposition(ap, scope="InputField")
        self.assertTrue(result.scope_optimal)
        self.assertFalse(result.optimal)
        result = rd.sum_decomposition(as_, dmax=3)
        self.assertTrue(result.optimal)
        result = rd.product_decomposition(eta, max_factors=2)
        self.assertTrue(result.extra["two_factor_optimal"])
        self.assertTrue(result.scope_optimal)
        self.assertFalse(result.optimal)
        self.assertFalse(rd.product_decomposition(e3).scope_optimal)

    def test_tensor_below_binary_degree_bound(self):
        result = run("tensor below binary degree bound", rd.product_decomposition, eta, 2,
                     max_factors=3, depth=0)
        self.assertEqual(result.method, "TensorRankOne")
        self.assertEqual(len(result.terms), 3)
        self.assertTrue(result.scope_optimal)
        result = run("tensor with explicit degree bound", rd.product_decomposition, eta, 2,
                     dmax=2, max_factors=3, depth=0)
        self.assertEqual(len(result.terms), 3)
        self.assertIsNone(rd.product_decomposition(eta, dmax=2, max_factors=2))

    def test_tensor_mixed_degrees_and_singular_basis(self):
        target = rd.AlgebraicNumber(fmpz_poly([-72, 0, 0, 0, 0, 0, 1]), 2)
        fd = rd.input_field_data(target.poly, target)
        fields = [next(h for h in fd.subgroups if h["index"] == d) for d in (2, 3)]
        va = [fmpq(0), fmpq(1)] + [fmpq(0)] * 4
        for family in (fields, fields[::-1]):
            factors = rd.tensor_test(fd, family, va, {})
            self.assertIsNotNone(factors)
            product = [fmpq(1)] + [fmpq(0)] * 5
            for factor in factors:
                product = rd.apply_matrix(fd.mult_matrix(factor), product)
            self.assertEqual(product, va)
            self.assertIsNone(rd.tensor_test(fd, family, [fmpq(1)] + va[1:], {}))
        self.assertIsNone(rd.tensor_test(fd, [fields[0]] * 2, va, {}))
        # Three quadratic fields have the right product of dimensions, but
        # a repeated field spans only a proper subspace of the degree-eight field.
        fd8 = rd.input_field_data(eta.poly, eta)
        quadratic = next(h for h in fd8.subgroups if h["index"] == 2)
        self.assertIsNone(rd.tensor_test(fd8, [quadratic] * 3, [fmpq(0), fmpq(1)] + [fmpq(0)] * 6, {}))

    def test_galois_tensor_filters_and_inconclusive_balls(self):
        # The cubic fixed field is not normal in this S3 splitting field.
        gd = rd.galois_data(fmpz_poly([-2, 0, 0, 1]))
        family = [next(h for h in gd.subgroups if h["index"] == d) for d in (2, 3)]
        with ctx.workprec(gd.prec):
            factors = [h["fixed"][-1] for h in family]
            target = [q / 7 for q in rd.apply_matrix(rd.fd_mult_matrix(gd, factors[0]), factors[1])]
            for fields in (family, family[::-1]):
                self.assertTrue(rd._tensor_conjugates_possible(gd, fields, target, {}))
                result = rd.tensor_test(gd, fields, target, {})
                self.assertIsNotNone(result)
                self.assertEqual(rd.apply_matrix(rd.fd_mult_matrix(gd, result[0]), result[1]), target)
            shifted = list(target)
            shifted[0] += 1
            self.assertFalse(rd._tensor_conjugates_possible(gd, family, shifted, {}))
            with patch.object(rd, "fd_mult_matrix", side_effect=AssertionError("rejected tensor must not build matrices")):
                self.assertIsNone(rd.tensor_test(gd, family, shifted, {}))
                self.assertIsNone(rd.tensor_test(gd, [family[0]] * 2, shifted, {}))
            # A perturbation below the ball precision must reach the exact
            # rational tensor test, which can still reject its nonzero minors.
            tiny_shift = list(target)
            tiny_shift[0] += fmpq(1, 2 ** (2 * gd.prec))
            self.assertTrue(rd._tensor_conjugates_possible(gd, family, tiny_shift, {}))
            with patch.object(rd, "fd_mult_matrix", wraps=rd.fd_mult_matrix) as exact_matrices:
                self.assertIsNone(rd.tensor_test(gd, family, tiny_shift, {}))
                self.assertGreater(exact_matrices.call_count, 0)
        gd4 = rd.galois_data(fmpz_poly([1, 0, 0, 0, 1]))
        quadratic = next(h for h in gd4.subgroups if h["index"] == 2)
        with patch.object(rd, "fd_mult_matrix", side_effect=AssertionError("proper compositum must not build matrices")):
            self.assertIsNone(rd.tensor_test(gd4, [quadratic] * 2, gd4.root_coords[0], {}))

    def test_bounded_fallback_with_explicit_bound(self):
        result = run("bounded fallback with explicit bound", rd.product_decomposition, w, 2,
                     dmax=2, max_factors=3)
        self.assertEqual(len(result.terms), 3)

    def test_input_field_does_not_extract_external_radicals(self):
        # A Galois input field still must honor the request to keep its factors
        # in that field: norm exponent one is the applicable scoped search.
        target = alg("Root[1 - 10 #^2 + #^4 &, 4]")
        for engine in ("input", "splitting"):
            result = rd.product_decomposition(target, scope="InputField", engine=engine, max_factors=2)
            self.assertEqual(result.extra["t"], 1)
            self.assertTrue(rd.verify_exact(target, result))
        # The degree-eight example has no proper factorization inside Q(a).
        result = run("external example restricted to input field", rd.product_decomposition,
                     ext, 8, scope="InputField", max_factors=2)
        self.assertEqual(result.extra["t"], 1)

    def test_bounded_scope_optimality(self):
        target = alg("Root[1 - 10 #^2 + #^4 &, 4]")
        result = rd.bounded_decomposition(target, "Plus", 4, 3, 2)
        self.assertFalse(result.scope_optimal)
        self.assertTrue(rd.bounded_decomposition(target, "Plus", 4, 3, 1).scope_optimal)
        result = rd.bounded_decomposition(w, "Times", 2, 2, 3)
        self.assertTrue(result.optimal)
        self.assertTrue(result.scope_optimal)
        with patch.object(rd, "catalog", side_effect=AssertionError("impossible box must not be enumerated")):
            self.assertIsNone(rd.bounded_decomposition(ap, "Plus", 8, 10 ** 6, 1))

    def test_galois_cache_scale_and_resource_limit(self):
        integer = fmpz_poly([-2, 0, 1])
        fractional = fmpz_poly([-1, 0, 2])
        self.assertEqual(rd.galois_data(integer).scale, 1)
        self.assertEqual(rd.galois_data(fractional).scale, 2)
        with self.assertRaises(ValueError):
            rd.galois_data(integer, maxorder=1)
        target = rd.AlgebraicNumber(fractional, 2)
        self.assertTrue(rd.verify_exact(target, rd.sum_decomposition(target, engine="splitting")))

    def test_conjugate_coordinates_roundtrip_and_low_precision(self):
        gd = rd.galois_data(fmpz_poly([-1, -1, 0, 0, 1]))
        vectors = [gd.root_coords[0], [fmpq(i - 1, i + 1) for i in range(gd.order)]]
        for vector in vectors:
            integers, denominator = rd._clear_denominators(vector)
            with ctx.workprec(gd.prec):
                reference = rd.conj_vector(gd, vector)
                restored = rd.coords_from_conjugates(gd, [z * denominator for z in reference])
                self.assertEqual([q / denominator for q in restored], vector)
            for precision in (16, 32, 64):
                with ctx.workprec(precision):
                    low = rd.conj_vector(gd, vector)
                    self.assertTrue(all(a.overlaps(b) for a, b in zip(low, reference)))
                    # Insufficient precision may fail certification, but must
                    # never reconstruct a different exact coordinate vector.
                    try:
                        restored = rd.coords_from_conjugates(gd, [z * denominator for z in low])
                    except rd.PrecisionError:
                        continue
                    self.assertEqual(restored, [fmpq(x) for x in integers])

    def test_input_validation(self):
        rd.catalog(1, 1)
        for degree, height in ((True, 1), (1, True), (0, 1), (1, -1)):
            with self.subTest(catalog=(degree, height)), self.assertRaises(ValueError):
                rd.catalog(degree, height)
        for polynomial in ([0], [1], [-1, 0, 1], [1, -2, 1]):
            with self.subTest(polynomial=polynomial), self.assertRaises(ValueError):
                rd.AlgebraicNumber(fmpz_poly(polynomial), 1)
        for index in (0, 3, -1, 1.5, True):
            with self.subTest(index=index), self.assertRaises(ValueError):
                rd.AlgebraicNumber(fmpz_poly([-2, 0, 1]), index)
        for text in ("Root[-2+#junk^2&,1]", "Root[-2+#^2foo&,1]", "Root[&,1]"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                alg(text)
        for fn, options in ((rd.sum_decomposition, {"max_terms": 0}),
                            (rd.product_decomposition, {"max_factors": -1}),
                            (rd.sum_decomposition, {"dmax": 0}),
                            (rd.sum_decomposition, {"scope": "typo"}),
                            (rd.product_decomposition, {"engine": "typo"})):
            with self.subTest(options=options), self.assertRaises(ValueError):
                fn(ap, **options)
        with self.assertRaises(ValueError):
            rd.lower_bound(fmpz_poly([1, -2, 1]))

    def test_arithmetic_and_exact_verifier(self):
        two = rd.AlgebraicNumber.from_rational(2)
        three = rd.AlgebraicNumber.from_rational(3)
        zero = rd.AlgebraicNumber.from_rational(0)
        self.assertEqual(rd.combine_algebraic(two, three, "+").as_fraction(), 5)
        self.assertEqual(rd.combine_algebraic(two, three, "/").as_fraction(), Fraction(2, 3))
        self.assertEqual(rd.scale_algebraic(ap, Fraction(0), 200).as_fraction(), 0)
        with self.assertRaises(ZeroDivisionError):
            rd.combine_algebraic(two, zero, "/")
        with self.assertRaises(ValueError):
            rd.combine_algebraic(two, three, "typo")
        wrong = rd.Decomposition("Plus", [three], [1], 1, 1, False, False, "Global", "Test")
        self.assertFalse(rd.verify_exact(two, wrong))
        one = rd.AlgebraicNumber.from_rational(1)
        near_one = rd.AlgebraicNumber.from_rational(1 + Fraction(1, 2 ** 400))
        close = rd.Decomposition("Plus", [near_one], [1], 1, 1, False, False, "Global", "Test")
        self.assertTrue(rd.verify_numeric(one, close, 160))
        self.assertFalse(rd.verify_exact(one, close, 160))
        p = fmpz_poly([-2, 0, 1])
        with self.assertRaises(rd.PrecisionError):
            rd.AlgebraicNumber.from_value(p, acb(arb(0, 2)), 100)

    def test_affine_arithmetic_preserves_real_and_complex_branches(self):
        for coefficients in ([-2, 0, 1], [-2, 0, 0, 1], [25, 0, -2, 0, 1]):
            polynomial = fmpz_poly(coefficients)
            for index in range(1, polynomial.degree() + 1):
                target = rd.AlgebraicNumber(polynomial, index)
                self.assertEqual(rd.scale_algebraic(target, 0, 160).as_fraction(), 0)
                for scale in (Fraction(2, 3), Fraction(-5, 7)):
                    with ctx.workprec(200):
                        value = target.value(200) * rd._fmpq_to_acb(fmpq(scale.numerator, scale.denominator))
                        scaled = rd.scale_algebraic(target, scale, 200)
                        expected = rd.AlgebraicNumber.from_value(scaled.poly, value, 200)
                        self.assertEqual(scaled.index, expected.index)
                        if scale > 0:
                            self.assertEqual(scaled.index, index)
                        shift = Fraction(11, 13)
                        translated = rd.combine_algebraic(scaled, rd.AlgebraicNumber.from_rational(shift), "+")
                        value += rd._fmpq_to_acb(fmpq(11, 13))
                        expected = rd.AlgebraicNumber.from_value(translated.poly, value, 200)
                        self.assertEqual(translated.index, expected.index)
                        self.assertEqual(translated.poly, rd._affine_polynomial(polynomial, scale, shift))
        self.assertEqual(rd.primitive(fmpz_poly()), fmpz_poly())
        self.assertEqual(rd.primitive(fmpz_poly([12, -18])), fmpz_poly([-2, 3]))
        self.assertEqual(rd.poly_from_fractions([Fraction(2, 3), Fraction(-1, 2)]), fmpz_poly([-4, 3]))

    def test_complex_roots_and_precision_stability(self):
        for coeffs in ([25, 0, -2, 0, 1], [6, 0, 5, 0, 1]):
            p = fmpz_poly(coeffs)
            low, high = rd.poly_roots(p, 160), rd.poly_roots(p, 300)
            self.assertTrue(all(x.overlaps(y) for x, y in zip(low, high)))
            self.assertTrue(all(low[i].imag < 0 and low[i + 1].imag > 0 for i in range(0, 4, 2)))
        for index in range(1, 5):
            target = rd.AlgebraicNumber(fmpz_poly([25, 0, -2, 0, 1]), index)
            result = rd.sum_decomposition(target, max_terms=2)
            self.assertEqual(result.max_degree, 2)
            self.assertTrue(rd.verify_exact(target, result))
        # Both positive roots round to the same binary64 number.
        m = 10 ** 30
        p = fmpz_poly([m * m - 2, -2 * m, 1])
        with ctx.workprec(300):
            roots = rd.poly_roots(p, 300)
            self.assertTrue(roots[0].real < roots[1].real)


if __name__ == "__main__":
    unittest.main(verbosity=2)
