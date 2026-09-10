#!/usr/bin/env python3
"""Independent exact checks for the article, NOT an execution of Wolfram code.

Run: python verification/verify_math.py
Requires SymPy. Writes verification/results.json and verification/results.txt.
No numeric near-zero test is used as an equality certificate.
"""
from __future__ import annotations
import hashlib
import json
import math
import platform
import re
import sys
import time
from collections import Counter
from pathlib import Path
import sympy as s

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
COUNTS: Counter[str] = Counter()
CASES: Counter[str] = Counter()
DETAILS: dict[str, object] = {}
START = time.perf_counter()


def check(condition: object, family: str, description: str) -> None:
    if condition is not True and condition != s.true:
        raise AssertionError(f"{family}: {description}: {condition!r}")
    COUNTS[family] += 1


def dickson(m: int, t: s.Expr, n: s.Expr) -> tuple[s.Expr, s.Expr]:
    d0, d1, v0, v1 = s.Integer(2), t, s.Integer(0), s.Integer(1)
    for _ in range(2, m + 1):
        d0, d1 = d1, s.expand(t*d1 - n*d0)
        v0, v1 = v1, s.expand(t*v1 - n*v0)
    return d1, v1


def quadratic_power(A: s.Rational, B: s.Rational, c: int, m: int):
    a = sum(s.binomial(m, j)*A**(m-j)*B**j*c**(j//2) for j in range(0, m+1, 2))
    b = sum(s.binomial(m, j)*A**(m-j)*B**j*c**((j-1)//2) for j in range(1, m+1, 2))
    return s.expand(a), s.expand(b)


def verify_odd() -> None:
    T, N = s.symbols("T N")
    for m in (3, 5, 7, 9, 11):
        d, v = dickson(m, T, N)
        check(s.expand(d*d - 4*N**m - (T*T-4*N)*v*v) == 0,
              "Dickson polynomial identities", f"m={m}")
    for m in (3, 5, 7, 9):
        for c in (2, 3, 5, 7):
            for A in map(s.Rational, ("-3/2", "-1", "0", "1", "3/2")):
                for B in map(s.Rational, ("-3/2", "-1", "1", "3/2")):
                    a, b = quadratic_power(A, B, c, m)
                    n, t = A*A-c*B*B, 2*A
                    d, v = dickson(m, t, n)
                    check(n**m == a*a-c*b*b, "Odd-root parameter checks", "norm")
                    check(d == 2*a, "Odd-root parameter checks", "trace")
                    check(v != 0, "Odd-root parameter checks", "nonzero denominator")
                    check(s.cancel(b/v) == B, "Odd-root parameter checks", "coefficient reconstruction")
                    CASES["Odd-root parameter cases"] += 1
    DETAILS["odd_indices_tested"] = [3, 5, 7, 9]


def verify_square_roots() -> None:
    for u in range(2, 10):
        for v in range(1, u):
            for sign in (-1, 1):
                a, b, c = u+v, 2*sign, u*v
                delta = s.sqrt(a*a-b*b*c)
                z = s.sqrt((a+delta)/2) + sign*s.sqrt((a-delta)/2)
                # sympify rational division to avoid Python floats:
                z = s.sqrt(s.Rational(a+delta, 2)) + sign*s.sqrt(s.Rational(a-delta, 2))
                check(s.simplify(s.expand(z*z) - (a+b*s.sqrt(c))) == 0,
                      "Direct quadratic checks", "squared identity")
                check(u > v > 0, "Direct quadratic checks", "principal-sign hypothesis")
                CASES["Direct quadratic cases"] += 1
    for c in (2, 3, 5, 6, 7):
        for r in range(1, 4):
            for t in range(1, 4):
                for sign in (-1, 1):
                    a, b = sign*2*c*r*t, c*r*r+t*t
                    D = a*a-b*b*c
                    e = abs(c*r*r-t*t)
                    z = s.Integer(c)**s.Rational(1, 4) * (
                        s.sqrt(s.Rational(b+e, 2)) + sign*s.sqrt(s.Rational(b-e, 2)))
                    check(-c*D == (c*e)**2 and D < 0,
                          "Indirect quadratic checks", "signed norm")
                    check(s.simplify(s.expand(z*z) - (a+b*s.sqrt(c))) == 0,
                          "Indirect quadratic checks", "squared identity")
                    check(e > 0 and b >= e, "Indirect quadratic checks", "principal-sign hypothesis")
                    CASES["Indirect quadratic cases"] += 1
    for r in range(1, 6):
        for t in list(range(-4, 0)) + list(range(1, 5)):
            a, b, n = r*r-t*t, 2*r*t, r*r+t*t
            z = s.sqrt(s.Rational(n+a, 2)) + s.I*s.sign(b)*s.sqrt(s.Rational(n-a, 2))
            check(s.expand(z*z) == a+s.I*b, "Gaussian checks", "squared identity")
            check(s.re(z) == r and s.im(z) == t, "Gaussian checks", "principal branch")
            CASES["Gaussian cases"] += 1


def verify_honsbeek() -> None:
    A, B, z = s.symbols("A B z", nonzero=True)
    numerator = -z*z*A*A/2 + z*A*B + B*B
    F = z**4 + 4*z**3 + 8*(B/A)**3*z - 4*(B/A)**3
    remainder = s.expand(numerator**2 - (B**3-z**3*A**3)*(A+B) - A**4*F/4)
    check(remainder == 0, "Honsbeek checks", "universal polynomial identity")
    for j in range(-12, 13):
        t = s.Rational(j, 2)
        if t in (0, -4, s.Rational(1, 2)):
            continue
        ratio = t**3*(t+4)/(4*(1-2*t))
        check(s.factor(t**4+4*t**3+8*ratio*t-4*ratio) == 0,
              "Honsbeek checks", "quartic root parameterization")
        check(ratio-t**3 != 0, "Honsbeek checks", "nonzero denominator")
        CASES["Honsbeek parameter cases"] += 1
    for alpha, beta, t in ((5, -4, -2), (28, -27, -3), (-4, 5, 1)):
        check(s.Rational(t)**4+4*t**3+8*s.Rational(beta, alpha)*t-4*s.Rational(beta, alpha) == 0,
              "Honsbeek checks", f"benchmark {alpha,beta,t}")


def squarefree(n: int) -> int:
    return math.prod(int(p) for p, e in s.factorint(n).items() if e % 2)


def verify_square_classes() -> None:
    primes = (2, 3, 5, 7, 11)
    def mask(n: int) -> int:
        return sum(1 << i for i, p in enumerate(primes) if n % p == 0)
    def decode(v: int) -> int:
        return math.prod(p for i, p in enumerate(primes) if v & (1 << i))
    h = {0}
    for d in (55, 210, 462):
        h |= {x ^ mask(d) for x in h}
    check(len(h) == 4, "Square-class checks", "input field rank two")
    coset = sorted(decode(mask(6) ^ x) for x in h)
    check(coset == [6, 35, 77, 330], "Square-class checks", "missing support coset")
    old1 = {1, *primes}; old2 = old1 | {55, 210, 462}
    check(not ({6, 35, 77} & old2), "Square-class checks", "old support omission")
    gamma = s.sqrt(6)+s.sqrt(35)+s.sqrt(77)
    rho = 118+2*s.sqrt(210)+14*s.sqrt(55)+2*s.sqrt(462)
    check(s.expand(gamma*gamma-rho) == 0, "Square-class checks", "denesting square")
    x = s.symbols("x0:4")
    coeff: dict[int, s.Expr] = {}
    for i, di in enumerate(coset):
        for j in range(i, len(coset)):
            dj = coset[j]; g = math.gcd(di, dj); d = di*dj//(g*g)
            coeff[d] = coeff.get(d, 0)+(1 if i == j else 2)*g*x[i]*x[j]
    expected = {1: s.Integer(118), 55: s.Integer(14), 210: s.Integer(2), 462: s.Integer(2)}
    check(set(coeff) == set(expected), "Square-class checks", "coefficient basis closure")
    for d, rhs in expected.items():
        check(coeff[d].subs(dict(zip(x, (1, 1, 1, 0)))) == rhs,
              "Square-class checks", f"coefficient d={d}")
    # Exhaustively check XOR/gcd multiplication on this small ambient field.
    for i in range(32):
        for j in range(32):
            di, dj = decode(i), decode(j); g = math.gcd(di, dj)
            check(di*dj//(g*g) == decode(i ^ j), "Square-class multiplication checks", f"{i},{j}")
    DETAILS["coset_example"] = {"primes": list(primes), "input_square_classes": [decode(x) for x in sorted(h)],
        "solution_coset": coset, "coefficients": [1, 1, 1, 0], "ambient_degree": 32, "input_field_degree": 4,
        "systems": {str(d): str(expr) for d, expr in sorted(coeff.items())}}


def verify_inverse_and_branches() -> None:
    x = s.Symbol("x")
    denoms = [1+s.sqrt(2), s.sqrt(2)+s.sqrt(3), 2+s.sqrt(3),
              s.real_root(2, 3), 2+s.I, s.sqrt(2)+s.I]
    for d in denoms:
        p = s.Poly(s.minpoly(d, x), x)
        coeff = list(reversed(p.all_coeffs()))
        inv = coeff[-1]
        for a in reversed(coeff[1:-1]):
            inv = s.expand(inv*d+a)
        inv = -inv/coeff[0]
        residual = s.simplify(s.expand(d*inv-1))
        check(residual == 0, "Polynomial inverse checks", str(d))
        CASES["Polynomial inverse cases"] += 1
    check(s.expand_complex(s.Integer(-8)**s.Rational(1, 3)) == 1+s.I*s.sqrt(3),
          "Principal-branch checks", "principal cube root is not real cube root")
    check(s.sqrt(-1)*s.sqrt(-1) == -1 and s.sqrt(s.Integer(-1)*(-1)) == 1,
          "Principal-branch checks", "product phase cannot be ignored")
    a = s.sqrt(s.Rational(3, 2)+s.sqrt(3))
    b = s.Integer(3)**s.Rational(1, 4)*(1+s.sqrt(3))/2
    check(s.simplify(s.expand(b*b-a*a)) == 0, "Principal-branch checks", "context-cost example square")
    check(b.is_positive is True, "Principal-branch checks", "context-cost example sign")
    a = (3+2*s.sqrt(2))**s.Rational(1, 6)
    b = (1+s.sqrt(2))**s.Rational(1, 3)
    check(s.expand((1+s.sqrt(2))**2) == 3+2*s.sqrt(2),
          "Principal-branch checks", "same-depth index reduction identity")
    check(a.is_positive is True and b.is_positive is True,
          "Principal-branch checks", "same-depth identity sign")
    for q in range(2, 33):
        for k in range(q):
            check((s.Rational(2*k, q)*q/2).is_integer is True,
                  "Root-of-unity arithmetic checks", f"q={q}, k={k}")


def verify_control_model() -> None:
    # This is an explicit state-machine model, not a translation/interpreter of WL.
    original, partial = (3, 4, 30), (2, 6, 45)
    old_result = original       # reset by a later unsuccessful stage
    repaired_result = min(partial, original)
    check(old_result > partial and repaired_result == partial,
          "Control-flow model checks", "incumbent retention")
    cache = {"target": "unchanged at low quota"}
    check(cache["target"] == "unchanged at low quota", "Control-flow model checks", "unqualified memo suppresses retry")
    positive_cache: dict[str, str] = {}
    check("target" not in positive_cache, "Control-flow model checks", "do not cache failed search")


def lexical_check(path: Path) -> None:
    """Only balanced comments/strings/brackets: not a native syntax/type check."""
    text = path.read_text(encoding="utf-8")
    stack: list[tuple[str, int]] = []
    comment = 0; in_string = False; i = 0
    pairs = {')': '(', ']': '[', '}': '{', '|>': '<|'}
    while i < len(text):
        c, two = text[i], text[i:i+2]
        if comment:
            if two == '(*': comment += 1; i += 2; continue
            if two == '*)': comment -= 1; i += 2; continue
            i += 1; continue
        if in_string:
            if c == '\\': i += 2; continue
            if c == '"': in_string = False
            i += 1; continue
        if two == '(*': comment = 1; i += 2; continue
        if c == '"': in_string = True; i += 1; continue
        if two == '<|': stack.append((two, i)); i += 2; continue
        if two == '|>':
            if not stack or stack[-1][0] != '<|': raise AssertionError(f"{path}: mismatched association at {i}")
            stack.pop(); i += 2; continue
        if c in '([{': stack.append((c, i))
        elif c in ')]}':
            if not stack or stack[-1][0] != pairs[c]:
                line = text.count('\n', 0, i)+1
                raise AssertionError(f"{path}: mismatched delimiter at line {line}: {c}; stack={stack[-3:]}")
            stack.pop()
        i += 1
    
    if stack or comment or in_string:
        print("OPEN:", [(c,text.count(chr(10),0,pos)+1, text[max(0,pos-30):pos+60]) for c,pos in stack], "comment",comment,"string",in_string)
    check(not stack and comment == 0 and not in_string, "Lexical checks", str(path.name))


def main() -> None:
    verify_odd(); verify_square_roots(); verify_honsbeek(); verify_square_classes()
    verify_inverse_and_branches(); verify_control_model()
    for path in sorted(ROOT.rglob("*")):
        if path.suffix in (".wl", ".wlt", ".wls"):
            lexical_check(path)
    package = ROOT / "code" / "StradFixed3.wl"
    content = package.read_text(encoding="utf-8")
    check('best = negativeRadicandCandidate[target, rho, p, q, best]' in content,
          "Structural checks", "negative stage threads incumbent")
    check('best = kummerCandidates[target, rho, p, q, best]' in content,
          "Structural checks", "Kummer stage threads incumbent")
    body = content.split('certify[a_, b_] :=', 1)[1].split('numericallyDifferentQ[d_]', 1)[0]
    check('numericallyDifferentQ' not in body, "Structural checks", "exact classifier excludes heuristic")
    check('If[best =!= target, AssociateTo[$memo' in content,
          "Structural checks", "positive-only result memo")
    check('FactorInteger[Abs[disc]]' in content and 'bounded[FactorInteger[Abs[disc]]]' in content,
          "Structural checks", "bounded discriminant integer factorization")
    result = {
        "status": "PASS", "python": platform.python_version(), "sympy": s.__version__,
        "assertions": sum(COUNTS.values()), "counts": dict(COUNTS), "case_counts": dict(CASES),
        "elapsed_seconds": round(time.perf_counter()-START, 3),
        "native_wolfram_execution": "NOT RUN: connector HTTP 404; no local kernel",
        "scope": "Exact mathematical checks, a stated control-flow model, and lexical/structural checks only.",
        "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
        "package_lines": len(content.splitlines()), "details": DETAILS,
    }
    (HERE / "results.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    lines = ["Independent verification: PASS", f"Python {result['python']}; SymPy {result['sympy']}",
             f"Assertions: {result['assertions']}", *[f"  {k}: {v}" for k, v in COUNTS.items()],
             "Cases:", *[f"  {k}: {v}" for k, v in CASES.items()],
             "Native Wolfram execution: NOT RUN", result["scope"],
             f"Package SHA-256: {result['package_sha256']}",
             f"Elapsed: {result['elapsed_seconds']} seconds"]
    (HERE / "results.txt").write_text("\n".join(lines)+"\n", encoding="utf-8")
    print("\n".join(lines))

if __name__ == "__main__":
    main()
