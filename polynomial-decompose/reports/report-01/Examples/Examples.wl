(* Evaluate in a fresh Wolfram kernel. Paths work with Get or wolframscript. *)
Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],
  "Kernel", "AlgebraicDecomposition.wl"}]];
Clear[x];
poly = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
  (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
  (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
chain = AlgebraicDecompose[poly, x];
Print["Original example: ", chain];
Print["Exact and complete: ", AlgebraicVerifyDecomposition[
  poly, chain, x, "RequireComplete" -> True, "RequireNormalized" -> True]];
Print["Degree-three decision: ", AlgebraicDecomposeAtDegree[poly, x, 3]];
Print["Decision record: ", AlgebraicDecompositionReport[poly, x]];

nested = Expand[poly /. x -> x^4 - x + 1];
Print["Nested example: ", AlgebraicDecompose[nested, x]];

alpha = Root[#^5 - # - 1 &, 1];
pRoot = Expand[(x^2 + alpha x)^3 + alpha (x^2 + alpha x) + 1];
Print["Quintic Root coefficients: ", AlgebraicDecompose[pRoot, x]];

Print["All complete chains of x^12: ", AlgebraicDecomposeAll[x^12, x]];
Print["Chebyshev collision: ", AlgebraicDecomposeAll[ChebyshevT[6, x], x]];
Print["Explicit cap: ", AlgebraicDecomposeAll[x^30, x, "MaxDecompositions" -> 2]];
Print["Indecomposability obstruction: ", AlgebraicDecompositionReport[x^6 + x, x]];

(* Restore the normalization in the Stack Exchange question without
   changing the composition: g = Sqrt[2] h and f_old(y)=f(y/Sqrt[2]). *)
questionNormalization = {
  Expand[chain[[1]] /. x -> x/Sqrt[2]], Expand[Sqrt[2] chain[[2]]]
};
Print["Question's normalization: ", questionNormalization];
