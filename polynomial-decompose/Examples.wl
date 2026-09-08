(* Worked functional-composition examples; run wolfram.exe -script Examples.wl. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "AlgebraicDecomposition.wl"}]];
Clear[x];
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x + (12 + 26 Sqrt[2]) x^2 +
  (56 + 8 Sqrt[2]) x^3 + (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[p, x];
Print["Question polynomial: ", p];
Print["Complete normalized chain, outermost first: ", chain];
Print["Verified: ", VerifyAlgebraicDecomposition[p, chain, x,
  "RequireComplete" -> True, "RequireNormalized" -> True]];
Print["Nested example degrees: ", Exponent[#, x] & /@
  AlgebraicDecompose[Expand[p /. x -> x^4 - x + 1], x]];
Print["All normalized chains of T6: ", AlgebraicDecompositions[ChebyshevT[6, x], x]];
Print["Every right pair of x^12: ", AlgebraicDecompositionPairs[x^12, x]];
negative = AlgebraicDecompositionData[x^6 + x, x];
Print["Indecomposability data: ", negative];
Print["Independent certificate check: ", VerifyAlgebraicDecompositionData[x^6 + x, negative, x]];
Print["Explicitly truncated enumeration: ", AlgebraicDecompositions[x^12, x, "MaxDecompositions" -> 2]];
