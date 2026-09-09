"""Exact functional decomposition over characteristic-zero algebraic fields.

Public chains are outermost first. Every nonfirst component is monic with
constant term zero. Coefficients are converted once per call to a SymPy exact
number field; no symbolic zero heuristics or floating-point tests are used.
The polynomial algorithm uses the formal-root recurrence and monic division,
not derivative factorization, polynomial factorization, or a built-in
decomposition oracle. Coefficient-field construction may internally factor.

This unifies the three accompanying reports. Report 03's full polynomial-base
digits are the certificate format; a verifier checks them without running the
candidate recurrence or polynomial division. Python-flint accelerates rational
polynomial arithmetic when SymPy uses its FLINT rational ground type.
"""

from __future__ import annotations

from functools import lru_cache
import itertools
import math

import sympy as sp
from sympy.polys.constructor import construct_domain
from sympy.polys.polyerrors import CoercionFailed, PolynomialError

try:
    from flint import fmpq, fmpq_poly
except ImportError:  # The exact SymPy-domain implementation remains available.
    fmpq = fmpq_poly = None


class EnumerationLimitError(RuntimeError):
    """More complete chains exist than the requested output limit permits."""

    complete = False

    def __init__(self, limit, partial_chains):
        self.limit = limit
        self.partial_chains = partial_chains
        super().__init__(f"more than {limit} complete chains exist; partial_chains contains the first {limit}")


def _is_integer(value):
    return not isinstance(value, bool) and isinstance(value, (int, sp.Integer))


def _integer(value, name, minimum=1):
    if not _is_integer(value) or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")
    return int(value)


