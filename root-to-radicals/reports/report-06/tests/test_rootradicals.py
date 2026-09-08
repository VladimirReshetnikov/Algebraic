"""Reproducible exact tests. Run: python -m unittest discover -s tests -v.
Set PYTHONPATH to ./python first, or install that directory with pip -e.
The optional extended examples use the CLI time limit rather than blocking this suite.
"""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
import warnings
import sympy as s
from sympy.combinatorics.named_groups import CyclicGroup, DihedralGroup, SymmetricGroup, AlternatingGroup
from sympy.utilities.exceptions import SymPyDeprecationWarning
from rootradicals import RadicalProgram, radicalize, certify_expression, radical_expression
from rootradicals.field import ExactField, Interval, Rectangle
from rootradicals.groups import TableGroup
from rootradicals.solver import prime_degree_obstruction, zeta_algebraic
from rootradicals.cli import request_target, rational
warnings.filterwarnings('ignore', category=SymPyDeprecationWarning)
x=s.Symbol('x')
ROOT=Path(__file__).resolve().parents[1]

class ConversionTests(unittest.TestCase):
    def check_conversion(self, f, i, **kw):
        a=s.CRootOf(f,i)
        r=radicalize(a,**kw)
        self.assertEqual(r.status,'success',r.message)
        self.assertTrue(r.verify())
        self.assertTrue(radical_expression(r.expression))
        self.assertTrue(certify_expression(r.expression,a,r.polynomial))
        p=RadicalProgram.from_json(r.program.to_json())
        self.assertTrue(certify_expression(p.expression(),a,r.polynomial))
        return r
    def test_original_sextic(self):
        r=self.check_conversion(x**6+x**4-x**3-x**2-1,1)
        self.assertIn('reciprocal',r.details['transformations'][0])
    def test_original_quintic(self):
        r=self.check_conversion(5*x**5-25*x**3+25*x+6,4)
        self.assertIn('Dickson',r.details['transformations'][0])
    def test_sextic_other_real(self): self.check_conversion(x**6+x**4-x**3-x**2-1,0)
    def test_translated_septic_real(self): self.check_conversion((x-3)**7+2,0)
    def test_translated_septic_complex(self): self.check_conversion((x-3)**7+2,6)
    def test_real_cyclotomic_quintic(self):
        self.check_conversion(x**5+x**4-4*x**3-3*x**2+3*x+1,4)
    def test_cyclotomic_order_11(self): self.check_conversion(s.cyclotomic_poly(11,x),9)
    def test_power_composition(self): self.check_conversion(x**8+3*x**4+1,7)
    def test_rational(self):
        r=radicalize(s.Rational(-7,13));self.assertTrue(r.verify());self.assertEqual(r.expression,s.Rational(-7,13))
    def test_reducible_input(self): self.check_conversion((x-2)*(x**5-x-1),1)
    def test_repeated_input(self): self.check_conversion((x**2-2)**2,3)
    def test_extension_hint_membership(self):
        f=s.minpoly(s.sqrt(2)+s.sqrt(3)+s.sqrt(5),x)
        r=self.check_conversion(f,7,method='structural',extension_hints=[s.sqrt(2),s.sqrt(3),s.sqrt(5)])
        self.assertIn(r.method,('structural','extension-hints'))
    def test_nonsolvable_quintic(self):
        r=radicalize(s.CRootOf(x**5-x-1,0));self.assertEqual(r.status,'not_solvable')
        self.assertEqual(r.details['modular_prime'],2);self.assertEqual(r.details['cycle_type'],[2,3])
    def test_nonsolvable_septic(self):
        r=radicalize(s.CRootOf(x**7-x-1,0));self.assertEqual(r.status,'not_solvable')
        self.assertEqual(r.details['cycle_type'],[2,5])
    def test_recognizer_failure_is_unknown(self):
        r=radicalize(s.CRootOf(x**5-x-1,0),method='structural');self.assertEqual(r.status,'unknown')
    def test_degree_limit_is_not_nonsolvable(self):
        r=radicalize(s.CRootOf(x**3-2,0),method='galois',max_field_degree=2)
        self.assertEqual(r.status,'resource_limit')
    def test_bad_options_and_float(self):
        for kw in ({'method':'bogus'},{'max_field_degree':0},{'max_field_degree':True}):
            with self.assertRaises(ValueError):radicalize(s.sqrt(2),**kw)
        with self.assertRaises(ValueError):radicalize(s.Float('1.414213562373095'))
    def test_nearby_is_not_equal(self):
        a=s.CRootOf(x**2-2,1)
        self.assertFalse(certify_expression(s.sqrt(2)+s.Rational(1,10**100),a))
    def test_incorrect_conjugate(self):
        self.assertFalse(certify_expression(-s.sqrt(2),s.CRootOf(x**2-2,1)))

