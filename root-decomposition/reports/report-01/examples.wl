(* Evaluate with a native Wolfram Language kernel.
   Get this file, or evaluate the blocks individually in a notebook. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, u, v, w, z];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
productRoot = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
sumRoot = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];

(* Exact conjugate selection and a global optimality certificate. *)
productCertificate = SelectRootPair[productRoot, x^3 + x + 1, x^3 - x + 1, x, "Product"];
sumCertificate = SelectRootPair[sumRoot, x^3 + x + 1, x^3 - x + 1, x, "Sum"];
Print[productCertificate];
Print[sumCertificate];

(* Discover the cubics within explicit templates, rather than supplying them. *)
sumTemplate = SolveRootTemplate[sumRoot,
  x^3 + u x + v, x^3 + w x + z, {u, v, w, z}, x, "Sum"];
productTemplate = SolveRootTemplate[productRoot,
  x^3 + u x + v, x^3 + w x + 1, {u, v, w}, x, "Product"];
Print[sumTemplate["Candidates"]];
Print[productTemplate["Candidates"]];

(* Finite coefficient-height search. This catalog contains both cubics. *)
smallCatalog = PolynomialCatalog[3, 1, x, "MonicOnly" -> True];
Print[SearchRootCatalog[productRoot, smallCatalog, x, "Product"]];
Print[SearchRootCatalog[sumRoot, smallCatalog, x, "Sum"]];

(* Both operations over two specified fields use rational linear algebra. *)
Print[SplitOverFields[(1 + Sqrt[2]) (2 + Sqrt[3]), Sqrt[2], Sqrt[3], "Product"]];
Print[SplitOverFields[1 + Sqrt[2] + Sqrt[3], Sqrt[2], Sqrt[3], "Sum"]];

(* Global additive optimization; possibly expensive. Run separately:
MinimumSumDecomposition[sumRoot]
MinimumSumDecomposition[productRoot]          (* minimum maximum degree 6 *)
MinimumSumDecomposition[Sqrt[2]+Sqrt[3]+Sqrt[5]]  (* maximum degree 2 *)

Use TimeConstrained[..., 120, Failure["Timeout", <||>]] to impose a wall-clock
limit. A timeout, resource guard, or unresolved solver is not nonexistence.
*)

(* Explicit degree-six additive split of the product example. *)
c = Root[4 - 81 # + 9 #^2 - 27 #^3 + 6 #^4 + #^6 &, 1];
d = Root[4 - 81 # + 9 #^2 - 27 #^3 + 6 #^4 + #^6 &, 2];
Print[VerifyRootDecomposition[productRoot, {c/3, d/3}, "Sum"]];
(* The generic verifier reports a certified upper bound of 6.
   The article supplies the separate global lower-bound proof of 6. *)