def _degrees(n):
    """Proper possible inner degrees, in increasing order."""
    ds = set()
    for d in range(2, math.isqrt(n) + 1):
        if n % d == 0:
            ds.update((d, n // d))
    return sorted(ds)


def _proper_degree(n, d):
    return _is_integer(d) and 1 < d < n and n % d == 0


def _obstruction(digits):
    """First nonconstant base digit, with zero-based digit and power indices."""
    return next(((j, k, value) for j, digit in enumerate(digits)
                 for k, value in enumerate(digit[1:], 1) if value), None)


def _raw_coefficients(expression, x):
    expression = sp.sympify(expression)
    if not isinstance(expression, (sp.Expr, sp.Poly)):
        raise ValueError("the input must be a polynomial expression or Poly")
    if expression.has(sp.Float):
        raise ValueError("approximate coefficients are not accepted")
    if isinstance(expression, sp.Expr) and x not in expression.free_symbols:
        return [expression]
    # CRootOf binds its own polynomial variable. SymPy's expression-domain
    # Poly constructor can nevertheless mistake that bound x for the outer
    # generator. Shield exact algebraic atoms while collecting coefficients.
    atoms = expression.atoms(sp.CRootOf, sp.AlgebraicNumber)
    shield = {atom: sp.Dummy("algebraic_coefficient") for atom in atoms}
    restore = {temporary: atom for atom, temporary in shield.items()}
    polynomial = sp.Poly(expression.xreplace(shield), x, domain=sp.EX)
    return [c.xreplace(restore) for c in reversed(polynomial.all_coeffs())]


def _prepare(expressions, x):
    if not isinstance(x, sp.Symbol):
        raise ValueError("x must be a Symbol")
    if len(expressions) == 1 and isinstance(expressions[0], sp.Poly):
        polynomial = expressions[0]
        if polynomial.gens == (x,) and (polynomial.domain in (sp.ZZ, sp.QQ) or polynomial.domain.is_AlgebraicField):
            polynomial = polynomial.to_field()
            engine = _Engine(polynomial.domain)
            return engine, [engine.trim(reversed(polynomial.rep.to_list()))]
    coefficients, sizes = [], []
    for expression in expressions:
        if isinstance(expression, sp.Poly):
            if expression.gens != (x,) or expression.domain.characteristic() != 0:
                raise ValueError("a univariate characteristic-zero polynomial is required")
            expression = expression.as_expr()
        try:
            raw = _raw_coefficients(expression, x)
        except (PolynomialError, CoercionFailed) as exc:
            raise ValueError("the input must be a polynomial in x") from exc
        for coefficient in raw:
            if coefficient.free_symbols or coefficient.is_algebraic is False:
                raise ValueError("coefficients must be explicit exact algebraic numbers")
        coefficients.extend(raw)
        sizes.append(len(raw))

    # Verification commonly receives an exact Poly together with expressions
    # for its components. Preserve the existing field whenever it contains
    # all coefficients, instead of rebuilding a primitive element.
    for expression in expressions:
        if isinstance(expression, sp.Poly) and expression.domain.is_AlgebraicField:
            try:
                engine, converted = _convert_coefficients(expression.domain, coefficients)
            except (CoercionFailed, ValueError, NotImplementedError):
                continue
            return engine, _split_vectors(engine, converted, sizes)

    if all(c.is_Rational for c in coefficients):
        engine, converted = _convert_coefficients(sp.QQ, coefficients)
    else:
        # Explicit root atoms are useful generators even when a whole
        # coefficient cancels by a minimal-polynomial identity. Constructing
        # the field of that zero expression directly can be needlessly costly.
        generators = set()
        for c in coefficients:
            generators.update(c.atoms(sp.CRootOf, sp.AlgebraicNumber))
            generators.update(power for power in c.atoms(sp.Pow)
                              if power.exp.is_Rational and not power.exp.is_Integer
                              and power.is_algebraic is not False)
            if c.has(sp.I):
                generators.add(sp.I)
        try:
            if not generators:
                raise CoercionFailed("infer the coefficient field")
            domain = sp.QQ.algebraic_field(*sorted(generators, key=sp.default_sort_key))
            engine, converted = _convert_coefficients(domain, coefficients)
        except (CoercionFailed, ValueError, NotImplementedError):
            try:
                domain, converted = construct_domain(coefficients, extension=True)
                if domain in (sp.ZZ, sp.QQ):
                    engine, converted = _convert_coefficients(sp.QQ, coefficients)
                elif not domain.is_AlgebraicField:
                    domain = sp.QQ.algebraic_field(*[c for c in coefficients if not c.is_Rational])
                    engine, converted = _convert_coefficients(domain, coefficients)
                else:
                    engine = _Engine(domain)
            except (CoercionFailed, ValueError, NotImplementedError, sp.polys.polyerrors.NotAlgebraic) as exc:
                raise ValueError("coefficients could not be represented in an exact algebraic number field") from exc
    return engine, _split_vectors(engine, converted, sizes)


def _convert_coefficients(domain, coefficients):
    engine = _Engine(domain)
    return engine, list(map(engine.scalar, coefficients))


def _split_vectors(engine, converted, sizes):
    coefficients = iter(converted)
    return [engine.trim(itertools.islice(coefficients, size)) for size in sizes]


class _Engine:
    """Ascending coefficient vectors with exact equality in one fixed field."""

    def __init__(self, domain):
        self.K = domain
        self.zero, self.one = domain.zero, domain.one
        self.native = fmpq is not None and isinstance(self.one, fmpq)
        self._trials = {}
        self._pairs = {}
        self._scalars = {}
        if domain.is_AlgebraicField:
            self._scalars[domain.ext.as_expr()] = domain.unit

    def scalar(self, expression):
        """Evaluate known algebraic expressions by arithmetic in the field.

        Calling to_number_field on each coefficient is unnecessary when it
        is already a rational expression in the field's selected generators.
        Unrecognized exact algebraic constants still use SymPy's conversion.
        """
        if expression in self._scalars:
            return self._scalars[expression]
        if expression.is_Rational:
            value = self.K.convert(expression)
        elif expression.is_Add:
            value = sum((self.scalar(arg) for arg in expression.args), self.zero)
        elif expression.is_Mul:
            value = self.one
            for arg in expression.args:
                value *= self.scalar(arg)
        elif expression.is_Pow and expression.exp.is_Integer:
            value = self.scalar(expression.base) ** int(expression.exp)
        elif isinstance(expression, sp.AlgebraicNumber):
            value = self.scalar(expression.as_expr())
        else:
            value = self.K.from_sympy(expression)
        self._scalars[expression] = value
        return value

    def trim(self, coefficients):
        result = list(coefficients) or [self.zero]
        while len(result) > 1 and not result[-1]:
            result.pop()
        return tuple(result)

    def expression(self, v, x):
        return sp.Add(*(self.symbolic(c) * x ** i for i, c in enumerate(v) if c))

    def symbolic(self, coefficient):
        expression = self.K.to_sympy(coefficient)
        return expression.xreplace({atom: atom.as_expr() for atom in expression.atoms(sp.AlgebraicNumber)})

    def add(self, a, b):
        return self.trim(c + d for c, d in itertools.zip_longest(a, b, fillvalue=self.zero))

    def subtract(self, a, b):
        return self.add(a, [-c for c in b])

    def multiply(self, a, b, truncate=None):
        if a == (self.zero,) or b == (self.zero,):
            return (self.zero,)
        if self.native:
            values = (fmpq_poly(list(a)) * fmpq_poly(list(b))).coeffs()
            return self.trim(values if truncate is None else values[:truncate])
        length = len(a) + len(b) - 1
        if truncate is not None:
            length = min(length, truncate)
        values = [self.zero] * length
        nonzero_b = [(j, c) for j, c in enumerate(b) if c]
        for i, c in enumerate(a):
            if c:
                for j, d in nonzero_b:
                    if i + j >= length:
                        break
                    values[i + j] += c * d
        return self.trim(values)

    def power(self, a, exponent, truncate=None):
        result = (self.one,)
        while exponent:
            if exponent & 1:
                result = self.multiply(result, a, truncate)
            exponent >>= 1
            if exponent:
                a = self.multiply(a, a, truncate)
        return result

    def compose_digits(self, digits, inner):
        result = (self.zero,)
        for digit in reversed(digits):
            result = self.add(self.multiply(result, inner), digit)
        return result

    def compose(self, outer, inner):
        if self.native:
            return self.trim(fmpq_poly(list(outer))(fmpq_poly(list(inner))).coeffs())
        return self.compose_digits([(coefficient,) for coefficient in outer], inner)

    def compose_chain(self, parts):
        result = (self.zero, self.one)
        for part in reversed(parts):
            result = self.compose(part, result)
        return result

    def candidate(self, c, d):
        n, m = len(c) - 1, (len(c) - 1) // d
        s = [self.K.exquo(c[n - i], c[-1]) for i in range(d)]
        u = [self.one] + [self.zero] * (d - 1)
        nonzero_s = [i for i in range(1, d) if s[i]]
        if not nonzero_s:
            return (self.zero,) * d + (self.one,)
        for k in range(1, d):
            total = self.zero
            for i in nonzero_s:
                if i > k:
                    break
                scalar = (m + 1) * i - m * k
                if scalar and u[k - i]:
                    total += scalar * s[i] * u[k - i]
            u[k] = total / (m * k)
        return (self.zero,) + tuple(reversed(u))

    def divide_monic(self, a, h):
        d, n = len(h) - 1, len(a) - 1
        if n < d:
            return (self.zero,), a
        if self.native:
            quotient, remainder = divmod(fmpq_poly(list(a)), fmpq_poly(list(h)))
            return self.trim(quotient.coeffs()), self.trim(remainder.coeffs())
        remainder, quotient = list(a), [self.zero] * (n - d + 1)
        nonzero_h = [(j, value) for j, value in enumerate(h[:-1]) if value]
        for k in range(n - d, -1, -1):
            coefficient = remainder[k + d]
            quotient[k] = coefficient
            if coefficient:
                for j, value in nonzero_h:
                    remainder[k + j] -= coefficient * value
            remainder[k + d] = self.zero
        return self.trim(quotient), self.trim(remainder[:d])

    def base_digits(self, c, h):
        """Yield successive remainders; searches can stop at the first obstruction."""
        if not any(h[:-1]):
            d = len(h) - 1
            if c != (self.zero,):
                yield from (self.trim(c[j:j + d]) for j in range(0, len(c), d))
            return
        while c != (self.zero,):
            c, remainder = self.divide_monic(c, h)
            yield remainder

    def attempt(self, c, d):
        key = c, d
        if key not in self._trials:
            h, digits = self.candidate(c, d), []
            for remainder in self.base_digits(c, h):
                if len(remainder) > 1:
                    self._trials[key] = None
                    break
                digits.append(remainder[0])
            else:
                self._trials[key] = (self.trim(digits), h)
        return self._trials[key]

    def iter_pairs(self, c):
        for d in _degrees(len(c) - 1):
            if (pair := self.attempt(c, d)) is not None:
                yield pair

    def pairs(self, c):
        if c not in self._pairs:
            self._pairs[c] = tuple(self.iter_pairs(c))
        return self._pairs[c]

    def first_pair(self, c):
        return next(self.iter_pairs(c), None)

    def one_chain(self, c):
        suffix = []
        while (pair := self.first_pair(c)) is not None:
            c, h = pair
            suffix.append(h)
        return [c] + list(reversed(suffix))

    def chains(self, c, suffix=()):
        pairs = self.pairs(c)
        if not pairs:
            yield (c,) + suffix
        else:
            for outer, inner in pairs:
                if self.first_pair(inner) is None:
                    yield from self.chains(outer, (inner,) + suffix)

    def certificate(self, c, d, x):
        h = self.candidate(c, d)
        digits = list(self.base_digits(c, h))
        outer = self.trim(digit[0] for digit in digits)
        witness = _obstruction(digits)
        obstruction = None if witness is None else {
            "digit_index": witness[0], "power": witness[1], "coefficient": self.symbolic(witness[2])}
        return {"type": "DegreeTest", "right_degree": d, "outer_degree": (len(c) - 1) // d,
                "inner": self.expression(h, x), "outer_candidate": self.expression(outer, x),
                "digits": [self.expression(r, x) for r in digits],
                "decomposable": obstruction is None, "obstruction": obstruction,
                "residual": sp.S.Zero if witness is None else
                    self.expression(self.subtract(c, self.compose(outer, h)), x)}


def decompose(p, x):
    """Return one complete normalized chain, outermost first.

    Constants and linear polynomials return the singleton [p]. For nonlinear
    inputs every component has degree at least two and is indecomposable over
    every characteristic-zero extension of the coefficient field.
    """
    engine, (c,) = _prepare([p], x)
    return [engine.expression(v, x) for v in engine.one_chain(c)]


def decompositions(p, x, *, max_chains=None):
    """Enumerate all complete normalized chains without affine duplicates.

    A finite cap is an output bound, not a time or arithmetic-memory bound.
    If more chains exist, raise EnumerationLimitError containing partial_chains
    and complete=False. Exactly hitting the cap still returns a complete list.
    """
    if max_chains is not None:
        max_chains = _integer(max_chains, "max_chains")
    engine, (c,) = _prepare([p], x)
    stream = engine.chains(c)
    if max_chains is not None:
        stream = itertools.islice(stream, max_chains + 1)
    chains = [[engine.expression(v, x) for v in chain] for chain in stream]
    if max_chains is not None and len(chains) > max_chains:
        raise EnumerationLimitError(max_chains, chains[:max_chains])
    return chains


def decomposition_pairs(p, x):
    """All normalized nontrivial (outer, inner) pairs, in inner-degree order."""
    engine, (c,) = _prepare([p], x)
    return [tuple(engine.expression(v, x) for v in pair) for pair in engine.pairs(c)]


def right_decompose(p, x, d):
    """The unique normalized degree-d pair, or None if it does not exist.

    An invalid degree raises ValueError; a valid unsuccessful trial returns
    None. Use decomposition_data(p, x, d) for its exact negative witness.
    """
    d = _integer(d, "d", 2)
    engine, (c,) = _prepare([p], x)
    if not _proper_degree(len(c) - 1, d):
        raise ValueError("d must be a proper divisor of the input degree")
    pair = engine.attempt(c, d)
    return None if pair is None else tuple(engine.expression(v, x) for v in pair)


def decomposition_data(p, x, d=None):
    """Produce a full fixed-degree certificate, or exhaustive degree tests."""
    engine, (c,) = _prepare([p], x)
    n = len(c) - 1
    if d is not None:
        d = _integer(d, "d", 2)
        if not _proper_degree(n, d):
            raise ValueError("d must be a proper divisor of the input degree")
        return engine.certificate(c, d, x)
    degrees = _degrees(n)
    tests = [engine.certificate(c, d, x) for d in degrees]
    accepted = [test["right_degree"] for test in tests if test["decomposable"]]
    return {"type": "AllDegreeTests", "input_degree": -sp.oo if c == (engine.zero,) else n,
            "tested_right_degrees": degrees, "accepted_right_degrees": accepted,
            "indecomposable": None if n < 2 else not accepted, "tests": tests}


def compose(parts, x):
    """Compose an outermost-first sequence; the empty sequence represents x."""
    if not isinstance(parts, (list, tuple)):
        raise ValueError("parts must be a list or tuple")
    engine, vectors = _prepare(parts, x)
    return engine.expression(engine.compose_chain(vectors), x)


def verify_decomposition(p, parts, x, *, require_complete=False, require_normalized=False):
    """Check an exact identity, optionally completeness and normalization.

    Completeness checks every component using the degree decision algorithm;
    it is distinct from the independent certificate checker. A singleton
    constant or linear polynomial satisfies the documented low-degree convention.
    """
    if type(require_complete) is not bool or type(require_normalized) is not bool:
        raise ValueError("verification options must be booleans")
    if not isinstance(parts, (list, tuple)):
        return False
    engine, vectors = _prepare([p] + list(parts), x)
    c, chain = vectors[0], vectors[1:]
    if engine.compose_chain(chain) != c:
        return False
    if require_normalized and any(h[0] or h[-1] != engine.one for h in chain[1:]):
        return False
    if require_complete:
        if len(c) <= 2:
            return len(chain) == 1 and chain[0] == c
        return bool(chain) and all(len(h) > 2 and engine.first_pair(h) is None for h in chain)
    return True


def _verify_degree_data(c, test, engine, vector):
    """No candidate recurrence or polynomial division is used here."""
    required = {"type", "right_degree", "outer_degree", "inner", "outer_candidate",
                "digits", "decomposable", "obstruction", "residual"}
    if not isinstance(test, dict) or not required <= test.keys() or test["type"] != "DegreeTest":
        return False
    n, d = len(c) - 1, test["right_degree"]
    if not _proper_degree(n, d):
        return False
    m = n // d
    if (type(test["decomposable"]) is not bool or not _is_integer(test["outer_degree"])
            or test["outer_degree"] != m):
        return False
    if not isinstance(test["digits"], list) or len(test["digits"]) != m + 1:
        return False
    h, outer = vector(test["inner"]), vector(test["outer_candidate"])
    digits = [vector(digit) for digit in test["digits"]]
    if len(h) != d + 1 or h[0] or h[-1] != engine.one or any(len(r) > d for r in digits):
        return False
    # Reverse coefficients turn the top congruence for h^m into a truncated
    # ordinary power. This independently proves the unique forced candidate.
    top = engine.power(tuple(reversed(h)), m, truncate=d)
    for k in range(d):
        coefficient = top[k] if k < len(top) else engine.zero
        if coefficient * c[-1] != c[n - k]:
            return False
    reconstructed = engine.compose_digits(digits, h)
    if reconstructed != c or outer != engine.trim(r[0] for r in digits):
        return False
    witness = _obstruction(digits)
    if test["decomposable"] != (witness is None):
        return False
    obstruction = test["obstruction"]
    if witness is None:
        if obstruction is not None:
            return False
    else:
        if not isinstance(obstruction, dict) or not {"digit_index", "power", "coefficient"} <= obstruction.keys():
            return False
        j, k, coefficient = witness
        if (not _is_integer(obstruction["digit_index"]) or not _is_integer(obstruction["power"])
                or obstruction["digit_index"] != j or obstruction["power"] != k
                or vector(obstruction["coefficient"]) != (coefficient,)):
            return False
    # Reconstruction with constant digits already proves c = outer(h).
    residual = (engine.zero,) if witness is None else engine.subtract(c, engine.compose(outer, h))
    return vector(test["residual"]) == residual


def verify_decomposition_data(p, data, x):
    """Independently validate a fixed-degree or exhaustive certificate.

    Invalid polynomial input raises ValueError. Malformed, incomplete, or
    altered certificate data returns False. Exhaustive records must cover
    exactly every proper divisor, including all negative witnesses.
    """
    engine, (c,) = _prepare([p], x)
    # Share conversions across degree tests, retaining this input's exact field.
    @lru_cache(maxsize=None, typed=True)
    def vector(expression):
        return engine.trim(map(engine.scalar, _raw_coefficients(expression, x)))

    try:
        if not isinstance(data, dict):
            return False
        if data.get("type") == "DegreeTest":
            return _verify_degree_data(c, data, engine, vector)
        required = {"type", "input_degree", "tested_right_degrees", "accepted_right_degrees", "indecomposable", "tests"}
        if not required <= data.keys() or data["type"] != "AllDegreeTests":
            return False
        n = len(c) - 1
        degrees = _degrees(n)
        if data["input_degree"] != (-sp.oo if c == (engine.zero,) else n):
            return False
        if c != (engine.zero,) and not _is_integer(data["input_degree"]):
            return False
        for key in ("tested_right_degrees", "accepted_right_degrees"):
            if not isinstance(data[key], list) or not all(map(_is_integer, data[key])):
                return False
        if (data["tested_right_degrees"] != degrees or not isinstance(data["tests"], list)
                or len(data["tests"]) != len(degrees)):
            return False
        for d, test in zip(degrees, data["tests"]):
            if not _verify_degree_data(c, test, engine, vector) or test["right_degree"] != d:
                return False
        accepted = [d for d, test in zip(degrees, data["tests"]) if test["decomposable"]]
        expected = None if n < 2 else not accepted
        return data["accepted_right_degrees"] == accepted and data["indecomposable"] is expected
    except (ValueError, TypeError, KeyError, IndexError, PolynomialError, CoercionFailed, NotImplementedError):
        return False
