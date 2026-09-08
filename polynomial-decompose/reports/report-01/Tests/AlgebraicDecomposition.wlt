(* Native Wolfram Language tests. Load the package first, or use RunTests.wls.
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
VerificationTest[
  sameChain[AlgebraicDecomposeAtDegree[poly, x, 2], expected],
  True,
  TestID -> "original-normalized-pair"
]

VerificationTest[
  sameChain[AlgebraicDecompose[poly, x], expected],
  True,
  TestID -> "original-complete-chain"
]

VerificationTest[
  samePoly[AlgebraicCompose[expected, x], poly],
  True,
  TestID -> "original-compose"
]

VerificationTest[
  AlgebraicDecomposeAtDegree[poly, x, 3],
  Missing["NotDecomposableAtDegree", 3],
  TestID -> "original-degree-three-rejected"
]

VerificationTest[
  Length[AlgebraicRightComponents[poly, x]],
  1,
  TestID -> "original-all-pairs"
]

VerificationTest[
  AlgebraicDecomposeAll[poly, x]["ReturnedCount"],
  1,
  TestID -> "original-all-chains"
]

VerificationTest[
  AlgebraicVerifyDecomposition[poly, expected, x, "RequireComplete" -> True, "RequireNormalized" -> True],
  True,
  TestID -> "original-verification"
]

VerificationTest[
  Exponent[#, x] & /@ AlgebraicDecompose[nested, x],
  {3, 2, 4},
  TestID -> "nested-degree-sequence"
]

VerificationTest[
  AlgebraicVerifyDecomposition[nested, AlgebraicDecompose[nested, x, "DegreeOrder" -> "Descending"], x, "RequireComplete" -> True, "RequireNormalized" -> True],
  True,
  TestID -> "nested-descending-verification"
]

VerificationTest[
  sameChain[AlgebraicDecompose[nested, x], {141 + 105 Sqrt[2] + (168 + 142 Sqrt[2]) x + (56 + 72 Sqrt[2]) x^2 + 16 Sqrt[2] x^3, x^2 + (2 + 1/Sqrt[2]) x, x^4 - x}],
  True,
  TestID -> "nested-exact-components"
]

VerificationTest[
  AlgebraicDecompose[x^4-x+1, x],
  {x^4-x+1},
  TestID -> "quartic-indecomposable"
]

VerificationTest[
  AlgebraicRightComponents[x^6+x, x],
  {},
  TestID -> "degree-six-indecomposable"
]

VerificationTest[
  AlgebraicDecompose[x^5+x+1, x],
  {x^5+x+1},
  TestID -> "prime-terminal"
]

VerificationTest[
  AlgebraicDecompose[0, x],
  {0},
  TestID -> "terminal-0"
]

VerificationTest[
  AlgebraicDecompose[7, x],
  {7},
  TestID -> "terminal-7"
]

VerificationTest[
  AlgebraicDecompose[x, x],
  {x},
  TestID -> "terminal-x"
]

VerificationTest[
  AlgebraicDecompose[2 x+3, x],
  {2 x+3},
  TestID -> "terminal-2x+3"
]

VerificationTest[
  AlgebraicDecompose[Sqrt[2], x],
  {Sqrt[2]},
  TestID -> "terminal-Sqrt2"
]

VerificationTest[
  AlgebraicCompose[{}, x],
  x,
  TestID -> "empty-composition"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x, {}, x, "RequireNormalized" -> True],
  True,
  TestID -> "empty-identity-verification"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x, {}, x, "RequireComplete" -> True],
  False,
  TestID -> "empty-chain-not-complete"
]

VerificationTest[
  AlgebraicDecompositionReport[0,x]["Degree"],
  -Infinity,
  TestID -> "zero-report-degree"
]

VerificationTest[
  AlgebraicDecompositionReport[7,x]["Status"],
  "Constant",
  TestID -> "constant-report-status"
]

VerificationTest[
  AlgebraicDecompositionReport[x,x]["Status"],
  "Linear",
  TestID -> "linear-report-status"
]

