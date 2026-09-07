(* Native Wolfram tests. Supplied, but NOT executed in the authoring environment. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
alphaP = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
alphaS = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
u = Root[1 + # + #^3 &, 1];
v = Root[1 - # + #^3 &, 1];
w = (1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[6]);

VerificationTest[RootDegree /@ {0, 3/7, u, v, alphaP, alphaS},
  {1, 1, 3, 3, 9, 9}, TestID -> "absolute degrees"]
VerificationTest[DegreeLowerBound /@ {0, 3/7, alphaP, alphaS, w},
  {1, 1, 3, 3, 2}, TestID -> "prime divisor bounds"]
VerificationTest[{ExactRootEqualQ[alphaP, u v], ExactRootEqualQ[alphaS, u + v]},
  {True, True}, TestID -> "requested root branches"]
VerificationTest[CertifyRootDecomposition[alphaP, {u, v}, "Product"]["GlobalMinimumProved"],
  True, TestID -> "global product optimality certificate"]
VerificationTest[CertifyRootDecomposition[alphaS, {u, v}, "Sum"]["GlobalMinimumProved"],
  True, TestID -> "global sum optimality certificate"]
VerificationTest[FailureQ[CertifyRootDecomposition[alphaP, {u, v}, "Sum"]],
  True, TestID -> "wrong identity rejected"]
VerificationTest[FailureQ[RootDegree[1.25]], True, TestID -> "inexact input rejected"]
VerificationTest[RootCompositionPolynomial[x^3+x+1, x^3-x+1, x, z, "Product"],
  z^9+2 z^7-3 z^6+z^5-z^4+3 z^3-z-1, TestID -> "product resultant"]
VerificationTest[RootCompositionPolynomial[x^3+x+1, x^3-x+1, x, z, "Sum"],
  z^9+6 z^6+3 z^5-15 z^3+24 z^2-4 z+8, TestID -> "sum resultant"]
VerificationTest[RootCompositionPolynomial[2 x-1, 3 x-1, x, z, "Product"],
  z-1/6, TestID -> "nonmonic polynomial normalization"]
VerificationTest[RootDecomposition`Private`rationalSolve[{{1}, {1}}, {0, 1}],
  $Failed, TestID -> "inconsistent rational system rejected"]
VerificationTest[RootDecomposition`Private`rationalSolve[{{1, 1}}, {2}],
  {2, 0}, TestID -> "free variables set to zero"]
VerificationTest[
  With[{c = BuildRootField[Sqrt[2]/2]},
    ExactRootEqualQ[RootDecomposition`Private`fromCoordinates[c["AlphaCoordinates"], c], Sqrt[2]/2]],
  True, TestID -> "integral primitive element and coordinates"]
VerificationTest[
  With[{r = FindRootPairByHeight[alphaP, "Product", "TimeConstraint" -> 120]},
    {r["MaximumDegree"], r["GlobalMinimumProved"]}],
  {3, True}, TestID -> "automatic bounded product discovery"]
VerificationTest[
  With[{r = FindRootPairByHeight[alphaS, "Sum", "TimeConstraint" -> 120]},
    {r["MaximumDegree"], r["GlobalMinimumProved"]}],
  {3, True}, TestID -> "automatic bounded sum discovery"]
VerificationTest[
  With[{r = MinimumRootSum[alphaS, "TimeConstraint" -> 120]},
    {r["MaximumDegree"], r["GlobalMinimumProved"]}],
  {3, True}, TestID -> "structural sum discovery"]
VerificationTest[
  With[{r = MinimumRootProductPair[alphaP, "TimeConstraint" -> 120]},
    {r["MaximumDegree"], r["GlobalMinimumProved"]}],
  {3, True}, TestID -> "structural product discovery"]
VerificationTest[
  With[{e = EnumerateEmbeddedSubfields[BuildRootField[w], "TimeConstraint" -> 120]},
    {e["Complete"], Sort[#["Degree"] & /@ e["Fields"]]}],
  {True, {1, 2, 2, 2, 4}}, TestID -> "all five biquadratic subfields"]
VerificationTest[
  With[{e = EnumerateEmbeddedSubfields[BuildRootField[w], "MaxNodes" -> 0]}, e["Complete"]],
  False, TestID -> "partial subfield enumeration labeled"]
VerificationTest[
  With[{r = MinimumRootProductPair[w, "TimeConstraint" -> 120]},
    {r["MaximumDegree"], r["TwoFactorMinimumProved"], r["GlobalMinimumProved"]}],
  {4, True, False}, TestID -> "binary and arbitrary arity are not conflated"]
VerificationTest[
  With[{r = SearchRootProducts[w, {1+Sqrt[2], 1+Sqrt[3], 1+Sqrt[6]},
    "MaximumDegree" -> 2, "MaximumFactors" -> 3, "IncludeInverses" -> False,
    "TimeConstraint" -> 120]}, {r["MaximumDegree"], r["GlobalMinimumProved"]}],
  {2, True}, TestID -> "three quadratic factors found"]
VerificationTest[
  With[{r = SearchRootProducts[w, {1+Sqrt[2], 1+Sqrt[3], 1+Sqrt[6]},
    "MaximumDegree" -> 2, "MaximumFactors" -> 2, "IncludeInverses" -> False,
    "TimeConstraint" -> 120]}, {r["Status"], r["GlobalNonexistenceProved"]}],
  {"NotFoundInBounds", False}, TestID -> "bounded failure is not global impossibility"]

VerificationTest[
  With[{c = BuildRootField[3/7]},
    RootDecomposition`Private`fromCoordinates[c["AlphaCoordinates"], c]],
  3/7, TestID -> "rational ambient coordinates avoid zero to zero power"]
