Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, z, u, v];
rTimes = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
rSum = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
f = 1 + x + x^3; g = 1 - x + x^3;
Print["Exact supplied polynomial pair:"];
Print[RootPairFromPolynomials[rTimes, {f, g}, x, "Product"]];
Print[RootPairFromPolynomials[rSum, {f, g}, x, "Sum"]];
Print["Automatic bounded discovery (may select equivalent sign variants):"];
Print[BoundedPairDecompose[rTimes, "Product", 3, 1]];
Print[BoundedPairDecompose[rSum, "Sum", 3, 1]];
Print["Complete additive method on a small splitting field:"];
small = GlobalSumDecompose[Sqrt[2] + Sqrt[3]];
Print[KeyTake[small, {"Components", "MaximumDegree", "ProvenMinimum", "FieldDegree"}]];
(* The degree-nine examples have splitting-field degree 36. Their complete
   additive searches may be much more expensive; they are not needed to
   prove the minimum once the degree-three certificates are found. *)
