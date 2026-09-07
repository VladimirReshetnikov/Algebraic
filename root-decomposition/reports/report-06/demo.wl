(* Run Get["demo.wl"] from the extracted directory.
   Expected results below are mathematically proved and independently checked;
   this file was not run in a native Wolfram kernel during preparation. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];
Clear[x, a, b, alphaProduct, alphaSum, productResult, sumResult];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];
alphaProduct = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
alphaSum = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
Print["Original identities: ",
  {RootReduce[a b - alphaProduct], RootReduce[a + b - alphaSum]}];
(* {0, 0} *)
productResult = MinTwoFactorInField[alphaProduct];
sumResult = MinSumGlobally[alphaSum];
Print["Automatic product result: ", productResult];
Print["Automatic sum result: ", sumResult];
(* Both maximum degrees are 3, with global minimality certified. *)
Print["Original small-height product representatives: ",
  PairFromPolynomials[alphaProduct, x^3+x+1, x^3-x+1, x, "Product"]];
Print["Subfield degrees of the product input: ",
  AllSubfieldBases[alphaProduct]["Degrees"]];
(* {1, 3, 3, 9} *)
Print["Its internal additive minimum: ",
  MinSumInField[alphaProduct]["MaxDegree"]];
(* 9, but the unrestricted additive minimum is 6, as proved in the article. *)
