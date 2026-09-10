(* Prints the summary numbers quoted in unified_analysis_C.tex from the recorded rows. *)
scratch = "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/";
fixedB = Get[scratch <> "exp_battery2_rows.m"]; fixedC = Get[scratch <> "exp_battery3_rows.m"]; newB = Get[scratch <> "exp_new2_rows.m"];
main = Select[fixedC, ! StringStartsQ[#["id"], "N"] &]; newC = Select[fixedC, StringStartsQ[#["id"], "N"] &];
wrongQ[r_] := r["exact"] === False || r["numeric"] === False;
summ[rows_, name_] := Module[{slow = First[MaximalBy[rows, #["time"] &]]},
  Print[name, ": rows ", Length[rows], "  depth reduced ", Count[rows, r_ /; r["depth"][[2]] < r["depth"][[1]]],
   "  wrong ", Count[rows, r_ /; wrongQ[r]], "  messages ", Count[rows, r_ /; r["messages"] =!= {}],
   "  total ", Round[Total[rows[[All, "time"]]], 0.1], " s  slowest ", slow["id"], " ", Round[slow["time"], 0.01], " s"]];
summ[main, "battery v3"]; summ[Select[fixedB, ! StringStartsQ[#["id"], "N"] &], "battery v2"]; summ[newC, "N v3"]; summ[newB, "N v2"];
Print["rows slower than 5 s (v3): ", {#["id"], Round[#["time"], 0.01]} & /@ Select[main, #["time"] > 5 &]];
Print["rows slower than 5 s (v2): ", {#["id"], Round[#["time"], 0.01]} & /@ Select[fixedB, #["time"] > 5 &]];
Print["depth changes v2 -> v3: ", Select[Table[b = SelectFirst[fixedB, #["id"] === c["id"] &, None]; If[b === None, Nothing, {c["id"], b["depth"], c["depth"]}], {c, main}], #[[2]] =!= #[[3]] &]];
Print["result changes v2 -> v3: ", Select[Table[b = SelectFirst[fixedB, #["id"] === c["id"] &, None]; If[b === None, Nothing, {c["id"], b["result"], c["result"]}], {c, main}], #[[2]] =!= #[[3]] &] /. s_String :> StringTake[s, UpTo[60]]];
Print["N side by side:"];
Do[b = SelectFirst[newB, #["id"] === c["id"] &, None];
 Print["  ", c["id"], "  v2 ", b["depth"], " ", Round[b["time"], 0.01], "s ", If[wrongQ[b], "WRONG", ""], "  v3 ", c["depth"], " ", Round[c["time"], 0.01], "s ", If[wrongQ[c], "WRONG", ""], "  ", StringTake[c["result"], UpTo[70]]], {c, newC}];
fuzzB = Get[scratch <> "exp_fuzz2_results.m"]; fuzzC = Get[scratch <> "exp_fuzz3_results.m"];
cnt[st_, k_] := Lookup[st, k, 0];
Print["fuzz v3: families ", Length[fuzzC], " inputs ", Total[fuzzC[[All, 2]]], " total ", Round[Total[fuzzC[[All, 4]]], 0.1], " s  wrong ", Total[cnt[#[[3]], "WRONGVALUE"] & /@ fuzzC], " timeouts ", Total[cnt[#[[3]], "timeout"] & /@ fuzzC], " denested ", Total[cnt[#[[3]], "denested"] & /@ fuzzC]];
Print["fuzz v2 (F1-F10): inputs ", Total[fuzzB[[All, 2]]], " total ", Round[Total[fuzzB[[All, 4]]], 0.1], " s denested ", Total[cnt[#[[3]], "denested"] & /@ fuzzB]];
Do[Print["  ", StringTake[fuzzC[[i, 1]], UpTo[38]], "  v3 ", fuzzC[[i, 3]], " total ", Round[fuzzC[[i, 4]], 0.01], " max ", Round[fuzzC[[i, 5]], 0.01], If[i <= Length[fuzzB], "   v2 " <> ToString[fuzzB[[i, 3]]] <> " total " <> ToString[Round[fuzzB[[i, 4]], 0.01]] <> " max " <> ToString[Round[fuzzB[[i, 5]], 0.01]], ""]], {i, Length[fuzzC]}];
diff = Get[scratch <> "differential3_rows.m"];
Print["differential: ", Length[diff], " inputs; v2 equal ", Count[diff, r_ /; r["OldEqual"] === True], " v3 equal ", Count[diff, r_ /; r["NewEqual"] === True],
  "; depth v2<v3 ", Count[diff, r_ /; r["OldDepth"] < r["NewDepth"]], " v3<v2 ", Count[diff, r_ /; r["NewDepth"] < r["OldDepth"]], "; time v2 ", Round[Total[diff[[All, "OldSeconds"]]], 0.1], " v3 ", Round[Total[diff[[All, "NewSeconds"]]], 0.1]];
Do[Print["  ", InputForm[r["Input"]], "  v2 d", r["OldDepth"], " ", r["OldSeconds"], "s ", r["OldStatus"], "  v3 d", r["NewDepth"], " ", r["NewSeconds"], "s ", r["NewStatus"]], {r, diff}];
Print["DONE"];
