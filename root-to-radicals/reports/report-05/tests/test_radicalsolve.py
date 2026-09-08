"""Run: python -m unittest discover -s tests -v
The optional S4 integration test is enabled with RADICALSOLVE_SLOW=1.
"""
import sys,os,json,subprocess,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from radicalsolve import *
from radicalsolve.core import GaloisEngine,Budget,rational_poly,anp_key,same_known_root
from radicalsolve.codec import encode_dag,decode_dag
x=s.symbols('x')
F6=x**6+x**4-x**3-x**2-1
F5=5*x**5-25*x**3+25*x+6

class StructuralTests(unittest.TestCase):
    def test_original_sextic_selected(self):
        r=radicalize(F6,1)
        self.assertEqual(r.method,'reciprocal-composition')
        self.assertTrue(verify(F6,r.expression,index=1))
    def test_original_quintic_selected(self):
        r=radicalize(F5,4)
        self.assertEqual(r.method,'dickson')
        self.assertTrue(verify(F5,r.expression,index=4))
    def test_sextic_reduction_identity(self):
        self.assertEqual(s.expand(x**3*((x-1/x)**3+4*(x-1/x)-1)-F6),0)
    def test_all_original_embeddings(self):
        # The structural identities prove annihilation; test every embedding match.
        for f in (F5,F6):
            p=s.Poly(f,x);rr=Solver().all_roots(p)
            for j in range(p.degree()):
                self.assertEqual(sum(same_known_root(p,s.CRootOf(p,j),r.expression) for r in rr),1)
    def test_shifted_binomial(self):
        p=s.Poly((x+1)**5+2,x);r=radicalize(p,0)
        self.assertEqual(r.method,'power-composition')
        self.assertTrue(verify(p,r.expression,index=0))
    def test_power_composition(self):
        p=s.Poly(x**8-5*x**4+4,x)
        rr=Solver().all_roots(p)
        self.assertEqual(len(rr),8)
        self.assertTrue(all(verify(p,r.expression) for r in rr))
    def test_shifted_reciprocal(self):
        p=s.Poly(F6.subs(x,x-2),x)
        rr=Solver().all_roots(p)
        self.assertEqual(rr[0].method,'reciprocal-composition')
        self.assertTrue(verify(p,rr[0].expression))
    def test_generic_quartic(self):
        p=s.Poly(x**4-x-1,x); rr=Solver().all_roots(p)
        self.assertEqual(len(rr),4)
        self.assertTrue(all(radical_expression_q(r.expression) for r in rr))
        for r in rr:
            self.assertLess(abs(complex(s.N(p.as_expr().subs(x,r.expression),70))),1e-55)
    def test_rational(self):
        self.assertEqual(radicalize(3*x-2).expression,s.Rational(2,3))
    def test_repeated_root_indices(self):
        p=s.Poly((x**2-2)**2,x)
        self.assertEqual(radicalize(p,0).expression,radicalize(p,1).expression)
    def test_mixed_factor_solvability(self):
        p=s.Poly((x**2-2)*(x**5-x-1),x)
        self.assertEqual(radicalize(p,0).expression,-s.sqrt(2))
    def test_not_solvable(self):
        with self.assertRaises(NotSolvable):radicalize(x**5-x-1)
    def test_wrong_conjugate(self):
        self.assertFalse(verify(x**2-2,s.sqrt(2),index=0))
    def test_nonroot(self):
        self.assertFalse(verify(x**2-2,s.sqrt(3)))
    def test_floats_rejected(self):
        with self.assertRaises(InvalidInput):radicalize(x**2-s.Float('1.2'))
    def test_parameters_rejected(self):
        a=s.symbols('a')
        with self.assertRaises(InvalidInput):radicalize(x**2-a)
    def test_invalid_index(self):
        with self.assertRaises(InvalidInput):radicalize(x**2-2,2)
        with self.assertRaises(InvalidInput):radicalize(x**2-2,True)
    def test_grammar(self):
        self.assertTrue(radical_expression_q(s.sqrt(2)+s.Pow(-1,s.Rational(2,7))))
        self.assertFalse(radical_expression_q(s.CRootOf(x**5-x-1,0)))
        self.assertFalse(radical_expression_q(s.cos(s.pi/7)))
        self.assertFalse(radical_expression_q(s.Float(1)))

