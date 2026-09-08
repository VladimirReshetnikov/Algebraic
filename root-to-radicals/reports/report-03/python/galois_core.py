"""Exact, exhaustive Galois/Fourier reference backend.

All field operations are rational polynomial arithmetic modulo one irreducible
polynomial. Automatic splitting fields can be VERY expensive in SymPy. A supplied
embedded model is useful for testing and for computations prepared in another CAS.
The supplied model is validated; an abstract group with unverified root labels is
not an accepted replacement for actual field automorphisms.
"""
from __future__ import annotations
from dataclasses import dataclass
from functools import lru_cache
from typing import Any
import sympy as s
from sympy.polys.numberfields import field_isomorphism
from radicalroots import ResourceLimit, NotSolvable, RadicalError, radical_q, zeta, exact_equal, plain_expression


def embed_exact(K, expression):
    """Embed via factorization and certified same-root selection, not PSLQ.

    SymPy's default to_number_field may accept a real PSLQ embedding after
    checking only the defining polynomial. fast=False bypasses that heuristic
    branch and uses the factorization path with a separation-bound root test.
    """
    expression = plain_expression(expression)
    if expression.is_Rational:
        return K.convert(expression)
    coeffs = field_isomorphism(expression, K.ext, fast=False)
    if coeffs is None:
        raise RadicalError("The specified embedded algebraic number is outside the field")
    return K([K.dom.from_sympy(c) for c in coeffs])


def apply_image(K, element, image):
    out = K.zero
    for c in element.to_list():
        out = out*image + K(c)
    return out


def vector(K, a):
    cs = list(reversed(a.to_list()))
    cs += [s.S.Zero]*(K.mod.degree()-len(cs))
    return s.Matrix([s.Rational(c.numerator, c.denominator)
                     if hasattr(c, 'numerator') else s.Rational(c) for c in cs])


@dataclass
class GaloisModel:
    K: Any
    conductor: int
    unity: Any
    images: list
    table: list[list[int]]
    identity: int
    group: set[int]

    @classmethod
    def from_field(cls, K, conductor: int, max_field_degree: int | None = 64):
        """Require a Galois field K containing the specified principal zeta_m.

        Validation factors the primitive minimal polynomial into degree-one
        factors over K, builds every actual automorphism, and checks its action.
        """
        if not isinstance(conductor, int) or conductor < 1:
            raise ValueError("conductor must be a positive integer")
        d = K.mod.degree()
        if max_field_degree is not None and d > max_field_degree:
            raise ResourceLimit(f"Field degree {d} exceeds {max_field_degree}")
        unity = embed_exact(K, zeta(conductor))
        f = K.ext.minpoly
        factors = s.Poly(f.as_expr(), f.gen, domain=K).factor_list()[1]
        if len(factors) != d or any(p.degree() != 1 or e != 1 for p,e in factors):
            raise RadicalError("The supplied field is not Galois over QQ")
        images = []
        for p, _ in factors:
            a,b = p.rep.to_list()
            images.append(-b/a)
        lookup = {a: i for i,a in enumerate(images)}
        identity = lookup[K.unit]
        table = [[lookup[apply_image(K, b, a)] for b in images] for a in images]
        group = {i for i,a in enumerate(images)
                 if apply_image(K, unity, a) == unity}
        if len(group)*int(s.totient(conductor)) != d:
            raise RadicalError("Cyclotomic fixed-field dimension mismatch")
        # K/Q(zeta_m) must have all prime-order roots of unity it will need.
        for prime in s.factorint(len(group)):
            if conductor % int(prime):
                raise RadicalError("Conductor misses a prime divisor of the relative group")
        return cls(K,conductor,unity,images,table,identity,group)

    def act(self, element, index):
        return apply_image(self.K, element, self.images[index])


def automatic_model(p: s.Poly, max_field_degree: int | None = 64) -> GaloisModel:
    """Build L (all roots), then M=L(zeta_rad([L:QQ])).

    Primitive-element adjunction is checked after EACH step, but a single
    adjunction can still be expensive before the degree cap can be checked.
    """
    n = p.degree()
    if max_field_degree is not None and n > max_field_degree:
        raise ResourceLimit("Polynomial degree already exceeds field-degree cap")
    # Cheap radical formulas are allowed as INTERNAL exact field generators.
    # For arbitrary degree, RootOf generators give the same complete algorithm.
    if n <= 4:
        rdict = s.roots(p.as_expr(),p.gen)
        rs = list(rdict) if len(rdict) == n else p.all_roots(radicals=False)
    else:
        rs = p.all_roots(radicals=False)
    K = s.QQ.algebraic_field(rs[0])
    for r in rs[1:]:
        K = s.QQ.algebraic_field(plain_expression(K.ext), r)
        if max_field_degree is not None and K.mod.degree() > max_field_degree:
            raise ResourceLimit(f"Splitting field degree exceeds {max_field_degree}")
    d = K.mod.degree()
    m = int(s.prod(s.factorint(d)))
    M = s.QQ.algebraic_field(plain_expression(K.ext), zeta(m))
    return GaloisModel.from_field(M, m, max_field_degree)


