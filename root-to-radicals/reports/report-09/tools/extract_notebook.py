"""Read notebook boxes as text; never evaluate notebook code."""
import re, pathlib, json
p=pathlib.Path(__file__).resolve().parents[1]
s=(p/'original/FindExtension.nb').read_text()
def closing(s,start):
    stack=[]; quoted=False; escape=False
    for i in range(start,len(s)):
        c=s[i]
        if quoted:
            if escape: escape=False
            elif c=='\\': escape=True
            elif c=='"': quoted=False
        elif c=='"': quoted=True
        elif c in '[{(': stack.append(c)
        elif c in ']})':
            stack.pop()
            if not stack:return i
    raise ValueError('Unbalanced notebook')
token=re.compile(r'\s*("(?:\\.|[^"\\])*"|[A-Za-z$`][A-Za-z0-9$`]*|\d+|\[|\]|\{|\}|,|[^\s])',re.S)
def parse(text):
    toks=token.findall(text); i=0
    def atom():
        nonlocal i
        t=toks[i]; i+=1
        if t[0]=='"':
            return t[1:-1].replace('\\"','"').replace('\\\n','')
        if t=='{':
            v=[]
            while toks[i]!='}':
                if toks[i]==',':i+=1;continue
                v.append(atom())
            i+=1;return v
        if i<len(toks) and toks[i]=='[':
            i+=1; v=[]
            while toks[i]!=']':
                if toks[i]==',':i+=1;continue
                v.append(atom())
            i+=1;return (t,v)
        return t
    return atom()
def render(a):
    if isinstance(a,str): return a
    if isinstance(a,list):return '\n'.join(map(render,a))
    h,v=a
    if h=='RowBox':return ''.join(map(render,v[0]))
    if h=='SuperscriptBox':return '('+render(v[0])+')^('+render(v[1])+')'
    if h=='FractionBox':return '('+render(v[0])+')/('+render(v[1])+')'
    if h=='SqrtBox':return 'Sqrt['+render(v[0])+']'
    if h in ('StyleBox','TagBox','FormBox','InterpretationBox','TooltipBox','BoxData'):return render(v[0])
    return h+'['+', '.join(map(render,v))+']'
replacements={'\\[IndentingNewLine]':'\n','\\[RuleDelayed]':':>','\\[Rule]':'->','\\[Equal]':'==','\\[NotEqual]':'!=','\\[Not]':'!','\\[LeftDoubleBracket]':'[[','\\[RightDoubleBracket]':']]','\\[VeryThinSpace]':' ','\\[InvisibleSpace]':' '}
out=[]
for j,m in enumerate(re.finditer(r'Cell\[BoxData\[',s)):
    start=m.end()-1; end=closing(s,start)
    if not re.match(r'\s*,\s*"Input"',s[end+1:]):continue
    text=render(parse(s[start+1:end]))
    for k,v in replacements.items():text=text.replace(k,v)
    line=s[:m.start()].count('\n')+1
    out.append(f'(* Input cell, notebook source line {line}. Display-box transcription only. *)\n{text}\n')
(p/'original/FindExtension-input-cells.txt').write_text('\n'.join(out))
print(len(out),'input cells')
