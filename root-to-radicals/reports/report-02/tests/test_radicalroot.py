import sympy as s
import pytest
from sympy.combinatorics.named_groups import (SymmetricGroup, AlternatingGroup,
                                              DihedralGroup, CyclicGroup)
from radicalroot import *
x,y=s.symbols('x y')

@pytest.mark.parametrize('expr,expected',[
    (s.sqrt(2)+s.I,True),(zeta(7),True),
    (s.CRootOf(x**5-x-1,0),False),(s.cos(s.pi/7),False),
    (s.Float(1.2),False),(s.Symbol('a')**s.Rational(1,3),False)])
def test_grammar(expr,expected):
    assert radical_expression_q(expr)==expected

@pytest.mark.parametrize('n',range(2,10))
def test_dickson_identity(n):
    a=s.symbols('a')
    assert s.cancel(dickson(n,x+a/x,a)-x**n-(a/x)**n)==0

@pytest.mark.parametrize('index',range(5))
def test_question_quintic_all_roots(index):
    r=radicalize(5*x**5-25*x**3+25*x+6,index,method='fast')
    assert r.success and r.method=='dickson'
    assert verify_result(r)

@pytest.mark.parametrize('index',[0,1])
def test_question_sextic_real_roots(index):
    r=radicalize(x**6+x**4-x**3-x**2-1,index,method='fast')
    assert r.success and r.method=='reciprocal/low_degree'
    assert verify_result(r)

@pytest.mark.parametrize('f,index',[
    ((x+1)**5+2,0),(x**8-2,0),(x**6-3*x**3+1,0),
    (x**2-2,1),(x**3-x+1,0),((x-7)*(x**5-x-1),1)])
def test_fast_families(f,index):
    r=radicalize(f,index,method='fast')
    assert r.success,(r.status,r.message)
    assert verify_result(r)

@pytest.mark.parametrize('f,index',[(x**2-2,0),(x**3-2,0),
    (x**3-2,1),(x**4+x**3+x**2+x+1,0),(x**4-2,0)])
def test_complete_reference_path(f,index):
    r=radicalize(f,index,method='galois')
    assert r.success,(r.status,r.message)
    assert r.method=='galois_kummer'
    assert verify_result(r)
    assert all(s.isprime(p) for p in r.certificate['chain_indices'])
    assert s.prod(r.certificate['chain_indices'])==r.certificate['relative_group_order']

def test_pair_resolvent_question():
    f=s.Poly(x**6+x**4-x**3-x**2-1,x)
    R=pair_sum_resolvent(f,y)
    q=y**3+4*y-1
    h=y**12-y**9+8*y**8-2*y**7-y**6+4*y**5+18*y**4+9*y**3+2*y**2-1
    assert R==s.Poly(q*h,y,domain=s.QQ)
    assert s.Poly(s.resultant(f.as_expr(),f.as_expr().subs(x,y-x),x),y,domain=s.QQ)==s.Poly(64*f.as_expr().subs(x,y/2),y,domain=s.QQ)*R**2

def table_group(g):
    elems=list(g.generate_schreier_sims()); ids={a:i for i,a in enumerate(elems)}
    return FiniteGroup([[ids[a*b] for b in elems] for a in elems],ids[g.identity])

@pytest.mark.parametrize('g',[CyclicGroup(9),DihedralGroup(4),SymmetricGroup(3),AlternatingGroup(4),SymmetricGroup(4)])
def test_prime_chains(g):
    G=table_group(g);chain=G.cyclic_prime_chain()
    assert s.prod(row[3] for row in chain)==g.order()
    assert len(G.derived_series()[-1])==1

def test_nonsolvable_group():
    G=table_group(AlternatingGroup(5))
    with pytest.raises(RadicalError) as e:G.cyclic_prime_chain()
    assert e.value.status=='not_solvable'

def test_nonsolvable_polynomial():
    r=radicalize(x**5-x-1,0,method='galois')
    assert r.status=='not_solvable'
    assert r.certificate['galois_group_order']==120

def test_notfound_is_not_nonsolvable():
    r=radicalize(x**5-x-1,0,method='fast',pair_limit=0)
    assert r.status=='not_found'

def test_resource_limit():
    r=radicalize(x**3-2,0,method='galois',max_field_degree=2)
    assert r.status=='resource_limit'

@pytest.mark.parametrize('f,index',[(x+s.Float(0.1),0),(x+y,0),(x*x-2,2),(s.Integer(1),0)])
def test_bad_input(f,index):
    r=radicalize(f,index,method='fast')
    assert r.status in {'unsupported_input','backend_failure'}

def test_wrong_conjugate_rejected():
    r=RadicalResult('success',-s.sqrt(2),target=s.CRootOf(x*x-2,1))
    assert not verify_result(r)

def test_notebook_degree_eight_with_hint():
    f=x**8+8*x**7+20*x**6+8*x**5-36*x**4-48*x**3-15*x**2+2*x+1
    r=radicalize(f,0,method='fast',pair_limit=0,extensions=[s.sqrt(3)+s.sqrt(5)])
    assert r.success
    expected=(-2-s.sqrt(3)-s.sqrt(5+2*s.sqrt(5)))/2
    assert same_algebraic(r.expression,expected)
    assert verify_result(r)
