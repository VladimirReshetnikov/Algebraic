(* Convert the recorded unified-C runs into LaTeX table fragments.
   Reads the row files written by exp_battery3.wl (StradFixed3), exp_battery2.wl of
   unified-B (StradFixed2), exp_new2.wl (round-3 cases on StradFixed2), the fuzz
   results of exp_fuzz2.wl / exp_fuzz3.wl and the differential rows of differential3.wl. *)
scratch = "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/";
outdir = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-C/tables/";
If[! DirectoryQ[outdir], CreateDirectory[outdir]];

texEscape[s_String] := StringReplace[s, {"\\" -> "\\textbackslash{}", "&" -> "\\&", "%" -> "\\%", "$" -> "\\$", "#" -> "\\#", "_" -> "\\_", "{" -> "\\{", "}" -> "\\}", "~" -> "\\textasciitilde{}", "^" -> "\\textasciicircum{}"}];
breakable[s_String] := StringReplace[texEscape[s], {"]" -> "]\\allowbreak{}", "`" -> "`\\allowbreak{}", "[" -> "[\\allowbreak{}", ")" -> ")\\allowbreak{}", "(" -> "(\\allowbreak{}", "*" -> "*\\allowbreak{}", "/" -> "/\\allowbreak{}", "," -> ",\\allowbreak{}", " + " -> " +\\allowbreak{} ", " - " -> " -\\allowbreak{} ", "\\textasciicircum{}" -> "\\textasciicircum{}\\allowbreak{}"}];
stripHold[s_String] := StringReplace[s, {StartOfString ~~ "HoldForm[" ~~ body__ ~~ "]" ~~ EndOfString :> body}];
fmtTime[t_] := ToString[NumberForm[N[t], {5, 3}]];
fmtFlag[f_] := Switch[f, True, "yes", False, "\\textbf{NO}", "n/a", "--", _, ToString[f]];
depthStr[d_] := ToString[d[[1]]] <> "$\\to$" <> ToString[d[[2]]];
shorten[s_String] := If[StringLength[s] > 260, StringTake[s, 250] <> " ...", s];

