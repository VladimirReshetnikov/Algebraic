from pathlib import Path
import random
root=Path(__file__).resolve().parents[1]
tests=[]
def add(name, expr, expected='True'):
    tests.append(f'VerificationTest[\n  {expr},\n  {expected},\n  TestID -> "{name}"\n]\n')
setup='''(* Native Wolfram Language tests. Load the package first, or use RunTests.wls.
   Tests are supplied for execution in a fresh kernel; they were not run
   in the delivery environment. No approximate comparisons are used. *)
Clear[x, a, poly, nested, expected, samePoly, sameChain];
samePoly[p_, q_] := And @@ (SameQ[RootReduce[#], 0] & /@
  CoefficientList[Expand[p - q], x]);
sameChain[c_, d_] := ListQ[c] && ListQ[d] && Length[c] == Length[d] &&
  And @@ MapThread[samePoly, {c, d}];
poly = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x + (12 + 26 Sqrt[2]) x^2 +
  (56 + 8 Sqrt[2]) x^3 + (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
nested = Expand[poly /. x -> x^4 - x + 1];
expected = {3 + 3 Sqrt[2] + (8 + 14 Sqrt[2]) x +
  (8 + 24 Sqrt[2]) x^2 + 16 Sqrt[2] x^3, x^2 + x/Sqrt[2]};
'''
add('original-normalized-pair','sameChain[AlgebraicDecomposeAtDegree[poly, x, 2], expected]')
add('original-complete-chain','sameChain[AlgebraicDecompose[poly, x], expected]')
add('original-compose','samePoly[AlgebraicCompose[expected, x], poly]')
add('original-degree-three-rejected','AlgebraicDecomposeAtDegree[poly, x, 3]','Missing["NotDecomposableAtDegree", 3]')
add('original-all-pairs','Length[AlgebraicRightComponents[poly, x]]','1')
add('original-all-chains','AlgebraicDecomposeAll[poly, x]["ReturnedCount"]','1')
add('original-verification','AlgebraicVerifyDecomposition[poly, expected, x, "RequireComplete" -> True, "RequireNormalized" -> True]')
add('nested-degree-sequence','Exponent[#, x] & /@ AlgebraicDecompose[nested, x]','{3, 2, 4}')
add('nested-descending-verification','AlgebraicVerifyDecomposition[nested, AlgebraicDecompose[nested, x, "DegreeOrder" -> "Descending"], x, "RequireComplete" -> True, "RequireNormalized" -> True]')
add('nested-exact-components','sameChain[AlgebraicDecompose[nested, x], {141 + 105 Sqrt[2] + (168 + 142 Sqrt[2]) x + (56 + 72 Sqrt[2]) x^2 + 16 Sqrt[2] x^3, x^2 + (2 + 1/Sqrt[2]) x, x^4 - x}]')
add('quartic-indecomposable','AlgebraicDecompose[x^4-x+1, x]','{x^4-x+1}')
add('degree-six-indecomposable','AlgebraicRightComponents[x^6+x, x]','{}')
add('prime-terminal','AlgebraicDecompose[x^5+x+1, x]','{x^5+x+1}')
for expr in ['0','7','x','2 x+3','Sqrt[2]']:
    add('terminal-'+expr.replace(' ','').replace('[','').replace(']',''),f'AlgebraicDecompose[{expr}, x]',f'{{{expr}}}')
add('empty-composition','AlgebraicCompose[{}, x]','x')
add('empty-identity-verification','AlgebraicVerifyDecomposition[x, {}, x, "RequireNormalized" -> True]')
add('empty-chain-not-complete','AlgebraicVerifyDecomposition[x, {}, x, "RequireComplete" -> True]','False')
add('zero-report-degree','AlgebraicDecompositionReport[0,x]["Degree"]','-Infinity')
add('constant-report-status','AlgebraicDecompositionReport[7,x]["Status"]','"Constant"')
add('linear-report-status','AlgebraicDecompositionReport[x,x]["Status"]','"Linear"')
add('negative-decision-status','AlgebraicDecompositionReport[x^6+x,x]["Status"]','"Indecomposable"')
add('negative-decision-all-degrees','Lookup[AlgebraicDecompositionReport[x^6+x,x]["Trials"], "RightDegree"]','{2,3}')
add('negative-decision-obstructions','Lookup[AlgebraicDecompositionReport[x^6+x,x]["Trials"], "NonconstantRemainder"]','{x,x}')
add('successful-decision-status','AlgebraicDecompositionReport[poly,x]["Status"]','"Decomposable"')
add('power-composition-multiplies-degrees','AlgebraicCompose[{x^2,x^3},x]','x^6')
add('power-chain-complete','AlgebraicDecompose[x^12,x]','{x^3,x^2,x^2}')
for n,c in [(6,2),(12,3),(16,1),(30,6),(36,6)]:
    add(f'power-all-count-{n}',f'AlgebraicDecomposeAll[x^{n},x]["ReturnedCount"]',str(c))
