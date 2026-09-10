# Mathics3

For installation, package-specific validation, compatibility subtleties, and
current limitations, see [AsymptoticAnalysis compatibility](COMPATIBILITY.md).
The [public API inventory](API-COVERAGE.md) maps exported operations to exact
portable cases and records remaining input and option coverage.
The [portable validation guide](PORTABLE-VALIDATION.md) explains supported
runner commands, receipt interpretation, and known execution-tool limits.
For the maintained implementation gotchas and reproducible checking rules,
see [MATHICS-NOTES.md](../MATHICS-NOTES.md), the companion to the Wolfram notes.
The [empty-list notes](LISTS.md) explain the package-local mapping workaround
used by flat-series and Fourier operations.
The [inline assumption notes](INPUT-ASSUMPTIONS.md) explain how held entry
points preserve symbolic membership conditions before native evaluation.
The comparison below is background material, not a package acceptance record.

https://mathics.org/

The useful way to think about Mathics3 is **not** as “another CAS with Mathematica-ish notation”, but as an independent reimplementation of a substantial subset of the Wolfram Language. Its parser and evaluator deliberately target WL semantics, and quite a lot of ordinary Mathematica code runs unchanged. The largest differences are now less about basic syntax than about the **long tail of evaluator semantics and the enormous difference in library coverage**.

For a concrete baseline, I am comparing current **Mathematica/Wolfram Language 15.0/15.0.1** with **Mathics3 10.0.1**. Mathematica 15.0 shipped in June 2026 and 15.0.1 in July; Mathics3 10.0.1 was released May 7, 2026. ([Wolfram][1])

## 1. Syntax: remarkably close

At the textual language level, Mathics is highly compatible. Both languages fundamentally parse input into the same Mathematica-style expression model:

```wl
f[x, y]
Plus[x, y]
x + y
{a, b, c}
Part[x, 2]
x[[2]]
Rule[x, y]
x -> y
Pattern[x, Blank[]]
x_
```

In both systems, syntax is largely syntactic sugar for expression trees. Thus

```wl
1 + 2/3
```

ultimately has a structure equivalent to

```wl
Plus[
    1,
    Times[
        2,
        Power[3, -1]
    ]
]
```

Mathics' parser explicitly constructs this Wolfram-style M-expression representation, including context qualification such as `System`Plus`. Its parser is based on operator precedence/precedence climbing, backed by extensive tables of Wolfram operators and named characters. ([Mathics3 Developer Reference][2])

Here is the practical syntax comparison:

| Feature                                    | Mathematica     | Mathics3            |
| ------------------------------------------ | --------------- | ------------------- |
| `Head[arg,…]` function syntax              | Yes             | Yes                 |
| `{a,b,c}` lists                            | Yes             | Yes                 |
| `expr[[i]]` parts                          | Yes             | Yes                 |
| `;;` spans                                 | Yes             | Yes                 |
| `=` / `:=`                                 | Yes             | Yes                 |
| `->` / `:>`                                | Yes             | Yes                 |
| `/.`, `//.`, rules                         | Yes             | Yes                 |
| `_`, `__`, `___`, named patterns           | Yes             | Yes                 |
| `?`, `/;`, alternatives, optional patterns | Yes             | Largely             |
| `#`, `#1`, `##`, `&` pure functions        | Yes             | Yes                 |
| `/@`, `@@`, `@@@`, `//`, `@`               | Yes             | Yes                 |
| `/;`, `/:`, `^=`, `^:=`, etc.              | Yes             | Mostly              |
| `Module`, `Block`, `With`                  | Yes             | Yes                 |
| `Do`, `For`, `While`, `If`, `Which`        | Yes             | Yes                 |
| contexts using backticks                   | Yes             | Yes                 |
| `BeginPackage` package conventions         | Yes             | Substantial support |
| implicit multiplication `2 x`              | Yes             | Yes                 |
| named characters `\[Alpha]` etc.           | Extensive       | Extensive           |
| Unicode mathematical operators             | Extensive       | Extensive           |
| comments `(* ... *)`                       | Yes             | Yes                 |
| arbitrary-precision literals               | Yes             | Yes                 |
| Mathematica's box language                 | Complete/native | Partial             |
| 2-D notebook input                         | Native          | Partial/incomplete  |
| `StandardForm`/`TraditionalForm` fidelity  | Canonical       | Approximate         |

