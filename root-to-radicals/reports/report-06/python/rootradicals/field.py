"""Exact quotient-field arithmetic and certified rectangular sign tests."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Any
import sympy as s
from .groups import TableGroup

@dataclass(frozen=True)
class Interval:
    lo: s.Rational
    hi: s.Rational
    def __add__(self, b: "Interval") -> "Interval":
        return Interval(self.lo + b.lo, self.hi + b.hi)
    def __neg__(self) -> "Interval": return Interval(-self.hi, -self.lo)
    def __sub__(self, b: "Interval") -> "Interval": return self + (-b)
    def __mul__(self, b: "Interval") -> "Interval":
        v = [self.lo*b.lo, self.lo*b.hi, self.hi*b.lo, self.hi*b.hi]
        return Interval(min(v), max(v))

@dataclass(frozen=True)
class Rectangle:
    re: Interval
    im: Interval
    @classmethod
    def rational(cls, a: s.Rational) -> "Rectangle":
        return cls(Interval(a, a), Interval(s.S.Zero, s.S.Zero))
    def __add__(self, b: "Rectangle") -> "Rectangle":
        return Rectangle(self.re+b.re, self.im+b.im)
    def __mul__(self, b: "Rectangle") -> "Rectangle":
        return Rectangle(self.re*b.re-self.im*b.im, self.re*b.im+self.im*b.re)

class ExactField:
    """Elements are SymPy ANP values, always reduced modulo an irreducible Q-polynomial."""
    def __init__(self, domain: Any):
        self.K = domain
        self.degree = int(domain.mod.degree())
        self.theta = domain.unit
        self.zero, self.one = domain.zero, domain.one
        self._theta_root = None
        self._conjugate_theta = None
        self._theta_rects: dict[int, Rectangle] = {}
        self._embedding_checks: dict[Any, bool] = {}

    def vector(self, a: Any) -> list[s.Rational]:
        v = [self.K.dom.to_sympy(c) for c in a.to_list()]
        return [s.S.Zero]*(self.degree-len(v)) + v

    def from_vector(self, v: list[s.Rational]):
        return self.K([self.K.dom.from_sympy(c) for c in v])

    def apply(self, image: Any, a: Any):
        out = self.zero
        for c in a.to_list():
            out = out*image + self.K(c)
        return out

    def matches_embedding(self, value: Any, target: s.Expr, polynomial: s.Poly) -> bool:
        """Independently anchor a field value to a specified complex embedding.

        Prove annihilation in the quotient first, then compare two KNOWN roots.
        This does not accept a number-field membership conversion merely because
        it returned a root of the right polynomial.
        """
        key = (value, target, polynomial)
        if key in self._embedding_checks: return self._embedding_checks[key]
        out = self.zero
        for c in polynomial.all_coeffs(): out = out*value+self.K.from_sympy(c)
        if out != self.zero: answer = False
        elif polynomial.degree() == 1: answer = True  # its only root
        else: answer = bool(polynomial.same_root(self.K.to_sympy(value), target))
        self._embedding_checks[key] = answer
        return answer

    def conjugate(self, a: Any):
        if self._conjugate_theta is None:
            target = s.conjugate(self.K.ext.root)
            image = self.K.from_sympy(target)
            if not self.matches_embedding(image, target, self.K.ext.minpoly):
                raise ArithmeticError("Conjugation selected an incorrect embedding")
            self._conjugate_theta = image
        return self.apply(self._conjugate_theta, a)

    def _root(self):
        if self._theta_root is None:
            mp = self.K.ext.minpoly
            # mp is the certified minimal polynomial of the primitive expression;
            # hence same_root's premise (both inputs are roots) is satisfied.
            roots = mp.all_roots(radicals=False)
            if len(roots) == 1: self._theta_root = roots[0]
            else:
                for r in roots:
                    if mp.same_root(r, self.K.ext.root):
                        self._theta_root = r; break
            if self._theta_root is None:
                raise ArithmeticError("Cannot isolate primitive embedding")
        return self._theta_root

    def theta_rectangle(self, bits: int) -> Rectangle:
        if bits not in self._theta_rects:
            r = self._root()
            eps = s.Rational(1, 2)**bits
            if isinstance(r, s.CRootOf):
                q = r.eval_rational(dx=eps, dy=eps)
                re, im = q.as_real_imag()
                box = Rectangle(Interval(re-eps, re+eps), Interval(im-eps, im+eps))
            elif r.is_Rational:
                box = Rectangle.rational(r)
            elif s.re(r).is_Rational and s.im(r).is_Rational:
                re, im = s.re(r), s.im(r)
                box = Rectangle(Interval(re, re), Interval(im, im))
            else:
                raise ArithmeticError("Unexpected non-isolated primitive root")
            self._theta_rects[bits] = box
        return self._theta_rects[bits]

    def rectangle(self, a: Any, bits: int) -> Rectangle:
        t = self.theta_rectangle(bits)
        out = Rectangle.rational(s.S.Zero)
        for c in a.to_list():
            out = out*t + Rectangle.rational(self.K.dom.to_sympy(c))
        return out

    def sign_component(self, a: Any, component: str) -> int:
        """Decide sign exactly. Zero is decided algebraically BEFORE refinement."""
        c = self.conjugate(a)
        if component == "real":
            if a + c == self.zero: return 0
        elif component == "imag":
            if a - c == self.zero: return 0
        else: raise ValueError("component must be real or imag")
        bits = 16
        while True:
            rect = self.rectangle(a, bits)
            v = rect.re if component == "real" else rect.im
            if v.lo > 0: return 1
            if v.hi < 0: return -1
            bits *= 2

    def principal_sector(self, a: Any, p: int, zeta_p: Any) -> bool:
        """Whether a lies in Arg(a) in (-pi/p, pi/p], for nonzero a."""
        if a == self.zero: return True
        if p == 2:
            re = self.sign_component(a, "real")
            return re > 0 or (re == 0 and self.sign_component(a, "imag") > 0)
        if p < 2 or p % 2 == 0:
            raise ValueError("Expected 2 or an odd prime")
        eta = -(zeta_p**((p+1)//2))  # exp(pi I/p), without adjoining a new field
        return (self.sign_component(a*eta, "imag") > 0 and
                self.sign_component(a/eta, "imag") <= 0)

    def automorphisms_fixing(self, fixed: Any):
        mp = self.K.ext.minpoly
        facs = s.Poly(mp.as_expr(), mp.gen, domain=self.K).factor_list()[1]
        images = []
        total = 0
        for f, multiplicity in facs:
            if f.degree() != 1 or multiplicity != 1:
                raise ArithmeticError("Field is not normal: primitive polynomial did not split")
            total += 1
            coeff = f.rep.to_list()
            image = -coeff[1]/coeff[0]
            if self.apply(image, fixed) == fixed:
                images.append(image)
        if total != self.degree or len(set(images)) != len(images):
            raise ArithmeticError("Incomplete automorphism enumeration")
        where = {a: i for i, a in enumerate(images)}
        if self.theta not in where:
            raise ArithmeticError("Missing identity automorphism")
        table = []
        for a in images:
            row = []
            for b in images:
                c = self.apply(a, b)
                if c not in where:
                    raise ArithmeticError("Automorphisms are not closed")
                row.append(where[c])
            table.append(row)
        return images, TableGroup(table, where[self.theta])

    def rational_coordinates(self, basis: list[Any], value: Any) -> list[s.Rational]:
        matrix = s.Matrix.hstack(*[s.Matrix(self.vector(b)) for b in basis])
        solution, parameters = matrix.gauss_jordan_solve(s.Matrix(self.vector(value)))
        if parameters.rows:
            raise ArithmeticError("Basis is not linearly independent")
        if any(not c.is_Rational for c in solution):
            raise ArithmeticError("Coordinates are not rational")
        if matrix*solution != s.Matrix(self.vector(value)):
            raise ArithmeticError("Coordinate reconstruction failed")
        return list(solution)
