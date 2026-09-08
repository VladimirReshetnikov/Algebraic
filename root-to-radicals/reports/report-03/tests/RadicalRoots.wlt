(* Native Wolfram tests: provided for execution; NOT run in the authoring environment. *)
Get[FileNameJoin[{DirectoryName[$InputFileName],"..","Kernel","RadicalRoots.wl"}]];
VerificationTest[
 Module[{r=Root[-1-#^2-#^3+#^4+#^6&,2],e},
  e=RadicalRoot[r,"Method"->"Fast"];
  RadicalExpressionQ[e] && RadicalEqualQ[e,r]],
 True,TestID->"original-sextic-selected-root"]
VerificationTest[
 Module[{r=Root[6+25 #-25 #^3+5 #^5&,5],e},
  e=RadicalRoot[r,"Method"->"Fast"];
  RadicalExpressionQ[e] && RadicalEqualQ[e,r]],
 True,TestID->"original-quintic-selected-root"]
VerificationTest[
 And@@Table[With[{r=Root[-1-#^2-#^3+#^4+#^6&,k]},
  With[{e=RadicalRoot[r,"Method"->"Fast"]},
    RadicalExpressionQ[e] && RadicalEqualQ[e,r]]],{k,1,6}],
 True,TestID->"all-sextic-conjugates"]
VerificationTest[
 And@@Table[With[{r=Root[6+25 #-25 #^3+5 #^5&,k]},
  With[{e=RadicalRoot[r,"Method"->"Fast"]},
    RadicalExpressionQ[e] && RadicalEqualQ[e,r]]],{k,1,5}],
 True,TestID->"all-quintic-conjugates"]
VerificationTest[
 With[{r=Root[-2+#^7&,1]},RadicalEqualQ[RadicalRoot[r,"Method"->"Fast"],r]],
 True,TestID->"septic-binomial"]
VerificationTest[
 Module[{r=Root[-2+#^3&,1],report},report=RadicalRootReport[r,"Method"->"Galois"];
  report["Status"]==="Success" && RadicalEqualQ[report["Expression"],r]],
 True,TestID->"general-cubic"]
VerificationTest[
 RadicalRootReport[Root[-1-#+#^5&,1],"Method"->"Fast"]["Status"],
 "Unknown",TestID->"fast-miss-is-not-nonsolvability"]
VerificationTest[
 RadicalRootReport[Root[-2+#^3&,1],"Method"->"Galois","MaxFieldDegree"->1]["Status"],
 "ResourceLimit",TestID->"field-budget"]
VerificationTest[RadicalExpressionQ[(-1)^(2/7)],True,TestID->"unity-is-a-radical"]
VerificationTest[RadicalExpressionQ[Cos[Pi/7]],False,TestID->"no-trig-output"]
VerificationTest[RadicalExpressionQ[Root[-1-#+#^5&,1]],False,TestID->"no-root-output"]
VerificationTest[RadicalEqualQ[Sqrt[2],-Sqrt[2]],False,TestID->"reject-wrong-conjugate"]
VerificationTest[RadicalRootReport[1.2]["Status"],"InvalidInput",TestID->"reject-floats"]
VerificationTest[RadicalRoot[7/3],7/3,TestID->"rational-input"]
