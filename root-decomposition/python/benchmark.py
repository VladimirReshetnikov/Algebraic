"""Time the article examples; add --full for the expensive many-factor search.

Reported times exclude the separate exact verification of each returned
identity. The Galois-data and explicitly cached searches run in that order.
"""
import argparse
import time
import rootdecomp as rd

ap = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
as_ = rd.parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")
ext = rd.parse_wolfram_root("Root[4 - 8 #^2 - 16 #^4 - 4 #^6 + #^8 &, 4]")
s6 = rd.parse_wolfram_root("Root[-1 + 4 #^2 + #^6 &, 3]")

def timeit(label, fn, target=None):
    t0 = time.perf_counter()
    r = fn()
    elapsed = time.perf_counter() - t0
    if target is not None and (r is None or not rd.verify_exact(target, r)):
        raise AssertionError(f"{label}: the returned identity failed exact verification")
    print(f"{label}: {elapsed:.2f} s  -> {r if not hasattr(r, 'order') else 'order ' + str(r.order)}", flush=True)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full", action="store_true", help="also time the product search for the sum example")
    args = parser.parse_args()
    timeit("product example, fast path", lambda: rd.product_decomposition(ap), ap)
    timeit("sum example, fast path", lambda: rd.sum_decomposition(as_), as_)
    timeit("splitting-field data of the product example (|G|=36)", lambda: rd.galois_data(ap.poly))
    timeit("D+(product root) with cached data", lambda: rd.sum_decomposition(ap, engine="splitting"), ap)
    timeit("sqrt((1+sqrt2)(1+sqrt3)) two-factor with t=2 (|G|=16)", lambda: rd.product_decomposition(ext, engine="splitting"), ext)
    timeit("x^4-x-1 pair sum (|G|=24)", lambda: rd.sum_decomposition(s6, engine="splitting"), s6)
    if args.full:
        timeit("product of sum root, unrestricted heuristic", lambda: rd.product_decomposition(as_), as_)


if __name__ == "__main__":
    main()
