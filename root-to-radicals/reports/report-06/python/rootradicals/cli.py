"""JSON protocol and a killable worker process, including on Windows.

Polynomial coefficients are descending rational pairs [numerator, denominator]
with both entries decimal strings. A zero-based SymPy index OR an approximate
embedding hint is required. Wolfram callers MUST verify the returned expression
against the original Root: a numerical hint is not a certificate of root identity.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess
import sys
import warnings
from typing import Any
import sympy as s
from sympy.utilities.exceptions import SymPyDeprecationWarning
from .program import RadicalProgram, integer
from .solver import radicalize

def rational(pair: Any) -> s.Rational:
    if not isinstance(pair, list) or len(pair) != 2:
        raise ValueError("Expected a rational [numerator, denominator] pair")
    n, d = integer(pair[0]), integer(pair[1])
    if d <= 0: raise ValueError("Denominator must be positive")
    return s.Rational(n, d)

def request_target(request: dict[str, Any]):
    coeffs = [rational(c) for c in request["coefficients"]]
    if len(coeffs) < 2 or coeffs[0] == 0:
        raise ValueError("Expected a nonconstant polynomial with nonzero leading coefficient")
    x = s.Symbol("x")
    f = s.Poly.from_list(coeffs, x, domain=s.QQ)
    roots = f.all_roots(radicals=False)
    if "root_index" in request:
        k = request["root_index"]
        if type(k) is not int or not 0 <= k < len(roots):
            raise ValueError("root_index must be a zero-based SymPy root index")
    elif "embedding_hint" in request:
        hint = request["embedding_hint"]
        re, im = rational(hint["re"]), rational(hint["im"])
        precision = request.get("hint_digits", 80)
        if type(precision) is not int or not 20 <= precision <= 100000:
            raise ValueError("hint_digits must be an integer between 20 and 100000")
        def score(r):
            a, b = s.N(r, precision).as_real_imag()
            return s.N((a-re)**2+(b-im)**2, precision)
        k = min(range(len(roots)), key=lambda j: score(roots[j]))
    else:
        raise ValueError("Provide root_index or embedding_hint")
    return roots[k], k

def worker(request: dict[str, Any]) -> dict[str, Any]:
    target, index = request_target(request)
    hints = [RadicalProgram.from_json(p).expression() for p in request.get("extension_hints", [])]
    answer = radicalize(target, method=request.get("method", "auto"),
                        max_field_degree=request.get("max_field_degree", 64),
                        extension_hints=hints,
                        galois_precheck=request.get("galois_precheck", True))
    out = answer.to_json()
    out["selected_sympy_root_index"] = index
    out["backend_version"] = "0.1.0"
    out["sympy_version"] = s.__version__
    return out

def main() -> int:
    # SymPy currently emits an irrelevant modular-factor-ordering deprecation.
    warnings.filterwarnings("ignore", category=SymPyDeprecationWarning)
    try:
        raw = sys.stdin.read(10_000_001)
        if len(raw) > 10_000_000: raise ValueError("Request exceeds 10 MB")
        request = json.loads(raw)
        if not isinstance(request, dict): raise ValueError("Expected a JSON object")
        if "--worker" in sys.argv:
            out = worker(request)
        else:
            limit = request.get("time_limit", 180)
            if limit is not None and (not isinstance(limit, (int, float)) or limit <= 0):
                raise ValueError("time_limit must be positive or null")
            env = os.environ.copy()
            package_root = str(Path(__file__).resolve().parents[1])
            env["PYTHONPATH"] = package_root + os.pathsep + env.get("PYTHONPATH", "")
            process = subprocess.Popen([sys.executable, "-m", "rootradicals.cli", "--worker"],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, encoding="utf-8", env=env)
            try:
                stdout, stderr = process.communicate(raw, timeout=limit)
                if process.returncode:
                    out = {"status": "unknown", "method": "worker",
                           "message": "Backend worker failed", "details": {"stderr": stderr[-8000:]}}
                else:
                    out = json.loads(stdout)
            except subprocess.TimeoutExpired:
                process.kill()
                _, stderr = process.communicate()
                out = {"status": "resource_limit", "method": "worker-timeout",
                       "message": f"The backend exceeded its {limit}-second time limit.",
                       "details": {"stderr": stderr[-2000:]}}
    except (ValueError, KeyError, TypeError) as exc:
        out = {"status": "invalid_input", "method": "protocol", "message": str(exc)}
    except Exception as exc:
        out = {"status": "unknown", "method": "backend-error",
               "message": f"{type(exc).__name__}: {exc}"}
    print(json.dumps(out, ensure_ascii=True, separators=(",", ":")))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
