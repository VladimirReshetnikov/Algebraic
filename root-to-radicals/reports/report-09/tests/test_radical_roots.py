"""Regression suite. Run from the distribution root:
    python -m unittest discover -s tests -v
The test runner inserts the sibling source directory; installation is optional.
"""
from __future__ import annotations
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
import sympy as S

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'python'))
from radical_roots import (solve_polynomial, solve_root, build_tower, Limits,
    NotSolvable, ResourceLimit, RadicalError, VerificationError,
    expression_ast, from_ast, verify_certificate, pair_sum_resolvent)
from radical_roots.fast import dickson, dickson_candidates
from radical_roots.core import LinearSpace, same_root_known
x, y = S.symbols('x y')
SEXTIC = x**6 + x**4 - x**3 - x**2 - 1
QUINTIC = 5*x**5 - 25*x**3 + 25*x + 6

class FastPathTests(unittest.TestCase):
    def test_original_quintic(self):
        sol = solve_polynomial(QUINTIC, method='fast')
        self.assertEqual(sol.metadata['method'], 'Dickson')
        self.assertEqual(len(sol.expressions), 5)
        expected = ((-3+4*S.I)/5)**S.Rational(1,5) + ((-3-4*S.I)/5)**S.Rational(1,5)
        self.assertTrue(same_root_known(S.Poly(QUINTIC,x), sol.expression(4), expected))
        for e in sol.expressions:
            self.assertEqual(from_ast(expression_ast(e)), e)
        # An independent symbolic annihilator check on the reported target.
        self.assertEqual(S.Poly(S.minpoly(sol.expression(4),x),x).monic(), S.Poly(QUINTIC,x).monic())

    def test_original_sextic(self):
        sol = solve_polynomial(SEXTIC, method='fast')
        self.assertEqual(sol.metadata['method'], 'PairSum')
        u = (S.Rational(1,2)+S.sqrt(849)/18)**S.Rational(1,3)
        s = u-4/(3*u)
        expected = (s+S.sqrt(s*s+4))/2
        self.assertTrue(same_root_known(S.Poly(SEXTIC,x), sol.expression(1), expected))
        self.assertEqual(S.Poly(S.minpoly(sol.expression(1),x),x).monic(), S.Poly(SEXTIC,x).monic())
        for e in sol.expressions: expression_ast(e)

    def test_sextic_identity(self):
        # F(X)=X^3 g(X-1/X) proves every quadratic lift algebraically.
        g = y**3+4*y-1
        self.assertEqual(S.cancel(x**3*g.subs(y,x-1/x)-SEXTIC), 0)
        R = pair_sum_resolvent(S.Poly(SEXTIC,x))
        q = S.Poly(x**3+4*x-1,x)
        self.assertTrue(R.rem(q).is_zero)
        self.assertEqual(R.degree(), 15)

    def test_pair_sum_collision(self):
        f = S.Poly((x*x-1)*(x*x-4),x)
        R = pair_sum_resolvent(f)
        self.assertEqual(R, S.Poly(x*x*(x*x-1)*(x*x-9),x,domain=S.QQ))

    def test_degree_seven(self):
        sol=solve_polynomial(x**7-2,method='fast')
        self.assertEqual(sol.metadata['method'],'Dickson')
        self.assertEqual(len(sol.expressions),7)
        for e in sol.expressions:
            self.assertEqual(S.expand_power_base(e**7,force=False),2)

    def test_degree_ten(self):
        f=S.Poly(S.resultant(y**5-2,(x-y)**2-3,y),x)
        self.assertEqual(f.degree(),10)
        sol=solve_polynomial(f,method='fast')
        self.assertEqual(sol.metadata['method'],'PairSum')
        self.assertEqual(len(sol.expressions),10)
        self.assertTrue(same_root_known(f,sol.expression(1),2**S.Rational(1,5)+S.sqrt(3)))

    def test_shifted_scaled_dickson(self):
        f=S.Poly(7*(dickson(7,x+S.Rational(2,3),S.Rational(2,5))+11),x)
        candidates,info=dickson_candidates(f)
        self.assertEqual(info['shift'],'2/3')
        self.assertEqual(info['a'],'2/5')
        self.assertEqual(len(candidates),7)
        u,a=S.symbols('u a')
        self.assertEqual(S.cancel(dickson(7,u+a/u,a)-u**7-(a/u)**7),0)

    def test_reducible_selected_factor(self):
        f=(x-2)*(x**5-x-1)
        sol=solve_root(f,1,method='galois') # real roots: quintic's root, then 2
        self.assertEqual(sol.expression(),2)
        # Irrational selected factor, while another factor is nonsolvable.
        sol=solve_root((x*x-2)*(x**5-x-1),0,method='fast')
        self.assertEqual(sol.expression(),-S.sqrt(2))

    def test_repeated_and_rational(self):
        self.assertEqual(solve_root((x-3)**3,2).expression(),3)
        sol=solve_polynomial((x-1)**2*(x+2))
        self.assertEqual(sol.expressions,[-2,1])
        self.assertTrue(build_tower(x-S.Rational(3,7)).verify())

    def test_search_exhaustion_is_not_nonsolvability(self):
        with self.assertRaises(RadicalError) as ctx:
            solve_polynomial(x**5-x-1,method='fast',pair_sum_max_degree=0)
        self.assertNotIsInstance(ctx.exception,NotSolvable)

class GeneralConstructorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.quadratic=build_tower(x*x-2)
        cls.biquadratic=build_tower(x**4-10*x*x+1)

    def test_quadratic(self):
        self.assertTrue(self.quadratic.verify())
        self.assertEqual(self.quadratic.expressions(),[-S.sqrt(2),S.sqrt(2)])

    def test_two_step_tower(self):
        t=self.biquadratic
        self.assertTrue(t.verify())
        self.assertEqual(t.metadata['chain_orders'],[4,2,1])
        self.assertEqual(t.expressions(),[-S.sqrt(3)-S.sqrt(2),-S.sqrt(3)+S.sqrt(2),
                                         S.sqrt(3)-S.sqrt(2),S.sqrt(3)+S.sqrt(2)])

    def test_pure_cubic(self):
        t=build_tower(x**3-2)
        self.assertTrue(t.verify())
        self.assertEqual(t.metadata['splitting_degree'],6)
        self.assertEqual(t.metadata['chain_orders'],[3,1])

    def test_cyclic_cubic(self):
        t=build_tower(x**3-3*x+1)
        self.assertTrue(t.verify())
        self.assertEqual(t.metadata['splitting_degree'],3)
        self.assertEqual(t.metadata['field_degree'],6)
        for e in t.expressions():expression_ast(e)

    def test_nonabelian_relative_group(self):
        # Forces the general engine, not the cubic formula shortcut.
        t=build_tower(x**3-x-1)
        self.assertTrue(t.verify())
        self.assertEqual(t.metadata['chain_orders'],[6,3,1])
        self.assertEqual(t.metadata['field_degree'],12)
        for e in t.expressions():expression_ast(e)

    def test_general_quintic(self):
        t=build_tower(x**5-2)
        self.assertTrue(t.verify())
        self.assertEqual(t.metadata['splitting_degree'],20)
        self.assertEqual(t.metadata['field_degree'],20)
        self.assertEqual(t.metadata['chain_orders'],[5,1])
        for e in t.expressions():expression_ast(e)

    def test_automorphism_factorization_fallback(self):
        from unittest.mock import patch
        with patch('radical_roots.core.anchor_conjugate_candidates',return_value=[]):
            t=build_tower(x**4-10*x*x+1)
        self.assertEqual(t.metadata['automorphism_enumeration'],'primitive polynomial factorization')
        self.assertTrue(t.verify())

    def test_tower_object_bound_to_certificate(self):
        t=copy.deepcopy(self.biquadratic)
        t.steps[0]['branch']^=1
        with self.assertRaises(VerificationError):t.verify()

    def test_certificate_bound_to_expected_polynomial(self):
        with self.assertRaises(VerificationError):
            verify_certificate(self.quadratic.certificate,expected_polynomial=x*x-3)

    def test_nonsolvable(self):
        with self.assertRaises(NotSolvable) as ctx:
            build_tower(x**5-x-1)
        self.assertEqual(ctx.exception.evidence['order'],120)
        self.assertEqual(ctx.exception.evidence['derived_orders'],[120,60])

    def test_resource_status(self):
        with self.assertRaises(ResourceLimit):
            build_tower(x*x-2,limits=Limits(max_field_degree=1))

    def test_tampered_branch(self):
        c=copy.deepcopy(self.biquadratic.certificate)
        c['steps'][0]['branch']^=1
        with self.assertRaises(VerificationError):verify_certificate(c)

    def test_tampered_radicand(self):
        c=copy.deepcopy(self.biquadratic.certificate)
        c['steps'][0]['radicand']=['Q','7','1']
        with self.assertRaises(VerificationError):verify_certificate(c)

    def test_tampered_target(self):
        c=copy.deepcopy(self.biquadratic.certificate)
        c['target_values'][0]=['0']*4
        with self.assertRaises(VerificationError):verify_certificate(c)

    def test_tampered_anchor(self):
        c=copy.deepcopy(self.biquadratic.certificate)
        c['primitive_anchor']=['Q','1','1']
        with self.assertRaises(VerificationError):verify_certificate(c)

    def test_empty_certificate_rejected(self):
        with self.assertRaises(VerificationError):verify_certificate({})

