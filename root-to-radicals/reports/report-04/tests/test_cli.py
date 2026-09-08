"""CLI and certificate rejection smoke tests; run from any directory."""
from pathlib import Path
import sys,subprocess,json,time,hashlib,copy
import sympy as s
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python'))
import radical_roots as rr
engine=ROOT/'python/radical_roots.py'
results=[]

def run(name,args,expected):
    start=time.monotonic()
    p=subprocess.run([sys.executable,str(engine),*args],capture_output=True,text=True,timeout=40)
    out=json.loads(p.stdout)
    assert out['status']==expected,(name,p.stdout,p.stderr)
    assert p.returncode==(0 if expected=='Success' else 2)
    if expected=='Success':
        env={}
        for var,ast in out['radical_dag']['assignments']:
            env[var]=rr.expression_from_ast(ast,env)
        expr=rr.expression_from_ast(out['radical_dag']['result'],env)
        assert rr.radical_expression_q(expr)
    results.append(dict(name=name,passed=True,status=expected,seconds=round(time.monotonic()-start,6)))

run('CLI/quadratic-galois',['--coefficients','[1,0,-2]','--index','1','--method','galois'],'Success')
run('CLI/complex-rectangle',['--coefficients','[1,0,4]','--rectangle','["-1/10","1/10","19/10","21/10"]'],'Success')
run('CLI/nonsolvable',['--coefficients','[1,0,0,0,-1,-1]'],'NotSolvableByRadicals')
run('CLI/watchdog',['--coefficients','[1,0,0,-2]','--method','galois','--timeout','0.001'],'ResourceLimit')
run('CLI/invalid-index',['--coefficients','[1,0,-2]','--index','99'],'InvalidInput')

x=rr.X
r=rr.radicalize(x**3-2,0,method='galois')
f=s.Poly(x**3-2,x)
assert rr.verify_tower_result(r,f)
tampered=copy.deepcopy(r);tampered.final+=1
assert not rr.verify_tower_result(tampered,f)
results.append(dict(name='certificate/reject-wrong-final',passed=True))
tampered=copy.deepcopy(r);tampered.data['steps'][0]['phase']=(tampered.data['steps'][0]['phase']+1)%3
assert not rr.verify_tower_result(tampered,f)
results.append(dict(name='certificate/reject-wrong-phase',passed=True))
q=s.Poly((x-1)*(x-1-s.Rational(1,10**40)),x)
assert not rr.same_algebraic_root(q,s.S.One,1+s.Rational(1,10**40))
assert rr.same_algebraic_root(q,s.S.One,s.S.One)
results.append(dict(name='separation/nearby-exact-roots',passed=True))
report=dict(tests=len(results),passed=len(results),source_sha256=hashlib.sha256(engine.read_bytes()).hexdigest(),results=results)
(ROOT/'validation/cli-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
