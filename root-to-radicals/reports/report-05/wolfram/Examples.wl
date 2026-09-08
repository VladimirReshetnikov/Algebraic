Get[FileNameJoin[{DirectoryName[$InputFileName],"RadicalSolve.wl"}]];

r6 = Root[-1-#^2-#^3+#^4+#^6&,2];
r5 = Root[6+25#-25#^3+5#^5&,5];

(* Both examples have native structural solutions; Python is not needed. *)
a6 = Radicalize[r6,Method->"Native"];
a5 = Radicalize[r5,Method->"Native"];
{VerifyRadical[r6,a6],VerifyRadical[r5,a5]}
RadicalReport[r6,Method->"Native"]

(* General descent; set this option to the desired Python executable. *)
RadicalReport[Root[#^3-3#+1&,1],Method->"Galois",
  "PythonExecutable"->"python","MaxFieldDegree"->96]

(* A genuine negative answer, not failure to find a formula. *)
Radicalize[Root[#^5-#-1&,1]]
