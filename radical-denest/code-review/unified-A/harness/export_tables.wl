(* Convert experiment row files into LaTeX longtable fragments *)
scratch = "C:/Users/vresh/AppData/Local/Temp/claude/C--RadicalDenest--claude-worktrees-strad-denesting-analysis-6158e6/8331ac58-d8d2-4638-b75d-79549acb84bf/scratchpad/";
outdir = "C:/RadicalDenest/.claude/worktrees/strad-denesting-analysis-6158e6/src/code-review/unified-A/tables/";
If[! DirectoryQ[outdir], CreateDirectory[outdir]];

texEscape[s_String] := StringReplace[s, {"\\" -> "\\textbackslash{}", "&" -> "\\&", "%" -> "\\%", "$" -> "\\$", "#" -> "\\#", "_" -> "\\_", "{" -> "\\{", "}" -> "\\}", "~" -> "\\textasciitilde{}", "^" -> "\\textasciicircum{}"}];
(* allow line breaks in long code strings: insert \allowbreak after some characters *)
breakable[s_String] := StringReplace[texEscape[s], {"]" -> "]\\allowbreak{}", "[" -> "[\\allowbreak{}", ")" -> ")\\allowbreak{}", "(" -> "(\\allowbreak{}", "*" -> "*\\allowbreak{}", "/" -> "/\\allowbreak{}", "," -> ",\\allowbreak{}", " + " -> " +\\allowbreak{} ", " - " -> " -\\allowbreak{} ", "\\textasciicircum{}" -> "\\textasciicircum{}\\allowbreak{}"}];
stripHold[s_String] := StringReplace[s, {StartOfString ~~ "HoldForm[" ~~ body__ ~~ "]" ~~ EndOfString :> body}];
fmtTime[t_] := ToString[NumberForm[N[t], {5, 3}]];
fmtFlag[f_] := Switch[f, True, "yes", False, "\\textbf{NO}", "n/a", "--", _, ToString[f]];

writeTable[rows_List, file_String, caption_String, label_String, ids_: All] := Module[{sel, lines},
  sel = If[ids === All, rows, Select[rows, MemberQ[ids, #["id"]] &]];
  lines = {
    "\\begin{longtable}{@{}p{0.055\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.33\\textwidth}>{\\ttfamily\\footnotesize\\raggedright\\arraybackslash}p{0.33\\textwidth}p{0.05\\textwidth}p{0.05\\textwidth}p{0.05\\textwidth}@{}}",
    "\\caption{" <> caption <> "}\\label{" <> label <> "}\\\\",
    "\\toprule ID & Input & Output & Equal & Depth & Time (s)\\\\\\midrule\\endfirsthead",
    "\\toprule ID & Input & Output & Equal & Depth & Time (s)\\\\\\midrule\\endhead",
    "\\bottomrule\\endfoot"};
  Do[
   AppendTo[lines, StringJoin[
     r["id"], " & ", breakable[stripHold[r["input"]]], " & ", breakable[r["result"]],
     If[r["messages"] =!= {}, "\\newline{\\scriptsize\\itshape " <> StringReplace[texEscape[StringRiffle[r["messages"], ", "]], "::" -> "::\\allowbreak{}"] <> "}", ""],
     " & ", fmtFlag[If[r["exact"] === "n/a", r["numeric"], r["exact"]]], " & ",
     ToString[r["depth"][[1]]] <> "$\\to$" <> ToString[r["depth"][[2]]], " & ", fmtTime[r["time"]],
     "\\\\"]], {r, sel}];
  AppendTo[lines, "\\end{longtable}"];
  Export[outdir <> file, StringRiffle[lines, "\n"], "Text"];
  Print["wrote ", file, " (", Length[sel], " rows)"]];

orig = Get[scratch <> "exp_original_rows.m"];
help = Get[scratch <> "exp_helpers_rows.m"];
r2 = Get[scratch <> "exp_round2_rows.m"];
r3 = Get[scratch <> "exp_round3_rows.m"];
fixed = Get[scratch <> "exp_fixed_rows.m"];

pick[rows_, prefix_] := Select[rows, StringStartsQ[#["id"], prefix] &];

writeTable[pick[orig, "A"], "orig_A.tex", "Original program on classical denesting identities. ``Equal'' is exact equality (\\texttt{RootReduce}) with the expected value; where an expected value was not supplied, numeric agreement with the input is shown. Depth is the syntactic radical depth before and after.", "tab:origA"];
writeTable[pick[orig, "B"], "orig_B.tex", "Original program on non-denestable and trivial inputs.", "tab:origB"];
writeTable[pick[orig, "C"], "orig_C.tex", "Original program on branch counterexamples (wrapper level). ``Equal'' compares with the true value of the input.", "tab:origC"];
writeTable[pick[orig, "D"], "orig_D.tex", "Original core \\texttt{denest11} called directly with forced multipliers.", "tab:origD"];
writeTable[pick[orig, "E"], "orig_E.tex", "Original program on symbolic input.", "tab:origE"];
writeTable[pick[help, "H"], "help_H.tex", "\\texttt{Factorc} on symbolic and numeric inputs. ``Equal'' is exact equality with the input.", "tab:helpH"];
writeTable[Join[pick[help, "R"], pick[help, "M"], pick[help, "N"], pick[help, "S"]], "help_RMNS.tex", "Helper-level probes: \\texttt{RationalizeDenominator}, marker collisions, nesting helpers, comparator, slice, \\texttt{PossibleZeroQ}.", "tab:helpR"];
writeTable[Join[pick[r2, "J"], pick[r2, "K"]], "r2_JK.tex", "Original program: wrapper-level numeric branch errors caused by \\texttt{Factorc} (J) and miscellaneous inputs (K).", "tab:r2JK"];
writeTable[Join[pick[r2, "L"], pick[r2, "M"], pick[r2, "N"]], "r2_LMN.tex", "Original program: higher-order roots and timing (L), \\texttt{PossibleZeroQ} on actual candidate differences (M), prime processing with the original and the corrected comparator (N).", "tab:r2LMN"];
writeTable[Join[pick[r3, "Q"], pick[r3, "R"], pick[r3, "S"]], "r3_QRS.tex", "Original program: roots of negative bases (Q), the \\texttt{Ceiling[Log]} issue (R), output quality for a four-term square root (S).", "tab:r3QRS"];
writeTable[pick[fixed, "A"], "fixed_A.tex", "Corrected version on the classical identities (compare Table~\\ref{tab:origA}).", "tab:fixedA"];
writeTable[Join[pick[fixed, "B"], pick[fixed, "C"]], "fixed_BC.tex", "Corrected version on non-denestable inputs (B) and on the branch counterexamples (C).", "tab:fixedBC"];
writeTable[Join[pick[fixed, "D"], pick[fixed, "E"]], "fixed_DE.tex", "Corrected version: direct core calls with forced multipliers (D) and symbolic input (E).", "tab:fixedDE"];
writeTable[Join[pick[fixed, "J"], pick[fixed, "K"]], "fixed_JK.tex", "Corrected version: factorizer and rationalizer probes (J) and miscellaneous inputs (K).", "tab:fixedJK"];
writeTable[Join[pick[fixed, "L"], pick[fixed, "Q"]], "fixed_LQ.tex", "Corrected version: higher-order roots (L) and roots of negative bases (Q).", "tab:fixedLQ"];
Print["DONE"];
