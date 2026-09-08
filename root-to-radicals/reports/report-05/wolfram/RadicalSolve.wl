(* ::Package:: *)
(* RadicalSolve 0.1.0. Native structural reductions and an exact Python backend.
   No notebook cells are evaluated. No private Wolfram symbols are used. *)
BeginPackage["RadicalSolve`"];

Radicalize::usage = "Radicalize[alpha] converts an exact algebraic number to radicals. Native structural reductions are attempted first; the bundled Python backend supplies general Galois/Fourier descent. A Failure is returned on a resource limit, nonsolvability, or failed verification.";
RadicalReport::usage = "RadicalReport[alpha, opts] returns the expression together with its method and exact verification status.";
RadicalExpressionQ::usage = "RadicalExpressionQ[e] accepts only exact rational arithmetic, I, and rational powers, with no Root or trigonometric functions.";
VerifyRadical::usage = "VerifyRadical[alpha,e] checks the radical grammar and requires RootReduce[alpha-e] === 0.";

Options[Radicalize] = {Method -> Automatic,
  "PythonExecutable" -> "python", "MaxFieldDegree" -> 96,
  TimeConstraint -> Infinity, "VerificationTimeConstraint" -> Infinity,
  "ReturnReport" -> False};
Options[RadicalReport] = Options[Radicalize];
Options[VerifyRadical] = {TimeConstraint -> Infinity};

Begin["`Private`"];
$packageDirectory = DirectoryName[$InputFileName];
$backendScript = FileNameJoin[{$packageDirectory, "..", "python", "cli.py"}];

rationalQ[e_] := IntegerQ[e] || Head[e] === Rational;
RadicalExpressionQ[e_] := Which[
  rationalQ[e], True,
  Head[e] === Complex, rationalQ[Re[e]] && rationalQ[Im[e]],
  Head[e] === Plus || Head[e] === Times,
    And @@ (RadicalExpressionQ /@ (List @@ e)),
  Head[e] === Power, rationalQ[e[[2]]] && RadicalExpressionQ[e[[1]]],
  True, False];

zeroExact[e_, limit_] := TrueQ[
  If[limit === Infinity,
    Quiet[Check[RootReduce[e] === 0, False]],
    TimeConstrained[Quiet[Check[RootReduce[e] === 0, False]], limit, False]]];
VerifyRadical[a_, e_, OptionsPattern[]] :=
  RadicalExpressionQ[e] && zeroExact[a-e, OptionValue[TimeConstraint]];

unity[n_Integer, k_Integer] := (-1)^(2 Mod[k,n]/n);
rationalNthRoots[q_, n_Integer] := Module[{a},
  If[q === 0, Return[{0}]];
  If[q < 0 && EvenQ[n], Return[{}]];
  a = Sign[q] Abs[q]^(1/n);
  If[!rationalQ[a], Return[{}]];
  If[EvenQ[n], {a,-a}, {a}]];

