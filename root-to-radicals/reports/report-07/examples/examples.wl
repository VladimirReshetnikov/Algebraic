(* Run after loading Wolfram/SystematicRadicals.wl. No outputs below are
   represented as results of an executed Wolfram kernel in this release. *)
a=Root[-1-#^2-#^3+#^4+#^6&,2];
r=RadicalSolve[a,Method->"Practical"];
Print[r];
If[r["Status"]==="Success",Print[RadicalVerify[a,r["Expression"]]]];

b=Root[6+25#-25#^3+5#^5&,5];
s=SystematicToRadicals[b,Method->"Practical"];
Print[s];Print[RadicalVerify[b,s]];

c=Root[#^3-2&,1];
tower=RadicalSolve[c,Method->"Complete",TimeConstraint->120];
Print[tower];Print[RadicalTowerVerify[tower]];

(* Unbounded algorithm: resource usage can be enormous.
RadicalSolve[a,Method->"Complete",TimeConstraint->Infinity,
  "MaxFieldDegree"->Infinity]
*)
