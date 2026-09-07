(* RootDecomposition.wl -- exact algorithms accompanying the article.
   Validation status: independently checked in SymPy; NOT executed in a
   Mathematica kernel in the authoring session. Run RunTests.wl locally.
   No numerical approximation is used to accept an identity.
*)
BeginPackage["RootDecomposition`"];
RootDegree::usage = "RootDegree[a] is the absolute algebraic degree over Q.";
RootDegreeLowerBound::usage = "RootDegreeLowerBound[a] gives a lower bound valid for any finite sum or product decomposition.";
RootSubfieldData::usage = "RootSubfieldData[theta] computes all embedded subfields of Q(theta), as rational row bases.";
RootPairDecompose::usage = "RootPairDecompose[a, \"Sum\"|\"Product\", data:Automatic] minimizes the maximum degree among TWO components in the supplied ambient field (default Q(a)).";
RootSumDecompose::usage = "RootSumDecompose[a, data:Automatic] optimizes arbitrary finite sums in the supplied ambient field (default Q(a)).";
RootGlobalSumDecompose::usage = "RootGlobalSumDecompose[a] optimizes arbitrary finite sums globally, using a normal closure when necessary. Potentially very expensive.";
RootPolynomialCatalogue::usage = "RootPolynomialCatalogue[d,H] lists all primitive irreducible integer polynomials of degrees 2 through d, coefficient height at most H and positive leading coefficient.";
RootProductFromCandidates::usage = "RootProductFromCandidates[a,candidates,d,R] exhausts products of at most R factors, with all but one factor from candidates; the last factor is tested exactly for degree <= d.";
BoundedRootProduct::usage = "BoundedRootProduct[a,d,H,R] searches products with at most R factors; all but one have minimal-polynomial height <= H and degree <= d. Failure to find is NOT global impossibility.";
RootPairFromPolynomial::usage = "RootPairFromPolynomial[a,p,x,op,d] uses a resultant to find a partner for a root of p; returns a verified pair or a scoped NotFound result.";
Begin["`Private`"];

$failureTag = Unique["RootDecompositionFailure"];
fail[tag_, detail_] := Throw[Failure[tag, <|"Detail" -> detail|>], $failureTag];
qQ[t_] := IntegerQ[t] || Head[t] === Rational;
zeroQ[t_] := TrueQ[RootReduce[t] === 0];
rr[t_] := Module[{v = Quiet[Check[RootReduce[t], $Failed]]},
  If[v === $Failed, fail["AlgebraicReduction", HoldForm[t]]]; v];

minimal[a_, x_] := Module[{p},
  If[!FreeQ[a, _Real], fail["InexactInput", "Use exact algebraic numbers, not decimal approximations."]];
  p = Quiet[Check[MinimalPolynomial[rr[a], x], $Failed]];
  If[p === $Failed || !PolynomialQ[p,x], fail["NotAlgebraic", HoldForm[a]]];
  If[!VectorQ[CoefficientList[p,x],qQ] || Exponent[p,x] < 1,
    fail["NotAlgebraicOverQ", HoldForm[a]]]; p];
degree[a_] := Module[{x}, Exponent[minimal[a,x],x]];
lower[a_] := Module[{n=degree[a]}, If[n==1,1,Max[First /@ FactorInteger[n]]]];
RootDegree[a_] := Catch[degree[a],$failureTag];
RootDegreeLowerBound[a_] := Catch[lower[a],$failureTag];

(* An integral primitive generator prevents ToNumberField from rescaling
   the generator behind our coordinate system. No integral BASIS is needed. *)
makeField[a_] := Module[{x,p,theta,n,c},
  p=minimal[a,x]; n=Exponent[p,x]; c=Coefficient[p,x,n];
  theta=rr[c a]; p=minimal[theta,x]; p=Expand[p/Coefficient[p,x,n]];
  <|"Theta"->theta,"Variable"->x,"Polynomial"->p,"Degree"->n|>];

vec[a_,ctx_] := Module[{n=ctx["Degree"],x=ctx["Variable"],v,an,p},
  v=rr[a]; If[qQ[v],Return[PadRight[{v},n]]];
  an=Quiet[Check[ToNumberField[v,ctx["Theta"]],$Failed]];
  If[Head[an]=!=AlgebraicNumber,fail["OutsideAmbientField",HoldForm[a]]];
  If[!zeroQ[an[[1]]-ctx["Theta"]],fail["GeneratorMismatch",an]];
  p=AlgebraicNumberPolynomial[an,x];
  p=PolynomialRemainder[p,ctx["Polynomial"],x];
  v=PadRight[CoefficientList[p,x],n];
  If[Length[v]!=n || !VectorQ[v,qQ],fail["BadCoordinates",v]]; v];