add('chebyshev-six-all-count','AlgebraicDecomposeAll[ChebyshevT[6,x],x]["ReturnedCount"]','2')
add('chebyshev-six-all-valid','AllTrue[AlgebraicDecomposeAll[ChebyshevT[6,x],x]["Decompositions"], AlgebraicVerifyDecomposition[ChebyshevT[6,x],#,x,"RequireComplete"->True,"RequireNormalized"->True]&]')
add('cap-truncated','AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->1]["EnumerationComplete"]','False')
add('cap-not-truncated','AlgebraicDecomposeAll[x^16,x,"MaxDecompositions"->1]["EnumerationComplete"]')
add('cap-exact-boundary','AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->2]["EnumerationComplete"]')
add('cap-count','AlgebraicDecomposeAll[x^30,x,"MaxDecompositions"->2]["ReturnedCount"]','2')
add('incorrect-chain','AlgebraicVerifyDecomposition[x^6,{x^2,x^4},x]','False')
add('unsplit-not-complete','AlgebraicVerifyDecomposition[x^4,{x^4},x,"RequireComplete"->True]','False')
add('split-is-complete','AlgebraicVerifyDecomposition[x^4,{x^2,x^2},x,"RequireComplete"->True]')
add('linear-factor-not-complete','AlgebraicVerifyDecomposition[x^2+x,{2x,(x^2+x)/2},x,"RequireComplete"->True]','False')
add('linear-factor-valid-identity','AlgebraicVerifyDecomposition[x^2+x,{2x,(x^2+x)/2},x]')
add('nonmonic-inner-rejected-by-normalization','AlgebraicVerifyDecomposition[x^4,{x^2/4,2x^2},x,"RequireNormalized"->True]','False')
add('same-nonmonic-identity-valid','AlgebraicVerifyDecomposition[x^4,{x^2/4,2x^2},x]')
add('root-quintic','Module[{a=Root[#^5-#-1&,1],p,c}, p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; c=AlgebraicDecompose[p,x]; sameChain[c,{x^3+a x+1,x^2+a x}]]')
add('root-complex-conjugate','Module[{a=Root[#^5-#-1&,2],p},p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; sameChain[AlgebraicDecompose[p,x],{x^3+a x+1,x^2+a x}]]')
add('mixed-field','Module[{a=Sqrt[2]+I,b=Sqrt[3],p},p=Expand[(x^2+a x)^3+b(x^2+a x)+1];sameChain[AlgebraicDecompose[p,x],{x^3+b x+1,x^2+a x}]]')
add('algebraicnumber-coefficient','Module[{a=AlgebraicNumber[Sqrt[2],{1,1}],p},p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,"RequireComplete"->True]]')
add('exact-leading-degree-cancellation','Module[{a=Root[#^5-#-1&,1]},Exponent[#,x]& /@ AlgebraicDecompose[(a^5-a-1)x^10+(x^2+x)^2,x]]','{2,2}')
add('radical-branch-preserved','Module[{a=(-2)^(1/3),p},p=Expand[(x^2+a x)^3+2(x^2+a x)+1];sameChain[AlgebraicDecompose[p,x],{x^3+2x+1,x^2+a x}]]')
for name,expr in [
('inexact','AlgebraicDecompose[1.0 x^4+x,x]'),
('transcendental','AlgebraicDecompose[x^4+Pi x,x]'),
('symbolic','AlgebraicDecompose[x^4+a x,x]'),
('not-polynomial','AlgebraicDecompose[Sqrt[x]+x^2,x]'),
('invalid-variable','AlgebraicDecompose[x^4,1]'),
('numeric-variable','AlgebraicCompose[{},Pi]'),
('invalid-degree','AlgebraicDecomposeAtDegree[x^6,x,4]'),
('noninteger-degree','AlgebraicDecomposeAtDegree[x^6,x,2.0]'),
('trivial-degree','AlgebraicDecomposeAtDegree[x^6,x,1]'),
('bad-cap','AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->0]'),
('bad-order','AlgebraicDecompose[x^6,x,"DegreeOrder"->"Random"]'),
('unknown-option','AlgebraicDecompose[x^6,x,"Extension"->Sqrt[2]]'),
('bad-verification-option','AlgebraicVerifyDecomposition[x,{x},x,"RequireComplete"->1]')]:
    add('failure-'+name,f'MatchQ[{expr},_Failure]')
# Exact random constructed inputs are generated here, then frozen into the .wlt.
rng=random.Random(206618)
for i in range(40):
    m,d=rng.choice([2,3,4,5]),rng.choice([2,3,4])
    def pol(n,alg):
        ts=[]
        for j in range(n):
            a,b=rng.randint(-3,3),rng.randint(-2,2)
            c=f'({a}'+(f'+({b}) Sqrt[2]' if alg else '')+')'
            ts.append(f'{c} x^{j}')
        ts.append(f'({rng.choice([-2,-1,1,2])}) x^{n}')
        return '+'.join(ts)
    fs,gs=pol(m,i>=20),pol(d,i>=20)
    expr=f'''Module[{{f={fs},g={gs},p,c,hn,fn}},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,{d}];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,{d}]];
    fn=Expand[f/.x->Coefficient[g,x,{d}] x+(g/.x->0)];
    sameChain[c,{{fn,hn}}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]]'''
    add(f'frozen-random-{i:02}',expr)
(root/'Tests'/'AlgebraicDecomposition.wlt').write_text(setup+'\n'.join(tests))
(root/'validation'/'native_test_count.txt').write_text(str(len(tests))+'\n')
print(len(tests),'native tests generated')
