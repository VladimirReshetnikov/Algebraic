#!/usr/bin/env python3
"""Independent, exact SymPy checks for article identities and algorithms.

This script does NOT execute Wolfram Language. It verifies the mathematical
identities, finite-catalog discovery, and the rational fixed-space construction
on a biquadratic field. Run: python verify.py
"""
from __future__ import annotations

from itertools import product
from math import gcd
from functools import reduce
import json
from pathlib import Path
import sys
import sympy as sp

x, z, u, v = sp.symbols("x z u v")
checks: list[str] = []


def check(name: str, condition: bool) -> None:
    if not bool(condition):
        raise AssertionError(name)
    checks.append(name)
    print(f"PASS: {name}")


def composed(p: sp.Expr, q: sp.Expr, mode: str) -> sp.Expr:
    """Monic polynomial of all pairwise sums or products, multiplicities kept."""
    f = sp.Poly(p, x, domain=sp.QQ).monic().as_expr()
    g = sp.Poly(q, x, domain=sp.QQ).monic()
    if mode == "Sum":
        transformed = g.as_expr().subs(x, z - x)
    elif mode == "Product":
        degree = g.degree()
        transformed = sum(g.nth(j) * z**j * x**(degree - j)
                          for j in range(degree + 1))
    else:
        raise ValueError("mode must be Sum or Product")
    return sp.expand(sp.resultant(f, transformed, x))


def catalog(degree: int, height: int) -> list[sp.Expr]:
    """Includes primitive nonmonic integer polynomials, positive leading term."""
    result = []
    for lead in range(1, height + 1):
        for low in product(range(-height, height + 1), repeat=degree):
            coefficients = low + (lead,)
            if reduce(gcd, coefficients) != 1:
                continue
            p = sum(c * x**j for j, c in enumerate(coefficients))
            if sp.Poly(p, x).is_irreducible:
                result.append(p)
    return result


