"""Independent executable reference for the characteristic-zero algorithm.

Requires Python 3.10+ and SymPy. Uses exact SymPy domain elements, not floats.
This file does NOT execute or validate the Wolfram Language runtime.
Coefficients are stored in ascending order; the zero polynomial is (0,).
Original implementation distributed under MIT-0.
"""
from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Iterable

import sympy as sp

Vector = tuple[Any, ...]


@dataclass
class ExactDecomposer:
    domain: Any = sp.QQ

    @property
    def zero(self):
        return self.domain.zero

    @property
    def one(self):
        return self.domain.one

    def trim(self, a: Iterable[Any]) -> Vector:
        a = list(a)
        if not a:
            return (self.zero,)
        while len(a) > 1 and not a[-1]:
            a.pop()
        return tuple(a)

    def vector(self, expr: sp.Expr, x: sp.Symbol) -> Vector:
        p = sp.Poly(expr, x, domain=self.domain)
        return self.trim(reversed(p.rep.to_list()))

    def expression(self, p: Vector, x: sp.Symbol) -> sp.Expr:
        return sp.Add(*(self.domain.to_sympy(c) * x**i
                        for i, c in enumerate(p)))

    def add(self, a: Vector, b: Vector) -> Vector:
        z = self.zero
        return self.trim((a[i] if i < len(a) else z) +
                         (b[i] if i < len(b) else z)
                         for i in range(max(len(a), len(b))))

    def multiply(self, a: Vector, b: Vector) -> Vector:
        out = [self.zero] * (len(a) + len(b) - 1)
        for i, ai in enumerate(a):
            for j, bj in enumerate(b):
                out[i+j] += ai*bj
        return self.trim(out)

    def compose(self, f: Vector, h: Vector) -> Vector:
        out = (self.zero,)
        for c in reversed(f):
            out = self.add(self.multiply(out, h), (c,))
        return out

    def compose_chain(self, chain: Iterable[Vector]) -> Vector:
        out = (self.zero, self.one)
        for f in chain:
            out = self.compose(out, f)
        return out

    def divide_monic(self, p: Vector, h: Vector) -> tuple[Vector, Vector]:
        n, d = len(p)-1, len(h)-1
        if d < 1 or h[-1] != self.one:
            raise ValueError("A nonconstant monic divisor is required")
        if n < d:
            return (self.zero,), p
        r = list(p)
        q = [self.zero] * (n-d+1)
        for k in range(n, d-1, -1):
            c = r[k]
            q[k-d] = c
            for j in range(d):
                r[k-d+j] -= c*h[j]
            r[k] = self.zero
        return self.trim(q), self.trim(r[:d])

    def degrees(self, p: Vector) -> list[int]:
        n = len(p)-1
        return [int(d) for d in sp.divisors(n) if 1 < d < n] if n >= 4 else []

    def candidate(self, p: Vector, d: int) -> Vector:
        if d not in self.degrees(p):
            raise ValueError("The right degree must be a proper divisor")
        n, m = len(p)-1, (len(p)-1)//d
        c = [self.domain.exquo(p[n-j], p[-1]) for j in range(d)]
        b = [self.one] + [self.zero]*(d-1)
        for k in range(1, d):
            total = sum((self.domain.convert((m+1)*j-m*k)*c[j]*b[k-j]
                         for j in range(1, k+1)), self.zero)
            b[k] = self.domain.exquo(total, self.domain.convert(m*k))
        return (self.zero,) + tuple(reversed(b))

    def outer(self, p: Vector, h: Vector) -> dict[str, Any]:
        q, digits = p, []
        while len(q) > 1:
            quotient, remainder = self.divide_monic(q, h)
            if len(remainder) > 1:
                return dict(success=False, digit=len(digits),
                            remainder=remainder, previous=tuple(digits))
            digits.append(remainder[0])
            q = quotient
        digits.append(q[0])
        f = self.trim(digits)
        assert self.compose(f, h) == p
        return dict(success=True, outer=f)

    def trial(self, p: Vector, d: int) -> dict[str, Any]:
        h = self.candidate(p, d)
        return dict(right=h, right_degree=d, **self.outer(p, h))

    def pairs(self, p: Vector) -> list[tuple[Vector, Vector]]:
        out = []
        for d in self.degrees(p):
            t = self.trial(p, d)
            if t['success']:
                out.append((t['outer'], t['right']))
        return out

    def decompose(self, p: Vector, descending: bool = False) -> list[Vector]:
        degrees = self.degrees(p)
        if descending:
            degrees.reverse()
        for d in degrees:
            t = self.trial(p, d)
            if t['success']:
                out = self.decompose(t['outer'], descending) + \
                      self.decompose(t['right'], descending)
                assert self.compose_chain(out) == p
                return out
        return [p]

    def all_chains(self, p: Vector, limit: int | None = None) -> dict[str, Any]:
        if limit is not None and (type(limit) is not int or limit < 1):
            raise ValueError("limit must be None or a positive integer")
        out: list[list[Vector]] = []

        @lru_cache(maxsize=None)
        def pairs(q):
            return tuple(self.pairs(q))

        class Enough(Exception):
            pass

        def visit(q, suffix):
            ps = pairs(q)
            if not ps:
                chain = [q, *suffix]
                assert self.compose_chain(chain) == p
                out.append(chain)
                if limit is not None and len(out) > limit:
                    raise Enough
            else:
                for f, h in ps:
                    if not pairs(h):
                        visit(f, [h, *suffix])
        try:
            visit(p, [])
        except Enough:
            pass
        complete = limit is None or len(out) <= limit
        if not complete:
            out = out[:limit]
        return dict(chains=out, complete=complete, count=len(out))