The linear syntax is therefore one of Mathics' strongest areas. Its scanner explicitly contains Wolfram named-character, ASCII/Unicode operator, precedence, associativity and escape-sequence tables. ([GitHub][3])

### Where syntax compatibility starts breaking

The important qualification is that Mathematica has **two languages intertwined**:

```text
kernel expression language
        +
box / notebook representation language
```

A Mathematica notebook expression such as

```wl
SuperscriptBox["x", "2"]
```

is not merely pretty-printing trivia. Boxes, interpretation boxes, formatting rules, `MakeBoxes`, `TemplateBox`, `InterpretationBox`, held box structures, notebook expressions and the front end form another programmable system.

Mathics implements boxes and forms, but this is explicitly still an area under development. Its current roadmap calls out finishing boxing, `DisplayForm`, `MakeBoxes` conformance and notebook integration as unfinished work. ([GitHub][4])

So:

**plain `.wl` source:** often impressively portable.

**code manipulating boxes/notebooks:** much less portable.

---

# 2. The basic evaluation model is also the same

This is where the comparison becomes more interesting.

Both languages are fundamentally **term-rewriting evaluators**, rather than conventional eager function-call languages.

An expression

```wl
f[a, b]
```

is not intrinsically a call to a function named `f`. It is an expression whose head happens to be `f`. Definitions associated with `f`, `a`, `b`, their heads, and sometimes deeper components can cause transformations.

Both systems therefore implement concepts corresponding to:

```wl
OwnValues
DownValues
UpValues
SubValues
Attributes
Options
DefaultValues
FormatValues
```

Mathics' internal definitions object explicitly maintains OwnValues, DownValues, UpValues, SubValues and related rule collections. ([Mathics3 Developer Reference][5])

This is a major distinction from projects that merely translate Mathematica syntax to Python/SymPy.

## Mathematica's standard evaluation cycle

Very roughly, for

```wl
h[e1, e2, ...]
```

Mathematica does something like:

```text
evaluate the head h

inspect attributes of h

evaluate arguments as permitted by
    HoldFirst
    HoldRest
    HoldAll
    HoldAllComplete

splice Sequence[...] unless prevented

perform various canonicalizations implied by attributes

look for applicable definitions/rules

transform the expression

if it changed, start evaluation again
```

The official documentation explicitly says that whenever the expression changes, the standard evaluation sequence effectively starts over. ([Wolfram Documentation Center][6])

That restart property explains an enormous amount of Mathematica behavior.

Mathics uses essentially the same conceptual architecture: recursively evaluate expressions, inspect attributes, perform rewrites/function applications and repeat until stable. ([Mathics3 Developer Reference][7])

So this works for fundamentally the same reason in both:

```wl
f[x_] := x + 1
g[x_] := f[x]^2

g[4]
```

and gives

```wl
25
```

through repeated expression transformation rather than a conventional compiled call stack.

---

# 3. Attributes are central in both

Mathics understands many of Mathematica's evaluator attributes, including such essential ones as

```wl
Flat
Orderless
OneIdentity
Listable

HoldFirst
HoldRest
HoldAll
HoldAllComplete
SequenceHold

Protected
Locked
ReadProtected

NumericFunction
NHoldAll
NHoldFirst
NHoldRest
```

The conceptual purpose is the same.

For example:

```wl
SetAttributes[f, HoldAll]
```

changes the evaluator's treatment of

```wl
f[1 + 1]
```

rather than requiring `f` itself to implement some conventional “lazy argument” protocol.

Likewise `Flat`, `Orderless` and `OneIdentity` affect not only computation but **pattern matching**:

```wl
Attributes[Plus]
```

includes semantics which let patterns match an associative and commutative operation in ways impossible for an ordinary fixed-arity function.

This is exactly the kind of obscure WL behavior that is difficult to clone perfectly.

---

# 4. The biggest evaluator difference: holding and rewriting

There is a particularly important current incompatibility that Mathics' developers themselves identify.

In Mathematica, a hold attribute controls **evaluation/function application**, but it does not simply mean “do no rewriting anywhere inside this expression”.

For example, `HoldAll` is weaker than one might initially expect. Mathematica can still:

* splice `Sequence`;
* remove `Unevaluated`;
* use certain upvalues associated with held arguments.

`HoldAllComplete` is the much stronger barrier that suppresses these additional mechanisms. ([Wolfram Documentation Center][8])

