(* Integration tests supplied for the user's Wolfram kernel; NOT executed
   during preparation of this archive. Python and SymPy must be available. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RadicalRoots.wl"}]];

VerificationTest[
 RootReduce[RootToRadicals[Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2],
   "NativeAttempt" -> False] - Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]],
 0, TestID -> "question-sextic"]
VerificationTest[
 RootReduce[RootToRadicals[Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5],
   "NativeAttempt" -> False] - Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]],
 0, TestID -> "question-quintic"]
VerificationTest[
 MatchQ[RootToRadicals[Root[-1 - # + #^5 &, 1], "NativeAttempt" -> False],
  Failure["NotSolvableByRadicals", _Association]],
 True, TestID -> "nonsolvable-S5"]
VerificationTest[
 And @@ Table[
   With[{r = Root[-2 + #^3 &, i]},
    TrueQ[RootReduce[RootToRadicals[r, Method -> "Galois", "NativeAttempt" -> False] - r] === 0]],
   {i, 1, 3}],
 True, TestID -> "complex-root-ordering"]
VerificationTest[RadicalExpressionQ[Cos[Pi/7]], False, TestID -> "no-hidden-trigonometry"]
VerificationTest[RadicalExpressionQ[(-1)^(2/7)], True, TestID -> "root-of-unity-is-radical"]
