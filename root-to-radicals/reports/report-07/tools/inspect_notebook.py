"""Inert box-text extraction for auditing the supplied notebook; NO evaluation.

This is deliberately not a complete Mathematica parser. Unsupported box heads
are retained visibly. The original notebook remains the authoritative source.
"""
from pathlib import Path
import re,sys,hashlib,json

NAMED={r'\[IndentingNewLine]':'\n',r'\[VeryThinSpace]':' ',r'\[InvisibleSpace]':' ',
 r'\[Rule]':'->',r'\[RuleDelayed]':':>',r'\[Equal]':'==',r'\[NotEqual]':'!=',
 r'\[Not]':'!',r'\[And]':'&&',r'\[Or]':'||',r'\[LessEqual]':'<=',r'\[GreaterEqual]':'>=',
 r'\[LeftDoubleBracket]':'[[',r'\[RightDoubleBracket]':']]',r'\[Infinity]':'Infinity',
 r'\[ImaginaryI]':'I',r'\[Pi]':'Pi',r'\[Element]':'\\[Element]'}

def balanced(text,start):
    pairs={'[':']','{':'}','(':')'}; stack=[];quote=False;esc=False;comment=0;i=start
    while i<len(text):
        if comment:
            if text[i:i+2]=='(*':comment+=1;i+=2;continue
            if text[i:i+2]=='*)':comment-=1;i+=2;continue
            i+=1;continue
        if quote:
            if esc:esc=False
            elif text[i]=='\\':esc=True
            elif text[i]=='"':quote=False
            i+=1;continue
        if text[i:i+2]=='(*':comment=1;i+=2;continue
        c=text[i]
        if c=='"':quote=True
        elif c in pairs:stack.append(pairs[c])
        elif c in ']})':
            if not stack or c!=stack.pop():raise ValueError(f'mismatch at {i}')
            if not stack:return i
        i+=1
    raise ValueError('unclosed expression')

class Parser:
    def __init__(self,text):
        self.ts=re.findall(r'"(?:\\[\s\S]|[^"\\])*"|[A-Za-z$][A-Za-z0-9`$]*|->|:>|[^\s]',text);self.i=0
    def atom(self):
        t=self.ts[self.i];self.i+=1
        if t=='{':
            a=[]
            while self.ts[self.i]!='}':
                a.append(self.atom())
                if self.ts[self.i]==',':self.i+=1
            self.i+=1;return ('List',a)
        if self.i<len(self.ts) and self.ts[self.i]=='[':
            self.i+=1;a=[]
            while self.ts[self.i]!=']':
                a.append(self.atom())
                if self.ts[self.i]==',':self.i+=1
            self.i+=1;return(t,a)
        if t.startswith('"'):
            v=t[1:-1].replace('\\\n','').replace('\\"','"').replace('\\\\','\\')
            for old,new in NAMED.items():v=v.replace(old,new)
            return v
        return t

def render(a):
    if isinstance(a,str):return a
    h,args=a
    if h in ('List','RowBox'):return ''.join(render(x) for x in args)
    if h in ('StyleBox','TagBox','FormBox'):return render(args[0])
    if h=='InterpretationBox':return render(args[1])
    if h=='SuperscriptBox':return '('+render(args[0])+')^('+render(args[1])+')'
    if h=='FractionBox':return '('+render(args[0])+')/('+render(args[1])+')'
    if h=='SqrtBox':return 'Sqrt['+render(args[0])+']'
    if h=='RadicalBox':return '('+render(args[0])+')^(1/('+render(args[1])+'))'
    return h+'['+','.join(render(x) for x in args)+']'

if __name__=='__main__':
    src=Path(sys.argv[1]);out=Path(sys.argv[2]);text=src.read_text();cells=[]
    for match in re.finditer(r'Cell\[BoxData\[',text):
        start=match.end()-1;end=balanced(text,start)
        if not re.match(r'\s*,\s*"Input"',text[end+1:]):continue
        body=text[start+1:end]
        try:content=render(Parser(body).atom())
        except Exception as exc:content=f'(* UNPARSED: {exc} *)\n'+body
        line=text.count('\n',0,match.start())+1
        cells.append(f'(* Input cell {len(cells)+1}; notebook source line {line}. *)\n{content}\n')
    out.write_text('(* AUDIT TRANSCRIPTION ONLY; NOT AN EXECUTABLE PACKAGE. *)\n\n'+'\n'.join(cells))
    print(json.dumps({'input_cells':len(cells),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
                      'bytes':src.stat().st_size,'transcription_bytes':out.stat().st_size},indent=2))