Mathics' current 2026–27 roadmap explicitly says:

> WMA's `Hold` attributes limit function application, not rule rewrite. However, in Mathics3, that distinction is not made.

The developers consequently propose splitting rule rewriting from function application more cleanly inside the evaluator. ([GitHub][4])

That is not a cosmetic discrepancy. It can affect programs using combinations of

```wl
HoldAll
Evaluate
Unevaluated
With
Condition
UpValues
RuleDelayed
```

which is precisely where sophisticated Mathematica metaprogramming tends to live.

This is probably the single most important semantic caveat to remember when porting evaluator-heavy WL code to Mathics.

---

# 5. Pattern matching and definition dispatch

Both support the characteristic WL machinery:

```wl
f[x_] := ...
f[x_Integer] := ...
f[x_?Positive] := ...
f[x_ /; test[x]] := ...

x /: f[x] := ...
```

as well as constructs such as

```wl
Blank
BlankSequence
BlankNullSequence
Pattern
PatternTest
Condition
Alternatives
Optional
Repeated
RepeatedNull
OptionsPattern
```

Mathics goes much further than simple wildcard matching: its evaluator associates rule sets with OwnValues, DownValues, UpValues and SubValues, and performs Mathematica-style transformation-rule matching. ([Mathics3 Developer Reference][9])

But this is another place where perfect compatibility is extraordinarily difficult.

Mathematica has subtle rules concerning:

* ordering definitions by specificity;
* matching `Flat` and `Orderless` heads;
* `OneIdentity`;
* sequence blanks;
* optional arguments and defaults;
* conditions;
* upvalue search;
* interaction of evaluation with matching;
* lexical renaming inside delayed definitions.

Mathics has been actively fixing precisely this class of issues. Its roadmap says recent work made “rule selection for functions closer to WMA”, while listing efficient pattern matching and evaluator restructuring as remaining work. ([GitHub][4])

In other words, something as ordinary as

```wl
f[x_] := 1
f[x_Integer] := 2
```

is straightforwardly compatible.

Something like a package that exploits `Flat`, held arguments, sequence patterns, upvalues and conditional delayed rules as an internal DSL deserves compatibility testing.

---

# 6. `Set` versus `SetDelayed`

The conceptual semantics agree:

```wl
lhs = rhs
```

evaluates `rhs` now and stores the resulting definition, whereas

```wl
lhs := rhs
```

stores a delayed rule whose right side is evaluated when the definition fires.

Likewise Mathics supports up/down/subvalue assignment mechanisms such as the equivalents of

```wl
TagSet
TagSetDelayed
UpSet
UpSetDelayed
Unset
```

But assignment processing is another evaluator corner with historical compatibility fixes. The Mathics roadmap specifically mentions work on `UpSet`, `DownSet` and `SetDelayed` to better reproduce Mathematica behavior. ([GitHub][4])

---

# 7. Canonicalization is important

In both systems,

```wl
Plus
Times
```

are not ordinary binary operators.

Because of attributes such as

```wl
Flat
Orderless
OneIdentity
```

expressions are flattened and put into canonical order:

```wl
a + (b + c)
```

effectively becomes

```wl
Plus[a, b, c]
```

and argument order may be rearranged.

Similarly,

```wl
a b c
```

is represented as one `Times` expression rather than nested binary multiplications.

Mathics deliberately imitates this expression model.

That is one reason it can execute fairly sophisticated symbolic WL programs that would be painful to translate into an ordinary language.

---

# 8. Numerical semantics: similar interface, different engine

Here there is an architectural difference.

### Mathematica

Wolfram has its own implementations of:

```text
arbitrary precision arithmetic
special functions
polynomial algorithms
symbolic integration
equation solving
numerical integration
optimization
linear algebra
ODE/PDE solving
...
```

with many layers of algorithms accumulated over decades.

### Mathics

Mathics is written largely in Python and opportunistically uses the Python mathematical ecosystem, especially libraries such as:

```text
SymPy
mpmath
NumPy
SciPy
Pillow / scikit-image
```

depending on the operation. Its project describes itself as an open-source Mathematica kernel implemented on top of this ecosystem. ([GitHub][10])

This means two expressions can have identical front-end syntax:

```wl
Integrate[f[x], x]
NIntegrate[f[x], {x, a, b}]
Solve[eqn, x]
N[expr, 100]
```

