# SPDX-License-Identifier: GPL-3.0-or-later
"""Decode Qt revision-13 metadata as data. Never invoke meta calls or getters.

The observed Windows layout uses QT_NO_DATA_RELOCATION, so SuperData has two
pointers. The alternate one-pointer layout is tried only with strict class-name
and metadata-header validation. Built-in type IDs are retained in all records.
"""
import argparse,importlib.util,json,re,struct
from pathlib import Path

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
native=load('amd_native',Path(__file__).with_name('index-amd-native-models.py'))
pe_module=load('amd_pe',Path(__file__).with_name('index-amd-pe.py'))
BUILTINS={0:'unknown',1:'bool',2:'int',3:'uint',4:'qlonglong',5:'qulonglong',6:'double',7:'QChar',8:'QVariantMap',9:'QVariantList',10:'QString',11:'QStringList',12:'QByteArray',14:'QDate',15:'QTime',16:'QDateTime',17:'QUrl',18:'QLocale',19:'QRect',20:'QRectF',21:'QSize',22:'QSizeF',25:'QPoint',26:'QPointF',28:'QVariantHash',31:'void*',32:'long',33:'short',34:'char',35:'ulong',36:'ushort',37:'uchar',38:'float',39:'QObject*',40:'signed char',41:'QVariant',42:'QModelIndex',43:'void',44:'QRegularExpression'}

def decode(pe,offset,expected):
 b=pe.b;ptrs=struct.unpack_from('<8Q',b,offset);errors=[]
 for stringindex in (2,1):
  try:
   strings=pe.offset(ptrs[stringindex]-pe.base);data=pe.offset(ptrs[stringindex+1]-pe.base)
   def word(index):return struct.unpack_from('<I',b,data+index*4)[0]
   header=[word(i) for i in range(14)]
   if header[0]!=13 or max(header[2:12])>50000:raise ValueError('Unsupported metadata header')
   def text(index):
    if index>50000:raise ValueError('String index out of bounds')
    relative,length=struct.unpack_from('<II',b,strings+index*8)
    if length>100000 or relative>2000000:raise ValueError('String bounds')
    value=b[strings+relative:strings+relative+length]
    if len(value)!=length or b[strings+relative+length]!=0:raise ValueError('Invalid string terminator')
    return value.decode('utf8')
   name=text(header[1])
   if name!=expected:raise ValueError('Class name mismatch')
   def type_name(value):return text(value&0x7fffffff) if value&0x80000000 else BUILTINS.get(value,'QtTypeID:'+str(value))
   classinfo=[{'name':text(word(header[3]+2*i)),'value':text(word(header[3]+2*i+1))} for i in range(header[2])]
   methods=[]
   for i in range(header[4]):
    base=header[5]+i*6;n,argc,params,tag,flags,meta=[word(base+j) for j in range(6)]
    if argc>1000:raise ValueError('Parameter count')
    typ=flags&12;parameter_types=[word(params+1+j) for j in range(argc)]
    methods.append({'index':i,'name':text(n),'kind':{0:'method',4:'signal',8:'slot',12:'constructor'}[typ],'access':{0:'private',1:'protected',2:'public'}.get(flags&3,'unknown'),'flags':hex(flags),'const':bool(flags&0x100),'return_type':type_name(word(params)),'parameter_types':[type_name(v) for v in parameter_types],'parameter_names':[text(word(params+1+argc+j)) for j in range(argc)],'tag':text(tag)})
   properties=[]
   for i in range(header[6]):
    base=header[7]+i*5;n,typ,flags,notify,rev=[word(base+j) for j in range(5)]
    properties.append({'name':text(n),'type':type_name(typ),'type_id':hex(typ),'flags':hex(flags),'readable':bool(flags&1),'writable':bool(flags&2),'constant':bool(flags&0x400),'required':bool(flags&0x1000000),'notify_method_index':None if notify==0xffffffff else notify,'notify_signal':methods[notify]['name'] if notify<len(methods) else None,'revision':rev})
   enums=[]
   for i in range(header[8]):
    base=header[9]+i*5;n,alias,flags,count,values=[word(base+j) for j in range(5)]
    if count>20000:raise ValueError('Enum count')
    entries=[]
    for j in range(count):
     value=word(values+2*j+1)
     if flags&0x40:value|=word(values+2*count+j)<<32
     entries.append({'name':text(word(values+2*j)),'unsigned_value':value})
    enums.append({'name':text(n),'alias':text(alias),'flags':hex(flags),'values':entries})
   return {'class':name,'revision':header[0],'superdata_pointer_count':stringindex,'signal_count':header[13],'class_info':classinfo,'properties':properties,'methods':methods,'enums':enums,'static_metaobject_file_offset':hex(offset),'static_metacall_va':hex(ptrs[stringindex+2]),'super_direct_va':hex(ptrs[0]),'super_getter_va':hex(ptrs[1]) if stringindex==2 else None}
  except (ValueError,struct.error,IndexError,UnicodeError) as error:errors.append(str(error))
 raise ValueError('; '.join(errors))

def run(exe,pdb,out):
 pe=pe_module.PE(exe.read_bytes());streams=native.streams(pdb);index=struct.unpack_from('<H',streams[3],20)[0];b=streams[index];pos=0;symbols={}
 while pos+4<=len(b):
  length,kind=struct.unpack_from('<HH',b,pos);payload=b[pos+4:pos+2+length]
  if length<2 or pos+length+2>len(b):raise ValueError('Invalid CodeView record')
  if kind in (0x110c,0x110d):
   name=payload[10:].split(b'\0',1)[0].decode('utf8',errors='replace')
   if name.endswith('::staticMetaObject'):
    offset=struct.unpack_from('<I',payload,4)[0];section=struct.unpack_from('<H',payload,8)[0]
    if section and section<=len(pe.sections):symbols[name[:-18]]=pe.sections[section-1][3]+offset
  pos+=length+2
 result=[];errors=[]
 for name,offset in symbols.items():
  try:result.append(decode(pe,offset,name))
  except ValueError as error:errors.append({'class':name,'error':str(error)})
 out.write_text(json.dumps({'classes':result,'errors':errors},indent=2));print(json.dumps({'metadata_symbols':len(symbols),'decoded_classes':len(result),'errors':errors[:8],'properties':sum(len(c['properties']) for c in result),'methods_and_signals':sum(len(c['methods']) for c in result),'enums':sum(len(c['enums']) for c in result)},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('exe',type=Path);p.add_argument('pdb',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.exe,a.pdb,a.output)
