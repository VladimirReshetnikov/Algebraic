(* ::Package:: *)
(* SystematicRadicals 0.1.0 -- exact radical reconstruction over Q.
   Reference implementation. See validation/STATUS.md for execution status.
   No private Mathematica symbols, numerical equality tests, or PowerExpand.
*)
BeginPackage["SystematicRadicals`"];
RadicalSolve::usage = "RadicalSolve[a,opts] returns an Association with Status, Expression (on success), Method, and Certificate. Input must be an exact algebraic number over Q.";
SystematicToRadicals::usage = "SystematicToRadicals[a,opts] returns a certified radical expression or Failure. It does not replace System`ToRadicals.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] tests the strict grammar of rational constants, I, arithmetic and rational powers.";
RadicalVerify::usage = "RadicalVerify[a,e] checks the radical grammar and exact equality RootReduce[e-a]===0.";
RadicalTowerVerify::usage = "RadicalTowerVerify[result] independently checks a positive Kummer tower's polynomial identities and exact branch selections.";
PairSumResolvent::usage = "PairSumResolvent[p,x,t] returns the exact pair-sum resolvent Product[t-ri-rj,i<j] for square-free rational p.";
Options[RadicalSolve] = {Method -> "Automatic", TimeConstraint -> 60,
  "MaxFieldDegree" -> 128, "MaxDepth" -> 12, "PairResolvent" -> True};
Options[SystematicToRadicals] = Options[RadicalSolve];
Begin["`Private`"];

rationalQ[a_] := IntegerQ[a] || Head[a] === Rational;
zeroQ[a_] := TrueQ[Quiet[Check[RootReduce[a] === 0, False]]];
RadicalExpressionQ[a_?rationalQ] := True;
RadicalExpressionQ[a_Complex] := rationalQ[Re[a]] && rationalQ[Im[a]];
RadicalExpressionQ[a_Plus] := AllTrue[List @@ a, RadicalExpressionQ];
RadicalExpressionQ[a_Times] := AllTrue[List @@ a, RadicalExpressionQ];
RadicalExpressionQ[Power[a_,b_?rationalQ]] := RadicalExpressionQ[a];
RadicalExpressionQ[_] := False;
RadicalVerify[a_,e_] := RadicalExpressionQ[e] && zeroQ[e-a];
zeta[n_Integer] /; n >= 1 := If[n == 1, 1, (-1)^(2/n)];
fail[status_, message_] := Throw[<|"Status" -> status,
  "Diagnostics" -> {message}|>, srFailureTag];
require[q_, message_] := If[!TrueQ[q], fail["Inconclusive", message]];
polyRoots[p_,x_] := With[{fn = Function[Evaluate[p /. x -> Slot[1]]],
  n = Exponent[p,x]}, Table[Root[fn,k], {k,n}]];
monic[p_,x_] := Expand[p/Coefficient[p,x,Exponent[p,x]]];
smallRoots[p_,x_] := Module[{r},
  r = Quiet[Check[x /. Solve[p == 0,x,Cubics -> True,Quartics -> True],{}]];
  Select[ToRadicals[r],RadicalExpressionQ]];
dickson[0,x_,a_] := 2;
dickson[n_Integer,x_,a_] /; n >= 1 := Module[{u=2,v=x,w,k},
  Do[w=Expand[x v-a u];u=v;v=w,{k,2,n}];v];
rationalNthRoots[c_,n_] := Module[{u},
  u = If[c < 0 && OddQ[n], -(-c)^(1/n), c^(1/n)];
  If[rationalQ[u],DeleteDuplicates[If[EvenQ[n],{u,-u},{u}]],{}]];

