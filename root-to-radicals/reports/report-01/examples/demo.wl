Get[FileNameJoin[{DirectoryName[$InputFileName], "..", "wolfram", "RadicalRoot.wl"}]];
(* On Windows a full python.exe path may be needed. *)
r = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
a = RadicalRoot[r, "UseNative" -> False, "PythonExecutable" -> "python"];
{a, RootReduce[a - r]}
q = Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5];
RadicalRoot[q, "UseNative" -> False, "Return" -> "Data"]
