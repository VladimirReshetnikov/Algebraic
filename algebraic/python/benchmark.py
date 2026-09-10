"""Time the article examples of all three operations.

    python benchmark.py                 # the standard set
    python benchmark.py --full          # add the expensive searches
    python benchmark.py --group radicals

Reported times exclude input construction and the separate exact verification
of each returned identity, both of which happen outside the timed call.  This
merges the two benchmark scripts the separate projects carried and adds the
radical descent, which had none.
"""

from __future__ import annotations

import argparse
import time

import sympy as sp

from algebraic import polynomial_decomposition as ad
from algebraic import radicals as rt
from algebraic import root_decomposition as rd

X = sp.Symbol("x")


def timeit(label, fn, check=None):
    start = time.perf_counter()
    value = fn()
    elapsed = time.perf_counter() - start
    if check is not None and not check(value):
        raise AssertionError(f"{label}: the returned result failed its check")
    shown = value if len(str(value)) <= 90 else str(value)[:87] + "..."
    print(f"  {elapsed:8.2f} s  {label}: {shown}", flush=True)
    return value


def group_polynomial(full):
    print("functional decomposition of polynomials")
    s = sp.sqrt(2)
    p = (3 + 3*s + (14 + 4*s)*X + (12 + 26*s)*X**2 + (56 + 8*s)*X**3
         + (8 + 48*s)*X**4 + 48*X**5 + 16*s*X**6)
    timeit("question sextic, one chain", lambda: ad.decompose(p, X),
           lambda c: ad.verify_decomposition(p, c, X, require_complete=True))
    timeit("question sextic, all chains", lambda: ad.decompositions(p, X))
    q = sp.expand(p.subs(X, X**4 - X + 1))
    timeit("degree 24, one chain", lambda: ad.decompose(q, X),
           lambda c: ad.verify_decomposition(q, c, X, require_complete=True))
    timeit("Chebyshev T_12, all chains", lambda: ad.decompositions(sp.chebyshevt(12, X), X))
    if full:
        r = sp.expand(sp.chebyshevt(96, X))
        timeit("Chebyshev T_96, one chain", lambda: ad.decompose(r, X))


def group_decomposition(full):
    print("sums and products of algebraic numbers")
    ap = rd.parse_wolfram_root("Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1]")
    asum = rd.parse_wolfram_root("Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1]")
    ext = rd.parse_wolfram_root("Root[4 - 8 #^2 - 16 #^4 - 4 #^6 + #^8 &, 4]")
    s6 = rd.parse_wolfram_root("Root[-1 + 4 #^2 + #^6 &, 3]")
    timeit("product example, fast path", lambda: rd.product_decomposition(ap),
           lambda r: rd.verify_exact(ap, r))
    timeit("sum example, fast path", lambda: rd.sum_decomposition(asum),
           lambda r: rd.verify_exact(asum, r))
    timeit("splitting-field data of the product example (|G| = 36)",
           lambda: rd.galois_data(ap.poly), lambda g: g.order == 36)
    timeit("D+(product root) with cached data",
           lambda: rd.sum_decomposition(ap, engine="splitting"), lambda r: rd.verify_exact(ap, r))
    timeit("sqrt((1+sqrt2)(1+sqrt3)) two-factor with t = 2 (|G| = 16)",
           lambda: rd.product_decomposition(ext, engine="splitting"),
           lambda r: rd.verify_exact(ext, r))
    timeit("x^4-x-1 pair sum (|G| = 24)",
           lambda: rd.sum_decomposition(s6, engine="splitting"), lambda r: rd.verify_exact(s6, r))
    if full:
        timeit("product of the sum root, unrestricted heuristic",
               lambda: rd.product_decomposition(asum), lambda r: rd.verify_exact(asum, r))


def group_radicals(full):
    print("radical expressions")
    for label, syntax, options in [
        ("sextic, structural", "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]", {}),
        ("sextic, by descent", "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]", {"method": "galois"}),
        ("quintic, structural", "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]", {}),
        ("quintic, by descent", "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]", {"method": "galois"}),
        ("cyclic quintic", "Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 1]", {}),
        ("Phi_7 by descent", "Root[1 + # + #^2 + #^3 + #^4 + #^5 + #^6 &, 3]", {"method": "galois"}),
    ]:
        a = rd.parse_wolfram_root(syntax)
        timeit(f"{label} ({options.get('method', 'auto')})",
               lambda a=a, o=options: rt.root_to_radicals(a, **o),
               lambda r: r.verified)
    if full:
        a = rd.parse_wolfram_root("Root[-1 - # + #^4 &, 1]")
        timeit("x^4-x-1 by descent", lambda: rt.root_to_radicals(a, method="galois"),
               lambda r: r.verified)


GROUPS = {"polynomial": group_polynomial, "decomposition": group_decomposition,
          "radicals": group_radicals}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--group", action="append", choices=sorted(GROUPS) + ["all"],
                        help="time one group (repeatable); the default is all")
    parser.add_argument("--full", action="store_true",
                        help="also run the expensive searches")
    args = parser.parse_args()
    groups = args.group or ["all"]
    if "all" in groups:
        groups = ["polynomial", "decomposition", "radicals"]
    for name in dict.fromkeys(groups):
        GROUPS[name](args.full)


if __name__ == "__main__":
    main()
