"""Non-evaluating rational input and radical expression DAG interchange."""
from __future__ import annotations
import re
import sympy as s
from .core import InvalidInput, radical_expression_q

INTEGER = re.compile(r'-?[0-9]+\Z')
def integer(text):
    if not isinstance(text,str) or not INTEGER.fullmatch(text):
        raise InvalidInput('An integer must be encoded as a signed decimal string.')
    return int(text)

def rational(pair):
    if not isinstance(pair,list) or len(pair)!=2:
        raise InvalidInput('A rational coefficient must be [numerator,denominator].')
    a,b = map(integer,pair)
    if b==0:
        raise InvalidInput('A rational denominator cannot be zero.')
    return s.Rational(a,b)

def encode_dag(expr):
    """Children precede parents. Repeated subexpressions appear only once."""
    nodes, memo = [],{}
    def put(e):
        if e in memo:
            return memo[e]
        if e.is_Rational:
            node = ['Q',str(e.p),str(e.q)]
        elif e==s.I:
            node = ['I']
        elif e.func in (s.Add,s.Mul):
            node = ['Add' if e.func==s.Add else 'Mul',*[put(a) for a in e.args]]
        elif e.func==s.Pow and e.exp.is_Rational:
            node = ['Pow',put(e.base),put(e.exp)]
        else:
            raise InvalidInput('Only rational arithmetic and rational powers can be encoded.')
        i=len(nodes);nodes.append(node);memo[e]=i
        return i
    root=put(expr)
    return {'nodes':nodes,'root':root,'format':'RadicalSolve-DAG-1'}

def decode_dag(data):
    if not isinstance(data,dict) or data.get('format')!='RadicalSolve-DAG-1':
        raise InvalidInput('Unknown radical DAG format.')
    out=[]
    for node in data['nodes']:
        if not isinstance(node,list) or not node:
            raise InvalidInput('Malformed DAG node.')
        tag=node[0]
        if tag=='Q' and len(node)==3:
            value=rational(node[1:])
        elif tag=='I' and len(node)==1:
            value=s.I
        else:
            if not all(type(i) is int and 0<=i<len(out) for i in node[1:]):
                raise InvalidInput('DAG references must point to earlier nodes.')
            args=[out[i] for i in node[1:]]
            if tag=='Add':value=s.Add(*args)
            elif tag=='Mul':value=s.Mul(*args)
            elif tag=='Pow' and len(args)==2 and args[1].is_Rational:
                value=s.Pow(*args)
            else:raise InvalidInput('Malformed operation in DAG.')
        if not radical_expression_q(value):
            raise InvalidInput('Decoded operation is undefined or is not a radical.')
        out.append(value)
    root=data['root']
    if type(root) is not int or not 0<=root<len(out):
        raise InvalidInput('Invalid root reference.')
    return out[root]
