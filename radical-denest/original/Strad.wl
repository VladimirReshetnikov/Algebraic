ClearAll[Strad];
Unprotect[Print];
Strad[eaf__] := Block[{Print = (Null &)}, DenestRadicals3[eaf]];
ClearAll[DenestRadicals3];
DenestRadicals3[expr_, alllevels_ : False, func_ : denest11] :=
 Block[{f, mod, level, problems, i1, i2},
  If[alllevels =!= True,
   level = ReplaceAll,
   level = ReplaceRepeated
   ];
  mod = level[Factorc[expr],
    radicand_?AlgebraicQ^pow_Rational :> Block[{factored, SumQ, i, j},
      SumQ[expression_] :=
       MemberQ[
        expression, _Plus | Complex[Except[0], _], {0, Infinity}];
      factored = FactorTermsList[radicand];
      factored[[2]] = 
       Flatten[{Replace[Factorc[factored[[2]]], 
          prod_Times :> List @@ prod]}];
      factored[[1]] = 
       DeleteCases[{#, ComplexExpand[factored[[1]]/#]} &[
         GCD[Re[factored[[1]]], Im[factored[[1]]]]], 1];
      factored[[1]] = #[[1]]^#[[2]] & /@ 
        Flatten[FactorInteger /@ factored[[1]], 1];
      factored = Flatten[factored];
      factored = 
       factored //. 
        list : {a___, expr1_, b___, expr2_, c___} :> {a, b, c, 
           ComplexExpand[expr1*expr2]} /; And[SumQ[expr1], SumQ[expr2]];
      j = 1;
      For[{i = 1}, i <= Length[factored], i++,
       If[N[Re[factored[[i]]], 100] < 0,
        factored[[i]] = -factored[[i]];
        j *= -1
        ]
       ];
      factored = DeleteCases[Prepend[factored, j], 1];
      f[Simplify[
        Times @@ (Simplify[RationalizeDenominator[Together[#]]] & /@ 
           factored)], pow]
      ]
    ];
  mod = mod //. 
    prod : Times[a___, expr1 : f[rad1_, pow1_], b___, 
       expr2 : f[rad2_, pow2_], c___] :> 
     Times[a, b, c, f[(rad1^pow1)*(rad2^pow2)]] /; 
      And[! FreeQ[rad1, Power], ! FreeQ[rad2, Power]];
  mod = level[mod, f[rad_, pow_] :> f[rad^pow]];
  mod = mod //. 
    prod : Times[a___, expr1 : f[rad1_], b___, expr2 : f[rad2_], 
       c___] :> 
     Times[a, b, c, f[rad1*rad2]] /; 
      And[And[Re[#] != 0, Im[#] != 0] &[N[rad1, 10]], 
       And[Re[#] != 0, Im[#] != 0] &[N[rad2, 10]]];
  problems = DeleteDuplicates[Cases[mod, f[_], {0, Infinity}]];
  Print[problems];
  Print[];
  If[alllevels =!= True,
   mod = 
    Simplify[
     mod /. ((# -> Replace[#, f[val_] :> func[val]]) & /@ problems)],
   For[{i1 = 1}, MemberQ[problems, f[__]] === True, i1++,
    i1 = Mod[i1, Length[problems], 1];
    If[MatchQ[problems[[i1]], f[problem__] /; FreeQ[problem, f[__]]],
     problems[[i1]] = problems[[i1]] -> (problems[[i1]] /. f -> func);
     For[{i2 = 1}, i2 <= Length[problems], i2++,
      If[Head[problems[[i2]]] =!= Rule,
       problems[[i2]] = problems[[i2]] //. problems[[i1]];
       ]
      ];
     ];
    ];
   mod = Simplify[mod //. problems];
   ];
  Return[mod];
  ]
  
ClearAll[denest11];
denest11[problem_, forcedmultipliers_ : 0] :=
 Block[{radicand, outerpower, reductionpower, extrapower, 
   multiplierstack, multipliers, multiplier, terms, history, attempt, 
   solution, updatehistory, stackchange, addmultipliers, 
   trymultiplier, newmultipliers, x, i1, i2, i3},
  If[! MemberQ[problem, 
     Power[inner_?(Function[var, MemberQ[var, Power[a_, b_], Infinity]]),
       outer_], {0, Infinity}],
   Return[problem];
   ];
  Print["problem  ", problem];
  reductionpower = (LCM @@ (maxnestdepth[problem, 
        MatchQ[#, Power[_, _Rational]] &] /. {Power[base_, exp_], _} :>
         Denominator[exp]));
  outerpower = 1/reductionpower;
  radicand = problem^reductionpower;
  extrapower = 
   Times @@ ((LCM @@ #) & /@ (DeleteCases[
         Cases[nestdepthsort[radicand, 
           MatchQ[#, Power[_, _Rational]] &], 
          patt : {{expr_, nest_}, Repeated[{_, _}, {0, Infinity}]} /; 
           nest >= 2], {Except[Power[_, _Rational]], _}, {2}] /. 
        patt : {Power[base_, exp_], nest_} :> Denominator[exp]));
  Print["outer root: ", reductionpower, "  extra root: ", extrapower];
  Print[];
  
  (*tries a multiplier
  returns {<boolean progress>, {multiplier, minpoly, degree}, [answer]}*)
  trymultiplier[radicand_, outerpower_, multiplier_, best_, 
     worseknown_] /; MatchQ[outerpower, Rational[1, _Integer]] :=
   Block[{minpoly, degree, polygcd, possibilities, result, expected, 
     arg1},
    minpoly = MinimalPolynomial[(multiplier*radicand)^outerpower];
    degree = Exponent[minpoly[arg1], arg1];
    result = {False, {multiplier, minpoly, degree}};
    Print["multiplier: ", multiplier, "   minpoly degree: ", degree];
    If[Or[degree < best, GCD[degree, best] < best],
     polygcd = 
      PolynomialGCD[minpoly[arg1], 
       arg1^(1/outerpower) - multiplier*radicand, 
       Extension -> Automatic];
     If[And[Exponent[polygcd, arg1] < (1/outerpower), polygcd =!= 1],
      possibilities = 
       Flatten[Outer[Times, 
         arg1/(multiplier^outerpower) /. Solve[polygcd == 0, arg1], 
         Exp[2*I*\[Pi]*Range[0, (1/outerpower) - 1, 1]/(1/outerpower)]]];
      result = 
       DeleteDuplicates[
        Select[possibilities, PossibleZeroQ[# - radicand^outerpower] &]];
      If[Length[result] > 1,
       Print[Length[result], " possible solutions, taking the first"];
       Print[result];
       result = Take[result, 1];
       ];
      (*progress because a denesting occurred*)
      result = {True, {multiplier, minpoly, degree}, result[[1]]},
      If[polygcd =!= 1,
       If[
        Or[degree < best, 
         And[GCD[degree, best] < best, worseknown =!= True]],
        (*progress because degree of minpoly has decreased*)
        result = {True, {multiplier, minpoly, degree}}
        ],
       Print[
        "PolynomialGCD error: ", {radicand, outerpower, multiplier, 
         minpoly}]
       ]
      ],
     If[And[worseknown =!= True, degree != best],
      (*progress because this multiplier has greater degree than a pre\
vious multiplier*)
      Print["previous progress identified"];
      result = {True, {multiplier, minpoly, degree}};
      ]
     ];
    Return[result];
    ];
  
  (*form for attempts is {multiplier, minpoly, degree}, 
  attempt2 is Null if only one attempt is available*)
  newmultipliers[smaller_, larger_, reductionpower_] :=
   Block[{done, new, primes, multiplierprimes, minprimes, maxprimes, 
     primeratio, multipliercap, arg1},
    minprimes = 5;
    maxprimes = 14;
    primeratio = 100;
    multipliercap = 1000;
    
    (*two possibilites: reduction in degree, 
    reduction only in GCD of degrees*)
    If[Or[larger === Null, 
      GCD[smaller[[-1]], larger[[-1]]] == 
       Min[smaller[[-1]], larger[[-1]]]],
     (*one degree is a multiple of the other, usual case*)
     primes = 
      DeleteCases[
       FactorInteger[Discriminant[smaller[[2]][arg1], arg1], 
        Automatic], {-1, 1}];
     primes = 
      Sort[DeleteCases[primes, 
        factor : {prime_, _} /; 
         And[! PrimeQ[prime], (Print["composite factor: ", factor]; 
           True)]], #1[[1]] <= #[[2]] &];
     primes = Flatten[primes[[All, 1]]];
     multiplierprimes = primes;
     For[{i3 = Length[primes]}, 
      And[i3 > minprimes, 
       multiplierprimes[[i3]]/multiplierprimes[[i3 - 1]] > primeratio],
       i3--,
      multiplierprimes[[i3]] = 0;
      ];
     multiplierprimes = 
      DeleteCases[multiplierprimes, 0][[
       1 ;; Min[
         Max[minprimes, Ceiling[Log[multipliercap]/Log[reductionpower]]],
          Length[multiplierprimes]]]];
     new = 
      smaller[[1]]*
       Drop[Union[
         Divisors[(Times @@ multiplierprimes)^(reductionpower - 1)], 
         primes], 1];
     ,
     (*different degree reductions in each degree from a larger degree\
*)
     Print[
      "GCD of smallest degrees is smaller than any observed degree: \
", {smaller[[{1, -1}]], larger[[{1, -1}]]}];
     new = smaller[[1]]*larger[[1]]*{1};
     Print[PolynomialGCD @@ {smaller[[2]][x], larger[[2]][x]}];
     ];
    new = {{False, smaller}, ComplexitySort[new]};
    Return[new];
    ];
  
  (*compute initial set of multipliers*)
  If[ListQ[forcedmultipliers],
   multipliers = {{False, {0, Infinity, Infinity}}, forcedmultipliers},
   (*old, may be better*)
   (*
   terms=DeleteCases[Replace[#,{Times[a___,
   Alternatives[_Rational,_Integer],b___]\[RuleDelayed]a*b,
   Alternatives[_Rational,_Integer]\[Rule]0,Complex[a_,
   b_]\[RuleDelayed]Sign[b]*I}]&/@(List@@Expand[
   RationalizeDenominator[radicand]]),0];
   *)
   terms = 
    DeleteCases[
     Replace[#, {Times[a___, Alternatives[_Rational, _Integer], 
           b___] :> a*b, Alternatives[_Rational, _Integer] -> 0, 
         Complex[a_, b_] :> Sign[b]*I}] & /@ (List @@ 
        Expand[RationalizeDenominator[radicand]]), 0];
   multipliers = Prepend[Replace[If[Head[#] === Times,
         
         Times @@ (Function[{var}, 
             var^(maxnestdepth[var, 
                  Function[{var2}, 
                   MatchQ[var2, Power[_, _Rational]]]][[
                 1]] /. {{Power[base_, 
                    exp_], _} :> (Denominator[exp] - Numerator[exp])/
                   Numerator[exp], {Complex[
                    0, _], _} :> -1})] /@ (List @@ #)),
         #^(maxnestdepth[#, 
              Function[{var}, MatchQ[var, Power[_, _Rational]]]][[
             1]] /. {{Power[base_, 
                exp_], _} :> (Denominator[exp] - Numerator[exp])/
               Numerator[exp], {Complex[0, _], _} :> -1})
         ], 
        Times[a___, Alternatives[_Rational, _Integer], b___] :> 
         a*b] & /@ Sort[terms, (Re[#1] <= Re[#2]) &], 1];
   multipliers = {{True, {0, Infinity, Infinity}}, multipliers};
   ];
  
  solution = problem;
  history = {{0, Infinity, Infinity}};
  (*multiplierstack form {{{<do full set>,{<multiplier,minpoly,
  degree for generating this set>}},{<multipliers>}},...}*)
  multiplierstack = {multipliers};
  (*add power set of multipliers as second element in multiplierstack*)
  (*multiplierstack=Append[multiplierstack,
  {multiplierstack[[1,1]],ComplexitySort[DeleteCases[Union[(Times@@#)&/@
  Subsets[DeleteCases[multipliers[[2]],1]]],mult_/;MemberQ[
  multipliers[[2]],mult]]]}];*)
  Catch[
   For[{i1 = 1}, i1 <= Length[multiplierstack], i1++,
    (*compute new multipliers from data if not already done*)
    If[ListQ[multiplierstack[[i1, 2]]] =!= True,
     multiplierstack[[i1]] = 
       multiplierstack[[i1, -2]] @@ (multiplierstack[[i1, -1]]);
     ];
    multipliers = multiplierstack[[i1]];
    stackchange = False;
    If[multipliers[[1, 2]] =!= history[[1]],
     Print["multiplier count: ", Length[multipliers[[2]]], "  from: ",
       multipliers[[1, 2, {1, -1}]]],
     If[! ListQ[forcedmultipliers],
      Print["multiplier count: ", Length[multipliers[[2]]], 
        "  multipliers: ", multipliers[[2]]];,
      Print["multiplier count: ", Length[multipliers[[2]]]];
      ]
     ];
    For[{i2 = 1}, i2 <= Length[multipliers[[2]]], i2++,
     multiplier = multipliers[[2, i2]];
     updatehistory = False;
     addmultipliers = False;
     (*try a multiplier, different based on history*)
     If[And[Length[history] >= 3, history[[-2]] =!= history[[1]]],
      attempt = 
       trymultiplier[radicand, outerpower, multiplier, 
        history[[-1, -1]], True],
      attempt = 
        trymultiplier[radicand, outerpower, multiplier, 
         history[[-1, -1]], False];
      ];
     multiplierstack[[i1, 2, i2]] = {multiplier, attempt[[2, -1]]};
     
     If[And[multipliers[[1, 1]] === True, 
       attempt[[2, -1]] <= history[[-1, -1]]],
      addmultipliers = True
      ];
     (*check if progress has been made on this attempt, 
     no action taken if no progress*)
     If[attempt[[1]] === True,
      (*history will be updated*)
      updatehistory = True;
      
      (*decide if a stackchange will be made*)
      If[history[[-1]] =!= history[[1]],
       stackchange = True;
       ];
      
      If[ListQ[attempt[[-1]]] =!= True,
       (*a solution was obtained*)
       Print["success: ", 
        Join[attempt[[2, {1, -1}]], 
         If[IntegerQ[multiplier], {FactorInteger[multiplier]}, {}]]];
       solution = Simplify[attempt[[-1]]];
       If[
        Or[history[[-1]] === history[[1]], 
         history[[2, -1]]/attempt[[2, -1]] >= reductionpower],
        (*not worth trying for additional denesting, exit immediately*)
        history = Append[history, attempt[[2]]];
        Throw[, "solution"],
        (*further denesting will be attempted*)
        Print["attempting additional denesting, current solution is:"];
        Print[solution];
        ];
       ];
      
      If[
       And[history[[-1]] =!= history[[1]], 
        Or[attempt[[2, -1]] < history[[-1, -1]], 
         history[[-2]] === history[[1]]]],
       (*improvement has occured, new multipliers will be created*)
       Print["improvement  ", attempt[[2, {1, -1}]]];
       addmultipliers = True;
       ];
      ];
     
     (*add new multipliers if needed*)
     If[addmultipliers === True,
      Block[{smaller, larger, done, new},
       If[attempt[[2, -1]] <= history[[-1, -1]],
        smaller = attempt[[2]];
        larger = history[[-1]],
        smaller = history[[-1]];
        larger = attempt[[2]];
        ];
       new = {{False, smaller}, 
         newmultipliers, {smaller, 
          If[larger =!= history[[1]], larger, Null], reductionpower}};
       
       Print["adding new multipliers from: ", multiplier];
       (*update multiplierstack with new multipliers*)
       If[multipliers[[1, 1]] === False,
        (*use new multipliers immediately*)
        done = {multipliers[[1]], multipliers[[2, 1 ;; i2]]};
        multiplierstack = Insert[multiplierstack, new, i1 + 1];
        If[i2 < Length[multipliers[[2]]],
         
         multiplierstack = 
           Insert[multiplierstack, {multipliers[[1]], 
             multipliers[[2, i2 + 1 ;; -1]]}, i1 + 2];
         ];
        multiplierstack[[i1]] = done,
        (*use new multipliers later*)
        stackchange = False;
        For[{i3 = Length[multiplierstack]}, i3 >= i1, i3--,
         
         If[Or[multiplierstack[[i3, 1, 2]] === history[[1]], 
           new[[1, 2, -1]] > multiplierstack[[i3, 1, 2, -1]], 
           And[new[[1, 2, -1]] === multiplierstack[[i3, 1, 2, -1]], 
            LeafCount[new[[1, 2, 1]]] >= 
             LeafCount[multiplierstack[[i3, 1, 2, 1]]]]],
          multiplierstack = Insert[multiplierstack, new, i3 + 1];
          Break[];
          ]
         ];
        ];
       ]
      ];
     
     (*update history if needed*)
     If[updatehistory === True,
      For[{i3 = Length[history]}, i3 >= 1, i3--,
        If[history[[i3, -1]] > attempt[[2, -1]],
         history = Insert[history, attempt[[2]], i3 + 1];
         Break[];
         ]
        ];
      ];
     
     (*break inner loop if stack has changed*)
     If[stackchange === True,
      Break[];
      ];
     ];(*end of inner loop*)
    
    (*add additional multipliers after first pass (if no forced multip\
liers)*)
    If[And[i1 === 1, ! ListQ[forcedmultipliers]],
     Block[{best, worst, extra, f},
      best = Min[multiplierstack[[i1, 2, All, 2]]];
      worst = Max[multiplierstack[[i1, 2, All, 2]]];
      extra = 
       DeleteCases[
        DeleteDuplicates[
         Replace[(Distribute[
               f @@ (#^Range[0, 1] & /@ (Cases[
                    multiplierstack[[i1, 2]], {mult_, degree_} /; 
                    degree < worst][[All, 1]])), 
               List] //. {f[a___, Power[base_Times, exp_], b___] :> 
                f[a, b, Sequence @@ ((List @@ base)^exp)], 
               f[a___, prod_Times, b___] :> f[a, b, Sequence @@ prod],
                f[a___, Power[base_, exp_], b___] :> 
                f[a, b, (-1)^exp, (-base)^exp] /; 
                 And[base != -1, Re[base] < 0], 
               f[a___, Power[base_, Rational[num1_, denom_]], b___, 
                 Power[base_, Rational[num2_, denom_]], c___] :> 
                f[a, b, c, base^(Mod[num1 + num2, denom]/denom)]}) /. 
            f -> Times, Times[a___, _Integer, b___] :> a*b, {1}] //. 
          Power[base_, Rational[a_, b_]] :> base^(Mod[a, b]/b)], 
        Alternatives @@ multiplierstack[[i1, 2, All, 1]]];
      If[Length[extra] >= 1,
       Print["adding multipliers based on progress in initial guess"];
       multiplierstack = 
        Insert[multiplierstack, {multiplierstack[[i1, 1]], extra}, 
         i1 + 1];
       ];
      ]
     ];
    
    ](*end of outer loop*),
   "solution"
   ];(*end of Catch, used to break the loop when a solution is found*)
  
  Print["history: ", #[[{1, -1}]] & /@ history];
  If[solution =!= problem,
   Print[solution],
   Print["no progress"];
   ];
  Print[];
  Return[solution];
  ]
  
ClearAll[RationalizeDenominator];
RationalizeDenominator[expr_] :=
 Block[{conjugate, denom, x},
  denom = Denominator[expr];
  conjugate = MinimalPolynomial[denom];
  Expand[
    Numerator[expr]*PolynomialQuotient[conjugate[x], x - denom, x] /. 
     x -> 0]/(-1*conjugate[0])
  ]
  
ClearAll[AlgebraicQ];
AlgebraicQ[num_] := Element[num, Algebraics]

ClearAll[nestdepths]
nestdepths[expr_, func_] :=
 Block[{inner},
  If[Depth[expr] === 1,
   {expr, If[func[expr], 1, 0]},
   inner = Map[nestdepths[#, func] &, (List @@ expr), {1}];
   {expr, 
    Sequence @@ 
     inner, ((Max @@ ((#[[-1]]) & /@ inner)) + If[func[expr], 1, 0])}
   ]
  ]

ClearAll[nestdepthsort]
nestdepthsort[expr_, func_] :=
 Block[{data},
  data = nestdepths[expr, func];
  data = 
   data //. 
    patt : {a : Except[_List], b : __, c : Except[_List]} :> {{a, c}, 
      b};
  data = data //. patt : {rep : Repeated[{_, _}]} :> Sequence @@ patt;
  data = Gather[{data}, (#1[[2]] == #2[[2]]) &];
  data = Sort[data, (#1[[1, 2]] >= #2[[1, 2]]) &];
  data
  ]

ClearAll[maxnestdepth]
maxnestdepth[expr_, func_] :=
 Block[{data, max},
  data = nestdepths[{expr}, func][[2]];
  max = data[[-1]];
  data = 
   FixedPoint[
    DeleteCases[# /. {a_, b_} :> {} /; b < max, {}, Infinity] &, data];
  data = 
   If[And[ListQ[#], Length[#] > 2], Sequence @@ (#[[2 ;; -2]]), #] & /@
     data;
  If[Length[data] > 2,
   data = data[[2 ;; -2]],
   data = {data}
   ];
  data
  ]
  
ClearAll[ComplexitySort];
ComplexitySort[expr_] := 
  Return[Sort[expr, 
    Switch[LeafCount[#1] - LeafCount[#2], a_ /; a < 0, True, 
      a_ /; a > 0, False, 0, Abs[#1] <= Abs[#2]] &]];
	  
ClearAll[Factorc]
Factorc[expr_] :=
 Flatten[
   fullfactor[
     expr] //. {pow : {a : Except[_List], b : Except[_List]} :> {a^b},
      prod : {rep : (Repeated[{Except[_List]}, {2, 
            Infinity}])} :> {Times[rep]}, 
     sum : {rep : Repeated[{{Except[_List]}}, {2, Infinity}]} :> 
      Plus[rep], 
     pow2 : {{a : Except[_List]}, b : Except[_List]} :> {a^b}, 
     pow3 : {{{a : Except[_List]}}, b : Except[_List]} :> {a^b}}][[1]]

ClearAll[fullfactor]
fullfactor[expr_] :=
 Block[{factorlist, i = 0, j = 0, done = False},
  factorlist = FactorList[expr];
  While[! done && j < 5,
   j++;
   done = True;
   For[{i = 1}, i <= Length[factorlist], i++,
    Which[
     Head[factorlist[[i, 1]]] === Power,
     done = False;
     factorlist[[
       i]] = {{factorlist[[i, 1, 1]], 
        factorlist[[i, 1, 2]]*factorlist[[i, 2]]}},
     And[
      MemberQ[{Integer, Rational}, Head[factorlist[[i, 1]]]], ! 
       PrimeQ[factorlist[[i, 1]]], Abs[factorlist[[i, 1]]] =!= 1],
     done = False;
     factorlist[[i]] = {#[[1]], #[[2]]*factorlist[[i, 2]]} & /@ 
       FactorInteger[factorlist[[i, 1]]],
     Head[factorlist[[i, 1]]] === Plus,
     done = False;
     factorlist[[i]] = 
      combine[fullfactor /@ 
        Replace[factorlist[[i, 1]], Plus[a_, b__] :> {a, b}], 
       factorlist[[i, 2]]],
     True,
     factorlist[[i]] = {factorlist[[i]]}
     ]
    ];
   factorlist = Flatten[factorlist, 1]
   ];
  factorlist
  ]

ClearAll[combine];
combine[terms_List, pow_] :=
 Block[{simpler = terms, base, bases, positions, factor, i, j, k},
  For[{i = 1}, i <= Length[terms], i++,
   base = terms[[i]];
   For[{j = 1}, j < Length[base], j++,
    For[{k = j + 1}, k <= Length[base], k++,
     If[base[[j, 1]] === base[[k, 1]],
      base[[j]] = {base[[j, 1]], base[[j, 2]] + base[[k, 2]]};
      base[[k]] = {0, 0}
      ]
     ];
    If[base[[j, 1]] === 1,
     base[[j]] = {0, 0}
     ]
    ];
   simpler[[i]] = Delete[base, Position[base, {0, 0}]];
   ];
  bases = Intersection @@ Map[#[[1]] &, simpler, {2}];
  For[{i = 1}, i <= Length[bases], i++,
   positions = 
    Position[#, {bases[[i]], Except[_List]}, 1] & /@ simpler;
   factor = 
    Min[Extract[simpler[[#]], positions[[#]]][[1, 2]] & /@ 
      Range[1, Length[simpler], 1]];
   For[{j = 1}, j <= Length[simpler], j++,
    simpler[[j, Sequence @@ (positions[[j, 1]]), 2]] -= factor
    ];
   bases[[i]] = {bases[[i]], factor*pow};
   ];
  Append[bases, {simpler, pow}]
  ]
  
