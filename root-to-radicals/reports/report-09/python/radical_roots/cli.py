"""JSON-only bridge and process-isolated command-line entry point.

Run: python path/to/radical_roots/cli.py < request.json
No Python/Wolfram source received from the caller is evaluated.
"""
from __future__ import annotations
import json
import math
from pathlib import Path
import re
import subprocess
import sys

# Also support direct execution from an unpacked distribution.
if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

RATIONAL = re.compile(r'[+-]?\d+(?:/[1-9]\d*)?\Z')


def error(status, message, **extra):
    return {'status': status, 'message': str(message), **extra}


def worker(request):
    import sympy as S
    from radical_roots import (solve_polynomial, solve_root, Limits, NotSolvable,
                              ResourceLimit, RadicalError, VerificationError,
                              expression_ast)
    x = S.Symbol('x')
    try:
        raw = request['coefficients']
        if not isinstance(raw, list) or len(raw) < 2:
            raise ValueError('coefficients must be an ascending list of exact rationals')
        if any(not isinstance(v, str) or not RATIONAL.fullmatch(v) for v in raw):
            raise ValueError('Coefficients must be integer or rational strings, e.g. "-3/5"')
        coeff = [S.Rational(v) for v in raw]
        if coeff[-1] == 0:
            raise ValueError('Leading coefficient must be nonzero')
        f = S.Poly(sum(c*x**j for j,c in enumerate(coeff)), x, domain=S.QQ)
        bound = request.get('max_field_degree', 96)
        if bound is not None and (isinstance(bound, bool) or not isinstance(bound, int) or bound < 1):
            raise ValueError('max_field_degree must be a positive integer or null')
        limits = Limits(max_field_degree=bound, seconds=request.get('seconds', 300))
        options = dict(method=request.get('method', 'auto'), limits=limits,
                       pair_sum_max_degree=int(request.get('pair_sum_max_degree', 10)),
                       max_extension_degree=int(request.get('max_extension_degree', 6)))
        if 'root_index' in request:
            sol = solve_root(f, request['root_index'], **options)
        else:
            sol = solve_polynomial(f, **options)
        verified = 'exact identities plus separation-certified root matching'
        if sol.tower is not None:
            if request.get('verify', True):
                sol.tower.verify()
                verified = 'radical tower certificate replayed'
            else:
                verified = 'construction checks; separate replay skipped'
        out = {'status': 'Success', 'expressions': [expression_ast(e) for e in sol.expressions],
               'metadata': sol.metadata, 'verification': verified,
               'ordering': 'SymPy real-first canonical order (zero based; not WL complex-root order)',
               'sympy_version': S.__version__}
        if sol.tower is not None:
            t = sol.tower
            out['tower'] = {'cyclotomic_order': t.m,
                'steps': [{'symbol': str(s['symbol']), 'prime': s['prime'],
                           'branch': s['branch'], 'radicand': expression_ast(s['radicand'])}
                          for s in t.steps],
                'outputs': [expression_ast(e) for e in t.outputs]}
            out['certificate'] = t.certificate
        return out
    except NotSolvable as exc:
        return error('NotSolvable', exc, evidence=exc.evidence)
    except ResourceLimit as exc:
        return error('ResourceLimit', exc)
    except VerificationError as exc:
        return error('VerificationFailure', exc)
    except RadicalError as exc:
        return error('SearchExhausted', exc)
    except (ValueError, KeyError, TypeError) as exc:
        return error('InvalidInput', exc)
    except Exception as exc:
        return error('BackendError', exc, exception=type(exc).__name__)


def main():
    try:
        raw = sys.stdin.read()
        request = json.loads(raw)
        if not isinstance(request, dict):
            raise ValueError('The request must be a JSON object')
        seconds = request.get('seconds', 300)
        if seconds is not None and (isinstance(seconds, bool) or not isinstance(seconds, (int,float))
                                    or not math.isfinite(seconds) or seconds <= 0):
            raise ValueError('seconds must be positive and finite, or null for no time limit')
        if '--worker' in sys.argv[1:]:
            response = worker(request)
        else:
            # The expensive algebra happens in another process. A factorization
            # that never returns cannot bypass this parent wall-clock limit.
            try:
                done = subprocess.run([sys.executable, str(Path(__file__).resolve()), '--worker'],
                    input=raw, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    timeout=seconds, check=False)
                try:
                    response = json.loads(done.stdout)
                    if not isinstance(response, dict) or 'status' not in response:
                        raise ValueError('Missing worker status')
                except (ValueError, json.JSONDecodeError):
                    response = error('BackendError', 'Worker did not return a valid response',
                                     exit_code=done.returncode, stderr=done.stderr[-6000:])
            except subprocess.TimeoutExpired:
                response = error('ResourceLimit', 'Hard wall-clock limit reached; worker terminated')
    except ImportError as exc:
        response = error('DependencyFailure', 'Cannot import the Python backend dependency: '+str(exc), exception=type(exc).__name__)
    except Exception as exc:
        response = error('InvalidInput', exc, exception=type(exc).__name__)
    sys.stdout.write(json.dumps(response, ensure_ascii=True, separators=(',', ':')) + '\n')
    return 0 if response.get('status') == 'Success' else 2


if __name__ == '__main__':
    raise SystemExit(main())
