(* Run from this directory, or replace the path below by an absolute path. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, a, b, productTarget, sumTarget];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
productTarget = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
sumTarget = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

Print["Exact verification of the requested answers:"];
Print[VerifyRootDecomposition[productTarget, {a, b}, Times]];
Print[VerifyRootDecomposition[sumTarget, {a, b}, Plus]];

Print["Recover the second polynomial from a proposed first polynomial:"];
Print[RootPairFromPolynomial[productTarget, 1 + x + x^3, x, Times, 3]];
Print[RootPairFromPolynomial[sumTarget, 1 + x + x^3, x, Plus, 3]];

Print["Search without supplying either cubic:"];
Print[FindRootPair[productTarget, Times, 3, 1, "TimeLimit" -> 120]];
Print[FindRootPair[sumTarget, Plus, 3, 1, "TimeLimit" -> 120]];

(* Optional, expensive exact field methods. Uncomment to run.
model = BuildNormalFieldModel[sumTarget,
  "TimeLimit" -> 1800, "MaxNormalDegree" -> 48];
If[! FailureQ[model],
  Print[CompleteSumDecomposition[sumTarget, model]];
  Print[CompleteProductPairDecomposition[productTarget, model]]
];
The two targets generate the same degree-nine field; their normal closure
has degree 36. Its group has 60 subgroups.
*)

(* An arbitrary-length sum, not replaceable by two quadratic summands. *)
threeSquareRoots = RootReduce[Sqrt[2] + Sqrt[3] + Sqrt[5]];
Print[DictionaryRootDecomposition[threeSquareRoots,
  {Sqrt[2], Sqrt[3], Sqrt[5]}, Plus, 2, 3]];

(* A product of three cubics whose minimal polynomial has degree 27. *)
c = Root[3 + # + #^3 &, 1];
threeCubics = RootReduce[a b c];
Print[DictionaryRootDecomposition[threeCubics, {a, b, c}, Times, 3, 3,
  "TimeLimit" -> 180]];
