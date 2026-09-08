"""Run from any directory: python tests/test_radical_roots.py.

Successful answers are root-matched again after expanding the straight-line
program. A marked subset also receives an independent minimal-polynomial check;
Galois-Kummer answers receive a separate triangular-polynomial certificate check. The test log is evidence for these cases, not a formal proof.
"""
from pathlib import Path
import sys, json, time, platform, traceback, hashlib
import sympy as s
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
import radical_roots as rr
x=rr.X
source_hash=hashlib.sha256(Path(rr.__file__).read_bytes()).hexdigest()
records=[]

def check(name,fn):
    start=time.monotonic()
    try:
        detail=fn()
        rec=dict(name=name,passed=True,seconds=round(time.monotonic()-start,6),detail=detail)
    except Exception as e:
        rec=dict(name=name,passed=False,seconds=round(time.monotonic()-start,6),error=repr(e))
        traceback.print_exc()
    records.append(rec)
    print(json.dumps(rec),flush=True)

def success(f,i,method='auto',independent=True):
    a=rr.radicalize(f,i,method=method)
    assert a.status=='Success',a.summary()
    e=a.expanded()
    assert rr.radical_expression_q(e)
    if a.method=='Galois-Kummer':
        assert rr.verify_tower_result(a,s.Poly(s.minpoly(a.target,x),x,domain=s.QQ))
    p=s.Poly(s.minpoly(a.target,x),x,domain=s.QQ)
    if independent:
        assert rr._annihilates(p,e)
    assert rr.same_algebraic_root(p,e,a.target,both_known_roots=True)
    # JSON serialization and a non-executable radical DAG must work.
    encoded=json.dumps(a.summary())
    assert 'radical_dag' in encoded
    assert 'Root' not in a.to_wolfram() and 'Cos[' not in a.to_wolfram()
    return dict(method=a.method,degree=p.degree(),independent_minpoly_check=independent,group_order=a.data.get('group_order'),
                steps=len(a.assignments),wolfram=a.to_wolfram())

def status(f,i,expected,**opts):
    a=rr.radicalize(f,i,**opts)
    assert a.status==expected,a.summary()
    return a.summary()

def raises(fn,kind=ValueError):
    try:fn()
    except kind:return {'exception':kind.__name__}
    raise AssertionError('Expected exception')

for name,f,i in [
 ('rational',3*x-7,0),('quadratic-negative',x*x-2,0),
 ('quadratic-positive',x*x-2,1),('pure-cubic-real',x**3-2,0),
 ('pure-cubic-complex-minus',x**3-2,1),('pure-cubic-complex-plus',x**3-2,2),
 ('biquadratic',x**4-10*x*x+1,3),('D4-quartic',x**4-2,2)]:
    check('galois/'+name,lambda f=f,i=i:success(f,i,'galois'))

f6=x**6+x**4-x**3-x*x-1
f5=5*x**5-25*x**3+25*x+6
for i in range(6):
    check(f'question-sextic/root-{i}',lambda i=i:success(f6,i,'fast',independent=(i<2)))
for i in range(5):
    check(f'question-quintic/root-{i}',lambda i=i:success(f5,i,'fast',independent=(i==4)))
for name,f,i in [
 ('shifted-seventh',(x+1)**7+2,0),('sextic-binomial',x**6-2,5),
 ('composition',(x*x+x)**3-2,1),('even-octic',x**8-10*x**4+1,6),
 ('repeated-root',(x*x-2)**3,1),
 ('selected-solvable-factor',(x**5-x-1)*(x*x-2),2)]:
    check('fast/'+name,lambda f=f,i=i:success(f,i,independent=False))
check('galois/cyclic-quintic',lambda:success(x**5+x**4-4*x**3-3*x*x+3*x+1,4,'galois',independent=False))
check('fast/cyclotomic-degree-six',lambda:success(s.cyclotomic_poly(7,x),0,'fast',independent=False))
check('fast/real-cyclotomic-quintic',lambda:success(x**5+x**4-4*x**3-3*x*x+3*x+1,4,'fast',independent=False))
check('nonsolvable-S5',lambda:status(x**5-x-1,0,'NotSolvableByRadicals'))
check('nonsolvable-selected-factor',lambda:status((x**5-x-1)*(x*x-2),1,'NotSolvableByRadicals'))
check('field-degree-limit',lambda:status(x**3-2,0,'ResourceLimit',method='galois',max_degree=2))
check('fast-not-found-is-not-nonsolvable',lambda:status(x**5-x-1,0,'NotFound',method='fast',pair_resolvent=False))

def pairtest():
    p=s.Poly(f6,x)
    q=rr.pair_sum_resolvent(p)
    z=q.gen
    expected=(z**3+4*z-1)*(z**12-z**9+8*z**8-2*z**7-z**6+4*z**5+18*z**4+9*z**3+2*z*z-1)
    assert s.expand(q.as_expr()-expected)==0
    assert s.expand(f6-x**3*((x-1/x)**3+4*(x-1/x)-1))==0
    return {'pair_resolvent_degree':q.degree(),'identity':'exact'}
check('pair-resolvent-identity',pairtest)
for name,fn in [
 ('float',lambda:rr.radicalize(x*x-s.Float(2))),
 ('parameter',lambda:rr.radicalize(x*x-s.Symbol('a'))),
 ('zero',lambda:rr.radicalize(0)),
 ('index',lambda:rr.radicalize(x*x-2,2)),
 ('bool-index',lambda:rr.radicalize(x*x-2,True)),
 ('method',lambda:rr.radicalize(x*x-2,method='numerical'))]:
    check('reject/'+name,lambda fn=fn:raises(fn))
for f,box,expected in [
 (x*x+4,['-1/10','1/10','19/10','21/10'],1),
 (x*x-2,['7/5','3/2','-1/10','1/10'],1),
 (x**3-2,['-1','-1/2','-3/2','-1'],1),
 (x-1,['1/2','3/2','-1','1'],0)]:
    def rect(f=f,box=box,expected=expected):
        i=rr.select_root_rectangle(s.Poly(f,x),list(map(s.Rational,box)))
        assert i==expected,(i,expected)
        return {'index':i,'rectangle':box}
    check('rectangle/'+str(f),rect)
check('reject/rectangle-boundary',lambda:raises(lambda:rr.select_root_rectangle(s.Poly(x*x-1,x),[1,2,-1,1])))
check('reject/rectangle-two-roots',lambda:raises(lambda:rr.select_root_rectangle(s.Poly(x*x-1,x),[-2,2,-1,1])))
check('reject/trigonometric-output',lambda:{'rejected':not rr.radical_expression_q(s.cos(s.pi/7))} if not rr.radical_expression_q(s.cos(s.pi/7)) else (_ for _ in ()).throw(AssertionError()))

report={'python':platform.python_version(),'sympy':s.__version__,'source_sha256':source_hash,
        'tests':len(records),'passed':sum(r['passed'] for r in records),
        'results':records}
out=Path(__file__).resolve().parents[1]/'validation'/'test-report.json'
out.write_text(json.dumps(report,indent=2)+'\n')
print('FINAL',report['passed'],'/',report['tests'],flush=True)
sys.exit(0 if report['passed']==report['tests'] else 1)
