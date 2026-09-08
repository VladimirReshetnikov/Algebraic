(* Load wolfram/RadicalRoot.wl first, then run TestReport["tests/RadicalRoot.wlt"].
   The first two tests are native; the others need configured Python/SymPy.
   These tests were supplied but NOT executed in the delivery environment. *)
VerificationTest[RadicalExpressionQ[Sqrt[2] + I^(1/3)], True, TestID -> "radical-grammar"]
VerificationTest[RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "root-is-not-radical"]
VerificationTest[RadicalRoot[Sqrt[2]], Sqrt[2], TestID -> "native-square-root"]
VerificationTest[
 With[{r = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]},
   RootReduce[RadicalRoot[r, "UseNative" -> False] - r]],
 0, TestID -> "original-sextic"]
VerificationTest[
 With[{r = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]},
   RootReduce[RadicalRoot[r, "UseNative" -> False] - r]],
 0, TestID -> "original-quintic"]
VerificationTest[
 MatchQ[RadicalRoot[Root[#^5 - # - 1 &, 1], "UseNative" -> False],
   Failure["NotSolvableByRadicals", _Association]],
 True, TestID -> "negative-solvability"]
VerificationTest[
 MatchQ[RadicalRoot[1.25], Failure["InexactInput", _Association]],
 True, TestID -> "reject-machine-input"]
