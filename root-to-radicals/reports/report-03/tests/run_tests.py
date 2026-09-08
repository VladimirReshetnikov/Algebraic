"""Isolated regression runner; writes honest PASS/FAIL/TIMEOUT JSON.

Usage: python tests/run_tests.py [--timeout 30] [--filter substring]
Each test runs in a fresh subprocess with a hard timeout, unlike the solver's
algebraic degree/node budgets. TIMEOUT is not a mathematical negative result.
"""
import argparse, datetime, json, os, pathlib, platform, subprocess, sys, time
import sympy
from test_python import RadicalTests

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--timeout',type=float,default=30)
    p.add_argument('--filter',default='')
    args=p.parse_args()
    root=pathlib.Path(__file__).resolve().parents[1]
    results=[]
    for name in sorted(n for n in dir(RadicalTests) if n.startswith('test_') and args.filter in n):
        start=time.perf_counter()
        try:
            proc=subprocess.run([sys.executable,str(root/'tests/test_python.py'),
                                 'RadicalTests.'+name],capture_output=True,text=True,
                                timeout=args.timeout)
            status='PASS' if proc.returncode==0 else 'FAIL'
            output=proc.stdout+proc.stderr
        except subprocess.TimeoutExpired as e:
            status='TIMEOUT'
            output='Process terminated by isolated regression runner.'
        row=dict(test=name,status=status,seconds=round(time.perf_counter()-start,4),output=output)
        results.append(row)
        print(f"{status:7} {name}: {row['seconds']} s",flush=True)
    report=dict(recorded_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                python=sys.version,sympy=sympy.__version__,platform=platform.platform(),
                per_test_timeout=args.timeout,tests=results,
                summary={s:sum(r['status']==s for r in results) for s in ['PASS','FAIL','TIMEOUT']})
    path=root/'test-results'/('python-tests'+('-'+args.filter if args.filter else '')+'.json')
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(report,indent=2))
    print(json.dumps(report['summary']),flush=True)
    return int(any(r['status']!='PASS' for r in results))
if __name__=='__main__': sys.exit(main())
