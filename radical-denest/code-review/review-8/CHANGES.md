# Implementation map: StradFixed2 → proposed StradFixed3

This is a derivative, not a byte-identical patch, and native validation remains outstanding.

| Finding | Main implementation sites | Change |
|---|---|---|
| F01 | `ordinaryRootQ`, `closedCanonicalQ`, `opaqueExactQ`, `exactQ` | Check rational defining data or bounded checked canonicalization; cache only positive type recognition. |
| F02 | `powerProposals`, `negativeRadicandCandidate`, `kummerCandidates` | Thread incumbent through every stage; unsuccessful stages preserve it. |
| F03 | `kummerCandidates`, even-index path | Offer raw residual candidates before recursion and use the full cost gate. |
| F04 | `improveNumber`, `recurse`, `$memo`, `$inProgress`, `$trialUse` | Positive-only result cache, active-call guard, shared per-target trial accounting. |
| F05 | `certify`, `numericallyDifferentQ`, `accept` | Exact public statuses; numerical search rejection has its own counter and cannot certify inequality. |
| F06 | `bounded`, `run`, factorization and polynomial helpers | Wider budget scope; heavy calls wrapped; known degree checked early; missing costs allowed after interruption. |
| F07 | `squarefreeData`, `surdSystem`, `cosetBases`, `multiSurdSquareRoots` | Optional square-class-coset search; rational coefficient arithmetic instead of expanded radical coefficient extraction. |
| F08 | `honsbeekSquareRoots` | Recognize rational cubes of exact terms, including rational summands; offer both signs for nonzero denominator. |
| F09 | `quadraticOddRoots` | Trace/norm reconstruction for bounded odd indices using Dickson recurrences. |
| F10 | `progressQ` | Optional independent-list progress; global policy retained by default. |
| F11 | `run`, `walk` | Optional exact-island processing in mixed hosts; approximate leaves unchanged. |
| F12 | multiplier admission/queue | Expression keys, optional canonicalization, explicit selected nonzero checks, inner-batch clipping. |
| F13 | `accept`, `trace`, `run` | Separate candidate and committed-pass journals; scope/truncation metadata; result-change flag separate from termination status. |
| F14 | `resolveOptions`, `invoke`, public definitions | Validate malformed argument sequences and missing input; resolve each public head's defaults. |

## Deliberately retained

Local exact acceptance, branch-sensitive principal-value checks, assumption isolation, direct/indirect quadratic paths, Gaussian roots, cubic trace/norm reconstruction, Honsbeek quartic construction, linear-factor and residual-index search, degree-four polynomial-GCD reconstruction, Horner rationalization, shared time controls, centralized multiplier admission, and bounded repeated passes.

The new package context is ``RadicalDenest3` ``. Loading it does not overwrite ``RadicalDenest2` ``.

## Tradeoffs

Positive-only caching may repeat failed work. Exact public inequality classification may be slower than heuristic rejection. Strict type recognition can return a conservative False for unsupported algebraic presentations. Canonical multiplier keys can cost more than they save. Coset enumeration and rational solving remain bounded, and default coset search is disabled. Independent-list mode deliberately differs from the global cost policy. No performance advantage is claimed without native benchmarks.
