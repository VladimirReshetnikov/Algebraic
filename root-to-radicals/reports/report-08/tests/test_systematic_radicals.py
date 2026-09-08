"""Executable regression tests. Run from the package root with unittest discover.
Only the explicit slow tower tests bypass the fast paths. No numerical tolerance
is used to accept a selected root: Poly.same_root supplies its bounded-error test.
"""
from __future__ import annotations
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
import json
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
import sympy as s
import systematic_radicals as r
x = s.symbols("x")
SEXTIC = x**6+x**4-x**3-x**2-1
QUINTIC = 5*x**5-25*x**3+25*x+6

@lru_cache(None)
def tower(f):
    result = r.solve_polynomial(f, x, method="galois", max_seconds=180, verify=True)
    dest = ROOT / "validation" / "certificates"
    dest.mkdir(parents=True, exist_ok=True)
    name = str(f).replace(" ", "").replace("**", "^").replace("*", "_")
    (dest / (name+".json")).write_text(json.dumps(result.certificate, indent=2))
    return result

class RadicalTests(unittest.TestCase):
    def assertRootSet(self, f, roots):
        p = s.Poly(f, x)
        self.assertEqual(len(roots), p.degree())
        self.assertTrue(all(r.radical_expression_q(e) for e in roots))
        targets = list(p.all_roots(radicals=False))
        # The construction/identity supplies same_root's root precondition.
        matching = [next((i for i, t in enumerate(targets) if p.same_root(a, t)), None)
                    for a in roots]
        self.assertNotIn(None, matching)
        self.assertEqual(len(set(matching)), p.degree())

    def test_01_rational(self):
        self.assertEqual(r.solve_polynomial(7*x-3,x).outputs, [s.Rational(3,7)])
    def test_02_inexact_rejected(self):
        with self.assertRaises(r.InvalidInput): r.solve_polynomial(x*x-2.0,x)
    def test_03_algebraic_coefficient_rejected(self):
        with self.assertRaises(r.InvalidInput): r.solve_polynomial(x*x-s.sqrt(2),x)
    def test_04_reducible_rejected(self):
        with self.assertRaises(r.InvalidInput): r.solve_polynomial((x*x-2)*(x*x-3),x)
    def test_05_constant_rejected(self):
        with self.assertRaises(r.InvalidInput): r.solve_polynomial(s.Integer(3),x)
    def test_06_invalid_limits(self):
        for kwargs in [{"max_field_degree":0},{"max_field_degree":True},
                       {"max_seconds":0},{"max_seconds":float("nan")}]:
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(r.InvalidInput): r.solve_polynomial(x*x-2,x,**kwargs)
    def test_07_invalid_method(self):
        with self.assertRaises(r.InvalidInput): r.solve_polynomial(x*x-2,x,method="magic")
    def test_08_strict_grammar(self):
        for a in [x,s.pi,s.cos(s.Rational(1,7)),s.Float(1),s.CRootOf(x**5-x-1,0)]:
            self.assertFalse(r.radical_expression_q(a))
        self.assertTrue(r.radical_expression_q((1+s.I)**s.Rational(1,5)-s.sqrt(2)))
    def test_09_sextic_reduction_identity(self):
        self.assertEqual(s.cancel(x**3*((x-1/x)**3+4*(x-1/x)-1)-SEXTIC),0)
    def test_10_sextic_all_roots(self):
        sol=r.solve_polynomial(SEXTIC,x,method="fast")
        self.assertTrue(sol.method.startswith("Reciprocal/"))
        self.assertRootSet(SEXTIC,sol.expanded_roots())
    def test_11_sextic_positive_formula(self):
        t=((9+s.sqrt(849))/18)**s.Rational(1,3)-((s.sqrt(849)-9)/18)**s.Rational(1,3)
        a=(t+s.sqrt(t*t+4))/2
        self.assertTrue(s.Poly(SEXTIC,x).same_root(a,s.CRootOf(SEXTIC,1)))
    def test_12_quintic_all_roots(self):
        sol=r.solve_polynomial(QUINTIC,x,method="fast")
        self.assertEqual(sol.method,"Dickson")
        self.assertRootSet(QUINTIC,sol.expanded_roots())
    def test_13_quintic_selected_root(self):
        a=r.solve_root(QUINTIC,4,x,method="fast")
        self.assertTrue(s.Poly(QUINTIC,x).same_root(a,s.CRootOf(QUINTIC,4)))
    def test_14_shifted_binomial(self):
        f=(x-3)**7-2
        sol=r.solve_polynomial(f,x,method="fast")
        self.assertTrue(sol.method.startswith("PowerComposition/"))
        self.assertRootSet(f,sol.expanded_roots())
    def test_15_power_composition(self):
        sol=r.solve_polynomial(x**10-2,x,method="fast")
        self.assertEqual(len(sol.outputs),10)
        self.assertTrue(all(s.simplify(a**10-2)==0 for a in sol.outputs))
    def test_16_translated_dickson(self):
        f=s.expand(r.dickson(5,x-4,2)+3)
        sol=r.solve_polynomial(f,x,method="fast")
        self.assertEqual(sol.method,"Dickson")
        self.assertRootSet(f,sol.outputs)
    def test_17_weighted_reciprocal(self):
        f=x**6+8*x**4+x**3+16*x*x+8
        sol=r.solve_polynomial(f,x,method="fast")
        self.assertTrue(sol.method.startswith("Reciprocal/"))
        self.assertRootSet(f,sol.outputs)
    def test_18_fast_miss_is_not_nonsolvability(self):
        with self.assertRaises(r.NotFound): r.solve_polynomial(x**5-x-1,x,method="fast")
    def test_19_nonsolvable(self):
        with self.assertRaises(r.NotSolvable) as cm: r.solve_polynomial(x**5-x-1,x)
        self.assertEqual(cm.exception.details["group_order"],120)
    def test_20_reducible_input_easy_factor(self):
        f=(x-10)*(x**5-x-1)
        self.assertEqual(r.solve_root(f,1,x),10)
    def test_21_reducible_input_hard_factor(self):
        with self.assertRaises(r.NotSolvable): r.solve_root((x-10)*(x**5-x-1),0,x)
    def test_22_index_validation(self):
        for i in [-1,2,True]:
            with self.assertRaises(r.InvalidInput): r.solve_root(x*x-2,i,x)
    def test_23_field_degree_budget(self):
        with self.assertRaises(r.ResourceLimit):
            r.solve_polynomial(x**3-2,x,method="galois",max_field_degree=3)
    def test_24_tower_quadratic(self):
        z=tower(x*x-2)
        self.assertEqual(z.diagnostics["prime_steps"],[2])
        self.assertRootSet(x*x-2,z.expanded_roots())
    def test_25_tower_pure_cubic(self):
        z=tower(x**3-2)
        self.assertEqual(z.diagnostics["prime_steps"],[3])
        self.assertRootSet(x**3-2,z.expanded_roots())
    def test_26_tower_cyclic_cubic(self):
        z=tower(x**3-3*x+1)
        self.assertEqual(z.diagnostics["working_field_degree"],6)
        self.assertRootSet(x**3-3*x+1,z.expanded_roots())
    def test_27_tower_biquadratic(self):
        z=tower(x**4-10*x*x+1)
        self.assertEqual(z.diagnostics["composition_orders"],[4,2,1])
        self.assertRootSet(x**4-10*x*x+1,z.expanded_roots())
    def test_28_tower_nonabelian_quartic(self):
        z=tower(x**4-2)
        self.assertEqual(z.diagnostics["stabilizer_order"],8)
        self.assertRootSet(x**4-2,z.expanded_roots())
    def test_29_tower_nonabelian_cubic(self):
        z=tower(x**3-x-1)
        self.assertEqual(z.diagnostics["composition_orders"],[6,3,1])
        self.assertTrue(r.verify_certificate(z.certificate,x**3-x-1))
        # Avoid expanding this deliberately unoptimized tower in routine tests.
    def test_30_tampered_power_rejected(self):
        c=deepcopy(tower(x**3-2).certificate)
        c["radicands"][0]=["Q","0","1"]
        with self.assertRaises(r.CertificateError): r.verify_certificate(c)
    def test_31_wrong_polynomial_rejected(self):
        with self.assertRaises(r.CertificateError):
            r.verify_certificate(tower(x*x-2).certificate,x*x-3)
    def test_32_duplicate_roots_rejected(self):
        c=deepcopy(tower(x*x-2).certificate)
        c["root_witnesses"][0]=c["root_witnesses"][1]
        with self.assertRaises(r.CertificateError): r.verify_certificate(c)
    def test_33_json_protocol(self):
        data=r._request({"coefficients":[["1","1"],["0","1"],["-2","1"]]})
        self.assertEqual(data["status"],"Success")
        self.assertEqual(len(data["roots"]),2)
        self.assertNotIn("RootOf",json.dumps(data))
    def cli(self, data):
        p=subprocess.run([sys.executable,str(ROOT/"python"/"systematic_radicals.py"),"--json"],
            input=json.dumps(data),text=True,capture_output=True,timeout=30)
        return p,json.loads(p.stdout)
    def test_34_cli_success(self):
        p,d=self.cli({"coefficients":[["1","1"],["0","1"],["-2","1"]],"max_seconds":10})
        self.assertEqual(p.returncode,0);self.assertEqual(d["status"],"Success")
    def test_35_cli_hard_timeout(self):
        p,d=self.cli({"coefficients":[["1","1"],["0","1"],["-2","1"]],"max_seconds":0.001})
        self.assertEqual(d["status"],"ResourceLimit")
    def test_36_cli_invalid_input(self):
        p,d=self.cli({"coefficients":[["1","0"],["0","1"]]})
        self.assertEqual(d["status"],"InvalidInput")

if __name__=="__main__": unittest.main(verbosity=2)
