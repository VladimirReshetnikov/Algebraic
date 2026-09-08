"""Reproducible exact polynomial-decomposition timings.

Run python benchmark.py, optionally --full for degree-96 and larger enumeration.
Input construction and independent identity/completeness checks are outside
the reported search time. The first example includes coefficient conversion;
the others pass an existing exact Poly to reuse its coefficient field.
"""

import argparse
import importlib.util
from pathlib import Path
import statistics
import sys
import time

import sympy as sp

import algebraic_decompose as ad


def timed(label, p, x, *, enumerate_all=False):
    start = time.perf_counter()
    chains = ad.decompositions(p, x) if enumerate_all else [ad.decompose(p, x)]
    elapsed = time.perf_counter() - start
    for chain in chains:
        if not ad.verify_decomposition(p, chain, x, require_complete=True, require_normalized=True):
            raise AssertionError(f"{label}: invalid complete normalized chain")
    degrees = [int(sp.degree(component, x)) for component in chains[0]]
    print(f"{label}: {elapsed:.6f} s; {len(chains)} chain(s), first degrees {degrees}; exact checks passed", flush=True)


def compare_report01(x):
    """Compare identical QQ vectors; neither timing includes field creation."""
    source = Path(__file__).resolve().parents[1] / "reports/report-01/Reference/exact_decomposition.py"
    spec = importlib.util.spec_from_file_location("archived_decomposition_reference", source)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    # Read-only loading: do not create a __pycache__ inside the archived report.
    exec(compile(source.read_text(encoding="utf-8"), str(source), "exec"), module.__dict__)
    coefficients = (sp.QQ.one, sp.QQ.one) + (sp.QQ.zero,) * 94 + (sp.QQ.one,)
    timings = {}
    for label, factory in (("report01", lambda: module.ExactDecomposer(sp.QQ)),
                           ("live", lambda: ad._Engine(sp.QQ))):
        samples = []
        for _ in range(7):
            engine = factory()  # fresh local caches for every measured search
            start = time.perf_counter()
            result = engine.pairs(coefficients)
            samples.append(time.perf_counter() - start)
            if result:
                raise AssertionError("x^96+x+1 must have no nontrivial decomposition pairs")
        timings[label] = statistics.median(samples)
        print(f"QQ all-pairs of x^96+x+1, {label}: median {timings[label]:.6f} s over 7 fresh searches", flush=True)
    print(f"This sparse workload: {timings['report01']/timings['live']:.2f}x; coefficient conversion excluded", flush=True)
    p = x**96+x+1
    if not ad.verify_decomposition_data(p, ad.decomposition_data(p, x), x):
        raise AssertionError("independent exhaustive certificate verification failed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--compare-report01", action="store_true", help="compare identical sparse rational all-pairs workloads")
    args = parser.parse_args()
    x, r = sp.Symbol("x"), sp.sqrt(2)
    question = 3+3*r+(14+4*r)*x+(12+26*r)*x**2+(56+8*r)*x**3+(8+48*r)*x**4+48*x**5+16*r*x**6
    timed("question sextic, expression input", question, x)
    nested = sp.Poly(question.subs(x, x**4-x+1), x, extension=r)
    timed("nested degree 24, existing coefficient field", nested, x)
    timed("sparse inner regression", sp.Poly((x**4+x)**2, x), x)
    timed("all chains of x^60", sp.Poly(x**60, x), x, enumerate_all=True)
    timed("absolute indecomposability, degree 120", sp.Poly(x**120+x, x), x)
    if args.full:
        outer, middle, inner = x**3+r*x+1, x**4+x+r, x**8+x+1
        dense = sp.Poly(outer.subs(x, middle).subs(x, inner), x, extension=r)
        timed("dense degree 96 over Q(sqrt(2))", dense, x)
        timed("all chains of T_60", sp.Poly(sp.chebyshevt(60, x), x), x, enumerate_all=True)
    if args.compare_report01:
        compare_report01(x)


if __name__ == "__main__":
    main()
