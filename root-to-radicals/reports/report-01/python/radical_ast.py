"""A whitelist-only radical expression tree, with sequential definitions.

Powers mean principal complex rational powers.  RootOf, trigonometric
functions, algebraic placeholders and arbitrary executable strings are not
part of this grammar.
"""
import sympy as s

def rat(a):
    a=s.Rational(a);return ['q',int(a.p),int(a.q)]
def ref(name): return ['ref',name]
def isq(a,v=None): return a[0]=='q' and (v is None or s.Rational(a[1],a[2])==v)
def add(*args):
    terms=[];c=s.S.Zero
    for a in args:
        aa=a[1:] if a[0]=='add' else [a]
        for b in aa:
            if isq(b):c+=s.Rational(b[1],b[2])
            else:terms.append(b)
    if c:terms.insert(0,rat(c))
    return rat(0) if not terms else terms[0] if len(terms)==1 else ['add',*terms]
def mul(*args):
    terms=[];c=s.S.One
    for a in args:
        aa=a[1:] if a[0]=='mul' else [a]
        for b in aa:
            if isq(b):c*=s.Rational(b[1],b[2])
            else:terms.append(b)
    if c==0:return rat(0)
    if c!=1:terms.insert(0,rat(c))
    return rat(1) if not terms else terms[0] if len(terms)==1 else ['mul',*terms]
def power(a,p,q=1):
    e=s.Rational(p,q)
    if e==0:return rat(1)
    if e==1:return a
    if isq(a) and e.q==1:return rat(s.Rational(a[1],a[2])**e)
    return ['pow',a,int(e.p),int(e.q)]
def linear(cs,basis):return add(*[mul(rat(c),a) for c,a in zip(cs,basis) if c])
def sympy_expr(a,env=None):
    env={} if env is None else env
    op=a[0]
    if op=='q':return s.Rational(a[1],a[2])
    if op=='ref':return env.get(a[1],s.Symbol(a[1]))
    if op=='add':return s.Add(*(sympy_expr(b,env) for b in a[1:]))
    if op=='mul':return s.Mul(*(sympy_expr(b,env) for b in a[1:]))
    if op=='pow':return s.Pow(sympy_expr(a[1],env),s.Rational(a[2],a[3]),evaluate=False)
    raise ValueError('Unknown radical AST operation')
def numeric(a,env=None,digits=40):
    import mpmath as mp
    env={} if env is None else env
    with mp.workdps(digits):
        op=a[0]
        if op=='q':return mp.mpf(a[1])/a[2]
        if op=='ref':return env[a[1]]
        if op=='add':return sum((numeric(b,env,digits) for b in a[1:]),mp.mpf(0))
        if op=='mul':return mp.fprod(numeric(b,env,digits) for b in a[1:])
        if op=='pow':return mp.power(numeric(a[1],env,digits),mp.mpf(a[2])/a[3])
    raise ValueError('Unknown radical AST operation')
def field_eval(a,F,env):
    op=a[0]
    if op=='q':return F.rational(s.Rational(a[1],a[2]))
    if op=='ref':return env[a[1]]
    if op=='add':return sum((field_eval(b,F,env) for b in a[1:]),F.zero)
    if op=='mul':
        v=F.one
        for b in a[1:]:v*=field_eval(b,F,env)
        return v
    if op=='pow' and a[3]==1:return field_eval(a[1],F,env)**a[2]
    raise ValueError('Expected rational operations and integer powers only')

def from_sympy(expr):
    """Convert only arithmetic radicals; reject every other symbolic head."""
    expr=s.sympify(expr)
    if expr.is_Rational:return rat(expr)
    if expr==s.I:return power(rat(-1),1,2)
    if expr.is_Add:return add(*(from_sympy(a) for a in expr.args))
    if expr.is_Mul:return mul(*(from_sympy(a) for a in expr.args))
    if expr.is_Pow and expr.exp.is_Rational:
        return power(from_sympy(expr.base),int(expr.exp.p),int(expr.exp.q))
    raise ValueError('Expression is not an arithmetic radical: '+str(expr))

def validate(tree, allowed_refs=()):
    """Strict JSON grammar validation; no Python or Wolfram code is evaluated."""
    if not isinstance(tree,list) or not tree or not isinstance(tree[0],str):
        raise ValueError('Invalid expression node')
    op=tree[0]
    integer=lambda v:isinstance(v,int) and not isinstance(v,bool)
    if op=='q':
        if len(tree)!=3 or not all(integer(v) for v in tree[1:]) or tree[2]<=0:
            raise ValueError('Invalid rational literal')
    elif op=='ref':
        if len(tree)!=2 or not isinstance(tree[1],str) or tree[1] not in allowed_refs:
            raise ValueError('Invalid or forward reference')
    elif op in ('add','mul'):
        for node in tree[1:]:validate(node,allowed_refs)
    elif op=='pow':
        if len(tree)!=4 or not integer(tree[2]) or not integer(tree[3]) or tree[3]<=0:
            raise ValueError('Invalid power')
        validate(tree[1],allowed_refs)
    else:raise ValueError('Unknown expression operation')
    return True

def expanded_expressions(result):
    """Return exact SymPy expressions; expansion can be much larger than the DAG."""
    env={}
    for definition in result.get('definitions',[]):
        name=definition['name']
        if not isinstance(name,str) or name in env:raise ValueError('Duplicate definition')
        validate(definition['expression'],env)
        env[name]=sympy_expr(definition['expression'],env)
    out=[]
    for root in result['roots']:
        validate(root['expression'],env)
        out.append(sympy_expr(root['expression'],env))
    return out
