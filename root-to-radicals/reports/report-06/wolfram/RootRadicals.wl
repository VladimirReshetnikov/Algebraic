(* ::Package:: *)
(* RootRadicals 0.1.0 -- MIT-0. See ../article/root-radicals.pdf. *)
BeginPackage["RootRadicals`"];
RadicalizeRoot::usage = "RadicalizeRoot[a, options] returns an Association describing a certified radical conversion of an exact algebraic number a. Unknown and resource-limited results are not proofs of nonsolvability.";
RootToRadicals::usage = "RootToRadicals[a, options] returns a radical expression, or a Failure containing the structured result. Every successful Wolfram result is checked by RootReduce against a.";
ExactRadicalQ::usage = "ExactRadicalQ[e] tests the grammar of finite expressions over rational numbers and I using addition, multiplication, and rational powers.";
DecodeRadicalProgram::usage = "DecodeRadicalProgram[association] decodes the whitelisted rootradicals-dag-v1 JSON representation without evaluating code strings.";
Begin["`Private`"];
$PackageDirectory = DirectoryName[$InputFileName];
$DefaultDriver = FileNameJoin[{DirectoryName[$PackageDirectory], "python", "driver.py"}];
ratQ[z_] := IntegerQ[z] || Head[z] === Rational;
ExactRadicalQ[z_] := Which[
  ratQ[z], True,
  Head[z] === Complex, ratQ[Re[z]] && ratQ[Im[z]],
  MemberQ[{Plus, Times}, Head[z]], AllTrue[List @@ z, ExactRadicalQ],
  Head[z] === Power, ratQ[z[[2]]] && ExactRadicalQ[z[[1]]],
  True, False];
SetAttributes[limited, HoldFirst];
limited[e_, Infinity] := e;
limited[e_, t_] := TimeConstrained[e, t, $Failed];
exactEqual[a_, b_, limit_] := TrueQ[limited[Quiet[Check[RootReduce[a-b] === 0, False]], limit]];
rrSuccess[a_, e_, method_, more_:<||>] := Join[
  <|"Status"->"Success", "Expression"->e, "Verified"->True,
    "Input"->a, "Method"->method|>, more];
rrStatus[status_, message_, more_:<||>] := Join[
  <|"Status"->status, "Verified"->False, "Message"->message|>, more];

(* A bounded native accelerator. Failure here has no Galois-theoretic meaning. *)
zeta[n_, k_] := (-1)^(2 Mod[k,n]/n);
dickson[0, x_, a_] := 2;
dickson[n_Integer?Positive, x_, a_] := Module[{u=2,v=x,w,j},
  For[j=2,j<=n,j++,w=Expand[x v-a u];u=v;v=w];v];
rationalRoots[a_, d_] := Module[{r},
  If[a<0 && EvenQ[d], Return[{}]];
  r=If[a<0, -(-a)^(1/d), a^(1/d)];
  If[!ratQ[r], Return[{}]];
  If[EvenQ[d] && r!=0,{r,-r},{r}]];
smallRoots[p_, x_] := Module[{r},
  r=Quiet[Check[x /. Solve[p==0,x,Cubics->True,Quartics->True],$Failed]];
  If[!ListQ[r],Return[$Failed]];
  r=ToRadicals[r];
  If[Length[r]==Exponent[p,x] && AllTrue[r,ExactRadicalQ],r,$Failed]];
