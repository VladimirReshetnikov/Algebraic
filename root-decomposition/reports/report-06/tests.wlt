(* Run from this directory after Get["RootDecomposition.wl"],
   or execute TestReport["tests.wlt"].  Native-kernel tests are supplied,
   not claimed to have been run during preparation. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, a, b, productInput, sumInput, pp, ps];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
pp = x^9 + 2 x^7 - 3 x^6 + x^5 - x^4 + 3 x^3 - x - 1;
ps = x^9 + 6 x^6 + 3 x^5 - 15 x^3 + 24 x^2 - 4 x + 8;
productInput = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
sumInput = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
VerificationTest[RootReduce[a b - productInput], 0, TestID -> "original product identity"]
VerificationTest[RootReduce[a + b - sumInput], 0, TestID -> "original sum identity"]
VerificationTest[AlgebraicDegree /@ {a,b,productInput,sumInput}, {3,3,9,9}, TestID -> "absolute degrees"]
VerificationTest[ComposedPolynomial[x^3+x+1,x^3-x+1,x,"Product"], pp, TestID -> "product resultant"]
VerificationTest[ComposedPolynomial[x^3+x+1,x^3-x+1,x,"Sum"], ps, TestID -> "sum resultant"]
VerificationTest[AllSubfieldBases[productInput]["Degrees"], {1,3,3,9}, TestID -> "product subfields"]
VerificationTest[AllSubfieldBases[sumInput]["Degrees"], {1,3,3,9}, TestID -> "sum subfields"]
VerificationTest[MinTwoFactorInField[productInput]["MaxDegree"], 3, TestID -> "automatic product optimum"]
VerificationTest[MinSumInField[sumInput]["MaxDegree"], 3, TestID -> "automatic additive optimum"]
VerificationTest[MinSumGlobally[sumInput]["GlobalMinimumCertified"], True, TestID -> "global additive certificate"]
VerificationTest[MinSumInField[productInput]["MaxDegree"], 9, TestID -> "internal sum differs from global sum"]
VerificationTest[MinTwoFactorInField[sumInput]["MaxDegree"], 9, TestID -> "internal two-factor negative result"]
VerificationTest[MinSumInField[3/7]["MaxDegree"], 1, TestID -> "rational input"]
VerificationTest[MinTwoFactorInField[0]["MaxDegree"], 1, TestID -> "zero product input"]
VerificationTest[MinSumInField[(Sqrt[2]+Sqrt[3])/5]["MaxDegree"], 2, TestID -> "nonintegral input generator"]
VerificationTest[PairFromPolynomials[productInput,x^3+x+1,x^3-x+1,x,"Product"]["ExactIdentityVerified"], True, TestID -> "branch certificate"]
VerificationTest[FailureQ[AllSubfieldBases[productInput,"MaxDivisors"->1]], True, TestID -> "resource limit is failure"]
VerificationTest[FailureQ[AlgebraicDegree[1.25]], True, TestID -> "reject inexact input"]
VerificationTest[FiniteCatalogSearch[8,{2},"Product",3]["ExactIdentityVerified"], True, TestID -> "singleton finite catalog"]
VerificationTest[FailureQ[FiniteCatalogSearch[7,{2},"Product",3]], True, TestID -> "finite catalog no result"]
VerificationTest[
 With[{r1=Root[4-81#+9#^2-27#^3+6#^4+#^6&,1],
       r2=Root[4-81#+9#^2-27#^3+6#^4+#^6&,2]},
  RootReduce[(r1+r2)/3-productInput]], 0,
 TestID -> "global sextic additive decomposition of product input"]

VerificationTest[ExactRootList[(x^2-2)^2,x],
 {-Sqrt[2],Sqrt[2]}, TestID -> "repeated polynomial roots are deduplicated"]
