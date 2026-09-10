(* Native diagnostic probes, NOT previously executed.
   wolframscript -file tests/probe_original.wls /path/to/StradFixed2.wl
   The last probe exercises a private helper's incumbent contract, not a claim
   that the full public pipeline necessarily returns a wrong result. *)
args = Rest[$ScriptCommandLine];
If[Length[args] < 1, Print["Supply the path of StradFixed2.wl."]; Exit[2]];
Get[First[args]];
Print["Kernel: ", $Version];
r = Root[#^3 + Pi # + 1 &, 1];
Print["Nonalgebraic Root: ", InputForm[r]];
Print["Precision: ", Precision[r]];
Print["ExactAlgebraicQ (should be False): ", RadicalDenest2`ExactAlgebraicQ[r]];
symbolic = Root[#^3 - # + parameter &, 1];
Print["Symbolic Root accepted: ", RadicalDenest2`ExactAlgebraicQ[symbolic]];
target = (3 + 2 Sqrt[2])^(1/6); incumbent = (1 + Sqrt[2])^(1/3);
result = RadicalDenest2`Private`standalone[
 Block[{RadicalDenest2`Private`$cfg = Join[RadicalDenest2`Private`$cfg,
    <|"MaxRecursion" -> 0, "MaxTrials" -> 0, "NumericPrefilter" -> False|>]},
  RadicalDenest2`Private`powerProposals[target, incumbent]], $Failed];
Print["Equal input/incumbent: ", RootReduce[target - incumbent] === 0];
Print["Input/incumbent/result costs: ", RadicalDenest2`RadicalCost /@ {target, incumbent, result}];
Print["Helper result: ", InputForm[result]];
Print["Malformed-option result: ", InputForm[RadicalDenest2`Strad[target, 17]]];