while going through substantially different algorithms.

Consequently differences tend to appear in:

```text
branch choices
generated conditions
assumption handling
exact simplification
algebraic number representation
special-function reductions
precision tracking
convergence decisions
performance
```

rather than in basic notation.

---

# 9. Programming capabilities

This is where the breadth difference becomes obvious.

| Area                             | Mathematica/WL 15                          | Mathics3 10                               |
| -------------------------------- | ------------------------------------------ | ----------------------------------------- |
| Symbolic expression programming  | Extremely complete                         | Strong                                    |
| Pattern matching/rules           | Extremely complete                         | Strong, with corner incompatibilities     |
| Functional programming           | Extensive                                  | Good subset                               |
| Procedural programming           | Extensive                                  | Good subset                               |
| `Module`/`Block`/`With` scoping  | Complete                                   | Supported                                 |
| Attributes/evaluation control    | Complete                                   | Substantial, imperfect                    |
| Contexts/packages                | Complete                                   | Supported                                 |
| Lists                            | Very extensive                             | Strong                                    |
| Associations                     | Very extensive                             | Supported                                 |
| Strings/regex                    | Very extensive                             | Good subset                               |
| Options/default arguments        | Complete                                   | Supported                                 |
| Message system                   | Complete                                   | Supported subset                          |
| Streams/files/directories        | Extensive                                  | Substantial                               |
| `Import`/`Export` formats        | Hundreds of formats/features               | Much smaller subset                       |
| Binary data                      | Extensive                                  | Supported subset                          |
| Date/time                        | Extensive                                  | Supported subset                          |
| Compilation                      | Multiple mature compilation technologies   | Preliminary/limited                       |
| Debugging/tracing                | Mature introspection + FE facilities       | Basic plus Mathics-specific debugging     |
| Parallel computation             | Built in                                   | Very limited compared with WL             |
| Distributed computation          | Built in                                   | No comparable integrated subsystem        |
| GPU computation                  | Several facilities                         | No comparable integrated subsystem        |
| External-language integration    | Python, C, Java, .NET, R, SQL, etc.        | Python-centric implementation/integration |
| Notebook programming             | Extremely rich                             | Partial                                   |
| Dynamic UI                       | `Dynamic`, controls, notebook events, etc. | Much smaller                              |
| Cloud deployment                 | Integrated                                 | No comparable Wolfram Cloud system        |
| HTTP/API deployment              | Extensive                                  | Ordinary Python/web ecosystem instead     |
| Database/data-resource framework | Extensive                                  | Very limited                              |
| Knowledge/entity system          | Huge integrated system                     | Very small                                |
| Machine learning                 | Large integrated framework                 | No comparable framework                   |
| Neural networks                  | Large integrated framework                 | No comparable framework                   |
| LLM/AI programming               | Now large and integrated                   | No comparable subsystem                   |

The Mathics manual itself warns that Mathics does not yet provide the full range of Mathematica capabilities. Its reference is nevertheless fairly substantial: arithmetic, assignments, expression atoms, binary data, compilation, colors, date/time, statistics, filesystem operations, distances, graphics, evaluation control, boxing, expression manipulation and I/O all have dedicated sections. ([Mathics][11])

---

# 10. Mathematical capabilities

The same pattern occurs more strongly here.

