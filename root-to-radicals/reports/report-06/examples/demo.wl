(* Get the package first; see README.md. *)
a = Root[-1-#^2-#^3+#^4+#^6&,2];
b = RootToRadicals[a];
Print[{b,RootReduce[b-a]===0}];
a = Root[6+25#-25#^3+5#^5&,5];
b = RootToRadicals[a];
Print[{b,RootReduce[b-a]===0}];
(* Requires Python backend: *)
Print[RadicalizeRoot[Root[#^5-#-1&,1],"UseNative"->False]];
