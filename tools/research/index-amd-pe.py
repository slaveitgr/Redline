# SPDX-License-Identifier: GPL-3.0-or-later
"""Data-only PE import/export inventory for every executable image in an MSIX."""
import argparse,hashlib,json,struct,zipfile
from pathlib import Path

class PE:
 def __init__(self,b):
  self.b=b
  if b[:2]!=b'MZ':raise ValueError('Not MZ')
  pe=struct.unpack_from('<I',b,0x3c)[0]
  if b[pe:pe+4]!=b'PE\0\0':raise ValueError('Not PE')
  self.machine,count,_,_,_,opt_size,_=struct.unpack_from('<HHIIIHH',b,pe+4);opt=pe+24;magic=struct.unpack_from('<H',b,opt)[0];self.is64=magic==0x20b
  if magic not in (0x20b,0x10b):raise ValueError('Unsupported optional header')
  self.base=struct.unpack_from('<Q' if self.is64 else '<I',b,opt+(24 if self.is64 else 28))[0]
  n=struct.unpack_from('<I',b,opt+(108 if self.is64 else 92))[0];directory=opt+(112 if self.is64 else 96)
  self.dirs=[struct.unpack_from('<II',b,directory+i*8) for i in range(min(n,16))];self.sections=[]
  for i in range(count):
   off=opt+opt_size+i*40;vs,rva,size,raw=struct.unpack_from('<4I',b,off+8);self.sections.append((rva,vs,size,raw))
 def offset(self,rva):
  for start,vs,size,raw in self.sections:
   if start<=rva<start+max(vs,size):
    delta=rva-start
    if delta>=size:raise ValueError('RVA has no on-disk data')
    return raw+delta
  if 0<=rva<min(s[3] for s in self.sections):return rva
  raise ValueError('RVA outside image')
 def text(self,rva):
  off=self.offset(rva);end=self.b.find(b'\0',off,off+4096)
  if end<0:raise ValueError('Unterminated string')
  return self.b[off:end].decode('ascii',errors='replace')
 def thunks(self,rva):
  if not rva:return []
  result=[];off=self.offset(rva);size=8 if self.is64 else 4;fmt='<Q' if self.is64 else '<I';ordinal=1<<(size*8-1)
  for i in range(100000):
   value=struct.unpack_from(fmt,self.b,off+i*size)[0]
   if value==0:return result
   result.append('#'+str(value&0xffff) if value&ordinal else self.text(value+2))
  raise ValueError('Too many imports')
 def imports(self,delay=False):
  idx=13 if delay else 1
  if idx>=len(self.dirs) or not self.dirs[idx][0]:return []
  rva,size=self.dirs[idx];offset=self.offset(rva);result=[];step=32 if delay else 20
  for i in range(min(size//step+1,4096)):
   values=struct.unpack_from('<8I' if delay else '<5I',self.b,offset+i*step)
   if not any(values):return result
   if delay:
    attrs,name,_,iat,original,_,_,_=values
    if not attrs&1:name-=self.base;original-=self.base
   else:original,_,_,name,iat=values
   result.append({'dll':self.text(name),'functions':self.thunks(original or iat)})
  return result
 def exports(self):
  if not self.dirs or not self.dirs[0][0]:return []
  rva,size=self.dirs[0];off=self.offset(rva);fields=struct.unpack_from('<IIHHIIIIIII',self.b,off)
  _,_,_,_,_,base,count,names,func_rva,names_rva,ord_rva=fields
  if max(count,names)>200000:raise ValueError('Export count exceeds bound')
  result=[]
  for i in range(names):
   name=self.text(struct.unpack_from('<I',self.b,self.offset(names_rva)+i*4)[0]);index=struct.unpack_from('<H',self.b,self.offset(ord_rva)+i*2)[0]
   target=struct.unpack_from('<I',self.b,self.offset(func_rva)+index*4)[0]
   result.append({'name':name,'ordinal':base+index,'rva':target,**({'forwarder':self.text(target)} if rva<=target<rva+size else {})})
  return result

def run(package,out):
 results=[]
 with zipfile.ZipFile(package) as z:
  for name in z.namelist():
   if not name.lower().endswith(('.exe','.dll')):continue
   data=z.read(name);item={'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
   try:
    pe=PE(data);item.update({'machine':hex(pe.machine),'is64':pe.is64,'imports':pe.imports(),'delay_imports':pe.imports(True),'exports':pe.exports(),'managed':len(pe.dirs)>14 and bool(pe.dirs[14][0])})
   except (ValueError,struct.error,IndexError) as e:item['parse_error']=str(e)
   results.append(item)
 out.write_text(json.dumps(results,indent=2));print(json.dumps({'images':len(results),'parse_errors':[{k:r[k] for k in ['path','parse_error']} for r in results if 'parse_error'in r],'named_exports':sum(len(r.get('exports',[])) for r in results),'imported_dll_edges':sum(len(r.get('imports',[]))+len(r.get('delay_imports',[])) for r in results)},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('package',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.package,a.output)
