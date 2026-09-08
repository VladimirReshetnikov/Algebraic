"""Lexical delimiter check, NOT a Wolfram parser or runtime test."""
from pathlib import Path
import sys

def check(path):
    text=Path(path).read_text(); stack=[]; i=0; comment=0; string=False
    while i<len(text):
        if comment:
            if text.startswith('(*',i):comment+=1;i+=2;continue
            if text.startswith('*)',i):comment-=1;i+=2;continue
            i+=1;continue
        if string:
            if text[i]=='\\':i+=2;continue
            if text[i]=='"':string=False
            i+=1;continue
        if text.startswith('(*',i):comment=1;i+=2;continue
        c=text[i]
        if c=='"':string=True
        elif c in '([{':stack.append((c,text.count('\n',0,i)+1))
        elif c in ')]}':
            if not stack or stack[-1][0]!='([{'[')]}'.index(c)]:
                raise ValueError(f'{path}: delimiter mismatch at line {text.count(chr(10),0,i)+1}')
            stack.pop()
        i+=1
    if stack or comment or string:raise ValueError(f'{path}: unclosed syntax token')
    print(f'{path}: balanced delimiters and closed strings/comments; runtime NOT tested')

if __name__=='__main__':
    for path in sys.argv[1:]:check(path)
