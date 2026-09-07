#!/usr/bin/env python3
"""Independent exact checks for article.tex. Requires Python 3 and SymPy.

This script checks the algebra and finite groups, not the Wolfram interpreter.
No floating-point computation is used to accept an identity or minimal degree.
"""
from __future__ import annotations

import itertools
import json
import math
import platform
from collections import Counter
from pathlib import Path
from typing import Callable, Sequence, Any

import sympy as sp

OUT = Path(__file__).resolve().parent
checks: dict[str, Any] = {}

def require(condition: bool, label: str) -> None:
    if not bool(condition):
        raise AssertionError(label)
    checks[label] = True


def finite_group(elements: Sequence[Any], mul: Callable[[Any, Any], Any]):
    index = {g: i for i, g in enumerate(elements)}
    table = [[index[mul(g, h)] for h in elements] for g in elements]
    ident = next(i for i in range(len(elements))
                 if all(table[i][j] == table[j][i] == j for j in range(len(elements))))
    return table, ident


def subgroups(table: list[list[int]], ident: int) -> list[frozenset[int]]:
    def closure(gens: frozenset[int]) -> frozenset[int]:
        found = {ident}
        todo = [ident]
        for a in todo:
            for b in gens:
                c = table[a][b]
                if c not in found:
                    found.add(c)
                    todo.append(c)
        return frozenset(found)
    found = [frozenset({ident})]
    seen = set(found)
    for h in found:
        for g in range(len(table)):
            if g in h:
                continue
            k = closure(h | {g})
            if k not in seen:
                seen.add(k)
                found.append(k)
    return found


def exponent(table: list[list[int]], ident: int) -> int:
    result = 1
    for i in range(len(table)):
        x, order = i, 1
        while x != ident:
            x, order = table[x][i], order + 1
        result = math.lcm(result, order)
    return result


def fixed_basis(matrices: Sequence[sp.Matrix], h: frozenset[int]) -> list[sp.Matrix]:
    eye = sp.eye(matrices[0].rows)
    return sp.Matrix.vstack(*(matrices[g] - eye for g in h)).nullspace()


def span_rank(matrices: Sequence[sp.Matrix], hs: Sequence[frozenset[int]], d: int,
              containing: frozenset[int] | None = None) -> int:
    vectors = []
    for h in hs:
        if len(matrices) // len(h) <= d and (containing is None or containing <= h):
            vectors.extend(fixed_basis(matrices, h))
    return sp.Matrix.hstack(*vectors).rank() if vectors else 0


