#!/usr/bin/env python3
"""JSON command-line interface, with a killable worker and strict rational input."""
from __future__ import annotations
import argparse,json,multiprocessing as mp,re,sys,time,traceback
from pathlib import Path

RATIONAL=re.compile(r'[+-]?\d+(?:/[1-9]\d*)?\Z')


def rational_list(values):
    import sympy as s
    if not isinstance(values,list) or len(values)<2:raise ValueError('Need at least two coefficients')
    out=[]
    for v in values:
        if isinstance(v,bool) or not isinstance(v,(str,int)) or not RATIONAL.fullmatch(str(v)):
            raise ValueError('Each coefficient must be an integer or an exact fraction string')
        num,sep,den=str(v).partition('/')
        out.append(s.Rational(int(num),int(den) if sep else 1))
    if out[0]==0:raise ValueError('Leading coefficient must be nonzero')
    return out


def execute(request):
    import sympy as s
    from api import all_radicals,root_radicals,verify
    if request.get('action')=='verify':
        return {'status':'Verified','verified':bool(verify(request['result']))}
    cs=rational_list(request['coefficients']);x=s.Symbol('x')
    f=s.Poly.from_list(cs,x,domain=s.QQ)
    options={}
    for name,default in [('max_field_degree',128),('max_candidates',1000000)]:
        value=request.get(name,default)
        if value is not None and (isinstance(value,bool) or not isinstance(value,int) or value<0):
            raise ValueError(name+' must be a nonnegative integer or null')
        options[name]=None if value in (None,0) else value
    method=request.get('method','auto')
    if request.get('progress',False):
        start=time.monotonic()
        options['progress']=lambda message:print(f'{time.monotonic()-start:.3f}s {message}',file=sys.stderr,flush=True)
    action=request.get('action','root')
    if action=='all':result=all_radicals(f,method=method,**options)
    elif action=='root':result=root_radicals(f,request.get('index',0),method=method,**options)
    else:raise ValueError('Unknown action')
    if request.get('verify',True) and result['status'] in ('Success','NotSolvable'):
        result['verified']=bool(verify(result))
    return result


def worker(conn,request):
    try:conn.send(execute(request))
    except Exception as exc:
        conn.send({'status':'Error','reason':type(exc).__name__,'message':str(exc),
                   'traceback':traceback.format_exc()})
    finally:conn.close()


def run(request):
    timeout=request.get('timeout',120)
    if timeout is not None and (isinstance(timeout,bool) or not isinstance(timeout,(int,float)) or timeout<0):
        raise ValueError('timeout must be nonnegative seconds or null')
    if timeout in (None,0):return execute(request)
    context=mp.get_context('spawn');receive,send=context.Pipe(duplex=False)
    process=context.Process(target=worker,args=(send,request));process.start();send.close()
    try:
        if receive.poll(timeout):
            try:result=receive.recv()
            except EOFError:result={'status':'Error','reason':'WorkerExit','message':'Worker exited without a result'}
            process.join(2)
            return result
        return {'status':'Unknown','reason':'Timeout','message':f'Wall-clock limit of {timeout} seconds reached'}
    finally:
        if process.is_alive():process.terminate();process.join(2)
        if process.is_alive():process.kill();process.join()
        receive.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json',action='store_true',help='Read one JSON request from standard input')
    parser.add_argument('--coefficients',help='High-to-low JSON array; quote rational coefficients')
    parser.add_argument('--index',type=int,default=0,help='Zero-based SymPy CRootOf index')
    parser.add_argument('--all',action='store_true',help='Solve an irreducible polynomial, all conjugates')
    parser.add_argument('--method',choices=['auto','general','structural'],default='auto')
    parser.add_argument('--timeout',type=float,default=120,help='Seconds; 0 disables the wall-clock limit')
    parser.add_argument('--max-field-degree',type=int,default=128,help='0 disables the degree cap')
    parser.add_argument('--max-candidates',type=int,default=1000000,help='0 disables the enumeration cap')
    parser.add_argument('--verify',action='store_true',help='Explicitly request verification (already the default)')
    parser.add_argument('--no-verify',action='store_true',help='Skip the independent certificate recheck, not construction checks')
    parser.add_argument('--verify-file',help='Recheck a saved positive or negative JSON result')
    parser.add_argument('--progress',action='store_true',help='Write stage reports to standard error')
    parser.add_argument('--output',help='Write JSON to this path rather than standard output')
    args=parser.parse_args()
    try:
        if args.json:request=json.load(sys.stdin)
        elif args.verify_file:
            request={'action':'verify','result':json.loads(Path(args.verify_file).read_text()),'timeout':args.timeout}
        else:
            if args.coefficients is None:parser.error('--coefficients, --json, or --verify-file is required')
            request={'coefficients':json.loads(args.coefficients),'index':args.index,
                     'action':'all' if args.all else 'root','method':args.method,
                     'timeout':args.timeout,'max_field_degree':args.max_field_degree,
                     'max_candidates':args.max_candidates,'verify':not args.no_verify,'progress':args.progress}
        if not isinstance(request,dict):raise ValueError('JSON request must be an object')
        result=run(request)
    except Exception as exc:
        result={'status':'Error','reason':type(exc).__name__,'message':str(exc)}
    text=json.dumps(result,indent=2,allow_nan=False)+'\n'
    if args.output:Path(args.output).write_text(text,encoding='utf-8')
    else:sys.stdout.write(text)
    return 2 if result.get('status')=='Error' else 0


if __name__=='__main__':
    mp.freeze_support()
    sys.exit(main())
