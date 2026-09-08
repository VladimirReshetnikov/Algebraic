(* These tests are supplied for a real Wolfram kernel. They were not executed
   in the preparation environment. Run TestReport on this file. *)
Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]], "SystematicRadicals.wl"}]];

VerificationTest[RadicalExpressionQ[(1 + I)^(1/5) - Sqrt[2]], True,
  TestID -> "strict-radical-grammar-positive"]
VerificationTest[RadicalExpressionQ[Cos[Pi/7]], False,
  TestID -> "strict-radical-grammar-negative"]
VerificationTest[VerifyRadical[Sqrt[2], Sqrt[2]], True,
  TestID -> "exact-equality-positive"]
VerificationTest[VerifyRadical[Sqrt[2], -Sqrt[2]], False,
  TestID -> "conjugates-are-not-equal"]
VerificationTest[Radicalize[3/7], 3/7, TestID -> "rational"]
VerificationTest[
  Module[{a = Root[#^6 + #^4 - #^3 - #^2 - 1 &, 2], b},
    b = Radicalize[a, Method -> "Native", "TimeLimit" -> 120];
    RadicalExpressionQ[b] && VerifyRadical[a, b]], True,
  TestID -> "original-sextic-native"]
VerificationTest[
  Module[{a = Root[5 #^5 - 25 #^3 + 25 # + 6 &, 5], b},
    b = Radicalize[a, Method -> "Native", "TimeLimit" -> 120];
    RadicalExpressionQ[b] && VerifyRadical[a, b]], True,
  TestID -> "original-quintic-native"]
VerificationTest[
  MatchQ[Radicalize[1.0], Failure["InvalidInput", _Association]], True,
  TestID -> "inexact-rejected"]
VerificationTest[
  Module[{a = Root[#^3 - 3 # + 1 &, 1], b},
    b = Radicalize[a, Method -> "Galois", "TimeLimit" -> 120];
    RadicalExpressionQ[b] && VerifyRadical[a, b]], True,
  TestID -> "python-galois-bridge"]
VerificationTest[
  MatchQ[Radicalize[Root[#^5 - # - 1 &, 1], Method -> "Galois"],
    Failure["NotSolvable", _Association]], True,
  TestID -> "exact-nonsolvability"]
