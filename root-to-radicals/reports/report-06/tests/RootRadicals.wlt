(* Wolfram MUnit tests. These are supplied for local execution, not claimed run. *)
(* Load wolfram/RootRadicals.wl before TestReport on this file. *)
VerificationTest[
  Module[{a=Root[-1-#^2-#^3+#^4+#^6&,2],b},b=RootToRadicals[a];
    ExactRadicalQ[b] && RootReduce[b-a]===0],True,TestID->"original-sextic"]
VerificationTest[
  Module[{a=Root[6+25#-25#^3+5#^5&,5],b},b=RootToRadicals[a];
    ExactRadicalQ[b] && RootReduce[b-a]===0],True,TestID->"original-quintic"]
VerificationTest[
  Module[{a=Root[(#-3)^7+2&,7],b},b=RootToRadicals[a];
    ExactRadicalQ[b] && RootReduce[b-a]===0],True,TestID->"complex-septic"]
VerificationTest[RootToRadicals[17/23],17/23,TestID->"rational"]
VerificationTest[RadicalizeRoot[1.414]["Status"],"InvalidInput",TestID->"reject-float"]
VerificationTest[ExactRadicalQ[Sin[Pi/7]],False,TestID->"reject-hidden-trig"]
VerificationTest[
 DecodeRadicalProgram[<|"format"->"rootradicals-dag-v1",
  "nodes"->{<|"op"->"Q","n"->"2","d"->"1"|>,
   <|"op"->"Pow","base"->0,"n"->"1","d"->"2"|>},"output"->1|>],
 Sqrt[2],TestID->"strict-DAG-decoder"]
VerificationTest[
 DecodeRadicalProgram[<|"format"->"rootradicals-dag-v1",
  "nodes"->{<|"op"->"Get","file"->"malicious.wl"|>},"output"->0|>],
 $Failed,TestID->"no-code-evaluation"]
(* The following require the Python backend and SymPy 1.14.0. *)
VerificationTest[
 Module[{a=Root[#^4-2&,4],r},r=RadicalizeRoot[a,Method->"Galois"];
   r["Status"]==="Success" && RootReduce[r["Expression"]-a]===0],
 True,TestID->"python-D4-exact-check"]
VerificationTest[
 RadicalizeRoot[Root[#^5-#-1&,1],"UseNative"->False]["Status"],
 "NotSolvable",TestID->"proved-nonsolvable"]
VerificationTest[
 RadicalizeRoot[Root[#^3-2&,1],Method->"Galois","MaxFieldDegree"->2]["Status"],
 "ResourceLimit",TestID->"resource-not-impossibility"]
