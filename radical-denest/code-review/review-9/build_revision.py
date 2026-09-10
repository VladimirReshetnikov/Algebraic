#!/usr/bin/env python3
"""Rebuild the standalone revision, rejecting any unreviewed baseline."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parent
BASE_SHA = '0bdeded347385a55a044fdd35883006d053685dc'
base = (ROOT / 'StradFixed2.original.wl').read_bytes()
actual = hashlib.sha1(b'blob ' + str(len(base)).encode() + b'\0' + base).hexdigest()
if actual != BASE_SHA:
    raise SystemExit(f'Wrong baseline Git blob: {actual}; expected {BASE_SHA}')
s = base.decode('utf-8')

def replace(old: str, new: str, count: int = 1) -> None:
    global s
    n = s.count(old)
    if n != count:
        raise RuntimeError(f'Patch anchor occurred {n}, expected {count}: {old[:100]!r}')
    s = s.replace(old, new)

# Change the context, retaining all unaffected algorithms and public entry points.
s = s.replace('RadicalDenest2', 'RadicalDenest3')
s = s.replace('StradFixed2.wl -- second corrected version', 'StradFixed3.wl -- proposed third corrected version')
# The replacement header and article supersede the historical contract.
start, stop = s.index('(* StradFixed3.wl'), s.index('BeginPackage[')
s = s[:start] + '''(* StradFixed3.wl -- proposed research revision, September 2026.
   Baseline: Git blob 0bdeded347385a55a044fdd35883006d053685dc.
   See README.md and the accompanying review for scope and validation status.
   Every accepted proposal must be a cheaper explicit radical and pass exact
   algebraic equality against its original target. Root admission is deliberately
   conservative. Resource limits are cooperative kernel limits, not process-level
   wall-clock/RSS guarantees. Input evaluation and option resolution precede them.
   No completeness, minimum-depth, or native-regression-pass claim is made.
   The original algorithm is retained; changes are reproducibly applied by
   build_revision.py plus revision_definitions.wl. Context: RadicalDenest3`. *)

''' + s[stop:]
replace('"NumericPrefilter" -> True, "MaxTraceEntries" -> 200};',
        '"NumericPrefilter" -> False, "MaxTraceEntries" -> 200,\n   "MaxCharacterRank" -> 2, "MaxCharacterPatterns" -> 8,\n   "MaxOddIndex" -> 7, "DiscriminantBatchCap" -> 24};')
replace('"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience"',
        '"MaxTrials", "MultiplierCap", "MaxTraceEntries", "MaxRecursion", "Patience",\n       "MaxCharacterRank", "MaxCharacterPatterns", "DiscriminantBatchCap"')
replace('"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount", "MaxPasses"',
        '"MemoryBudget", "MaxRootIndex", "MaxDegree", "MaxSolveDegree", "MaxLeafCount", "MaxPasses", "MaxOddIndex"')
replace('If[cfg["MaxSolveDegree"] > 4, AppendTo[bad, "MaxSolveDegree"]];',
        'If[cfg["MaxSolveDegree"] > 4, AppendTo[bad, "MaxSolveDegree"]];\n   If[cfg["MaxCharacterRank"] > 4, AppendTo[bad, "MaxCharacterRank"]];')
replace('primes = Union @@ (First /@ FactorInteger[#] & /@ surds);',
        'primes = bounded[Union @@ (First /@ FactorInteger[#] & /@ surds)];\n   If[primes === $Failed, Return[{}]];')
replace('sq = Expand[cand^2];', 'sq = bounded[Expand[cand^2]];\n    If[sq === $Failed, Continue[]];')
replace('Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]];',
        'bounded[Together[-Coefficient[f, $x, 0]/Coefficient[f, $x, 1]]]];')
replace('primes = Take[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], UpTo[8]];',
        'primes = bounded[Take[Select[First /@ FactorInteger[Abs[disc]], PrimeQ], UpTo[8]]];\n      If[primes === $Failed, primes = {}];')
replace('batch >= 24', 'batch >= $cfg["DiscriminantBatchCap"]')
replace('batch < 24', 'batch < $cfg["DiscriminantBatchCap"]')
replace('Do[batch++; admit[m prime^e], {e, 1, q - 1}], {prime, primes}];',
        '''Do[If[admitted >= cap || proposed >= proposalCap ||
          batch >= $cfg["DiscriminantBatchCap"] || expiredQ[], Break[]];
        batch++; admit[m prime^e], {e, 1, q - 1}], {prime, primes}];''')
replace('If[candidate === $Failed || ! exactQ[candidate], Return[best]];',
        'If[candidate === $Failed || ! smallQ[candidate] || ! exactQ[candidate], Return[best]];')
replace('vars = Array[cvar, Length[U]];',
        'vars = Table[Unique["surdCoefficient"], {Length[U]}];')
# Definitions below replace entire targeted functions; remove their originals.
# Removing avoids stale overloads and makes the generated source reviewable.
for name, next_anchor in [
    ('algebraicFormQ[e_]', '(* exactness is decided'),
    ('radicalNodes[e_]', 'cheaperQ[new_'),
    ('canonicalNonzeroQ[e_]', 'SetAttributes[standalone'),
    ('kummerCandidates[target_', '(* ------------------------------------------------------------------ *)\n(* the multiplier search'),
    ('rootCandidates[rho_', '(* ------------------------------------------------------------------ *)\n(* Kummer-linear'),
    ('powerProposals[target_', '(* the multiplier search is meant'),
    ('improveNumber[target_', '(* an exact algebraic island'),
    ('run[e_, cfg_Association', 'invoke[e_, head_Symbol')
]:
    a=s.index(name); b=s.index(next_anchor,a)
    s=s[:a]+s[b:]
replace('$recursion = 0, $Assumptions = True},',
        '$recursion = 0, $inProgress = <||>, $lastCertificateMethod = "None", $Assumptions = True},')
replace('"After" -> candidate, "Method" -> method|>',
        '"After" -> candidate, "Method" -> method, "EqualityMethod" -> $lastCertificateMethod|>')
# Broaden option-tail matching so malformed options reach the validator.
s=s.replace('opts : OptionsPattern[]','opts___')
# Define every replacement while still inside the package private context.
replace('End[];\nEndPackage[];',
        (ROOT / 'revision_definitions.wl').read_text(encoding='utf-8') + '\nEnd[];\nEndPackage[];')
(ROOT / 'StradFixed3.wl').write_text(s,encoding='utf-8')
print(f'Built StradFixed3.wl ({len(s.encode())} bytes) from verified baseline {BASE_SHA}')
