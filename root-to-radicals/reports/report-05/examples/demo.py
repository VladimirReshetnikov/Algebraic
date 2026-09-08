#!/usr/bin/env python3
"""Reproduce the original examples and a forced general cyclic-quintic run.

Run from any directory. --json PATH also writes the radical DAGs and audit data.
The cyclic-quintic numerical residual is a regression check, not a proof.
"""
from __future__ import annotations
import argparse
import json
import platform
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python'))
import sympy as s
from radicalsolve import Solver, radicalize, verify
from radicalsolve.codec import encode_dag


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', type=Path, help='write reproducible result data')
    args = parser.parse_args()
    x = s.Symbol('x')
    examples = [
        ('Original sextic, positive real root', x**6+x**4-x**3-x**2-1, 1),
        ('Original quintic, largest real root', 5*x**5-25*x**3+25*x+6, 4),
    ]
    report = {'python': platform.python_version(), 'sympy': s.__version__, 'examples': []}
    for name, f, index in examples:
        start = time.monotonic()
        r = radicalize(f, index=index)
        checked = verify(f, r.expression, index=index)
        assert checked
        print(name)
        print('  method:', r.method)
        print('  expression:', r.expression)
        print('  value:', s.N(r.expression, 25))
        print('  independently verified:', checked)
        report['examples'].append({
            'name': name, 'polynomial': str(f), 'sympy_index': index,
            'method': r.method, 'dag': encode_dag(r.expression),
            'expression': str(r.expression), 'wolfram': r.wolfram(),
            'independently_verified': checked, 'record': r.record,
            'elapsed_seconds': time.monotonic()-start,
        })

    # Short hand-derived forms for the very same embeddings.
    u = ((9+s.sqrt(849))/18)**s.Rational(1, 3)
    y = u-4/(3*u)
    v = ((-3+4*s.I)/5)**s.Rational(1, 5)
    compact = [(y+s.sqrt(y*y+4))/2, v+1/v]
    for (_, f, index), value in zip(examples, compact):
        assert verify(f, value, index=index)
    report['compact_formulas'] = [str(e) for e in compact]
    report['compact_formulas_independently_verified'] = True

    f = x**5+x**4-4*x**3-3*x**2+3*x+1
    solver = Solver(method='galois', max_field_degree=96)
    start = time.monotonic()
    roots = solver.all_roots(f)
    elapsed = time.monotonic()-start
    residuals = [abs(complex(s.N(f.subs(x, r.expression), 35))) for r in roots]
    assert len(roots) == 5 and max(residuals) < 1e-25
    print('Forced general cyclic-quintic method')
    print('  number of radical expressions:', len(roots))
    print('  maximum high-precision residual:', max(residuals))
    print('  group construction:', solver.events)
    print('  independent final minimal-polynomial reconstruction: not run')
    report['general_cyclic_quintic'] = {
        'polynomial': str(f), 'events': solver.events, 'elapsed_seconds': elapsed,
        'residuals': residuals,
        'verification_note': 'Internal exact invariants and separation-based branch checks; '
                             'additional numerical residuals. No independent final '
                             'minimal-polynomial reconstruction in this demonstration.',
        'roots': [{'dag': encode_dag(r.expression), 'record': r.record,
                   'method': r.method, 'expression': str(r.expression),
                   'wolfram': r.wolfram()} for r in roots],
    }
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
        print('Wrote:', args.json)


if __name__ == '__main__':
    main()
