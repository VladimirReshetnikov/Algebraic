# Why is ToRadicals[] not able to handle all cases? Is there a workaround?

https://mathematica.stackexchange.com/questions/34011/why-is-toradicals-not-able-to-handle-all-cases-is-there-a-workaround

---

The documentation for the function [`ToRadicals`](http://reference.wolfram.com/mathematica/ref/ToRadicals.html) says:
>♦ There are some cases in which expressions involving radicals can in principle be given, but `ToRadicals` cannot find them.

I'm concerned only with cases where the argument to `ToRadicals` is a single `Root` object with a single polynomial function with integer coefficients and no parameters, and an explicit root index.

---
Here is an example when _Mathematica_ cannot find an expression in radicals:

    ToRadicals[Root[-1 - #1^2 - #1^3 + #1^4 + #1^6 &, 2]]

But actually the expression exists:
$$\frac1{\sqrt[3]{36}}\left(\frac3{\sqrt{\beta\phantom{.}}}+\frac\beta2\right),\ \text{where}\ \beta=\sqrt[3]{2\,\ \alpha}-8\sqrt[3]{\frac3\alpha\phantom{}},\ \alpha=9+\sqrt{849}.$$

---
Another example is

    ToRadicals[Root[6 + 25 #1 - 25 #1^3 + 5 #1^5 &, 5]]

where the expression in radicals is
$$\sqrt[5]{\frac{-3+4\sqrt{-1}}5}+\sqrt[5]{\frac{-3-4\sqrt{-1}}5}$$

---
What is the nature of this restriction? Is the problem known to be undecidable in general? Or is it extremely computationally expensive? 

Can we write an implementation of `ToRadicals` that is able to find an expression in radicals in all cases when it is possible? Or, at least, in much more cases then the built-in `ToRadicals` does?

https://mathematica.stackexchange.com/q/34011/7288

---

    rad = Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2];
    poly = rad[[1]][x]
    PolynomialRemainder[poly, x^2 + a x + b, x]
    a /. SolveAlways[% == 0, x];
    Factor[poly, Extension -> %[[1]]];
    x /. Solve[% == 0, x];
    ans = Select[%, N[# == rad] &] // First // Simplify

>-1 - x^2 - x^3 + x^4 + x^6

>-1 + b- a b- a^2 b- a^4 b + b^2 + 
 3 a^2 b^2 - b^3 + (a - a^2 - a^3 - a^5 + b + 2 a b + 4 a^3 b - 3 a b^2) x

>1/12 (8 3^(2/3) (2/(-9 + Sqrt[849]))^(1/3) - 
   2^(2/3) (3 (-9 + Sqrt[849]))^(1/3) + Sqrt[
   2 (24 + 96 3^(1/3) (2/(-9 + Sqrt[849]))^(2/3) + 
      2^(1/3) (3 (-9 + Sqrt[849]))^(2/3))])
	  
https://mathematica.stackexchange.com/a/34015/7288