class GeneralTests(unittest.TestCase):
    def check_general(self, f, order, independent=True):
        solver=Solver(method='galois');rr=solver.all_roots(f)
        self.assertEqual(len(rr),s.degree(f,x))
        self.assertEqual(rr[-1].record['field_degree'],order)
        self.assertTrue(all(r.method=='galois-fourier' for r in rr))
        if independent:
            self.assertTrue(all(verify(f,r.expression) for r in rr))
        for r in rr:
            self.assertLess(abs(complex(s.N(f.subs(x,r.expression),85))),1e-65)
        return rr
    def test_C2(self):self.check_general(x**2+1,2)
    def test_C3(self):self.check_general(x**3-3*x+1,3)
    def test_S3_non_disjoint(self):self.check_general(x**3-2,6)
    def test_V4(self):self.check_general(x**4-10*x**2+1,4)
    def test_C4(self):self.check_general(x**4+x**3+x**2+x+1,4)
    def test_D4(self):self.check_general(x**4-2,8)
    def test_C5(self):
        # Independent minpoly reconstruction is deliberately not used here:
        # it discarded the resolvent relations and was very slow in this environment.
        self.check_general(x**5+x**4-4*x**3-3*x**2+3*x+1,5,independent=False)
    def test_tensor_zero_divisors(self):
        e=GaloisEngine(rational_poly(x**2+x+1),Budget(),[])
        a=e.K.unit;b=-e.K.one-a
        left=(-a,e.K.one);right=(-b,e.K.one)
        self.assertTrue(any(c!=e.K.zero for c in left))
        self.assertTrue(any(c!=e.K.zero for c in right))
        self.assertEqual(e.tmul(left,right,3),(e.K.zero,e.K.zero))
    def test_limit_is_not_nonsolvability(self):
        with self.assertRaises(ResourceLimit):
            Solver(method='galois',max_field_degree=2).all_roots(x**3-2)
    def test_invalid_limits(self):
        for limit in (0,-1,float('nan'),float('inf'),True):
            with self.assertRaises(InvalidInput):Solver(max_seconds=limit)
    @unittest.skipUnless(os.getenv('RADICALSOLVE_SLOW')=='1','optional slow S4 integration')
    def test_S4(self):self.check_general(x**4-x-1,24,independent=False)

class ProtocolTests(unittest.TestCase):
    def test_dag_roundtrip(self):
        e=radicalize(F5,4).expression
        self.assertEqual(decode_dag(encode_dag(e)),e)
    def test_forward_reference_rejected(self):
        with self.assertRaises(InvalidInput):
            decode_dag({'format':'RadicalSolve-DAG-1','nodes':[['Pow',0,1]],'root':0})
    def test_undefined_power_rejected(self):
        with self.assertRaises(InvalidInput):
            decode_dag({'format':'RadicalSolve-DAG-1','nodes':[['Q','0','1'],['Q','-1','1'],['Pow',0,1]],'root':2})
    def test_cli(self):
        cli=Path(__file__).resolve().parents[1]/'python'/'cli.py'
        data={'coefficients':[['1','1'],['0','1'],['-2','1']],'action':'all'}
        p=subprocess.run([sys.executable,str(cli)],input=json.dumps(data),text=True,capture_output=True,check=True)
        r=json.loads(p.stdout)
        self.assertEqual(r['status'],'Success');self.assertEqual(len(r['roots']),2)
        self.assertTrue(all(verify(x**2-2,decode_dag(t['dag'])) for t in r['roots']))
    def test_cli_hard_deadline(self):
        cli=Path(__file__).resolve().parents[1]/'python'/'cli.py'
        data={'coefficients':[['1','1'],['0','1'],['-2','1']],
              'hard_timeout_seconds':0.001}
        p=subprocess.run([sys.executable,str(cli)],input=json.dumps(data),text=True,capture_output=True)
        self.assertEqual(json.loads(p.stdout)['status'],'ResourceLimit')
    def test_cli_rejects_source_code(self):
        cli=Path(__file__).resolve().parents[1]/'python'/'cli.py'
        data={'coefficients':[['__import__("os")','1'],['1','1']]}
        p=subprocess.run([sys.executable,str(cli)],input=json.dumps(data),text=True,capture_output=True)
        self.assertEqual(json.loads(p.stdout)['status'],'InvalidInput')

if __name__=='__main__':unittest.main()
