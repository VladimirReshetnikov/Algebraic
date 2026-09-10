(* Replays the random inputs of exp_fuzz3.wl (same seed, same generator order) without
   running Strad, then times the inputs of the chosen families one by one and prints the
   slow ones with their DenestReport statistics.  Diagnostic aid for unified-C, Section 7. *)
Get["C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/corrected/StradFixed3.wl"];
Needs["RadicalDenest3`"];
SeedRandom[20260905];
sqf = {2, 3, 5, 6, 7, 10, 11, 13, 15, 17};
sqf3 = {2, 3, 5, 6, 7, 10, 11, 13, 14, 15, 21, 22, 26, 30, 33, 35};
rnz[] := RandomChoice[Join[Range[-7, -1], Range[1, 7]]];
gens = {
  {"F1", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Sqrt[Expand[(p + q Sqrt[c])^2]]]], 40},
  {"F2", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^3]^(1/3)]], 30},
  {"F3", Function[{}, Module[{a = RandomInteger[{-30, 30}], b = rnz[], c = RandomChoice[sqf]}, Sqrt[a + b Sqrt[c]]]], 40},
  {"F4", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Sqrt[Expand[(p + q I Sqrt[c])^2]]]], 40},
  {"F5", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q I Sqrt[c])^2]^(3/2)]], 40},
  {"F6", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf], r = rnz[], s = rnz[], d = RandomChoice[sqf]}, Sqrt[Expand[(p + q I Sqrt[c])^2]] Sqrt[Expand[(r + s I Sqrt[d])^2]]]], 40},
  {"F7", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^4]^(1/4)]], 25},
  {"F8", Function[{}, Module[{p = rnz[], q = rnz[], r = rnz[], cd = RandomSample[sqf, 2]}, Sqrt[Expand[(p + q Sqrt[cd[[1]]] + r Sqrt[cd[[2]]])^2]]]], 25},
  {"F9", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^2]^(3/2)]], 30},
  {"F10", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf], r = rnz[], s = rnz[], d = RandomChoice[sqf]}, Sqrt[-Expand[(p + q Sqrt[c])^2]] Sqrt[-Expand[(r + s Sqrt[d])^2]]]], 30},
  {"F11", Function[{}, Module[{abc = RandomSample[sqf3, 3], s = RandomChoice[{-1, 1}, 3]}, Sqrt[Expand[(s . Sqrt[abc])^2]]]], 30},
  {"F12", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^5]^(1/5)]], 25},
  {"F13", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^7]^(1/7)]], 20},
  {"F14", Function[{}, Module[{p = rnz[], q = rnz[], c = RandomChoice[sqf]}, Expand[(p + q Sqrt[c])^6]^(1/6)]], 15}};
inputs = Association[Table[g[[1]] -> Table[g[[2]][], {g[[3]]}], {g, gens}]];
families = Rest[$ScriptCommandLine];
If[families === {}, families = {"F8", "F10", "F11"}];
threshold = 2;
Do[Print["=== ", f];
 Do[Module[{t, r},
   {t, r} = AbsoluteTiming[TimeConstrained[DenestReport[e], 120, $TimedOut]];
   If[t > threshold || r === $TimedOut,
    Print[InputForm[e], "\n   -> ", If[r === $TimedOut, $TimedOut, InputForm[r["Result"]]], "   ", Round[t, 0.01], " s",
     If[r =!= $TimedOut, "\n   stats " <> ToString[KeyTake[r["Statistics"], {"Islands", "Trials", "Certificates", "CosetSystems", "FastPathAccepted", "CandidatesAccepted", "MultipliersAdmitted"}], InputForm] <> "  limits " <> ToString[r["Limits"]], ""]]]],
  {e, inputs[f]}], {f, families}];
Print["DONE"];