VerificationTest[
  AlgebraicDecompositionReport[x^6+x,x]["Status"],
  "Indecomposable",
  TestID -> "negative-decision-status"
]

VerificationTest[
  Lookup[AlgebraicDecompositionReport[x^6+x,x]["Trials"], "RightDegree"],
  {2,3},
  TestID -> "negative-decision-all-degrees"
]

VerificationTest[
  Lookup[AlgebraicDecompositionReport[x^6+x,x]["Trials"], "NonconstantRemainder"],
  {x,x},
  TestID -> "negative-decision-obstructions"
]

VerificationTest[
  AlgebraicDecompositionReport[poly,x]["Status"],
  "Decomposable",
  TestID -> "successful-decision-status"
]

VerificationTest[
  AlgebraicCompose[{x^2,x^3},x],
  x^6,
  TestID -> "power-composition-multiplies-degrees"
]

VerificationTest[
  AlgebraicDecompose[x^12,x],
  {x^3,x^2,x^2},
  TestID -> "power-chain-complete"
]

VerificationTest[
  AlgebraicDecomposeAll[x^6,x]["ReturnedCount"],
  2,
  TestID -> "power-all-count-6"
]

VerificationTest[
  AlgebraicDecomposeAll[x^12,x]["ReturnedCount"],
  3,
  TestID -> "power-all-count-12"
]

VerificationTest[
  AlgebraicDecomposeAll[x^16,x]["ReturnedCount"],
  1,
  TestID -> "power-all-count-16"
]

VerificationTest[
  AlgebraicDecomposeAll[x^30,x]["ReturnedCount"],
  6,
  TestID -> "power-all-count-30"
]

VerificationTest[
  AlgebraicDecomposeAll[x^36,x]["ReturnedCount"],
  6,
  TestID -> "power-all-count-36"
]

VerificationTest[
  AlgebraicDecomposeAll[ChebyshevT[6,x],x]["ReturnedCount"],
  2,
  TestID -> "chebyshev-six-all-count"
]

VerificationTest[
  AllTrue[AlgebraicDecomposeAll[ChebyshevT[6,x],x]["Decompositions"], AlgebraicVerifyDecomposition[ChebyshevT[6,x],#,x,"RequireComplete"->True,"RequireNormalized"->True]&],
  True,
  TestID -> "chebyshev-six-all-valid"
]

VerificationTest[
  AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->1]["EnumerationComplete"],
  False,
  TestID -> "cap-truncated"
]

VerificationTest[
  AlgebraicDecomposeAll[x^16,x,"MaxDecompositions"->1]["EnumerationComplete"],
  True,
  TestID -> "cap-not-truncated"
]

VerificationTest[
  AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->2]["EnumerationComplete"],
  True,
  TestID -> "cap-exact-boundary"
]

VerificationTest[
  AlgebraicDecomposeAll[x^30,x,"MaxDecompositions"->2]["ReturnedCount"],
  2,
  TestID -> "cap-count"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^6,{x^2,x^4},x],
  False,
  TestID -> "incorrect-chain"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^4,{x^4},x,"RequireComplete"->True],
  False,
  TestID -> "unsplit-not-complete"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^4,{x^2,x^2},x,"RequireComplete"->True],
  True,
  TestID -> "split-is-complete"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^2+x,{2x,(x^2+x)/2},x,"RequireComplete"->True],
  False,
  TestID -> "linear-factor-not-complete"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^2+x,{2x,(x^2+x)/2},x],
  True,
  TestID -> "linear-factor-valid-identity"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^4,{x^2/4,2x^2},x,"RequireNormalized"->True],
  False,
  TestID -> "nonmonic-inner-rejected-by-normalization"
]

VerificationTest[
  AlgebraicVerifyDecomposition[x^4,{x^2/4,2x^2},x],
  True,
  TestID -> "same-nonmonic-identity-valid"
]

