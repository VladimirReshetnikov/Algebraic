"""Finite-group computations on exact multiplication tables.

No list of transitive groups, assumed Galois action, or probabilistic decisions.
Multiplication t[a][b] means a composed with b.
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Iterable
import sympy as s

@dataclass
class TableGroup:
    table: list[list[int]]
    identity: int

    def __post_init__(self):
        self.order = len(self.table)
        self.inverse = []
        for a in range(self.order):
            matches = [b for b in range(self.order)
                       if self.table[a][b] == self.identity and self.table[b][a] == self.identity]
            if len(matches) != 1:
                raise ValueError("Invalid group inverse table")
            self.inverse.append(matches[0])

    def closure(self, generators: Iterable[int]) -> frozenset[int]:
        gens = sorted(set(generators))
        gens = sorted(set(gens + [self.inverse[g] for g in gens]))
        seen = {self.identity}
        queue = [self.identity]
        for a in queue:
            for b in gens:
                c = self.table[a][b]
                if c not in seen:
                    seen.add(c); queue.append(c)
        return frozenset(seen)

    def derived(self, h: Iterable[int]) -> frozenset[int]:
        h = sorted(h)
        commutators = []
        for a in h:
            for b in h:
                c = self.table[self.table[self.table[a][b]][self.inverse[a]]][self.inverse[b]]
                commutators.append(c)
        return self.closure(commutators)

    def derived_series(self, h: Iterable[int] | None = None) -> list[frozenset[int]]:
        out = [frozenset(range(self.order) if h is None else h)]
        while len(out[-1]) > 1:
            nxt = self.derived(out[-1])
            out.append(nxt)
            if nxt == out[-2]: break
        return out

    def prime_chain(self) -> list[frozenset[int]] | None:
        """Descending subnormal series, with normal prime-order quotients.

        Starting at H', greedily enlarge a proper subgroup. Every intermediate
        subgroup is normal since it contains H'. A maximal proper subgroup of
        the abelian quotient has prime index. No subgroup enumeration is needed.
        """
        h = frozenset(range(self.order))
        out = [h]
        while len(h) > 1:
            n = self.derived(h)
            if n == h: return None
            for g in sorted(h - n):
                test = self.closure(set(n) | {g})
                if test != h: n = test
            p, rem = divmod(len(h), len(n))
            if rem or not s.isprime(p):
                raise ArithmeticError("Prime-index construction failed")
            for g in h:
                for a in n:
                    if self.table[self.table[g][a]][self.inverse[g]] not in n:
                        raise ArithmeticError("Subgroup is not normal")
            out.append(n); h = n
        return out
