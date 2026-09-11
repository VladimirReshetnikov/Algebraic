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

(* Every example below is printed through show, which gives each value a
   time budget: none in the Wolfram kernel, five minutes in Mathics, where
   the Galois engine is a hundred times slower and the degree-9 product
   example does not finish in an hour. *)
(* The Galois engine is a hundred times slower in Mathics and stops at a
   degree-72 resultant (README, "Mathics3"); the examples that need more
   than that print a note there instead of running -- Mathics'
   TimeConstrained does not interrupt a long SymPy computation, so a budget
   would not help. *)
$mathics = report["Kernel"] === "Mathics";
SetAttributes[{show, showHeavy}, HoldAll];
show[args___] := Print[args];
showHeavy[label_, args___] := If[$mathics,
  Print[label, "(skipped on Mathics: beyond the Galois engine's limit there, see README)"],
  Print[label, args]];

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
show["Lower bound for the product example: ", RootDecompositionLowerBound[ap]];
showHeavy["Product example: ", RootProductDecomposition[ap]["Expression"]];
showHeavy["Sum example:     ", RootSumDecomposition[as]["Expression"]];
(* The product root needs sextic summands globally; inside Q(ap) degree 9 is necessary. *)
showHeavy["Product root as a sum: ", RootSumDecomposition[ap]["Expression"]];
showHeavy["   restricted to Q(ap): ", RootSumDecomposition[ap, "Scope" -> "InputField"]["MaximumDegree"]];
(* Optimal factors may lie outside the splitting field (norm exponent 2). *)
ext = Sqrt[(1 + Sqrt[2]) (1 + Sqrt[3])];
showHeavy["External factors: ", RootProductDecomposition[ext]["Expression"]];
(* Three quadratics attain degree 2; the optimum with at most two factors is 4. *)
eta = (1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5]);
showHeavy["Three factors: ", RootProductDecomposition[eta]["Expression"]];
(* A flat sum of three quadratics that is neither a binary sum nor a binary product. *)
e3 = Sqrt[2] + Sqrt[3] + Sqrt[6];
showHeavy["Flat sum: ", RootSumDecomposition[e3]["Expression"]];
showHeavy["Binary sum with degree <= 3: ", RootSumDecomposition[e3, 3, "MaxTerms" -> 2]];
showHeavy["Two-factor product: ", RootProductDecomposition[e3, "MaxFactors" -> 2]["MaximumDegree"]];
(* Gaussian rational coefficients. *)
g1 = I + Sqrt[2] + I Sqrt[2];
showHeavy["Gaussian combination: ", RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals"]["Expression"]];
gd = If[$mathics, $Failed, RootGaloisData[ap]];   (* the degree-9 group: beyond the engine's limit in Mathics *)
showHeavy["Galois data: ", If[AssociationQ[gd],
  {"order", gd["Order"], "exponent", gd["Exponent"], "subfield degrees", Tally[gd["SubfieldDegrees"]]}, gd]];

(* ---- 3. radical expressions ------------------------------------------ *)
showHeavy["Solvable? x^5-5x+12: ", RootSolvableQ[Root[#^5 - 5 # + 12 &, 1]],
  ";  x^5-x-1: ", RootSolvableQ[Root[#^5 - # - 1 &, 1]]];
show["Structural: ", RootToRadicals[Root[#^4 - 10 #^2 + 1 &, 4]]];
showHeavy["Cyclic quintic 2 cos(2 Pi/11): ", RootToRadicals[Root[#^5 + #^4 - 4 #^3 - 3 #^2 + 3 # + 1 &, 1]]];
showHeavy["Sextic of the question: ", RootRadicalReport[Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]]];

(* ---- 4. denesting ---------------------------------------------------- *)
show["Strad: ", Strad[Sqrt[5 + 2 Sqrt[6]]]];
show["Strad: ", Strad[(239 + 169 Sqrt[2])^(1/7)]];
showHeavy["Strad, Ramanujan: ", Strad[(2^(1/3) - 1)^(1/3)]];
rep = DenestReport[Sqrt[5 + 2 Sqrt[6]]];
show["Report: ", rep["Result"], " ", rep["Status"], " cost ", rep["InitialCost"], " -> ", rep["FinalCost"]];
show["EqualityStatus: ", EqualityStatus[Sqrt[2] + Sqrt[3], Sqrt[5 + 2 Sqrt[6]]]];