def main() -> None:
    f = x**3 + x + 1
    g = x**3 - x + 1
    ps = z**9 + 6*z**6 + 3*z**5 - 15*z**3 + 24*z**2 - 4*z + 8
    pt = z**9 + 2*z**7 - 3*z**6 + z**5 - z**4 + 3*z**3 - z - 1
    check("sum resultant equals the supplied polynomial", composed(f, g, "Sum") == ps)
    check("product resultant equals the supplied polynomial", composed(f, g, "Product") == pt)
    check("both cubics irreducible", all(sp.Poly(p, x).is_irreducible for p in [f, g]))
    check("both nonics irreducible over Q", all(sp.Poly(p, z).is_irreducible for p in [ps, pt]))
    check("both nonics have exactly one real root", all(sp.Poly(p, z).count_roots(-sp.oo, sp.oo) == 1 for p in [ps, pt]))
    check("cubic discriminants are -31 and -23", (sp.discriminant(f, x), sp.discriminant(g, x)) == (-31, -23))

    # The sparse symbolic ansatz used to discover the supplied cubics.
    sparse_product = sp.resultant(x**3+u*x+1, z**3+v*z*x**2+x**3, x)
    sparse_expected = (z**9-2*u*v*z**7-3*z**6+u**2*v**2*z**5
                       +u*v*z**4+(u**3+v**3+3)*z**3+u*v*z-1)
    check("sparse product coefficient formula", sp.expand(sparse_product-sparse_expected) == 0)
    sparse_sum = sp.Poly(sp.resultant(x**3+u*x+1, (z-x)**3+v*(z-x)+1, x), z)
    check("sparse sum discovery coefficients", sparse_sum.nth(7) == 3*u+3*v
          and sparse_sum.nth(5) == 3*u**2+3*u*v+3*v**2)

    def companion(p: sp.Expr) -> sp.Matrix:
        poly = sp.Poly(p, x).monic()
        n = poly.degree()
        matrix = sp.zeros(n)
        for j in range(n - 1):
            matrix[j + 1, j] = 1
        for j in range(n):
            matrix[j, n - 1] = -poly.nth(j)
        return matrix

    cf, cg = companion(f), companion(g)
    check("Kronecker product agrees with the resultant", sp.kronecker_product(cf, cg).charpoly(z).as_expr() == pt)
    csum = sp.kronecker_product(cf, sp.eye(3)) + sp.kronecker_product(sp.eye(3), cg)
    check("Kronecker sum agrees with the resultant", csum.charpoly(z).as_expr() == ps)
    check("nonmonic coefficients are normalized correctly", sp.expand(composed(2*x**2-1, 3*x**2-1, "Product") - (z**2-sp.Rational(1,6))**2) == 0)
    check("zero product has correct multiplicity", composed(x, x**2-2, "Product") == z**2)
    check("composed polynomial may have repeated factors", composed(x**2-2, x**2-2, "Product") == sp.expand((z**2-4)**2))
    check("minimal polynomial need only divide the resultant", composed(x**2-2, x**2-2, "Sum") == z**4-8*z**2)
    check("actual target has smaller degree than the full resultant", sp.minimal_polynomial(2*sp.sqrt(2), z) == z**2-8)

    polynomials = catalog(3, 1)
    witnesses = {}
    for mode, target in [("Sum", ps), ("Product", pt)]:
        found = None
        for i, p in enumerate(polynomials):
            for q in polynomials[i:]:
                r = composed(p, q, mode)
                if sp.rem(r, target, z) == 0:
                    found = (str(p), str(q))
                    break
            if found:
                break
        witnesses[mode] = found
        check(f"height-one cubic catalog discovers a {mode.lower()} decomposition", found is not None)
    check("nonmonic catalog includes 2*x^2-1", 2*x**2-1 in catalog(2, 2))

    # Relative fixed spaces in Q(sqrt(2),sqrt(3)), power basis in theta.
    theta_poly = x**4 - 10*x**2 + 1
    images = [x, -x, x**3-10*x, -x**3+10*x]  # theta, -theta, -1/theta, 1/theta
    matrices = []
    for image in images:
        cols = []
        for j in range(4):
            remainder = sp.Poly(sp.rem(image**j, theta_poly, x), x)
            cols.append(sp.Matrix([remainder.nth(i) for i in range(4)]))
        matrices.append(sp.Matrix.hstack(*cols))
    check("four rational automorphism matrices close under multiplication", all(a*b in matrices for a in matrices for b in matrices))
    all_fixed = sp.Matrix.vstack(*(a-sp.eye(4) for a in matrices)).nullspace()
    target = sp.Matrix([0,1,0,0])
    check("theta is not in the degree-one fixed space", sp.Matrix.hstack(*all_fixed).row_join(target).rank() > len(all_fixed))
    quadratic_vectors = []
    for a in matrices[1:]:
        quadratic_vectors.extend((a-sp.eye(4)).nullspace())
    span = sp.Matrix.hstack(*quadratic_vectors)
    check("quadratic fixed spaces span the biquadratic field", span.rank() == 4)
    check("theta is a sum of elements from degree-two subfields", span.row_join(target).rank() == span.rank())

    quartic = x**4-x-1
    sextic = z**6+4*z**2-1
    check("quartic pair-sum resultant formula", composed(quartic, quartic, "Sum") == sp.expand((z**4-8*z-16)*sextic**2))
    check("sextic pair-sum polynomial is irreducible", sp.Poly(sextic,z).is_irreducible)
    check("quartic is irreducible modulo two", sp.Poly(quartic, x, modulus=2).is_irreducible)
    check("quartic discriminant is -283", sp.discriminant(quartic,x) == -283)
    check("quartic resolvent is irreducible", sp.Poly(x**3+4*x-1,x).is_irreducible)
    three_sum = sp.sqrt(2)+sp.sqrt(3)+sp.sqrt(5)
    three_product = (1+sp.sqrt(2))*(1+sp.sqrt(3))*(1+sp.sqrt(5))
    check("three quadratic summands can require degree eight", sp.degree(sp.minimal_polynomial(three_sum,x), x) == 8)
    check("three quadratic factors can require degree eight", sp.degree(sp.minimal_polynomial(three_product,x), x) == 8)
    check("nested-square-root example has absolute degree four", sp.minimal_polynomial(sp.sqrt(2+sp.sqrt(2)),x) == x**4-4*x**2+2)

    a = sp.CRootOf(f,0)
    b = sp.CRootOf(g,0)
    report = {
        "python_version": sys.version.split()[0],
        "sympy_version": sp.__version__,
        "passed": len(checks), "failed": 0,
        "checks": checks,
        "height_one_cubic_count": len(polynomials),
        "discovered_polynomial_pairs": witnesses,
        "approximations": {"a": str(a.evalf(30)), "b": str(b.evalf(30)),
                           "a_plus_b": str((a+b).evalf(30)),
                           "a_times_b": str((a*b).evalf(30))},
        "wolfram_language_kernel_tested": False,
        "wolfram_connector_error": "HTTP 404, MCP SSE probe failed; no kernel result returned."
    }
    destination = Path(__file__).with_name("verification_results.json")
    destination.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(f"\n{len(checks)} exact checks passed. Report: {destination.name}")


if __name__ == "__main__":
    main()
