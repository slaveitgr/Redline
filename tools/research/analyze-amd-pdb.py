# SPDX-License-Identifier: GPL-3.0-or-later
"""Local static MSF/PDB inspection; never loads or runs the target executable."""
import argparse,json,struct,uuid,re
from pathlib import Path

def inspect(pdb,exe):
 data=pdb.read_bytes()
 if not data.startswith(b'Microsoft C/C++ MSF 7.00'):raise ValueError('Unsupported PDB format')
 block,_,_,directory_size,_,blockmap=struct.unpack_from('<6I',data,32)
 count=(directory_size+block-1)//block
 indexes=struct.unpack_from('<'+'I'*count,data,blockmap*block)
 directory=b''.join(data[i*block:(i+1)*block] for i in indexes)[:directory_size]
 n=struct.unpack_from('<I',directory)[0];sizes=struct.unpack_from('<'+'I'*n,directory,4);pos=4+4*n;streams=[]
 for size in sizes:
  count=0 if size==0xffffffff else (size+block-1)//block
  indexes=struct.unpack_from('<'+'I'*count,directory,pos);pos+=count*4
  streams.append(b''.join(data[i*block:(i+1)*block] for i in indexes)[:size] if size!=0xffffffff else b'')
 _,_,age=struct.unpack_from('<III',streams[1]);guid=uuid.UUID(bytes_le=streams[1][12:28])
 binary=exe.read_bytes();matched=False
 for m in re.finditer(b'RSDS',binary):
  start=m.start()
  if start+24<=len(binary) and binary[start+4:start+20]==guid.bytes_le and struct.unpack_from('<I',binary,start+20)[0]==age:matched=True
 symbolstream=struct.unpack_from('<H',streams[3],20)[0]
 symbols=streams[symbolstream];pos=0;records=0;relevant=[]
 # Offsets here are relative to record payload after the CodeView type field.
 name_offsets={0x110e:10,0x110c:10,0x110d:10,0x1110:35,0x110f:35,0x1125:10,0x1127:10}
 while pos+4<=len(symbols):
  length,kind=struct.unpack_from('<HH',symbols,pos)
  if length<2 or pos+2+length>len(symbols):raise ValueError('Invalid CodeView record size')
  payload=symbols[pos+4:pos+2+length];records+=1
  if kind in name_offsets:
   raw=payload[name_offsets[kind]:].split(b'\0',1)[0]
   name=raw.decode('utf-8',errors='replace')
   if re.search('metric|tuning|overdrive|overlay|notification|navigation|relive|qInitResources|qCleanupResources|qt_resource',name,re.I):relevant.append({'kind':hex(kind),'name':name,**({'section':struct.unpack_from('<H',payload,8)[0],'offset':struct.unpack_from('<I',payload,4)[0]} if kind in (0x110e,0x110c,0x110d) else {})})
  pos+=length+2
 return {'pdb_guid':str(guid),'age':age,'executable_matches':matched,'stream_count':n,'symbol_stream':symbolstream,'symbol_records':records,'relevant_symbols':relevant}

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('pdb',type=Path);parser.add_argument('exe',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
 result=inspect(args.pdb,args.exe);args.output.write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result.items() if k!='relevant_symbols'},indent=2));print('Relevant named symbols:',len(result['relevant_symbols']))
