(* Wolfram Language regression tests. Supplied for local execution;
   these were NOT run in a Wolfram kernel during preparation. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, ap, as, a, b, fp, fs, p, q, dp, ds, rp, rs, u4, u8];
p = x^3 + x + 1;
q = x^3 - x + 1;
fp = x^9 + 2 x^7 - 3 x^6 + x^5 - x^4 + 3 x^3 - x - 1;
fs = x^9 + 6 x^6 + 3 x^5 - 15 x^3 + 24 x^2 - 4 x + 8;
ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];

VerificationTest[RootReduce[ap - a b], 0, TestID -> "product-identity"]
VerificationTest[RootReduce[as - a - b], 0, TestID -> "sum-identity"]
VerificationTest[RootProductPolynomial[p, q, x], fp, TestID -> "product-resultant"]
VerificationTest[RootSumPolynomial[p, q, x], fs, TestID -> "sum-resultant"]
VerificationTest[IrreduciblePolynomialQ /@ {fp, fs}, {True, True},
  TestID -> "irreducible-nonics"]
VerificationTest[CountRoots[#, x] & /@ {fp, fs}, {1, 1},
  TestID -> "unique-real-branches"]
VerificationTest[AlgebraicDegree /@ {ap, as, a, b}, {9, 9, 3, 3},
  TestID -> "absolute-degrees"]
VerificationTest[DegreeLowerBound /@ {ap, as, 1/2, Sqrt[2]}, {3, 3, 1, 2},
  TestID -> "degree-lower-bounds"]

VerificationTest[
  Module[{aa, bb},
    aa = -(x^7 + 2 x^5 - 2 x^4 + 1)/2;
    bb = -(x^7 + 2 x^5 - 2 x^4 + 2 x^3 + 2 x - 1)/2;
    PolynomialRemainder[#, fp, x] & /@
      {aa^3 + aa + 1, bb^3 - bb + 1, aa bb - x}
  ], {0, 0, 0}, TestID -> "product-polynomial-certificate"]
VerificationTest[
  Module[{aa, bb},
    aa = -(2025 x^8 + 750 x^7 - 4374 x^6 + 10530 x^5 +
      9975 x^4 - 28868 x^3 - 51921 x^2 - 12496 x + 39992)/83732;
    bb = x - aa;
    PolynomialRemainder[#, fs, x] & /@
      {aa^3 + aa + 1, bb^3 - bb + 1, aa + bb - x}
  ], {0, 0, 0}, TestID -> "sum-polynomial-certificate"]

VerificationTest[
  dp = FieldDecompositionData[ap];
  If[AssociationQ[dp], Sort[Length /@ dp["Subfields"]], dp],
  {1, 3, 3, 9}, TestID -> "product-subfield-lattice"]
VerificationTest[
  ds = FieldDecompositionData[as];
  If[AssociationQ[ds], Sort[Length /@ ds["Subfields"]], ds],
  {1, 3, 3, 9}, TestID -> "sum-subfield-lattice"]
VerificationTest[
  rp = ProductDecomposition[ap];
  If[AssociationQ[rp], {rp["MaximumDegree"], rp["IdentityVerified"],
    rp["GlobalOptimalityCertified"]}, rp],
  {3, True, True}, TestID -> "optimal-product-example"]
VerificationTest[
  If[AssociationQ[rp], Sort[MinimalPolynomial[#, x] & /@ rp["Terms"]], rp],
  Sort[{p, q}], TestID -> "product-cubic-polynomials-after-normalization"]
VerificationTest[
  rs = GlobalAdditiveDecomposition[as];
  If[AssociationQ[rs], {rs["MaximumDegree"], rs["IdentityVerified"],
    rs["GlobalOptimalityCertified"]}, rs],
  {3, True, True}, TestID -> "optimal-sum-example"]
VerificationTest[
  AdditiveDecomposition[0]["Terms"], {0}, TestID -> "zero-sum"]
VerificationTest[
  ProductDecomposition[0]["Terms"], {0}, TestID -> "zero-product"]
VerificationTest[
  AdditiveDecomposition[1/2]["MaximumDegree"], 1,
  TestID -> "nonintegral-rational"]
VerificationTest[
  FailureQ[AdditiveDecomposition[1.25]], True, TestID -> "inexact-rejected"]
VerificationTest[
  FailureQ[BoundedDecompositionSearch[ap, "Product", 0, 1, 2]], True,
  TestID -> "invalid-search-bounds"]

VerificationTest[
  u4 = RootReduce[Sqrt[2] + Sqrt[3] + Sqrt[6]];
  Module[{r = AdditiveDecomposition[u4]},
    If[AssociationQ[r], {r["MaximumDegree"], Length[r["Terms"]],
      r["GlobalOptimalityCertified"]}, r]],
  {2, 3, True}, TestID -> "three-term-sum"]
VerificationTest[
  u8 = RootReduce[(1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5])];
  Module[{r = ProductDecomposition[u8]},
    If[AssociationQ[r], {r["MaximumDegree"], Length[r["Terms"]],
      r["IdentityVerified"], r["GlobalOptimalityCertified"]}, r]],
  {2, 3, True, True}, TestID -> "three-factor-tensor-product"]
VerificationTest[
  Module[{h, s, r},
    h = {Root[-1 - # + #^4 &, 1], Root[-1 - # + #^4 &, 2]};
    s = RootReduce[Total[h]];
    r = AdditiveDecomposition[s];
    If[AssociationQ[r], {r["MaximumDegree"],
      r["GlobalOptimalityCertified"]}, r]],
  {6, False}, TestID -> "ambient-field-restriction-is-real"]