class InterfaceTests(unittest.TestCase):
    def cli(self,request):
        p=subprocess.run([sys.executable,str(ROOT/'python/radical_roots/cli.py')],
            input=json.dumps(request),text=True,capture_output=True,timeout=30)
        return json.loads(p.stdout)

    def test_cli_success(self):
        r=self.cli({'coefficients':['6','25','0','-25','0','5'],'seconds':20,'method':'fast'})
        self.assertEqual(r['status'],'Success')
        self.assertEqual(len(r['expressions']),5)
        for ast in r['expressions']:expression_ast(from_ast(ast))

    def test_cli_nonsolvable(self):
        r=self.cli({'coefficients':['-1','-1','0','0','0','1'],'method':'galois','seconds':20})
        self.assertEqual(r['status'],'NotSolvable')

    def test_cli_hard_timeout(self):
        r=self.cli({'coefficients':['-1','-1','0','1'],'method':'galois','seconds':0.01})
        self.assertEqual(r['status'],'ResourceLimit')
        self.assertIn('terminated',r['message'])

    def test_cli_input_rejected(self):
        r=self.cli({'coefficients':['__import__("os").system("echo bad")','1'],'seconds':20})
        self.assertEqual(r['status'],'InvalidInput')

    def test_ast_rejects_unrecognized_operations(self):
        for ast in [['Root',['-2','0','1'],0],['S','unbound'],['exec','bad'],['Q','bad','1'],['Q','1','0'],['Q',1.5,'1']]:
            with self.assertRaises(ValueError):from_ast(ast)
        with self.assertRaises(ValueError):expression_ast(S.cos(S.pi/7))

    def test_linear_space(self):
        b=LinearSpace(3)
        self.assertTrue(b.add([S.Integer(0),S.Integer(2),S.Integer(1)]))
        self.assertTrue(b.add([S.Integer(1),S.Integer(1),S.Integer(0)]))
        self.assertEqual(b.coordinates([S.Integer(3),S.Integer(7),S.Integer(2)]),[2,3])
        self.assertIsNone(b.coordinates([S.Integer(0),S.Integer(0),S.Integer(1)]))
        self.assertFalse(b.add([S.Integer(0),S.Integer(4),S.Integer(2)]))

if __name__=='__main__':unittest.main(verbosity=2)
