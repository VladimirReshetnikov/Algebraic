(* Run with: wolframscript -file code/RunTests.wl
   Or evaluate Get[".../code/RunTests.wl"] in Mathematica. *)
Get[FileNameJoin[{DirectoryName[$InputFileName],"RootDecomposition.wl"}]];
a=Root[1+#+#^3&,1]; b=Root[1-#+#^3&,1];
prod=Root[-1-#+3#^3-#^4+#^5-3#^6+2#^7+#^9&,1];
sum=Root[8-4#+24#^2-15#^3+3#^5+6#^6+#^9&,1];
prodData=RootSubfieldData[prod]; sumData=RootSubfieldData[sum];
prodAns=RootPairDecompose[prod,"Product",prodData];
sumAns=RootPairDecompose[sum,"Sum",sumData];
report=TestReport[{
 VerificationTest[RootReduce[prod-a b],0,TestID->"OriginalProduct"],
 VerificationTest[RootReduce[sum-a-b],0,TestID->"OriginalSum"],
 VerificationTest[RootDegree /@ {prod,sum},{9,9},TestID->"InputDegrees"],
 VerificationTest[prodData["SubfieldDegrees"],{1,3,3,9},TestID->"ProductSubfields"],
 VerificationTest[sumData["SubfieldDegrees"],{1,3,3,9},TestID->"SumSubfields"],
 VerificationTest[{prodAns["MaximumDegree"],prodAns["Verified"],
   prodAns["GlobalOptimalityProved"]},{3,True,True},TestID->"OptimalProduct"],
 VerificationTest[{sumAns["MaximumDegree"],sumAns["Verified"],
   sumAns["GlobalOptimalityProved"]},{3,True,True},TestID->"OptimalSum"],
 VerificationTest[RootSumDecompose[sum,sumData]["MaximumDegree"],3,
   TestID->"AnyLengthSum"],
 VerificationTest[RootPairFromPolynomial[prod,x^3+x+1,x,"Product",3]["MaximumDegree"],3,
   TestID->"ResultantProduct"],
 VerificationTest[RootPairFromPolynomial[sum,x^3+x+1,x,"Sum",3]["MaximumDegree"],3,
   TestID->"ResultantSum"],
 VerificationTest[RootSumDecompose[Sqrt[2]+Sqrt[3]+Sqrt[5]]["MaximumDegree"],2,
   TestID->"ThreeQuadraticSummands"],
 VerificationTest[RootPairDecompose[(Sqrt[2]+Sqrt[3])/2,"Sum"]["MaximumDegree"],2,
   TestID->"NonintegralInput"],
 VerificationTest[RootPairDecompose[0,"Product"]["Components"],{0},TestID->"Zero"],
 VerificationTest[RootPairFromPolynomial[0,x^2-2,x,"Product",2]["Verified"],True,
   TestID->"ZeroResultantProduct"],
 VerificationTest[FailureQ[BoundedRootProduct[1,2,1,0]],True,
   TestID->"RejectZeroFactorBound"],
 VerificationTest[RootPairDecompose[3/7,"Sum"]["MaximumDegree"],1,TestID->"Rational"],
 VerificationTest[FailureQ[RootDegree[1.25]],True,TestID->"RejectInexact"],
 VerificationTest[RootProductFromCandidates[(1+Sqrt[2])(1+Sqrt[3])(1+Sqrt[5]),
   {1+Sqrt[2],1+Sqrt[3],1+Sqrt[5]},2,3]["MaximumDegree"],2,
   TestID->"ThreeQuadraticFactors"]
}];
Print[report];
Print["Product: ",prodAns]; Print["Sum: ",sumAns];