(* side-by-side: second corrected version (A columns) vs third (B columns) *)
writeCompare[rowsA_List, rowsB_List, file_String, caption_String, label_String] := Module[{lines, a},
  lines = {
    "\\begin{longtable}{@{}p{0.045\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.28\\textwidth}p{0.055\\textwidth}p{0.065\\textwidth}p{0.055\\textwidth}p{0.065\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.27\\textwidth}@{}}",
    "\\caption{" <> caption <> "}\\label{" <> label <> "}\\\\",
    "\\toprule ID & Input & \\multicolumn{2}{l}{StradFixed2} & \\multicolumn{2}{l}{StradFixed3} & Output of StradFixed3\\\\ & & depth & time (s) & depth & time (s) & \\\\\\midrule\\endfirsthead",
    "\\toprule ID & Input & \\multicolumn{2}{l}{StradFixed2} & \\multicolumn{2}{l}{StradFixed3} & Output of StradFixed3\\\\ & & depth & time (s) & depth & time (s) & \\\\\\midrule\\endhead",
    "\\bottomrule\\endfoot"};
  Do[a = SelectFirst[rowsA, #["id"] === b["id"] &, None];
   AppendTo[lines, StringJoin[
     b["id"], " & ", breakable[stripHold[b["input"]]], " & ",
     If[a === None, "--", depthStr[a["depth"]] <> If[a["exact"] === False || a["numeric"] === False, " $\\times$", ""]], " & ", If[a === None, "--", fmtTime[a["time"]]], " & ",
     depthStr[b["depth"]], If[b["exact"] === False || b["numeric"] === False, " $\\times$", ""], " & ", fmtTime[b["time"]], " & ",
     breakable[shorten[b["result"]]], If[b["messages"] =!= {}, "\\newline{\\scriptsize\\itshape " <> texEscape[StringRiffle[b["messages"], ", "]] <> "}", ""],
     "\\\\"]], {b, rowsB}];
  AppendTo[lines, "\\end{longtable}"];
  Export[outdir <> file, StringRiffle[lines, "\n"], "Text"];
  Print["wrote ", file, " (", Length[rowsB], " rows)"]];

fixedB = Get[scratch <> "exp_battery2_rows.m"];
fixedC = Get[scratch <> "exp_battery3_rows.m"];
newB = Get[scratch <> "exp_new2_rows.m"];
pick[rows_, prefixes_List] := Select[rows, StringStartsQ[#["id"], Alternatives @@ prefixes] &];

writeCompare[fixedB, pick[fixedC, {"A"}], "cmp_A.tex", "Classical identities: second corrected version (unified-B) against \\texttt{StradFixed3}. Depth is the syntactic radical depth before and after; a $\\times$ after a depth would mark an output not exactly equal to its input.", "tab:cmpA"];
writeCompare[fixedB, pick[fixedC, {"B", "C"}], "cmp_BC.tex", "Non-denestable inputs (B) and branch counterexamples (C).", "tab:cmpBC"];
writeCompare[fixedB, pick[fixedC, {"D", "E"}], "cmp_DE.tex", "Direct core calls with forced multipliers (D) and symbolic input (E).", "tab:cmpDE"];
writeCompare[fixedB, pick[fixedC, {"J", "K"}], "cmp_JK.tex", "Factorizer and rationalizer probes (J) and miscellaneous inputs (K).", "tab:cmpJK"];
writeCompare[fixedB, pick[fixedC, {"L", "Q"}], "cmp_LQ.tex", "Higher-order roots (L) and roots of negative bases (Q).", "tab:cmpLQ"];
writeCompare[newB, pick[fixedC, {"N"}], "cmp_N.tex", "Round-3 cases (N): the reviews' motivating inputs and the unified-C controls, \\texttt{StradFixed2} against \\texttt{StradFixed3}. A $\\times$ after a depth marks an output not exactly equal to the expected value; the two occurrences are a rejected unknown option (N15, previous version) and the rejected malformed call N28.", "tab:cmpN"];

(* fuzz summary: F1-F10 have StradFixed2 counterparts, F11-F14 are new *)
fuzzB = Get[scratch <> "exp_fuzz2_results.m"];
fuzzC = Get[scratch <> "exp_fuzz3_results.m"];
cnt[stats_, key_] := Lookup[stats, key, 0];
lines = {"\\begin{tabular}{@{}l r rrr rrr rr@{}}", "\\toprule",
  " & & \\multicolumn{3}{c}{StradFixed2} & \\multicolumn{3}{c}{StradFixed3} & \\multicolumn{2}{c}{StradFixed3 time (s)}\\\\",
  "\\cmidrule(lr){3-5}\\cmidrule(lr){6-8}\\cmidrule(lr){9-10}",
  "Family & $n$ & denested & unchanged & \\textbf{wrong} & denested & unchanged & \\textbf{wrong} & total & max\\\\\\midrule"};
Do[c = fuzzC[[i]]; b = If[i <= Length[fuzzB], fuzzB[[i]], None];
 AppendTo[lines, StringJoin[StringReplace[c[[1]], RegularExpression["^(F\\d+) .*$"] -> "$1"], " & ", ToString[c[[2]]], " & ",
   If[b === None, "-- & -- & --", ToString[cnt[b[[3]], "denested"]] <> " & " <> ToString[cnt[b[[3]], "unchanged"] + cnt[b[[3]], "equal-rewritten"]] <> " & " <> ToString[cnt[b[[3]], "WRONGVALUE"]]], " & ",
   ToString[cnt[c[[3]], "denested"]], " & ", ToString[cnt[c[[3]], "unchanged"] + cnt[c[[3]], "equal-rewritten"]], " & ", ToString[cnt[c[[3]], "WRONGVALUE"]], " & ",
   fmtTime[c[[4]]], " & ", fmtTime[c[[5]]], "\\\\"]], {i, Length[fuzzC]}];
AppendTo[lines, "\\midrule Total & " <> ToString[Total[fuzzC[[All, 2]]]] <> " & " <>
  ToString[Total[cnt[#[[3]], "denested"] & /@ fuzzB]] <> " & " <> ToString[Total[(cnt[#[[3]], "unchanged"] + cnt[#[[3]], "equal-rewritten"]) & /@ fuzzB]] <> " & " <> ToString[Total[cnt[#[[3]], "WRONGVALUE"] & /@ fuzzB]] <> " & " <>
  ToString[Total[cnt[#[[3]], "denested"] & /@ fuzzC]] <> " & " <> ToString[Total[(cnt[#[[3]], "unchanged"] + cnt[#[[3]], "equal-rewritten"]) & /@ fuzzC]] <> " & " <> ToString[Total[cnt[#[[3]], "WRONGVALUE"] & /@ fuzzC]] <> " & " <>
  fmtTime[Total[fuzzC[[All, 4]]]] <> " & " <> fmtTime[Max[fuzzC[[All, 5]]]] <> "\\\\"];
AppendTo[lines, "\\bottomrule"]; AppendTo[lines, "\\end{tabular}"];
Export[outdir <> "fuzz.tex", StringRiffle[lines, "\n"], "Text"];
Print["wrote fuzz.tex"];

(* differential corpus of review-8 *)
diff = Get[scratch <> "differential3_rows.m"];
lines = {"\\begin{longtable}{@{}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.23\\textwidth}p{0.03\\textwidth}p{0.055\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.2\\textwidth}p{0.03\\textwidth}p{0.055\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.2\\textwidth}@{}}",
  "\\caption{The differential corpus of review-8 (\\texttt{tests/differential.wls}), run natively against \\texttt{StradFixed2} and \\texttt{StradFixed3} with a 60\\,s budget. A \\textbf{NO} after a depth would mark an output not exactly equal to its input.}\\label{tab:diff}\\\\",
  "\\toprule Input & \\multicolumn{3}{l}{StradFixed2: depth, time (s), output} & \\multicolumn{3}{l}{StradFixed3: depth, time (s), output}\\\\\\midrule\\endfirsthead",
  "\\toprule Input & \\multicolumn{3}{l}{StradFixed2: depth, time (s), output} & \\multicolumn{3}{l}{StradFixed3: depth, time (s), output}\\\\\\midrule\\endhead",
  "\\bottomrule\\endfoot"};
Do[AppendTo[lines, StringJoin[breakable[ToString[r["Input"], InputForm]], " & ", ToString[r["OldDepth"]], If[r["OldEqual"] =!= True, " \\textbf{NO}", ""], " & ", fmtTime[r["OldSeconds"]], " & ", breakable[shorten[ToString[r["OldResult"], InputForm]]],
   " & ", ToString[r["NewDepth"]], If[r["NewEqual"] =!= True, " \\textbf{NO}", ""], " & ", fmtTime[r["NewSeconds"]], " & ", breakable[shorten[ToString[r["NewResult"], InputForm]]], "\\\\"]], {r, diff}];
AppendTo[lines, "\\end{longtable}"];
Export[outdir <> "differential.tex", StringRiffle[lines, "\n"], "Text"];
Print["wrote differential.tex"];
Print["DONE"];
