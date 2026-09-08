"""Exact, branch-aware conversion of algebraic numbers to radical programs."""
from .program import RadicalProgram, radical_expression
from .solver import RadicalResult, radicalize, certify_expression, dickson, zeta_expr
__all__ = ["RadicalProgram", "RadicalResult", "radicalize", "certify_expression",
           "radical_expression", "dickson", "zeta_expr"]
__version__ = "0.1.0"
