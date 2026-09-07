(* Run from a fresh Wolfram Language kernel.
   Native execution was unavailable during preparation; see README.md. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, z, ap, as, u, v, p, q, rp, rs];
p = x^3 + x + 1;
q = x^3 - x + 1;
ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
u = Root[1 + # + #^3 &, 1];
v = Root[1 - # + #^3 &, 1];

Print["Exact equalities (expected {0,0}): ", RootReduce /@ {ap-u v, as-u-v}];
Print["Product certificate: ", CheckDecomposition[ap, {u,v}, "Product"]];
Print["Sum certificate: ", CheckDecomposition[as, {u,v}, "Sum"]];
Print["Product resultant: ", ProductPolynomial[p,q,x,z]];
Print["Sum resultant: ", SumPolynomial[p,q,x,z]];

(* Recover a pair when only one candidate polynomial is supplied. *)
Print[PairFromPolynomial[ap,p,x,"Product",3]];
Print[PairFromPolynomial[as,p,x,"Sum",3]];

(* No advance knowledge of either cubic is needed for this bounded search.
   Both occur in the height-one dictionary. *)
Print[SearchRootDecomposition[ap,"Product",3,1,2]];
Print[SearchRootDecomposition[as,"Sum",3,1,2]];

(* Quick demonstrations of the complete small-field backend. *)
small = Sqrt[2] + Sqrt[3];
gsmall = BuildGaloisData[small];
Print[CompleteSumDecomposition[small,gsmall]];
Print[CompleteTwoFactorDecomposition[small,gsmall]];

(* More expensive examples: enable individually.

gp = BuildGaloisData[ap];
Print[CompleteTwoFactorDecomposition[ap,gp]];  (* maximum degree 3 *)
Print[CompleteSumDecomposition[ap,gp]];        (* maximum degree 6 *)

aexternal = RootReduce[Sqrt[(1+Sqrt[2]) (1+Sqrt[3])]];
ge = BuildGaloisData[aexternal];
Print[CompleteTwoFactorDecomposition[aexternal,ge]];
(* max degree 4, norm exponent 2, GlobalOptimal -> True *)
Print[CompleteSumDecomposition[aexternal,ge]];
(* max degree 8, GlobalOptimal -> True *)
*)
