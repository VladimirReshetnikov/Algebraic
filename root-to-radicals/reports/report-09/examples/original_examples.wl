Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "wolfram", "SystematicRadicals.wl"}]];
a = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
b = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
{SystematicToRadicals[a], SystematicToRadicals[b]}
(* On Windows, specify the actual interpreter, for example:
   SystematicToRadicals[a, Method -> "Python",
     "PythonCommand" -> {"py", "-3"}]
   OR {"C:\\path\\to\\venv\\Scripts\\python.exe"}.
*)
u = (1/2 + Sqrt[849]/18)^(1/3);
s = u - 4/(3 u);
{RootReduce[(s + Sqrt[s^2 + 4])/2 - a],
 RootReduce[((-3 + 4 I)/5)^(1/5) + ((-3 - 4 I)/5)^(1/5) - b]}
(* Expected: {0,0}; these WL tests are supplied for local kernel execution. *)