class GaloisTests(ConversionTests):
    # Do not inherit the conversion cases twice: the runner below only loads
    # methods defined on this class, using load_tests.
    def test_galois_quadratic(self): self.check_conversion(x**2-2,1,method='galois')
    def test_galois_s3_real(self):
        r=self.check_conversion(x**3-2,0,method='galois')
        self.assertEqual(r.details['splitting_field_degree'],6)
        self.assertEqual(r.details['prime_indices'],[3])
    def test_galois_s3_complex(self): self.check_conversion(x**3-2,2,method='galois')
    def test_galois_cyclic_cubic(self): self.check_conversion(x**3-3*x+1,2,method='galois')
    def test_galois_biquadratic(self):
        r=self.check_conversion(x**4+1,3,method='galois')
        self.assertEqual(r.details['prime_indices'],[2,2])
    def test_galois_degree_eight(self): self.check_conversion(x**8+1,7,method='galois')
    def test_galois_d4(self): self.check_conversion(x**4-2,3,method='galois')
    def test_corrupt_certificate_rejected(self):
        r=radicalize(s.CRootOf(x**2-2,1),method='galois')
        c=copy.copy(r.certificate);c.step_values=[-v for v in c.step_values]
        self.assertFalse(c.verify(r.program,r.target))
    def test_corrupt_output_rejected(self):
        r=radicalize(s.CRootOf(x**2-2,1),method='galois')
        p=RadicalProgram(r.program.assignments,r.program.output+1)
        self.assertFalse(r.certificate.verify(p,r.target))

