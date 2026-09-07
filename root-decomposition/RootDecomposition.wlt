(* Regression tests for RootDecomposition.wl.
   Run with  TestReport["RootDecomposition.wlt"]  from this directory, or
   wolfram -script RunTests.wl  (see RunTests.wl).  *)

BeginTestSection["RootDecomposition"];

Get[FileNameJoin[{DirectoryName[$TestFileName /. "" -> $InputFileName /. "" -> Directory[]], "RootDecomposition.wl"}]];

ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
u = Root[1 + # + #^3 &, 1];
v = Root[1 - # + #^3 &, 1];

VerificationTest[RootDecompositionLowerBound[ap], 3, TestID -> "lower bound of the product example"];
VerificationTest[RootDecompositionLowerBound[Sqrt[2] + Sqrt[3]], 2, TestID -> "lower bound of sqrt2+sqrt3"];
VerificationTest[RootDecompositionLowerBound[Root[#^5 - # - 1 &, 1]], 5, TestID -> "prime degree"];
VerificationTest[RootDecompositionLowerBound[Root[#^4 - # - 1 &, 1]], 4, TestID -> "S4 exponent bound"];

VerificationTest[RootDecompositionVerify[ap, {u, v}, Times]["Verified"], True, TestID -> "verify product identity"];
VerificationTest[RootDecompositionVerify[as, {u, v}, Plus]["Verified"], True, TestID -> "verify sum identity"];

gd = RootGaloisData[ap];
VerificationTest[gd["Order"], 36, TestID -> "Galois group order S3 x S3"];
VerificationTest[gd["Exponent"], 6, TestID -> "Galois group exponent"];
VerificationTest[Tally[gd["SubfieldDegrees"]], {{1, 1}, {2, 3}, {3, 6}, {4, 1}, {6, 20}, {9, 9}, {12, 4}, {18, 15}, {36, 1}}, TestID -> "subfield degree distribution"];

rp = RootProductDecomposition[ap];
VerificationTest[Sort[rp["Terms"]], Sort[{u, v}], TestID -> "product example recovers the two cubics"];
VerificationTest[rp["MaximumDegree"], 3, TestID -> "product example maximum degree"];
VerificationTest[rp["Optimal"], True, TestID -> "product example optimal"];
VerificationTest[rp["Verified"], True, TestID -> "product example verified"];

rs = RootSumDecomposition[as];
VerificationTest[Sort[rs["Terms"]], Sort[{u, v}], TestID -> "sum example recovers the two cubics"];
VerificationTest[rs["MaximumDegree"], 3, TestID -> "sum example maximum degree"];
VerificationTest[rs["Optimal"], True, TestID -> "sum example optimal"];

rs6 = RootSumDecomposition[ap];
VerificationTest[rs6["MaximumDegree"], 6, TestID -> "product root as a sum needs sextics"];
VerificationTest[rs6["Optimal"], True, TestID -> "sextic sum is globally optimal"];
VerificationTest[rs6["Verified"], True, TestID -> "sextic sum verified"];
VerificationTest[RootSumDecomposition[ap, "Scope" -> "InputField"]["MaximumDegree"], 9, TestID -> "inside Q(a) the product root is additively indecomposable"];

e3 = RootReduce[Sqrt[2] + Sqrt[3] + Sqrt[6]];
VerificationTest[RootSumDecomposition[e3]["MaximumDegree"], 2, TestID -> "sqrt2+sqrt3+sqrt6 is a sum of quadratics"];
VerificationTest[FailureQ[RootSumDecomposition[e3, 3, "MaxTerms" -> 2]], True, TestID -> "sqrt2+sqrt3+sqrt6 is not a binary sum"];
VerificationTest[RootProductDecomposition[e3, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "sqrt2+sqrt3+sqrt6 is not a binary product"];

g1 = RootReduce[I + Sqrt[2] + I Sqrt[2]];
VerificationTest[FailureQ[RootSumDecomposition[g1, 3, "MaxTerms" -> 2]], True, TestID -> "i+sqrt2+i sqrt2 is not a binary sum"];
VerificationTest[RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals"]["MaximumDegree"], 2, TestID -> "Gaussian coefficients"];

eta = RootReduce[(1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5])];
VerificationTest[RootProductDecomposition[eta]["MaximumDegree"], 2, TestID -> "three quadratic factors"];
VerificationTest[RootProductDecomposition[eta, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "two-factor optimum is four"];

q = RootReduce[1 + Sqrt[2] + Sqrt[3]];
VerificationTest[RootSumDecomposition[q]["MaximumDegree"], 2, TestID -> "1+sqrt2+sqrt3 sum"];
VerificationTest[RootProductDecomposition[q, "MaxFactors" -> 2]["MaximumDegree"], 4, TestID -> "1+sqrt2+sqrt3 two-factor product"];

ext = RootReduce[Sqrt[(1 + Sqrt[2]) (1 + Sqrt[3])]];
rext = RootProductDecomposition[ext];
VerificationTest[rext["MaximumDegree"], 4, TestID -> "external quartic factors"];
VerificationTest[rext["NormExponent"], 2, TestID -> "norm exponent two"];
VerificationTest[RootSumDecomposition[ext]["MaximumDegree"], 8, TestID -> "external example is additively indecomposable"];

s6 = Root[-1 + 4 #^2 + #^6 &, 3];
VerificationTest[RootSumDecomposition[s6]["MaximumDegree"], 4, TestID -> "pair sum of quartic roots"];
VerificationTest[RootSumDecomposition[s6, "Scope" -> "InputField"]["MaximumDegree"], 6, TestID -> "pair sum inside its own field"];

VerificationTest[RootSumDecomposition[RootReduce[Exp[2 Pi I/5]]]["MaximumDegree"], 4, TestID -> "fifth root of unity"];
VerificationTest[RootSumDecomposition[7/3]["Terms"], {7/3}, TestID -> "rational input"];
VerificationTest[FailureQ[RootSumDecomposition[1.5]], True, TestID -> "inexact input rejected"];

VerificationTest[RootBoundedDecomposition[ap, Times, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded product search"];
VerificationTest[RootBoundedDecomposition[as, Plus, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded sum search"];

EndTestSection[];
