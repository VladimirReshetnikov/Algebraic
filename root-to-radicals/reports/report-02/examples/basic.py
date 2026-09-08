"""Run from the archive root after `pip install ./python`."""
import sympy as s
from radicalroot import radicalize, verify_result
x = s.Symbol("x")
for f, index, method in [
    (5*x**5-25*x**3+25*x+6, 4, "fast"),
    (x**6+x**4-x**3-x**2-1, 1, "fast"),
    (x**3-2, 0, "galois"),
    (x**5-x-1, 0, "galois"),
]:
    result = radicalize(f, index, method=method)
    print("\nPolynomial:", f, "SymPy index:", index)
    print("Status:", result.status, "Method:", result.method)
    if result.success:
        print("Radicals:", result.expression)
        print("Independent exact check:", verify_result(result))
        if "chain_indices" in result.certificate:
            print("Prime indices:", result.certificate["chain_indices"])
    else:
        print(result.message)
