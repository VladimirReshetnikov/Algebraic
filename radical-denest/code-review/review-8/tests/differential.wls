(* Compare selected values against the original in a fresh native kernel.
   wolframscript -file tests/differential.wls /path/to/StradFixed2.wl
   This corpus is supplementary; it does not replace unified-B's 144 tests.
   Time limits below intentionally differ from the repository benchmarks. *)
base = DirectoryName[DirectoryName[$InputFileName]];
args = Rest[$ScriptCommandLine];
If[Length[args] < 1, Print["Supply the path of StradFixed2.wl."]; Exit[2]];
Get[First[args]]; Get[FileNameJoin[{base, "code", "StradFixed3.wl"}]];
corpus = {
 Sqrt[3 + 2 Sqrt[2]], Sqrt[5 + 2 Sqrt[6]], Sqrt[4 + 3 Sqrt[2]],
 Sqrt[3/2 + Sqrt[3]], (7 + 5 Sqrt[2])^(1/3), (41 - 29 Sqrt[2])^(1/5),
 (-99 - 70 Sqrt[2])^(1/6), (-239 - 169 Sqrt[2])^(1/7),
 (1393 - 985 Sqrt[2])^(1/9), (7 20^(1/3) - 19)^(1/6),
 (133 + 57 2^(2/3) 3^(1/3) + 48 2^(1/3) 3^(2/3))^(1/6),
 Sqrt[5^(1/3) - 4^(1/3)], Sqrt[28^(1/3) - 3],
 Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]],
 Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]],
 (3 + 2 Sqrt[2])^(1/6), Sqrt[2 + Sqrt[2]],
 1/(Sqrt[2] + Sqrt[3 + 2 Sqrt[2]])
};
rows = Table[
 old = RadicalDenest2`DenestReport[e, "TimeBudget" -> 30, "OperationTime" -> 5];
 new = RadicalDenest3`DenestReport[e, "TimeBudget" -> 30, "OperationTime" -> 5,
   "SquareClassSearch" -> True];
 <|"Input" -> e, "OldResult" -> old["Result"], "NewResult" -> new["Result"],
  "OldExactEquality" -> TimeConstrained[Quiet[Check[RootReduce[e - old["Result"]] === 0, False]], 30, "Unknown"],
  "NewExactEquality" -> TimeConstrained[Quiet[Check[RootReduce[e - new["Result"]] === 0, False]], 30, "Unknown"],
  "OldDepth" -> RadicalDenest2`RadicalDepth[old["Result"]],
  "NewDepth" -> RadicalDenest3`RadicalDepth[new["Result"]],
  "OldStatus" -> old["Status"], "NewStatus" -> new["Status"],
  "OldSeconds" -> old["ElapsedSeconds"], "NewSeconds" -> new["ElapsedSeconds"]|>, {e, corpus}];
Print["Kernel: ", $Version]; Print[InputForm[rows]];
Export[FileNameJoin[{base, "tests", "native_differential.wl"}], ToString[rows, InputForm], "Text"];
