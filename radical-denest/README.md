# RadicalDenest

Analysis, correction and literature survey of `Strad.wl`, a Wolfram Language
program that denests radicals: it rewrites an expression such as
`Sqrt[5 + 2 Sqrt[6]]` as `Sqrt[2] + Sqrt[3]`, or `(2^(1/3) - 1)^(1/3)` as
`(1 - 2^(1/3) + 4^(1/3))/9^(1/3)`, whenever an expression with fewer nested
root extractions exists and can be found.

The repository has three parts: the program and its corrected versions
(`src/`), three rounds of code review with kernel experiments
(`src/code-review/`), and a research guide to the mathematical and
computer-algebra literature on radical denesting together with the freely
available sources themselves (`docs/`).

## Layout

```
.
├── LICENSE                       MIT-0
├── README.md                     this file (AGENTS.md and CLAUDE.md are symlinks to it)
├── src/
│   ├── original/Strad.wl         the program under review, unchanged (585 lines)
│   ├── corrected/
│   │   ├── StradFixed.wl         first corrected version (context RadicalDenest`)
│   │   ├── StradFixed2.wl        second corrected version (context RadicalDenest2`)
│   │   ├── StradFixed3.wl        third corrected version, current (context RadicalDenest3`)
│   │   └── KNOWN_GAPS.md         inputs the first version misses; all handled by the later ones
│   └── code-review/
│       ├── unified-A/            first round: analysis of Strad.wl from three reviews of it
│       │                         (those reviews are no longer in the repository), kernel
│       │                         experiments, and StradFixed.wl
│       ├── unified-B/            second round: three reviews of StradFixed.wl (review-4/5/6,
│       │                         no longer in the repository) compared and consolidated,
│       │                         StradFixed2.wl designed and evaluated, regression suite
│       ├── review-7/             three independent reviews of StradFixed2.wl, each with a
│       ├── review-8/             report (PDF + LaTeX), a proposed StradFixed3.wl, a native
│       ├── review-9/             test suite and SymPy checks
│       └── unified-C/            third round: the three reviews compared and consolidated,
│                                 StradFixed3.wl designed and evaluated, regression suite
└── docs/
    ├── report/                   unified research guide to the denesting literature
    ├── literature/               downloaded papers, theses, documentation, web resources
    └── scripts/                  the download tooling that produced docs/literature
```

## The program and its corrections (`src/`)

`src/original/Strad.wl` is the input to the whole project. Its architecture is
a marker wrapper around radicals, a multiplier search using minimal polynomials
and polynomial GCDs over algebraic extensions, a roots-of-unity orbit over the
candidates, and a final numerical check. The first round of review found
defects in each stage: loss of the principal branch when a power is
re-extracted, branch-unsafe power identities, results accepted on the strength
of `PossibleZeroQ` "assuming zero" messages, a comparator that reverses lists,
unbounded searches, and silent failures on symbolic input.

`src/corrected/StradFixed.wl` kept the architecture but certified every result
against the input by exact algebra. Three further reviews and a probing session
then found that its certification did not cover a user-supplied solver in a
symbolic host, that its budgets did not bound whole calls, that its option
defaults were not propagated, that its multiplier cap leaked, and that fifteen
denestable inputs were left unchanged.

`src/corrected/StradFixed2.wl` (second version) puts one acceptance
gate in front of every candidate, runs each call inside one time and memory
region with every expensive kernel operation bounded, resolves and validates
options once, replaces the marker wrapper and the custom factorizer by a
congruence walk over arithmetic hosts, adds exact fast paths (direct, indirect,
Gaussian, cubic-in-quadratic, Honsbeek, multi-surd), separates the phase of
negative radicands, uses the linear factors of `x^k - rho` for Kummer roots and
index reduction, bounds the multiplier queue at a single admission point, and
returns structured reports. Three further reviews then found that its
admission test accepted non-algebraic `Root` objects, that a numeric prefilter
could decide its public equality status, that two proposal stages could discard
a better incumbent, that index reductions depended on recursive progress, that
failed searches were memoized without their budget, and that its multi-surd
solver missed the square-class cosets.

`src/corrected/StradFixed3.wl` is the current version. It validates `Root` and
`AlgebraicNumber` payloads, classifies equality by exact algebra only, threads
incumbents through every stage, offers index reductions before recursion, keeps
a budget-aware memo, runs every kernel operation and the report costs inside
the resource region, rejects malformed calls, and adds three coverage
extensions: the trace–norm criterion for every odd index up to a bound, a
Honsbeek recognizer for every term with a rational cube, and a square-class
coset search (integer relations, then rational systems) for multi-surd square
roots. See `src/corrected/README.md` for usage and the option list.

## The code reviews (`src/code-review/`)

`unified-A/unified_analysis.pdf` (first round) compares three reviews of the
original program, reconstructs the algorithm, proves the supporting
mathematics, executes the program and the reviews' test suites in Wolfram
15.0.1, catalogues 27 defects with evidence, presents `StradFixed.wl` and
evaluates it on the same battery, and lists future improvements. Its harness,
logs and generated tables are alongside; its Section 5.7 records the probing
session that produced `KNOWN_GAPS.md`.

`unified-B/unified_analysis_B.pdf` (second round) compares and assesses three
independent reviews of `StradFixed.wl` (`review-4`, `review-5`, `review-6`,
since removed from the repository; each had a report, a proposed replacement
`StradImproved.wl`, a native test suite its author could not run, and executed
SymPy checks), consolidates their findings with the probing results into a
catalogue of 23 issues, presents the design of `StradFixed2.wl` with the
mathematics of its new fast paths, reruns the first-round battery and
randomized families on it, reruns the probing scripts (all fifteen misses now
denested), runs a 144-test regression suite that translates the three reviews'
suites, and runs the reviews' own suites against their own proposals. Everything
is reproducible from `unified-B/harness/` and recorded in `unified-B/logs/`.

`review-7`, `review-8` and `review-9` are three independent reviews of
`StradFixed2.wl` at commit `9000d6f`. Each contains a report, a proposed
`StradFixed3.wl` in the context `RadicalDenest3\``, a native test suite that
its author could not run, and executed SymPy checks.

