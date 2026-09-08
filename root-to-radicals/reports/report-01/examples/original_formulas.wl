(* These identities are proved in the article and were tested in Python.
   This Wolfram file itself was not executed in the delivery environment. *)
u = ((9 + Sqrt[849])/18)^(1/3);
y = u - 4/(3 u);
sexticAnswer = (y + Sqrt[y^2 + 4])/2;
v = ((-3 + 4 I)/5)^(1/5);
quinticAnswer = v + 1/v;
{RootReduce[sexticAnswer - Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]],
 RootReduce[quinticAnswer - Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]]}
