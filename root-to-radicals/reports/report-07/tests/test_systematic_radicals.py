"""Executed tests for the Python implementation. Run: python -m pytest -q tests.

The Wolfram tests in the neighboring directory are separate and were NOT run
in the preparation environment (the Wolfram connector returned HTTP 404).
"""
from copy import deepcopy
from pathlib import Path
import sys
import pytest
import sympy as s
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
from systematic_radicals import (solve_radical, solve_with_timeout, exact_equal,
    radical_expression_q, verify_tower, pair_sum_resolvent, dickson, zeta)

x=s.Symbol('x')
SEXTIC=x**6+x**4-x**3-x**2-1
QUINTIC=5*x**5-25*x**3+25*x+6

@pytest.mark.parametrize('p,i,method',[
    (SEXTIC,1,'reciprocal'), (QUINTIC,4,'Dickson'),
    (x**7-2,0,'shifted-power'), ((x-3)**10-7,1,'shifted-power'),
    (x**4-2,1,'degree<=4'), (x**3-2,0,'degree<=4'),
    ((x**2-2)**2,2,'degree<=4'),
])
def test_practical_successes(p,i,method):
    r=solve_radical(p,i,method='practical')
    assert r.status=='Success',r.diagnostics
    assert r.method==method
    assert radical_expression_q(r.expression)
    assert exact_equal(r.expression,s.CRootOf(p,i))

@pytest.mark.parametrize('i',range(5))
def test_all_dickson_branches(i):
    r=solve_radical(QUINTIC,i,method='practical')
    assert r.status=='Success',r.diagnostics
    assert exact_equal(r.expression,s.CRootOf(QUINTIC,i))

@pytest.mark.parametrize('i',[1,2,5,6])
def test_complex_binomial_branches(i):
    r=solve_radical(x**7-2,i,method='practical')
    assert r.status=='Success',r.diagnostics
    assert exact_equal(r.expression,s.CRootOf(x**7-2,i))

@pytest.mark.parametrize('p,i',[(x**2-2,1),(x**3-2,0),(x**4+1,0),
                              (x**4+x**3+x**2+x+1,0),(x**4-2,1)])
def test_forced_general_backend(p,i):
    r=solve_radical(p,i,method='complete')
    assert r.status=='Success',r.diagnostics
    assert r.method=='Galois-Kummer'
    assert verify_tower(r,s.CRootOf(p,i))
    assert radical_expression_q(r.expression)
    assert s.prod(st['prime'] for st in r.certificate['steps'])*s.totient(
        r.certificate['cyclotomic_order'])==r.certificate['field_degree']

@pytest.mark.parametrize('bad', [s.cos(s.pi/7),s.exp(2*s.pi*s.I/7),
                               s.CRootOf(SEXTIC,1),s.Symbol('a'),s.Float(1.2)])
def test_strict_grammar_rejects_hidden_nonradicals(bad):
    assert not radical_expression_q(bad)

@pytest.mark.parametrize('n',range(1,10))
def test_dickson_identity(n):
    u,a=s.symbols('u a')
    assert s.cancel(dickson(n,x,a).subs(x,u+a/u)-u**n-(a/u)**n)==0
    assert radical_expression_q(zeta(n))

def test_pair_resolvent_and_collisions():
    for p in [s.Poly(SEXTIC,x),s.Poly(x**4-1,x)]:
        r=pair_sum_resolvent(p);t=r.gen;n=p.degree()
        res=s.resultant(p.as_expr(),p.as_expr().subs(x,t-x),x)
        assert s.cancel(res-2**n*p.as_expr().subs(x,t/2)*r.as_expr()**2)==0
    r=pair_sum_resolvent(s.Poly(SEXTIC,x))
    assert s.rem(r.as_expr(),r.gen**3+4*r.gen-1,r.gen)==0
    # x^4-1 has two distinct pairs with sum zero: multiplicity is retained.
    rr=pair_sum_resolvent(s.Poly(x**4-1,x))
    assert rr.nth(0)==0 and rr.nth(1)==0

def test_nonsolvability_and_reducible_target():
    for method in ['practical','automatic']:
        r=solve_radical(x**5-x-1,method=method)
        assert r.status=='NotSolvable'
        assert r.certificate['group_order']==120
    p=(x-3)*(x**5-x-1)
    assert solve_radical(p,1).expression==3
    assert solve_radical(p,0).status=='NotSolvable'

@pytest.mark.parametrize('p,i,kwargs',[
    (x**2-s.Float(2),0,{}),(x**2-s.sqrt(2),0,{}),
    (x**2+s.Symbol('a'),0,{}),(x**2-2,-1,{}),(x**2-2,2,{}),
    (s.Integer(0),0,{}),(x**2-2,False,{}),
    (x**2-2,0,{'method':'typo'}),(x**2-2,0,{'max_field_degree':0}),
    (x**2-2,0,{'max_depth':-1})])
