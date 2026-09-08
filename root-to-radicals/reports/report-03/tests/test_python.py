"""Run directly for unittest, or through run_tests.py for per-test isolation."""
import pathlib, sys, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from radicalroots import (to_radicals, exact_equal, radical_q, zeta, dickson,
                          fast_candidates, NotSolvable, ResourceLimit, RadicalError)
from galois_core import GaloisModel, radicals_from_model, prime_chain
from sympy.combinatorics.named_groups import (CyclicGroup, SymmetricGroup,
                                             AlternatingGroup, DihedralGroup)
x=s.Symbol('x')
F=x**6+x**4-x**3-x**2-1
Q=5*x**5-25*x**3+25*x+6

class RadicalTests(unittest.TestCase):
    def conversion(self, f, i=0, **opts):
        r=to_radicals(f,i,**opts)
        self.assertEqual(r.status,'Success',str(r))
        self.assertTrue(r.verified)
        self.assertTrue(radical_q(r.expression))
        self.assertTrue(exact_equal(r.expression,s.CRootOf(f,i)))
        return r
    def test_01_sextic_positive(self):
        r=self.conversion(F,1,method='fast')
        t=(s.Rational(1,2)+s.sqrt(849)/18)**s.Rational(1,3)
        y=t-4/(3*t)
        self.assertTrue(exact_equal(r.expression,(y+s.sqrt(y*y+4))/2))
        self.assertIn('Reciprocal',r.method)
    def test_02_sextic_negative(self): self.conversion(F,0,method='fast')
    def test_03_sextic_complex(self): self.conversion(F,2,method='fast')
    def test_04_quintic_largest(self):
        r=self.conversion(Q,4,method='fast')
        u=((-3+4*s.I)/5)**s.Rational(1,5)
        self.assertTrue(exact_equal(r.expression,u+1/u))
        self.assertEqual(r.method,'Dickson')
    def test_05_quintic_other_branch(self): self.conversion(Q,0,method='fast')
    def test_06_quadratic_complex(self): self.conversion(x*x+1,0)
    def test_07_cubic_three_real(self): self.conversion(x**3-3*x+1,1,method='fast')
    def test_08_cubic_negative_real(self): self.conversion(x**3+2,0,method='fast')
    def test_09_quartic(self): self.conversion(x**4-2,0,method='fast')
    def test_10_binomial_septic(self): self.conversion(x**7-2,0,method='fast')
    def test_11_shifted_septic(self): self.conversion(s.expand((x-3)**7-2),0,method='fast')
    def test_12_dickson_septic(self): self.conversion(dickson(7,x,1)-3,0,method='fast')
    def test_13_composition(self):
        # A non-even, non-Dickson composition; exact polynomial identity checks
        # proposal soundness separately from the selected-root tests above.
        h=x*x+x
        f=s.expand(h**3+h+1)
        proposal=fast_candidates(s.Poly(f,x))
        self.assertIsNotNone(proposal)
        self.assertEqual(len(proposal[0]),6)
        for r in proposal[0][:1]:
            self.assertTrue(exact_equal(f.subs(x,r),0))
    def test_14_reducible_rational_selected(self):
        r=self.conversion((x-100)*(x**5-x-1),1)
        self.assertEqual(r.expression,100)
    def test_15_nonsolvable_S5(self):
        r=to_radicals(x**5-x-1)
        self.assertEqual(r.status,'NotSolvable')
        self.assertFalse(r.verified)
        self.assertEqual(r.details['group_order'],120)
    def test_16_fast_unknown_is_not_nonsolvable(self):
        r=to_radicals(x**5-x-1,method='fast')
        self.assertEqual(r.status,'Unknown')
    def test_17_general_quadratic_phase(self):
        r=self.conversion(x*x-2,0,method='galois')
        self.assertEqual(r.method,'GaloisFourier')
        self.assertTrue(any(p['phase']!=0 for p in r.details['phases']))
    def test_18_general_cubic_zero_resolvents(self):
        r=self.conversion(x**3-2,0,method='galois')
        self.assertEqual(r.details['quotient_primes'],[3])
        self.assertEqual(r.details['field_degree'],6)
    def test_19_general_cubic_complex(self): self.conversion(x**3-2,1,method='galois')
    def test_20_supplied_biquadratic(self):
        K=s.QQ.algebraic_field(s.sqrt(2),s.sqrt(3))
        M=GaloisModel.from_field(K,2)
        target=K.from_sympy(s.sqrt(2)-s.sqrt(3))
        r,d=radicals_from_model(M,target)
        self.assertEqual(K.from_sympy(r),target)
        self.assertEqual(d['quotient_primes'],[2,2])
        self.assertTrue(any(p['phase']!=0 for p in d['phases']))
    def test_21_supplied_complex_V4(self):
        K=s.QQ.algebraic_field(s.sqrt(2),s.I)
        M=GaloisModel.from_field(K,2)
        target=K.from_sympy(s.sqrt(2)+s.I)
        r,d=radicals_from_model(M,target)
        self.assertEqual(K.from_sympy(r),target)
    def test_22_reject_non_galois_model(self):
        K=s.QQ.algebraic_field(2**s.Rational(1,3))
        with self.assertRaises(RadicalError): GaloisModel.from_field(K,1)
    def test_23_field_budget(self):
        r=to_radicals(x**3-2,method='galois',max_field_degree=2)
        self.assertEqual(r.status,'ResourceLimit')
    def test_24_node_budget(self):
        r=to_radicals(x*x-2,method='galois',max_nodes=1)
        self.assertEqual(r.status,'ResourceLimit')
    def test_25_wrong_conjugate_rejected(self):
        self.assertFalse(exact_equal(s.sqrt(2),s.CRootOf(x*x-2,0)))
        self.assertFalse(exact_equal(1,2))
    def test_26_strict_grammar(self):
        self.assertTrue(radical_q(zeta(7)))
        self.assertTrue(radical_q((1+s.sqrt(2))**s.Rational(-2,3)))
        for r in [s.CRootOf(x**5-x-1,0),s.cos(s.pi/7),s.pi,s.Float(1.0),s.Symbol('a')]:
            self.assertFalse(radical_q(r),str(r))
    def test_27_input_validation(self):
        for f in [x**2+1.0,x**2+s.sqrt(2),x+s.Symbol('a')]:
            with self.assertRaises((ValueError,s.PolynomialError)): to_radicals(f)
        with self.assertRaises(ValueError): to_radicals(x*x-2,-1)
        with self.assertRaises(ValueError): to_radicals(x*x-2,method='unsupported')
    def test_28_finite_group_chains(self):
        for group,expected in [(CyclicGroup(5),[5]),(SymmetricGroup(3),[2,3]),
                              (SymmetricGroup(4),[2,3,2,2]),(DihedralGroup(4),[2,2,2])]:
            elems=list(group.generate_schreier_sims()); idx={a:i for i,a in enumerate(elems)}
            tab=[[idx[a*b] for b in elems] for a in elems]
            chain=prime_chain(tab,idx[group.identity],set(range(len(elems))))
            self.assertEqual([t[3] for t in chain],expected)
    def test_29_perfect_group_rejected(self):
        group=AlternatingGroup(5)
        elems=list(group.generate_schreier_sims());idx={a:i for i,a in enumerate(elems)}
        tab=[[idx[a*b] for b in elems] for a in elems]
        with self.assertRaises(NotSolvable):
            prime_chain(tab,idx[group.identity],set(range(len(elems))))
    def test_30_dickson_and_reciprocal_identities(self):
        u,a=s.symbols('u a')
        for n in range(1,10):
            self.assertEqual(s.cancel(dickson(n,x,a).subs(x,u+a/u)-u**n-(a/u)**n),0)
        self.assertEqual(s.expand(x**3*((x-1/x)**3+4*(x-1/x)-1)-F),0)

    def test_31_sextic_remaining_conjugates(self):
        for i in (3,4,5): self.conversion(F,i,method='fast')
    def test_32_quintic_remaining_conjugates(self):
        for i in (1,2,3): self.conversion(Q,i,method='fast')
    def test_33_general_nonabelian_D4(self):
        r=self.conversion(x**4-2,0,method='galois')
        self.assertEqual(r.details['relative_group_order'],8)
        self.assertEqual(r.details['quotient_primes'],[2,2,2])
    def test_34_cyclotomic_base_only(self):
        from galois_core import embed_exact
        K=s.QQ.algebraic_field(zeta(3))
        M=GaloisModel.from_field(K,3)
        target=embed_exact(K,zeta(3))
        r,d=radicals_from_model(M,target)
        self.assertTrue(exact_equal(r,zeta(3)))
        self.assertEqual(d['quotient_primes'],[])
    def test_35_conductor_validation(self):
        K=s.QQ.algebraic_field(s.sqrt(2))
        with self.assertRaises(RadicalError): GaloisModel.from_field(K,1)
    def test_36_nearby_conjugates(self):
        # Both roots round to 1 at ordinary working precision. A numerical
        # closeness test would give the wrong answer; root separation does not.
        epsilon=s.Rational(1,10**30)
        a=1+s.sqrt(2)*epsilon
        b=1-s.sqrt(2)*epsilon
        self.assertFalse(exact_equal(a,b))
        self.assertTrue(exact_equal(a,(10**30+s.sqrt(2))/10**30))

if __name__=='__main__': unittest.main(verbosity=2)
