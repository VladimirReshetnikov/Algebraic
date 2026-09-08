(* Run in a licensed Wolfram kernel: TestReport["tests/RadicalRoot.wlt"]. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "wolfram", "RadicalRoot.wl"}]];
VerificationTest[RadicalExpressionQ[(-1)^(2/7) + Sqrt[2]], True, TestID -> "radical-grammar-positive"]
VerificationTest[RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "radical-grammar-negative"]
VerificationTest[VerifyRadical[Sqrt[2], -Sqrt[2]], False, TestID -> "wrong-conjugate"]
VerificationTest[Module[{a = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5], r},
  r = RootToRadicals[a, Method -> "Fast"]; VerifyRadical[a, r]], True,
  TestID -> "question-quintic"]
VerificationTest[Module[{a = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2], r},
  r = RootToRadicals[a, Method -> "Fast"]; VerifyRadical[a, r]], True,
  TestID -> "question-sextic"]
VerificationTest[Module[{a = Root[(# + 1)^5 + 2 &, 1], r},
  r = RootToRadicals[a, Method -> "Fast"]; VerifyRadical[a, r]], True,
  TestID -> "shifted-binomial"]
VerificationTest[Module[{a = Root[#^3 - 2 &, 1], r},
  r = RadicalSolve[a, Method -> "Galois", TimeConstraint -> 300];
  AssociationQ[r] && VerifyRadical[a, r["Expression"]]], True,
  TestID -> "kummer-cubic"]
VerificationTest[Module[{a = Root[#^4 - 2 &, 1], r},
  r = RadicalSolve[a, Method -> "Galois", TimeConstraint -> 300];
  AssociationQ[r] && VerifyRadical[a, r["Expression"]]], True,
  TestID -> "kummer-quartic"]
VerificationTest[Module[{x, y, r}, r = PairSumResolvent[x^6 + x^4 - x^3 - x^2 - 1, x, y];
  PolynomialRemainder[r, y^3 + 4 y - 1, y]], 0, TestID -> "pair-resolvent"]
VerificationTest[FailureQ[RootToRadicals[0.1]], True, TestID -> "reject-inexact"]
VerificationTest[MatchQ[RadicalSolve[Root[#^3 - 2 &, 1], Method -> "Galois",
  "MaxFieldDegree" -> 2], Failure["ResourceLimit", _]], True, TestID -> "resource-limit"]
