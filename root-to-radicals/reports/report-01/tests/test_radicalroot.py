"""Regression and adversarial tests. Run: python -m unittest discover -s tests -v"""
from pathlib import Path
import copy,json,subprocess,sys,tempfile,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from api import all_radicals,root_radicals,verify,selected_expression,expressions
from radical_solver import construct_irreducible
from exact_fields import ExactField
from certified_embedding import Embedding
import radical_ast as A
from structural import reciprocal_reduction,dickson
ROOT=Path(__file__).resolve().parents[1]
x=s.Symbol('x')


class RadicalTests(unittest.TestCase):
    def test_01_original_sextic(self):
        f=x**6+x**4-x**3-x**2-1;r=root_radicals(f,1)
        self.assertEqual(r['status'],'Success');self.assertTrue(verify(r))
        self.assertEqual(len(r['roots']),6)
        h,c=reciprocal_reduction(s.Poly(f,x,domain=s.QQ))
        self.assertEqual(c,-1);self.assertEqual(h.all_coeffs(),[1,0,4,-1])
        self.assertEqual(s.Poly(s.minpoly(selected_expression(r),x),x).monic(),s.Poly(f,x,domain=s.QQ))

    def test_02_original_quintic(self):
        r=root_radicals(5*x**5-25*x**3+25*x+6,4)
        self.assertEqual(r['certificate']['construction']['kind'],'ShiftedDickson')
        self.assertTrue(verify(r));self.assertEqual(len(r['roots']),5)

    def test_03_general_quadratics_and_boundary(self):
        for f in [x*x-2,x*x+1,x*x+3]:
            with self.subTest(f=f):
                r=all_radicals(f,method='general');self.assertTrue(verify(r))
                for tree in r['roots']:self.assertTrue(A.validate(tree['expression'],['zeta','r1']))

    def test_04_general_cubics(self):
        for f in [x**3-2,x**3-x-1,x**3-3*x+1]:
            with self.subTest(f=f):self.assertTrue(verify(all_radicals(f,method='general')))

    def test_05_general_quartics(self):
        for f in [x**4-2,x**4-10*x*x+1]:
            with self.subTest(f=f):self.assertTrue(verify(all_radicals(f,method='general')))

    def test_06_negative_quintic(self):
        r=root_radicals(x**5-x-1,0)
        self.assertEqual(r['status'],'NotSolvable');self.assertTrue(verify(r))

    def test_07_negative_prime_degree_certificate(self):
        r=root_radicals(x**7-x-1,0,method='general')
        self.assertEqual(r['method'],'PrimeDegreeTransposition');self.assertTrue(verify(r))
        r['certificate']['factors'][0][0]=2
        with self.assertRaises(ValueError):verify(r)

    def test_08_reducible_selected_factor(self):
        f=(x-2)*(x**5-x-1)
        r=root_radicals(f,1);self.assertEqual(selected_expression(r),2);self.assertTrue(verify(r))
        r=root_radicals(f,0);self.assertEqual(r['status'],'NotSolvable');self.assertTrue(verify(r))

    def test_09_repeated_roots(self):
        for idx in [0,1,2]:
            r=root_radicals((x-3)**3,idx);self.assertEqual(selected_expression(r),3);self.assertTrue(verify(r))

    def test_10_resource_limits_are_unknown(self):
        r=all_radicals(x**4-2,method='general',max_field_degree=3)
        self.assertEqual(r['status'],'Unknown')
        r=all_radicals(x**3-2,method='general',max_candidates=1)
        self.assertEqual(r['status'],'Unknown')

    def test_11_tampered_branch(self):
        r=all_radicals(x**3-2,method='general')
        r['certificate']['stages'][0]['branch']=(r['certificate']['stages'][0]['branch']+1)%3
        with self.assertRaises(ValueError):verify(r)

    def test_12_tampered_output_and_conjugate(self):
        r=all_radicals(x**4-2,method='general');q=copy.deepcopy(r)
        q['roots'][0]['expression']=A.rat(123)
        with self.assertRaises(ValueError):verify(q)
        q=copy.deepcopy(r);q['roots'][0]['index'],q['roots'][1]['index']=q['roots'][1]['index'],q['roots'][0]['index']
        with self.assertRaises(ValueError):verify(q)

    def test_13_ast_rejects_unsupported_heads(self):
        for a in [['Root',[1,2,3]],['ref','not_defined'],['pow',['q',1,1],1,0],['q',True,2]]:
            with self.assertRaises(ValueError):A.validate(a)
        with self.assertRaises(ValueError):A.from_sympy(s.cos(1))

    def test_14_inexact_and_symbolic_rejected(self):
        for f in [x**2-2.0,x**2-s.sqrt(2),x**2-s.Symbol('a')]:
            with self.assertRaises((ValueError,s.polys.polyerrors.CoercionFailed)):root_radicals(f)
        with self.assertRaises(ValueError):root_radicals(x*x-2,True)

    def test_15_shifted_binomial_and_cyclotomic(self):
        for f in [(x-3)**5-2,s.cyclotomic_poly(11,x)]:
            with self.subTest(f=f):self.assertTrue(verify(all_radicals(f)))

    def test_16_wolfram_bridge_protocol(self):
        req={'action':'all','coefficients':['1','0','-2'],'timeout':30,'verify':True}
        p=subprocess.run([sys.executable,str(ROOT/'python'/'cli.py'),'--json'],input=json.dumps(req),text=True,capture_output=True,timeout=40)
        r=json.loads(p.stdout);self.assertEqual(r['status'],'Success');self.assertTrue(r['verified'])

    def test_17_cli_strict_input_and_timeout(self):
        for req in [{'coefficients':[1,0,2.0]},{'coefficients':[1,0,'__import__("os").system("id")']}]:
            req['timeout']=0
            p=subprocess.run([sys.executable,str(ROOT/'python'/'cli.py'),'--json'],input=json.dumps(req),text=True,capture_output=True,timeout=10)
            self.assertEqual(json.loads(p.stdout)['status'],'Error')
        req={'coefficients':[1,0,-2],'timeout':0.001,'method':'general'}
        p=subprocess.run([sys.executable,str(ROOT/'python'/'cli.py'),'--json'],input=json.dumps(req),text=True,capture_output=True,timeout=10)
        self.assertEqual(json.loads(p.stdout)['status'],'Unknown')

    def test_18_unbounded_general_option(self):
        r=all_radicals(x**3-2,method='general',max_field_degree=None,max_candidates=None)
        self.assertTrue(verify(r))

    def test_19_saved_general_quintics(self):
        for name in ['cyclic_quintic','binomial_quintic']:
            with self.subTest(name=name):
                r=json.loads((ROOT/'validation'/(name+'.json')).read_text())
                self.assertTrue(verify(r));self.assertEqual(len(r['roots']),5)

    def test_20_dickson_identity(self):
        u,c=s.symbols('u c')
        for n in range(2,10):
            self.assertEqual(s.cancel(dickson(n,u+c/u,c)-u**n-(c/u)**n),0)


if __name__=='__main__':unittest.main()
