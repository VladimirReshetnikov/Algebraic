"""Read notebook boxes as inert text; never evaluate notebook contents."""
from pathlib import Path
import re,hashlib,argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("notebook",type=Path)
parser.add_argument("--output",type=Path)
args=parser.parse_args()
p=args.notebook
text=p.read_text(encoding="utf-8")
def close(s,start):
 stack=[]; quote=False; esc=False; comment=0;i=start
 while i<len(s):
  c=s[i]
  if comment:
   if s[i:i+2]=='(*':comment+=1;i+=2;continue
   if s[i:i+2]=='*)':comment-=1;i+=2;continue
  elif quote:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='"':quote=False
  else:
   if s[i:i+2]=='(*':comment=1;i+=2;continue
   if c=='"':quote=True
   elif c in '[{(':stack.append(c)
   elif c in ']})':
    stack.pop()
    if not stack:return i
  i+=1
 raise ValueError('unbalanced')
def parts(s):
 out=[];i=0;start=0
 while i<len(s):
  if s[i]=='"':
   i+=1
   while i<len(s):
    if s[i]=='\\':i+=2;continue
    if s[i]=='"':break
    i+=1
  elif s[i] in '[{(':i=close(s,i)
  elif s[i]==',':out.append(s[start:i].strip());start=i+1
  i+=1
 out.append(s[start:].strip());return out
def render(s):
 s=s.strip()
 if s.startswith('"') and s.endswith('"'):
  return s[1:-1].replace('\\\n','').replace('\\"','"').replace('\\[IndentingNewLine]','\n').replace('\\[VeryThinSpace]',' ').replace('\\[InvisibleSpace]',' ')
 if s.startswith('{'):return ''.join(map(render,parts(s[1:-1])))
 m=re.match(r'([A-Za-z$][\w`$]*)\[',s)
 if not m:return s
 head=m[1]; ar=parts(s[m.end():-1]); rr=[render(a) for a in ar]
 if head in ('RowBox','BoxData','StyleBox','TagBox','FormBox'):return rr[0]
 if head=='SuperscriptBox':return '('+rr[0]+')^('+rr[1]+')'
 if head=='FractionBox':return '('+rr[0]+')/('+rr[1]+')'
 if head=='SqrtBox':return 'Sqrt['+rr[0]+']'
 if head=='RadicalBox':return '('+rr[0]+')^(1/('+rr[1]+'))'
 if head=='InterpretationBox' and len(rr)>1:return rr[1]
 return head+'['+', '.join(rr)+']'
out=[]
for m in re.finditer(r'Cell\[BoxData\[',text):
 start=m.end()-1;end=close(text,start)
 tail=text[end+1:end+200]
 if re.match(r',\s*"Input"',tail):
  line=text[:m.start()].count('\n')+1
  out.append((line,render(text[start+1:end])))
q=args.output if args.output else p.with_suffix(".inputs.txt")
q.write_text('\n\n'.join(f'===== Input {i+1}; original line {line} =====\n{code}' for i,(line,code) in enumerate(out)))
print(len(out),'input cells',q.stat().st_size,'bytes')
print('SHA256',hashlib.sha256(p.read_bytes()).hexdigest())
print("Output:",q)
