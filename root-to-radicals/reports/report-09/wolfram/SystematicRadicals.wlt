(* Prospective tests: not executed in a Wolfram kernel in the build environment. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "SystematicRadicals.wl"}]];
VerificationTest[RadicalExpressionQ[(-1)^(2/7) 2^(1/7)], True, TestID -> "strict-radical-grammar"];
VerificationTest[RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "reject-root-in-output"];
VerificationTest[RadicalExpressionQ[Cos[Pi/7]], False, TestID -> "reject-trig-in-output"];
VerificationTest[Module[{r = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2], e},
 e = SystematicToRadicals[r, Method -> "Native"]; RadicalExpressionQ[e] && ExactRadicalEqualQ[e, r]],
 True, TestID -> "original-sextic-native"];
VerificationTest[Module[{r = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5], e},
 e = SystematicToRadicals[r, Method -> "Native"]; RadicalExpressionQ[e] && ExactRadicalEqualQ[e, r]],
 True, TestID -> "original-quintic-native"];
VerificationTest[Module[{r = Root[#^7 - 2 &, 4], e},
 e = SystematicToRadicals[r, Method -> "PythonFast"]; RadicalExpressionQ[e] && ExactRadicalEqualQ[e, r]],
 True, TestID -> "complex-conjugate-bridge"];
VerificationTest[Module[{r = Root[#^3 - # - 1 &, 1], e},
 e = SystematicToRadicals[r, Method -> "Galois"]; RadicalExpressionQ[e] && ExactRadicalEqualQ[e, r]],
 True, TestID -> "galois-backend"];
VerificationTest[MatchQ[SystematicToRadicals[Root[#^5 - # - 1 &, 1], Method -> "Galois"],
 Failure["NotSolvable", _Association]], True, TestID -> "nonsolvability-distinct-from-timeout"];
