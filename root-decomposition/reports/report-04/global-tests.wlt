(* Optional, more expensive tests of the finite additive algorithm. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
VerificationTest[Module[{a=Sqrt[2]+Sqrt[3],r},
 r=RDGlobalSum[a]; {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"],r["EnumeratedSubfields"]}],
 {True,2,True,5},TestID->"all-biquadratic-subfields"]
VerificationTest[Module[{a=1+Sqrt[2]+Sqrt[3],r},
 r=RDGlobalSum[a]; {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],
 {True,2,True},TestID->"biquadratic-global-sum"]
VerificationTest[Module[{a=Sqrt[2],r},
 r=RDSumInFields[a,{Sqrt[2]+Sqrt[3]}];
 {RDVerify[a,r],r["FieldDegreeThreshold"]}],
 {True,4},TestID->"supplied-field-threshold-not-element-degree"]
VerificationTest[Module[{a=Root[#^6+4#^2-1&,2],r},
 r=RDGlobalSum[a,"TimeLimit"->1800,"MaxFieldDegree"->48];
 {RDVerify[a,r],r["MaximumDegree"],r["GlobalOptimal"]}],
 {True,4,True},TestID->"quartic-pair-sum-degree-six"]
