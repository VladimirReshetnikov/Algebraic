(* Run in a fresh Wolfram kernel, or evaluate sections in a notebook.
   These are executable examples, not a transcript of native execution. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "..",
  "AlgebraicDecomposition.wl"}]];
Clear[x, p, p2, a, q, chain, certificate];
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x + (12 + 26 Sqrt[2]) x^2 +
  (56 + 8 Sqrt[2]) x^3 + (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[p, x];
Print["Original, normalized: ", chain];
Print["Exact identity: ", VerifyAlgebraicDecomposition[p, chain, x]];
Print["All normalized pairs: ", AlgebraicDecompositionPairs[p, x]];
Print["Rejected right degree: ", AlgebraicRightDecompose[p, x, 3]];
certificate = AlgebraicDecompositionData[p, x];
Print["Certificate: ", certificate];
Print["Certificate verified independently: ",
  VerifyAlgebraicDecompositionData[p, certificate, x]];
p2 = Expand[p /. x -> x^4 - x + 1];
Print["Nested example: ", AlgebraicDecompose[p2, x]];
Print["Power alternatives: ", AlgebraicDecompositions[x^12, x]];
Print["Chebyshev alternatives: ", AlgebraicDecompositions[ChebyshevT[6, x], x]];
a = Root[#^5 - # - 1 &, 1];
q = Expand[(x^3 + a x)^2 + (1 + a) (x^3 + a x) + 2];
Print["Quintic Root coefficients: ", AlgebraicRightDecompose[q, x, 3]];
Print["Composite atomic inner factor: ", AlgebraicDecompose[(x^4 + x)^2, x]];
Print["Negative certificate: ", AlgebraicDecompositionData[x^6 + x, x]];
Print["Inexact input is refused: ", AlgebraicDecompose[1.0 x^4, x]];
