(* Load this script, or evaluate its sections in a notebook.
   Expected results follow from the article's proofs. This Wolfram code
   was not executed during preparation; see verification_results.json. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "RootDecomposition.wl"}]];

ap = Root[-1 - # + 3 #^3 - #^4 + #^5 - 3 #^6 + 2 #^7 + #^9 &, 1];
as = Root[8 - 4 # + 24 #^2 - 15 #^3 + 3 #^5 + 6 #^6 + #^9 &, 1];
a = Root[1 + # + #^3 &, 1];
b = Root[1 - # + #^3 &, 1];

(* Direct exact certificates: both are zero. *)
{RootReduce[ap - a b], RootReduce[as - a - b]}

(* Template-free recovery. Each result is an Association. *)
productResult = ProductDecomposition[ap];
sumResult = GlobalAdditiveDecomposition[as];
{DecompositionExpression[productResult], DecompositionExpression[sumResult]}
{productResult["MaximumDegree"], sumResult["MaximumDegree"]}
{productResult["GlobalOptimalityCertified"], sumResult["GlobalOptimalityCertified"]}

(* Inspect all subfield dimensions. Expected: {1,3,3,9} in each case. *)
productField = FieldDecompositionData[ap];
sumField = FieldDecompositionData[as];
{Length /@ productField["Subfields"], Length /@ sumField["Subfields"]}

(* A genuinely three-factor example, globally optimal degree 2. *)
u8 = RootReduce[(1 + Sqrt[2]) (1 + Sqrt[3]) (1 + Sqrt[5])];
tensorResult = ProductDecomposition[u8];
DecompositionExpression[tensorResult]

(* Optional small-height search. It is not needed by the field algorithm.
   Uncomment to enumerate all primitive polynomials with degree <= 3,
   coefficient height <= 1, and decompositions of length <= 2.
   More generous bounds can be expensive. *)
(* boundedProduct = BoundedDecompositionSearch[ap, "Product", 3, 1, 2]; *)
(* boundedSum = BoundedDecompositionSearch[as, "Sum", 3, 1, 2]; *)

(* Optional global additive test requiring a normal closure of degree 24.
   The unrestricted answer has degree 4, not the internal-field answer 6. *)
(* quartics = {Root[-1 - # + #^4 &, 1], Root[-1 - # + #^4 &, 2]}; *)
(* outsideExample = RootReduce[Total[quartics]]; *)
(* externalResult = GlobalAdditiveDecomposition[outsideExample]; *)
