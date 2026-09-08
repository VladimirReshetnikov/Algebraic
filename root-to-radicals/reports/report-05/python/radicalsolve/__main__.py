"""JSON stdin/stdout command protocol; never evals input code."""
import json,sys,time,traceback
import sympy as s
from .core import Solver,RadicalError,InvalidInput,X,verify
from .codec import rational,encode_dag
from . import __version__

def main():
    started=time.monotonic()
    try:
        data=json.load(sys.stdin)
        if not isinstance(data,dict):raise InvalidInput('A JSON object is required.')
        coeff=data.get('coefficients')
        if not isinstance(coeff,list) or len(coeff)<2:raise InvalidInput('Nonconstant coefficients required.')
        cc=[rational(c) for c in coeff]
        if cc[0]==0:raise InvalidInput('Leading coefficient cannot be zero.')
        p=s.Poly.from_list(cc,X,domain=s.QQ)
        solver=Solver(method=data.get('method','auto'),
                      max_field_degree=data.get('max_field_degree',96),
                      max_seconds=data.get('max_seconds'))
        if data.get('action','all')=='root':
            rr=[solver.root(p,data.get('index',0))]
        elif data.get('action','all')=='all':
            rr=solver.all_roots(p)
        else:raise InvalidInput('Action must be root or all.')
        roots=[]
        for r in rr:
            entry={'dag':encode_dag(r.expression),'method':r.method,'record':r.record}
            if data.get('verify',False):
                entry['independently_verified']=verify(p,r.expression)
            roots.append(entry)
        result={'status':'Success','roots':roots,'events':solver.events}
        exitcode=0
    except RadicalError as exc:
        result={'status':exc.status,'message':str(exc),'details':exc.details};exitcode=2
    except (ValueError,TypeError,KeyError,json.JSONDecodeError) as exc:
        result={'status':'InvalidInput','message':str(exc)};exitcode=2
    except Exception as exc:
        # Never relabel a backend exception as mathematical nonsolvability.
        result={'status':'BackendError','message':str(exc),'exception':type(exc).__name__};exitcode=3
        traceback.print_exc(file=sys.stderr)
    result.update(version=__version__,sympy_version=s.__version__,elapsed_seconds=time.monotonic()-started)
    json.dump(result,sys.stdout,separators=(',',':'));sys.stdout.write('\n')
    return exitcode

if __name__=='__main__':sys.exit(main())
