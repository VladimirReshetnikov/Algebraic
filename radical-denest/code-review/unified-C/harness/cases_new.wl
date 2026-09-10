(* Round-3 cases (group N): the inputs that the three reviews of StradFixed2
   (review-7, review-8, review-9) used to motivate their findings, plus the
   controls of the unified-C report. Read by exp_battery3.wl (StradFixed3) and
   exp_new2.wl (StradFixed2) after the respective runner defined runCase/add. *)
Print["=== N. Round-3 cases (coset search, odd indices, Honsbeek, index reduction, grammar) ==="];
add@runCase["N01", Strad[Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]]], Sqrt[6] + Sqrt[35] + Sqrt[77]];
add@runCase["N02", Strad[Sqrt[37 + 4 Sqrt[15] + 6 Sqrt[14] + 2 Sqrt[210]]], Sqrt[6] + Sqrt[10] + Sqrt[21]];
add@runCase["N03", Strad[Sqrt[60 + 10 Sqrt[6] + 10 Sqrt[14] + 10 Sqrt[21]]], Sqrt[10] + Sqrt[15] + Sqrt[35]];
add@runCase["N04", Strad[Sqrt[142 + 28 Sqrt[15] + 20 Sqrt[21] + 12 Sqrt[35]]], Sqrt[30] + Sqrt[42] + Sqrt[70]];
add@runCase["N05", Strad[Sqrt[(5 + Sqrt[6] + Sqrt[10] + Sqrt[15])/2]], (Sqrt[2] + Sqrt[3] + Sqrt[5])/2];
add@runCase["N06", Strad[Sqrt[118 + 2 Sqrt[210] + 14 Sqrt[55] + 2 Sqrt[462]], "MaxTrials" -> 0], Sqrt[6] + Sqrt[35] + Sqrt[77]];
add@runCase["N07", Strad[Sqrt[142 + 28 Sqrt[15] + 20 Sqrt[21] + 12 Sqrt[35]], "MaxTrials" -> 0], Sqrt[30] + Sqrt[42] + Sqrt[70]];
add@runCase["N08", Strad[(41 + 29 Sqrt[2])^(1/5)], 1 + Sqrt[2]];
add@runCase["N09", Strad[(41 - 29 Sqrt[2])^(1/5)], (-1)^(1/5) (Sqrt[2] - 1)];
add@runCase["N10", Strad[(239 + 169 Sqrt[2])^(1/7)], 1 + Sqrt[2]];
add@runCase["N11", Strad[(-239 - 169 Sqrt[2])^(1/7)], (-1)^(1/7) (1 + Sqrt[2])];
add@runCase["N12", Strad[(1393 - 985 Sqrt[2])^(1/9)], (-1)^(1/9) (Sqrt[2] - 1)];
add@runCase["N13", Strad[Expand[(2 + Sqrt[3])^9]^(1/9)], 2 + Sqrt[3]];
add@runCase["N14", Strad[Expand[(1 + Sqrt[5])^11]^(1/11)], None];
add@runCase["N15", Strad[Expand[(1 + Sqrt[5])^11]^(1/11), "MaxOddIndex" -> 11], 1 + Sqrt[5]];
add@runCase["N16", Strad[Sqrt[28^(1/3) - 3]], (98^(1/3) - 28^(1/3) - 1)/3];
add@runCase["N17", Strad[Sqrt[5^(1/3) - 4^(1/3)]], (2^(1/3) + 20^(1/3) - 25^(1/3))/3];
add@runCase["N18", Strad[(3 + 2 Sqrt[2])^(1/4)], Sqrt[1 + Sqrt[2]]];
add@runCase["N19", Strad[(3 + 2 Sqrt[2])^(1/6)], (1 + Sqrt[2])^(1/3)];
add@runCase["N20", Strad[(3 + 2 Sqrt[2])^(1/6), "MaxRecursion" -> 0], (1 + Sqrt[2])^(1/3)];
add@runCase["N21", Strad[(7 20^(1/3) - 19)^(1/6)], None];
add@runCase["N22", Strad[(133 + 57 2^(2/3) 3^(1/3) + 48 2^(1/3) 3^(2/3))^(1/6)], None];
add@runCase["N23", Strad[Sqrt[1 + Sqrt[3]] + Sqrt[3 + 3 Sqrt[3]] - Sqrt[10 + 6 Sqrt[3]]], None];
add@runCase["N24", Strad[1/(Sqrt[2] + Sqrt[3 + 2 Sqrt[2]])], (2 Sqrt[2] - 1)/7];
add@runCase["N25", Strad[Sqrt[-(16 - 2 Sqrt[29] + 2 Sqrt[55 - 10 Sqrt[29]])]], I (Sqrt[5] + Sqrt[11 - 2 Sqrt[29]])];
add@runCase["N26", Strad[Root[#^5 + # - Pi &, 1]], None];
add@runCase["N27", Strad[Root[#^5 + # - 1 &, 1] + Sqrt[5 + 2 Sqrt[6]]], None];
add@runCase["N28", Strad[Sqrt[2], 17], None];
add@runCase["N29", Strad[Sqrt[1 + Sqrt[2]]], None];
add@runCase["N30", Strad[Sqrt[2 + Sqrt[3] + Sqrt[5]]], None];
add@runCase["N31", Strad[Sqrt[2 + Sqrt[3]] + Sqrt[5 + 2 Sqrt[6]], True], None];
add@runCase["N32", Strad[Expand[(Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7])^2]^(1/2)], Sqrt[2] + Sqrt[3] + Sqrt[5] + Sqrt[7]];
add@runCase["N33", Strad[Expand[(Sqrt[6] + Sqrt[10] + Sqrt[15] + Sqrt[21] + Sqrt[35])^2]^(1/2)], Sqrt[6] + Sqrt[10] + Sqrt[15] + Sqrt[21] + Sqrt[35]];
Print["=== N. equality status of conjugates ==="];
Print["EqualityStatus[Sqrt[2], -Sqrt[2]] = ", EqualityStatus[Sqrt[2], -Sqrt[2]]];
Print["EqualityStatus[Root[#^5 + # - Pi &, 1], 0] = ", EqualityStatus[Root[#^5 + # - Pi &, 1], 0]];
Print["ExactAlgebraicQ[Root[#^5 + # - Pi &, 1]] = ", ExactAlgebraicQ[Root[#^5 + # - Pi &, 1]]];
Print["RadicalCost[1 + 2^100 I] = ", RadicalCost[1 + 2^100 I], "   RadicalCost[1 + I] = ", RadicalCost[1 + I]];
