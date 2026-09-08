#!/usr/bin/env python3
"""Lexical delimiter/comment/string check; NOT a Wolfram parser or evaluator."""
from pathlib import Path
import json
import re
root=Path(__file__).resolve().parents[1]
results=[]
for f in sorted(list(root.rglob('*.wl'))+list(root.rglob('*.wls'))+list(root.rglob('*.wlt'))+list(root.rglob('*.m'))):
    s=f.read_text(); stack=[]; comment=0; string=False; i=0; code=[]
    while i<len(s):
        two=s[i:i+2]; c=s[i]
        if string:
            if c=='\\': i+=2; continue
            if c=='"': string=False
            i+=1;continue
        if comment:
            if two=='(*':comment+=1;i+=2;continue
            if two=='*)':comment-=1;i+=2;continue
            i+=1;continue
        if two=='(*':comment=1;i+=2;continue
        if c=='"':string=True;code.append('""');i+=1;continue
        if c in '[{(' : stack.append((c,i))
        elif c in ']})':
            assert stack and stack[-1][0] == {']':'[','}':'{',')':'('}[c], (f,i,stack[-3:])
            stack.pop()
        code.append(c);i+=1
    assert not stack and not comment and not string,(f,stack,comment,string)
    forbidden=[]
    if f.name=='AlgebraicDecomposition.wl':
        forbidden=re.findall(r'\b(?:Factor|Solve|Decompose|N|Chop|PossibleZeroQ|Rationalize|RootApproximant)\s*\[',''.join(code))
        assert not forbidden
    results.append({'file':str(f.relative_to(root)), 'balanced':True})
report={'status':'passed','scope':'Only lexical delimiters, strings, comments and forbidden core function calls; not syntax or runtime validation.','files':results}
(root/'validation'/'wl_static_results.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
