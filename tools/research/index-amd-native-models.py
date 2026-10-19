# SPDX-License-Identifier: GPL-3.0-or-later
"""Read PDB type and public-symbol metadata without executing target code."""
import argparse,struct,json,re
from pathlib import Path

def streams(path):
 b=path.read_bytes()
 if not b.startswith(b'Microsoft C/C++ MSF 7.00'):raise ValueError('Unknown MSF format')
 block,_,_,size,_,blockmap=struct.unpack_from('<6I',b,32);count=(size+block-1)//block
 indexes=struct.unpack_from('<'+'I'*count,b,blockmap*block);directory=b''.join(b[i*block:(i+1)*block] for i in indexes)[:size]
 n=struct.unpack_from('<I',directory)[0];sizes=struct.unpack_from('<'+'I'*n,directory,4);pos=4+4*n;result=[]
 for size in sizes:
  count=0 if size==0xffffffff else (size+block-1)//block;indexes=struct.unpack_from('<'+'I'*count,directory,pos);pos+=count*4
  result.append(b''.join(b[i*block:(i+1)*block] for i in indexes)[:size] if size!=0xffffffff else b'')
 return result

def number(b,pos):
 leaf=struct.unpack_from('<H',b,pos)[0];pos+=2
 if leaf<0x8000:return leaf,pos
 formats={0x8000:'b',0x8001:'h',0x8002:'H',0x8003:'i',0x8004:'I',0x8009:'q',0x800a:'Q'}
 if leaf not in formats:raise ValueError('Unsupported numeric leaf '+hex(leaf))
 fmt='<'+formats[leaf];return struct.unpack_from(fmt,b,pos)[0],pos+struct.calcsize(fmt)

def run(path,out):
 s=streams(path);tpi=s[2];version,header,first,last,recordbytes=struct.unpack_from('<5I',tpi);pos=header;records={}
 for index in range(first,last):
  length,kind=struct.unpack_from('<HH',tpi,pos)
  if length<2 or pos+2+length>len(tpi):raise ValueError('Invalid TPI record')
  records[index]=(kind,tpi[pos+4:pos+2+length]);pos+=length+2
 if pos!=header+recordbytes:raise ValueError('TPI record extent mismatch')
 def fields(index,seen=None):
  seen=set() if seen is None else seen
  if not index:return [],None
  if index in seen:return [],'cycle'
  seen.add(index);kind,b=records[index]
  if kind!=0x1203:return [],'not fieldlist'
  pos=0;result=[]
  while pos<len(b):
   if b[pos]>=0xf0:pos+=b[pos]&15;continue
   leaf=struct.unpack_from('<H',b,pos)[0];pos+=2
   if leaf==0x1502:
    attr=struct.unpack_from('<H',b,pos)[0];pos+=2;value,pos=number(b,pos);end=b.find(b'\0',pos)
    if end<0:raise ValueError('Invalid enum name')
    result.append({'name':b[pos:end].decode('utf8',errors='replace'),'value':value});pos=end+1
   elif leaf==0x1404:
    continuation=struct.unpack_from('<I',b,pos+2)[0];more,error=fields(continuation,seen);result+=more;pos+=6
    if error:return result,error
   else:return result,'unsupported field '+hex(leaf)
  return result,None
 enums=[]
 for index,(kind,b) in records.items():
  if kind!=0x1507:continue
  count,props,underlying,field=struct.unpack_from('<HHII',b);name=b[12:].split(b'\0',1)[0].decode('utf8',errors='replace')
  if props&0x80:continue
  values,error=fields(field)
  enums.append({'name':name,'type_index':hex(index),'underlying_type':hex(underlying),'declared_count':count,'values':values,'complete':not error and len(values)==count,**({'error':error} if error else {})})
 symbolindex=struct.unpack_from('<H',s[3],20)[0];b=s[symbolindex];pos=0;models={}
 while pos+4<=len(b):
  length,kind=struct.unpack_from('<HH',b,pos);payload=b[pos+4:pos+2+length]
  if length<2 or pos+length+2>len(b):raise ValueError('Invalid symbol record')
  if kind==0x110e:
   name=payload[10:].split(b'\0',1)[0].decode('utf8',errors='replace')
   match=re.match(r'^\?([^@?]+)@([^@?$]+)@(UI_RSX|Runtime|Runtime_GameManager|Core)@@',name)
   if match:
    method,cls,ns=match.groups();key=ns+'::'+cls
    models.setdefault(key,{})[method]={'symbol':name,'section':struct.unpack_from('<H',payload,8)[0],'offset':struct.unpack_from('<I',payload,4)[0]}
  pos+=length+2
 result={'type_records':len(records),'complete_enums':sum(e['complete'] for e in enums),'enums':enums,'models':models}
 out.write_text(json.dumps(result,indent=2));print(json.dumps({'type_records':len(records),'enums':len(enums),'complete_enums':result['complete_enums'],'model_classes':len(models),'named_model_members':sum(len(v) for v in models.values())},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('pdb',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.pdb,a.output)
