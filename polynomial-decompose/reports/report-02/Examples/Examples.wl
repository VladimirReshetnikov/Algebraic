(* Evaluate this file in a Wolfram kernel, or evaluate its cells individually. *)
Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],
 "Kernel", "AlgebraicDecomposition.wl"}]];
Clear[x, p, a, g, h, answer];
p = 3 + 3 Sqrt[2] + (14 + 4 Sqrt[2]) x +
 (12 + 26 Sqrt[2]) x^2 + (56 + 8 Sqrt[2]) x^3 +
 (8 + 48 Sqrt[2]) x^4 + 48 x^5 + 16 Sqrt[2] x^6;
answer = AlgebraicDecompose[p,x];
Print["Normalized sextic decomposition: ",answer];
Print[VerifyAlgebraicDecomposition[p,answer,x]];
Print["Nested example: ",AlgebraicDecompose[Expand[p /. x->x^4-x+1],x]];

a = Root[#^5-#-1 &,1];
g = (1+a) x^2+a^2 x+Sqrt[3]; h = x^3+a x;
p = Expand[g /. x->h];
Print["Quintic Root coefficient example: ",AlgebraicDecompose[p,x]];
Print["All complete decompositions of x^12: ",AlgebraicDecompositions[x^12,x]];
Print["All Chebyshev pairs: ",AlgebraicRightDecompositions[ChebyshevT[6,x],x]];
Print["Negative certificate: ",AlgebraicDecompositionAttempt[x^6+x,x,2]];
Print["A cap is not a complete enumeration: ",AlgebraicDecompositions[x^12,x,"MaxDecompositions"->1]];
