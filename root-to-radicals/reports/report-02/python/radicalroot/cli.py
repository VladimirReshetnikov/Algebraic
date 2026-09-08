"""Command-line front end with a hard whole-worker time limit and no eval parser."""
from __future__ import annotations
import argparse
from fractions import Fraction
import json
import multiprocessing as mp
import sys
import sympy as s
from .core import radicalize


def _worker(conn, coeff, index, method, degree, order, pair_limit):
    try:
        x=s.Symbol('x')
        p=s.Poly.from_list([s.Rational(a,b) for a,b in coeff],x)
        r=radicalize(p,index,method=method,max_field_degree=degree,
                     max_group_order=order,pair_limit=pair_limit)
        conn.send(dict(status=r.status,method=r.method,message=r.message,
                       target=str(r.target),expression=None if r.expression is None else str(r.expression),
                       certificate=r.certificate))
    except BaseException as exc:
        conn.send(dict(status='backend_failure',message=f'{type(exc).__name__}: {exc}'))
    finally:
        conn.close()


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--coefficients',required=True,help='Descending rational coefficients, comma separated')
    parser.add_argument('--index',type=int,default=0,help='ZERO-based SymPy CRootOf index')
    parser.add_argument('--method',choices=['auto','fast','galois'],default='auto')
    parser.add_argument('--timeout',type=float,default=120,help='Seconds; 0 disables the time limit')
    parser.add_argument('--max-field-degree',type=int,default=48,help='0 disables the degree limit')
    parser.add_argument('--max-group-order',type=int,default=96,help='0 disables the order limit')
    parser.add_argument('--pair-limit',type=int,default=8)
    args=parser.parse_args(argv)
    if args.timeout<0 or args.max_field_degree<0 or args.max_group_order<0 or args.pair_limit<0:
        parser.error('Limits must be nonnegative')
    try:
        cf=[Fraction(a.strip()) for a in args.coefficients.split(',')]
        if len(cf)<2 or cf[0]==0:
            raise ValueError('At least two coefficients and a nonzero leading coefficient are required')
        coeff=[(c.numerator,c.denominator) for c in cf]
    except (ValueError,ZeroDivisionError) as exc:
        parser.error(str(exc))
    ctx=mp.get_context('spawn'); parent, child=ctx.Pipe(duplex=False)
    proc=ctx.Process(target=_worker,args=(child,coeff,args.index,args.method,
        args.max_field_degree or None,args.max_group_order or None,args.pair_limit))
    proc.start(); child.close()
    try:
        if parent.poll(args.timeout or None):
            try: result=parent.recv()
            except EOFError: result={'status':'backend_failure','message':'Worker exited without a result'}
        else:
            result={'status':'resource_limit','message':'Whole-worker time limit exceeded; solvability is unknown'}
            proc.terminate()
    except KeyboardInterrupt:
        proc.terminate(); result={'status':'resource_limit','message':'Interrupted by user'}
    finally:
        parent.close(); proc.join(2)
        if proc.is_alive():proc.kill();proc.join()
    print(json.dumps(result,indent=2,default=str))
    return 0 if result['status']=='success' else 2