structuralRoots[p0_,x_,depth_:16] := Module[
  {p,n,shift,q,nonzero,a,b,u,r,d,h,sub,g,j,k,ar},
  If[depth<0,Return[$Failed]];
  n=Exponent[p0,x];p=Expand[p0/Coefficient[p0,x,n]];
  If[n<=4,Return[smallRoots[p,x]]];
  shift=-Coefficient[p,x,n-1]/n;q=Expand[p/.x->x+shift];
  nonzero=Select[Range[n],Coefficient[q,x,#]!=0&];
  If[nonzero=={n},u=(-Coefficient[q,x,0])^(1/n);
    Return[Table[shift+zeta[n,k] u,{k,0,n-1}]]];
  a=-Coefficient[q,x,n-2]/n;b=Expand[dickson[n,x,a]-q];
  If[FreeQ[b,x] && a!=0,
    u=((b+Sqrt[b^2-4 a^n])/2)^(1/n);
    Return[Table[shift+zeta[n,k] u+a/(zeta[n,k] u),{k,0,n-1}]]];
  If[EvenQ[n],d=n/2;
    Do[If[a!=0 && And@@Table[
          Coefficient[q,x,d-j]==a^j Coefficient[q,x,d+j],{j,1,d}],
      h=Coefficient[q,x,d]+Sum[Coefficient[q,x,d+j] dickson[j,x,a],{j,1,d}];
      sub=structuralRoots[h,x,depth-1];
      If[ListQ[sub],Return[Flatten[Table[
        {shift+(r+Sqrt[r^2-4 a])/2,shift+(r-Sqrt[r^2-4 a])/2},{r,sub}],1]]]],
      {a,rationalRoots[Coefficient[q,x,0],d]}]];
  g=GCD@@nonzero;
  If[g>1,h=Sum[Coefficient[q,x,j] x^(j/g),{j,0,n,g}];
    sub=structuralRoots[h,x,depth-1];
    If[ListQ[sub],Return[Flatten[Table[
      Table[shift+zeta[g,k] r^(1/g),{k,0,g-1}],{r,sub}],1]]]];
  $Failed];
chooseRoot[candidates_, a_, verifyLimit_] := Module[{ordered},
  ordered=SortBy[DeleteDuplicates[candidates],Quiet[Abs[N[#-a,40]]]&];
  SelectFirst[ordered,ExactRadicalQ[#] && exactEqual[#,a,verifyLimit]&,$Failed]];
nativeConvert[a_,p_,x_,hints_,verifyLimit_] := Module[{r,rs,factors,h},
  r=Quiet[Check[ToRadicals[a],$Failed]];
  If[ExactRadicalQ[r] && exactEqual[r,a,verifyLimit],Return[r]];
  rs=structuralRoots[p,x];
  If[ListQ[rs],r=chooseRoot[rs,a,verifyLimit];If[r=!=$Failed,Return[r]]];
  If[hints=!={},
    factors=Quiet[Check[FactorList[p,Extension->hints],$Failed]];
    If[ListQ[factors],
      Do[h=pair[[1]];If[1<=Exponent[h,x]<=4,
        rs=smallRoots[h,x];If[ListQ[rs],r=chooseRoot[rs,a,verifyLimit];
          If[r=!=$Failed,Return[r]]]],{pair,Rest[factors]}]]];
  $Failed];

(* Strict data protocol. No ToExpression, Get, or evaluation of returned source. *)
parseInteger[s_String] := If[StringMatchQ[s,RegularExpression["-?(0|[1-9][0-9]*)"]],
  If[StringStartsQ[s,"-"],-FromDigits[StringDrop[s,1]],FromDigits[s]],Throw[$Failed]];
parseInteger[_] := Throw[$Failed];
parseRational[node_] := Module[{n=parseInteger[node["n"]],d=parseInteger[node["d"]]},
  If[d<=0,Throw[$Failed]];n/d];
DecodeRadicalProgram[obj_Association] := Catch[Module[{nodes,vals={},ref,v,op,ids,k},
  If[Lookup[obj,"format",None]=!="rootradicals-dag-v1",Throw[$Failed]];
  nodes=Lookup[obj,"nodes",None];
  If[!ListQ[nodes] || Length[nodes]>100000,Throw[$Failed]];
  ref[i_] := If[IntegerQ[i] && 0<=i<Length[vals],vals[[i+1]],Throw[$Failed]];
  Do[If[!AssociationQ[node],Throw[$Failed]];op=Lookup[node,"op",None];
    v=Switch[op,
      "Q",parseRational[node],
      "I",I,
      "Add"|"Mul",ids=Lookup[node,"args",None];
        If[!ListQ[ids],Throw[$Failed]];
        If[op=="Add",Plus@@(ref/@ids),Times@@(ref/@ids)],
      "Pow",ref[node["base"]]^parseRational[node],
      _,Throw[$Failed]];
    If[!ExactRadicalQ[v],Throw[$Failed]];AppendTo[vals,v],{node,nodes}];
  k=Lookup[obj,"output",None];ref[k]]];
DecodeRadicalProgram[_] := $Failed;
rationalPair[a_] := {ToString[Numerator[a],InputForm],ToString[Denominator[a],InputForm]};
encodeProgram[expr_] := Catch[Module[{nodes={},emit,add,out},
  add[o_] := (AppendTo[nodes,o];Length[nodes]-1);
  emit[z_] := Which[
    ratQ[z],add[<|"op"->"Q","n"->First[rationalPair[z]],"d"->Last[rationalPair[z]]|>],
    z===I,add[<|"op"->"I"|>],
    Head[z]===Complex,Module[{re=emit[Re[z]],im=emit[Im[z]],i=emit[I],t},
      t=add[<|"op"->"Mul","args"->{im,i}|>];add[<|"op"->"Add","args"->{re,t}|>]],
    Head[z]===Plus || Head[z]===Times,Module[{ids=emit/@(List@@z)},
      add[<|"op"->If[Head[z]===Plus,"Add","Mul"],"args"->ids|>]],
    Head[z]===Power && ratQ[z[[2]]],Module[{base=emit[z[[1]]],q=rationalPair[z[[2]]]},
      add[<|"op"->"Pow","base"->base,"n"->First[q],"d"->Last[q]|>]],
    True,Throw[$Failed]];
  out=emit[expr];<|"format"->"rootradicals-dag-v1","nodes"->nodes,"output"->out|>]];

Options[RadicalizeRoot] = {
  Method->Automatic,"PythonExecutable"->Automatic,"DriverPath"->Automatic,
  "UseNative"->True,"NativeTimeLimit"->15,"VerificationTimeLimit"->60,
  "TimeLimit"->180,"MaxFieldDegree"->64,"ExtensionHints"->{},
  "MaxEmbeddingRetries"->4,"InitialEmbeddingDigits"->80};
Options[RootToRadicals] = Options[RadicalizeRoot];
RadicalizeRoot[input_,OptionsPattern[]] := Module[
  {a,p,x=Unique["x"],coeffs,hints=OptionValue["ExtensionHints"],r,method,
   py,driver,verify=OptionValue["VerificationTimeLimit"],req,response,process,
   limit=OptionValue["TimeLimit"],max=OptionValue["MaxFieldDegree"],hintsJSON,
   digits=OptionValue["InitialEmbeddingDigits"],attempt,status,approx,re,im,extra},
  method=Replace[OptionValue[Method],{Automatic->"auto","Structural"->"structural","Galois"->"galois"}];
  If[!MemberQ[{"auto","structural","galois"},method],
    Return[rrStatus["InvalidInput","Method must be Automatic, Structural, or Galois."]]];
  If[!ListQ[hints] || !AllTrue[hints,ExactRadicalQ],
    Return[rrStatus["InvalidInput","Extension hints must be exact radical expressions."]]];
  If[!FreeQ[input,_Real],Return[rrStatus["InvalidInput","Approximate inputs are not accepted."]]];
  If[!AllTrue[{verify,OptionValue["NativeTimeLimit"],limit},
      #===Infinity || (NumericQ[#] && TrueQ[#>0])&],
    Return[rrStatus["InvalidInput","Time limits must be positive numbers or Infinity."]]];
  r=limited[Quiet[Check[
    a=RootReduce[input];p=MinimalPolynomial[a,x];
    If[!PolynomialQ[p,x] || Exponent[p,x]<1,$Failed,
      coeffs=Reverse[CoefficientList[p,x]];
      If[AllTrue[coeffs,ratQ],True,$Failed]],$Failed]],verify];
  If[r=!=True,Return[rrStatus["Unknown",
    "Could not establish a finite exact algebraic input over Q within the verification limit."]]];
  If[ratQ[a],Return[rrSuccess[input,a,"Rational"]]];
  If[TrueQ[OptionValue["UseNative"]] && method=!="galois",
    r=limited[nativeConvert[a,p,x,hints,verify],OptionValue["NativeTimeLimit"]];
    If[r=!=$Failed && ExactRadicalQ[r],Return[rrSuccess[input,r,"NativeStructural"]]]];
  py=Replace[OptionValue["PythonExecutable"],Automatic:>If[$OperatingSystem=="Windows","python","python3"]];
  driver=Replace[OptionValue["DriverPath"],Automatic->$DefaultDriver];
  If[!StringQ[py] || !StringQ[driver] || !FileExistsQ[driver],
    Return[rrStatus["Unknown","Python executable or driver path is not configured correctly."]]];
  If[!(max===Infinity || (IntegerQ[max] && max>=1)),
    Return[rrStatus["InvalidInput","MaxFieldDegree must be a positive integer or Infinity."]]];
  If[!IntegerQ[digits] || digits<20 || digits>100000 ||
       !IntegerQ[OptionValue["MaxEmbeddingRetries"]] || OptionValue["MaxEmbeddingRetries"]<1,
    Return[rrStatus["InvalidInput","Invalid embedding precision or retry count."]]];
  hintsJSON=encodeProgram/@hints;
  Do[
    approx=N[a,digits];re=Rationalize[Re[approx],0];im=Rationalize[Im[approx],0];
    req=<|"coefficients"->(rationalPair/@coeffs),"method"->method,
      "max_field_degree"->Replace[max,Infinity->Null],
      "time_limit"->Replace[limit,Infinity->Null],"hint_digits"->digits,
      "embedding_hint"-><|"re"->rationalPair[re],"im"->rationalPair[im]|>,
      "extension_hints"->hintsJSON|>;
    process=Quiet[Check[RunProcess[{py,driver},All,ExportString[req,"RawJSON"]],$Failed]];
    If[!AssociationQ[process] || Lookup[process,"ExitCode",1]!=0,
      Return[rrStatus["Unknown","The Python process could not be executed.",<|"Process"->process|>]]];
    response=Quiet[Check[ImportString[process["StandardOutput"],"RawJSON"],$Failed]];
    If[!AssociationQ[response],Return[rrStatus["Unknown","Invalid backend JSON response."]]];
    status=Lookup[response,"status","unknown"];
    If[status=!="success",
      Return[rrStatus[Lookup[<|"not_solvable"->"NotSolvable","resource_limit"->"ResourceLimit",
        "invalid_input"->"InvalidInput"|>,status,"Unknown"],
        Lookup[response,"message","Backend did not produce a result."],<|"Backend"->response|>]]];
    r=DecodeRadicalProgram[Lookup[response,"program",None]];
    If[r===$Failed,Return[rrStatus["Unknown","The returned radical DAG failed validation."]]];
    (* A hint can select a different conjugate. Only this exact check authorizes success. *)
    If[exactEqual[r,a,verify],Return[rrSuccess[input,r,"Python",<|"Backend"->response|>]]];
    digits=Min[100000,2 digits],{attempt,OptionValue["MaxEmbeddingRetries"]}];
  rrStatus["Unknown","Exact verification against the original Root did not succeed. No expression was accepted.",
    <|"Backend"->response|>]];
RootToRadicals[a_,opts:OptionsPattern[]] := Module[{r=RadicalizeRoot[a,opts]},
  If[Lookup[r,"Status",None]==="Success",r["Expression"],Failure["RootRadicals",r]]];
End[];
EndPackage[];
