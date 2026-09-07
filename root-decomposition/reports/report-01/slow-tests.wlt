(* Exhaustive additive tests: potentially expensive; use a native WL kernel. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
VerificationTest[MinimumSumDecomposition[RootReduce[a+b]]["MaximumDegree"], 3,
  TestID -> "complete-additive-sum9"]
VerificationTest[MinimumSumDecomposition[RootReduce[a b]]["MaximumDegree"], 6,
  TestID -> "complete-additive-product9"]
VerificationTest[MinimumSumDecomposition[Sqrt[2]+Sqrt[3]+Sqrt[5]]["MaximumDegree"], 2,
  TestID -> "complete-additive-multiquadratic8"]
VerificationTest[MinimumSumDecomposition[Sqrt[1+Sqrt[2]] Sqrt[1+Sqrt[7]]]["MaximumDegree"], 8,
  TestID -> "complete-additive-counterexample8"]
