Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]], "SystematicRadicals.wl"}]];

alpha = Root[#^6 + #^4 - #^3 - #^2 - 1 &, 2];
r = Radicalize[alpha, Method -> "Native"];
Print[r];
Print[VerifyRadical[alpha, r]];

beta = Root[5 #^5 - 25 #^3 + 25 # + 6 &, 5];
Print[RadicalReport[beta, Method -> "Native"]];

(* General construction. On Windows or with a virtual environment, set
   "PythonExecutable" to the absolute path of its Python executable. *)
Print[RadicalReport[Root[#^3 - 2 &, 1], Method -> "Galois",
  "TimeLimit" -> 120, "MaxFieldDegree" -> 48]];

(* This is an exact nonsolvability result, unlike a timeout. *)
Print[Radicalize[Root[#^5 - # - 1 &, 1], Method -> "Galois"]];
