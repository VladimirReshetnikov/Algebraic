(* NotebookTarget.wl

   The number studied in the notebook FindExtension.nb attached to the question is
   beta0 = InverseBetaRegularized[1/9, 1/3, 1/3].  This script reproduces its
   recognition as an algebraic number of degree 27, expresses the degree-9 number
   theta of the notebook's tower in radicals with RootToRadicals, and assembles a
   radical expression for beta0 through the "Extension" option (factorization over
   Q(3^(1/6), theta) followed by the cubic formula).

   Run with  wolfram -script NotebookTarget.wl  from this directory (about 15 minutes;
   progress is printed as it happens). *)

SetDirectory[DirectoryName[$InputFileName /. "" -> Directory[]]];
Get["RootToRadicals.wl"];
say[args___] := (Print[DateString[{"Hour", ":", "Minute", ":", "Second"}], "  ", args]);

beta0 = InverseBetaRegularized[1/9, 1/3, 1/3];
nbeta = With[{p = 1000}, With[{v = N[beta0, 3/2 p]}, SetPrecision[v, p]]];
{t, root} = AbsoluteTiming[RootApproximant[nbeta, 30]];
mp = MinimalPolynomial[root, x];
say["RootApproximant: degree ", Exponent[mp, x], " in ", t, " s; |root - beta0| at 400 digits: ", Abs[N[root - beta0, 400]]];
say["minimal polynomial: ", mp];

theta = Root[-1 + 9 #1 - 684 #1^2 + 3972 #1^3 - 12033 #1^4 + 19647 #1^5 + 3318 #1^6 + 6111 #1^7 - 657 #1^8 + #1^9 &, 3];
say["theta: solvable? ", RootSolvableQ[theta], ", group order ", RootGaloisData[theta]["Order"]];
rTheta = RootRadicalReport[theta, "VerificationTimeLimit" -> 300];
say["theta by radicals: ", KeyDrop[rTheta, "Expression"]];
say["theta expression: ", rTheta["Expression"]];

say["beta0 through the extension Q(3^(1/6), theta) ..."];
rBeta = RootRadicalReport[root, "Extension" -> {3^(1/6), theta}, "VerificationTimeLimit" -> 300];
If[FailureQ[rBeta], say["failed: ", rBeta],
  say["beta0 by radicals: ", KeyDrop[rBeta, "Expression"]];
  say["|expression - beta0| at 300 digits: ", Abs[N[rBeta["Expression"] - beta0, 300]]];
  say["expression: ", InputForm[rBeta["Expression"]]];
  Export["NotebookTarget-expression.m", rBeta["Expression"]]];
