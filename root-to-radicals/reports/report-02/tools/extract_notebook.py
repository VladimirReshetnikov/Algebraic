"""Read BoxData without evaluating the notebook. Inspection output, not executable WL."""
import re, pathlib, json, sys
s=pathlib.Path(sys.argv[1]).read_text()
def endbr(s,i):
    depth=0; string=False; esc=False
    for j in range(i,len(s)):
        c=s[j]
        if string:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c=='"': string=False
        elif c=='"': string=True
        elif c=='[': depth+=1
        elif c==']':
            depth-=1
            if depth==0:return j
    raise ValueError('unbalanced')
pat=re.compile(r'"(?:\\.|[^"\\])*"|[A-Za-z$\\][\w$`\\]*|(?:\d+(?:\.\d*)?)|\S')
class Parser:
    def __init__(self,t):self.t=pat.findall(t.replace("\\\n", ""));self.i=0
    def parse(self):
        t=self.t[self.i];self.i+=1
        if t=='{':
            out=[]
            while self.t[self.i]!='}':
                out.append(self.parse())
                if self.t[self.i]==',':self.i+=1
                else:break
            self.i+=1;return ('List',out)
        if t.startswith('"'):
            return t[1:-1].replace('\\"','"').replace('\\\n','')
        if self.i<len(self.t) and self.t[self.i]=='[':
            self.i+=1;out=[]
            while self.t[self.i]!=']':
                out.append(self.parse())
                if self.t[self.i]==',':self.i+=1
                elif self.t[self.i]!=']':
                    # Metadata/infix arguments are irrelevant to visible box contents.
                    out.append(self.t[self.i]);self.i+=1
            self.i+=1;return (t,out)
        return t
repls={'\\[IndentingNewLine]':'\n','\\[Rule]':' -> ','\\[RuleDelayed]':' :> ',
'\\[Equal]':' == ','\\[NotEqual]':' != ','\\[Not]':'!','\\[LeftDoubleBracket]':'[[',
'\\[RightDoubleBracket]':']]','\\[VeryThinSpace]':' ','\\[InvisibleSpace]':' ',
'\\[Times]':'*','\\[ImaginaryI]':'I','\\[Pi]':'Pi'}
def fmt(a):
    if isinstance(a,str):
        for x,y in repls.items():a=a.replace(x,y)
        return a
    h,b=a; f=[fmt(x) for x in b]
    if h in ('RowBox','List'):return ''.join(f)
    if h=='SuperscriptBox':return '('+f[0]+')^('+f[1]+')'
    if h=='FractionBox':return '('+f[0]+')/('+f[1]+')'
    if h=='SqrtBox':return 'Sqrt['+f[0]+']'
    if h=='RadicalBox':return '('+f[0]+')^(1/('+f[1]+'))'
    if h in ('StyleBox','FormBox','TagBox','TooltipBox','InterpretationBox'):return f[0]
    return h+'['+','.join(f)+']'
out=[]; errors=[]
for m in re.finditer(r'Cell\[BoxData\[',s):
    a=m.end()-1;b=endbr(s,a)
    if not re.match(r'\s*,\s*"Input"',s[b+1:]):continue
    line=s.count('\n',0,m.start())+1
    try: text=fmt(Parser(s[a+1:b]).parse())
    except Exception as e:errors.append([line,str(e)]);text='[UNPARSED BOX DATA]'
    out.append({'source_line':line,'text':text})
path=pathlib.Path(sys.argv[2]);path.write_text('\n\n'.join('(* Input cell at notebook line %d *)\n%s'%(r['source_line'],r['text']) for r in out))
path.with_suffix('.json').write_text(json.dumps(out,indent=2))
print(len(out),'input cells;',len(errors),'parse errors;',errors[:10])
