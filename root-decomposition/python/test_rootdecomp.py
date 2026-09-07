"""Regression tests and timings for rootdecomp.py (run: python test_rootdecomp.py)."""
import time
from fractions import Fraction

from flint import fmpz_poly

import rootdecomp as rd


def alg(s):
    return rd.parse_wolfram_root(s)


def run(label, fn, a, expect_max=None, **kw):
    t0 = time.perf_counter()
    r = fn(a, **kw)
    dt = time.perf_counter() - t0
    ok = rd.verify_numeric(a, r) if r is not None else None
    if expect_max == "none":
        status = "OK" if r is None else "CHECK"
    else:
        status = "OK" if (r is not None and (expect_max is None or r.max_degree == expect_max) and ok) else "CHECK"
    print(f"[{status}] {label} ({dt:.2f} s): {r}  numeric={ok}")
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

run("product example", rd.product_decomposition, ap, 3)
run("sum example", rd.sum_decomposition, as_, 3)
run("sum of product root", rd.sum_decomposition, ap, 6)
run("sum of product root in Q(a)", rd.sum_decomposition, ap, 9, scope="InputField")
run("sqrt2+sqrt3+sqrt6 sum", rd.sum_decomposition, e3, 2)
run("sqrt2+sqrt3+sqrt6 sum, two terms", rd.sum_decomposition, e3, "none", dmax=3, max_terms=2)
run("sqrt2+sqrt3+sqrt6 product", rd.product_decomposition, e3, 4)
run("eta product", rd.product_decomposition, eta, 2)
run("eta two factors", rd.product_decomposition, eta, 4, max_factors=2)
run("w product", rd.product_decomposition, w, None)
run("1+r2+r3 sum", rd.sum_decomposition, q, 2)
run("1+r2+r3 product", rd.product_decomposition, q, 4)
run("sqrt((1+r2)(1+r3)) product", rd.product_decomposition, ext, 4)
run("sqrt((1+r2)(1+r3)) sum", rd.sum_decomposition, ext, 8)
run("zeta5 sum", rd.sum_decomposition, z5, 4)
run("x^4-x-1 pair sum", rd.sum_decomposition, s6, 4)
run("x^4-x-1 pair sum in Q(a)", rd.sum_decomposition, s6, 6, scope="InputField")
run("product of sum root", rd.product_decomposition, as_, 9)