def test_invalid_input(p,i,kwargs):
    assert solve_radical(p,i,variable=x,**kwargs).status=='InvalidInput'

def test_resource_limit_is_not_nonsolvability():
    r=solve_radical(x**3-2,method='complete',max_field_degree=2)
    assert r.status=='Inconclusive'
    assert 'degree' in ' '.join(r.diagnostics)

def test_tampered_certificates():
    r=solve_radical(x**2-2,1,method='complete');target=s.CRootOf(x**2-2,1)
    assert verify_tower(r,target)
    bad=deepcopy(r);bad.certificate['steps'][0]['radicand']+=1
    assert not verify_tower(bad,target)
    bad=deepcopy(r);bad.certificate['steps'][0]['branch']^=1
    assert not verify_tower(bad,target)
    assert not verify_tower(r,s.CRootOf(x**2-2,0))

def test_process_timeout():
    r=solve_with_timeout(x**5-x-1,method='complete',seconds=0.001)
    assert r.status=='Inconclusive'
    assert 'Wall-clock' in ' '.join(r.diagnostics)

@pytest.mark.parametrize('p,method',[
 (x**8+8*x**7+20*x**6+8*x**5-36*x**4-48*x**3-15*x**2+2*x+1,'shifted-power'),
 (x**8+8*x**7+10*x**6-52*x**5-131*x**4-28*x**3+100*x**2+32*x+16,'shifted-power'),
 (x**8+8*x**7+16*x**6-4*x**5-68*x**4-28*x**3+49*x**2+14*x+1,'pair-resolvent'),
])
def test_additional_notebook_octics(p,method):
    r=solve_radical(p,0,method='practical')
    assert r.status=='Success',r.diagnostics
    assert r.method==method
    assert exact_equal(r.expression,s.CRootOf(p,0))

def test_solvable_practical_miss_is_inconclusive():
    p=x**8+8*x**7+16*x**6-4*x**5-68*x**4-28*x**3+49*x**2+14*x+1
    r=solve_radical(p,0,method='practical',pair_resolvent=False)
    assert r.status=='Inconclusive'

def test_shortcut_exception_does_not_block_complete_backend(monkeypatch):
    import systematic_radicals as sr
    def fail(*args,**kwargs):
        raise RuntimeError('deliberate shortcut failure')
    monkeypatch.setattr(sr,'structural_candidates',fail)
    r=sr.solve_radical(x**2-2,1,pair_resolvent=False)
    assert r.status=='Success' and r.method=='Galois-Kummer'
    assert sr.verify_tower(r,s.CRootOf(x**2-2,1))
    assert 'deliberate shortcut failure' in ' '.join(r.diagnostics)

def test_process_certificate_survives_domain_reconstruction():
    # SymPy reconstructs integral QQ polynomials as ZZ when unpickling.
    # The verifier must normalize domains before comparing ring elements.
    r=solve_with_timeout(x**2-2,1,method='complete',seconds=30)
    assert r.status=='Success',r.diagnostics
    assert verify_tower(r,s.CRootOf(x**2-2,1))

def test_rational_equality_uses_matching_domains():
    a=s.Add(s.sqrt(2),-s.sqrt(2),evaluate=False)
    assert exact_equal(a,s.S.Zero)

@pytest.mark.parametrize('name,n,orders',[
    ('S',3,[6,3,1]),('S',4,[24,12,4,1]),
    ('A',5,[60,60]),('S',5,[120,60,60])])
def test_group_table_subroutines(name,n,orders):
    """Unit-test finite-group logic, not an embedded splitting-field claim."""
    from sympy.combinatorics.named_groups import SymmetricGroup,AlternatingGroup
    from systematic_radicals import FiniteGroup
    P=(SymmetricGroup if name=='S' else AlternatingGroup)(n)
    elements=list(P.generate_schreier_sims())
    lookup={g:i for i,g in enumerate(elements)}
    G=FiniteGroup.__new__(FiniteGroup)
    G.table=[[lookup[a*b] for b in elements] for a in elements]
    G.identity=lookup[P.identity]
    G.inverse=[lookup[~a] for a in elements]
    G.elements=frozenset(range(len(elements)))
    assert [len(h) for h in G.derived_series()]==orders
    if orders[-1]==1:
        H=G.elements;primes=[]
        while len(H)>1:
            K,_,p=G.prime_step(H);primes.append(p)
            assert len(H)==p*len(K)
            # Consecutive normality, rather than global normality, is required.
            assert all(G.table[G.table[g][k]][G.inverse[g]] in K for g in H for k in K)
            H=K
        assert s.prod(primes)==len(elements)
