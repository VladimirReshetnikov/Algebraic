(* Wolfram regression suite. Not executed in a Wolfram kernel during preparation. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x];
f = x^3+x+1; g = x^3-x+1;
pm = x^9+2x^7-3x^6+x^5-x^4+3x^3-x-1;
ps = x^9+6x^6+3x^5-15x^3+24x^2-4x+8;
am = First[RDRoots[pm,x]]; as = First[RDRoots[ps,x]];
u = Root[#^3+#+1&,1]; v = Root[#^3-#+1&,1];

VerificationTest[Expand[RDCompose[f,g,x,"Product"]-pm],0,TestID->"forward-product"]
VerificationTest[Expand[RDCompose[f,g,x,"Sum"]-ps],0,TestID->"forward-sum"]
VerificationTest[{RDZeroQ[am-u v],RDZeroQ[as-u-v]},{True,True},TestID->"branches"]
VerificationTest[{RDDegree[am],RDDegree[as],RDDegree[u],RDDegree[v]},{9,9,3,3},TestID->"absolute-degrees"]
VerificationTest[RDComplementPolynomials[pm,f,x,3,"Product"],{g},TestID->"inverse-product"]
VerificationTest[RDComplementPolynomials[ps,f,x,3,"Sum"],{g},TestID->"inverse-sum"]
VerificationTest[Module[{r=RDSplitWithPolynomial[am,f,x,3,"Product"]},
  {RDVerify[am,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,3,True},TestID->"fixed-first-product"]
VerificationTest[Module[{r=RDSplitWithPolynomial[as,f,x,3,"Sum"]},
  {RDVerify[as,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,3,True},TestID->"fixed-first-sum"]
VerificationTest[Module[{r=RDBoundedSplit[am,3,1,"Product"]},
  {RDVerify[am,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,3,True},TestID->"catalog-product"]
VerificationTest[Module[{r=RDBoundedSplit[as,3,1,"Sum"]},
  {RDVerify[as,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,3,True},TestID->"catalog-sum"]
VerificationTest[Expand[RDCompose[x^2-2,x^2-2,x,"Sum"]-x^2(x^2-8)],0,TestID->"repeated-sum-values"]
VerificationTest[Expand[RDCompose[x^2-2,x^2-2,x,"Product"]-(x^2-4)^2],0,TestID->"repeated-product-values"]
VerificationTest[Module[{a=Sqrt[2]+Sqrt[3]+Sqrt[5],r},
 r=RDPoolSplit[a,{Sqrt[2],Sqrt[3],Sqrt[5]},2,3,"Sum"];
 {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,2,True},TestID->"three-summands"]
VerificationTest[Module[{a=(1+Sqrt[2])(1+Sqrt[3])(1+Sqrt[5]),r},
 r=RDPoolSplit[a,{1+Sqrt[2],1+Sqrt[3],1+Sqrt[5]},2,3,"Product"];
 {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,2,True},TestID->"three-factors"]
VerificationTest[FailureQ[RDDegree[0.5]],True,TestID->"reject-inexact"]
VerificationTest[Module[{a=Root[#^5-#-1&,1],r=RDGlobalSum[Root[#^5-#-1&,1]]},
 {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,5,True},TestID->"prime-degree-obstruction"]

VerificationTest[Module[{a=(Sqrt[2]+Sqrt[3])/2,r},
 r=RDSplitWithPolynomial[a,2x^2-1,x,2,"Sum"];
 {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],{True,2,True},TestID->"nonmonic-first-polynomial"]
