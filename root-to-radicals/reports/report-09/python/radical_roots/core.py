"""Exact splitting-field / Kummer reference implementation (characteristic zero).

Only SymPy is required.  This is deliberately a transparent reference algorithm,
not a competitor to optimized computational-number-theory implementations.
No fixed degree bound is imposed when Limits.max_field_degree is None.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from time import monotonic
from math import gcd
from functools import reduce
from typing import Callable, Iterable
import re
import sympy as S
from sympy.combinatorics import Permutation, PermutationGroup
from sympy.polys.polyerrors import CoercionFailed, IsomorphismFailed

def exact_rational(text):
    if not isinstance(text,str) or re.fullmatch(r'[+-]?\d+(?:/[1-9]\d*)?',text) is None:
        raise ValueError('Invalid exact rational string')
    return S.Rational(text)

X = S.Symbol('x')
Z = S.Symbol('z')

class RadicalError(Exception):
    """Base class: failure is not a proof of nonsolvability."""
class ResourceLimit(RadicalError):
    pass
class VerificationError(RadicalError):
    pass
class NotSolvable(RadicalError):
    def __init__(self, message, evidence=None):
        super().__init__(message)
        self.evidence = evidence or {}

@dataclass
class Limits:
    max_field_degree: int | None = 96
    seconds: float | None = None
    started: float = field(default_factory=monotonic)
    progress: Callable[[str], None] | None = None

    def check(self, stage: str, degree: int | None = None):
        if self.progress:
            self.progress(stage)
        if self.seconds is not None and monotonic()-self.started > self.seconds:
            raise ResourceLimit(f'Cooperative time limit reached: {stage}')
        if degree is not None and self.max_field_degree is not None:
            if degree > self.max_field_degree:
                raise ResourceLimit(f'Field degree {degree} exceeds {self.max_field_degree}: {stage}')

class LinearSpace:
    """Exact echelon basis; coordinates refer to the original inserted vectors."""
    def __init__(self, dimension: int):
        self.dimension = dimension
        self.rows = []  # pivot, normalized vector, original-basis coordinates
        self.size = 0

    def coordinates(self, vector):
        v = list(vector)
        ans = [S.S.Zero]*self.size
        for p, row, rep in self.rows:
            c = v[p]
            if c:
                v = [a-c*b for a,b in zip(v,row)]
                for j,b in enumerate(rep):
                    ans[j] += c*b
        return ans if not any(v) else None

    def add(self, vector):
        v = list(vector)
        rep = [S.S.Zero]*self.size + [S.S.One]
        for p,row,old in self.rows:
            c=v[p]
            if c:
                v=[a-c*b for a,b in zip(v,row)]
                for j,b in enumerate(old):
                    rep[j] -= c*b
        p=next((i for i,a in enumerate(v) if a),None)
        if p is None:
            return False
        c=v[p]
        self.rows.append((p,[a/c for a in v],[a/c for a in rep]))
        self.size += 1
        return True


def rational_poly(poly, variable=None):
    if isinstance(poly,S.Poly):
        if len(poly.gens)!=1:
            raise ValueError('A univariate rational polynomial is required.')
        f=S.Poly(poly.as_expr().subs(poly.gens[0],X),X,domain=S.QQ)
    else:
        variable=variable or X
        f=S.Poly(S.sympify(poly).subs(variable,X),X,domain=S.QQ)
    if f.degree()<1:
        raise ValueError('The polynomial must be nonconstant.')
    return f


def zeta(m: int):
    """e^(2*pi*i/m), written using a principal rational power of -1."""
    if m==1: return S.S.One
    return S.Pow(-1,S.Rational(2,m))


def rational_vector(K,a):
    n=K.mod.degree()
    c=[S.Rational(q) for q in a.to_list()][::-1]
    return c+[S.S.Zero]*(n-len(c))


def horner(K, coefficients, value):
    ans=K.zero
    for c in coefficients:
        ans=ans*value+K.convert(c)
    return ans


def minpoly_element(K,a):
    """Krylov linear-dependence algorithm, without symbolic resultants."""
    space=LinearSpace(K.mod.degree())
    power=K.one
    for k in range(K.mod.degree()+1):
        v=rational_vector(K,power)
        coords=space.coordinates(v)
        if coords is not None:
            return S.Poly(X**k-sum(c*X**j for j,c in enumerate(coords)),X,domain=S.QQ)
        if not space.add(v):
            raise VerificationError('Inconsistent Krylov dependence')
        power*=a
    raise VerificationError('No minimal-polynomial dependence')


def same_root_known(f,a,b):
    """Both a and b MUST already be known roots of the square-free f.

    SymPy's same_root uses a separation bound and bounded-error evaluation.
    This must never be used to establish polynomial annihilation.
    """
    f=f.sqf_part()
    if f.degree()==1:
        return True
    return bool(f.same_root(a,b))


def splitting_field(f, limits):
    rs=f.all_roots(radicals=True)
    if f.degree()==1:
        return None,rs
    # Exact binomial splitting-field shortcut. This does not synthesize the
    # requested output: the full automorphism/Kummer pipeline still runs.
    n=f.degree()
    if all(f.nth(j)==0 for j in range(1,n)):
        limits.check('binomial splitting field')
        root=S.Pow(-f.monic().nth(0),S.Rational(1,n))
        K=S.QQ.algebraic_field(root,zeta(n))
        limits.check('binomial splitting field constructed',K.mod.degree())
        candidates=[root*zeta(n)**j for j in range(n)]
        ordered=[next(a for a in candidates if same_root_known(f,a,r)) for r in rs]
        return K,ordered
    # For an irreducible cubic, adjoining sqrt(discriminant) to one root
    # gives the splitting field. This avoids an expensive compositum of two
    # independently isolated CRootOf objects; it is an exact field shortcut.
    if f.degree()==3:
        limits.check('cubic splitting field via discriminant')
        K=S.QQ.algebraic_field(rs[0],S.sqrt(f.discriminant()))
        limits.check('cubic splitting field',K.mod.degree())
        factors=S.Poly(f.as_expr(),X,domain=K).factor_list()[1]
        if any(q.degree()!=1 or e!=1 for q,e in factors):
            raise VerificationError('Cubic splitting construction failed')
        candidates=[]
        for q,_ in factors:
            c=q.rep.to_list(); candidates.append(K.to_sympy(-c[1]/c[0]))
        ordered=[]
        for r in rs:
            ordered.append(next(a for a in candidates if same_root_known(f,a,r)))
        return K,ordered
    K=None
    for j,r in enumerate(rs):
        limits.check(f'adjoin input conjugate {j+1}/{len(rs)}')
        if K is None:
            K=S.QQ.algebraic_field(r)
        else:
            try:
                K.from_sympy(r)
                continue
            except (CoercionFailed,IsomorphismFailed):
                K=S.QQ.algebraic_field(K.ext,r)
        limits.check('splitting field extension',K.mod.degree())
    # Membership is exact and is also the normality/completeness witness.
    for r in rs:
        K.from_sympy(r)
    return K,rs


def anchor_conjugate_candidates(K, max_candidates=4096):
    """Cheap over-approximation of conjugates from a primitive-element AST.

    Independent choices at repeated subexpressions may be inconsistent; this
    is harmless because callers filter by the exact primitive polynomial and
    use this path ONLY after obtaining all D distinct roots. A bounded failed
    attempt falls back to ordinary factorization of the primitive polynomial.
    """
    from itertools import product
    class TooLarge(Exception): pass
    cache={}
    def linear_roots(expr):
        f=S.Poly(expr,X,domain=K)
        ans=[]
        for q,_ in f.factor_list()[1]:
            if q.degree()==1:
                c=q.rep.to_list();ans.append(-c[1]/c[0])
        return ans
    def candidates(e):
        if e in cache:return cache[e]
        if isinstance(e,S.AlgebraicNumber):ans=candidates(e.as_expr())
        elif e.is_Rational:ans=[K.convert(e)]
        elif e==S.I:ans=linear_roots(X**2+1)
        elif isinstance(e,S.CRootOf):
            ans=linear_roots(e.poly.as_expr().subs(e.poly.gen,X))
        elif e.is_Add or e.is_Mul:
            children=[candidates(a) for a in e.args]
            if S.prod(len(c) for c in children)>max_candidates:raise TooLarge()
            if e.is_Add:ans=[sum(row,K.zero) for row in product(*children)]
            else:ans=[reduce(lambda a,b:a*b,row,K.one) for row in product(*children)]
        elif e.is_Pow and e.exp.is_Rational:
            num,den=int(e.exp.p),int(e.exp.q)
            if den>64:raise TooLarge()
            ans=[]
            for base in candidates(e.base):
                if not base and num<0:continue
                v=base**num
                ans.extend([v] if den==1 else linear_roots(X**den-K.to_sympy(v)))
                if len(ans)>max_candidates:raise TooLarge()
        else:raise TooLarge()
        ans=list(dict.fromkeys(ans))
        if len(ans)>max_candidates:raise TooLarge()
        cache[e]=ans
        return ans
    try:return candidates(K.ext.as_expr())
    except (TooLarge,CoercionFailed,IsomorphismFailed):return []


class Automorphisms:
    def __init__(self,K,root_values,z,limits):
        self.K=K
        self.D=K.mod.degree()
        self.theta=K.unit
        limits.check('enumerate primitive-element conjugates',self.D)
        phi=S.Poly(K.ext.minpoly.as_expr().subs(K.ext.minpoly.gen,X),X,domain=S.QQ)
        candidates=anchor_conjugate_candidates(K)
        images=list(dict.fromkeys(a for a in candidates if not horner(K,phi.all_coeffs(),a)))
        self.enumeration_method='anchor conjugates, checked complete'
        if len(images)!=self.D:
            limits.check('factor primitive polynomial over its own field',self.D)
            factors=S.Poly(phi.as_expr(),X,domain=K).factor_list()[1]
            if any(q.degree()!=1 or e!=1 for q,e in factors) or len(factors)!=self.D:
                raise VerificationError('The constructed field is not certified normal')
            images=[]
            for q,_ in factors:
                coeff=q.rep.to_list();images.append(-coeff[1]/coeff[0])
            self.enumeration_method='primitive polynomial factorization'
        self.images=images
        self.powers=[]
        for a in self.images:
            powers=[K.one]
            for _ in range(1,self.D):powers.append(powers[-1]*a)
            self.powers.append(powers)
        root_map={a:i for i,a in enumerate(root_values)}
        self.by_perm={}
        self.indices=[]
        for j in range(len(self.images)):
            if self.apply(j,z)!=z:continue
            key=tuple(root_map[self.apply(j,a)] for a in root_values)
            if key in self.by_perm:
                raise VerificationError('Root action is not faithful')
            self.by_perm[key]=j
            self.indices.append(j)
        self.G=PermutationGroup([Permutation(list(k)) for k in self.by_perm])
        if self.G.order()!=len(self.indices):
            raise VerificationError('Automorphism enumeration is not closed')

    def apply(self,j,a):
        coeff=a.to_list()[::-1]
        result=self.K.zero
        for c,power in zip(coeff,self.powers[j]):
            if c:result += self.K.convert(c)*power
        return result

    def index(self,g):
        key=tuple(g(i) for i in range(self.G.degree))
        return self.by_perm[key]


def normalize_generator(K,a):
    v=rational_vector(K,a)
    den=S.ilcm(*[q.q for q in v]) if len(v)>1 else v[0].q
    numer=[int(q*den) for q in v]
    content=reduce(gcd,(abs(c) for c in numer),0)
    first=next(c for c in numer if c)
    scalar=S.Rational(content,den)*(1 if first>0 else -1)
    return a/K.convert(scalar)


def choose_branch(K,b,p,zp):
    """Find k with b = zeta_p^k * principal_root(b^p,p).

    Polynomial annihilation is exact in K.  Only conjugate identification uses
    bounded-error evaluation plus a rational polynomial separation bound.
    """
    q=b**p
    qexpr=K.to_sympy(q)
    bexpr=K.to_sympy(b)
    hq=minpoly_element(K,q)
    h=S.Poly(hq.as_expr().subs(X,X**p),X,domain=S.QQ).sqf_part()
    principal=S.Pow(qexpr,S.Rational(1,p))
    # A numerical ordering is an optimization; every acceptance uses same_root.
    candidates=[zeta(p)**k*principal for k in range(p)]
    order=sorted(range(p),key=lambda k:abs(complex(S.N(candidates[k],25))-complex(S.N(bexpr,25))))
    for k in order:
        if same_root_known(h,candidates[k],bexpr):
            return k,h
    raise VerificationError('Unable to certify a radical branch')


@dataclass
class RadicalTower:
    polynomial: S.Poly
    m: int
    steps: list
    outputs: list
    metadata: dict
    certificate: dict

    def expressions(self):
        env={Z:zeta(self.m)}
        for step in self.steps:
            q=step['radicand'].xreplace(env)
            env[step['symbol']]=zeta(step['prime'])**step['branch']*S.Pow(q,S.Rational(1,step['prime']))
        return [e.xreplace(env) for e in self.outputs]

    def expression(self,index=0):
        return self.expressions()[index]

    def verify(self):
        c=self.certificate
        if c.get('kind')=='linear':
            if self.m!=1 or self.steps or len(self.outputs)!=1 or expression_ast(self.outputs[0])!=c['root']:
                raise VerificationError('Tower object differs from its linear certificate')
        else:
            if self.m!=c['m'] or [expression_ast(e) for e in self.outputs]!=c['outputs']:
                raise VerificationError('Tower outputs differ from the certificate')
            if len(self.steps)!=len(c['steps']):
                raise VerificationError('Tower step count differs from the certificate')
            for a,b in zip(self.steps,c['steps']):
                if (str(a['symbol'])!=b['symbol'] or a['prime']!=b['prime'] or
                    a['branch']!=b['branch'] or expression_ast(a['radicand'])!=b['radicand']):
                    raise VerificationError('Tower definition differs from the certificate')
        return verify_certificate(c,expected_polynomial=self.polynomial)


def build_tower(poly, *, limits=None, precheck=True):
    """Construct a radical tower for every root of an irreducible polynomial.

    On unlimited exact arithmetic this algorithm terminates, returning a tower
    iff the polynomial is solvable.  Resource failures are not NotSolvable.
    """
    limits=limits or Limits()
    f=rational_poly(poly).monic()
    if not f.is_irreducible:
        raise ValueError('build_tower expects an irreducible polynomial; use solve_polynomial for reducible input')
    n=f.degree()
    if n==1:
        r=-f.nth(0)
        return RadicalTower(f,1,[],[r],{'method':'linear'},
            {'version':2,'kind':'linear','polynomial':[str(f.nth(0)),'1'],
             'root':expression_ast(r)})
    if precheck and n<=6:
        # This optimization has a degree bound; the main algorithm does not.
        try:
            G,_=S.galois_group(f)
        except Exception as exc:
            # Failure to classify is not a mathematical negative answer.
            limits.check('small-degree Galois precheck unavailable: '+type(exc).__name__)
        else:
            if not G.is_solvable:
                ds=G.derived_series()
                raise NotSolvable('Nonsolvable Galois group',{
                    'source':'SymPy exact small-degree Galois algorithm',
                    'order':int(G.order()),'derived_orders':[int(g.order()) for g in ds]})
    K,roots=splitting_field(f,limits)
    splitting_degree=K.mod.degree()
    m=int(S.prod(S.factorint(splitting_degree).keys()))
    ze=zeta(m)
    try:z=K.from_sympy(ze)
    except (CoercionFailed,IsomorphismFailed):
        limits.check('adjoin required roots of unity')
        K=S.QQ.algebraic_field(K.ext,ze)
        z=K.from_sympy(ze)
    D=K.mod.degree()
    limits.check('cyclotomic compositum',D)
    alpha=[K.from_sympy(r) for r in roots]
    autos=Automorphisms(K,alpha,z,limits)
    G=autos.G
    if int(G.order())*int(S.totient(m))!=D:
        raise VerificationError('Incorrect cyclotomic fixed-field degree')
    if not G.is_solvable:
        raise NotSolvable('Nonsolvable Galois group over the cyclotomic base',{
            'source':'exact splitting-field automorphisms',
            'order':int(G.order()),
            'derived_orders':[int(g.order()) for g in G.derived_series()]})
    chain=G.composition_series()
    basis=[z**j for j in range(int(S.totient(m)))]
    monomials=[Z**j for j in range(len(basis))]
    space=LinearSpace(D)
    for a in basis:
        if not space.add(rational_vector(K,a)):
            raise VerificationError('Dependent cyclotomic basis')
    steps=[]; cert_steps=[]
    theta_powers=[K.one]
    for _ in range(1,D):theta_powers.append(theta_powers[-1]*K.unit)
    for i,(H,N) in enumerate(zip(chain,chain[1:]),1):
        p=int(H.order()//N.order())
        if not S.isprime(p) or not N.is_normal(H):
            raise VerificationError('Composition series is not cyclic-prime')
        sigma=next(g for g in H.generate_schreier_sims() if not N.contains(g))
        sj=autos.index(sigma)
        nidx=[autos.index(g) for g in N.generate_schreier_sims()]
        zp=z**(m//p)
        limits.check(f'Kummer step {i}: index {p}',D)
        b=None
        for power in theta_powers:
            trace=sum((autos.apply(j,power) for j in nidx),K.zero)
            term=trace
            r=K.zero
            for k in range(p):
                r += zp**(-k)*term
                term=autos.apply(sj,term)
            if r:
                b=normalize_generator(K,r)
                break
        if b is None:
            raise VerificationError('All eigenprojectors vanished on a spanning set')
        if autos.apply(sj,b)!=zp*b or any(autos.apply(j,b)!=b for j in nidx):
            raise VerificationError('Kummer eigenvector identity failed')
        q=b**p
        coords=space.coordinates(rational_vector(K,q))
        if coords is None:
            raise VerificationError('Radicand did not descend into preceding field')
        radicand=S.Add(*(c*mon for c,mon in zip(coords,monomials)))
        branch,h=choose_branch(K,b,p,zp)
        symbol=S.Symbol(f'r{i}')
        steps.append({'symbol':symbol,'prime':p,'branch':branch,'radicand':radicand})
        cert_steps.append({'symbol':str(symbol),'prime':p,'branch':branch,
                           'radicand':expression_ast(radicand),
                           'value':[str(c) for c in rational_vector(K,b)]})
        old_basis=list(basis);old_monomials=list(monomials)
        for j in range(1,p):
            for a,mon in zip(old_basis,old_monomials):
                new=a*b**j
                if not space.add(rational_vector(K,new)):
                    raise VerificationError('Kummer basis extension is dependent')
                basis.append(new);monomials.append(mon*symbol**j)
    if len(basis)!=D:
        raise VerificationError('Tower does not span the splitting compositum')
    outputs=[]
    for a in alpha:
        coords=space.coordinates(rational_vector(K,a))
        if coords is None:raise VerificationError('Target is outside the constructed basis')
        outputs.append(S.Add(*(c*mon for c,mon in zip(coords,monomials))))
    # Keep an exact algebraic anchor, rather than isolating a new degree-D
    # CRootOf for the primitive element. The anchor is certificate-only and is
    # never returned as part of a radical expression.
    limits.check('record exact primitive-element embedding')
    phi=S.Poly(K.ext.minpoly.as_expr().subs(K.ext.minpoly.gen,X),X,domain=S.QQ)
    primitive_expr=K.ext.as_expr()
    cert={'version':2,'polynomial':[str(f.nth(i)) for i in range(n+1)],
          'primitive_polynomial':[str(phi.nth(i)) for i in range(D+1)],
          'primitive_anchor':algebraic_ast(primitive_expr),'m':m,
          'zeta_value':[str(c) for c in rational_vector(K,z)],
          'steps':cert_steps,'outputs':[expression_ast(e) for e in outputs],
          'target_values':[[str(c) for c in rational_vector(K,a)] for a in alpha]}
    metadata={'method':'Galois-Kummer','automorphism_enumeration':autos.enumeration_method,
              'splitting_degree':splitting_degree,
              'field_degree':D,'cyclotomic_order':m,'relative_group_order':int(G.order()),
              'chain_orders':[int(H.order()) for H in chain],
              'branch_indices':[s['branch'] for s in steps]}
    return RadicalTower(f,m,steps,outputs,metadata,cert)


def expression_ast(e):
    """Portable, non-executable whitelist AST. No strings are evaluated as code."""
    e=S.sympify(e)
    if e.is_Rational:return ['Q',str(e.p),str(e.q)]
    if e==S.I:return ['P',['Q','-1','1'],['Q','1','2']]
    if e.is_Symbol:return ['S',str(e)]
    if e.is_Add:return ['A',*[expression_ast(a) for a in e.args]]
    if e.is_Mul:return ['M',*[expression_ast(a) for a in e.args]]
    if e.is_Pow and e.exp.is_Rational:
        return ['P',expression_ast(e.base),expression_ast(e.exp)]
    raise ValueError('Not in the radical grammar: '+str(e))


def from_ast(a,symbols=None):
    symbols=symbols or {}
    if not isinstance(a,list) or not a:raise ValueError('Invalid expression AST')
    tag=a[0]
    if tag=='Q' and len(a)==3:
        if any(not isinstance(v,str) or re.fullmatch(r'[+-]?\d+',v) is None for v in a[1:]):
            raise ValueError('Rational AST leaves must be decimal integer strings')
        n,d=int(a[1]),int(a[2])
        if d<=0:raise ValueError('Rational denominator must be positive')
        return S.Rational(n,d)
    if tag=='S' and len(a)==2 and a[1] in symbols:return symbols[a[1]]
    if tag in ('A','M'):
        return (S.Add if tag=='A' else S.Mul)(*(from_ast(v,symbols) for v in a[1:]))
    if tag=='P' and len(a)==3:
        b=from_ast(a[1],symbols); e=from_ast(a[2],symbols)
        if not e.is_Rational:raise ValueError('Nonrational exponent')
        return S.Pow(b,e)
    raise ValueError('Invalid expression AST tag or unknown symbol')


def field_ast(a,K,env):
    tag=a[0]
    if tag=='Q':return K.convert(S.Rational(int(a[1]),int(a[2])))
    if tag=='S':return env[a[1]]
    if tag=='A':return sum((field_ast(v,K,env) for v in a[1:]),K.zero)
    if tag=='M':return reduce(lambda u,v:u*v,(field_ast(v,K,env) for v in a[1:]),K.one)
    if tag=='P':
        exponent=from_ast(a[2])
        if not exponent.is_Integer:raise VerificationError('Certificate polynomials must have integral powers')
        return field_ast(a[1],K,env)**int(exponent)
    raise VerificationError('Unknown certificate AST operation')


def verify_certificate(cert, *, expected_polynomial=None):
    """Rebuild rational quotient arithmetic; recheck every branch and target.

    The verifier does not recompute the Galois group or trust the search log.
    Exact irreducibility/field operations and SymPy root-separation tests form
    its trusted computational base. Certificates are not formal Lean proofs.
    """
    if not isinstance(cert,dict) or not cert:
        raise VerificationError('Missing certificate')
    if cert.get('version')!=2:raise VerificationError('Unsupported certificate version')
    def pol(c):return S.Poly(sum(exact_rational(v)*X**i for i,v in enumerate(c)),X,domain=S.QQ)
    f=pol(cert['polynomial'])
    if expected_polynomial is not None and f.monic()!=rational_poly(expected_polynomial).monic():
        raise VerificationError('Certificate belongs to a different input polynomial')
    if cert.get('kind')=='linear':
        r=from_ast(cert['root'])
        if f.degree()!=1 or not r.is_Rational or f.eval(r)!=0:
            raise VerificationError('Invalid linear certificate')
        return True
    phi=pol(cert['primitive_polynomial'])
    if not phi.is_irreducible:raise VerificationError('Reducible primitive polynomial')
    theta=from_algebraic_ast(cert['primitive_anchor'])
    K=S.QQ.algebraic_field(theta)
    actual=S.Poly(K.ext.minpoly.as_expr().subs(K.ext.minpoly.gen,X),X,domain=S.QQ).monic()
    if actual!=phi.monic():raise VerificationError('Anchor does not match primitive polynomial')
    def val(v):return horner(K,[exact_rational(a) for a in v[::-1]],K.unit)
    z=val(cert['zeta_value']);m=int(cert['m'])
    cp=S.Poly(S.cyclotomic_poly(m,X),X)
    if horner(K,cp.all_coeffs(),z):raise VerificationError('Invalid cyclotomic value')
    if not same_root_known(cp,K.to_sympy(z),zeta(m)):
        raise VerificationError('Wrong cyclotomic branch')
    env={'z':z}
    for step in cert['steps']:
        p=int(step['prime']);k=int(step['branch'])
        if p<2 or not 0<=k<p:raise VerificationError('Invalid radical exponent or branch')
        b=val(step['value']);q=field_ast(step['radicand'],K,env)
        if b**p!=q:raise VerificationError('Radicand identity failed')
        actual,_=choose_branch(K,b,p,z**(m//p))
        if actual!=k:raise VerificationError('Incorrect radical branch')
        if step['symbol'] in env:raise VerificationError('Duplicate tower symbol')
        env[step['symbol']]=b
    roots=f.all_roots(radicals=True)
    if len(cert['outputs'])!=f.degree() or len(cert['target_values'])!=f.degree():
        raise VerificationError('Wrong number of targets')
    for i,(out,stored) in enumerate(zip(cert['outputs'],cert['target_values'])):
        a=field_ast(out,K,env)
        if a!=val(stored):raise VerificationError('Output reconstruction failed')
        if horner(K,f.all_coeffs(),a):raise VerificationError('Output does not annihilate polynomial')
        if not same_root_known(f,K.to_sympy(a),roots[i]):raise VerificationError('Incorrect target conjugate')
    return True


def algebraic_ast(e):
    """Certificate-only extension of the whitelist grammar by isolated roots."""
    if isinstance(e,S.AlgebraicNumber):return algebraic_ast(e.as_expr())
    if isinstance(e,S.CRootOf):
        q=e.poly
        return ['Root',[str(q.nth(j)) for j in range(q.degree()+1)],int(e.index)]
    if e.is_Add:return ['A',*[algebraic_ast(a) for a in e.args]]
    if e.is_Mul:return ['M',*[algebraic_ast(a) for a in e.args]]
    if e.is_Pow and e.exp.is_Rational:return ['P',algebraic_ast(e.base),expression_ast(e.exp)]
    return expression_ast(e)


def from_algebraic_ast(a):
    if a[0]=='Root':
        q=S.Poly(sum(exact_rational(v)*X**j for j,v in enumerate(a[1])),X,domain=S.QQ)
        return S.CRootOf(q,int(a[2]))
    if a[0] in ('A','M'):
        return (S.Add if a[0]=='A' else S.Mul)(*(from_algebraic_ast(v) for v in a[1:]))
    if a[0]=='P':return S.Pow(from_algebraic_ast(a[1]),from_ast(a[2]))
    return from_ast(a)
