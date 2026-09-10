(* Worked examples of the four operations of Algebraic.wl, in one script.

       wolfram -script Examples.wl
       python -X utf8 -m mathics --no-readline -q -f Examples.wl

   The first two sections merge polynomial-decompose/Examples.wl and
   root-decomposition/Examples.wl; the third and fourth reproduce the leading
   examples of the root-to-radicals and radical-denest READMEs.  On a kernel
   where the Galois engine is unavailable (see AlgebraicKernelReport[]) the
   examples that need it print the KernelPrecision failure and the script
   goes on. *)

$IterationLimit = 1000000;
Get[FileNameJoin[{DirectoryName[$InputFileName /. "" -> Directory[]], "Algebraic.wl"}]];
report = AlgebraicKernelReport[];
Print["Kernel: ", report["Kernel"], "; operations: ", report["Operations"]];

(* ---- 1. functional decomposition of polynomials ---------------------- *)
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

(* ---- 2. sums and products of algebraic numbers ----------------------- *)
ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
Print["Lower bound for the product example: ", RootDecompositionLowerBound[ap]];
Print["Product example: ", RootProductDecomposition[ap]["Expression"]];
Print["Sum example:     ", RootSumDecomposition[as]["Expression"]];
(* The product root needs sextic summands globally; inside Q(ap) degree 9 is necessary. *)
Print["Product root as a sum: ", RootSumDecomposition[ap]["Expression"]];
Print["   restricted to Q(ap): ", RootSumDecomposition[ap, "Scope" -> "InputField"]["MaximumDegree"]];
(* Optimal factors may lie outside the splitting field (norm exponent 2). *)
ext = Sqrt[(1 + Sqrt[2]) (1 + Sqrt[3])];
Print["External factors: ", RootProductDecomposition[ext]["Expression"]];
(* Three quadratics attain degree 2; the optimum with at most two factors is 4. *)
eta = (1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5]);
Print["Three factors: ", RootProductDecomposition[eta]["Expression"]];
(* A flat sum of three quadratics that is neither a binary sum nor a binary product. *)
e3 = Sqrt[2] + Sqrt[3] + Sqrt[6];
Print["Flat sum: ", RootSumDecomposition[e3]["Expression"]];
Print["Binary sum with degree <= 3: ", RootSumDecomposition[e3, 3, "MaxTerms" -> 2]];
Print["Two-factor product: ", RootProductDecomposition[e3, "MaxFactors" -> 2]["MaximumDegree"]];
(* Gaussian rational coefficients. *)
g1 = I + Sqrt[2] + I Sqrt[2];
Print["Gaussian combination: ", RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals"]["Expression"]];
gd = RootGaloisData[ap];
Print["Galois data: ", If[AssociationQ[gd],
  {"order", gd["Order"], "exponent", gd["Exponent"], "subfield degrees", Tally[gd["SubfieldDegrees"]]}, gd]];

(* ---- 3. radical expressions ------------------------------------------ *)
Print["Solvable? x^5-5x+12: ", RootSolvableQ[Root[#^5 - 5 # + 12 &, 1]],
  ";  x^5-x-1: ", RootSolvableQ[Root[#^5 - # - 1 &, 1]]];
Print["Structural: ", RootToRadicals[Root[#^4 - 10 #^2 + 1 &, 4]]];
Print["Cyclic quintic 2 cos(2 Pi/11): ", RootToRadicals[Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 1]]];
Print["Sextic of the question: ", RootRadicalReport[Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]]];

(* ---- 4. denesting ---------------------------------------------------- *)
Print["Strad: ", Strad[Sqrt[5 + 2 Sqrt[6]]]];
Print["Strad: ", Strad[(239 + 169 Sqrt[2])^(1/7)]];
Print["Strad, Ramanujan: ", Strad[(2^(1/3) - 1)^(1/3)]];
rep = DenestReport[Sqrt[5 + 2 Sqrt[6]]];
Print["Report: ", rep["Result"], " ", rep["Status"], " cost ", rep["InitialCost"], " -> ", rep["FinalCost"]];
Print["EqualityStatus: ", EqualityStatus[Sqrt[2] + Sqrt[3], Sqrt[5 + 2 Sqrt[6]]]];
