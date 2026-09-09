"""Compare representative solver workloads with a Git revision, checking exact outputs.

Run from any directory: python benchmarks/compare_solvers.py --baseline 204c97f
Each workload is warmed, then timed in alternating order. Input construction and
exact output comparison are outside the timed calls. Radical recognition uses
the same current field-engine dependency in both versions; its timed function
does not use that engine. These are workload timings, not whole-suite ratios.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time
import types

import flint
from flint import fmpq, fmpq_poly, fmpz_poly
import sympy as sp

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "rootdecomp": "root-decomposition/python/rootdecomp.py",
    "algebraic_decompose": "polynomial-decompose/python/algebraic_decompose.py",
    "roottoradicals": "root-to-radicals/python/roottoradicals.py",
}


def load_module(name, revision=None):
    path = SOURCES[name]
    source = (ROOT / path).read_text(encoding="utf-8") if revision is None else subprocess.check_output(
        ["git", "show", f"{revision}:{path}"], cwd=ROOT, text=True, encoding="utf-8")
    module = types.ModuleType(name if revision is None else name + "_baseline")
    module.__file__ = str(ROOT / path)
    sys.modules[module.__name__] = module
    exec(compile(source, module.__file__, "exec"), module.__dict__)
    module.__source_sha256__ = hashlib.sha256(source.encode("utf-8")).hexdigest()
    return module


def galois_signature(data):
    return tuple(getattr(data, key) for key in (
        "perms", "tower", "basis_exp", "gram", "gram_inv", "mult_table",
        "identity", "root_coords", "automorphisms", "subgroups", "exponent"))


def workloads(before, current):
    x = sp.Symbol("x")
    sparse = sp.Poly(x ** 600 + x + 1, x)
    algebraic = sp.Poly((x ** 4 + x ** 2 + sp.sqrt(2) * x) ** 24, x, extension=sp.sqrt(2))
    chebyshev = sp.Poly(sp.chebyshevt(120, x), x)
    for label, polynomial, method, args in (
        ("sparse degree-600 certificate", sparse, "decomposition_data", (2,)),
        ("algebraic degree-96 chain", algebraic, "decompose", ()),
        ("Chebyshev degree-120 all chains", chebyshev, "decompositions", ()),
    ):
        yield label, [lambda m=m, p=polynomial, f=method, a=args: getattr(m, f)(p, x, *a)
                      for m in (before["algebraic_decompose"], current["algebraic_decompose"])], lambda result: result
    for label, coefficients in (
        ("S4 field construction", [-1, -1, 0, 0, 1]),
        ("order-36 field construction", [8, -4, 24, -15, 0, 3, 6, 0, 0, 1]),
    ):
        polynomial = fmpz_poly(coefficients)
        yield label, [lambda m=m, p=polynomial: m.build_galois_data(p)
                      for m in (before["rootdecomp"], current["rootdecomp"])], galois_signature
    # x^m P(x+c/x), with P(y)=y^m+3*y^7+1 and m=24.
    m, c = 24, fmpq(2, 3)
    quadratic = fmpq_poly([c, 0, 1])
    reciprocal = (quadratic ** m + 3 * (quadratic ** 7).left_shift(m - 7)
                  + fmpq_poly([1]).left_shift(m)).numer()
    yield "degree-48 reciprocal recognition", [lambda module=module: module.reciprocal_decomposition(reciprocal)
        for module in (before["roottoradicals"], current["roottoradicals"])], lambda result: result


def compare(functions, signature, samples):
    expected = signature(functions[0]())
    if signature(functions[1]()) != expected:
        raise AssertionError("exact warm-up outputs differ")
    times = [[], []]
    for sample in range(samples):
        for index in ((0, 1) if sample % 2 else (1, 0)):
            start = time.perf_counter()
            result = functions[index]()
            times[index].append(time.perf_counter() - start)
            if signature(result) != expected:
                raise AssertionError("exact timed outputs differ")
    old, new = map(statistics.median, times)
    return {"exact_output_match": True, "baseline_seconds": old, "current_seconds": new, "ratio": old / new,
            "samples_seconds": {"baseline": times[0], "current": times[1]}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", default="204c97f", help="Git revision before the refactoring")
    parser.add_argument("--samples", type=int, default=7)
    parser.add_argument("--match", default="", help="run only workload labels containing this text")
    parser.add_argument("--output", type=Path, help="also write exact-check status and raw timings as JSON")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    revision = subprocess.check_output(["git", "rev-parse", "--verify", args.baseline + "^{commit}"],
                                       cwd=ROOT, text=True).strip()
    current = {name: load_module(name) for name in SOURCES}
    before = {name: load_module(name, revision) for name in SOURCES}
    report = {"baseline": revision, "python": sys.version, "sympy": sp.__version__,
              "python_flint": flint.__version__, "samples": args.samples,
              "current_source_sha256": {name: module.__source_sha256__ for name, module in current.items()},
              "workloads": {}}
    for label, functions, signature in workloads(before, current):
        if args.match.lower() in label.lower():
            result = compare(functions, signature, args.samples)
            report["workloads"][label] = result
            print(f"PASS {label}: {result['baseline_seconds']:.6f}s -> "
                  f"{result['current_seconds']:.6f}s ({result['ratio']:.2f}x)", flush=True)
    if not report["workloads"]:
        parser.error("--match selected no workloads")
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