| Mathematical area                   | Mathematica                              | Mathics3                                                 |
| ----------------------------------- | ---------------------------------------- | -------------------------------------------------------- |
| Integer/rational arithmetic         | Excellent                                | Excellent/basic operations                               |
| Arbitrary precision                 | Extremely mature                         | Supported via Python numerical stack                     |
| Complex arithmetic                  | Extensive                                | Supported                                                |
| Polynomial algebra                  | Very extensive                           | Good subset                                              |
| Factoring/expansion                 | Very extensive                           | Good                                                     |
| Rational functions                  | Very extensive                           | Good subset                                              |
| Algebraic numbers                   | Deep support                             | Considerably less complete                               |
| Groebner bases                      | Extensive                                | Some underlying SymPy capability / smaller interface     |
| Equation solving                    | `Solve`, `Reduce`, `Resolve`, etc.       | `Solve` and subset                                       |
| Inequalities/quantifier elimination | Very extensive                           | Much smaller                                             |
| Symbolic differentiation            | Excellent                                | Good                                                     |
| Symbolic integration                | Extremely extensive                      | `Integrate`, including Rubi work, but less complete      |
| Limits                              | Extensive                                | Supported                                                |
| Series                              | Extremely extensive                      | Supported                                                |
| Asymptotic analysis                 | Rich `Asymptotic*` framework             | Much smaller                                             |
| Numerical integration               | Industrial-strength                      | `NIntegrate` subset                                      |
| Root finding                        | Extensive                                | `FindRoot`                                               |
| Optimization                        | Very broad local/global/exact            | Smaller subset                                           |
| Linear algebra                      | Dense/sparse/symbolic/numeric            | Good basic subset                                        |
| Tensor algebra                      | Considerable                             | Basic tensor facilities                                  |
| Special functions                   | Huge                                     | Substantial subset                                       |
| Number theory                       | Huge                                     | Useful subset                                            |
| Combinatorics                       | Huge                                     | Useful subset                                            |
| Recurrences                         | Extensive                                | `RSolve`-style support                                   |
| Probability distributions           | Very large framework                     | Much smaller                                             |
| Statistics                          | Very large                               | Descriptive/basic subset                                 |
| ODEs                                | `DSolve`, `NDSolve`, etc.                | `DSolve`; much smaller numerically                       |
| PDEs                                | symbolic + numerical + FEM               | No comparable general PDE/FEM system                     |
| Integral transforms                 | Extensive                                | Partial                                                  |
| Discrete mathematics                | Extensive                                | Partial                                                  |
| Graph theory                        | Very extensive                           | Smaller, partly separate Mathics modules                 |
| Computational geometry              | Very extensive                           | Limited                                                  |
| Regions                             | Very extensive symbolic region framework | Limited                                                  |
| Control systems                     | Integrated                               | Essentially absent as comparable subsystem               |
| Signal processing                   | Extensive                                | Very limited                                             |
| Image processing                    | Extensive                                | Useful basic subset                                      |
| Audio                               | Extensive                                | No comparable subsystem                                  |
| Video                               | Extensive                                | No comparable subsystem                                  |
| Geospatial computation              | Extensive                                | No comparable subsystem                                  |
| Computational chemistry             | Extensive                                | Small data/functions subset                              |
| Units/quantities                    | Extensive                                | Basic quantity support                                   |
| Finite-element methods              | Extensive                                | No comparable subsystem                                  |
| Machine-learning mathematics        | Extensive                                | Mostly delegated to Python rather than WL-compatible API |

For scale, modern Wolfram Language encompasses graph computation, PDEs, image/audio/video processing, neural networks, statistics, optimization, regions and much more as parts of the same expression language. ([Wolfram Documentation Center][12])

Mathics' source layout shows that its implemented subset is nevertheless much broader than a toy CAS: it contains modules for arithmetic, assumptions, matrices, numerical operations, optimization, statistics, special functions, tensors, quantities, graphics, images, recurrence equations, patterns, functional/procedural programming and so forth. ([GitHub][13])

---

# 11. Symbol-count comparison

This gives perhaps the clearest numerical measure.

The current Wolfram documentation says:

> “The Wolfram Language has over 7000 built-in functions and other objects”

and provides the official alphabetical index. ([Wolfram Documentation Center][14])

Mathics keeps a particularly useful machine-readable file:

```text
SYMBOLS_MANIFEST.txt
```

in `mathics-core`. The current manifest contains about **1,345 registered names**, roughly **1,330 under `System`` and `System`` subcontexts**. ([GitHub][15])

So, very approximately,

$$
\frac{1330}{7000}<19.1\%.
$$

But **“19% compatible” would be misleading** for three reasons.

First, Wolfram's 7,000+ number refers to documented built-in functions and other public objects, whereas the Mathics manifest also contains implementation and compatibility names.

Second, one name is not one unit of capability. `NDSolve`, `Reduce`, `Integrate`, `EntityValue` or `NetTrain` can each represent an enormous subsystem.

Third, Mathics sometimes implements only a subset of the Mathematica options/cases for a shared symbol.

So symbol count is useful as a rough measure of library surface, not semantic coverage.

---

# 12. What the intersection looks like

The shared part contains much of the “classic Mathematica kernel”.

Representative shared families include constructs equivalent to:

