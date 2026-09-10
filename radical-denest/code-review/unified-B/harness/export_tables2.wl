(* Convert the recorded unified-B runs into LaTeX table fragments.
   Reads the row files written by exp_battery2.wl (and unified-A's exp_fixed.wl
   for the side-by-side comparison) and the fuzz results of exp_fuzz2.wl. *)
scratch = "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/";
outdir = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-B/tables/";
If[! DirectoryQ[outdir], CreateDirectory[outdir]];

texEscape[s_String] := StringReplace[s, {"\\" -> "\\textbackslash{}", "&" -> "\\&", "%" -> "\\%", "$" -> "\\$", "#" -> "\\#", "_" -> "\\_", "{" -> "\\{", "}" -> "\\}", "~" -> "\\textasciitilde{}", "^" -> "\\textasciicircum{}"}];
breakable[s_String] := StringReplace[texEscape[s], {"]" -> "]\\allowbreak{}", "[" -> "[\\allowbreak{}", ")" -> ")\\allowbreak{}", "(" -> "(\\allowbreak{}", "*" -> "*\\allowbreak{}", "/" -> "/\\allowbreak{}", "," -> ",\\allowbreak{}", " + " -> " +\\allowbreak{} ", " - " -> " -\\allowbreak{} ", "\\textasciicircum{}" -> "\\textasciicircum{}\\allowbreak{}"}];
stripHold[s_String] := StringReplace[s, {StartOfString ~~ "HoldForm[" ~~ body__ ~~ "]" ~~ EndOfString :> body}];
fmtTime[t_] := ToString[NumberForm[N[t], {5, 3}]];
fmtFlag[f_] := Switch[f, True, "yes", False, "\\textbf{NO}", "n/a", "--", _, ToString[f]];
depthStr[d_] := ToString[d[[1]]] <> "$\\to$" <> ToString[d[[2]]];

writeTable[rows_List, file_String, caption_String, label_String] := Module[{lines},
  lines = {
    "\\begin{longtable}{@{}p{0.055\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.33\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.33\\textwidth}p{0.05\\textwidth}p{0.05\\textwidth}p{0.05\\textwidth}@{}}",
    "\\caption{" <> caption <> "}\\label{" <> label <> "}\\\\",
    "\\toprule ID & Input & Output & Equal & Depth & Time (s)\\\\\\midrule\\endfirsthead",
    "\\toprule ID & Input & Output & Equal & Depth & Time (s)\\\\\\midrule\\endhead",
    "\\bottomrule\\endfoot"};
  Do[AppendTo[lines, StringJoin[
     r["id"], " & ", breakable[stripHold[r["input"]]], " & ", breakable[r["result"]],
     If[r["messages"] =!= {}, "\\newline{\\scriptsize\\itshape " <> StringReplace[texEscape[StringRiffle[r["messages"], ", "]], "::" -> "::\\allowbreak{}"] <> "}", ""],
     " & ", fmtFlag[If[r["exact"] === "n/a", r["numeric"], r["exact"]]], " & ", depthStr[r["depth"]], " & ", fmtTime[r["time"]], "\\\\"]], {r, rows}];
  AppendTo[lines, "\\end{longtable}"];
  Export[outdir <> file, StringRiffle[lines, "\n"], "Text"];
  Print["wrote ", file, " (", Length[rows], " rows)"]];

