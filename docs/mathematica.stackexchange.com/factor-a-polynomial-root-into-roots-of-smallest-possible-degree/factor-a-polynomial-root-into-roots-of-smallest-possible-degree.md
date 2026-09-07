

# Factor a polynomial Root into Roots of smallest possible degree 

Asked 10 years, 7 months ago 

Modified 7 years ago Viewed 700 times 

Suppose I have a polynomial <u>Root</u> representing an algebraic number. I want to represent it as a product of several polynomial Root s (if possible) such that the largest degree among the factors **15** is as small as possible. For example, Root[-1 - #1 + 3 #1^3 - #1^4 + #1^5 - 3 #1^6 + 2 #1^7 + #1^9 &, 1] has to be represented as Root[1 + # + #^3 &, 1] Root[1 - # + #^3 &, 1] . 

The second problem is the same, but replacing "product" with "sum". For example, Root[8 - 4 #1 + 24 #1^2 - 15 #1^3 + 3 #1^5 + 6 #1^6 + #1^9 &, 1] has to be represented as Root[1 + # + #^3 &, 1] + Root[1 - # + #^3 &, 1] . 

How can I implement solutions to these problems in _Mathematica_ ? 

**simplifying-expressions symbolic algebraic-manipulation algorithm number-theory** 

Share Edit Close Delete Flag 

edited Aug 7, 2019 at 18:45 asked Feb 8, 2016 at 18:55 Vladimir Reshetnikov **6,651** 32 83 



- 5 I'm sure you are aware of this but I'll say it anyway: this is not an easy problem. – Daniel Lichtblau May 9, 2016 at 14:14 

   - Would this perhaps be better asked on <u>Mathematics?</u> – Mr.Wizard Jul 8, 2016 at 6:31 

   - Recently we worked on a Metropolis-Hasting algorithm here in permutation-98 space. Consider two polynomials in rational coefficients of degree 3. That's rational-8 space. Is it inconceivable to adapt this algorithm to search this space and converge to a solution? – Dominic Aug 7, 2019 at 20:49 

- 1 @Dominic for Metropolis-Hastings you need to define a reasonably continuous quality function that you can try to maximize or minimize. Do you have any ideas for how to define it? – Roman Aug 7, 2019 at 22:57 

- 2 Just to state the obvious, going in opposite direction can be done with the help of direct products of companion matrices. Here, the problem is to write a companion matrix as a direct product of companion matrices. <u>math.stackexchange.com/questions/331017/… – yarchik Aug 8, 2019 at 7:35</u> 

| 

Sorted by: Reset to default 

2 Answers 

Date modified (newest first) 



# **A constructive approach** 

## **13 The problem can be solved if the form of the solution is given.** 



Define the two factors using a hint (that these should be _cubic_ equations) in the original post 

y1 = x^3 - p1 x + q1 y2 = x^3 - p2 x + q2 

+500 

Build a companion matrix of the polynomial p(x) 

CompanionMatrix[p_,x_]:=Module[{n,w=CoefficientList[p,x]},w=-w/Last[w]; n=Length[w]-1; SparseArray[{{i_,n}:>w[[i]],{i_,j_}/;i==j+1->1},{n,n}]] 

- The roots of a polynomial equation pA(x) = 0 are given by the eigenvalues of its companion matrix A. 

> If  is a root of a pA(x) (with companion matrix A) and  is a root of b pB(x) (with companion matrix B) then ab is an eigenvalue of A ⊗ B and a + b is an eigenvalue of A ⊗ I + I ⊗ B, where ⊗ is the direct product of matrices. 

Let us focus on the _product_ case and, therefore, determine the characteristic equation of the direct product of companion matrices 

(a1=CompanionMatrix[y1,x])//MatrixForm 

(a2=CompanionMatrix[y2,x])//MatrixForm y3=CharacteristicPolynomial[KroneckerProduct[a1,a2],x] y4=y3 Sign[CoefficientList[y3,x]//Last] 

The sum is treated similarly. 

We find out that the resulting characteristic polynomial is 

y4=-q1^3 q2^3 + p1 p2 q1^2 q2^2 x + (-p2^3 q1^2 - p1^3 q2^2 + 3 q1^2 q2^2) x^3 + p1 p2 q1 q2 x^4 + p1^2 p2^2 x^5 - 3 q1 q2 x^6 - 2 p1 p2 x^7 + x^9 

**Notice the relatively simple form in the case of trinomial equations.** Now, your polynomial is 

z = -1 - #1 + 3 #1^3 - #1^4 + #1^5 - 3 #1^6 + 2 #1^7 + #1^9 &@x 

We demand that the two polynomials ( y3 and z ) are equal for any value of x 

r = SolveAlways[z == y4, {x}] 

Several solutions are obtained. Take, for instance, the first one 

{y1, y2} /. r[[1]] 

(*{1/q2 + x/q2^(2/3) + x^3, q2 - q2^(2/3) x + x^3}*) 

Setting q2=1 we obtain the OP result. 

# **Comment on the method** 

MA has a nice RootApproximant function, which operates by virtue of the <u>LLL</u> algorithm. One may be tempted to follow this route and implement some kind of this <u>experimental mathematics</u> approach. In contrast, the presented solution is _fully constructive_ (in fact, algebraic) and does not require arbitrary precision computations. 

# **Answer to the 1st challenge question** 

y1=x^5+ m x^3+n x^2+p1 x+q1; y2=x^3+ p2 x+q2; a1=CompanionMatrix[y1,x]; a2=CompanionMatrix[y2,x]; y3=CharacteristicPolynomial[KroneckerProduct[a1,a2],x]; y4=y3 Sign[CoefficientList[y3,x]//Last]; z=-282300416-64550400 #-34426880 #^2-14185880 #^3+8564800 #^4+4231216 #^5-972800 #^6-367820 #^7+27360 #^8+2600 #^9+1680 #^10+100 #^11-240 #^12+40 #^13+#^15&@x; r=SolveAlways[y4==z,{x}] ({y1,y2}/.r[[1]])/.q2->1 Out[1]= {656-150 x+80 x^2-20 x^3+x^5,1+x+x^3} 

Notice that in the characteristic equation the highest order term can be negative, whereas I assume that in the given equation z it is always 1. Therefore, in order to use SolveAlways y3 is multiplied by the sign. 

From the shown solutions, one can see that there is some arbitrariness in the results. But this is, of course, expected. As for the shown solution in radicals, one probably needs to guess the field extension. 

One can create a Module as to fully automate the derivation. But is there a pressing need? 

# **Answer to the 2st challenge question** 

Here I demonstrate that the method can be used to write a root P in terms of three roots of lower-order polynomials as P = Q + RS. Additionally, the computation is done in a more structured form 

1. Define a generic polynomial with 1 as the leading coefficient 

pX[a_,n_]:=x^n+Sum[a[i]x^i,{i,0,n-1}] 

2. Define two modules that split a root in terms of a sum or a product 

pSum[pA_,pB_,y_]:=Module[{mA,mB,mAB,nA,nB,p}, nA=Exponent[pA,y]; nB=Exponent[pB,y]; mA=CompanionMatrix[pA,y]; mB=CompanionMatrix[pB,y]; 

mAB=KroneckerProduct[mA,IdentityMatrix[nB]]+KroneckerProduct[IdentityMatrix[nA],mB]; p=CharacteristicPolynomial[mAB,y]; p Sign[CoefficientList[p,y]//Last] ] pProduct[pA_,pB_,y_]:=Module[{mA,mB,mAB,p}, mA=CompanionMatrix[pA,y]; mB=CompanionMatrix[pB,y]; mAB=KroneckerProduct[mA,mB]; p=CharacteristicPolynomial[mAB,y]; p Sign[CoefficientList[p,y]//Last] ] 

  

3. Construct a working example for polynomials of the degrees 3, 2, 2 respectively. 

{nQ,nR,nS}={3,2,2}; nT=nR nS; pP[0]=(RootReduce[Root[#^3+#+3&,1]+Root[#^2+#+5&,1]Root[#^2+#+7&,1]]//First)@x 

Out[1]= 1984051825-172403780 x-281288553 x^2+14148329 x^3+17544721 x^4-310509 x^5-619703 x^6-4623 x^7+13443 x^8+244 x^9-167 x^10-3 x^11+x^12 

### 4. Do the **first part** , namely, split the root of a 12th order equation into a sum of 3rd and 4th order roots 

(sol[1]=SolveAlways[pP[0]==pSum[pX[q,nQ],pX[t,nT],x],x])//Transpose//TableForm rule[1]=q[2]->0; sol[1,1]=First[sol[1]]/.rule[1]; AppendTo[sol[1,1],rule[1]]; {pX[q,nQ],pX[t,nT]}/.sol[1,1] 

Out[2]= {3+x+x^3,1225-35 x-58 x^2-x^3+x^4} 

5. Do the **second part** , split the 4th order root into a product of 2 roots of quadratic equations 

(sol[2]=SolveAlways[(pX[t,nT]/.sol[1,1])==pProduct[pX[r,nR],pX[s,nS],x],x])//Transpo rule[2]=s[1]->1; sol[2,1]=First[sol[2]]/.rule[2]; AppendTo[sol[2,1],rule[2]]; {pX[r,nR],pX[s,nS]}/.sol[2,1] 

Out[3]= {5+x+x^2,7+x+x^2}   

6. The coefficients in rule[1] and rule[2] have been selected as to match the original equation. However, other choices are possible. 

Share Edit Follow Flag 

edited Aug 14, 2019 at 7:52 answered Aug 8, 2019 at 8:27 yarchik **25.7k** 2 40 91 



- 1 Very nice (+ upvote, of course). I missed a beat on this one-- it can similarly be done using resultants and solving. Basically equivalent to your approach, if you drill deep enough. – Daniel Lichtblau Aug 8, 2019 at 14:54 

1 E.g. Root[-282300416 - 64550400 # - 34426880 #^2 - 14185880 #^3 + 8564800 #^4 + 4231216 #^5 - 972800 #^6 - 367820 #^7 + 27360 #^8 + 2600 #^9 + 1680 #^10 + 100 #^11 - 240 #^12 + 40 #^13 + #^15 &, 1] can be represented as Root[-656 - 150 # - 80 #^2 - 20 #^3 + #^5 &, 1] * Root[-1 + # + #^3 &, 1] and ... – Vladimir Reshetnikov Aug 8, 2019 at 18:38 

1 ... actually, can be expressed in radicals: <u>(√3</u> 6β 2−2 3<sup>2/3</sup> <u>)(α(10√2γ 4+(√5</u> 2+2<sup>7/10</sup> <u>)γ</u><sup>2</sup> +2γ+2<sup>3/10</sup> (5+3√2))+(−68−35√2+2√4100−1918√2 ~~<u>)</u>~~ γ−2 2<sup>3/10</sup> (68+35√2)) 3 2<sup>17/30</sup> αβγ<sup>3</sup> , where α = √−2050 −959−−−−−−−−−√−2<sup>–</sup> , β = √3 −9 +−−−−−√−−93−, γ = √5 −102 + 72−−−−−−−−−−−−−−−−−−−−−−−−−√2<sup>–</sup> − √−20714 + 14647−−−−−−−−−−−−√−−2<sup>–</sup> – Vladimir Reshetnikov Aug 8, 2019 at 18:39 

- 1 @VladimirReshetnikov Try √−−21 as an extension. Yes, these were my guesses, more systematic way is through the computation of the Galois group of the polynomial. There are some MA packages available (library.wolfram.com/infocenter/TechNotes/158) and some nice posts on math.stackexchange: <u>math.stackexchange.com/questions/45893/…</u> . – yarchik Aug 11, 2019 at 19:54 

- 1 Thanks! By the way, I tried the package <u>Solving the Quintic with Mathematica</u> you linked, and it worked unreliable for me, failing to found existing solutions sometimes. Here is my implementation of a method from Daniel Lazard's paper <u>Solving Quintics by Radicals: mathematica.stackexchange.com/a/134551/7288. I corrected a few typos found in the paper to make it</u> work, and so far have not found any bugs in it. – Vladimir Reshetnikov Aug 11, 2019 at 20:24 

| 



**9** 



I'll show the resultant formulation for the degree 15 example. 

The polynomial in question: 

poly15 = (-282300416 - 64550400 # - 34426880 #^2 - 14185880 #^3 + 8564800 #^4 + 4231216 #^5 - 972800 #^6 - 367820 #^7 + 27360 #^8 + 2600 #^9 + 1680 #^10 + 100 #^11 - 240 #^12 + 40 #^13 + #^15) &[z]; 

Define monic polynomials of degree 3 and 5 with symbolic coefficients. 

poly3[x_] := Array[a, 3, 0].x^Range[0, 2] + x^3 poly5[x_] := Array[b, 5, 0].x^Range[0, 4] + x^5 

Here is the double-resultant way to get a polynomial whose roots are products of the roots of poly3 and poly5 . 

resxy = Resultant[Resultant[z - x*y, poly3[y], y], poly5[x], x]; 

Equate coefficients with this and the degree 15 polynomial. Since we can scale the two roots, force a constant term to be unity. 

coeffs = CoefficientList[resxy - poly15, z] /. {a[0] -> 1} 

Now solve: 

solns=Solve[coeffs == 0] 

(* Out[285]= {{a[1] -> 1, a[2] -> 0, b[0] -> 656, b[1] -> -150, b[2] -> 80, b[3] -> -20, b[4] -> 0}, {a[1] -> -(-1)^(1/3), a[2] -> 0, b[0] -> 656 (-1 + (-1)^(1/3)), b[1] -> 150 (-1)^(1/3), b[2] -> 80, b[3] -> 20 (1 - (-1)^(1/3)), b[4] -> 0}, {a[1] -> (-1)^(2/3), a[2] -> 0, b[0] -> 656 (-1 - (-1)^(2/3)), b[1] -> -150 (-1)^(2/3), b[2] -> 80, b[3] -> 20 (1 + (-1)^(2/3)), b[4] -> 0}} *) 

Recover polynomials that give the root pairs. To get integer coefficients we use the first solution above. 

{poly3[x], poly5[x]} /. solns[[1]] 

(* Out[289]= {x + x^3 + a[0], 656 - 150 x + 80 x^2 - 20 x^3 + x^5} *) 

Not so well explained as the approach by @yarchik (which I'd expect to see get the bounty), but at some level it is equivalent. 

Share Edit Follow Flag answered Aug 8, 2019 at 21:43 Daniel Lichtblau **61.4k** 2 109 207 Nice trick with 2 Resultant s (+). I thought, you would be using 1 resultant. – yarchik Aug 9, 2019 at 11:12 

@yarchik It can be done with one but then one of the polynomials needs to have a variable substitution, something like x-->y/x, and I can never remember exactly what it is. – Daniel Lichtblau Aug 9, 2019 at 15:00 

