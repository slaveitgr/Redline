# SPDX-License-Identifier: GPL-3.0-or-later
"""Lexical QML index of recovered research files; no QML evaluation or execution.

This is deliberately an inventory, not a claim of a complete QML/JavaScript AST.
Bindings are recorded as source expressions; runtime state remains unverified.
"""
import argparse,collections,json,re
from pathlib import Path

TOKEN=re.compile(r'(?P<comment>/\*.*?\*/|//[^\n]*)|(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|`(?:\\.|[^`\\])*`)|(?P<id>[A-Za-z_$][\w$]*)|(?P<number>\d+(?:\.\d+)?)|(?P<other>[^\s])',re.S)

def tokens(text):
 return [(m.group(),m.start(),m.end(),m.lastgroup) for m in TOKEN.finditer(text) if m.lastgroup!='comment']

def string(token):
 try:return json.loads(token) if token.startswith('"') else bytes(token[1:-1],'utf8').decode('unicode_escape') if token.isascii() else token[1:-1]
 except (ValueError,UnicodeDecodeError):return token[1:-1]

def analyze(path,relative):
 text=path.read_text();t=tokens(text);pairs={};stack=[];unbalanced=[]
 for i,(value,*_) in enumerate(t):
  if value=='{':stack.append(i)
  elif value=='}':
   if stack:pairs[stack.pop()]=i
   else:unbalanced.append(i)
 imports=[]
 for line in text.splitlines():
  if line.strip().startswith('import '):imports.append(line.strip()[7:])
 ids={t[i+2][0] for i in range(len(t)-2) if t[i][0]=='id' and t[i+1][0]==':' and t[i+2][3]=='id'}
 local=set(ids)
 for i in range(len(t)-2):
  if t[i][0] in ('var','let','const','function') and t[i+1][3]=='id':local.add(t[i+1][0])
 objects=[];types=collections.Counter();routes=[];refs=set();calls=collections.defaultdict(set);labels=set();identifiers=collections.defaultdict(set)
 for i,token in enumerate(t):
  value,start,end,kind=token
  if value=='qsTr' and i+2<len(t) and t[i+1][0]=='(' and t[i+2][3]=='string':labels.add(string(t[i+2][0]))
  if kind=='string':
   s=string(value)
   if s.startswith('qrc:/Qml/') and s.endswith('.qml'):refs.add(s[5:])
  if kind=='id' and i+3<len(t) and t[i+1][0]=='.' and t[i+2][3]=='id':
   member=t[i+2][0];identifiers[value].add(member)
   if t[i+3][0]=='(':
    calls[value].add(member)
    if member in ('navigateTo','loadPage','loadQml'):
     j=i+4;depth=1
     while j<len(t) and depth:
      if t[j][0]=='(':depth+=1
      elif t[j][0]==')':depth-=1
      if depth:j+=1
     if j<len(t):routes.append({'method':value+'.'+member,'arguments':text[t[i+3][2]:t[j][1]].strip(),'line':text.count('\n',0,start)+1})
  if value!='{' or i not in pairs or i==0 or t[i-1][3]!='id' or not t[i-1][0][0].isupper():continue
  typ=t[i-1][0];types[typ]+=1;stop=pairs[i];props={};j=i+1
  while j<stop:
   if t[j][0]=='{':j=pairs.get(j,j)+1;continue
   if t[j][3]=='id':
    key=t[j][0];k=j+1
    while k+1<stop and t[k][0]=='.' and t[k+1][3]=='id':key+='.'+t[k+1][0];k+=2
    if k<stop and t[k][0]==':':
     begin=k+1;finish=begin;depth=0
     if begin<stop and t[begin][0]=='{':finish=pairs.get(begin,begin)+1
     else:
      while finish<stop:
       v=t[finish][0]
       if depth==0 and (v==';' or (finish>begin and '\n' in text[t[finish-1][2]:t[finish][1]] and t[finish-1][0] not in {'&','|','?','+','-','*','/','=',',','.','!','<','>',':'} and v not in {'&','|','?','+','*','/',',','.','<','>'})):break
       if v in ['(','[']:depth+=1
       elif v in [')',']']:depth-=1
       if v=='{':finish=pairs.get(finish,finish)+1;continue
       finish+=1
     if begin<finish:props[key]=text[t[begin][1]:t[finish-1][2]].strip()
     j=max(finish,j+1);continue
   j+=1
  interesting={k:v for k,v in props.items() if k in ('id','displayText','text','title','dialogTitle','visible','enabled','highlight','checked','feature','featureId','featureID','model','automationName','currentIndex','source','target','onClicked','onToggled','onActivated','onButtonClicked') or k.startswith('on')}
  if interesting:objects.append({'type':typ,'line':text.count('\n',0,t[i-1][1])+1,'properties':interesting})
 external={root:sorted(members) for root,members in identifiers.items() if root not in local and root not in {'Qt','Math','JSON','console','Object','String','Array','Number','Date','parent','anchors','Layout','Text','Image','Color','Screen'}}
 return {'path':relative,'imports':imports,'types':dict(types),'objects':objects,'qml_references':sorted(refs),'routes':routes,'translated_labels':sorted(labels),'candidate_external_members':external,'calls':{root:sorted(members) for root,members in calls.items()},'lexical_braces_balanced':not stack and not unbalanced}

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('recovered',type=Path);p.add_argument('output',type=Path);a=p.parse_args();manifest=json.loads((a.recovered/'manifest.json').read_text());files=[]
 for bundle in manifest:
  for entry in bundle['files']:
   if entry['path'].endswith('.qml'):files.append(analyze(a.recovered/entry['output'],entry['path']))
 a.output.mkdir(parents=True,exist_ok=True);(a.output/'qml-index.json').write_text(json.dumps(files,indent=2,ensure_ascii=False))
 navigation=[{'path':f['path'],'buttons':[o for o in f['objects'] if o['type']=='NavigationButton'],'routes':f['routes']} for f in files if any(o['type']=='NavigationButton' for o in f['objects']) or f['routes']]
 (a.output/'navigation.json').write_text(json.dumps(navigation,indent=2,ensure_ascii=False))
 backend=collections.defaultdict(lambda:collections.defaultdict(list))
 for f in files:
  for root,members in f['candidate_external_members'].items():
   for member in members:backend[root][member].append(f['path'])
 (a.output/'candidate-backend-contracts.json').write_text(json.dumps(backend,indent=2))
 areas=collections.Counter('/'.join(Path(f['path']).parts[:3]) for f in files)
 summary={'qml_files':len(files),'areas':dict(areas),'object_instances':sum(sum(f['types'].values()) for f in files),'navigation_buttons':sum(sum(o['type']=='NavigationButton' for o in f['objects']) for f in files),'navigation_calls':sum(len(f['routes']) for f in files),'distinct_translated_labels':len(set(label for f in files for label in f['translated_labels'])),'files_with_lexical_brace_issues':[f['path'] for f in files if not f['lexical_braces_balanced']]}
 (a.output/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
