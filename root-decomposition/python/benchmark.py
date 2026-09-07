"""Timing of the Python implementation on the examples of the article (run: python benchmark.py)."""
import time
import rootdecomp as rd

ap = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
as_ = rd.parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")
ext = rd.parse_wolfram_root("Root[4 - 8 #^2 - 16 #^4 - 4 #^6 + #^8 &, 4]")
s6 = rd.parse_wolfram_root("Root[-1 + 4 #^2 + #^6 &, 3]")

def timeit(label, fn):
    t0 = time.perf_counter()
    r = fn()
    print(f"{label}: {time.perf_counter() - t0:.2f} s  -> {r if not hasattr(r, 'order') else 'order ' + str(r.order)}")

timeit("product example, fast path", lambda: rd.product_decomposition(ap))
timeit("sum example, fast path", lambda: rd.sum_decomposition(as_))
timeit("splitting-field data of the product example (|G|=36)", lambda: rd.galois_data(ap.poly))
timeit("D+(product root) with cached data", lambda: rd.sum_decomposition(ap, engine="splitting"))
timeit("sqrt((1+sqrt2)(1+sqrt3)) two-factor with t=2 (|G|=16)", lambda: rd.product_decomposition(ext, engine="splitting"))
timeit("x^4-x-1 pair sum (|G|=24)", lambda: rd.sum_decomposition(s6, engine="splitting"))