def prime_chain(table: list[list[int]], identity: int, group: set[int]):
    """Deterministic normal series with prime cyclic quotients, or proof of failure.

    Greedily enlarge the derived subgroup to a maximal proper subgroup.
    Since the quotient by the derived subgroup is abelian, every enlargement
    is normal. No costly enumeration of the entire subgroup lattice is needed.
    """
    inv = {a: next(b for b in group if table[a][b] == identity) for a in group}

    def closure(gens):
        generators = sorted(set(gens))
        known = {identity}
        todo = [identity]
        while todo:
            a = todo.pop()
            for b in generators:
                c = table[a][b]
                if c not in known:
                    known.add(c)
                    todo.append(c)
        return known

    H = set(group)
    chain = []
    while len(H) > 1:
        comms = {table[table[table[a][b]][inv[a]]][inv[b]] for a in H for b in H}
        N = closure(comms)
        if N == H:
            raise NotSolvable(f"Nontrivial perfect subgroup of order {len(H)}")
        for a in sorted(H):
            if a not in N:
                enlarged = closure(N | {a})
                if len(enlarged) < len(H):
                    N = enlarged
        p = len(H)//len(N)
        if not s.isprime(p):
            raise RadicalError("Maximal abelian quotient was not prime")
        sigma = min(H-N)
        # Independently check normality and the required quotient order.
        if any(table[table[h][a]][inv[h]] not in N for h in H for a in N):
            raise RadicalError("Invalid normal-subgroup step")
        power = identity
        for _ in range(p):
            power = table[power][sigma]
        if power not in N:
            raise RadicalError("Invalid quotient generator")
        chain.append((set(H), set(N), sigma, p))
        H = N
    return chain


def radicals_from_model(model: GaloisModel, element, *, max_nodes: int | None = 10000):
    """Fourier descent for an element of a validated embedded Galois model.

    The model may be larger than the target's splitting field. Therefore a
    nonsolvable supplied model does NOT prove the target is nonsolvable; the
    caller must distinguish this situation from automatic_model's construction.
    """
    K = model.K
    try:
        chain = prime_chain(model.table, model.identity, model.group)
    except NotSolvable as error:
        # In this low-level public function we do not assume model minimality.
        raise RadicalError("Supplied model has nonsolvable relative group; "
                           "this alone does not decide the target") from error
    m = model.conductor
    e = int(s.totient(m))
    powers = [model.unity**j for j in range(e)]
    B = s.Matrix.hstack(*(vector(K,a) for a in powers))
    pivot_rows = list(B.T.rref()[1])
    if len(pivot_rows) != e:
        raise RadicalError("Incorrect cyclotomic basis")
    inverse = B[pivot_rows,:].inv()
    phases = []
    nodes = 0
    zexpr = zeta(m)

    def fixed(a, subgroup):
        return all(model.act(a,i) == a for i in subgroup)

    @lru_cache(maxsize=None)
    def encode(a, level):
        nonlocal nodes
        nodes += 1
        if max_nodes is not None and nodes > max_nodes:
            raise ResourceLimit("Fourier expression-node budget exhausted")
        if not a:
            return s.S.Zero
        if level == 0:
            v = vector(K,a)
            coeffs = inverse*v[pivot_rows,:]
            if B*coeffs != v:
                raise RadicalError("Bottom invariant is outside the cyclotomic field")
            return s.Add(*(coeffs[j]*zexpr**j for j in range(e)))
        H,N,sigma,p = chain[level-1]
        if not fixed(a,N):
            raise RadicalError("Fourier input violates fixed-field invariant")
        if model.act(a,sigma) == a:
            return encode(a,level-1)
        orbit = [a]
        for _ in range(1,p):
            orbit.append(model.act(orbit[-1],sigma))
        zp = model.unity**(m//p)
        parts = []
        for j in range(p):
            R = sum((zp**(-j*k)*orbit[k] for k in range(p)), K.zero)
            if j == 0:
                if not fixed(R,H):
                    raise RadicalError("Trace was not in the parent field")
                parts.append(encode(R,level-1))
                continue
            if not R:
                parts.append(s.S.Zero)
                continue
            b = R**p
            if not fixed(b,H):
                raise RadicalError("Resolvent power was not in the parent field")
            b_expr = encode(b,level-1)
            # Determine the phase using the INTERNAL exact value of b rather
            # than expanding the (potentially much larger) output expression.
            principal = embed_exact(K, s.Pow(K.to_sympy(b),s.Rational(1,p)))
            phase = next((k for k in range(p) if zp**k*principal == R),None)
            if phase is None:
                raise RadicalError("No exact principal-root phase matched")
            term = zeta(p)**phase*s.Pow(b_expr,s.Rational(1,p),evaluate=False)
            parts.append(term)
            phases.append({"level":level,"frequency":j,"prime":p,"phase":phase})
        out = s.Add(*parts)/p
        return out

    output = encode(element,len(chain))
    if not radical_q(output):
        raise RadicalError("Forbidden head in radical output")
    # Check the expanded radical expression in the SAME exact embedding.
    if embed_exact(K, output) != element or not exact_equal(output, K.to_sympy(element)):
        raise RadicalError("Final embedded-field identity failed")
    return output, {"field_degree":K.mod.degree(), "conductor":m,
                    "relative_group_order":len(model.group),
                    "quotient_primes":[t[3] for t in chain],
                    "nodes":nodes,"phases":phases,
                    "verification":"exact field arithmetic plus separation-bound embedding checks"}
