"""Build the article's table from the actual committed validation records."""
from pathlib import Path
import json,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
LABELS={
 'question-sextic':r'Original sextic, $i=1$',
 'question-quintic':r'Original quintic, $i=4$',
 'nonsolvable-quintic':r'$x^5-x-1$, $i=0$',
 'general-quadratic':r'$x^2-2$, $i=1$',
 'general-cubic':r'$x^3-2$, $i=0$',
 'general-binomial-quartic':r'$x^4-2$, $i=1$',
 'general-cyclotomic-8':r'$x^4+1$, $i=0$',
 'general-cyclotomic-5':r'$\Phi_5(x)$, $i=0$',
 'notebook-octic-A':r'Notebook octic $A$, $i=0$',
 'notebook-octic-B':r'Notebook octic $B$, $i=0$',
 'notebook-octic-C':r'Notebook octic $C$, $i=0$',
 'automatic-binomial-quintic':r'$x^5-2$ (automatic), $i=0$',
 'general-binomial-quintic':r'$x^5-2$ (forced), $i=0$',
}
METHODS={'reciprocal':'Reciprocal','Dickson':'Dickson','SymPy-Galois':'Galois test',
 'Galois-Kummer':'General','shifted-power':'Power','pair-resolvent':'Pair resolvent','':'General'}
if __name__=='__main__':
    bench=json.loads((ROOT/'validation/benchmark.json').read_text())
    suite=ET.parse(ROOT/'validation/pytest.xml').getroot().find('testsuite')
    total=int(suite.attrib['tests']);bad=int(suite.attrib.get('failures',0))+int(suite.attrib.get('errors',0))
    skipped=int(suite.attrib.get('skipped',0));passed=total-bad-skipped
    elapsed=float(suite.attrib['time'])
    lines=[r'\paragraph{Recorded Python test run.}',
      f'{passed} passed, {bad} failures or errors, {skipped} skipped; '
      f'{elapsed:.2f} seconds in the recorded run. The test suite and machine-readable '
      r'JUnit record are included in the archive.',
      r'\begin{table}[htbp]',r'\centering\small',
      r'\begin{tabularx}{\textwidth}{@{}X l l r r@{}}',r'\toprule',
      r'Input and Python index & Path & Status & $D$ & Seconds\\',r'\midrule']
    for c in bench['cases']:
        label=LABELS[c['name']];method=METHODS.get(c['method'],c['method'])
        status={'Success':'Success','NotSolvable':'Not solvable','Inconclusive':'Inconclusive'}[c['status']]
        lines.append(f"{label} & {method} & {status} & {c.get('field_degree','--')} & {c['elapsed_seconds']:.2f}\\\\")
    lines += [r'\bottomrule',r'\end{tabularx}',
      r'\caption{Recorded bounded runs. $D=[E:\Q]$ is shown only when the general field was constructed. Indices are zero-based SymPy indices. The last row reached its 30-second limit; no nonsolvability conclusion follows.}',
      r'\label{tab:benchmark}',r'\end{table}']
    (ROOT/'article/validation-table.tex').write_text('\n'.join(lines)+'\n')
    print(f'Built validation table: {passed} passed / {total}; {len(bench["cases"])} benchmark cases.')
