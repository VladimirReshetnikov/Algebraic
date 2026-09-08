"""RadicalRoot: constructive Galois-to-radical conversion over Q.

This is a research/reference implementation, not an efficient universal
replacement for a production computer-algebra system.  With max_field_degree
and max_candidates set to None the general algorithm has no mathematical
search cutoff.  It is finite for every irreducible polynomial, assuming the
exact factorization and root-isolation primitives terminate.
"""
from __future__ import annotations
import itertools, math, time
import sympy as s
from sympy.combinatorics import Permutation, PermutationGroup
from exact_fields import ExactField, ResourceLimit, splitting_field, adjoin_root, map_element, Coordinates, q
from certified_embedding import Embedding
import radical_ast as A

VERSION='1.0.0'

def encoded(a):return [str(q(c)) for c in a.to_list()]
def decoded(F,cs):return F.domain([s.QQ.convert(s.Rational(c)) for c in cs])
def permkey(p,n):return tuple(p(i) for i in range(n))
def peval(F,coeffs,a):
    r=F.zero
    for c in coeffs:r=r*a+F.rational(c)
    return r

def normal_closure_group(F,roots,zeta,base_degree,max_candidates=None,progress=None):
    """Enumerate generator images; verify all candidates in exact arithmetic.

    theta is an integer linear combination of selected original roots and
    zeta. Thus every automorphism fixing zeta occurs among these candidates.
    Stop after the known degree [M:Q(zeta)] images have been found.
    """
    n=len(roots); expected=F.degree//base_degree
    weights=[w for w in F.root_weights if w]
    candidate_count=math.perm(n,len(weights))
    if max_candidates is not None and candidate_count>max_candidates:
        raise ResourceLimit(f'{candidate_count} possible generator images exceeds {max_candidates}')
    index={r:i for i,r in enumerate(roots)};seen=set();images={}
    fixed=F.rational(F.unity_coefficient)*zeta
    for selected in itertools.permutations(roots,len(weights)):
        image=fixed+sum((F.rational(w)*a for w,a in zip(weights,selected)),F.zero)
        if image in seen:continue
        seen.add(image)
        if peval(F,F.poly.all_coeffs(),image):continue
        if F.eval_at(zeta,image)!=zeta:continue
        actions=[F.eval_at(a,image) for a in roots]
        if any(a not in index for a in actions):raise ArithmeticError('Automorphism did not permute roots')
        perm=tuple(index[a] for a in actions)
        if len(set(perm))!=n:raise ArithmeticError('Non-bijective root action')
        images[perm]=image
        if len(images)==expected:break
    if len(images)!=expected:raise ArithmeticError('Incomplete automorphism enumeration')
    G=PermutationGroup([Permutation(list(p)) for p in images])
    if int(G.order())!=expected:raise ArithmeticError('Automorphism count and group order disagree')
    return G,images

