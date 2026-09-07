(* Run with Get["/path/to/code/Examples.wl"], or evaluate selected sections. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[alphaP, alphaS, u, v, w, p, s, rP, rS];
alphaP = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
alphaS = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
u = Root[1 + # + #^3 &, 1];
v = Root[1 - # + #^3 &, 1];

(* Certification of the exact requested branches, independent of discovery. *)
Print[CertifyRootDecomposition[alphaP, {u, v}, "Product"]];
Print[CertifyRootDecomposition[alphaS, {u, v}, "Sum"]];

(* Direct recovery formulas, derived in the article. *)
With[{p = alphaP},
  With[{delta = p^3 + p - 1},
    With[{a = -(delta p + 1)/(delta^2 + p + 1)},
      Print[RootReduce /@ {a, a - delta}]]]];
With[{s = alphaS},
  With[{a = (3 s^5 - 5 s^3 - 3 s^2 + 2 s - 4)/(6 s^4 - 6 s + 4)},
    Print[RootReduce /@ {a, s - a}]]];

(* Discovery: no input cubic pair is supplied. A simultaneous sign change of
   the two product factors is an equally valid answer. *)
rP = FindRootPairByHeight[alphaP, "Product", "MaximumDegree" -> 3,
  "CoefficientHeight" -> 1, "TimeConstraint" -> 120];
rS = FindRootPairByHeight[alphaS, "Sum", "MaximumDegree" -> 3,
  "CoefficientHeight" -> 1, "TimeConstraint" -> 120];
Print[rP]; Print[rS];

(* Structural searches start in Q(alpha), not in a large normal closure.
   Either cubic witness is globally optimal by the prime-divisor bound. *)
Print[MinimumRootSum[alphaS, "TimeConstraint" -> 120]];
Print[MinimumRootProductPair[alphaP, "TimeConstraint" -> 120]];

(* Arbitrary arity versus two factors. *)
w = (1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[6]);
Print[SearchRootProducts[w, {1 + Sqrt[2], 1 + Sqrt[3], 1 + Sqrt[6]},
  "MaximumDegree" -> 2, "MaximumFactors" -> 3, "IncludeInverses" -> False,
  "TimeConstraint" -> 120]];
(* The two-factor minimum is 4, whereas the arbitrary-arity minimum is 2. *)
Print[MinimumRootProductPair[w, "TimeConstraint" -> 120]];

(* For an exhaustive GLOBAL sum or two-factor search on a different small
   input, explicitly request a normal closure and remove search budgets:
   MinimumRootSum[a, "NormalClosure" -> True,
     "MaximumAmbientDegree" -> Infinity, "MaxNodes" -> Infinity,
     "TimeConstraint" -> Infinity]
   This is a finite algorithm but can be prohibitively expensive.
*)
