(* Examples for RootDecomposition.wl.  Evaluate with  Get["Examples.wl"]  from this directory. *)

Get[FileNameJoin[{DirectoryName[$InputFileName /. "" -> Directory[]], "RootDecomposition.wl"}]];

ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

Print["Product example: ", RootProductDecomposition[ap]["Expression"]];
Print["Sum example:     ", RootSumDecomposition[as]["Expression"]];

(* The product root as a sum needs two sextics, and nothing inside Q(ap) works. *)
Print["Product root as a sum: ", RootSumDecomposition[ap]["Expression"]];
Print["   restricted to Q(ap): ", RootSumDecomposition[ap, "Scope" -> "InputField"]["MaximumDegree"]];

(* Optimal factors may lie outside the splitting field (norm exponent 2). *)
ext = RootReduce[Sqrt[(1 + Sqrt[2]) (1 + Sqrt[3])]];
Print["External factors: ", RootProductDecomposition[ext]["Expression"]];

(* Three quadratic factors although no two factors of degree < 8 exist. *)
eta = RootReduce[(1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5])];
Print["Three factors: ", RootProductDecomposition[eta]["Expression"]];

(* A flat sum of three quadratics that is neither a binary sum nor a binary product. *)
e3 = RootReduce[Sqrt[2] + Sqrt[3] + Sqrt[6]];
Print["Flat sum: ", RootSumDecomposition[e3]["Expression"]];
Print["Binary sum with degree <= 3: ", RootSumDecomposition[e3, 3, "MaxTerms" -> 2]];
Print["Two-factor product: ", RootProductDecomposition[e3, "MaxFactors" -> 2]["MaximumDegree"]];

(* Gaussian rational coefficients. *)
g1 = RootReduce[I + Sqrt[2] + I Sqrt[2]];
Print["Gaussian combination: ", RootSumDecomposition[g1, "Coefficients" -> "GaussianRationals"]["Expression"]];

(* Galois data. *)
gd = RootGaloisData[ap];
Print["Galois group order ", gd["Order"], ", exponent ", gd["Exponent"], ", subfield degrees ", Tally[gd["SubfieldDegrees"]]];
