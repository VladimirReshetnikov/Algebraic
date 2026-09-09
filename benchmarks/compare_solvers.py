"""Compare representative solver workloads with a Git revision, checking exact outputs.

Run from any directory: python benchmarks/compare_solvers.py --baseline 204c97f
Each workload is warmed, then timed in alternating order. Input construction and
exact output comparison are outside the timed calls. Multiplication matrices use
identical current field data. Radical workloads share the current field dependency;
the full expression workflow includes branch selection and verification.
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
from flint import acb, arb, ctx, fmpq, fmpq_poly, fmpz_poly
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


def decomposition_signature(result):
    return {**vars(result), "terms": [(tuple(term.poly.coeffs()), term.index) for term in result.terms]}


def input_field_signature(data):
    return {**vars(data), "theta": (tuple(data.theta.poly.coeffs()), data.theta.index)}


def radical_signature(result):
    if result.method != "Dickson" or result.verified is not True:
        raise AssertionError("the radical workload must verify through Dickson recognition")
    return {**{key: value for key, value in vars(result).items() if key != "time"},
            "radical_depth": result.radical_depth, "leaf_count": result.leaf_count}


def workloads(before, current, match=""):
    x = sp.Symbol("x")
    sparse = sp.Poly(x ** 600 + x + 1, x)
    algebraic = sp.Poly((x ** 4 + x ** 2 + sp.sqrt(2) * x) ** 24, x, extension=sp.sqrt(2))
    chebyshev = sp.Poly(sp.chebyshevt(120, x), x)
    for label, polynomial, method, args in (
        ("sparse degree-600 certificate", sparse, "decomposition_data", (2,)),
        ("algebraic degree-96 chain", algebraic, "decompose", ()),
        ("Chebyshev degree-120 all chains", chebyshev, "decompositions", ()),
        ("power degree-360 all chains", sp.Poly(x ** 360, x), "decompositions", ()),
    ):
        yield label, [lambda m=m, p=polynomial, f=method, a=args: getattr(m, f)(p, x, *a)
                      for m in (before["algebraic_decompose"], current["algebraic_decompose"])], lambda result: result
    r = sp.sqrt(2)
    for label, make_polynomial, degree in (
        ("dense degree-48 certificate verification",
         lambda: sp.Poly(((2 + r) * (x ** 3 + r * x + 1)).subs(x, x ** 4 + x + r)
                         .subs(x, x ** 4 + x + 1), x, extension=r), None),
        ("power degree-360 certificate verification", lambda: sp.Poly(x ** 360, x), None),
        ("sparse algebraic degree-240 certificate verification",
         lambda: sp.Poly((2 + r) * x ** 240 + x ** 7 + 7, x, extension=r), 4),
    ):
        if match.lower() in label.lower():
            polynomial = make_polynomial()
            certificate = current["algebraic_decompose"].decomposition_data(polynomial, x, degree)

            def check_certificate(module, polynomial=polynomial, certificate=certificate):
                if module.verify_decomposition_data(polynomial, certificate, x) is not True:
                    raise AssertionError("certificate verification failed")
                return True

            yield label, [lambda m=m, check=check_certificate: check(m)
                          for m in (before["algebraic_decompose"], current["algebraic_decompose"])], lambda result: result
    label = "Chebyshev degree-120 chains with verification"
    if match.lower() in label.lower():
        def checked_chains(module):
            chains = module.decompositions(chebyshev, x)
            if not all(module.verify_decomposition(chebyshev, chain, x, require_complete=True,
                                                    require_normalized=True) for chain in chains):
                raise AssertionError("complete-chain verification failed")
            return chains

        yield label, [lambda m=m: checked_chains(m)
                      for m in (before["algebraic_decompose"], current["algebraic_decompose"])], lambda result: result
    for label, coefficients, index, method, options in (
        ("sum of degree-9 product root", [-1, -1, 0, 3, -1, 1, -3, 2, 0, 1], 1, "sum_decomposition", {}),
        ("product of degree-9 sum root", [8, -4, 24, -15, 0, 3, 6, 0, 0, 1], 1, "product_decomposition", {}),
        ("two-term quartic sum", [-8, 16, -4, -4, 1], 4, "sum_decomposition", {"max_terms": 2}),
        ("three-factor degree-8 tensor product", [4096, 4096, -16384, 6144, 3008, -768, -256, -8, 1],
         8, "product_decomposition", {"max_factors": 3, "depth": 0}),
    ):
        if match.lower() in label.lower():
            yield label, [lambda m=m, a=m.AlgebraicNumber(fmpz_poly(coefficients), index), f=method, o=options:
                          getattr(m, f)(a, **o)
                          for m in (before["rootdecomp"], current["rootdecomp"])], decomposition_signature
    for label, coefficients in (
        ("S4 field construction", [-1, -1, 0, 0, 1]),
        ("order-36 field construction", [8, -4, 24, -15, 0, 3, 6, 0, 0, 1]),
    ):
        polynomial = fmpz_poly(coefficients)
        yield label, [lambda m=m, p=polynomial: m.build_galois_data(p)
                      for m in (before["rootdecomp"], current["rootdecomp"])], galois_signature
    yield "degree-2 height-4 catalogue", [lambda m=m: m.catalog.__wrapped__(2, 4)
        for m in (before["rootdecomp"], current["rootdecomp"])], lambda result: tuple(
            (tuple(a.poly.coeffs()), a.index) for a in result)
    label = "input-field S4 construction"
    if match.lower() in label.lower():
        def input_field(module, a):
            module._ifcache.clear()
            return module.input_field_data(a.poly, a)

        polynomial = fmpz_poly([-1, -1, 0, 0, 1])
        yield label, [lambda m=m, a=m.AlgebraicNumber(polynomial, 1): input_field(m, a)
                      for m in (before["rootdecomp"], current["rootdecomp"])], input_field_signature
    labels = ("input-field degree-8 multiplication matrix", "input-field degree-8 element reconstruction")
    if any(match.lower() in label.lower() for label in labels):
        root = current["rootdecomp"]
        polynomial = fmpz_poly([-2] + [0] * 7 + [1])
        data = root.input_field_data(polynomial, root.AlgebraicNumber(polynomial, 1))
        fields = [module.InputFieldData(**vars(data)) for module in (before["rootdecomp"], root)]
        vector = [fmpq(i + 1, i + 2) for i in range(data.n)]
        for label, method, signature in (
            (labels[0], "mult_matrix", lambda result: result),
            (labels[1], "to_algebraic", lambda result: (tuple(result.poly.coeffs()), result.index)),
        ):
            yield label, [lambda field=field, method=method, vector=vector: getattr(field, method)(vector)
                          for field in fields], signature
    label = "order-48 unity multiplication matrix"
    if match.lower() in label.lower():
        data = current["rootdecomp"].galois_data(fmpz_poly([-1, -1, 0, 0, 1]) * fmpz_poly([1, 1, 1]))
        with ctx.workprec(data.prec):
            unity = data.scale * (acb(0, 2) * arb.pi() / 3).exp()
            matches = [i for i, root in enumerate(data.roots) if root.overlaps(unity)]
        if len(matches) != 1:
            raise AssertionError("cube root of unity is not uniquely isolated")
        vector = [q / data.scale for q in data.root_coords[matches[0]]]

        def multiplication(module):
            with ctx.workprec(data.prec):
                return module.multiplication_matrix_of(data, vector)

        yield label, [lambda m=m: multiplication(m)
            for m in (before["rootdecomp"], current["rootdecomp"])], lambda result: result
    # x^m P(x+c/x), with P(y)=y^m+3*y^7+1 and m=24.
    m, c = 24, fmpq(2, 3)
    quadratic = fmpq_poly([c, 0, 1])
    reciprocal = (quadratic ** m + 3 * (quadratic ** 7).left_shift(m - 7)
                  + fmpq_poly([1]).left_shift(m)).numer()
    yield "degree-48 reciprocal recognition", [lambda module=module: module.reciprocal_decomposition(reciprocal)
        for module in (before["roottoradicals"], current["roottoradicals"])], lambda result: result
    label = "quintic radical expression"
    if match.lower() in label.lower():
        a = current["rootdecomp"].AlgebraicNumber(fmpz_poly([6, 25, 0, -25, 0, 5]), 5)
        yield label, [lambda module=module, a=a: module.root_to_radicals(a)
                      for module in (before["roottoradicals"], current["roottoradicals"])], radical_signature


def compare(functions, signature, samples, cold_sympy_cache=False):
    expected = signature(functions[0]())
    if signature(functions[1]()) != expected:
        raise AssertionError("exact warm-up outputs differ")
    times = [[], []]
    for sample in range(samples):
        for index in ((0, 1) if sample % 2 else (1, 0)):
            if cold_sympy_cache:
                sp.core.cache.clear_cache()
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
    parser.add_argument("--cold-sympy-cache", action="store_true", help="clear SymPy's cache before each timed call")
    parser.add_argument("--output", type=Path, help="also write exact-check status and raw timings as JSON")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    revision = subprocess.check_output(["git", "rev-parse", "--verify", args.baseline + "^{commit}"],
                                       cwd=ROOT, text=True).strip()
    current = {name: load_module(name) for name in SOURCES}
    before = {name: load_module(name, revision) for name in SOURCES}
    report = {"baseline": revision, "python": sys.version, "sympy": sp.__version__,
              "current_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "python_flint": flint.__version__, "samples": args.samples,
              "cold_sympy_cache": args.cold_sympy_cache,
              "current_source_sha256": {name: module.__source_sha256__ for name, module in current.items()},
              "workloads": {}}
    for label, functions, signature in workloads(before, current, args.match):
        if args.match.lower() in label.lower():
            result = compare(functions, signature, args.samples, args.cold_sympy_cache)
            report["workloads"][label] = result
            print(f"PASS {label}: {result['baseline_seconds']:.6f}s -> "
                  f"{result['current_seconds']:.6f}s ({result['ratio']:.2f}x)", flush=True)
    if not report["workloads"]:
        parser.error("--match selected no workloads")
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
