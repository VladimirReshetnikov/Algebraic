"""Public Python API. Indices use SymPy's zero-based CRootOf convention."""
from __future__ import annotations
import sympy as s
from radical_solver import radicalize,verify_constructive,verify_negative
from structural import try_structural,verify_structural,certify_candidates
import radical_ast as A


def _rational_poly(poly):
    if isinstance(poly,s.Poly):
        if len(poly.gens)!=1:raise ValueError('A univariate polynomial is required')
        if any(c.has(s.Float) for c in poly.all_coeffs()):raise ValueError('Inexact coefficients are not accepted')
        return s.Poly(poly,domain=s.QQ)
    expr=s.sympify(poly)
    if expr.has(s.Float):raise ValueError('Inexact coefficients are not accepted')
    f=s.Poly(expr,domain=s.QQ)
    if len(f.gens)!=1:raise ValueError('A univariate polynomial is required')
    return f


def all_radicals(poly, *, method='auto', **options):
    """Solve all conjugates of an irreducible polynomial over Q.

    'auto': compact structural construction first, then general Galois descent.
    'general': always use the constructive Galois implementation.
    'structural': return Unknown if no implemented compact pattern applies.
    Caps apply to the general field construction; use CLI timeout for a hard
    wall-clock bound on either method. Caps None mean no artificial bound.
    """
    f=_rational_poly(poly)
    if f.degree()<1 or not f.is_irreducible:raise ValueError('Use root_radicals for reducible polynomials')
    if method not in ('auto','general','structural'):raise ValueError('Unknown method')
    if f.degree()==1:return certify_candidates(f,[-f.TC()/f.LC()],{'kind':'Linear'})
    if method!='general':
        out=try_structural(f)
        if out is not None:return out
        if method=='structural':return {'status':'Unknown','reason':'NoStructuralPattern','version':'1.0.0'}
    return radicalize(f,**options)


def root_radicals(poly,index=0, *, method='auto', **options):
    """Solve the selected root, reducing to its irreducible factor first.

    Repeated roots use CRootOf's multiplicity-aware indexing. The returned
    list comprises all conjugates of the selected root's minimal polynomial,
    not necessarily all roots of the originally supplied polynomial.
    """
    f=_rational_poly(poly)
    if isinstance(index,bool) or not isinstance(index,int) or not 0<=index<f.degree():
        raise ValueError('Root index must be an integer between 0 and degree-1')
    r=s.CRootOf(f,index)
    if r.is_Rational:
        t=s.Dummy('x');mf=s.Poly(t-r,t,domain=s.QQ);local=0
    else:mf=s.Poly(r.poly,domain=s.QQ);local=int(r.index)
    result=all_radicals(mf,method=method,**options)
    result['request']={'polynomial':[str(c) for c in f.all_coeffs()],
                       'root_index':index,'minimal_polynomial_root_index':local}
    if result['status']=='Success':
        result['selected_index']=local
        result['selected_expression']=next(a['expression'] for a in result['roots'] if a['index']==local)
    return result


def verify(result):
    """Recheck a positive certificate and its optional selected-root request."""
    if result.get('status')=='NotSolvable':ok=verify_negative(result)
    elif result.get('method')=='ConstructiveGalois':ok=verify_constructive(result)
    elif result.get('method')=='Structural':ok=verify_structural(result)
    else:raise ValueError('No positive certificate for this status/method')
    if 'request' in result:
        req=result['request'];x=s.Dummy('x')
        f=s.Poly.from_list([s.Rational(c) for c in req['polynomial']],x,domain=s.QQ)
        r=s.CRootOf(f,req['root_index'])
        mf=s.Poly(x-r,x,domain=s.QQ) if r.is_Rational else s.Poly(r.poly,domain=s.QQ)
        idx=0 if r.is_Rational else int(r.index)
        if [str(c) for c in mf.monic().all_coeffs()]!=result['polynomial']:
            raise ValueError('Wrong selected minimal polynomial')
        if idx!=req['minimal_polynomial_root_index']:
            raise ValueError('Wrong selected index')
        if result['status']=='Success':
            if idx!=result['selected_index']:raise ValueError('Wrong selected index')
            tree=next(a['expression'] for a in result['roots'] if a['index']==idx)
            if tree!=result['selected_expression']:raise ValueError('Wrong selected expression')
    return ok


def expressions(result):return A.expanded_expressions(result)


def selected_expression(result):
    """Fully expanded exact SymPy expression (may be much larger than JSON)."""
    if result.get('status')!='Success':raise ValueError('No radical expression is available')
    if 'selected_index' not in result:raise ValueError('Use root_radicals to select a root')
    return expressions(result)[result['selected_index']]
