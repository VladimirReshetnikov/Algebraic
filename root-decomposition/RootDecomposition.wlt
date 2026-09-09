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

VerificationTest[Module[{data, matrices, one, auts, perms, products},
  data = RootGaloisData[Root[#^4 - # - 1 &, 1]];
  matrices = RootDecomposition`Private`multiplicationMatrixOfElement[data, #] & /@ data["RootCoordinates"];
  one = UnitVector[data["Order"], 1]; auts = data["Automorphisms"]; perms = data["Permutations"];
  products = Association[Thread[perms -> auts]];
  And @@ Flatten[Table[auts[[s]] . one == one &&
      And @@ Table[auts[[s]] . matrices[[i]] == matrices[[perms[[s, i]]]] . auts[[s]], {i, Length[matrices]}],
    {s, data["Order"]}]] &&
    And @@ Flatten[Table[auts[[s]] . auts[[t]] == products[perms[[s]][[perms[[t]]]]],
      {s, data["Order"]}, {t, data["Order"]}]]],
  True, TestID -> "S4 automorphisms preserve field multiplication and noncommutative composition"];

VerificationTest[Module[{data = RootGaloisData[RootDecomposition`Private`x - 2, RootDecomposition`Private`x]},
  data["Automorphisms"]], {{{1}}}, TestID -> "trivial Galois action with no generators"];

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
VerificationTest[FailureQ[RootSumDecomposition[1.5]], True, {RootDecomposition::inexact}, TestID -> "inexact input rejected"];

VerificationTest[RootBoundedDecomposition[ap, Times, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded product search"];
VerificationTest[RootBoundedDecomposition[as, Plus, 3, 1, 2]["MaximumDegree"], 3, TestID -> "bounded sum search"];

(* Public bounds and certificate semantics, including paths that return early. *)
VerificationTest[FailureQ[RootSumDecomposition[Sqrt[2], 1]], True, TestID -> "sum degree bound survives trivial shortcut"];
VerificationTest[FailureQ[RootProductDecomposition[Sqrt[2], 1]], True, TestID -> "product degree bound survives trivial shortcut"];
VerificationTest[And @@ (FailureQ /@ {RootSumDecomposition[1, 0], RootProductDecomposition[0, 0],
  RootSumDecomposition[e3, "MaxTerms" -> 0], RootProductDecomposition[eta, "MaxFactors" -> 0],
  RootProductDecomposition[eta, "Scope" -> "Typo"], RootGaloisData[Sqrt[2], "WorkingPrecision" -> 0]}),
  True, TestID -> "invalid options rejected before early returns"];
VerificationTest[And @@ (FailureQ /@ {RootGaloisData[0, x], RootGaloisData[1, x], RootGaloisData[x^2 + Pi, x],
  RootGaloisData[x^2 + 1., x], RootGaloisData[(x - 1)^2, x]}), True, TestID -> "invalid Galois polynomials rejected"];
VerificationTest[And @@ (FailureQ /@ {RootBoundedDecomposition[1, Plus, 1, 1, 0],
  RootBoundedDecomposition[1, Times, 0, 1, 1], RootDecompositionCatalog[1, 0]}), True, TestID -> "invalid dictionary bounds rejected"];
VerificationTest[RootSumDecomposition[q, "MaxTerms" -> 1]["MaximumDegree"], 4, TestID -> "single summand means input itself"];
VerificationTest[RootProductDecomposition[eta, "MaxFactors" -> 1]["MaximumDegree"], 8, TestID -> "single factor means input itself"];
VerificationTest[FailureQ[RootProductDecomposition[eta, 2, "MaxFactors" -> 1]], True, TestID -> "single factor degree bound enforced"];
VerificationTest[With[{r = RootSumDecomposition[q, 2, "MaxTerms" -> 2]},
  {r["Verified"], Length[r["Terms"]], r["MaximumDegree"], r["Optimal"]}],
  {True, 2, 2, True}, TestID -> "trace centering respects two summands and certifies explicit bound"];
VerificationTest[With[{r = RootSumDecomposition[e3, "MaxTerms" -> 2]},
  {r["MaximumDegree"], r["Optimal"], r["ScopeOptimal"]}], {4, False, True},
  TestID -> "binary optimum does not certify unrestricted sum optimum"];
VerificationTest[With[{r = RootProductDecomposition[q, "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, True, True},
  TestID -> "binary product certificate has explicit scope"];

(* These inputs share an integral model but have different scaling metadata. *)
cacheA = RootGaloisData[x^2 - 2, x];
cacheB = RootGaloisData[2 x^2 - 1, x];
VerificationTest[{cacheA["Scale"], cacheB["Scale"]}, {1, 2}, TestID -> "Galois cache preserves input scale"];
VerificationTest[Quiet[FailureQ[RootGaloisData[Sqrt[2], "MaxGroupOrder" -> 1]]], True,
  TestID -> "cached Galois data respects a tighter group limit"];
VerificationTest[With[{xx = RootDecomposition`Private`x},
  {RootDecomposition`Private`inputFieldData[xx^4 - 10 xx^2 + 8]["Scale"],
   RootDecomposition`Private`inputFieldData[2 xx^4 - 5 xx^2 + 1]["Scale"]}], {1, 2},
  TestID -> "input field cache preserves input scale"];

VerificationTest[FailureQ[RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals", "MaxTerms" -> 2]],
  True, TestID -> "finite Gaussian term count is explicitly unsupported"];
VerificationTest[RootSumDecomposition[7/3, "Coefficients" -> "GaussianRationals"]["Terms"], {{1, 7/3}},
  TestID -> "Gaussian trivial result uses coefficient root pairs"];
VerificationTest[With[{r = RootSumDecomposition[I/2, "Coefficients" -> "GaussianRationals"]},
  {r["Verified"], r["MaximumDegree"]}], {True, 1}, TestID -> "Gaussian imaginary unit coordinates respect integral scaling"];
VerificationTest[With[{r = RootSumDecomposition[I Sqrt[2], "Coefficients" -> "GaussianRationals", "Scope" -> "InputField"]},
  {r["Verified"], r["MaximumDegree"]}], {True, 2}, TestID -> "Gaussian input field scope retains permitted roots"];

VerificationTest[With[{r = RootProductDecomposition[eta, "MaxFactors" -> 3, "BoundedSearch" -> None, "RecursionDepth" -> 0]},
  {r["Verified"], r["MaximumDegree"], Length[r["Terms"]], r["Method"], r["ScopeOptimal"]}], {True, 2, 3, "TensorRankOne", True},
  TestID -> "tensor search starts at many factor lower bound and respects factor count"];
VerificationTest[With[{r = RootProductDecomposition[3 eta/2, 2, "MaxFactors" -> 3, "BoundedSearch" -> None, "RecursionDepth" -> 0]},
  {r["Verified"], r["MaximumDegree"], Length[r["Terms"]]}], {True, 2, 3},
  TestID -> "product normalization absorbs rational factor within cap"];
VerificationTest[FailureQ[RootProductDecomposition[ext, 4, "Scope" -> "InputField", "MaxFactors" -> 2]], True,
  TestID -> "input field scope excludes external radical factors"];
VerificationTest[RootDecompositionVerify[0, {}, Plus]["MaximumDegree"], 1, TestID -> "empty sum degree convention"];
VerificationTest[RootDecompositionVerify[Sqrt[2], {N[Sqrt[2]]}, Plus]["Verified"], False,
  TestID -> "inexact terms cannot obtain exact verification"];
VerificationTest[With[{r = RootSumDecomposition[ap, "Engine" -> "InputField"]},
  {r["Optimal"], r["ScopeOptimal"]}], {False, False}, TestID -> "forced input field sum cannot certify global exhaustion"];
VerificationTest[With[{r = RootProductDecomposition[ext, "Engine" -> "InputField", "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, False, False},
  TestID -> "forced input field product cannot certify global exhaustion"];
VerificationTest[With[{r = RootProductDecomposition[ext, "Scope" -> "InputField", "MaxFactors" -> 2]},
  {r["Optimal"], r["ScopeOptimal"], r["TwoFactorOptimal"]}], {False, True, True},
  TestID -> "two factor certificate is relative to requested input field scope"];
VerificationTest[RootSumDecomposition[10^100 + Sqrt[2]]["Verified"], True,
  TestID -> "exact branch identification survives indistinguishable numerical roots"];
VerificationTest[RootBoundedDecomposition[Sqrt[2] + Sqrt[3], Plus, 4, 3, 2]["ScopeOptimal"], False,
  TestID -> "bounded feasibility shortcut does not certify minimal degree"];

VerificationTest[RootDecomposition`Private`groupClosure[Table[Mod[i + j - 2, 4] + 1, {i, 4}, {j, 4}], 1, {3}],
  {1, 3}, TestID -> "shared subgroup closure generates the order two subgroup"];
VerificationTest[Module[{attempts = {}, result},
  result = Quiet[RootDecomposition`Private`retryPrecision[Function[p, AppendTo[attempts, p];
    If[p < 40, Throw["precision", RootDecomposition`Private`precTag], p]], 10], RootDecomposition::prec];
  {result, attempts}], {40, {10, 20, 40}}, TestID -> "shared precision retry doubles until success"];
VerificationTest[Module[{attempts = {}, result},
  result = Quiet[RootDecomposition`Private`retryPrecision[Function[p, AppendTo[attempts, p];
    Throw["precision", RootDecomposition`Private`precTag]], 10], RootDecomposition::prec];
  {FailureQ[result], attempts}], {True, {10, 20, 40, 80}}, TestID -> "shared precision retry preserves four attempt limit"];

VerificationTest[Module[{data = RootGaloisData[x^3 - 2, x], one, result},
  one = UnitVector[data["Order"], 1];
  And @@ Table[RootDecomposition`Private`elementToAlgebraic[data, q one] === q, {q, {0, -2/7, 7/3}}] &&
    And @@ Table[
      result = RootDecomposition`Private`elementToAlgebraic[data, one + data["RootCoordinates"][[j]]/3];
      RootReduce[result - 1 - data["Roots"][[j]]/3] === 0 &&
        MinimalPolynomial[result, x] === Expand[27 (x - 1)^3 - 2], {j, 3}]],
  True, TestID -> "exact element orbits preserve rational real complex and nonintegral branches"];
VerificationTest[Module[{data = RootGaloisData[x^2 - 2, x, "WorkingPrecision" -> 30], result, den = 10^40},
  And @@ Table[
    result = RootDecomposition`Private`elementToAlgebraic[data, UnitVector[2, 1] + data["RootCoordinates"][[j]]/den];
    RootReduce[result - 1 - data["Roots"][[j]]/den] === 0 &&
      MinimalPolynomial[result, x] === Expand[(den^2 (x - 1)^2 - 2)/2], {j, 2}]],
  True, TestID -> "exact element orbits preserve extremely close conjugate branches"];

VerificationTest[And @@ Table[Module[{data = RootGaloisData[p, x], snapshot, one, pairs, den},
  snapshot = data; one = UnitVector[data["Order"], 1];
  pairs = Join[{{0 one, 0}, {one/7, 1/7}},
    Table[{one + data["RootCoordinates"][[j]]/3, 1 + data["Roots"][[j]]/3}, {j, Length[data["Roots"]]}],
    {{10^40 one + data["RootCoordinates"][[1]]/7, 10^40 + data["Roots"][[1]]/7}}];
  AllTrue[pairs, Function[pair, den = LCM @@ Denominator[pair[[1]]];
    RootDecomposition`Private`coordinatesFromConjugates[data,
      RootDecomposition`Private`conjugates[data, den pair[[1]]]]/den === pair[[1]] &&
      RootDecomposition`Private`elementDegree[data, pair[[1]]] === Exponent[MinimalPolynomial[pair[[2]], x], x]]] &&
    data === snapshot], {p, {x - 2, x^3 - 2, x^3 - 3 x + 1, x^4 + 1}}], True,
  TestID -> "shared trace coordinates and stabilizer degrees preserve exact real complex and rational elements"];
VerificationTest[With[{data = <|"Values" -> IdentityMatrix[2], "GramInverse" -> IdentityMatrix[2]|>},
  RootDecomposition`Private`coordinatesFromConjugates[data, {2, -3}] === {2, -3} &&
    AllTrue[{{1/3, 0}, {I, 0}, {N[1, 8], 0}},
      Catch[RootDecomposition`Private`coordinatesFromConjugates[data, #], RootDecomposition`Private`precTag] === "precision" &]],
  True, TestID -> "shared trace coordinates retain tagged noninteger imaginary and low accuracy failures"];

VerificationTest[And @@ Table[
  Module[{data = RootGaloisData[p, x], values},
    values = RootDecomposition`Private`valuesAtPrecision[data, 2 data["Precision"]];
    RootDecomposition`Private`basisValues[data["NumericRoots"], data["Permutations"], data["Tower"],
      data["BasisExponents"]] === data["Values"] &&
      RootDecomposition`Private`roundIntegerMatrix[Transpose[values] . values] === data["Gram"]],
  {p, {x - 2, x^3 - 2, x^4 - x - 1}}], True,
  TestID -> "shared basis evaluation preserves exact trace matrices at higher precision"];

VerificationTest[RootDecompositionCatalog[1, 2], {2, 1, 1/2, 0, -1, -1/2, -2},
  TestID -> "catalog preserves positive leading coefficient enumeration order"];
VerificationTest[RootDecompositionCatalog[2, 1], Join[{1, 0, -1}, Flatten[Table[
  RootDecomposition`Private`rootObject[p /. x -> RootDecomposition`Private`x, j],
  {p, {-1 - x + x^2, -1 + x + x^2, 1 - x + x^2, 1 + x^2, 1 + x + x^2}}, {j, 2}]]],
  TestID -> "catalog preserves quadratic polynomial and branch order"];
VerificationTest[Check[Module[{data = RootGaloisData[x, x, "Cache" -> False]},
  {data["Order"], data["Values"], data["RootCoordinates"],
   RootDecomposition`Private`valuesAtPrecision[data, 2 data["Precision"]]}], $Failed],
  {1, {{1}}, {{0}}, {{1}}}, TestID -> "zero root field avoids indeterminate zero powers"];
VerificationTest[Check[Module[{data = RootGaloisData[x (x^2 - 2), x, "Cache" -> False], values},
  values = RootDecomposition`Private`valuesAtPrecision[data, 2 data["Precision"]];
  {data["Order"], RootDecomposition`Private`roundIntegerMatrix[Transpose[values] . values] === data["Gram"]}], $Failed],
  {2, True}, TestID -> "splitting field containing zero preserves trace matrices without messages"];

VerificationTest[With[{xx = RootDecomposition`Private`x},
  {RootDecomposition`Private`frobeniusCycleType[xx^2 - xx - 1, 2],
   RootDecomposition`Private`frobeniusCycleType[xx^2 - xx - 1, 11],
   RootDecomposition`Private`frobeniusCycleType[2 xx^2 - 1, 3]}],
  {{2}, {1, 1}, {2}}, TestID -> "shared Frobenius helper returns sorted nonconstant factor degrees"];
VerificationTest[Check[RootDecomposition`Private`frobeniusExponentMultiple[RootDecomposition`Private`x^3 - 2, 0], $Failed],
  1, TestID -> "zero Frobenius prime budget gives neutral exponent without messages"];
VerificationTest[Check[With[{p = RootDecomposition`Private`x^4 - Times @@ Prime[Range[60]]},
  {RootDecomposition`Private`frobeniusExponentMultiple[p, 40], RootDecomposition`Private`lowerBoundFromPolynomial[p]}], $Failed],
  {1, 2}, TestID -> "finite Frobenius prime window with no good primes preserves valid lower bound"];

VerificationTest[RootDecomposition`Private`powerSums[1, 0], {}, TestID -> "Newton sums preserve the empty degree zero range"];
VerificationTest[And @@ Table[With[{xx = RootDecomposition`Private`x, n = Length[roots]},
  RootDecomposition`Private`powerSums[Expand[Times @@ (xx - roots)], n] ===
    Prepend[Table[Total[roots^k], {k, 1, n - 1}], n]],
  {roots, {{0}, {-3, 0, 0, 2}, {1, 1, 1, 1, 1}, {-5, -2, 1, 3, 4, 7}}}], True,
  TestID -> "Newton sums match independent root powers including repeated and zero roots"];
VerificationTest[And @@ Table[Module[{xx = RootDecomposition`Private`x, n, matrix},
  n = Exponent[p, x];
  matrix = Table[If[i == j + 1, 1, 0] - If[j == n, Coefficient[p, x, i - 1], 0], {i, n}, {j, n}];
  RootDecomposition`Private`powerSums[p /. x -> xx, n] === Table[Tr[MatrixPower[matrix, k]], {k, 0, n - 1}]],
  {p, {2 - 3 x + x^2, x^3 - 2, 1 + x + x^2 + x^3 + x^4}}], True,
  TestID -> "Newton sums match exact companion matrix traces for real and complex roots"];

VerificationTest[Module[{spaces = Table[<|"Basis" -> {UnitVector[4, i]}|>, {i, 4}]},
  And @@ Table[RootDecomposition`Private`findSumRepresentation[Take[spaces, count], UnitVector[4, 4], Infinity] === $Failed,
    {count, 0, 3}] &&
  RootDecomposition`Private`findSumRepresentation[spaces, {1, 1, 0, 0}, Infinity] ===
    Table[{spaces[[i]], UnitVector[4, i]}, {i, 2}]], True,
  TestID -> "sum span search preserves empty failures and first successful subset order"];
VerificationTest[Module[{spaces = Table[<|"Basis" -> {UnitVector[4, i]}|>, {i, 4}], expected},
  expected = Table[{spaces[[i]], UnitVector[4, i]}, {i, 4}];
  RootDecomposition`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, Infinity] === expected &&
    RootDecomposition`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, 3] === $Failed &&
    RootDecomposition`Private`findSumRepresentation[spaces, {1, 1, 1, 1}, 4] === expected], True,
  TestID -> "sum span search retains full space fallback and finite term caps"];
VerificationTest[With[{spaces = Table[<|"Basis" -> {UnitVector[5, i]}|>, {i, 4}]},
  RootDecomposition`Private`findSumRepresentation[spaces, UnitVector[5, 5], Infinity]], $Failed,
  TestID -> "unrestricted sum rejects an impossible full span"];

VerificationTest[Module[{x = RootDecomposition`Private`x, roots, data, a, poly},
  roots = Join[Flatten[Table[Root[Function @@ {p /. x -> Slot[1]}, k, mode],
      {p, {x^5 - x - 1, x^8 - 2}}, {k, Exponent[p, x]}, {mode, {0, 1}}]],
    {1 + Sqrt[2], Sqrt[2] + I Sqrt[3], 1 + Sqrt[2]/10^50}];
  a = Root[#^5 - # - 1 &, 2]; poly = (x^5 - x - 1) (x^2 - 2);
  (* The stored index is 2, but this larger polynomial places the same root at 4. *)
  RootDecomposition`Private`rootIndexOf[a, poly] === 4 && AllTrue[roots,
    Function[value, data = RootDecomposition`Private`inputData[value];
      IntegerQ[data["Index"]] && 1 <= data["Index"] <= data["Degree"] &&
        RootReduce[value - RootDecomposition`Private`rootObject[data["Polynomial"], data["Index"]]] === 0]]],
  True, TestID -> "stored Root indices are verified and mismatched candidates retain exact fallback"];

EndTestSection[];
