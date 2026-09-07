(* These exact splitting-field tests can be expensive.
   Supplied but not executed here. Run after the basic suite. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];

VerificationTest[
  Module[{a=Root[-1-#+3 #^3-#^4+#^5-3 #^6+2 #^7+#^9&,1],g,r},
    g=BuildGaloisData[a]; r=CompleteSumDecomposition[a,g];
    {g["GroupOrder"],g["GroupExponent"],Length[g["Subfields"]],
      r["MaximumDegree"],r["GlobalOptimal"]}],
  {36,6,60,6,True}, TestID -> "degree-nine-product-as-optimal-sum"]

VerificationTest[
  Module[{a=RootReduce[Sqrt[(1+Sqrt[2]) (1+Sqrt[3])]],g,r,s},
    g=BuildGaloisData[a];
    r=CompleteTwoFactorDecomposition[a,g];
    s=CompleteSumDecomposition[a,g];
    {g["GroupOrder"],g["GroupExponent"],r["MaximumDegree"],
      r["NormExponent"],r["GlobalOptimal"],s["MaximumDegree"]}],
  {16,4,4,2,True,8}, TestID -> "external-quartic-factors"]

VerificationTest[
  Module[{a=(1+Sqrt[2]) (1+Sqrt[3]) (1+Sqrt[5]),r},
    r=CompleteTwoFactorDecomposition[a];
    Lookup[r,{"MaximumDegree","OptimalAmongTwoFactors","GlobalOptimal"}]],
  {4,True,False}, TestID -> "two-factor-optimum-not-many-factor-optimum"]

VerificationTest[
  RootReduce[
    Root[-1-#+3 #^3-#^4+#^5-3 #^6+2 #^7+#^9&,1] -
    (Root[#^6+6 #^4-27 #^3+9 #^2-81 #+4&,1] +
     Root[#^6+6 #^4-27 #^3+9 #^2-81 #+4&,2])/3],
  0, TestID -> "explicit-sextic-sum"]