value[v_,ctx_] := rr[v.Table[ctx["Theta"]^j,{j,0,ctx["Degree"]-1}]];
mul[u_,v_,ctx_] := Module[{x=ctx["Variable"],n=ctx["Degree"],b,p},
  b=Table[x^j,{j,0,n-1}];
  p=PolynomialRemainder[Expand[(u.b)(v.b)],ctx["Polynomial"],x];
  PadRight[CoefficientList[p,x],n]];
rows[B_] := If[B==={}, {}, Select[RowReduce[B], !AllTrue[#,TrueQ[#==0]&]&]];
meet[A_,B_,n_] := Module[{eq=Join[NullSpace[A],NullSpace[B]]},
  If[eq==={},IdentityMatrix[n],rows[NullSpace[eq]]]];

(* A deterministic rational solution: free coordinates are set to zero.
   Missing is returned only after an exact inconsistency check. *)
qsolve[A_,b_] := Module[{R,n=Length[First[A]],z,p},
  R=RowReduce[MapThread[Append,{A,b}]];
  If[AnyTrue[R, AllTrue[Most[#],TrueQ[#==0]&] && Last[#]!=0 &],
    Return[Missing["Inconsistent"]]];
  z=ConstantArray[0,n];
  Do[p=Select[Range[n],row[[#]]!=0&,1];
    If[p=!={},z[[First[p]]]=Last[row]],{row,R}];
  If[A.z=!=b,fail["LinearSolveVerification",{A,b,z}]]; z];

(* For a factor g of minpoly(theta), compute
   {h(theta): g(X) divides h(X)-h(theta)} by rational linear algebra. *)
principal[g_,ctx_] := Module[{x=ctx["Variable"],n=ctx["Degree"],r,cols,h},
  r=Exponent[g,x];
  cols=Table[
    h=Expand[PolynomialRemainder[x^j,g,x]-ctx["Theta"]^j];
    Flatten[Table[vec[Coefficient[h,x,k],ctx],{k,0,r-1}]],
    {j,0,n-1}];
  rows[NullSpace[Transpose[cols]]]];

subfields[a_] := Module[{ctx=makeField[a],fl,gs,bs,new,B,n},
  n=ctx["Degree"];
  If[n==1,Return[<|"Field"->ctx,"Bases"->{IdentityMatrix[1]},
    "SubfieldDegrees"->{1},"FactorDegrees"->{1},"Complete"->True|>]];
  fl=Quiet[Check[FactorList[ctx["Polynomial"],Extension->{ctx["Theta"]}],$Failed]];
  If[fl===$Failed || !ListQ[fl] || Length[fl]<2,
    fail["ExtensionFactorizationFailed",ctx["Polynomial"]]];
  If[!AllTrue[Rest[fl],Last[#]==1&],fail["NonseparableFactorization",fl]];
  gs=First /@ Rest[fl]; bs={IdentityMatrix[n]};
  Do[B=principal[g,ctx]; new=meet[#,B,n]& /@ bs;
    bs=DeleteDuplicates[Join[bs,new]],{g,gs}];
  bs=SortBy[bs,Length];
  <|"Field"->ctx,"Bases"->bs,"SubfieldDegrees"->(Length /@ bs),
    "FactorDegrees"->(Exponent[#,ctx["Variable"]]& /@ gs),"Complete"->True|>];
RootSubfieldData[a_] := Catch[subfields[a],$failureTag];
getData[a_,data_] := Module[{z=If[data===Automatic,subfields[a],data]},
  If[!AssociationQ[z] || !TrueQ[z["Complete"]],
    fail["IncompleteSubfieldData","Supply completed RootSubfieldData output."]]; z];

normalizePair[terms_,op_] := Module[{b=terms[[1]],c=terms[[2]],x,p,m,mu,k,c0},
  p=minimal[b,x]; m=Exponent[p,x]; p=Expand[p/Coefficient[p,x,m]];
  If[op=="Sum",
    mu=-Coefficient[p,x,m-1]/m; Return[rr /@ {b-mu,c+mu}]];
  c0=Coefficient[p,x,0];
  If[c0==0,Return[terms]];
  k=rr[Surd[Abs[c0],m]];
  If[qQ[k] && k!=0,
    If[OddQ[m],k=Sign[c0] k]; rr /@ {b/k,c k}, terms]];

certificate[a_,terms_,op_,scope_,forceGlobal_:False] := Module[{ds,score,lb,ex},
  ds=degree /@ terms; score=Max[ds]; lb=lower[a];
  ex=If[op=="Sum",Total[terms],Times@@terms];
  If[!zeroQ[ex-a],fail["IdentityVerificationFailed",{a,terms,op}]];
  <|"Status"->"Success","Operation"->op,"Components"->terms,
    "Expression"->ex,"ComponentDegrees"->ds,"MaximumDegree"->score,
    "Verified"->True,"Scope"->scope,"GlobalDegreeLowerBound"->lb,
    "GlobalOptimalityProved"->TrueQ[forceGlobal || score==lb]|>];

pair[a_,op_,data_] := Module[{D,ctx,bs,av,pairs,F,G,w,ker,AG,u,v,terms},
  If[!MemberQ[{"Sum","Product"},op],fail["BadOperation",op]];
  If[degree[a]==1,Return[certificate[a,{rr[a]},op,"Global",True]]];
  D=getData[a,data]; ctx=D["Field"]; bs=D["Bases"]; av=vec[a,ctx];
  pairs=Flatten[Table[{i,j},{i,Length[bs]},{j,i,Length[bs]}],1];
  pairs=SortBy[pairs,Function[ij,{Max[Length /@ bs[[ij]]],Total[Length /@ bs[[ij]]]}]];
  Do[F=bs[[ij[[1]]]]; G=bs[[ij[[2]]]];
    If[op=="Sum",
      w=qsolve[Transpose[Join[F,G]],av];
      If[MissingQ[w],Continue[]];
      u=Take[w,Length[F]].F; v=Drop[w,Length[F]].G;
      terms=value[#,ctx]& /@ {u,v},
      AG=mul[av,#,ctx]& /@ G;
      ker=NullSpace[Transpose[Join[F,-AG]]];
      If[ker==={},Continue[]]; w=First[ker];
      u=Take[w,Length[F]].F; v=Drop[w,Length[F]].G;
      If[AllTrue[v,TrueQ[#==0]&],fail["UnexpectedZeroFactor",w]];
      terms={value[u,ctx],rr[1/value[v,ctx]]}];
    terms=normalizePair[terms,op];
    Return[certificate[a,terms,op,"OptimalTwoComponentsInAmbientField"]],
    {ij,pairs}];
  fail["InternalError","The trivial pair should always be available."]];
RootPairDecompose[a_,op_,data_:Automatic] := Catch[pair[a,op,data],$failureTag];

sumAny[a_,data_] := Module[{D,ctx,bs,av,levels,selected,B,w,parts,offset,len},
  If[degree[a]==1,Return[certificate[a,{rr[a]},"Sum","Global",True]]];
  D=getData[a,data]; ctx=D["Field"]; bs=D["Bases"]; av=vec[a,ctx];
  levels=Sort[DeleteDuplicates[Length /@ bs]];
  Do[selected=Select[bs,Length[#]<=d&]; B=Join@@selected;
    w=qsolve[Transpose[B],av]; If[MissingQ[w],Continue[]];
    offset=0; parts=Table[len=Length[F];
      With[{v=Take[w,{offset+1,offset+len}].F},offset+=len;value[v,ctx]],
      {F,selected}]; parts=Select[parts,!zeroQ[#]&];
    If[parts==={},parts={0}];
    Return[certificate[a,parts,"Sum","OptimalFiniteSumInAmbientField"]],
    {d,levels}];
  fail["InternalError","The whole ambient field should span the input."]];
RootSumDecompose[a_,data_:Automatic] := Catch[sumAny[a,data],$failureTag];

rootsOf[p_,x_] := Module[{fn=Function[Evaluate[p /. x->Slot[1]]]},
  Table[Root[fn,j],{j,Exponent[p,x]}]];
normalGenerator[a_] := Module[{x,p,all,reps,gens},
  p=minimal[a,x]; all=rootsOf[p,x];
  reps=Quiet[Check[ToNumberField[all,All],$Failed]];
  If[reps===$Failed || !ListQ[reps],fail["NormalClosureFailed",p]];
  gens=Cases[reps,AlgebraicNumber[t_,_List]:>t,{1}];
  If[gens==={},0,rr[First[gens]]]];
RootGlobalSumDecompose[a_] := Catch[Module[{ans,theta},
  ans=sumAny[a,Automatic];
  If[TrueQ[ans["GlobalOptimalityProved"]],Return[ans]];
  theta=normalGenerator[a]; ans=sumAny[a,subfields[theta]];
  Join[ans,<|"Scope"->"GlobalFiniteSumViaNormalClosure",
    "GlobalOptimalityProved"->True|>]],$failureTag];

catalogue[d_,H_,x_] := Module[{ans={},p},
  If[!IntegerQ[d] || d<1 || !IntegerQ[H] || H<1,
    fail["BadBounds",{d,H}]];
  Do[Do[If[GCD@@Join[cs,{lc}]!=1,Continue[]];
    p=lc x^m+cs.Table[x^j,{j,0,m-1}];
    If[TrueQ[IrreduciblePolynomialQ[p]],AppendTo[ans,p]],
    {lc,1,H},{cs,Tuples[Range[-H,H],m]}],{m,2,d}]; ans];
RootPolynomialCatalogue[d_,H_] := Catch[Module[{x},
  <|"Variable"->x,"Polynomials"->catalogue[d,H,x],
    "DegreeBound"->d,"CoefficientHeightBound"->H|>],$failureTag];

candidateProduct[a_,candidates_,d_,R_] := Module[{cat,walk,foundTag=Unique[],answer},
  If[!IntegerQ[d] || d<1 || !IntegerQ[R] || R<1,
    fail["BadBounds",{d,R}]];
  If[degree[a]<=d,Return[certificate[a,{rr[a]},"Product","CandidateSearch"]]];
  If[d<lower[a],Return[<|"Status"->"ImpossibleByDegreeLowerBound",
    "DegreeBound"->d,"GlobalDegreeLowerBound"->lower[a]|>]];
  cat=DeleteDuplicates[rr /@ candidates];
  If[!AllTrue[cat,!zeroQ[#] && degree[#]<=d&],
    fail["BadCandidates","Candidates must be nonzero and have absolute degree <= d."]];
  walk[prefix_,product_,start_,left_] := Module[{last,newproduct},
    last=rr[a/product];
    If[degree[last]<=d,
      Throw[certificate[a,Append[prefix,last],"Product","BoundedCandidateSearch"],foundTag]];
    If[left==0,Return[Null]];
    Do[newproduct=rr[product cat[[i]]];
      walk[Append[prefix,cat[[i]]],newproduct,i,left-1],{i,start,Length[cat]}]];
  answer=Catch[walk[{},1,1,R-1];Missing["NotFound"],foundTag];
  If[MissingQ[answer],<|"Status"->"NotFoundWithinBounds","DegreeBound"->d,
    "MaximumFactors"->R,"CandidateCount"->Length[cat],
    "GlobalImpossibilityProved"->False|>,answer]];
RootProductFromCandidates[a_,candidates_List,d_Integer,R_Integer] :=
  Catch[candidateProduct[a,candidates,d,R],$failureTag];
BoundedRootProduct[a_,d_Integer,H_Integer,R_Integer] := Catch[Module[{x,ps,cat,ans},
  If[d<1 || H<1 || R<1,fail["BadBounds",{d,H,R}]];
  If[degree[a]<=d,Return[certificate[a,{rr[a]},"Product","GlobalDegreeBound"]]];
  If[d<lower[a],Return[<|"Status"->"ImpossibleByDegreeLowerBound",
    "DegreeBound"->d,"GlobalDegreeLowerBound"->lower[a]|>]];
  ps=catalogue[d,H,x]; cat=Flatten[rootsOf[#,x]& /@ ps];
  ans=candidateProduct[a,cat,d,R];
  Join[ans,<|"CoefficientHeightBoundForAllButOneFactor"->H|>]],$failureTag];

(* An optional rational-resultant front end, not a rational-points solver. *)
RootPairFromPolynomial[a_,p_,x_Symbol,op_,d_Integer] := Catch[Module[
  {y,z,f,R,fl,qs,bs,cs},
  If[!MemberQ[{"Sum","Product"},op],fail["BadOperation",op]];
  If[d<1 || !PolynomialQ[p,x] || Exponent[p,x]<1 ||
    !VectorQ[CoefficientList[p,x],qQ],fail["BadCandidatePolynomial",p]];
  f=minimal[a,z]; bs=Select[rootsOf[p,x],degree[#]<=d&];
  If[op=="Product" && zeroQ[a],
    Return[If[bs==={},
      <|"Status"->"NotFoundForCandidatePolynomial",
        "GlobalImpossibilityProved"->False|>,
      certificate[a,{First[bs],0},op,"OneCandidatePolynomial"]]]];
  R=Expand[Resultant[p /. x->y,
    If[op=="Sum",f /. z->z+y,f /. z->z y],y]];
  If[R===0,fail["DegenerateResultant","Remove a zero root from the candidate polynomial."]];
  fl=FactorList[R]; qs=Select[First /@ Rest[fl],Exponent[#,z]<=d&];
  Do[cs=rootsOf[q,z];
    Do[If[op=="Product" && (zeroQ[b]||zeroQ[c]),Continue[]];
      If[zeroQ[If[op=="Sum",b+c,b c]-a],
        Return[certificate[a,normalizePair[{b,c},op],op,"OneCandidatePolynomial"]]],
      {b,bs},{c,cs}],{q,qs}];
  <|"Status"->"NotFoundForCandidatePolynomial","GlobalImpossibilityProved"->False|>
],$failureTag];

End[];
EndPackage[];
