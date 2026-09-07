# Is it possible to make Decompose work with coefficients containing radicals?

https://mathematica.stackexchange.com/questions/206618/is-it-possible-to-make-decompose-work-with-coefficients-containing-radicals

It appears that [`Decompose`](https://reference.wolfram.com/language/ref/Decompose.html) works reliably only on polynomials with integer coefficients, although it seems to be not mentioned in the docs. Can I make it work (or implement an alternative that would work) on polynomials with coefficients containing radicals? For example,

    Decompose[3 + 3 √2 + (14 + 4 √2) x + (12 + 26 √2) x^2 + 
        (56 + 8 √2) x^3 + (8 + 48 √2) x^4 + 48 x^5 + 16 √2 x^6, x]

    (* {3 + 3 √2 + (14 + 4 √2) x + (4 + 12 √2) x^2 + 8 x^3, x + √2 x^2} *)

Is there a known algorithmic solution to this problem at all?

https://mathematica.stackexchange.com/q/206618/7288

---

One way to decompose a polynomial $p(x)$ is to factor $p'(x)$ over a field and exploit $\frac{d}{dx}f(g(x)) = f'(g(x))g'(x)$.

The following code does just that to find all candidate $g'(x)$:

    extendedDecompose[poly_, x_, extension_:Automatic] /; PolynomialQ[poly, x] := 
      Module[{ext, res},
        ext = If[extension === Automatic, CoefficientList[poly, x], extension];
        
        res = FixedPoint[
          Flatten[Prepend[Rest[#], iExtendedDecompose[First[#], x, ext]]]&,
          {poly}
        ];
        res = res //. {a___, x^n_., x^m_., b___} :> {a, x^(n + m), b};
 
        simplifyCoefficients[res, x]
      ]

    extendedDecompose[expr_, ___] := {expr}

    iExtendedDecompose[poly_, x_, extension_] :=
      Module[{deg, facs, cands, dg, d, a, gcoeffs, f, g, sys, sol, res},
        deg = Exponent[poly, x];
        If[deg <= 1 || PrimeQ[deg], Return[{poly}]];

        facs = Select[FactorList[D[poly, x], Extension -> extension], Exponent[#[[1]], x] > 0&];
        If[Length[facs] < 2, Return[{poly}]];

        cands = Select[Times @@@ Subsets[Join @@ ConstantArray @@@ facs], 1 <= Exponent[#, x] <= 0.5deg&];
		
        SetAttributes[a, Listable];
        Catch[
          Do[
            dg = Exponent[gprime, x]+1;
            d = deg/dg;
            f = fromCoefficients[a[Range[0, d]], x];
            
            gcoeffs = Prepend[CoefficientList[gprime, x]/Range[dg], 0];
            gcoeffs /= SelectFirst[gcoeffs, Not @* PossibleZeroQ];
            g = fromCoefficients[gcoeffs, x];
            
            sys = Thread[CoefficientList[Expand[f /. x -> g] - poly, x] == 0];
            sol = Solve[sys, a[Range[0, d]]];
            
            If[ListQ[sol] && Length[sol] > 0,
              Throw[{f /. First[sol], g}]
            ],
            {gprime, cands}
          ];
          
          {poly}
        ]
      ]

    SetAttributes[simplifyCoefficients, Listable];

    simplifyCoefficients[poly_, x_] := 
      fromCoefficients[Simplify[CoefficientList[poly, x]], x]

    fromCoefficients[coeffs_, x_] := coeffs . PowerRange[1, x^(Length[coeffs] - 1), x]

Your example:

    poly = 3 + 3 √2 + (14 + 4 √2) x + (12 + 26 √2) x^2 + 
      (56 + 8 √2) x^3 + (8 + 48 √2) x^4 + 48 x^5 + 16 √2 x^6;

    decomp = extendedDecompose[poly, x]

>     {3 (1 + √2) + (14 + 4 √2) x + (4 + 12 √2) x^2 + 8 x^3, x + √2 x^2}

    PossibleZeroQ[poly - (First[decomp] /. x -> Last[decomp])]

>     True

A nested example:

    poly2 = Collect[poly /. x -> x^4 - x + 1, x];

    decomp2 = extendedDecompose[poly2, x]

>     {3 (47 + 35 √2) + (-478 - 368 √2) x + (540 + 436 √2) x^2 - 8 (25 + 22 √2) x^3, 
        x - (2 x^2)/(4 + √2), x - x^4}

    Fold[#1 /. x -> #2 &, decomp2] - poly2 // PossibleZeroQ

>     True

https://mathematica.stackexchange.com/a/206622/7288

---

This is also the method used by Decompose (due to Alagar and Tranh if I remember correctly). It was implemented well before the Extension option in Factor and we never really revisited it. – 
Daniel Lichtblau
 Commented Sep 22, 2019 at 14:02
 https://mathematica.stackexchange.com/questions/206618/is-it-possible-to-make-decompose-work-with-coefficients-containing-radicals#comment531408_206622