(* Returns {method, expressions}, or $Failed. Recursive degrees strictly fall. *)
nativeCandidates[p0_, x_Symbol] := Module[
  {p, n, center, q, exponents, g, inner, sub, values, a, b,
   d0, d1, d2, difference, m, residual, cc, c, t, j},
  n = Exponent[p0,x];
  p = Expand[p0/Coefficient[p0,x,n]];
  If[n === 1, Return[{"Rational", {-Coefficient[p,x,0]}}]];
  If[n <= 4,
    values = Quiet[Check[Table[
       ToRadicals[Root[Function[Evaluate[p /. x -> Slot[1]]], j]],
       {j,n}], $Failed]];
    If[ListQ[values] && And @@ (RadicalExpressionQ /@ values),
      Return[{"ClassicalFormula", values}]]];
  center = -Coefficient[p,x,n-1]/n;
  q = Expand[p /. x -> x+center];
  exponents = Select[Range[n], Coefficient[q,x,#] =!= 0 &];
  g = Apply[GCD,exponents];
  If[g > 1,
    inner = Sum[Coefficient[q,x,j g] x^j, {j,0,n/g}];
    sub = nativeCandidates[inner,x];
    If[sub =!= $Failed,
      values = Flatten[Table[center+unity[g,j] v^(1/g),
        {v,sub[[2]]},{j,0,g-1}]];
      Return[{"PowerComposition",values}]]];
  a = If[n > 2, -Coefficient[q,x,n-2]/n, 0];
  d0 = 2; d1 = x;
  Do[d2 = Expand[x d1-a d0]; d0=d1; d1=d2, {j,2,n}];
  difference = Expand[d1-q];
  If[FreeQ[difference,x],
    b = difference;
    values = If[a === 0,
      Table[center+unity[n,j] b^(1/n),{j,0,n-1}],
      t = ((b+Sqrt[b^2-4 a^n])/2)^(1/n);
      Table[center+unity[n,j] t+a/(unity[n,j] t),{j,0,n-1}]];
    Return[{"Dickson",values}]];
  If[EvenQ[n] && Coefficient[q,x,0] =!= 0,
    m=n/2;
    Do[
      residual=q; cc=ConstantArray[0,m+1];
      Do[c=Coefficient[residual,x,m+j]; cc[[j+1]]=c;
         residual=Expand[residual-c Expand[x^m (x+a/x)^j]], {j,m,0,-1}];
      If[residual === 0,
        inner=Sum[cc[[j+1]] x^j,{j,0,m}];
        sub=nativeCandidates[inner,x];
        If[sub =!= $Failed,
          values=Flatten[Table[
            {center+(v+Sqrt[v^2-4 a])/2,
             center+(v-Sqrt[v^2-4 a])/2}, {v,sub[[2]]}]];
          Return[{"ReciprocalComposition",values}]]],
      {a,rationalNthRoots[Coefficient[q,x,0],m]}]];
  $Failed];

(* Decode data, never Wolfram source text. Children must precede parents. *)
decodeInteger[text_String] := If[
  StringMatchQ[text,RegularExpression["-?[0-9]+"]],
  If[StringStartsQ[text,"-"],-FromDigits[StringDrop[text,1]],FromDigits[text]],
  Throw[$Failed,decodeTag]];
decodeDAG[data_Association] := Catch[Module[
  {nodes, values={}, node, tag, args, value, refs, root, den},
  If[Lookup[data,"format",None] =!= "RadicalSolve-DAG-1", Throw[$Failed,decodeTag]];
  nodes=Lookup[data,"nodes",None];
  If[!ListQ[nodes],Throw[$Failed,decodeTag]];
  Do[
    If[!ListQ[node] || Length[node]<1,Throw[$Failed,decodeTag]];
    tag=First[node];
    value=Switch[tag,
      "Q",
        If[Length[node]=!=3 || !AllTrue[Rest[node],StringQ],Throw[$Failed,decodeTag]];
        den=decodeInteger[node[[3]]];
        If[den===0,Throw[$Failed,decodeTag]];
        decodeInteger[node[[2]]]/den,
      "I", If[Length[node]=!=1,Throw[$Failed,decodeTag]]; I,
      "Add" | "Mul" | "Pow",
        refs=Rest[node];
        If[!AllTrue[refs,IntegerQ[#] && 0<=#<Length[values]&],Throw[$Failed,decodeTag]];
        args=(values[[#+1]]& /@ refs);
        Switch[tag,
          "Add",Plus@@args,
          "Mul",Times@@args,
          "Pow",If[Length[args]=!=2 || !rationalQ[args[[2]]],Throw[$Failed,decodeTag]];
            Power@@args],
      _,Throw[$Failed,decodeTag]];
    If[!RadicalExpressionQ[value],Throw[$Failed,decodeTag]];
    AppendTo[values,value], {node,nodes}];
  root=Lookup[data,"root",None];
  If[!IntegerQ[root] || !(0<=root<Length[values]),Throw[$Failed,decodeTag]];
  values[[root+1]]],decodeTag];
decodeDAG[_] := $Failed;

Radicalize[alpha_, OptionsPattern[]] := Module[
  {x, p, coefficients, method, native, answer, report, req, process,
   response, entries, entry, candidate, limit, verifyLimit, bound, py},
  method=OptionValue[Method]; limit=OptionValue[TimeConstraint];
  verifyLimit=OptionValue["VerificationTimeConstraint"];
  bound=OptionValue["MaxFieldDegree"]; py=OptionValue["PythonExecutable"];
  If[!MemberQ[{Automatic,"Native","Galois"},method],
    Return[Failure["InvalidInput",<|"MessageTemplate"->"Method must be Automatic, Native, or Galois."|>]]];
  If[!(bound===Infinity || (IntegerQ[bound] && bound>0)) ||
     !(limit===Infinity || (NumberQ[limit] && limit>0)) ||
     !(verifyLimit===Infinity || (NumberQ[verifyLimit] && verifyLimit>0)) || !StringQ[py],
    Return[Failure["InvalidInput",<|"MessageTemplate"->"Invalid resource limit or Python executable."|>]]];
  If[RadicalExpressionQ[alpha],
    report=<|"Expression"->alpha,"Method"->"AlreadyRadical","Verified"->True|>;
    Return[If[TrueQ[OptionValue["ReturnReport"]],report,alpha]]];
  If[!FreeQ[alpha,_Real],
    Return[Failure["InvalidInput",<|"MessageTemplate"->"Approximate input is not accepted."|>]]];
  p=Quiet[Check[MinimalPolynomial[alpha,x],$Failed]];
  If[p===$Failed || !PolynomialQ[p,x] || Exponent[p,x]<1 ||
    !AllTrue[CoefficientList[p,x],rationalQ],
    Return[Failure["InvalidInput",<|"MessageTemplate"->"An exact algebraic number over the rationals is required."|>]]];
  If[method =!= "Galois",
    native=If[limit===Infinity,nativeCandidates[p,x],
      TimeConstrained[nativeCandidates[p,x],limit,$Failed]];
    If[native =!= $Failed,
      answer=SelectFirst[native[[2]],VerifyRadical[alpha,#,TimeConstraint->verifyLimit]&,$Failed];
      If[answer =!= $Failed,
        report=<|"Expression"->answer,"Method"->native[[1]],"Verified"->True|>;
        Return[If[TrueQ[OptionValue["ReturnReport"]],report,answer]]]];
    If[method === "Native",
      Return[Failure["Unresolved",<|"MessageTemplate"->"The native structural methods did not produce a verified answer. This is not a nonsolvability result."|>]]]];
  If[!FileExistsQ[$backendScript],
    Return[Failure["BackendUnavailable",<|"MessageTemplate"->"The bundled Python backend script was not found.","Path"->$backendScript|>]]];
  coefficients=Reverse[CoefficientList[p,x]];
  req=<|"action"->"all",
    "coefficients"->({ToString[Numerator[#],InputForm],ToString[Denominator[#],InputForm]}& /@ coefficients),
    "method"->If[method==="Galois","galois","auto"],
    "max_field_degree"->If[bound===Infinity,Null,bound],
    "max_seconds"->If[limit===Infinity,Null,limit],
    "hard_timeout_seconds"->If[limit===Infinity,Null,limit]|>;
  process=Quiet[Check[RunProcess[{py,$backendScript},All,ExportString[req,"RawJSON"]],$Failed]];
  If[process===$Failed || !AssociationQ[process],
    Return[Failure["BackendUnavailable",<|"MessageTemplate"->"Python could not be executed. Set the PythonExecutable option to an interpreter with SymPy 1.14.0."|>]]];
  response=Quiet[Check[ImportString[process["StandardOutput"],"RawJSON"],$Failed]];
  If[!AssociationQ[response],
    Return[Failure["BackendError",<|"MessageTemplate"->"The backend did not return valid JSON.","StandardError"->process["StandardError"]|>]]];
  If[Lookup[response,"status",None] =!= "Success",
    Return[Failure[Lookup[response,"status","BackendError"],
      <|"MessageTemplate"->Lookup[response,"message","Backend failure."],"BackendRecord"->response|>]]];
  entries=Lookup[response,"roots",{}];
  If[!ListQ[entries],entries={}];
  Do[
    candidate=Quiet[Check[decodeDAG[Lookup[entry,"dag",None]],$Failed]];
    If[candidate =!= $Failed && VerifyRadical[alpha,candidate,TimeConstraint->verifyLimit],
      report=<|"Expression"->candidate,"Method"->Lookup[entry,"method","Python"],
        "Verified"->True,"BackendRecord"->Lookup[entry,"record",<||>]|>;
      Return[If[TrueQ[OptionValue["ReturnReport"]],report,candidate]]],
    {entry,entries}];
  Failure["VerificationFailed",<|"MessageTemplate"->"No backend candidate passed exact RootReduce verification for the requested embedding.","BackendRecord"->response|>]];

RadicalReport[alpha_,opts:OptionsPattern[]] :=
  Radicalize[alpha,"ReturnReport"->True,
    Sequence@@FilterRules[{opts},Except["ReturnReport"]]];

End[];
EndPackage[];
