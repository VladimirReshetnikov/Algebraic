(* Regression tests for RootToRadicals.wl.
   Run with  TestReport["RootToRadicals.wlt"]  from this directory, or
   wolfram -script RunTests.wl  (see RunTests.wl).  *)

BeginTestSection["RootToRadicals"];

Get[FileNameJoin[{DirectoryName[$TestFileName /. "" -> $InputFileName /. "" -> Directory[]], "RootToRadicals.wl"}]];

a6 = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];          (* first example of the question *)
a5 = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];            (* second example of the question *)
c5 = Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 1];  (* cyclic quintic, 2 cos(2 Pi/11) *)

(* radical grammar *)
VerificationTest[RadicalExpressionQ[(1 + Sqrt[5])/2], True, TestID -> "grammar: golden ratio"];
VerificationTest[RadicalExpressionQ[(-1)^(2/5) 7^(1/5) + I/3], True, TestID -> "grammar: roots of unity and I"];
VerificationTest[RadicalExpressionQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "grammar: Root is not a radical"];
VerificationTest[RadicalExpressionQ[Cos[Pi/7]], False, TestID -> "grammar: trigonometric"];
VerificationTest[RadicalExpressionQ[2^Sqrt[2]], False, TestID -> "grammar: irrational exponent"];
VerificationTest[RadicalDepth[Sqrt[1 + Sqrt[2]]], 2, TestID -> "depth: nested"];
VerificationTest[RadicalDepth[Sqrt[2]^3 + 1/Sqrt[3]], 1, TestID -> "depth: integer powers do not nest"];
VerificationTest[RadicalDepth[7/3], 0, TestID -> "depth: rational"];

(* the built-in function fails on all three *)
VerificationTest[Head[ToRadicals[a6]], Root, TestID -> "built-in ToRadicals fails on the sextic"];
VerificationTest[Head[ToRadicals[a5]], Root, TestID -> "built-in ToRadicals fails on the quintic"];
VerificationTest[Head[ToRadicals[c5]], Root, TestID -> "built-in ToRadicals fails on the cyclic quintic"];

