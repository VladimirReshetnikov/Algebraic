(* Direct radical formulas, requiring no Python. These are supplied for a
   Wolfram kernel; preparation-time verification was performed in Python. *)
Module[{c, s, sextic, quintic, u},
 c = ((9 + Sqrt[849])/18)^(1/3);
 s = c - 4/(3 c);
 sextic = (s + Sqrt[s^2 + 4])/2;
 u = ((-3 + 4 I)/5)^(1/5);
 quintic = u + 1/u;
 <|"SexticRadical" -> sextic,
   "SexticCheck" -> RootReduce[sextic - Root[-1 - #^2 - #^3 + #^4 + #^6 &, 2]],
   "QuinticRadical" -> quintic,
   "QuinticCheck" -> RootReduce[quintic - Root[6 + 25 # - 25 #^3 + 5 #^5 &, 5]]|>
]
