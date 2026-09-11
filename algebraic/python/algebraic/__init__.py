"""Exact computation with polynomials and algebraic numbers.

One package for three operations that were developed separately and share an
engine:

* :mod:`algebraic.polynomial_decomposition` -- functional decomposition of a
  polynomial with exact algebraic coefficients, ``p = f(g(x))``, over SymPy
  number fields;
* :mod:`algebraic.root_decomposition` -- decomposition of an algebraic number
  into a sum or a product of algebraic numbers of the smallest possible
  maximum degree, on python-flint (Arb ball arithmetic, FLINT factoring,
  exact rational linear algebra);
* :mod:`algebraic.radicals` -- expression of an algebraic number by radicals
  whenever its Galois group is solvable, using the Galois engine of
  :mod:`algebraic.root_decomposition` directly.

The three were separate top-level modules, and the radical descent reached
its engine by putting a sibling directory on ``sys.path``; here it is an
ordinary package import.

The Wolfram Language counterpart is ``algebraic/Algebraic.wl``, which carries
a fourth operation, radical denesting (``DenestRadicals``), that has no Python
implementation.

The names below are the ones a caller normally needs; everything else stays
reachable through the modules.  Two names mean different things in the two
engines and are deliberately not re-exported here: ``verify_numeric``
(a decomposition versus a radical expression) and ``frobenius_cycle_types``
(taken over a fixed number of primes versus a caller-supplied one).  Ask for
them through the module, ``root_decomposition.verify_numeric`` or
``radicals.verify_numeric``.

Requires SymPy >= 1.14 and python-flint >= 0.8.
"""

from __future__ import annotations

from . import polynomial_decomposition, radicals, root_decomposition

# functional decomposition of polynomials
from .polynomial_decomposition import (
    EnumerationLimitError,
    compose,
    decompose,
    decomposition_data,
    decomposition_pairs,
    decompositions,
    right_decompose,
    verify_decomposition,
    verify_decomposition_data,
)

# sums and products of algebraic numbers
from .root_decomposition import (
    AlgebraicNumber,
    Decomposition,
    GaloisData,
    InputFieldData,
    PrecisionError,
    bounded_decomposition,
    catalog,
    galois_data,
    lower_bound,
    parse_wolfram_root,
    product_decomposition,
    sum_decomposition,
    wolfram_poly,
)

# radical expressions
from .radicals import (
    DescentError,
    NotFound,
    NotSolvable,
    RadicalResult,
    ResourceLimit,
    is_radical_expression,
    is_solvable,
    radical_depth,
    root_to_radicals,
)

__version__ = "1.0.0"

__all__ = [
    "polynomial_decomposition", "root_decomposition", "radicals",
    # polynomial_decomposition
    "decompose", "decompositions", "decomposition_pairs", "right_decompose",
    "decomposition_data", "compose", "verify_decomposition",
    "verify_decomposition_data", "EnumerationLimitError",
    # root_decomposition
    "AlgebraicNumber", "parse_wolfram_root", "wolfram_poly",
    "sum_decomposition", "product_decomposition", "bounded_decomposition",
    "catalog", "galois_data", "lower_bound",
    "Decomposition", "GaloisData", "InputFieldData", "PrecisionError",
    # radicals
    "root_to_radicals", "is_solvable", "RadicalResult",
    "is_radical_expression", "radical_depth",
    "NotSolvable", "NotFound", "ResourceLimit", "DescentError",
    "__version__",
]