(* first example: generalized reciprocal symmetry *)
r6 = RootRadicalReport[a6];
VerificationTest[r6["Verified"], True, TestID -> "sextic example verified"];
VerificationTest[r6["Method"], "Reciprocal", TestID -> "sextic example method"];
VerificationTest[RootReduce[r6["Expression"] - a6], 0, TestID -> "sextic example exact identity"];
VerificationTest[RadicalExpressionQ[r6["Expression"]], True, TestID -> "sextic example is a radical expression"];
VerificationTest[Table[RootRadicalReport[Root[-1 - #^2 - #^3 + #^4 + #^6 &, k]]["Verified"], {k, 6}],
  ConstantArray[True, 6], TestID -> "sextic example all conjugates"];

(* second example: Dickson polynomial 5 (D_5(x, 1) + 6/5) *)
r5 = RootRadicalReport[a5];
VerificationTest[r5["Verified"], True, TestID -> "quintic example verified"];
VerificationTest[r5["Method"], "Dickson", TestID -> "quintic example method"];
VerificationTest[r5["RadicalDepth"], 1, TestID -> "quintic example depth"];
VerificationTest[RootReduce[r5["Expression"] - (((-3 + 4 I)/5)^(1/5) + ((-3 - 4 I)/5)^(1/5))], 0,
  TestID -> "quintic example equals the closed form of the question"];
VerificationTest[Table[RootRadicalReport[Root[6 + 25 # - 25 #^3 + 5 #^5 &, k]]["Verified"], {k, 5}],
  ConstantArray[True, 5], TestID -> "quintic example all conjugates"];

(* the cyclic quintic needs the general descent *)
rc = RootRadicalReport[c5];
VerificationTest[rc["Verified"], True, TestID -> "cyclic quintic verified"];
VerificationTest[rc["Method"], "Galois", TestID -> "cyclic quintic method"];
VerificationTest[{rc["GaloisGroupOrder"], rc["ExtendedGroupOrder"], rc["SeriesPrimes"]}, {5, 20, {5}},
  TestID -> "cyclic quintic group data"];
VerificationTest[RootRadicalReport[c5, "Resolvents" -> "Fourier"]["Verified"], True, TestID -> "cyclic quintic Fourier form"];
VerificationTest[RootRadicalReport[c5, "Resolvents" -> "Eigenvector"]["Verified"], True, TestID -> "cyclic quintic eigenvector form"];
VerificationTest[RootToRadicals[Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 3]] // RadicalExpressionQ, True,
  TestID -> "cyclic quintic other conjugate"];

(* forced descent on small solvable cases *)
VerificationTest[RootRadicalReport[Root[#^3 - 2 &, 2], Method -> "Galois"]["Verified"], True, TestID -> "descent x^3-2"];
VerificationTest[RootRadicalReport[Root[#^3 - 3 # + 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^3-3x+1"];
VerificationTest[RootRadicalReport[Root[#^4 - 2 &, 4], Method -> "Galois"]["Verified"], True, TestID -> "descent x^4-2"];
VerificationTest[RootRadicalReport[Root[#^4 - 10 #^2 + 1 &, 4], Method -> "Galois"]["Verified"], True, TestID -> "descent x^4-10x^2+1"];
VerificationTest[RootRadicalReport[Root[#^5 - 2 &, 3], Method -> "Galois"]["Verified"], True, TestID -> "descent x^5-2"];
VerificationTest[RootRadicalReport[Root[#^8 + 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^8+1"];
VerificationTest[RootRadicalReport[Root[Cyclotomic[7, #] &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent Phi_7"];
VerificationTest[RootRadicalReport[Root[#^6 - 2 #^3 - 1 &, 1], Method -> "Galois"]["Verified"], True, TestID -> "descent x^6-2x^3-1"];

(* forced descent on the two examples of the question *)
rg6 = RootRadicalReport[a6, Method -> "Galois"];
VerificationTest[rg6["Verified"], True, TestID -> "sextic example by descent"];
VerificationTest[{rg6["GaloisGroupOrder"], rg6["ExtendedGroupOrder"]}, {24, 48}, TestID -> "sextic example group orders"];
rg5 = RootRadicalReport[a5, Method -> "Galois"];
VerificationTest[rg5["Verified"], True, TestID -> "quintic example by descent"];
VerificationTest[{rg5["GaloisGroupOrder"], rg5["ExtendedGroupOrder"]}, {20, 40}, TestID -> "quintic example group orders"];

(* structural families *)
rd10 = RootRadicalReport[Root[#^10 + #^8 - 4 #^6 - 3 #^4 + 3 #^2 + 1 &, 5]];   (* c5's polynomial composed with x^2 *)
VerificationTest[rd10["Verified"], True, TestID -> "decomposition verified"];
VerificationTest[rd10["Method"], "Decompose", TestID -> "decomposition method"];
VerificationTest[
  And @@ Table[With[{a = Root[#^8 - 2 &, k]},
    RootReduce[RootToRadicals`Private`structuralDecompose[a,
      RootToRadicals`Private`x^8 - 2, 6] - a] === 0], {k, 8}],
  True, TestID -> "three-component decomposition all conjugates"];
rd7 = RootRadicalReport[Root[#^7 - 7 #^5 + 14 #^3 - 7 # - 3 &, 1]];             (* D_7(x, 1) - 3 *)
VerificationTest[rd7["Verified"], True, TestID -> "Dickson verified"];
VerificationTest[rd7["Method"], "Dickson", TestID -> "Dickson method"];
rps = RootRadicalReport[Root[3 - 9 # + 6 #^2 - 7 #^3 - #^6 &, 1], Method -> "Structural"];   (* pair sums of degree 3 *)
VerificationTest[rps["Verified"], True, TestID -> "pair-sum verified"];
VerificationTest[rps["Method"], "PairSum", TestID -> "pair-sum method"];
VerificationTest[RootRadicalReport[c5, Method -> "Structural"][[1]], "NotFound", TestID -> "structural search exhausted"];
rext = RootRadicalReport[a6, "Extension" -> {Root[#^3 + 4 # - 1 &, 1]}];   (* the subfield Q(a - 1/a) given explicitly *)
VerificationTest[rext["Verified"], True, TestID -> "extension option verified"];
VerificationTest[rext["Method"], "Extension", TestID -> "extension option method"];
VerificationTest[RootRadicalReport[a6, "Extension" -> {1.5}][[1]], "InvalidOptions", {RootToRadicals::opts}, TestID -> "extension option validation"];

(* negative results *)
VerificationTest[RootRadicalReport[Root[#^5 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^5-x-1 not solvable"];
VerificationTest[RootRadicalReport[Root[#^7 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^7-x-1 not solvable"];
VerificationTest[RootRadicalReport[Root[#^6 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^6-x-1 not solvable (long prime cycle)"];
VerificationTest[RootRadicalReport[Root[#^6 + #^4 + 3 #^2 - 2 # + 5 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "sextic with group of order 120"];
VerificationTest[RootRadicalReport[Root[#^8 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^8-x-1 not solvable (prime-power degree)"];
VerificationTest[RootRadicalReport[Root[#^9 - # - 1 &, 1]][[1]], "NotSolvable", {RootToRadicals::notsolv}, TestID -> "x^9-x-1 not solvable (prime-power degree)"];
VerificationTest[RootSolvableQ[Root[#^5 - # - 1 &, 1]], False, TestID -> "RootSolvableQ negative"];
VerificationTest[RootSolvableQ[Root[#^9 - # - 1 &, 1]], False, TestID -> "RootSolvableQ negative, degree 9"];
VerificationTest[RootSolvableQ[c5], True, TestID -> "RootSolvableQ cyclic quintic"];
VerificationTest[RootSolvableQ[a6], True, TestID -> "RootSolvableQ sextic example"];
VerificationTest[RootSolvableQ[Root[#^4 - # - 1 &, 1]], True, TestID -> "RootSolvableQ quartic"];

(* resource limits, trivial and invalid input *)
VerificationTest[RootRadicalReport[Root[#^4 - # - 1 &, 1], Method -> "Galois", "MaxGroupOrder" -> 10][[1]], "ResourceLimit",
  TestID -> "group order limit (Frobenius order multiple)"];
VerificationTest[RootRadicalReport[Root[#^4 - # - 1 &, 1], Method -> "Galois", "MaxGroupOrder" -> 12][[1]], "ResourceLimit",
  {RootDecomposition::order}, TestID -> "group order limit (engine)"];
VerificationTest[RootToRadicals[3/4], 3/4, TestID -> "rational input"];
VerificationTest[RootToRadicals[1 + Sqrt[2]], 1 + Sqrt[2], TestID -> "radical input is returned"];
VerificationTest[RootRadicalReport[1.5][[1]], "Inexact", {RootToRadicals::inexact}, TestID -> "inexact input"];
VerificationTest[RootRadicalReport[Pi][[1]], "NotAlgebraic", {RootDecomposition::notalg}, TestID -> "transcendental input"];
VerificationTest[RootRadicalReport[Root[#^3 - 2 &, 1], Method -> "Nope"][[1]], "InvalidOptions", {RootToRadicals::opts}, TestID -> "invalid option"];

EndTestSection[];