def construct_irreducible(f, *, max_field_degree=128, max_candidates=1000000,
                          precheck=True, progress=None):
    f=s.Poly(f,domain=s.QQ).monic()
    if f.degree()<2 or not f.is_irreducible:
        raise ValueError('construct_irreducible requires an irreducible polynomial of degree >=2')
    started=time.monotonic();note=progress or (lambda message:None)
    preliminary=None
    if precheck and 2<=f.degree()<=6:
        from sympy.polys.numberfields.galoisgroups import MaxTriesException
        try:
            G0,_=s.polys.numberfields.galois_group(f)
        except MaxTriesException:
            note('Optional small-degree Galois precheck exhausted its attempts; using general construction')
        else:
            preliminary={'order':int(G0.order()),'solvable':bool(G0.is_solvable),
                         'generators':[list(permkey(p,f.degree())) for p in G0.generators]}
            if not G0.is_solvable:
                return {'status':'NotSolvable','method':'ExactGaloisGroup',
                        'polynomial':[str(c) for c in f.all_coeffs()],
                        'galois':preliminary,'version':VERSION}
    if precheck and f.degree()>6:
        from obstructions import prime_degree_obstruction
        obstruction=prime_degree_obstruction(f)
        if obstruction is not None:return obstruction
    note('Constructing splitting field')
    F,roots,history=splitting_field(f,max_field_degree,note)
    splitting_degree=F.degree
    N=math.prod(s.factorint(splitting_degree))
    base_degree=int(s.totient(N))
    cyc=s.Poly(s.cyclotomic_poly(N,s.Dummy('z')),domain=s.QQ)
    fs=F.factor_rational(cyc)
    linears=[g for g,e in fs if g.degree()==1]
    if linears:
        g=linears[0];zeta=-g.rep.to_list()[1]/g.rep.to_list()[0]
    else:
        g=min((g for g,e in fs),key=lambda p:p.degree())
        note(f'Adjoining a primitive {N}-th root of unity')
        E,old_image,zeta,meta=adjoin_root(F,g,max_field_degree)
        E.selected_roots=[map_element(F,a,E,old_image) for a in F.selected_roots]
        c=meta['primitive_coefficient']
        E.root_weights=[c*w for w in F.root_weights];E.unity_coefficient=1
        roots=[map_element(F,a,E,old_image) for a in roots]
        F=E;history.append(dict(meta,kind='cyclotomic'))
    if sum((F.rational(w)*a for w,a in zip(F.root_weights,F.selected_roots)),F.zero)+F.rational(F.unity_coefficient)*zeta!=F.theta:
        raise ArithmeticError('Primitive generator description is inconsistent')
    note(f'Computing automorphisms in absolute degree {F.degree}')
    G,images=normal_closure_group(F,roots,zeta,base_degree,max_candidates,note)
    if not G.is_solvable:
        return {'status':'NotSolvable','method':'CyclotomicRelativeGaloisGroup',
                'polynomial':[str(c) for c in f.all_coeffs()],
                'relative_group_order':int(G.order()),
                'generators':[list(permkey(p,len(roots))) for p in G.generators],
                'certificate':{'field_polynomial':[str(v) for v in F.poly.all_coeffs()],
                    'roots':[encoded(v) for v in roots], 'zeta':encoded(zeta), 'unity_order':N,
                    'theta_root_weights':F.root_weights,
                    'theta_selected_roots':[encoded(v) for v in F.selected_roots],
                    'theta_unity_coefficient':F.unity_coefficient,
                    'generator_images':[encoded(images[permkey(p,len(roots))]) for p in G.generators]},
                'version':VERSION}
    note('Certifying the complex embedding and root-of-unity branch')
    embedding=Embedding(F)
    root_order=embedding.setup_conjugation(f,roots,zeta)
    exponent=embedding.unity_exponent(zeta,N)
    series=G.composition_series()
    orders=[int(H.order()) for H in series]
    if orders[-1]!=1:raise ArithmeticError('Composition series does not reach the identity')
    n=len(roots);D=F.degree;identity=s.eye(D);matrix_cache={}
    def automatrix(p):
        key=permkey(p,n)
        if key not in matrix_cache:matrix_cache[key]=F.automorphism_matrix(images[key])
        return matrix_cache[key]
    zexpr=A.power(A.rat(-1),2*exponent,N)
    definitions=[{'name':'zeta','expression':zexpr}]
    basis=[zeta**j for j in range(base_degree)]
    bexpr=[A.power(A.ref('zeta'),j) for j in range(base_degree)]
    stages=[]
    for i,(J,H) in enumerate(zip(series,series[1:]),1):
        p=int(J.order()//H.order())
        if not s.isprime(p) or not H.is_normal(J):raise ArithmeticError('Invalid prime-index normal step')
        sigma=next(g for g in J.generate_schreier_sims() if not H.contains(g))
        eigen=zeta**(N//p)
        rows=[automatrix(g)-identity for g in H.generators]
        rows.append(automatrix(sigma)-F.multiplication_matrix(eigen))
        null=s.Matrix.vstack(*rows).nullspace()
        if len(null)!=D//int(J.order()):raise ArithmeticError('Unexpected Kummer eigenspace dimension')
        # Primitive integral scaling often shortens the radicand substantially.
        v=null[0];den=s.ilcm(*[c.q for c in v]) if len(v)>1 else v[0].q
        ints=[int(c*den) for c in v];content=math.gcd(*ints)
        v=s.Matrix([c//content for c in ints])
        beta=F.from_vector(v)
        if not beta:raise ArithmeticError('Vanishing Kummer eigenvector')
        if F.from_vector(automatrix(sigma)*F.vector(beta))!=eigen*beta:
            raise ArithmeticError('Kummer eigenvalue identity failed')
        for g in H.generators:
            if F.from_vector(automatrix(g)*F.vector(beta))!=beta:
                raise ArithmeticError('Generator not fixed by the next subgroup')
        coord=Coordinates(F,basis)
        delta=beta**p
        dexpr=A.linear(coord(delta),bexpr)
        k,witness=embedding.principal_branch(beta,p,zeta,N,exponent)
        name=f'r{i}'
        expr=A.mul(A.power(A.ref('zeta'),(N//p)*k),A.power(dexpr,1,p))
        definitions.append({'name':name,'expression':expr})
        stages.append({'name':name,'prime':p,'branch':k,'beta':encoded(beta),
                       'radicand':dexpr,'sector_signs':witness,
                       'group_orders':[int(J.order()),int(H.order())]})
        basis=[b*beta**j for j in range(p) for b in basis]
        bexpr=[A.mul(b,A.power(A.ref(name),j)) for j in range(p) for b in bexpr]
        note(f'Radical stage {i}: prime {p}; fixed-field degree {len(basis)}')
    if len(basis)!=D:raise ArithmeticError('Final radical field basis is incomplete')
    final_coordinates=Coordinates(F,basis)
    result_roots=[]
    for i,a in enumerate(roots):
        result_roots.append({'index':root_order[i],
                             'expression':A.linear(final_coordinates(a),bexpr),
                             'field_value':encoded(a)})
    result_roots.sort(key=lambda r:r['index'])
    cert={'field_polynomial':[str(c) for c in F.poly.all_coeffs()],
          'field_embedding_index':0,'zeta':encoded(zeta),'unity_order':N,
          'unity_exponent':exponent,'theta_root_weights':F.root_weights,
          'theta_selected_roots':[encoded(a) for a in F.selected_roots],
          'theta_unity_coefficient':F.unity_coefficient,'stages':stages}
    out={'status':'Success','method':'ConstructiveGalois','version':VERSION,
         'polynomial':[str(c) for c in f.all_coeffs()],
         'definitions':definitions,'roots':result_roots,'certificate':cert,
         'statistics':{'input_degree':n,'splitting_field_degree':splitting_degree,
             'absolute_field_degree':D,'cyclotomic_order':N,'relative_group_order':int(G.order()),
             'composition_series_orders':orders,'extension_history':history,
             'elapsed_seconds':time.monotonic()-started,'preliminary_galois':preliminary}}
    return out


def verify_constructive(result):
    """Check a positive certificate without recomputing the Galois group.

    Checks irreducibility, all embedded roots, the primitive description,
    every principal branch, every assignment and every output coordinate.
    Raises on malformed certificates; returns True only after all checks.
    """
    if result.get('status')!='Success' or result.get('method')!='ConstructiveGalois':
        raise ValueError('Expected a constructive positive certificate')
    c=result['certificate'];t=s.Dummy('t');x=s.Dummy('x')
    fp=s.Poly.from_list([s.Rational(a) for a in c['field_polynomial']],t)
    if not fp.is_irreducible:raise ValueError('Certificate field polynomial is reducible')
    if c['field_embedding_index']!=0:raise ValueError('Unsupported field embedding index')
    F=ExactField.from_poly(fp)
    f=s.Poly.from_list([s.Rational(a) for a in result['polynomial']],x)
    if not f.is_irreducible:raise ValueError('Certificate target must be irreducible')
    roots=[decoded(F,r['field_value']) for r in result['roots']]
    if len(roots)!=f.degree() or len(set(roots))!=len(roots):raise ValueError('Missing or duplicate roots')
    zeta=decoded(F,c['zeta']);N=int(c['unity_order']);a=int(c['unity_exponent'])
    if N<2:raise ValueError('Invalid cyclotomic order')
    if peval(F,s.Poly(s.cyclotomic_poly(N,t)).all_coeffs(),zeta):raise ValueError('Nonprimitive unity value')
    F.selected_roots=[decoded(F,v) for v in c['theta_selected_roots']]
    F.root_weights=[int(w) for w in c['theta_root_weights']]
    F.unity_coefficient=int(c['theta_unity_coefficient'])
    if len(F.selected_roots)!=len(F.root_weights) or any(v not in roots for v in F.selected_roots):
        raise ValueError('Bad primitive root description')
    value=sum((F.rational(w)*b for w,b in zip(F.root_weights,F.selected_roots)),F.zero)+F.rational(F.unity_coefficient)*zeta
    if value!=F.theta:raise ValueError('Wrong primitive generator')
    E=Embedding(F);order=E.setup_conjugation(f,roots,zeta)
    if E.unity_exponent(zeta,N)!=a:raise ValueError('Wrong root-of-unity branch')
    defs=result['definitions']
    if len(defs)!=len(c['stages'])+1 or defs[0]!={'name':'zeta','expression':A.power(A.rat(-1),2*a,N)}:
        raise ValueError('Wrong cyclotomic assignment')
    env={'zeta':zeta}
    for i,st in enumerate(c['stages'],1):
        name=st['name'];p=int(st['prime']);k=int(st['branch'])
        if name in env or not s.isprime(p) or N%p:raise ValueError('Invalid radical stage')
        A.validate(st['radicand'],env)
        beta=decoded(F,st['beta']);delta=A.field_eval(st['radicand'],F,env)
        if not beta or beta**p!=delta:raise ValueError('Wrong radical power identity')
        kk,signs=E.principal_branch(beta,p,zeta,N,a)
        if kk!=k or signs!=st['sector_signs']:raise ValueError('Wrong principal branch')
        expected={'name':name,'expression':A.mul(A.power(A.ref('zeta'),(N//p)*k),A.power(st['radicand'],1,p))}
        if defs[i]!=expected:raise ValueError('Output assignment differs from certificate')
        env[name]=beta
    if sorted(r['index'] for r in result['roots'])!=list(range(len(roots))):raise ValueError('Bad root indices')
    for i,r in enumerate(result['roots']):
        A.validate(r['expression'],env)
        if A.field_eval(r['expression'],F,env)!=roots[i]:raise ValueError('Wrong output expression')
        if int(r['index'])!=order[i]:raise ValueError('Wrong conjugate')
    return True


def radicalize(f, **options):
    """General solver for an irreducible rational polynomial (all conjugates).

    Resource exhaustion is returned as Unknown, never as NotSolvable.
    Other failures are not silently swallowed; callers can distinguish a
    programming/backend error from a mathematically negative result.
    """
    try:return construct_irreducible(f,**options)
    except ResourceLimit as e:
        return {'status':'Unknown','reason':'ResourceLimit','message':str(e),'version':VERSION}


def verify_negative(result):
    """Check a non-solvability result; Unknown is never a negative certificate."""
    if result.get('status')!='NotSolvable':raise ValueError('Expected NotSolvable')
    method=result['method'];x=s.Dummy('x');t=s.Dummy('t')
    f=s.Poly.from_list([s.Rational(c) for c in result['polynomial']],x,domain=s.QQ)
    if not f.is_irreducible:raise ValueError('Target is not a minimal polynomial')
    if method=='PrimeDegreeTransposition':
        from obstructions import verify_prime_degree_obstruction
        return verify_prime_degree_obstruction(result)
    if method=='ExactGaloisGroup':
        G,_=s.polys.numberfields.galois_group(f)
        if G.is_solvable or int(G.order())!=result['galois']['order']:
            raise ValueError('Invalid Galois obstruction')
        return True
    if method!='CyclotomicRelativeGaloisGroup':raise ValueError('Unknown negative proof')
    c=result['certificate'];F=ExactField.from_poly(s.Poly.from_list([s.Rational(a) for a in c['field_polynomial']],t))
    if not F.poly.is_irreducible:raise ValueError('Reducible certificate field')
    roots=[decoded(F,a) for a in c['roots']];n=f.degree()
    if len(roots)!=n or len(set(roots))!=n or any(peval(F,f.all_coeffs(),a) for a in roots):
        raise ValueError('Incomplete or incorrect splitting roots')
    N=int(c['unity_order']);zeta=decoded(F,c['zeta'])
    if N<2 or peval(F,s.Poly(s.cyclotomic_poly(N,t)).all_coeffs(),zeta):raise ValueError('Bad unity')
    selected=[decoded(F,a) for a in c['theta_selected_roots']];weights=c['theta_root_weights']
    if len(selected)!=len(weights) or any(a not in roots for a in selected):raise ValueError('Bad primitive data')
    if sum((F.rational(s.Integer(w))*a for w,a in zip(weights,selected)),F.zero)+F.rational(s.Integer(c['theta_unity_coefficient']))*zeta!=F.theta:
        raise ValueError('Field contains unaccounted-for generators')
    images=[decoded(F,a) for a in c['generator_images']];perms=result['generators']
    if len(images)!=len(perms):raise ValueError('Missing group generator images')
    for image,perm in zip(images,perms):
        if sorted(perm)!=list(range(n)) or peval(F,F.poly.all_coeffs(),image):raise ValueError('Not an automorphism')
        if F.eval_at(zeta,image)!=zeta:raise ValueError('Does not fix cyclotomic base')
        if any(F.eval_at(a,image)!=roots[perm[i]] for i,a in enumerate(roots)):
            raise ValueError('Incorrect root action')
    G=PermutationGroup([Permutation(p) for p in perms])
    if G.is_solvable:raise ValueError('The certified subgroup is solvable')
    return True
