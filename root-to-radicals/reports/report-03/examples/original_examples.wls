Get[FileNameJoin[{DirectoryName[$InputFileName],"..","Kernel","RadicalRoots.wl"}]];
sextic=Root[-1-#^2-#^3+#^4+#^6&,2];
quintic=Root[6+25 #-25 #^3+5 #^5&,5];
Do[report=RadicalRootReport[r,"Method"->"Fast"];
 Print[InputForm[report]];Print[RadicalEqualQ[report["Expression"],r]],
 {r,{sextic,quintic}}];
(* A general, potentially expensive computation:
RadicalRootReport[Root[-2+#^3&,1],"Method"->"Galois"]

Removing the implemented resource caps does NOT remove backend limitations:
RadicalRootReport[sextic,"Method"->"Galois","TimeConstraint"->Infinity,
 "MaxFieldDegree"->Infinity,"MaxNodes"->Infinity,"MaxDepth"->Infinity]
*)
