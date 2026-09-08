Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "wolfram", "RadicalRoot.wl"}]];
a = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
b = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
ra = RootToRadicals[a, Method -> "Fast"];
rb = RootToRadicals[b, Method -> "Fast"];
Print[{ra, VerifyRadical[a, ra]}];
Print[{rb, VerifyRadical[b, rb]}];
(* Force the constructive normal-field method, not the fast paths. *)
r = RadicalSolve[Root[#^3 - 2 &, 1], Method -> "Galois", TimeConstraint -> 300];
Print[r];
(* A radical compositum hint for the degree-eight notebook example. *)
c = Root[1 + 2 # - 15 #^2 - 48 #^3 - 36 #^4 + 8 #^5 + 20 #^6 + 8 #^7 + #^8 &, 1];
rc = RootToRadicals[c, Method -> "Fast", "PairResolventLimit" -> 0,
  "Extensions" -> {{Sqrt[3], Sqrt[5]}}];
Print[{rc, VerifyRadical[c, rc]}];