`unified-C/unified_analysis_C.pdf` (third round) compares and assesses those
three reviews, runs their probes against `StradFixed2.wl`, consolidates their
findings into a catalogue of 22 issues, presents the design changes of
`StradFixed3.wl` with the mathematics of its coverage extensions, reruns the
battery and randomized families on both versions side by side, reruns the
probing scripts, runs a 230-test regression suite that adds the translated
suites of the three reviews, runs the reviews' own suites against their own
proposals, and runs review-8's differential corpus. Everything is reproducible
from `unified-C/harness/` and recorded in `unified-C/logs/`.

## The literature (`docs/`)

`docs/report/radical_denesting_unified.pdf` is *Radical Denesting: A Unified
Research Guide* (48 pages, 103 annotated bibliography entries). It was built by
consolidating four AI-generated research reports and then merging the three
unified syntheses that had been prepared from them. It covers the classical
square-root theory with proofs, Ramanujan's identities, the precise
higher-index criteria of Honsbeek and the cubic-in-quadratic test, the
algorithmic literature from Caviness–Fateman and Zippel through Borodin–Fagin–
Hopcroft–Tompa, Landau, Blömer, Horng–Huang and Cotner, field theory and
complexity models, equality testing, the actual contracts of the denesters in
SymPy, Maxima, Wolfram Language, Maple, SageMath, PARI/GP and FLINT/Calcium,
infinite radicals, a correction ledger, and reading paths. `docs/report/verify.py`
runs 59 exact SymPy checks of the identities used; its transcript and JSON
record sit beside it. The typography follows the ProveIt
`Analysis/FabiusFunction/docs` house style, as do the second- and third-round reports.

`docs/literature/` is the dataset of freely available sources cited in the
guide: 102 assets (54 PDFs, 49 TeX sources) covering 66 works, arranged as
`papers/<record>/` and `web_resources/<record>/`, with `download_manifest.json`
as the authoritative index (per-file SHA-256, origin URL, retrieval method,
evidence level). Six articles that existed only as poor scans also have
corrected re-typesettings under `retypeset-2026/`; `RETYPESET_ARTICLES.md`
describes them. Twenty-six planned assets could not be retrieved
(paywalls, bot blocks, dead hosts); the manifest lists them.

`docs/scripts/` contains the three independently written download packages
that were compared, the one that was selected and corrected
(`radical_literature_retrieval_package`), its helper scripts for supplementary
routes and manually obtained files, and a README recording the comparison, the
corrections and the outcome of both download passes.

## Requirements

- Wolfram Language 15 with `wolframscript` for the program and the harnesses.
  A single-seat license allows one kernel at a time; the harness scripts run
  sequentially.
- A TeX distribution with `pdflatex` (MiKTeX and TeX Live both work) for the
  reports. The research guide and the second- and third-round reports use the
  Libertinus fonts and fall back to Latin Modern if they are absent.
- Python 3.10+ with SymPy for `docs/report/verify.py` and the reviews' checks,
  and for the download scripts (which need no third-party packages).

## Conventions

Line endings are LF (`.gitattributes`, `.editorconfig`); PDFs and images are
binary. Log files are ignored by git, so recorded transcripts are stored with a
`.txt` extension. Everything is released under the MIT-0 license (`LICENSE`).
