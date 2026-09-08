"""Exact absolute fields and abstract root adjunction (SymPy 1.14).

No numerical root recognition is used to construct composita.  A primitive
power basis is found by rational linear algebra in K[b]/(g(b)).
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional
import sympy as s
from sympy.polys.polyerrors import NotInvertible

class ResourceLimit(RuntimeError):
    pass


def q(x):
    return s.Rational(x.numerator, x.denominator) if hasattr(x, 'numerator') else s.Rational(x)

@dataclass
class ExactField:
    poly: s.Poly
    domain: object

    @classmethod
    def from_poly(cls, p):
        p=s.Poly(p).monic()
        # Use a fresh generator: substitutions must not enter a RootOf's bound variable.
        t=s.Dummy('theta')
        p=s.Poly.from_list(p.all_coeffs(), t, domain=s.QQ)
        theta=s.CRootOf(p, 0)
        K=s.QQ.algebraic_field((p,theta))
        return cls(p,K)

    @property
    def degree(self): return self.poly.degree()
    @property
    def zero(self): return self.domain.zero
    @property
    def one(self): return self.domain.one
    @property
    def theta(self): return self.domain.unit
    @property
    def embedding(self): return self.domain.ext.root
    def rational(self,c): return self.domain.convert(c,s.QQ)
    def vector(self,a):
        cs=[q(c) for c in a.to_list()][::-1]
        return s.Matrix(cs+[s.S.Zero]*(self.degree-len(cs)))
    def from_vector(self,v):
        return self.domain([s.QQ.convert(c) for c in reversed(list(v))])
    def eval_at(self,a,image):
        r=self.zero
        for c in a.to_list(): r=r*image+self.rational(c)
        return r
    def factor_rational(self,f):
        x=s.Dummy('x')
        pp=s.Poly.from_list(s.Poly(f).all_coeffs(),x,domain=self.domain)
        return pp.factor_list()[1]
    def roots_rational(self,f):
        fs=self.factor_rational(f)
        if any(g.degree()!=1 for g,e in fs):
            raise ValueError('Polynomial does not split in the supplied field')
        return [-g.rep.to_list()[1]/g.rep.to_list()[0] for g,e in fs]
    def multiplication_matrix(self,a):
        return s.Matrix.hstack(*[self.vector(a*self.theta**j) for j in range(self.degree)])
    def automorphism_matrix(self,image):
        return s.Matrix.hstack(*[self.vector(image**j) for j in range(self.degree)])


def adjoin_root(F: ExactField, g: s.Poly, max_degree: Optional[int]=128):
    """Adjoin a root of a monic irreducible factor g over F.

    Return (new_field, image_of_old_theta, image_of_adjoined_root, metadata).
    The complex embedding can change: all maps are abstract field embeddings.
    """
    m=g.degree(); d=F.degree; D=m*d
    if m<2: raise ValueError('Need a nonlinear irreducible factor')
    if max_degree is not None and D>max_degree:
        raise ResourceLimit(f'Proposed absolute field degree {D} exceeds {max_degree}')
    high=g.rep.to_list(); lc=high[0]
    coeff=[c/lc for c in reversed(high)][:-1]
    z=F.zero; o=F.one
    def mul(a,b):
        w=[z for _ in range(2*m-1)]
        for i,u in enumerate(a):
            if u:
                for j,v in enumerate(b):
                    if v: w[i+j]=w[i+j]+u*v
        for k in range(2*m-2,m-1,-1):
            c=w[k]
            if c:
                for j in range(m): w[k-m+j]=w[k-m+j]-c*coeff[j]
        return w[:m]
    def vec(a): return s.Matrix.vstack(*[F.vector(u) for u in a])
    old=[F.theta]+[z]*(m-1)
    beta=[z,o]+[z]*(m-2)
    unit=[o]+[z]*(m-1)
    c=0
    while True:
        # Infinitely many integers are tried; separability guarantees success.
        eta=[beta[j]+F.rational(c)*old[j] for j in range(m)]
        powers=[unit]
        for j in range(D): powers.append(mul(powers[-1],eta))
        B=s.Matrix.hstack(*[vec(v) for v in powers[:-1]])
        try: inv=B.inv()
        except (s.matrices.exceptions.NonInvertibleMatrixError, NotInvertible):
            c+=1; continue
        rel=inv*vec(powers[D])
        t=s.Dummy('t')
        p=s.Poly.from_list([s.S.One]+[-rel[j] for j in range(D-1,-1,-1)],t,domain=s.QQ)
        E=ExactField.from_poly(p)
        theta_image=E.from_vector(inv*vec(old))
        beta_image=E.from_vector(inv*vec(beta))
        # Independent exact checks on both defining relations.
        old_relation=E.zero
        for a in F.poly.all_coeffs(): old_relation=old_relation*theta_image+E.rational(a)
        if old_relation: raise ArithmeticError('Old defining relation failed')
        gr=E.zero
        for a in high:
            ai=E.zero
            for b in a.to_list(): ai=ai*theta_image+E.rational(b)
            gr=gr*beta_image+ai
        if gr: raise ArithmeticError('Adjoined defining relation failed')
        return E,theta_image,beta_image,{'old_degree':d,'relative_degree':m,'new_degree':D,'primitive_coefficient':c}


def map_element(F,a,E,theta_image):
    r=E.zero
    for c in a.to_list(): r=r*theta_image+E.rational(c)
    return r


def splitting_field(f, max_degree=128, progress=None):
    f=s.Poly(f,domain=s.QQ).monic()
    if f.degree()<2 or not f.is_irreducible:
        raise ValueError('Expected an irreducible rational polynomial of degree >= 2')
    if max_degree is not None and f.degree()>max_degree:
        raise ResourceLimit('Initial field degree exceeds the limit')
    F=ExactField.from_poly(f); history=[]
    F.selected_roots=[F.theta]; F.root_weights=[1]; F.unity_coefficient=0
    while True:
        fs=F.factor_rational(f)
        nonlinear=[g for g,e in fs if g.degree()>1]
        if not nonlinear:
            roots=[-g.rep.to_list()[1]/g.rep.to_list()[0] for g,e in fs]
            if len(set(roots))!=f.degree(): raise ArithmeticError('Non-distinct split roots')
            return F,roots,history
        g=min(nonlinear,key=lambda h:h.degree())
        if progress: progress(f'Adjoining a degree-{g.degree()} factor to degree-{F.degree} field')
        E,old_image,new_root,meta=adjoin_root(F,g,max_degree)
        E.selected_roots=[map_element(F,a,E,old_image) for a in F.selected_roots]+[new_root]
        E.root_weights=[meta['primitive_coefficient']*w for w in F.root_weights]+[1]
        E.unity_coefficient=0
        F=E
        history.append(meta)


class Coordinates:
    """Exact, reusable left inverse for an independent list of field elements."""
    def __init__(self,F,basis):
        self.F=F
        self.B=s.Matrix.hstack(*[F.vector(a) for a in basis])
        self.rows=list(self.B.T.rref()[1])
        if len(self.rows)!=len(basis): raise ArithmeticError('Dependent field basis')
        self.inverse=self.B.extract(self.rows,list(range(len(basis)))).inv()
    def __call__(self,a):
        v=self.F.vector(a)
        c=self.inverse*v.extract(self.rows,[0])
        if self.B*c!=v: raise ArithmeticError('Element is outside the claimed fixed field')
        return list(c)
