"""A verified exact field model can bypass automatic splitting-field discovery."""
import pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'python'))
import sympy as s
from galois_core import GaloisModel,radicals_from_model,embed_exact
K=s.QQ.algebraic_field(s.sqrt(2),s.sqrt(3))
model=GaloisModel.from_field(K,conductor=2)
value=embed_exact(K,s.sqrt(2)-s.sqrt(3))
expression,details=radicals_from_model(model,value)
print(expression)
print(details)
