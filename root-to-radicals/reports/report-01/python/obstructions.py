"""Small exact non-solvability certificates; failed searches prove nothing."""
import sympy as s


def prime_degree_obstruction(poly, prime_bound=101):
    f=s.Poly(poly,domain=s.QQ).monic();n=f.degree()
    if n<5 or not s.isprime(n):return None
    for p in s.primerange(2,prime_bound+1):
        if any(c.q%p==0 for c in f.all_coeffs()):continue
        coeff=[int(c.p)*pow(int(c.q),-1,int(p))%p for c in f.all_coeffs()]
        g=s.Poly.from_list(coeff,f.gen,modulus=p)
        factors=g.factor_list()[1]
        degrees=[h.degree() for h,m in factors]
        if any(m!=1 for h,m in factors):continue
        if degrees.count(2)!=1 or any(d!=2 and d%2==0 for d in degrees):continue
        return {'status':'NotSolvable','method':'PrimeDegreeTransposition',
                'version':'1.0.0','polynomial':[str(c) for c in f.all_coeffs()],
                'certificate':{'prime':int(p),'degree':n,
                    'factors':[[int(c) for c in h.monic().all_coeffs()] for h,m in factors]},
                'galois':{'group':'SymmetricGroup','degree':n,'order':int(s.factorial(n))}}
    return None


def verify_prime_degree_obstruction(result):
    x=s.Dummy('x');f=s.Poly.from_list([s.Rational(c) for c in result['polynomial']],x,domain=s.QQ).monic()
    n=f.degree();cert=result['certificate'];p=int(cert['prime'])
    if not f.is_irreducible or n<5 or not s.isprime(n) or not s.isprime(p):
        raise ValueError('Invalid irreducibility or prime-degree hypothesis')
    if cert['degree']!=n or any(c.q%p==0 for c in f.all_coeffs()):raise ValueError('Bad reduction prime')
    g=s.Poly.from_list([int(c.p)*pow(int(c.q),-1,p)%p for c in f.all_coeffs()],x,modulus=p)
    factors=[s.Poly.from_list(cs,x,modulus=p).monic() for cs in cert['factors']]
    product=s.Poly(1,x,modulus=p)
    for h in factors:
        if not h.is_irreducible:raise ValueError('Nonirreducible modular factor')
        product*=h
    degrees=[h.degree() for h in factors]
    if product!=g or len(set(h.as_expr() for h in factors))!=len(factors):
        raise ValueError('Incorrect or ramified modular factorization')
    if degrees.count(2)!=1 or any(d!=2 and d%2==0 for d in degrees):
        raise ValueError('Cycle pattern does not isolate a transposition')
    return True