```wl
(* arithmetic *)
Plus
Times
Power
Abs
Sqrt
Exp
Log
Sin
Cos

(* definitions *)
Set
SetDelayed
Unset
Clear
ClearAll
Attributes

(* patterns/rules *)
Blank
Pattern
Condition
PatternTest
Rule
RuleDelayed
Replace
ReplaceAll

(* structural *)
Head
Part
Length
Map
Apply
Cases
Select
Flatten

(* functional *)
Function
Map
Fold
Nest
FixedPoint

(* scoping/control *)
Module
Block
With
If
Which
Do
While
For

(* algebra/calculus *)
Expand
Factor
Apart
Simplify
Solve
D
Integrate
NIntegrate
Limit
Series
DSolve

(* numerics *)
N
FindRoot

(* linear algebra *)
Dot
Det
Inverse
Eigenvalues
LinearSolve

(* graphics *)
Graphics
Plot
Plot3D
ListPlot

(* system/I/O *)
Import
Export
Get
Put
OpenRead
Read
Write
```

That explains why programs from the older, kernel-centric Mathematica literature can work surprisingly well in Mathics.

Indeed, the Mathics documentation recommends traditional Mathematica programming material precisely because the fundamental programming model is so close. ([Mathics][16])

---

# 13. Mathics has a few symbols of its own

Its namespace is not simply a strict subset.

The manifest contains Mathics/Python-specific facilities such as

```wl
MathicsVersion
PythonForm
$PythonImplementation
$TraceBuiltins
$TraceEvaluation
$TrackLocations
```

and other implementation/debugging facilities that naturally have no exact reason to exist in Mathematica. ([GitHub][15])

So conceptually the relation is more like

$$
\text{Mathics}
=
\text{large subset of WL}
+\text{Mathics-specific extensions}
+\text{some intentionally different internals}.
$$

---

# 14. The Mathematica-only part is enormous

The biggest portions of the 7,000+ symbol set with no comparable Mathics implementation are not obscure aliases. They encompass whole platforms.

Modern Mathematica has large families around, for example,

```text
Audio*
Video*
Image*
Geo*
Astro*
Entity*
Graph*
Net*
Classify / Predict
PDEComponent*
NDSolve*
FiniteElement*
Cloud*
APIFunction
Databin / DataRepository-style functionality
neural networks
control systems
signal processing
system modeling
knowledgebase queries
LLM integration
```

The current alphabetical index begins with things as diverse as `AASTriangle`, `AstroGraphics`, etc., illustrating how far Mathematica has expanded beyond symbolic mathematics. ([Wolfram Documentation Center][14])

This is why the raw built-in-count gap is so large even though the **core language** can feel much closer than 19%.

---

# 15. An interesting way to divide Wolfram Language

I would divide the compatibility surface into three concentric layers.

| Layer                         | Examples                                                                                | Mathics compatibility                     |
| ----------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Language kernel**           | expressions, lists, patterns, rules, assignments, functions, scoping                    | **High**                                  |
| **Classical CAS Mathematica** | algebra, calculus, special functions, matrices, plotting                                | **Medium**, varying strongly by operation |
| **Modern Wolfram platform**   | PDE/FEM, ML, neural nets, entities, geo, audio/video, cloud, notebooks, system modeling | **Low to essentially absent**             |

This is a more useful characterization than saying “Mathics implements 19% of Mathematica.”

For a language implementation project, the first layer is by far the most interesting: Mathics has reproduced enough of Mathematica's evaluator architecture that it can actually execute WL programs rather than merely imitate mathematical commands.

---

# 16. Where seemingly portable programs are most likely to fail

If I were trying to run an existing Mathematica package under Mathics, I would regard these as the danger zones:

1. evaluator tricks involving `Hold*`, `Evaluate`, `Unevaluated`, upvalues and conditions;
2. sophisticated `Flat`/`Orderless`/sequence pattern matching;
3. exact definition ordering and dispatch;
4. assumptions, branch cuts and algebraic simplification;
5. arbitrary-precision numerical algorithms;
6. complicated `Integrate`, `Solve`, `Reduce`, `DSolve` and special-function work;
7. `MakeBoxes` and custom formatting;
8. notebook/front-end programming;
9. modern domain-specific APIs;
10. performance-sensitive symbolic programs.

The first few are more interesting than simply “symbol not implemented”, because the code may parse perfectly and run almost correctly before producing a subtly different result. Mathics' own current roadmap specifically identifies evaluator, pattern-matching, boxes and plotting work as continuing architectural projects. ([GitHub][4])