def main() -> None:
    x, y = sp.symbols('x y')
    p, q = x**3 + x + 1, x**3 - x + 1
    ps = x**9 + 6*x**6 + 3*x**5 - 15*x**3 + 24*x**2 - 4*x + 8
    pm = x**9 + 2*x**7 - 3*x**6 + x**5 - x**4 + 3*x**3 - x - 1
    require(sp.resultant(p.subs(x, y), q.subs(x, x-y), y) == ps,
            'sum_resultant')
    product_operand = sum(sp.Poly(q, x).nth(j)*x**j*y**(3-j) for j in range(4))
    require(sp.resultant(p.subs(x, y), product_operand, y) == pm,
            'product_resultant')
    for name, poly in [('p', p), ('q', q), ('sum', ps), ('product', pm)]:
        require(sp.Poly(poly, x).is_irreducible, name + '_irreducible_over_Q')
        require(sp.Poly(poly, x).count_roots(-sp.oo, sp.oo) == 1,
                name + '_exactly_one_real_root')
    checks['cubic_discriminants'] = [int(sp.discriminant(p, x)), int(sp.discriminant(q, x))]
    # Rational-function certificates recover u from each input.
    ns, ds = 3*x**5-5*x**3-3*x**2+2*x-4, 6*x**4-6*x+4
    nm, dm = x**3-x**2-1, x**4+x**2-x+1
    for name, poly, num, den in [('sum', ps, ns, ds), ('product', pm, nm, dm)]:
        require(sp.gcd(poly, den) == 1, name + '_certificate_denominator_nonzero')
        require(sp.rem(num**3+num*den**2+den**3, poly, x) == 0,
                name + '_first_cubic_certificate')
        vn, vd = (x*den-num, den) if name == 'sum' else (x*den, num)
        require(sp.gcd(poly, vd) == 1, name + '_second_denominator_nonzero')
        require(sp.rem(vn**3-vn*vd**2+vd**3, poly, x) == 0,
                name + '_second_cubic_certificate')
    # A second, polynomial certificate for the product input.
    um = -(x**7+2*x**5-2*x**4+1)/2
    vm = -(x**7+2*x**5-2*x**4+2*x**3+2*x-1)/2
    require(sp.rem(um*vm-x, pm, x) == 0, 'polynomial_product_certificate')
    require(sp.rem(um**3+um+1, pm, x) == 0, 'polynomial_u_cubic_certificate')
    require(sp.rem(vm**3-vm+1, pm, x) == 0, 'polynomial_v_cubic_certificate')
    # Six pairing resolvents give a globally optimal additive representation of uv.
    r = x**6+6*x**4-27*x**3+9*x**2-81*x+4
    require(sp.Poly(r, x).is_irreducible, 'pairing_sextic_irreducible')
    require(sp.Poly(r, x).count_roots(-sp.oo, sp.oo) == 2, 'pairing_sextic_two_real_roots')
    require(sp.rem(sp.resultant(r.subs(x, y), r.subs(x, 3*x-y), y), pm, x) == 0,
            'pairing_sextic_sum_resultant_contains_product_input')
    # The two real pairing values satisfy w^2 - 3*x*w + C = 0.
    # Evaluate R(w) in Q[x,w]/(pm(x), w^2-3*x*w+C), with exact remainders.
    cc = sp.rem(3*um**2 - 3*vm**2 + 4, pm, x)
    aa, bb = sp.Integer(1), sp.Integer(0)
    ra, rb = sp.Integer(0), sp.Integer(0)
    for j in range(7):
        coeff = sp.Poly(r,x).nth(j)
        ra = sp.rem(ra + coeff*aa, pm, x)
        rb = sp.rem(rb + coeff*bb, pm, x)
        aa, bb = sp.rem(-cc*bb, pm, x), sp.rem(aa + 3*x*bb, pm, x)
    require(ra == 0 and rb == 0, 'pairing_quadratic_divides_sextic_exactly')
    # Exact group calculations for S3 x S3 in its standard tensor representation.
    perms = list(itertools.permutations(range(3)))
    def comp(p1, p2): return tuple(p1[p2[i]] for i in range(3))
    elts36 = list(itertools.product(perms, repeat=2))
    tab36, id36 = finite_group(elts36, lambda a,b: (comp(a[0],b[0]),comp(a[1],b[1])))
    hs36 = subgroups(tab36, id36)
    coordinates = [sp.Matrix([1,0]), sp.Matrix([0,1]), sp.Matrix([-1,-1])]
    def standard(p1): return sp.Matrix.hstack(coordinates[p1[0]], coordinates[p1[1]])
    mats36 = [sp.kronecker_product(standard(a), standard(b)) for a,b in elts36]
    stabilizer = frozenset(i for i,(a,b) in enumerate(elts36) if a[0] == b[0] == 0)
    require(exponent(tab36,id36) == 6, 'S3xS3_exponent_6')
    require(span_rank(mats36,hs36,5) == 0, 'product_input_no_additive_degree_at_most_5')
    require(span_rank(mats36,hs36,6) == 4, 'product_input_additive_degree_6_suffices')
    require(span_rank(mats36,hs36,8,stabilizer) == 0,
            'product_input_no_lower_additive_decomposition_inside_Qalpha')
    checks['S3xS3_subgroup_index_counts'] = dict(sorted(Counter(36//len(h) for h in hs36).items()))
    # External-factor counterexample.
    pw = x**4-4*x**3-16*x**2-8*x+4
    pa = pw.subs(x,x**2)
    require(sp.minimal_polynomial((1+sp.sqrt(2))*(1+sp.sqrt(3)),x) == pw,
            'external_example_square_minimal_polynomial')
    require(sp.Poly(pa,x).is_irreducible, 'external_example_degree_8')
    require(sp.Poly(pa,x).count_roots(-sp.oo,sp.oo) == 4, 'external_example_four_real_roots')
    f, g = x**4-2*x**2-1, x**4-2*x**2-2
    product_g = sum(sp.Poly(g,x).nth(j)*x**j*y**(4-j) for j in range(5))
    require(sp.expand(sp.resultant(f.subs(x,y),product_g,y) - pa**2) == 0,
            'external_example_resultant_is_square_not_minimal_polynomial')
    require(sp.Poly(f,x).is_irreducible and sp.Poly(g,x).is_irreducible,
            'external_example_factors_degree_4')
    # Normal form s^a t^b c^c z^e, with pairwise commutators z.
    elts16 = list(itertools.product(range(2),repeat=4))
    def mul16(v,w):
        a,b,c,e = v; A,B,C,E = w
        return (a^A,b^B,c^C,e^E^(b&A)^(c&A)^(c&B))
    tab16,id16 = finite_group(elts16,mul16)
    require(all(tab16[tab16[a][b]][c] == tab16[a][tab16[b][c]]
                for a,b,c in itertools.product(range(16),repeat=3)),
            'order16_group_associative')
    hs16 = subgroups(tab16,id16)
    zidx = elts16.index((0,0,0,1))
    require(exponent(tab16,id16) == 4, 'external_example_Galois_exponent_4')
    require(all(zidx in h for h in hs16 if len(h) >= 4),
            'every_degree_below_8_subfield_is_fixed_by_z')
    checks['order16_subgroup_index_counts'] = dict(sorted(Counter(16//len(h) for h in hs16).items()))
    # Three factors really differ from two.
    three = (1+sp.sqrt(2))*(1+sp.sqrt(3))*(1+sp.sqrt(5))
    require(sp.degree(sp.minimal_polynomial(three,x),x) == 8, 'three_quadratic_factors_degree_8')
    # Numerical values are display-only; all acceptance checks above are exact.
    ur = sp.CRootOf(p,0); vr=sp.CRootOf(q,0)
    checks['display_values'] = {'u':str(sp.N(ur,25)), 'v':str(sp.N(vr,25)),
                               'u_plus_v':str(sp.N(ur+vr,25)),
                               'u_times_v':str(sp.N(ur*vr,25))}
    checks['versions']={'python':platform.python_version(),'sympy':sp.__version__}
    checks['native_Wolfram_tests']='Not executed: available Wolfram evaluator returned HTTP 404.'
    (OUT/'results.json').write_text(json.dumps(checks,indent=2)+'\n')
    print(json.dumps(checks,indent=2))

if __name__ == '__main__':
    main()
