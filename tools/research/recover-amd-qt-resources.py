# SPDX-License-Identifier: GPL-3.0-or-later
"""Recover data-only Qt resource trees from a PE and its matched PDB inventory.

No target code is loaded or executed. Recovered files are private research inputs,
not public Redline source. Supports the observed Qt resource v3 layout.
"""
import argparse,hashlib,json,struct,zlib
from pathlib import Path,PurePosixPath

class PE:
 def __init__(self,path):
  self.data=path.read_bytes()
  if self.data[:2]!=b'MZ':raise ValueError('Not PE')
  pe=struct.unpack_from('<I',self.data,0x3c)[0]
  if self.data[pe:pe+4]!=b'PE\0\0':raise ValueError('Invalid PE signature')
  count=struct.unpack_from('<H',self.data,pe+6)[0];optional=struct.unpack_from('<H',self.data,pe+20)[0];table=pe+24+optional;self.sections=[]
  for i in range(count):
   off=table+i*40;name=self.data[off:off+8].rstrip(b'\0').decode();virtual_size,rva,raw_size,raw_offset=struct.unpack_from('<4I',self.data,off+8)
   self.sections.append({'name':name,'rva':rva,'size':raw_size,'offset':raw_offset})
 def location(self,symbol):
  section=self.sections[symbol['section']-1];offset=symbol['offset']
  if offset>=section['size']:raise ValueError('Resource array outside section')
  return section['offset']+offset

def recover(pe,arrays,output,label):
 data,name,tree=[pe.location(arrays[k]) for k in ['qt_resource_data','qt_resource_name','qt_resource_struct']]
 b=pe.data;records=[];seen=set();maxnode=0;maxname=0;maxdata=0
 def read_name(offset):
  nonlocal maxname
  length=struct.unpack_from('>H',b,name+offset)[0]
  if length>1024:raise ValueError('Invalid name length')
  end=name+offset+6+length*2
  if end>len(b):raise ValueError('Invalid name bounds')
  maxname=max(maxname,end-name)
  return b[name+offset+6:end].decode('utf-16-be')
 def walk(index,parent,depth=0):
  nonlocal maxnode,maxdata
  if depth>40 or index>10000 or index in seen:raise ValueError('Invalid resource tree')
  seen.add(index);maxnode=max(maxnode,index)
  off=tree+index*22
  name_offset,flags=struct.unpack_from('>IH',b,off)
  segment=read_name(name_offset) if index else ''
  if segment in ['.','..'] or '/' in segment or '\\' in segment:raise ValueError('Unsafe resource name')
  path=parent/segment
  if flags&2:
   count,first=struct.unpack_from('>II',b,off+6)
   if count>10000:raise ValueError('Invalid child count')
   for child in range(first,first+count):walk(child,path,depth+1)
  else:
   country,language,payload_offset=struct.unpack_from('>HHI',b,off+6)
   length=struct.unpack_from('>I',b,data+payload_offset)[0]
   if length>64*1024*1024:raise ValueError('Invalid resource size')
   raw=b[data+payload_offset+4:data+payload_offset+4+length]
   if len(raw)!=length:raise ValueError('Truncated payload')
   maxdata=max(maxdata,payload_offset+4+length)
   if flags&4:raise ValueError('Zstandard resource requires a separate decoder')
   if flags&1:
    expected=struct.unpack_from('>I',raw)[0]
    if expected>64*1024*1024:raise ValueError('Decompressed resource too large')
    decoder=zlib.decompressobj();decoded=decoder.decompress(raw[4:],expected+1)
    if len(decoded)!=expected or not decoder.eof:raise ValueError('Invalid compressed resource')
   else:decoded=raw
   relative=path.as_posix();dest=output/label/relative
   if dest.exists():dest=dest.with_name(dest.name+f'.locale-{country}-{language}')
   dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(decoded)
   records.append({'path':relative,'output':dest.relative_to(output).as_posix(),'flags':flags,'country':country,'language':language,'bytes':len(decoded),'sha256':hashlib.sha256(decoded).hexdigest()})
 walk(0,PurePosixPath())
 # A reconstructed data-only RCC allows independent validation with the installed Qt reader.
 payload=b[data:data+maxdata];names=b[name:name+maxname];nodes=b[tree:tree+(maxnode+1)*22]
 header=b'qres'+struct.pack('>IIIII',3,24+len(payload)+len(names),24,24+len(payload),0)
 (output/(label+'.rcc')).write_bytes(header+payload+names+nodes)
 return {'label':label,'arrays':{k:{'section':v['section'],'offset':v['offset']} for k,v in arrays.items()},'files':records,'node_count':len(seen),'data_bytes':maxdata,'name_bytes':maxname,'tree_bytes':len(nodes)}

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('exe',type=Path);parser.add_argument('symbols',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
 symbols=json.loads(args.symbols.read_text())
 if not symbols['executable_matches']:raise ValueError('PDB identity mismatch')
 pe=PE(args.exe);groups={name:sorted([s for s in symbols['relevant_symbols'] if s['name']==name],key=lambda s:(s['section'],s['offset'])) for name in ['qt_resource_data','qt_resource_name','qt_resource_struct']}
 counts={len(v) for v in groups.values()}
 if len(counts)!=1:raise ValueError('Unmatched resource array symbols')
 args.output.mkdir(parents=True,exist_ok=True);result=[]
 for i in range(len(groups['qt_resource_data'])):
  arrays={name:items[i] for name,items in groups.items()}
  result.append(recover(pe,arrays,args.output,f'embedded-{i+1}'))
 (args.output/'manifest.json').write_text(json.dumps(result,indent=2))
 print(json.dumps([{'label':r['label'],'files':len(r['files']),'decoded_bytes':sum(f['bytes'] for f in r['files']),'nodes':r['node_count']} for r in result],indent=2))
