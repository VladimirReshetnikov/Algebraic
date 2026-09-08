#!/usr/bin/env python3
"""Lexical delimiter/comment/string check, NOT a Wolfram parser or evaluator."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[1]
def check(path):
    text = path.read_text()
    stack = []; comment = 0; string = False; i = 0
    matching = {']':'[', ')':'(', '}':'{'}
    while i < len(text):
        two = text[i:i+2]
        if comment:
            if two == '(*': comment += 1; i += 2; continue
            if two == '*)': comment -= 1; i += 2; continue
            i += 1; continue
        if string:
            if text[i] == '\\': i += 2; continue
            if text[i] == '"': string = False
            i += 1; continue
        if two == '(*': comment = 1; i += 2; continue
        ch = text[i]
        if ch == '"': string = True
        elif ch in '([{': stack.append((ch, i))
        elif ch in ')]}':
            assert stack and stack[-1][0] == matching[ch], (path, i)
            stack.pop()
        i += 1
    assert not stack and not comment and not string, path
    return str(path.relative_to(root))
paths = sorted(p for p in root.rglob('*') if p.suffix in {'.wl','.wls','.wlt','.m'})
report = {'status':'PASS', 'scope':'Lexical delimiter/comment/string check only',
          'files':[check(p) for p in paths]}
print(json.dumps(report,indent=2))
(root/'validation'/'wl_structure_results.json').write_text(json.dumps(report,indent=2)+'\n')
