# Empty-list mapping in Mathics

Mathics3 10.0.1 can invalidate the internal evaluation cache of an empty list
when `Map` visits it. A later use of the same list inside a numeric list can
terminate the interpreter with a Python `AssertionError`. This reproduces
without loading AsymptoticAnalysis:

```wl
b = {};
f /@ b;
{b, 2, 0}
```

Empty coefficient lists are valid and common in this package. For example,
truncating away the finite coefficient in a flat sector leaves an empty jet
with a finite error bound. A successful Fourier residual check similarly
returns an empty list of residual blocks. These empty lists must remain safe
to store, inspect, and combine with their numerical metadata.

`MathicsLists.wl` redirects `Map` references in package-owned public, private,
and compatibility function definitions to an adapter. It handles exactly the two-argument form with an
empty list by returning an empty list directly. In that case there are no
applications of the mapped function. The function expression and input retain
ordinary argument evaluation, including any effects of evaluating the function
expression itself. Nonempty lists, other expression heads, explicit level
specifications, options, and invalid argument forms delegate to ``System`Map``.

The installer holds every inspected symbol, including symbols with stored or
effectful values. Reapplying the installer leaves already redirected function
definitions unchanged. An exact owning-context check excludes caller and
System definitions. The installer changes only the relevant `Map` references
in downvalues, retains stored values, and does not modify Mathics' ``System`Map``
or the installed interpreter.
The official Wolfram kernel does not load this adapter.

The public regression checks cover flat-sector truncation, scalar
multiplication, polynomial observables, and differentiation, including separate
inner and omitted-sector remainders. They also cover Fourier coefficient
extraction and an independently composed residual with no nonzero blocks.

The initial installer covered only private definitions. Wave-4 review
identified an omitted route through compatibility `Lookup`: both an empty
key list and an empty association list could still corrupt the reused list.
The regression checks both forms and subsequent construction of nested numeric
metadata. Official controls also establish an ambiguity at the empty first
argument: `Lookup[{}, key, default]` treats it as an empty rule collection and
returns the default once. An empty key list evaluates no default. Across
multiple missing keys or associations, one lazily evaluated default is shared
by the whole call. The adapter preserves these distinctions. The public empty
inverse multi-index is also tested; that public example already passed before
this extension and is not claimed as a reproduced crash.