class GroupAndBranchTests(unittest.TestCase):
    def table_group(self,G):
        els=list(G.generate_schreier_sims());where={g:i for i,g in enumerate(els)}
        return TableGroup([[where[a*b] for b in els] for a in els],where[G.identity])
    def test_solvable_group_chains(self):
        for G in [CyclicGroup(4),CyclicGroup(6),DihedralGroup(4),SymmetricGroup(3),SymmetricGroup(4)]:
            with self.subTest(order=G.order()):
                t=self.table_group(G);chain=t.prime_chain();self.assertIsNotNone(chain)
                self.assertEqual(len(chain[-1]),1)
                self.assertEqual([len(h) for h in t.derived_series()], [g.order() for g in G.derived_series()])
                for H,N in zip(chain,chain[1:]):self.assertTrue(s.isprime(len(H)//len(N)))
    def test_a5_is_not_solvable(self): self.assertIsNone(self.table_group(AlternatingGroup(5)).prime_chain())
    def test_square_root_branch_boundary(self):
        F=ExactField(s.QQ.algebraic_field(s.I));zp=F.K.from_sympy(s.S.NegativeOne)
        self.assertTrue(F.principal_sector(F.K.from_sympy(s.I),2,zp))
        self.assertFalse(F.principal_sector(F.K.from_sympy(-s.I),2,zp))
        self.assertTrue(F.principal_sector(F.K.from_sympy(s.S.One),2,zp))
        self.assertFalse(F.principal_sector(F.K.from_sympy(s.S.NegativeOne),2,zp))
    def test_cube_root_branch_boundary(self):
        z=zeta_algebraic(3);F=ExactField(s.QQ.algebraic_field(z));zp=F.K.from_sympy(z)
        eta=-zp**2
        self.assertTrue(F.principal_sector(eta,3,zp))
        self.assertFalse(F.principal_sector(F.one/eta,3,zp))
        self.assertFalse(F.principal_sector(-F.one,3,zp))
        self.assertTrue(F.principal_sector(F.one,3,zp))
    def test_fifth_root_branch_boundary(self):
        z=zeta_algebraic(5);F=ExactField(s.QQ.algebraic_field(z));zp=F.K.from_sympy(z)
        eta=-zp**3
        self.assertTrue(F.principal_sector(eta,5,zp))
        self.assertFalse(F.principal_sector(F.one/eta,5,zp))
        self.assertFalse(F.principal_sector(eta**2,5,zp))
        self.assertTrue(F.principal_sector(F.one,5,zp))
    def test_exact_zero_before_refinement(self):
        F=ExactField(s.QQ.algebraic_field(s.I));v=F.K.from_sympy(3*s.I)
        self.assertEqual(F.sign_component(v,'real'),0)
        self.assertEqual(F.sign_component(v,'imag'),1)
        v=F.K.from_sympy(s.Rational(1,10**200)+s.I)
        self.assertEqual(F.sign_component(v,'real'),1)
    def test_rectangle_arithmetic(self):
        a=Interval(s.Rational(-2),s.Rational(3));b=Interval(s.Rational(4),s.Rational(5))
        self.assertEqual(a*b,Interval(s.Rational(-10),s.Rational(15)))
        z=Rectangle(Interval(s.Integer(0),s.Integer(0)),Interval(s.Integer(1),s.Integer(1)))
        self.assertEqual(z*z,Rectangle.rational(s.Integer(-1)))
    def test_frobenius_no_false_rejection(self):
        for f in [x**5-2,5*x**5-25*x**3+25*x+6,x**7-2]:
            self.assertIsNone(prime_degree_obstruction(s.Poly(f,x,domain=s.QQ)))

class ProtocolTests(unittest.TestCase):
    def request(self):return {'coefficients':[['1','1'],['0','1'],['-2','1']], 'root_index':1,'time_limit':30}
    def call_cli(self,q):
        p=subprocess.run([sys.executable,str(ROOT/'python'/'driver.py')],input=json.dumps(q),text=True,capture_output=True,timeout=40,cwd='/tmp' if os.name!='nt' else str(ROOT))
        self.assertEqual(p.returncode,0,p.stderr);return json.loads(p.stdout)
    def test_cli_success(self):
        out=self.call_cli(self.request());self.assertEqual(out['status'],'success')
        self.assertEqual(RadicalProgram.from_json(out['program']).expression(),s.sqrt(2))
    def test_cli_timeout(self):
        q=self.request();q['time_limit']=0.001
        self.assertEqual(self.call_cli(q)['status'],'resource_limit')
    def test_bad_root_index(self):
        q=self.request();q['root_index']=True
        self.assertEqual(self.call_cli(q)['status'],'invalid_input')
    def test_embedding_hint(self):
        q=self.request();q.pop('root_index');q['embedding_hint']={'re':['14','10'],'im':['0','1']}
        target,index=request_target(q);self.assertEqual(index,1)
    def test_rational_validation(self):
        for q in [['1','0'],['1','-1'],['1/2','1'],['__import__("os")','1'],[1,'1']]:
            with self.assertRaises(ValueError):rational(q)
    def test_dag_roundtrip(self):
        e=s.sqrt(2)+(3+4*s.I)**s.Rational(1,5)
        p=RadicalProgram.from_expr(e);self.assertEqual(RadicalProgram.from_json(p.to_json()).expression(),e)
    def test_dag_reject_unknown_operation(self):
        with self.assertRaises(ValueError):RadicalProgram.from_json({'format':'rootradicals-dag-v1','nodes':[{'op':'eval','code':'print(1)'}],'output':0})
    def test_dag_reject_forward_reference(self):
        with self.assertRaises(ValueError):RadicalProgram.from_json({'format':'rootradicals-dag-v1','nodes':[{'op':'Pow','base':0,'n':'1','d':'2'}],'output':0})
    def test_dag_reject_nonfinite(self):
        with self.assertRaises(ValueError):RadicalProgram.from_json({'format':'rootradicals-dag-v1','nodes':[{'op':'Q','n':'0','d':'1'},{'op':'Pow','base':0,'n':'-1','d':'1'}],'output':1})
    def test_nonradical_grammar(self):
        for e in [s.pi,s.sin(s.Rational(1,3)),s.CRootOf(x**5-x-1,0),s.Symbol('z')]:
            self.assertFalse(radical_expression(e))

def load_tests(loader,tests,pattern):
    suite=unittest.TestSuite()
    for cls in [ConversionTests,GaloisTests,GroupAndBranchTests,ProtocolTests]:
        suite.addTests(cls(name) for name in sorted(cls.__dict__) if name.startswith('test_'))
    return suite

if __name__=='__main__':unittest.main(verbosity=2)
