#!/usr/bin/env python3
"""Basic lexical/packaging checks only. NOT a Wolfram parser or evaluator."""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OPEN = {'[': ']', '{': '}', '(': ')', '<|': '|>'}
CLOSE = set(OPEN.values())
LOOPS = {'Do', 'For', 'While', 'Table'}

def tokens(text: str):
    """Skip nested WL comments and honor escaped string characters."""
    i, line = 0, 1
    while i < len(text):
        if text[i].isspace():
            line += text[i] == '\n'; i += 1; continue
        if text.startswith('(*', i):
            depth, start = 1, line; i += 2
            while i < len(text) and depth:
                if text.startswith('(*', i): depth += 1; i += 2
                elif text.startswith('*)', i): depth -= 1; i += 2
                else: line += text[i] == '\n'; i += 1
            if depth: raise ValueError(f'Unclosed comment at line {start}')
            continue
        if text[i] == '"':
            start = line; i += 1
            while i < len(text):
                if text[i] == '\\': i += 2
                elif text[i] == '"': i += 1; break
                else: line += text[i] == '\n'; i += 1
            else: raise ValueError(f'Unclosed string at line {start}')
            yield 'STRING', start
            continue
        if text.startswith('<|', i) or text.startswith('|>', i):
            yield text[i:i+2], line; i += 2; continue
        m = re.match(r'[A-Za-z$][A-Za-z0-9$`]*', text[i:])
        if m:
            yield m.group(), line; i += len(m.group()); continue
        yield text[i], line; i += 1

def check(path: Path):
    text = path.read_text(encoding='utf-8')
    stack = []
    previous = None
    for token, line in tokens(text):
        if token == 'Return' and any(head in LOOPS for _, _, head in stack):
            raise ValueError(f'{path.name}:{line}: Return lexically inside a loop')
        if token in OPEN:
            stack.append((token, line, previous if token == '[' else None))
        elif token in CLOSE:
            if not stack or OPEN[stack[-1][0]] != token:
                raise ValueError(f'{path.name}:{line}: unmatched {token}')
            stack.pop()
        previous = token
    if stack: raise ValueError(f'{path.name}: unclosed delimiters {stack}')
    return {'file':str(path.relative_to(ROOT)), 'basic_lexical_check':'PASS',
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    files = sorted(p for p in ROOT.rglob('*') if p.suffix in {'.wl','.wlt','.m'})
    checks = [check(p) for p in files]
    test_text = (ROOT/'Tests/AlgebraicDecomposition.wlt').read_text()
    ids = re.findall(r'TestID\s*->\s*"([^"]+)"', test_text)
    assert len(ids) == len(set(ids)) == 60, 'Missing or duplicate test IDs'
    source = (ROOT/'Kernel/AlgebraicDecomposition.wl').read_text()
    tex = (ROOT/'article/article.tex').read_text()
    embedded = tex.rsplit('\\begin{lstlisting}\n',1)[1].split('\\end{lstlisting}',1)[0]
    assert embedded == source+'\n', 'Embedded article source differs from package'
    report = {'status':'BASIC_LEXICAL_AND_PACKAGING_CHECKS_PASS',
              'not_performed':'Wolfram parsing or native execution',
              'native_tests_authored':len(ids),
              'native_test_ids_unique':True,
              'article_source_matches_package':True,
              'no_Return_lexically_inside_Do_For_While_Table':True,
              'files':checks}
    out=ROOT/'Verification/source_checks.json'
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__ == '__main__':
    main()
