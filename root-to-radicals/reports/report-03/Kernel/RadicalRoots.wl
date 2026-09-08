(* ::Package:: *)
(* RadicalRoots 0.1.0 -- exact reference implementation.
   See docs/article.pdf and README.md for guarantees and testing status.
   No notebook definitions, private Simplify` symbols, or numeric zero tests.
*)
BeginPackage["RadicalRoots`"];
RadicalRoot::usage = "RadicalRoot[a, options] returns a certified radical expression for an exact algebraic number, or a Failure object.";
RadicalRootReport::usage = "RadicalRootReport[a, options] returns an Association with Status, Expression, Method, Verified and Details. Method may be Automatic, \"Fast\", or \"Galois\".";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] accepts only exact rational/complex-rational constants, arithmetic, and rational powers. Root, AlgebraicNumber and transcendental heads are rejected.";
RadicalEqualQ::usage = "RadicalEqualQ[a,b] returns True only when RootReduce[a-b] is exactly zero.";
Begin["`Private`"];

ratQ[e_] := MatchQ[e, _Integer | _Rational];
RadicalExpressionQ[e_] := Which[
  ratQ[e], True,
  Head[e] === Complex, ratQ[Re[e]] && ratQ[Im[e]],
  MemberQ[{Plus, Times}, Head[e]], AllTrue[List @@ e, RadicalExpressionQ],
  Head[e] === Power, ratQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];
rr[e_] := RootReduce[e];
RadicalEqualQ[a_, b_] := TrueQ[Quiet[Check[RootReduce[a-b], $Failed]] === 0];
eq[a_, b_] := RadicalEqualQ[a,b];
zeta[n_Integer] /; n > 0 := (-1)^(2/n);

failure[status_, text_, data_:<||>] := Throw[
  <|"Status"->status,"Expression"->Missing["NotAvailable"],
    "Method"->"None","Verified"->False,
    "Details"->Join[<|"Reason"->text|>,data]|>, $failureTag];
success[e_, method_, data_:<||>] := <|"Status"->"Success",
  "Expression"->e,"Method"->method,"Verified"->True,"Details"->data|>;
SetAttributes[checked, HoldFirst];
checked[e_] := Module[{r = Quiet[Check[e,$Failed]]},
  If[r === $Failed || r === $Aborted,
    failure["BackendError","An exact algebraic backend operation failed."]]; r];

polyRoots[p_, x_] := With[{f = Function[Evaluate[p /. x -> Slot[1]]]},
  Table[rr[Root[f,j]],{j,Exponent[p,x]}]];
dickson[n_Integer, x_, a_] := Module[{u=2,v=x,t},
  If[n===0,Return[u]];
  Do[t=Expand[x v-a u];u=v;v=t,{n-1}]; v];

rationalNthRoots[c_, n_Integer] := Module[{u,v,r},
  If[!ratQ[c] || c===0 || (c<0 && EvenQ[n]),Return[{}]];
  u=Abs[Numerator[c]]^(1/n);v=Denominator[c]^(1/n);
  If[!IntegerQ[u] || !IntegerQ[v],Return[{}]];
  r=Sign[c] u/v;If[EvenQ[n],{r,-r},{r}]];

lowCandidates[p_, x_] := Module[{n=Exponent[p,x],a,b,c,pp,qq,t,u,d,sol},
  Switch[n,
    1, {-Coefficient[p,x,0]},
    2, b=Coefficient[p,x,1];c=Coefficient[p,x,0];
       Table[(-b+e Sqrt[b^2-4 c])/2,{e,{1,-1}}],
    3, a=Coefficient[p,x,2];b=Coefficient[p,x,1];c=Coefficient[p,x,0];
       pp=Expand[b-a^2/3];qq=Expand[2 a^3/27-a b/3+c];
       If[eq[pp,0] && eq[qq,0],Return[ConstantArray[-a/3,3]]];
       d=Expand[qq^2/4+pp^3/27];t=-qq/2+Sqrt[d];
       If[eq[t,0],t=-qq/2-Sqrt[d]];
       u=t^(1/3);
       Table[zeta[3]^k u-pp/(3 zeta[3]^k u)-a/3,{k,0,2}],
    4, sol=Quiet[Check[x/.Solve[p==0,x,Cubics->True,Quartics->True],$Failed]];
       If[ListQ[sol] && Length[sol]===4 && AllTrue[sol,RadicalExpressionQ],sol,$Failed],
    _, $Failed]];

