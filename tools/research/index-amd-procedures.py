# SPDX-License-Identifier: GPL-3.0-or-later
"""Index CodeView procedure records and module boundaries from PDB DBI streams."""
import argparse,importlib.util,json,struct
from pathlib import Path
spec=importlib.util.spec_from_file_location('amd_native',Path(__file__).with_name('index-amd-native-models.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

def run(path,out):
 streams=module.streams(path);dbi=streams[3];size=struct.unpack_from('<I',dbi,24)[0];pos=64;end=64+size;modules=[];procedures=[];errors=[]
 while pos<end:
  stream=struct.unpack_from('<H',dbi,pos+34)[0];symbolbytes=struct.unpack_from('<I',dbi,pos+36)[0];start=pos+64;sep=dbi.find(b'\0',start,end);sep2=dbi.find(b'\0',sep+1,end)
  if min(sep,sep2)<0:raise ValueError('Invalid module name')
  name=dbi[start:sep].decode('utf8',errors='replace');obj=dbi[sep+1:sep2].decode('utf8',errors='replace');pos=(sep2+4)&~3
  info={'module':name,'object':obj,'stream':stream,'symbol_bytes':symbolbytes};modules.append(info)
  if stream==0xffff or symbolbytes<4:continue
  if stream>=len(streams):errors.append({'module':name,'error':'stream index'});continue
  b=streams[stream];p=4
  while p+4<=min(symbolbytes,len(b)):
   length,kind=struct.unpack_from('<HH',b,p)
   if length<2 or p+length+2>min(symbolbytes,len(b)):errors.append({'module':name,'error':'record boundary','offset':p});break
   payload=b[p+4:p+length+2]
   if kind in (0x110f,0x1110,0x1146,0x1147):
    if len(payload)<36:raise ValueError('Invalid procedure')
    codebytes=struct.unpack_from('<I',payload,12)[0];offset=struct.unpack_from('<I',payload,28)[0];section=struct.unpack_from('<H',payload,32)[0];proc=payload[35:].split(b'\0',1)[0].decode('utf8',errors='replace')
    procedures.append({'name':proc,'section':section,'offset':offset,'bytes':codebytes,'module':name})
   p+=length+2
 result={'modules':modules,'procedures':procedures,'errors':errors};out.write_text(json.dumps(result,indent=2));print(json.dumps({'modules':len(modules),'procedures':len(procedures),'errors':errors[:10]},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('pdb',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.pdb,a.output)
