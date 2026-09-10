# Preserving inline membership assumptions

Mathics3 10.0.1 has native `Element` rules that can replace a symbolic
membership condition by an inequivalent one. For example,
`Element[Sin[a], Reals]` becomes `Element[a, Reals]`. The original condition
does not imply that `a` is real: `a = Pi/2 + I` gives `Sin[a] = Cosh[1]`.

The held analytic entry points preserve membership predicates in inline
`Assumptions` option values before Mathics evaluates those native rules.
Immediate rules, delayed rules, and literal nested option lists are covered.
The option value is still evaluated by the existing option-resolution path;
the protection itself does not evaluate it or repeat its effects.

Consequently, the strict package backend rejects a coefficient `a` under
`Assumptions -> Element[Sin[a], Reals]` when it cannot prove that `a` is real.
The same membership assumption remains sufficient for a coefficient
`Sin[a]`. Ordinary positive-parameter assumptions continue to work. Unknown
membership predicates retain an internal held head so inspecting a stored
assumption does not cause Mathics to weaken it again.

This protection applies at the package's existing held analytic boundary.
It cannot reconstruct a condition that Mathics has already rewritten in a
stored variable, a computed option container, or `$Assumptions` before that
boundary is reached. Write the original condition inline when its symbolic
membership structure matters. Other constructors that perform ordinary
argument evaluation before entering that boundary have the same limitation.

Literal explicit native backend calls retain native evaluation and their
native-result contract. A native result does not assert that the package has
proved an analytic remainder or a real branch. The official Wolfram kernel
does not load this protection and retains its original definitions and
evaluation behavior.