---

## One subtle but important conclusion

The difference between Mathematica and Mathics is **much smaller at the language-design level than at the library/implementation level**.

If one stripped Mathematica down to something resembling the kernel of Mathematica 2–5—expression trees, patterns, rules, symbolic arithmetic, basic calculus, matrices, lists, procedural/functional programming and graphics—the comparison would be fairly close.

But today's Wolfram Language has grown into a 7,000+-symbol computational platform. Mathics has deliberately concentrated on reproducing the *language substrate* plus a useful classical-CAS subset. That makes its roughly 1,330 `System`` symbols more capable than their raw 19% count suggests, while still leaving an enormous gap in total functionality.

And the deepest remaining compatibility problem isn't parsing `x /. a_ -> f[a]`; Mathics already handles that sort of thing. It's reproducing all the pathological consequences of Mathematica's evaluator—**holding, rule rewriting, upvalues, pattern specificity, attributes, sequence handling, and repeated evaluation—with bug-for-bug-quality fidelity**. The Mathics developers clearly recognize this: their 2026 roadmap explicitly proposes architectural evaluator changes rather than merely adding another batch of functions. ([GitHub][4])


[1]: https://www.wolfram.com/mathematica/quick-revision-history/?utm_source=chatgpt.com "Mathematica Latest Version and Quick Revision History"
[2]: https://mathics-development-guide.readthedocs.io/en/latest/code-overview/parsing/overview.html?utm_source=chatgpt.com "Parsing Overview — Mathics3 1.1.0 documentation"
[3]: https://github.com/Mathics3/Mathics3-scanner?utm_source=chatgpt.com "GitHub - Mathics3/Mathics3-scanner: Tokenizer, and operator and character tables, and conversion routines for the Wolfram Language. · GitHub"
[4]: https://github.com/Mathics3/mathics-core/blob/master/FUTURE.rst?utm_source=chatgpt.com "mathics-core/FUTURE.rst at master · Mathics3/mathics-core · GitHub"
[5]: https://mathics-development-guide.readthedocs.io/en/latest/code-overview/object-classes.html?utm_source=chatgpt.com "Object Classes — Mathics3 1.1.0 documentation"
[6]: https://reference.wolfram.com/language/tutorial/Evaluation.html.en?utm_source=chatgpt.com "Evaluation—Wolfram Documentation"
[7]: https://mathics-development-guide.readthedocs.io/en/add-more-info-on-scanning/code-overview/evaluation.html?utm_source=chatgpt.com "Evaluation of an Expression — Mathics 1.1.0 documentation"
[8]: https://reference.wolfram.com/language/tutorial/EvaluationOfExpressions?utm_source=chatgpt.com "Evaluation of Expressions—Wolfram Documentation"
[9]: https://mathics-development-guide.readthedocs.io/en/latest/code-overview/pattern-matching.html?utm_source=chatgpt.com "Pattern Matching in Evaluation — Mathics3 1.1.0 documentation"
[10]: https://github.com/Mathics3/mathics-core?utm_source=chatgpt.com "GitHub - Mathics3/mathics-core: An open-source Mathematica Kernel. This repository contains the Python modules for WL Built-in functions, variables, core primitives, e.g. Symbol, a parser to create Expressions, and an evaluator to execute them. · GitHub"
[11]: https://mathics.org/docs/mathics3-latest.pdf?utm_source=chatgpt.com "Contents

I. Manual 5  
1\. Introduction 6  
2\. Lan"
[12]: https://reference.wolfram.com/language/guide/SummaryOfNewFeaturesIn11.html?utm_source=chatgpt.com "Summary of New Features in 11—Wolfram Documentation"
[13]: https://github.com/Mathics3/mathics-core/tree/master/mathics/builtin "mathics-core/mathics/builtin at master · Mathics3/mathics-core · GitHub"
[14]: https://reference.wolfram.com/language/guide/AlphabeticalListing?utm_source=chatgpt.com "Alphabetical Listing—Wolfram Documentation"
[15]: https://github.com/Mathics3/mathics-core/blob/master/SYMBOLS_MANIFEST.txt?utm_source=chatgpt.com "mathics-core/SYMBOLS_MANIFEST.txt at master · Mathics3/mathics-core · GitHub"
[16]: https://mathics.org/docs/mathics-latest.pdf?utm_source=chatgpt.com "2. Language Tutorial"
