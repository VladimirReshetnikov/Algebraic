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
VerificationTest[Module[{y}, AllTrue[{
    {2/3, True, 0}, {-2 + 3 I, True, 0}, {1. + I, False, 0},
    {(1 + Sqrt[2])^(2/3), True, 2}, {2^Sqrt[2], False, 1},
    {y^2, False, 0}, {y^(1/3), False, 1}, {(y + Sqrt[2])^(1/3), False, 2},
    {Sin[Sqrt[2]], False, 0}, {HoldForm[Sqrt[2]], False, 0}, {{Sqrt[2]}, False, 0},
    {True, False, 0}, {Root[#^5 - # - 1 &, 1], False, 0}},
  {RadicalExpressionQ[First[#]], RadicalDepth[First[#]]} === Rest[#] &]], True,
  TestID -> "typed grammar and depth preserve exact approximate symbolic and unsupported heads"];

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

VerificationTest[Module[{run},
  run[failures_] := Module[{precisions = {}, result},
    result = Block[{RootToRadicals`Private`$opts = {"WorkingPrecision" -> 80},
        RootToRadicals`Private`$galoisInfo, RootToRadicals`Private`descend},
      RootToRadicals`Private`descend[gd_, a_, primes_, form_] := (
        AppendTo[precisions, gd["Precision"]];
        If[Length[precisions] <= failures, Throw["precision", RootToRadicals`Private`precTag]];
        <|"Expression" -> Sqrt[2], "ExtendedGroupOrder" -> gd["Order"], "SeriesPrimes" -> {2}|>);
      RootToRadicals`Private`galoisRadicals[Sqrt[2], RootToRadicals`Private`x^2 - 2]];
    {precisions, If[FailureQ[result], result[[1]], result]}];
  {run[1], run[3]}], {{{80, 160}, Sqrt[2]}, {{80, 160, 320}, "Precision"}},
  TestID -> "descent without odd primes refreshes field precision and retains three-attempt limit"];

(* forced descent on the two examples of the question *)
rg6 = RootRadicalReport[a6, Method -> "Galois"];
VerificationTest[rg6["Verified"], True, TestID -> "sextic example by descent"];
VerificationTest[{rg6["GaloisGroupOrder"], rg6["ExtendedGroupOrder"]}, {24, 48}, TestID -> "sextic example group orders"];
rg5 = RootRadicalReport[a5, Method -> "Galois"];
VerificationTest[rg5["Verified"], True, TestID -> "quintic example by descent"];
VerificationTest[{rg5["GaloisGroupOrder"], rg5["ExtendedGroupOrder"]}, {20, 40}, TestID -> "quintic example group orders"];

(* Each suffix of quotient generators generates the corresponding subgroup. *)
VerificationTest[Module[{x, gd, H, index, steps, generators, identity, fixedSpace, basis},
  And @@ Table[
    gd = RootGaloisData[case[[1]], x]; H = Range[gd["Order"]];
    If[case[[2]] != 0,
      index = First@FirstPosition[gd["Roots"], _?(RootReduce[# - gd["Scale"] Exp[2 Pi I/case[[2]]]] === 0 &)];
      H = Select[H, gd["Permutations"][[#, index]] == index &]];
    identity = IdentityMatrix[gd["Order"]];
    fixedSpace[group_] := RowReduce[NullSpace[Join @@ (gd["Automorphisms"][[#]] - identity & /@ group)]];
    steps = RootToRadicals`Private`primeSeries[gd["MultiplicationTable"], gd["Identity"], H];
    {gd["Order"], Length[H]} == case[[3]] && And @@ Table[
      generators = steps[[i ;;, "Generator"]]; basis = fixedSpace[generators];
      RootDecomposition`Private`groupClosure[gd["MultiplicationTable"], gd["Identity"], generators] == steps[[i, "Group"]] &&
        basis == fixedSpace[steps[[i, "Group"]]] && Length[basis] Length[steps[[i, "Group"]]] == gd["Order"] &&
        AllTrue[basis, RootToRadicals`Private`fixedByQ[gd, #, steps[[i, "Group"]]] &], {i, Length[steps]}],
    {case, {{x^3 - 3 x + 1, 0, {3, 3}}, {x^4 - x - 1, 0, {24, 24}},
      {(x^5 + x^4 - 4 x^3 - 3 x^2 + 3 x + 1) Cyclotomic[5, x], 5, {20, 5}}}}]],
  True, TestID -> "series generator suffixes preserve exact fixed spaces including extended base"];

VerificationTest[Module[{perms, mt, H, allPairs, expected, actual, collections},
  allPairs[table_, id_, group_] := Module[{inv = Association @@ Table[g -> First[FirstPosition[table[[g]], id]], {g, group}]},
    RootDecomposition`Private`groupClosure[table, id,
      DeleteDuplicates[Flatten[Table[table[[table[[inv[g], inv[h]]], table[[g, h]]]], {g, group}, {h, group}]]]]];
  And @@ Table[
    perms = Permutations[Range[n]]; H = Range[Length[perms]];
    mt = Table[First@FirstPosition[perms, g[[h]]], {g, perms}, {h, perms}];
    actual = RootToRadicals`Private`primeSeries[mt, 1, H];
    expected = Block[{RootToRadicals`Private`commutatorSubgroup},
      RootToRadicals`Private`commutatorSubgroup[table_, id_, group_] := allPairs[table, id, group];
      RootToRadicals`Private`primeSeries[mt, 1, H]];
    collections = {{}, {1}, H, Reverse[H], Take[H, 3], Join[Take[H, 3], Take[H, 3]]};
    actual === expected && RootToRadicals`Private`solvableQ[mt, 1, H] === (n == 4) &&
      RootToRadicals`Private`commutatorSubgroup[mt, 1, H] === Pick[H, Signature /@ perms, 1] &&
      And @@ Table[RootToRadicals`Private`commutatorSubgroup[mt, 1, collection] === allPairs[mt, 1, collection],
        {collection, collections}], {n, {4, 5}}]],
  True, TestID -> "unordered commutators preserve derived groups, exact series, and partial collections"];

(* Exact coordinate powers agree with the former matrix route, including nonintegral elements. *)
VerificationTest[Module[{gd, vectors, one},
  gd = RootGaloisData[RootDecomposition`Private`x^3 - 2,
    RootDecomposition`Private`x, "WorkingPrecision" -> 80];
  one = UnitVector[gd["Order"], 1];
  vectors = {0 one, gd["RootCoordinates"][[2]],
    gd["RootCoordinates"][[1]]/3 + gd["RootCoordinates"][[2]]/7,
    10^40 one + ConstantArray[1/7, gd["Order"]]};
  And @@ Flatten[Table[
    RootDecomposition`Private`powerCoordinates[gd, v, k] ==
      If[k == 0, one, MatrixPower[RootDecomposition`Private`multiplicationMatrixOfElement[gd, v], k] . one],
    {v, vectors}, {k, {0, 1, 2, 3, 5}}]]],
  True, TestID -> "coordinate powers match matrices including precision fallback"];

VerificationTest[Module[{gd, one, numerators, denominators, divide, matrix},
  gd = RootGaloisData[RootDecomposition`Private`x^3 - 2, RootDecomposition`Private`x, "WorkingPrecision" -> 80];
  one = UnitVector[gd["Order"], 1];
  numerators = {0 one, one, gd["RootCoordinates"][[2]], 10^100 one + ConstantArray[1, gd["Order"]]};
  denominators = {one, gd["RootCoordinates"][[2]],
    gd["RootCoordinates"][[1]]/3 + gd["RootCoordinates"][[2]]/7,
    10^40 one + ConstantArray[1/7, gd["Order"]], one/10^100};
  FailureQ[RootDecomposition`Private`powerDivider[gd, 0 one]] && And @@ Flatten[Table[
    divide = RootDecomposition`Private`powerDivider[gd, denominator];
    matrix = RootDecomposition`Private`multiplicationMatrixOfElement[gd, denominator];
    Table[divide[numerator, k] == If[k == 0, numerator, LinearSolve[MatrixPower[matrix, k], numerator]],
      {numerator, numerators}, {k, {0, 1, 2, 3, 5}}], {denominator, denominators}]]],
  True, TestID -> "coordinate quotients match solves including norm and trace fallback"];

VerificationTest[Module[{gd, denominator, numerator, divide, matrix},
  gd = RootGaloisData[RootDecomposition`Private`x^3 - 3 RootDecomposition`Private`x + 1,
    RootDecomposition`Private`x, "WorkingPrecision" -> 80];
  denominator = gd["RootCoordinates"][[1]];
  numerator = UnitVector[gd["Order"], 1]/5 + gd["RootCoordinates"][[2]]/7;
  divide = RootDecomposition`Private`powerDivider[gd, denominator];
  matrix = RootDecomposition`Private`multiplicationMatrixOfElement[gd, denominator];
  RootDecomposition`Private`roundInteger[Times @@ RootDecomposition`Private`conjugates[gd, denominator]] == -1 &&
    And @@ Table[divide[numerator, k] == LinearSolve[MatrixPower[matrix, k], numerator], {k, {1, 2, 3, 5}}]],
  True, TestID -> "coordinate quotients preserve negative norm signs in odd degree"];

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
