"""Lexical delimiter check only. This does NOT parse/evaluate Wolfram Language."""
import json,pathlib,sys

def check(text):
    stack=[]; i=0; line=1; comment=0; string=False
    while i<len(text):
        ch=text[i]; token=text[i:i+2]
        if ch=='\n': line+=1
        if comment:
            if token=='(*': comment+=1;i+=2;continue
            if token=='*)': comment-=1;i+=2;continue
            i+=1;continue
        if string:
            if ch=='\\': i+=2;continue
            if ch=='"': string=False
            i+=1;continue
        if token=='(*': comment=1;i+=2;continue
        if ch=='"': string=True;i+=1;continue
        if token=='<|': stack.append(('|>',line));i+=2;continue
        if token=='|>':
            if not stack or stack.pop()[0]!='|>': raise ValueError(f'Association mismatch at line {line}')
            i+=2;continue
        if ch in '([{': stack.append((dict(zip('([{',')]}'))[ch],line))
        elif ch in ')]}':
            if not stack or stack.pop()[0]!=ch: raise ValueError(f'Delimiter mismatch at line {line}')
        i+=1
    if string or comment or stack: raise ValueError(f'Unclosed lexical item: {stack}, comment={comment}, string={string}')

def main():
    root=pathlib.Path(__file__).resolve().parents[1]
    result={'kind':'STATIC_LEXICAL_CHECK_ONLY','runtime_validation':False,'files':[]}
    for suffix in ('*.wl','*.wlt','*.wls','*.m'):
        for p in sorted(root.rglob(suffix)):
            try: check(p.read_text()); status='PASS';error=''
            except ValueError as e: status='FAIL';error=str(e)
            result['files'].append({'path':str(p.relative_to(root)),'status':status,'error':error})
    print(json.dumps(result,indent=2))
    (root/'test-results/wolfram-static-check.json').write_text(json.dumps(result,indent=2))
    return int(any(r['status']!='PASS' for r in result['files']))
if __name__=='__main__': sys.exit(main())
