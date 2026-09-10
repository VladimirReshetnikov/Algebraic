"""Check the Python results of all three operations in a native Wolfram kernel.

This merges the three cross-language checks the separate projects carried, and
with them one kernel harness instead of three that had drifted apart (one
searched `PATH` only, one also fell back to a hard-coded Wolfram 15 path, one
captured output and one did not).

Three groups, run together by default:

  polynomial     complete chains, all normalized chains, all pairs and the
                 fixed-degree certificates of `algebraic.polynomial_decomposition`.
                 This group loads `algebraic/Algebraic.wl` and compares
                 Python's answers with the package's own, and feeds Python's
                 certificates to the package's independent certificate
                 checker.  The Wolfram side recomposes the chains itself with
                 polynomial substitution and exact `RootReduce`; no
                 `Decompose` and no floating point is used.
  decomposition  sums and products from `algebraic.root_decomposition`, checked
                 with `RootReduce` and `MinimalPolynomial` alone.  No package
                 is loaded, so the check is independent of the Wolfram
                 implementation of the same algorithm.
  radicals       radical expressions from `algebraic.radicals`, checked
                 exactly as roots of the minimal polynomial and identified
                 numerically at 60 digits against the value Python computed.
                 Root indices are not exchanged: the two systems number
                 non-real roots differently.  No package is loaded.

Usage:

    python verify_wolfram.py                     # all three groups
    python verify_wolfram.py --group radicals
    python verify_wolfram.py --emit check.wl     # write, do not run

A failed check exits nonzero.  A native kernel is required to run; `--emit`
needs none.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import sympy as sp
from sympy.printing.mathematica import mathematica_code
from flint import ctx, fmpz_poly

from algebraic import polynomial_decomposition as ad
from algebraic import radicals as rt
from algebraic import root_decomposition as rd

PACKAGE = Path(__file__).resolve().parents[1] / "Algebraic.wl"
DEFAULT_WOLFRAM = r"C:\Program Files\Wolfram Research\Wolfram\15.0\wolfram.exe"

X = sp.Symbol("x")
ALPHA = sp.CRootOf(X**5 - X - 1, 0)          # the unique real root in both systems
FIELD_SYMBOL = sp.Symbol("crossCheckAlpha")


# --------------------------------------------------------------------------
# group 1: functional decomposition of polynomials
# --------------------------------------------------------------------------

KEYS = {
    "type": "Type", "right_degree": "RightDegree", "outer_degree": "OuterDegree",
    "inner": "Inner", "outer_candidate": "OuterCandidate", "digits": "Digits",
    "decomposable": "Decomposable", "obstruction": "Obstruction", "residual": "Residual",
    "digit_index": "DigitIndex", "power": "Power", "coefficient": "Coefficient",
    "input_degree": "InputDegree", "tested_right_degrees": "TestedRightDegrees",
    "accepted_right_degrees": "AcceptedRightDegrees", "indecomposable": "Indecomposable",
    "tests": "Tests",
}


def wolfram(value):
    """Serialize exact test data, including the shared real quintic root."""
    if value is None:
        return "None"
    if value is True:
        return "True"
    if value is False:
        return "False"
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "{" + ",".join(map(wolfram, value)) + "}"
    if isinstance(value, dict):
        entries = []
        for key, item in value.items():
            serialized = ('Missing["NotApplicable","DegreeBelowTwo"]'
                          if key == "indecomposable" and item is None else wolfram(item))
            entries.append(json.dumps(KEYS.get(key, key)) + "->" + serialized)
        return "<|" + ",".join(entries) + "|>"
    return mathematica_code(sp.sympify(value).xreplace({ALPHA: FIELD_SYMBOL}))


def polynomial_corpus():
    x, s = X, sp.sqrt(2)
    p = (3 + 3*s + (14 + 4*s)*x + (12 + 26*s)*x**2 + (56 + 8*s)*x**3
         + (8 + 48*s)*x**4 + 48*x**5 + 16*s*x**6)
    h = x**2 + x
    yield "question sextic", p
    yield "nested degree 24", sp.expand(p.subs(x, x**4 - x + 1))
    yield "sparse inner regression", (x**4 + x)**2
    yield "negative h-adic digits", h**3 + x*h
    yield "power collisions", x**12
    yield "Chebyshev collisions", sp.chebyshevt(12, x)
    yield "generic indecomposable", x**12 + x
    yield "prime degree", x**7 + s*x + 1
    yield "complex coefficients", (x**2 + (s + sp.I)*x)**3 + sp.I*(x**2 + (s + sp.I)*x) + 1
    h = x**3 + (s + sp.sqrt(3))*x
    yield "multiple quadratic generators", h**4 + sp.sqrt(3)*h + 1
    h = x**2 + ALPHA*x
    yield "irreducible quintic coefficient", h**3 + ALPHA*h + 1
    yield "leading coefficient cancellation", (ALPHA**5 - ALPHA - 1)*x**6 + (x**2 + x)**2
    yield "zero", sp.S.Zero
    yield "constant", sp.sqrt(3)
    yield "linear", s*x + sp.I


def script_polynomial():
    rows = []
    for label, polynomial in polynomial_corpus():
        chain = ad.decompose(polynomial, X)
        chains = ad.decompositions(polynomial, X)
        pairs = ad.decomposition_pairs(polynomial, X)
        certificate = ad.decomposition_data(polynomial, X)
        assert ad.verify_decomposition(polynomial, chain, X,
                                       require_complete=True, require_normalized=True), label
        assert ad.verify_decomposition_data(polynomial, certificate, X), label
        rows.append(wolfram({"Label": label, "Input": polynomial, "Chain": chain,
                             "AllChains": chains, "Pairs": pairs, "Certificate": certificate}))
        print(f"  prepared {label}: {len(chains)} complete chain(s), {len(pairs)} pair(s)", flush=True)
    return ("(* Generated by algebraic/python/verify_wolfram.py, group polynomial. *)\n"
            "Get[" + json.dumps(PACKAGE.as_posix()) + "];\n"
            "crossCheckAlpha = Root[#^5-#-1&,1];\nrows = {\n"
            + ",\n".join(rows) + "\n};\n" + r'''
canonical[p_] := Module[{c = RootReduce /@ CoefficientList[Expand[p],x]},
  If[c === {}, c = {0}];
  While[Length[c]>1 && Last[c]===0, c=Most[c]];
  c];
same[a_,b_] := canonical[a-b] === {0};
chainCompose[parts_List] := Fold[Expand[#1 /. x -> #2]&,x,parts];
chainKey[parts_List] := canonical /@ parts;
setKey[chains_List] := Sort[chainKey /@ chains];
failures = 0;
Do[
  checks = Quiet[Check[Module[{p=row["Input"], chain=row["Chain"], chains=row["AllChains"],
      pairs=row["Pairs"], certificate=row["Certificate"], native},
    native = AlgebraicDecompositions[p,x];
    <|"independent recomposition" -> (same[p,chainCompose[chain]] &&
          AllTrue[chains, same[p,chainCompose[#]]&] &&
          AllTrue[pairs, same[p,chainCompose[#]]&]),
      "complete normalized Python chain" -> VerifyAlgebraicDecomposition[p,chain,x,
          "RequireComplete"->True,"RequireNormalized"->True],
      "one-chain parity" -> (chainKey[chain] === chainKey[AlgebraicDecompose[p,x]]),
      "all-chain parity" -> (ListQ[native] && setKey[chains] === setKey[native]),
      "pair parity" -> (setKey[pairs] === setKey[AlgebraicDecompositionPairs[p,x]]),
      "independent Python-certificate check" -> VerifyAlgebraicDecompositionData[p,certificate,x]
    |>], <|"evaluation"->False|>]];
  failed = Keys[Select[checks, !TrueQ[#]&]];
  Print[If[failed === {}, "PASS ", "FAIL "], row["Label"],
        If[failed === {}, "", ": "<>ToString[failed,InputForm]]];
  If[failed =!= {}, failures++],
  {row,rows}];
Print["polynomial: ",Length[rows]," cases, ",failures," failed."];
groupFailures = groupFailures + failures;
''')


# --------------------------------------------------------------------------
# group 2: sums and products of algebraic numbers
# --------------------------------------------------------------------------

def decomposition_cases():
    """Representative identities, including restricted and complex outputs."""
    examples = [
        ("product example", "Root[-1-#+3#^3-#^4+#^5-3#^6+2#^7+#^9&,1]",
         rd.product_decomposition, {}, 3, None),
        ("sum example", "Root[8-4#+24#^2-15#^3+3#^5+6#^6+#^9&,1]",
         rd.sum_decomposition, {}, 3, None),
        ("sextic sum outside the input field", "Root[-1-#+3#^3-#^4+#^5-3#^6+2#^7+#^9&,1]",
         rd.sum_decomposition, {"engine": "splitting"}, 6, None),
        ("input-field additive optimum", "Root[-1-#+3#^3-#^4+#^5-3#^6+2#^7+#^9&,1]",
         rd.sum_decomposition, {"scope": "InputField"}, 9, None),
        ("affine sum with two terms", "Root[-8+16#-4#^2-4#^3+#^4&,4]",
         rd.sum_decomposition, {"max_terms": 2}, 2, 2),
        ("three quadratic tensor factors",
         "Root[4096+4096#-16384#^2+6144#^3+3008#^4-768#^5-256#^6-8#^7+#^8&,8]",
         rd.product_decomposition, {"dmax": 2, "max_factors": 3, "depth": 0}, 2, 3),
        ("external quartic factors", "Root[4-8#^2-16#^4-4#^6+#^8&,4]",
         rd.product_decomposition, {"max_factors": 2, "engine": "splitting"}, 4, 2),
        ("quartic summands of a sextic", "Root[-1+4#^2+#^6&,3]",
         rd.sum_decomposition, {"engine": "splitting"}, 4, None),
    ]
    for label, syntax, fn, options, degree, count in examples:
        target = rd.parse_wolfram_root(syntax)
        result = fn(target, **options)
        if result is None or result.max_degree != degree:
            raise AssertionError(f"{label}: expected maximum degree {degree}, got {result}")
        if count is not None and len(result.terms) > count:
            raise AssertionError(f"{label}: exceeded {count} components")
        print(f"  prepared {label}: degrees {result.degrees}", flush=True)
        yield label, target, result

    # Each branch of sqrt(3) +/- i sqrt(2), with both real-part signs: this
    # exercises the interchange ordering beyond the real article examples.
    for index in range(1, 5):
        target = rd.AlgebraicNumber(fmpz_poly([25, 0, -2, 0, 1]), index)
        result = rd.sum_decomposition(target, max_terms=2)
        if result is None or result.max_degree != 2 or len(result.terms) > 2:
            raise AssertionError(f"complex branch {index}: {result}")
        print(f"  prepared complex branch {index}: degrees {result.degrees}", flush=True)
        yield f"complex branch {index}", target, result


def script_decomposition():
    rows = []
    for label, target, result in decomposition_cases():
        terms = "{" + ",".join(t.wolfram() for t in result.terms) + "}"
        degrees = "{" + ",".join(map(str, result.degrees)) + "}"
        rows.append("{" + ",".join([json.dumps(label), target.wolfram(), terms,
                                    result.op, degrees]) + "}")
    return ("(* Generated by algebraic/python/verify_wolfram.py, group decomposition."
            "  No package is loaded. *)\nrows = {\n" + ",\n".join(rows) + "\n};\n" + r'''
failures = 0;
Do[
  ok = Quiet[Check[
    RootReduce[row[[2]] - Apply[row[[4]], row[[3]]]] === 0 &&
      (Exponent[MinimalPolynomial[#, x], x] & /@ row[[3]]) === row[[5]],
    False]];
  Print[If[TrueQ[ok], "PASS ", "FAIL "], row[[1]]];
  If[! TrueQ[ok], failures++],
  {row, rows}];
Print["decomposition: ", Length[rows], " cases, ", failures, " failed."];
groupFailures = groupFailures + failures;
''')


# --------------------------------------------------------------------------
# group 3: radical expressions
# --------------------------------------------------------------------------

RADICAL_CASES = [
    ("sextic example", "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]", {}),
    ("sextic example, conjugate 4", "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 4]", {}),
    ("sextic example by descent", "Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]", {"method": "galois"}),
    ("quintic example", "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]", {}),
    ("quintic example, conjugate 2", "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 2]", {}),
    ("quintic example by descent", "Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]", {"method": "galois"}),
    ("cyclic quintic", "Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 1]", {}),
    ("cyclic quintic, eigenvector form", "Root[1 + 3 # - 3 #^2 - 4 #^3 + #^4 + #^5 &, 2]",
     {"resolvents": "eigenvector"}),
    ("x^3-3x+1 by descent", "Root[1 - 3 # + #^3 &, 1]", {"method": "galois"}),
    ("x^4-x-1 by descent", "Root[-1 - # + #^4 &, 1]", {"method": "galois"}),
    ("Phi_7 by descent", "Root[1 + # + #^2 + #^3 + #^4 + #^5 + #^6 &, 3]", {"method": "galois"}),
    ("decomposition (non-real root)", "Root[1 + 3 #^2 - 3 #^4 - 4 #^6 + #^8 + #^10 &, 5]", {}),
    ("Dickson D_7", "Root[-3 - 7 # + 14 #^3 - 7 #^5 + #^7 &, 1]", {}),
]


def _wolfram_value(z):
    """The midpoint of the ball z as an exact rational Wolfram expression.

    Decimal strings with exponents such as 1e-759 are not valid Wolfram input.
    """
    re = z.real.mid().fmpq()
    im = z.imag.mid().fmpq()
    return f"(({re.p})/({re.q}) + (({im.p})/({im.q})) I)"


def script_radicals():
    rows = []
    for label, syntax, options in RADICAL_CASES:
        a = rd.parse_wolfram_root(syntax)
        result = rt.root_to_radicals(a, **options)
        print(f"  prepared {label}: method {result.method}, {result.leaf_count} leaves", flush=True)
        with ctx.workprec(400):
            value = _wolfram_value(a.value(400))
        poly = rd.wolfram_poly(a.poly).replace("#", "x")
        rows.append("{" + ", ".join([json.dumps(label), poly,
                                     "ToExpression[" + json.dumps(result.wolfram()) + "]",
                                     value]) + "}")
    return ("(* Generated by algebraic/python/verify_wolfram.py, group radicals."
            "  No package is loaded. *)\nrows = {\n" + ",\n".join(rows) + "\n};\n" + r'''
failures = 0;
Do[
  {label, poly, expr, value} = row;
  exact = Quiet[Check[RootReduce[poly /. x -> expr] === 0, False]];
  roots = Table[N[Root[Function @@ {poly /. x -> #}, k], 60], {k, Exponent[poly, x]}];
  near = Abs[N[expr, 60] - value] < 10^-30 && Count[roots, _?(Abs[# - value] < 10^-30 &)] == 1;
  ok = exact && near;
  Print[If[ok, "PASS ", "FAIL "], label, If[! exact, " (not a root)", ""],
        If[! near, " (wrong conjugate)", ""]];
  If[! ok, failures++],
  {row, rows}];
Print["radicals: ", Length[rows], " cases, ", failures, " failed."];
groupFailures = groupFailures + failures;
''')


GROUPS = {
    "polynomial": script_polynomial,
    "decomposition": script_decomposition,
    "radicals": script_radicals,
}


# --------------------------------------------------------------------------
# the shared kernel harness
# --------------------------------------------------------------------------

def find_kernel(explicit=None):
    """A native Wolfram kernel, not WolframScript."""
    for candidate in (explicit, shutil.which("wolfram"), shutil.which("math"), DEFAULT_WOLFRAM):
        if candidate and os.path.exists(candidate):
            return candidate
        if candidate and shutil.which(candidate):
            return shutil.which(candidate)
    return None


def build(groups):
    parts = ["groupFailures = 0;\n"]
    for name in groups:
        print(f"preparing group {name}", flush=True)
        parts.append(GROUPS[name]())
    parts.append('Print["total failures: ", groupFailures];\n'
                 "Exit[If[groupFailures === 0, 0, 1]];\n")
    return "\n".join(parts)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--group", action="append", choices=sorted(GROUPS) + ["all"],
                        help="check one group (repeatable); the default is all")
    parser.add_argument("--emit", type=Path,
                        help="write the standalone Wolfram script without running it")
    parser.add_argument("--wolfram", help="native kernel executable (not WolframScript)")
    parser.add_argument("--timeout", type=float, default=1800, help="kernel timeout in seconds")
    args = parser.parse_args(argv)

    groups = args.group or ["all"]
    if "all" in groups:
        groups = ["polynomial", "decomposition", "radicals"]
    seen = []
    for name in groups:
        if name not in seen:
            seen.append(name)

    kernel = find_kernel(args.wolfram)
    if not args.emit and not kernel:
        parser.error("No native Wolfram kernel found; supply --wolfram or use --emit")

    script = build(seen)
    if args.emit:
        args.emit.write_text(script, encoding="utf-8")
        print(f"wrote {args.emit.resolve()}")
        return 0
    with tempfile.TemporaryDirectory(prefix="algebraic-cross-") as directory:
        path = Path(directory) / "verify.wl"
        path.write_text(script, encoding="utf-8")
        return subprocess.run([kernel, "-noprompt", "-script", str(path)],
                              timeout=args.timeout, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
