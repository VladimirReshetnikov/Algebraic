"""Replay saved positive certificates without redoing the Galois search."""
from pathlib import Path
import json
import sys
from time import perf_counter
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python'))
from radical_roots import verify_certificate
import sympy as S
x=S.Symbol('x')
for path in sorted((ROOT/'validation/certificates').glob('*.json')):
    cert=json.loads(path.read_text())
    f=S.Poly(sum(S.Rational(v)*x**j for j,v in enumerate(cert['polynomial'])),x)
    t=perf_counter()
    assert verify_certificate(cert,expected_polynomial=f)
    print(path.name,': verified in',round(perf_counter()-t,3),'seconds')