structural[p0_,x_,depth_,maxDepth_] := Module[
 {p=monic[p0,x],n,h,q,es,g,y,lower,rs,a,m,ident,dn,c,tt,u,dec,inner,outer,out,fac,k},
 If[depth > maxDepth, Return[{{},"DepthLimit"}]];
 n=Exponent[p,x];
 If[n <= 4, Return[{smallRoots[p,x],"DegreeAtMostFour"}]];
 fac=Rest[FactorList[p]];
 If[Length[fac]>1 || (Length[fac]==1 && fac[[1,2]]>1),
   out=Flatten[structural[#[[1]],x,depth+1,maxDepth][[1]]& /@ fac];
   Return[{out,"RationalFactorization"}]];
 h=-Coefficient[p,x,n-1]/n;q=Expand[p /. x -> x+h];
 es=Select[Range[n],Coefficient[q,x,#] =!= 0&];g=Apply[GCD,es];
 y=Unique["y"];
 If[g>1,
   lower=Sum[Coefficient[q,x,j g] y^j,{j,0,n/g}];
   rs=structural[lower,y,depth+1,maxDepth][[1]];
   If[rs=!={},Return[{Flatten[Table[h+zeta[g]^k b^(1/g),{b,rs},{k,0,g-1}]],"ShiftedPower"}]]];
 If[EvenQ[n] && Coefficient[q,x,0]=!=0,
   m=n/2;
   Do[
     If[a===0,Continue[]];
     lower=Coefficient[q,x,m]+Sum[Coefficient[q,x,m+k] dickson[k,y,a],{k,1,m}];
     ident=Together[x^m (lower /. y -> x+a/x)-q];
     If[ident===0,
       rs=structural[lower,y,depth+1,maxDepth][[1]];
       If[rs=!={},Return[{Flatten[Table[h+(b+sgn Sqrt[b^2-4a])/2,
         {b,rs},{sgn,{1,-1}}]],"Reciprocal"}]]],
     {a,rationalNthRoots[Coefficient[q,x,0],m]}]];
 a=-Coefficient[q,x,n-2]/n;dn=dickson[n,x,a];
 c=Coefficient[q-dn,x,0];
 If[Expand[q-dn-c]===0,
   Do[If[tt===0,Continue[]];u=tt^(1/n);
     Return[{Table[h+zeta[n]^k u+a/(zeta[n]^k u),{k,0,n-1}],"Dickson"}],
     {tt,{(-c+Sqrt[c^2-4a^n])/2,(-c-Sqrt[c^2-4a^n])/2}}]];
 dec=Quiet[Check[Decompose[p,x],{p}]];
 If[ListQ[dec] && Length[dec]>1,
   inner=Last[dec];
   If[Exponent[inner,x]<=4,
     outer=First[dec];Do[outer=Expand[outer /. x -> dec[[k]]],{k,2,Length[dec]-1}];
     rs=structural[outer,x,depth+1,maxDepth][[1]];
     out=Flatten[smallRoots[inner-#,x]& /@ rs];
     If[out=!={},Return[{out,"Composition"}]]]];
 {{},"NoStructuralMatch"}];

PairSumResolvent[p0_,x_,t_] := Module[{p=monic[p0,x],n,res,diag,q,fac},
 n=Exponent[p,x];
 If[!PolynomialQ[p,x] || !VectorQ[CoefficientList[p,x],rationalQ] ||
    Exponent[PolynomialGCD[p,D[p,x]],x]>0,Return[$Failed]];
 res=Resultant[p,p /. x -> t-x,x];diag=2^n (p /. x -> t/2);
 q=monic[Cancel[res/diag],t];fac=Rest[FactorList[q]];
 If[!AllTrue[fac,EvenQ[#[[2]]]&],Return[$Failed]];
 monic[Times @@ (#[[1]]^(#[[2]]/2)& /@ fac),t]];

inGenerator[c_,theta_,t_] := Module[{a=ToNumberField[c,theta]},
 Which[rationalQ[a],a,
   Head[a]===AlgebraicNumber && (a[[1]]===theta || zeroQ[a[[1]]-theta]),
     AlgebraicNumberPolynomial[a,t],
   True,fail["Inconclusive","Exact field membership conversion failed."]]];

pairCandidates[p_,x_] := Module[{t=Unique["t"],r,fac,out={},b,br,mp,scale,theta,tr,fl,f,cf,expr},
 r=PairSumResolvent[p,x,t];If[r===$Failed,Return[{}]];
 fac=Select[Rest[FactorList[r]],1<Exponent[#[[1]],t]<=4&];
 Do[Do[
   br=ToRadicals[b];If[!RadicalExpressionQ[br],Continue[]];
   mp=MinimalPolynomial[b,t];scale=Coefficient[mp,t,Exponent[mp,t]];
   theta=RootReduce[scale b];tr=scale br;
   fl=Rest[FactorList[p,Extension -> theta]];
   Do[f=entry[[1]];
     If[1<=Exponent[f,x]<=4,
       cf=CoefficientList[f,x];
       cf=(inGenerator[#,theta,t] /. t -> tr)& /@ cf;
       expr=Sum[cf[[j+1]] x^j,{j,0,Length[cf]-1}];
       out=Join[out,smallRoots[expr,x]]],{entry,fl}],
   {b,polyRoots[factor[[1]],t]}],{factor,fac}];DeleteDuplicates[out]];

closure[gens_,tab_,id_] := Module[{seen={id},todo={id},a,b,c,gs=DeleteDuplicates[gens]},
 While[todo=!={},a=First[todo];todo=Rest[todo];
   Do[c=tab[[a,b]];If[!MemberQ[seen,c],AppendTo[seen,c];AppendTo[todo,c]],{b,gs}]];
 Sort[seen]];
derived[h_,tab_,inv_,id_] := closure[
 Flatten[Table[tab[[tab[[tab[[a,b]],inv[[a]]]],inv[[b]]]],{a,h},{b,h}]],tab,id];
primeStep[h_,tab_,inv_,id_] := Module[{k=derived[h,tab,inv,id],u,g,p},
 require[k=!=h,"A nontrivial perfect subgroup was encountered."];
 Do[u=closure[Append[k,g],tab,id];If[Length[u]<Length[h],k=u],{g,h}];
 p=Length[h]/Length[k];require[PrimeQ[p],"Prime-index subgroup construction failed."];
 {k,First[Complement[h,k]],p}];

primitiveGenerator[values_] := Module[{v=ToNumberField[values,All],gs},
 gs=Cases[v,AlgebraicNumber[g_,_]:>g,{1}];
 If[gs==={},If[AllTrue[values,rationalQ],1,
   fail["Inconclusive","Primitive-element construction did not return an algebraic-number representation."]],First[gs]]];

kummer[target_,f_,x_,maxDegree_] := Module[
 {rr,thetaL,dL,m,zv,theta,t=Unique["t"],mp,d,rem,pow,vec,coords,asPoly,
  zp,ap,fac,allImages,images,id,tab,inv,h,ds,next,base,syntax,zs=Unique["z"],
  chain,steps={},sub,sigma,p,sp,j,k,tr,r,eigen,power,cs,radicand,algp,algr,
  branches,branch,rsym,formula,rules,expr,certificate,order},
 rr=polyRoots[f,x];thetaL=primitiveGenerator[rr];
 dL=Exponent[MinimalPolynomial[thetaL,t],t];
 If[maxDegree=!=Infinity && dL>maxDegree,
   fail["Inconclusive","Splitting-field degree exceeds MaxFieldDegree."]];
 m=If[dL==1,1,Times @@ (First /@ FactorInteger[dL])];
 zv=zeta[m];theta=primitiveGenerator[{thetaL,zv}];
 mp=monic[MinimalPolynomial[theta,t],t];d=Exponent[mp,t];
 If[maxDegree=!=Infinity && d>maxDegree,
   fail["Inconclusive","Cyclotomic-compositum degree exceeds MaxFieldDegree."]];
 rem[a_]:=PolynomialRemainder[Expand[a],mp,t];
 pow[a_,n_Integer]:=Module[{b=rem[a],q=n,res=1},
   require[q>=0,"Negative modular power in internal arithmetic."];
   While[q>0,If[OddQ[q],res=rem[res b]];b=rem[b b];q=Quotient[q,2]];res];
 vec[a_]:=PadRight[CoefficientList[rem[a],t],d];
 coords[a_,basis_]:=Module[{mat=Transpose[vec /@ basis],v=vec[a],cc},
   cc=Quiet[Check[LinearSolve[mat,v],$Failed]];
   require[ListQ[cc] && Length[cc]==Length[basis] && mat.cc===v,
     "Exact subfield coordinates could not be certified."];cc];
 asPoly[a_]:=rem[inGenerator[a,theta,t]];
 zp=asPoly[zv];ap=asPoly[target];
 fac=Rest[FactorList[mp,Extension -> theta]];
 require[Length[fac]==d && AllTrue[fac,Exponent[#[[1]],t]==1 && #[[2]]==1&],
   "The claimed normal field did not split its primitive polynomial."];
 allImages=(asPoly[-Coefficient[#[[1]],t,0]/Coefficient[#[[1]],t,1]])& /@ fac;
 images=Select[allImages,rem[zp /. t -> #]===zp&];
 require[Length[images] EulerPhi[m]==d,"Incorrect cyclotomic stabilizer size."];
 id=FirstPosition[images,t,Missing["NotFound"],{1}];
 require[!MissingQ[id],"Identity automorphism missing."];id=First[id];
 tab=Table[FirstPosition[images,rem[images[[b]] /. t -> images[[a]]],
   Missing["NotFound"],{1}],{a,Length[images]},{b,Length[images]}];
 require[FreeQ[tab,_Missing],"Automorphisms are not closed under composition."];
 tab=Map[First,tab,{2}];
 inv=Table[SelectFirst[Range[Length[images]],tab[[a,#]]==id && tab[[#,a]]==id&,
   Missing["NotFound"]],{a,Length[images]}];
 require[FreeQ[inv,_Missing],"Automorphism inverse missing."];
 h=Range[Length[images]];ds={h};
 While[Length[Last[ds]]>1,next=derived[Last[ds],tab,inv,id];AppendTo[ds,next];
   If[next===ds[[-2]],Break[]]];
 certificate=<|"PrimitiveElement"->theta,"PolynomialVariable"->t,"Modulus"->mp,
   "SplittingDegree"->dL,"FieldDegree"->d,"CyclotomicOrder"->m,
   "CyclotomicPolynomial"->zp,"TargetPolynomial"->ap,
   "Automorphisms"->images,"DerivedOrders"->(Length /@ ds)|>;
 If[Length[Last[ds]]>1,Return[<|"Status"->"NotSolvable","Method"->"GaloisKummer",
   "Target"->target,"Certificate"->certificate,
   "Diagnostics"->{"Exact derived series stabilizes at a nontrivial subgroup."}|>]];
 base=Table[pow[zp,j],{j,0,EulerPhi[m]-1}];syntax=Table[zs^j,{j,0,Length[base]-1}];
 chain={h};
 While[Length[h]>1,
   {sub,sigma,p}=primeStep[h,tab,inv,id];sp={id};
   Do[AppendTo[sp,tab[[sigma,Last[sp]]]],{j,1,p-1}];eigen=0;
   Do[
     tr=rem[Total[(pow[images[[#]],k])& /@ sub]];r=0;
     Do[r=rem[r+pow[zp,Mod[-j m/p,m]] rem[tr /. t -> images[[sp[[j+1]]]]]],{j,0,p-1}];
     If[r=!=0,eigen=r;Break[]],{k,0,d-1}];
   require[eigen=!=0,"All Kummer eigenprojections vanished."];
   require[rem[eigen /. t -> images[[sigma]]]===rem[pow[zp,m/p] eigen],
     "Kummer eigenvalue identity failed."];
   require[AllTrue[sub,rem[eigen /. t -> images[[#]]]===eigen&],
     "Kummer generator is not subgroup-fixed."];
   power=pow[eigen,p];cs=coords[power,base];radicand=cs.syntax;
   algp=RootReduce[power /. t -> theta];algr=RootReduce[eigen /. t -> theta];
   branches=Range[0,p-1];
   order=Quiet[Check[SortBy[branches,Abs[N[zv^(m/p #) algp^(1/p)-algr,30]]&],branches]];
   branch=SelectFirst[order,zeroQ[zv^(m/p #) algp^(1/p)-algr]&,$Failed];
   require[branch=!=$Failed,"Principal-root branch could not be certified."];
   rsym=Unique["r"];
   AppendTo[steps,<|"Symbol"->rsym,"Prime"->p,"Radicand"->radicand,
     "Branch"->branch,"GeneratorPolynomial"->eigen,"PowerPolynomial"->power|>];
   base=Flatten[Table[(rem[# pow[eigen,j]])& /@ base,{j,0,p-1}]];
   syntax=Flatten[Table[(# rsym^j)& /@ syntax,{j,0,p-1}]];
   h=sub;AppendTo[chain,h]];
 require[Length[base]==d,"Terminal tower does not span the normal field."];
 formula=coords[ap,base].syntax;rules={zs->zv};
 Do[AppendTo[rules,st["Symbol"]->zv^(m/st["Prime"] st["Branch"])
   (st["Radicand"] /. rules)^(1/st["Prime"])],{st,steps}];
 expr=formula /. rules;require[RadicalExpressionQ[expr],"Output is not a strict radical expression."];
 certificate=Join[certificate,<|"ZSymbol"->zs,"Steps"->steps,"SubgroupChain"->chain,
   "Formula"->formula,"Expression"->expr,
   "Verification"->"Exact quotient identities and exact embedded branch equality"|>];
 <|"Status"->"Success","Method"->"GaloisKummer","Target"->target,
   "Expression"->expr,"Certificate"->certificate|>];

RadicalTowerVerify[result_Association] := Quiet[Check[Module[
 {c,t,theta,mp,m,zv,polys,rules,rem,st,p,j,a,r,br,formula},
 If[Lookup[result,"Status",""]=!="Success" || Lookup[result,"Method",""]=!="GaloisKummer",Return[False]];
 c=result["Certificate"];t=c["PolynomialVariable"];theta=c["PrimitiveElement"];
 mp=c["Modulus"];m=c["CyclotomicOrder"];zv=zeta[m];
 If[!IrreduciblePolynomialQ[mp],Return[False]];
 If[!zeroQ[mp /. t->theta] || !zeroQ[(c["CyclotomicPolynomial"] /. t->theta)-zv] ||
    !zeroQ[(c["TargetPolynomial"] /. t->theta)-result["Target"]],Return[False]];
 rem[e_]:=PolynomialRemainder[Expand[e],mp,t];
 polys={c["ZSymbol"]->c["CyclotomicPolynomial"]};rules={c["ZSymbol"]->zv};
 Do[p=st["Prime"];j=st["Branch"];
   If[!PrimeQ[p] || Mod[m,p]!=0 || !IntegerQ[j] || !(0<=j<p),Return[False]];
   a=rem[st["Radicand"] /. polys];r=st["GeneratorPolynomial"];
   If[rem[r^p-a]=!=0,Return[False]];
   br=zv^(m/p j) RootReduce[a /. t->theta]^(1/p);
   If[!zeroQ[br-(r /. t->theta)],Return[False]];
   AppendTo[polys,st["Symbol"]->r];
   AppendTo[rules,st["Symbol"]->zv^(m/p j) (st["Radicand"] /. rules)^(1/p)],{st,c["Steps"]}];
 formula=c["Formula"];
 rem[(formula /. polys)-c["TargetPolynomial"]]===0 &&
 (formula /. rules)===result["Expression"] && RadicalExpressionQ[result["Expression"]]
 ],False]];
RadicalTowerVerify[_] := False;

RadicalSolve[a_,OptionsPattern[]] := Module[
 {method=OptionValue[Method],tc=OptionValue[TimeConstraint],cap=OptionValue["MaxFieldDegree"],
  depth=OptionValue["MaxDepth"],pairs=OptionValue["PairResolvent"],target,f,x=Unique["x"],e,cs,which,ans},
 If[!MemberQ[{"Automatic","Practical","Complete"},method] ||
   !(tc===Infinity || (NumericQ[tc] && tc>0)) ||
   !(cap===Infinity || (IntegerQ[cap] && cap>=1)) || !(IntegerQ[depth] && depth>=0),
   Return[<|"Status"->"InvalidInput","Diagnostics"->{"Invalid method or resource limit."}|>]];
 TimeConstrained[Catch[
   If[!FreeQ[a,_Real],fail["InvalidInput","Inexact input is not accepted."]];
   target=Quiet[Check[RootReduce[a],$Failed]];
   f=Quiet[Check[MinimalPolynomial[target,x],$Failed]];
   If[f===$Failed || !PolynomialQ[f,x] || !VectorQ[CoefficientList[f,x],rationalQ] ||
      Exponent[f,x]<1,fail["InvalidInput","Require a single exact algebraic number over Q without parameters."]];
   f=monic[f,x];
   If[rationalQ[target],Return[<|"Status"->"Success","Method"->"Rational",
      "Target"->target,"Expression"->target,"Certificate"-><||>|>]];
   If[method=!="Complete",
     e=ToRadicals[target];
     If[RadicalVerify[target,e],Return[<|"Status"->"Success","Method"->"ToRadicals",
       "Target"->target,"Expression"->e,"Certificate"-><|"Verification"->"RootReduce"|>|>]];
     {cs,which}=structural[f,x,0,depth];
     cs=Quiet[Check[SortBy[cs,Abs[N[#-target,30]]&],cs]];
     ans=SelectFirst[cs,RadicalVerify[target,#]&,$Failed];
     If[ans=!=$Failed,Return[<|"Status"->"Success","Method"->which,"Target"->target,
       "Expression"->ans,"Certificate"-><|"MinimalPolynomial"->f,"Verification"->"RootReduce"|>|>]];
     If[TrueQ[pairs] && Exponent[f,x]<=12,
       cs=pairCandidates[f,x];ans=SelectFirst[cs,RadicalVerify[target,#]&,$Failed];
       If[ans=!=$Failed,Return[<|"Status"->"Success","Method"->"PairResolvent",
         "Target"->target,"Expression"->ans,"Certificate"-><|"Verification"->"RootReduce"|>|>]]]];
   If[method==="Practical",fail["Inconclusive","No certified expression was found by the practical methods. This is not a nonsolvability proof."]];
   kummer[target,f,x,cap],srFailureTag],tc,
   <|"Status"->"Inconclusive","Diagnostics"->{"TimeConstraint exceeded; no mathematical conclusion."}|>]];

SystematicToRadicals[a_,opts:OptionsPattern[]] := Module[{r=RadicalSolve[a,opts]},
 If[AssociationQ[r] && Lookup[r,"Status",""]==="Success",r["Expression"],
   Failure[If[AssociationQ[r],Lookup[r,"Status","Inconclusive"],"Inconclusive"],
     If[AssociationQ[r],r,<|"Diagnostics"->{"Unexpected backend result."}|>]]]];
End[];
EndPackage[];