(* side-by-side: first corrected version vs second *)
writeCompare[rowsA_List, rowsB_List, file_String, caption_String, label_String] := Module[{lines, a},
  lines = {
    "\\begin{longtable}{@{}p{0.045\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.28\\textwidth}p{0.055\\textwidth}p{0.065\\textwidth}p{0.055\\textwidth}p{0.065\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.27\\textwidth}@{}}",
    "\\caption{" <> caption <> "}\\label{" <> label <> "}\\\\",
    "\\toprule ID & Input & \\multicolumn{2}{l}{StradFixed} & \\multicolumn{2}{l}{StradFixed2} & Output of StradFixed2\\\\ & & depth & time (s) & depth & time (s) & \\\\\\midrule\\endfirsthead",
    "\\toprule ID & Input & \\multicolumn{2}{l}{StradFixed} & \\multicolumn{2}{l}{StradFixed2} & Output of StradFixed2\\\\ & & depth & time (s) & depth & time (s) & \\\\\\midrule\\endhead",
    "\\bottomrule\\endfoot"};
  Do[a = SelectFirst[rowsA, #["id"] === b["id"] &, None];
   AppendTo[lines, StringJoin[
     b["id"], " & ", breakable[stripHold[b["input"]]], " & ",
     If[a === None, "--", depthStr[a["depth"]]], " & ", If[a === None, "--", fmtTime[a["time"]]], " & ",
     depthStr[b["depth"]], If[b["exact"] === False || b["numeric"] === False, " \\textbf{WRONG}", ""], " & ", fmtTime[b["time"]], " & ",
     breakable[b["result"]], If[b["messages"] =!= {}, "\\newline{\\scriptsize\\itshape " <> texEscape[StringRiffle[b["messages"], ", "]] <> "}", ""],
     "\\\\"]], {b, rowsB}];
  AppendTo[lines, "\\end{longtable}"];
  Export[outdir <> file, StringRiffle[lines, "\n"], "Text"];
  Print["wrote ", file, " (", Length[rowsB], " rows)"]];

fixedA = Get[scratch <> "exp_fixed_rows.m"];
fixedB = Get[scratch <> "exp_battery2_rows.m"];
pick[rows_, prefixes_List] := Select[rows, StringStartsQ[#["id"], Alternatives @@ prefixes] &];

writeCompare[fixedA, pick[fixedB, {"A"}], "cmp_A.tex", "Classical identities: first corrected version (Table 5.16 of unified-A) against \\texttt{StradFixed2}. Depth is the syntactic radical depth before and after; every StradFixed2 output is exactly equal to its input.", "tab:cmpA"];
writeCompare[fixedA, pick[fixedB, {"B", "C"}], "cmp_BC.tex", "Non-denestable inputs (B) and branch counterexamples (C).", "tab:cmpBC"];
writeCompare[fixedA, pick[fixedB, {"D", "E"}], "cmp_DE.tex", "Direct core calls with forced multipliers (D) and symbolic input (E).", "tab:cmpDE"];
writeCompare[fixedA, pick[fixedB, {"J", "K"}], "cmp_JK.tex", "Factorizer and rationalizer probes (J) and miscellaneous inputs (K).", "tab:cmpJK"];
writeCompare[fixedA, pick[fixedB, {"L", "Q"}], "cmp_LQ.tex", "Higher-order roots (L) and roots of negative bases (Q).", "tab:cmpLQ"];

(* fuzz summary *)
fuzzA = Get[scratch <> "exp_fuzz_fixed_results.m"];
fuzzB = Get[scratch <> "exp_fuzz2_results.m"];
cnt[stats_, key_] := Lookup[stats, key, 0];
lines = {"\\begin{tabular}{@{}l r rrr rrr rr@{}}", "\\toprule",
  " & & \\multicolumn{3}{c}{StradFixed} & \\multicolumn{3}{c}{StradFixed2} & \\multicolumn{2}{c}{StradFixed2 time (s)}\\\\",
  "\\cmidrule(lr){3-5}\\cmidrule(lr){6-8}\\cmidrule(lr){9-10}",
  "Family & $n$ & denested & unchanged & \\textbf{wrong} & denested & unchanged & \\textbf{wrong} & total & max\\\\\\midrule"};
Do[a = fuzzA[[i]]; b = fuzzB[[i]];
 AppendTo[lines, StringJoin[StringReplace[b[[1]], RegularExpression["^(F\\d+) .*$"] -> "$1"], " & ", ToString[b[[2]]], " & ",
   ToString[cnt[a[[3]], "denested"]], " & ", ToString[cnt[a[[3]], "unchanged"] + cnt[a[[3]], "equal-rewritten"]], " & ", ToString[cnt[a[[3]], "WRONGVALUE"]], " & ",
   ToString[cnt[b[[3]], "denested"]], " & ", ToString[cnt[b[[3]], "unchanged"] + cnt[b[[3]], "equal-rewritten"]], " & ", ToString[cnt[b[[3]], "WRONGVALUE"]], " & ",
   fmtTime[b[[4]]], " & ", fmtTime[b[[5]]], "\\\\"]], {i, Length[fuzzB]}];
AppendTo[lines, "\\midrule Total & " <> ToString[Total[fuzzB[[All, 2]]]] <> " & " <>
  ToString[Total[cnt[#[[3]], "denested"] & /@ fuzzA]] <> " & " <> ToString[Total[(cnt[#[[3]], "unchanged"] + cnt[#[[3]], "equal-rewritten"]) & /@ fuzzA]] <> " & " <> ToString[Total[cnt[#[[3]], "WRONGVALUE"] & /@ fuzzA]] <> " & " <>
  ToString[Total[cnt[#[[3]], "denested"] & /@ fuzzB]] <> " & " <> ToString[Total[(cnt[#[[3]], "unchanged"] + cnt[#[[3]], "equal-rewritten"]) & /@ fuzzB]] <> " & " <> ToString[Total[cnt[#[[3]], "WRONGVALUE"] & /@ fuzzB]] <> " & " <>
  fmtTime[Total[fuzzB[[All, 4]]]] <> " & " <> fmtTime[Max[fuzzB[[All, 5]]]] <> "\\\\"];
AppendTo[lines, "\\bottomrule"]; AppendTo[lines, "\\end{tabular}"];
Export[outdir <> "fuzz.tex", StringRiffle[lines, "\n"], "Text"];
Print["wrote fuzz.tex"];
Print["DONE"];