fastCandidates[pin_, x_, depth_, maxDepth_] := Module[
  {p,n,low,shift,q,res,support,g,a,d,c,t,u,m,ds,cs,cands,new,sub},
  If[depth>maxDepth,failure["ResourceLimit","Fast recursion-depth limit reached."]];
  n=Exponent[pin,x];p=Expand[pin/Coefficient[pin,x,n]];
  low=lowCandidates[p,x];
  If[ListQ[low],Return[<|"Candidates"->low,"Method"->"Degree<=4"|>]];
  shift=-Coefficient[p,x,n-1]/n;
  If[!eq[shift,0],
    res=fastCandidates[Expand[p/.x->x+shift],x,depth+1,maxDepth];
    If[AssociationQ[res],Return[<|"Candidates"->(# + shift & /@ res["Candidates"]),
      "Method"->"Shift/"<>res["Method"]|>]];Return[$Failed]];
  cs=CoefficientList[p,x];
  support=Select[Range[n],cs[[#+1]]=!=0&];g=Apply[GCD,support];
  If[g>1,
    q=Total[(cs[[#+1]] x^(#/g)&)/@Prepend[support,0]];
    res=fastCandidates[q,x,depth+1,maxDepth];
    If[AssociationQ[res],Return[<|"Candidates"->Flatten[
      Table[zeta[g]^k r^(1/g),{r,res["Candidates"]},{k,0,g-1}]],
      "Method"->"Power/"<>res["Method"]|>]]];
  a=-Coefficient[p,x,n-2]/n;d=Expand[p-dickson[n,x,a]];
  If[Exponent[d,x]<=0 && !eq[a,0],
    c=d;t=(-c+Sqrt[c^2-4 a^n])/2;
    If[eq[t,0],t=(-c-Sqrt[c^2-4 a^n])/2];u=t^(1/n);
    Return[<|"Candidates"->Table[zeta[n]^k u+a/(zeta[n]^k u),{k,0,n-1}],
      "Method"->"Dickson"|>]];
  If[EvenQ[n] && cs[[1]]=!=0,
    m=n/2;
    Do[If[And@@Table[eq[cs[[m-j+1]],a^j cs[[m+j+1]]],{j,1,m}],
      q=cs[[m+1]]+Sum[cs[[m+j+1]] dickson[j,x,a],{j,1,m}];
      res=fastCandidates[Expand[q],x,depth+1,maxDepth];
      If[AssociationQ[res],Return[<|"Candidates"->Flatten[
        Table[(r+e Sqrt[r^2-4 a])/2,{r,res["Candidates"]},{e,{1,-1}}]],
        "Method"->"Reciprocal/"<>res["Method"]|>]]],
      {a,rationalNthRoots[cs[[1]],m]}]];
  If[AllTrue[cs,ratQ],
    ds=Quiet[Check[Decompose[p,x],{p}]];
    If[ListQ[ds] && Length[ds]>1,
      res=fastCandidates[First[ds],x,depth+1,maxDepth];
      If[AssociationQ[res],cands=res["Candidates"];
        Do[new={};Do[sub=fastCandidates[Expand[inner-r],x,depth+1,maxDepth];
          If[!AssociationQ[sub],Return[$Failed]];new=Join[new,sub["Candidates"]],
          {r,cands}];cands=new,{inner,Rest[ds]}];
        Return[<|"Candidates"->cands,"Method"->"Composition/"<>res["Method"]|>]]]];
  $Failed];

pick[candidates_, target_] := Module[{cs=Select[candidates,RadicalExpressionQ],ordered},
  ordered=Quiet[Check[SortBy[cs,N[Abs[#-target],40]&],cs]];
  (* Approximation changes ONLY the order of exact tests. *)
  Do[If[eq[e,target],Return[e]],{e,ordered}];$Failed];

primitive[values_] := Module[{common,an},
  common=checked[ToNumberField[values,All]];
  an=Cases[common,_AlgebraicNumber,{1}];
  If[an==={},failure["BackendError","No primitive element was returned."]];
  rr[an[[1,1]]]];

primeChain[mul_, id_, initial_] := Module[
  {inv,closure,H=Sort[initial],chain={},comm,childGroup,candidate,p,sigma,pow},
  inv=Table[First[Select[Range[Length[mul]],mul[[a,#]]===id&]],
            {a,Length[mul]}];
  closure[gens_] := Module[{known={id},todo={id},a,c},
    While[todo=!={},a=First[todo];todo=Rest[todo];
      Do[c=mul[[a,b]];If[!MemberQ[known,c],AppendTo[known,c];AppendTo[todo,c]],
         {b,gens}]];Sort[known]];
  While[Length[H]>1,
    comm=DeleteDuplicates[Flatten[Table[
      mul[[mul[[mul[[a,b]],inv[[a]]]],inv[[b]]]],{a,H},{b,H}]]];
    childGroup=closure[comm];
    If[childGroup===H,failure["NotSolvable","A nontrivial perfect subgroup was found.",
      <|"PerfectSubgroupOrder"->Length[H]|>]];
    Do[If[!MemberQ[childGroup,a],candidate=closure[Union[childGroup,{a}]];
      If[Length[candidate]<Length[H],childGroup=candidate]],{a,H}];
    p=Length[H]/Length[childGroup];
    If[!PrimeQ[p],failure["BackendError","Invalid prime-index subgroup step."]];
    sigma=First[Complement[H,childGroup]];
    If[!And@@Flatten[Table[MemberQ[childGroup,mul[[mul[[h,a]],inv[[h]]]]],{h,H},{a,childGroup}]],
      failure["BackendError","Normality check failed."]];
    pow=Nest[mul[[#,sigma]]&,id,p];
    If[!MemberQ[childGroup,pow],failure["BackendError","Quotient generator check failed."]];
    AppendTo[chain,<|"Parent"->H,"Child"->childGroup,"Generator"->sigma,"Prime"->p|>];
    H=childGroup];chain];

(* Every automorphism acts on actual algebraic numbers in one embedded field.
   There is no assumed correspondence between abstract and numerical root labels. *)
galoisConvert[target_, p_, x_, maxField_, maxNodes_] := Module[
  {roots,thetaL,d,m,unity,theta,dim,fp,images,coeff,act,index,id,mul,gamma,
   chain,nodes=0,phases={},base,encode,fixed,zexpr,out,an},
  roots=polyRoots[p,x];
  If[Length[roots]>maxField,
    failure["ResourceLimit","Polynomial degree exceeds the field-degree cap."]];
  thetaL=primitive[roots];d=Exponent[checked[MinimalPolynomial[thetaL,x]],x];
  If[d>maxField,failure["ResourceLimit","Splitting field exceeds the degree cap.",
    <|"SplittingFieldDegree"->d|>]];
  m=Times@@(First/@FactorInteger[d]);zexpr=zeta[m];unity=rr[zexpr];
  theta=primitive[Join[roots,{unity}]];
  fp=checked[MinimalPolynomial[theta,x]];dim=Exponent[fp,x];
  If[dim>maxField,failure["ResourceLimit","Cyclotomic compositum exceeds the degree cap.",
    <|"FieldDegree"->dim|>]];
  images=polyRoots[fp,x];
  coeff[a_] := coeff[a] = Module[{b},
    If[ratQ[a],Return[{a}]];
    b=checked[ToNumberField[a,theta]];
    If[Head[b]=!=AlgebraicNumber || !eq[b[[1]],theta],
      failure["BackendError","An element was not represented in the primitive field."]];
    b[[2]]];
  act[a_,i_Integer] := act[a,i] = With[{c=coeff[a]},
    rr[c.Table[images[[i]]^j,{j,0,Length[c]-1}]]];
  index[a_] := Module[{pos=FirstPosition[images,rr[a],Missing["NotFound"]]},
    If[MissingQ[pos],failure["BackendError","Automorphism images did not close."]];First[pos]];
  id=index[theta];
  mul=Table[index[act[images[[j]],i]],{i,dim},{j,dim}];
  gamma=Select[Range[dim],eq[act[unity,#],unity]&];
  If[Length[gamma] EulerPhi[m]=!=dim,
    failure["BackendError","Cyclotomic fixed-field dimension check failed."]];
  chain=primeChain[mul,id,gamma];
  fixed[a_,group_] := AllTrue[group,eq[act[a,#],a]&];
  base[a_] := Module[{b,c},
    If[ratQ[a],Return[a]];
    b=checked[ToNumberField[a,unity]];
    If[Head[b]=!=AlgebraicNumber || !eq[b[[1]],unity],
      failure["BackendError","Bottom invariant is outside the cyclotomic field."]];
    c=b[[2]];c.Table[zexpr^j,{j,0,Length[c]-1}]];
  encode[a_,0] := encode[a,0] = (nodes++;
    If[nodes>maxNodes,failure["ResourceLimit","Fourier node budget exhausted."]];base[a]);
  encode[a_,level_Integer] := encode[a,level] = Module[
    {step,H,childGroup,sigma,q,orbit,zp,parts={},R,b,be,principal,k,found},
    nodes++;If[nodes>maxNodes,failure["ResourceLimit","Fourier node budget exhausted."]];
    If[eq[a,0],Return[0]];
    step=chain[[level]];H=step["Parent"];childGroup=step["Child"];
    sigma=step["Generator"];q=step["Prime"];
    If[!fixed[a,childGroup],failure["BackendError","Fourier input fixed-field invariant failed."]];
    If[eq[act[a,sigma],a],Return[encode[a,level-1]]];
    orbit=NestList[act[#,sigma]&,a,q-1];zp=rr[unity^(m/q)];
    Do[R=rr[Sum[zp^(-j k) orbit[[k+1]],{k,0,q-1}]];
      If[j===0,
        If[!fixed[R,H],failure["BackendError","Trace invariant check failed."]];
        AppendTo[parts,encode[R,level-1]],
        If[eq[R,0],AppendTo[parts,0],
          b=rr[R^q];
          If[!fixed[b,H],failure["BackendError","Resolvent-power invariant failed."]];
          be=encode[b,level-1];principal=rr[b^(1/q)];found=False;
          Do[If[eq[zp^k principal,R],
            AppendTo[parts,zeta[q]^k be^(1/q)];
            AppendTo[phases,<|"Level"->level,"Frequency"->j,"Prime"->q,"Phase"->k|>];
            found=True;Break[]],{k,0,q-1}];
          If[!found,failure["BackendError","No exact principal-root phase matched."]]]],
      {j,0,q-1}];Total[parts]/q];
  out=encode[target,Length[chain]];
  If[!RadicalExpressionQ[out] || !eq[out,target],
    failure["BackendError","Final exact selected-root verification failed."]];
  success[out,"GaloisFourier",<|"SplittingFieldDegree"->d,"FieldDegree"->dim,
    "CyclotomicConductor"->m,"RelativeGroupOrder"->Length[gamma],
    "QuotientPrimes"->Lookup[chain,"Prime",{}],"ExpressionNodes"->nodes,
    "PhaseChoices"->phases|>]];

Options[RadicalRootReport]={"Method"->Automatic,"TimeConstraint"->120,
  "MaxFieldDegree"->64,"MaxNodes"->10000,"MaxDepth"->30,"ExtensionHints"->{}};
RadicalRootReport[input_,OptionsPattern[]] := Module[
  {method=OptionValue["Method"],time=OptionValue["TimeConstraint"],
   maxField=OptionValue["MaxFieldDegree"],maxNodes=OptionValue["MaxNodes"],
   maxDepth=OptionValue["MaxDepth"],hints=OptionValue["ExtensionHints"],run},
  run[] := Block[{$failureTag=Unique["RadicalFailure"],$MaxExtraPrecision=1000},
    Catch[Module[{r,p,x,fast,e,fl,subs},
      If[!MemberQ[{Automatic,"Fast","Galois"},method],
        failure["InvalidInput","Method must be Automatic, Fast, or Galois."]];
      If[!And@@((#===Infinity || (IntegerQ[#] && #>0))& /@ {maxField,maxNodes,maxDepth}),
        failure["InvalidInput","Resource limits must be positive integers or Infinity."]];
      If[!FreeQ[input,_Real],failure["InvalidInput","Inexact input is not accepted."]];
      If[!ListQ[hints] || !AllTrue[hints,RadicalExpressionQ],
        failure["InvalidInput","Extension hints must be radical expressions."]];
      r=checked[RootReduce[input]];
      p=checked[MinimalPolynomial[r,x]];
      If[!PolynomialQ[p,x] || Exponent[p,x]<1 || !AllTrue[CoefficientList[p,x],ratQ],
        failure["InvalidInput","An exact algebraic number over the rationals is required."]];
      If[RadicalExpressionQ[r],Return[success[r,"AlreadyRadical"]]];
      If[method=!= "Galois",
        e=Quiet[Check[ToRadicals[r],$Failed]];
        If[RadicalExpressionQ[e] && eq[e,r],Return[success[e,"ToRadicals"]]];
        fast=fastCandidates[p,x,0,maxDepth];
        If[AssociationQ[fast],e=pick[fast["Candidates"],r];
          If[e=!=$Failed,Return[success[e,fast["Method"]]]]];
        If[hints=!={},
          fl=Quiet[Check[FactorList[p,Extension->hints],{}]];
          subs=Select[First/@fl,PolynomialQ[#,x] && 0<Exponent[#,x]<Exponent[p,x]&];
          Do[If[eq[q/.x->r,0],fast=fastCandidates[q,x,0,maxDepth];
            If[AssociationQ[fast],e=pick[fast["Candidates"],r];
              If[e=!=$Failed,Return[success[e,"ExtensionHint/"<>fast["Method"]]]]]],{q,subs}]];
        If[method==="Fast",Return[<|"Status"->"Unknown","Expression"->Missing["NotAvailable"],
          "Method"->"Fast","Verified"->False,
          "Details"-><|"Reason"->"No certified structural match."|>|>]]];
      galoisConvert[r,p,x,maxField,maxNodes]
    ],$failureTag]];
  If[time===Infinity,run[],
    If[!NumericQ[time] || !TrueQ[time>0],
      <|"Status"->"InvalidInput","Expression"->Missing["NotAvailable"],
        "Method"->"None","Verified"->False,
        "Details"-><|"Reason"->"TimeConstraint must be positive or Infinity."|>|>,
      TimeConstrained[run[],time,<|"Status"->"ResourceLimit",
        "Expression"->Missing["NotAvailable"],"Method"->ToString[method],"Verified"->False,
        "Details"-><|"Reason"->"Wall-clock time limit reached."|>|>]]]];
Options[RadicalRoot]=Options[RadicalRootReport];
RadicalRoot[a_,opts:OptionsPattern[]] := Module[{r=RadicalRootReport[a,opts]},
  If[Lookup[r,"Status"]==="Success",r["Expression"],
    Failure[Lookup[r,"Status","BackendError"],KeyDrop[r,"Expression"]]]];

End[];
EndPackage[];
