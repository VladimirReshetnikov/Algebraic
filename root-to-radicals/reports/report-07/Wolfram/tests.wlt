(* Load SystematicRadicals.wl before TestReport[thisFile].
   These tests were supplied but NOT EXECUTED in the preparation environment. *)
VerificationTest[
 Module[{a=Root[-1-#^2-#^3+#^4+#^6&,2],r},
  r=RadicalSolve[a,Method->"Practical"];
  r["Status"]==="Success" && RadicalVerify[a,r["Expression"]]],
 True,TestID->"Original-sextic-exact"]
VerificationTest[
 Module[{a=Root[6+25#-25#^3+5#^5&,5],r},
  r=RadicalSolve[a,Method->"Practical"];
  r["Status"]==="Success" && RadicalVerify[a,r["Expression"]]],
 True,TestID->"Original-quintic-exact"]
VerificationTest[
 And@@Table[With[{a=Root[6+25#-25#^3+5#^5&,k]},
   Module[{r=RadicalSolve[a,Method->"Practical"]},
    r["Status"]==="Success" && RadicalVerify[a,r["Expression"]]]],{k,5}],
 True,TestID->"All-five-Dickson-branches"]
VerificationTest[
 Module[{a=Root[#^3-2&,1],r},
  r=RadicalSolve[a,Method->"Complete",TimeConstraint->120];
  r["Status"]==="Success" && RadicalTowerVerify[r] && RadicalVerify[a,r["Expression"]]],
 True,TestID->"Forced-Kummer-cubic"]
VerificationTest[
 Module[{a=Root[#^4+1&,1],r},
  r=RadicalSolve[a,Method->"Complete",TimeConstraint->120];
  r["Status"]==="Success" && RadicalTowerVerify[r]],
 True,TestID->"Forced-Kummer-complex-quartic"]
VerificationTest[
 Module[{a=Root[#^4-2&,2],r},
  r=RadicalSolve[a,Method->"Complete",TimeConstraint->120];
  r["Status"]==="Success" && RadicalTowerVerify[r]],
 True,TestID->"Forced-Kummer-nonabelian-quartic"]
VerificationTest[
 Module[{x,t,p,r},p=x^6+x^4-x^3-x^2-1;r=PairSumResolvent[p,x,t];
  Expand[Resultant[p,p/.x->t-x,x]-2^6 (p/.x->t/2) r^2]===0],
 True,TestID->"Pair-resolvent-identity"]
VerificationTest[RadicalSolve[1.25]["Status"],"InvalidInput",TestID->"Reject-inexact"]
VerificationTest[RadicalSolve[Root[#^2-a&,1]]["Status"],"InvalidInput",TestID->"Reject-parameter"]
VerificationTest[RadicalSolve[3/7]["Expression"],3/7,TestID->"Rational-input"]
VerificationTest[RadicalExpressionQ[Root[#^5-#-1&,1]],False,TestID->"Strict-grammar-Root"]
VerificationTest[RadicalExpressionQ[Cos[Pi/7]],False,TestID->"Strict-grammar-trig"]
VerificationTest[RadicalVerify[Sqrt[2],-Sqrt[2]],False,TestID->"Wrong-conjugate"]
VerificationTest[
 RadicalSolve[Root[#^3-2&,1],Method->"Complete","MaxFieldDegree"->2]["Status"],
 "Inconclusive",TestID->"Resource-is-not-impossibility"]