VerificationTest[
  Module[{a=Root[#^5-#-1&,1],p,c}, p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; c=AlgebraicDecompose[p,x]; sameChain[c,{x^3+a x+1,x^2+a x}]],
  True,
  TestID -> "root-quintic"
]

VerificationTest[
  Module[{a=Root[#^5-#-1&,2],p},p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; sameChain[AlgebraicDecompose[p,x],{x^3+a x+1,x^2+a x}]],
  True,
  TestID -> "root-complex-conjugate"
]

VerificationTest[
  Module[{a=Sqrt[2]+I,b=Sqrt[3],p},p=Expand[(x^2+a x)^3+b(x^2+a x)+1];sameChain[AlgebraicDecompose[p,x],{x^3+b x+1,x^2+a x}]],
  True,
  TestID -> "mixed-field"
]

VerificationTest[
  Module[{a=AlgebraicNumber[Sqrt[2],{1,1}],p},p=Expand[(x^2+a x)^3+a(x^2+a x)+1]; AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,"RequireComplete"->True]],
  True,
  TestID -> "algebraicnumber-coefficient"
]

VerificationTest[
  Module[{a=Root[#^5-#-1&,1]},Exponent[#,x]& /@ AlgebraicDecompose[(a^5-a-1)x^10+(x^2+x)^2,x]],
  {2,2},
  TestID -> "exact-leading-degree-cancellation"
]

VerificationTest[
  Module[{a=(-2)^(1/3),p},p=Expand[(x^2+a x)^3+2(x^2+a x)+1];sameChain[AlgebraicDecompose[p,x],{x^3+2x+1,x^2+a x}]],
  True,
  TestID -> "radical-branch-preserved"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[1.0 x^4+x,x],_Failure],
  True,
  TestID -> "failure-inexact"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[x^4+Pi x,x],_Failure],
  True,
  TestID -> "failure-transcendental"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[x^4+a x,x],_Failure],
  True,
  TestID -> "failure-symbolic"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[Sqrt[x]+x^2,x],_Failure],
  True,
  TestID -> "failure-not-polynomial"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[x^4,1],_Failure],
  True,
  TestID -> "failure-invalid-variable"
]

VerificationTest[
  MatchQ[AlgebraicCompose[{},Pi],_Failure],
  True,
  TestID -> "failure-numeric-variable"
]

VerificationTest[
  MatchQ[AlgebraicDecomposeAtDegree[x^6,x,4],_Failure],
  True,
  TestID -> "failure-invalid-degree"
]

VerificationTest[
  MatchQ[AlgebraicDecomposeAtDegree[x^6,x,2.0],_Failure],
  True,
  TestID -> "failure-noninteger-degree"
]

VerificationTest[
  MatchQ[AlgebraicDecomposeAtDegree[x^6,x,1],_Failure],
  True,
  TestID -> "failure-trivial-degree"
]

VerificationTest[
  MatchQ[AlgebraicDecomposeAll[x^6,x,"MaxDecompositions"->0],_Failure],
  True,
  TestID -> "failure-bad-cap"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[x^6,x,"DegreeOrder"->"Random"],_Failure],
  True,
  TestID -> "failure-bad-order"
]

VerificationTest[
  MatchQ[AlgebraicDecompose[x^6,x,"Extension"->Sqrt[2]],_Failure],
  True,
  TestID -> "failure-unknown-option"
]

VerificationTest[
  MatchQ[AlgebraicVerifyDecomposition[x,{x},x,"RequireComplete"->1],_Failure],
  True,
  TestID -> "failure-bad-verification-option"
]

VerificationTest[
  Module[{f=(3) x^0+(-1) x^1+(-3) x^2+(2) x^3+(-1) x^4,g=(-2) x^0+(-1) x^1+(-2) x^2+(3) x^3+(-2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-00"
]

VerificationTest[
  Module[{f=(0) x^0+(0) x^1+(3) x^2+(2) x^3,g=(3) x^0+(2) x^1+(0) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-01"
]

VerificationTest[
  Module[{f=(3) x^0+(3) x^1+(0) x^2+(2) x^3+(0) x^4+(2) x^5,g=(-2) x^0+(-1) x^1+(-2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-02"
]

VerificationTest[
  Module[{f=(3) x^0+(3) x^1+(3) x^2+(2) x^3,g=(0) x^0+(1) x^1+(0) x^2+(-2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-03"
]

VerificationTest[
  Module[{f=(-3) x^0+(1) x^1+(2) x^2+(0) x^3+(-2) x^4+(-1) x^5,g=(3) x^0+(3) x^1+(-3) x^2+(3) x^3+(2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-04"
]

VerificationTest[
  Module[{f=(3) x^0+(-1) x^1+(-2) x^2+(3) x^3+(-1) x^4+(2) x^5,g=(3) x^0+(-3) x^1+(-1) x^2+(-1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-05"
]

VerificationTest[
  Module[{f=(0) x^0+(1) x^1+(0) x^2+(-3) x^3+(2) x^4+(-1) x^5,g=(-2) x^0+(-1) x^1+(-3) x^2+(1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-06"
]

VerificationTest[
  Module[{f=(-1) x^0+(2) x^1+(-2) x^2+(-2) x^3+(2) x^4,g=(2) x^0+(3) x^1+(-1) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-07"
]

VerificationTest[
  Module[{f=(1) x^0+(-3) x^1+(-2) x^2+(0) x^3+(-2) x^4,g=(-2) x^0+(-2) x^1+(3) x^2+(-2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-08"
]

VerificationTest[
  Module[{f=(3) x^0+(3) x^1+(1) x^2+(2) x^3,g=(2) x^0+(2) x^1+(3) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-09"
]

VerificationTest[
  Module[{f=(-3) x^0+(2) x^1+(1) x^2+(0) x^3+(1) x^4,g=(1) x^0+(-3) x^1+(2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-10"
]

VerificationTest[
  Module[{f=(-2) x^0+(-2) x^1+(-3) x^2+(1) x^3+(-2) x^4+(2) x^5,g=(2) x^0+(2) x^1+(1) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-11"
]

VerificationTest[
  Module[{f=(-1) x^0+(2) x^1+(-1) x^2+(1) x^3,g=(3) x^0+(0) x^1+(-3) x^2+(-3) x^3+(-2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-12"
]

VerificationTest[
  Module[{f=(0) x^0+(-3) x^1+(0) x^2+(0) x^3+(-3) x^4+(-2) x^5,g=(-2) x^0+(-3) x^1+(3) x^2+(-3) x^3+(-1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-13"
]

VerificationTest[
  Module[{f=(3) x^0+(0) x^1+(2) x^2+(-1) x^3,g=(-1) x^0+(-3) x^1+(2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-14"
]

VerificationTest[
  Module[{f=(0) x^0+(3) x^1+(2) x^2+(-1) x^3+(-2) x^4,g=(-2) x^0+(0) x^1+(-3) x^2+(1) x^3+(-1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-15"
]

VerificationTest[
  Module[{f=(0) x^0+(1) x^1+(1) x^2,g=(3) x^0+(3) x^1+(-3) x^2+(3) x^3+(-2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-16"
]

VerificationTest[
  Module[{f=(1) x^0+(-1) x^1+(-3) x^2+(3) x^3+(3) x^4+(1) x^5,g=(-2) x^0+(-3) x^1+(1) x^2+(-2) x^3+(1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-17"
]

VerificationTest[
  Module[{f=(-1) x^0+(-3) x^1+(-2) x^2+(1) x^3+(2) x^4,g=(-1) x^0+(1) x^1+(-3) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-18"
]

VerificationTest[
  Module[{f=(1) x^0+(-2) x^1+(1) x^2+(1) x^3,g=(2) x^0+(0) x^1+(-3) x^2+(1) x^3+(1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-19"
]

VerificationTest[
  Module[{f=(3+(-1) Sqrt[2]) x^0+(3+(-2) Sqrt[2]) x^1+(2) x^2,g=(0+(-1) Sqrt[2]) x^0+(-3+(2) Sqrt[2]) x^1+(-3+(-2) Sqrt[2]) x^2+(-1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-20"
]

VerificationTest[
  Module[{f=(-3+(1) Sqrt[2]) x^0+(1+(-2) Sqrt[2]) x^1+(2+(2) Sqrt[2]) x^2+(2+(2) Sqrt[2]) x^3+(2) x^4,g=(1+(-2) Sqrt[2]) x^0+(0+(0) Sqrt[2]) x^1+(-3+(-1) Sqrt[2]) x^2+(1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-21"
]

VerificationTest[
  Module[{f=(1+(1) Sqrt[2]) x^0+(-2+(1) Sqrt[2]) x^1+(1) x^2,g=(-2+(-2) Sqrt[2]) x^0+(-1+(2) Sqrt[2]) x^1+(1+(-1) Sqrt[2]) x^2+(0+(-1) Sqrt[2]) x^3+(2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-22"
]

VerificationTest[
  Module[{f=(2+(-2) Sqrt[2]) x^0+(0+(1) Sqrt[2]) x^1+(0+(-1) Sqrt[2]) x^2+(-3+(-1) Sqrt[2]) x^3+(-1+(1) Sqrt[2]) x^4+(2) x^5,g=(-2+(2) Sqrt[2]) x^0+(3+(0) Sqrt[2]) x^1+(-1+(-2) Sqrt[2]) x^2+(-1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-23"
]

VerificationTest[
  Module[{f=(0+(-1) Sqrt[2]) x^0+(-2+(-2) Sqrt[2]) x^1+(-3+(2) Sqrt[2]) x^2+(1) x^3,g=(-1+(1) Sqrt[2]) x^0+(-1+(-2) Sqrt[2]) x^1+(-2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-24"
]

VerificationTest[
  Module[{f=(2+(-2) Sqrt[2]) x^0+(-2+(-1) Sqrt[2]) x^1+(2+(1) Sqrt[2]) x^2+(-1) x^3,g=(2+(2) Sqrt[2]) x^0+(-2+(-1) Sqrt[2]) x^1+(1+(0) Sqrt[2]) x^2+(-1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-25"
]

VerificationTest[
  Module[{f=(1+(-1) Sqrt[2]) x^0+(1+(-2) Sqrt[2]) x^1+(-3+(2) Sqrt[2]) x^2+(2) x^3,g=(1+(0) Sqrt[2]) x^0+(-1+(-2) Sqrt[2]) x^1+(-1) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-26"
]

VerificationTest[
  Module[{f=(3+(1) Sqrt[2]) x^0+(0+(2) Sqrt[2]) x^1+(1+(2) Sqrt[2]) x^2+(1+(-1) Sqrt[2]) x^3+(1) x^4,g=(-2+(-1) Sqrt[2]) x^0+(3+(-1) Sqrt[2]) x^1+(-2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-27"
]

VerificationTest[
  Module[{f=(-3+(-2) Sqrt[2]) x^0+(-1+(2) Sqrt[2]) x^1+(-1) x^2,g=(0+(-1) Sqrt[2]) x^0+(-2+(-2) Sqrt[2]) x^1+(3+(0) Sqrt[2]) x^2+(1+(1) Sqrt[2]) x^3+(1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-28"
]

VerificationTest[
  Module[{f=(0+(-1) Sqrt[2]) x^0+(1+(2) Sqrt[2]) x^1+(0+(-1) Sqrt[2]) x^2+(1+(1) Sqrt[2]) x^3+(-2) x^4,g=(0+(-2) Sqrt[2]) x^0+(2+(2) Sqrt[2]) x^1+(1) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-29"
]

VerificationTest[
  Module[{f=(-2+(0) Sqrt[2]) x^0+(-1+(-2) Sqrt[2]) x^1+(2) x^2,g=(-3+(2) Sqrt[2]) x^0+(2+(1) Sqrt[2]) x^1+(2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-30"
]

VerificationTest[
  Module[{f=(1+(-1) Sqrt[2]) x^0+(2+(0) Sqrt[2]) x^1+(1) x^2,g=(-1+(-2) Sqrt[2]) x^0+(1+(2) Sqrt[2]) x^1+(3+(0) Sqrt[2]) x^2+(1+(1) Sqrt[2]) x^3+(1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-31"
]

VerificationTest[
  Module[{f=(1+(0) Sqrt[2]) x^0+(1+(-1) Sqrt[2]) x^1+(-1+(2) Sqrt[2]) x^2+(0+(0) Sqrt[2]) x^3+(-3+(2) Sqrt[2]) x^4+(1) x^5,g=(0+(-2) Sqrt[2]) x^0+(0+(-2) Sqrt[2]) x^1+(-2+(1) Sqrt[2]) x^2+(1+(-1) Sqrt[2]) x^3+(2) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-32"
]

VerificationTest[
  Module[{f=(1+(2) Sqrt[2]) x^0+(1+(2) Sqrt[2]) x^1+(0+(1) Sqrt[2]) x^2+(-1) x^3,g=(1+(1) Sqrt[2]) x^0+(-3+(1) Sqrt[2]) x^1+(-1+(-1) Sqrt[2]) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-33"
]

VerificationTest[
  Module[{f=(-1+(-1) Sqrt[2]) x^0+(-1+(0) Sqrt[2]) x^1+(0+(0) Sqrt[2]) x^2+(-1+(0) Sqrt[2]) x^3+(-2) x^4,g=(3+(1) Sqrt[2]) x^0+(-2+(-2) Sqrt[2]) x^1+(-2+(-1) Sqrt[2]) x^2+(-1) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-34"
]

VerificationTest[
  Module[{f=(2+(1) Sqrt[2]) x^0+(-2+(-1) Sqrt[2]) x^1+(0+(2) Sqrt[2]) x^2+(-1+(1) Sqrt[2]) x^3+(2+(1) Sqrt[2]) x^4+(-2) x^5,g=(0+(2) Sqrt[2]) x^0+(3+(0) Sqrt[2]) x^1+(-1+(-2) Sqrt[2]) x^2+(2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-35"
]

VerificationTest[
  Module[{f=(-2+(2) Sqrt[2]) x^0+(-1+(2) Sqrt[2]) x^1+(-3+(-1) Sqrt[2]) x^2+(-2+(-1) Sqrt[2]) x^3+(2) x^4,g=(1+(2) Sqrt[2]) x^0+(-3+(0) Sqrt[2]) x^1+(2+(1) Sqrt[2]) x^2+(-2+(0) Sqrt[2]) x^3+(1) x^4,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,4];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,4]];
    fn=Expand[f/.x->Coefficient[g,x,4] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-36"
]

VerificationTest[
  Module[{f=(-2+(0) Sqrt[2]) x^0+(-2+(2) Sqrt[2]) x^1+(-2+(1) Sqrt[2]) x^2+(-1+(1) Sqrt[2]) x^3+(-3+(2) Sqrt[2]) x^4+(-1) x^5,g=(2+(1) Sqrt[2]) x^0+(1+(-2) Sqrt[2]) x^1+(2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-37"
]

VerificationTest[
  Module[{f=(-3+(-2) Sqrt[2]) x^0+(3+(-2) Sqrt[2]) x^1+(1) x^2,g=(-3+(-1) Sqrt[2]) x^0+(3+(0) Sqrt[2]) x^1+(-1+(-1) Sqrt[2]) x^2+(-2) x^3,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,3];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,3]];
    fn=Expand[f/.x->Coefficient[g,x,3] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-38"
]

VerificationTest[
  Module[{f=(2+(2) Sqrt[2]) x^0+(-3+(0) Sqrt[2]) x^1+(2) x^2,g=(-1+(0) Sqrt[2]) x^0+(0+(-1) Sqrt[2]) x^1+(-2) x^2,p,c,hn,fn},
    p=Expand[f/.x->g]; c=AlgebraicDecomposeAtDegree[p,x,2];
    hn=Expand[(g-(g/.x->0))/Coefficient[g,x,2]];
    fn=Expand[f/.x->Coefficient[g,x,2] x+(g/.x->0)];
    sameChain[c,{fn,hn}] && AlgebraicVerifyDecomposition[p,AlgebraicDecompose[p,x],x,
      "RequireComplete"->True,"RequireNormalized"->True]],
  True,
  TestID -> "frozen-random-39"
]
