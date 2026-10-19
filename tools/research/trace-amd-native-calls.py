# SPDX-License-Identifier: GPL-3.0-or-later
"""Disassemble bounded procedures and index static calls; never run target code."""
import argparse,collections,importlib.util,json,re,struct,subprocess
from pathlib import Path
spec=importlib.util.spec_from_file_location('amd_pe',Path(__file__).with_name('index-amd-pe.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
TARGETS=[
 'UI_RSX::OverdriveBaseModel::Apply','UI_RSX::OverdriveBaseModel::ApplyWattmanSettings','UI_RSX::OverdriveBaseModel::Discard',
 'Runtime::OverdriveRuntime::ApplyOverdriveSettings','Runtime::OverdriveRuntime::ApplyOneGPUODNDefault',
 'UI_RSX::PerfSettingsModel::changedPerfSettingValue','UI_RSX::PerfSettingsModel::setMetricIsLogging',
 'UI_RSX::PerfSettingsModel::setHwSamplingInterval','UI_RSX::PerfSettingsModel::setFlSamplingInterval',
 'UI_RSX::PerfSettingsModel::setPerformanceMetricsWindowPosition',
 'Runtime::MetricsOverlayMangr::CheckCondForShowingMetricsOverlay',
 'Runtime::MetricsOverlayMangr::UpdateMetricsOverlay',
 'Runtime::MetricsOverlayMangr::UpdateEnableMetricsOverlayRegKey',
 'UI_RSX::DvrCommandModel::DvrCommand','UI_RSX::DvrCommandModel::SetIsRecording',
 'UI_RSX::MiscPreferenceModel::changeTheme','UI_RSX::MiscPreferenceModel::SetTheme',
 'UI_RSX::MiscPreferenceModel::changeLanguage','UI_RSX::MiscPreferenceModel::SetLanguage',
 'UI_RSX::MiscPreferenceModel::SetSystemTray',
 'Runtime::DvrRuntime::RunDVRCommand','UI_RSX::MiscPreferenceModelController::OnEvent','UI_RSX::MiscPreferenceModelController::ConnectModel','UI_RSX::PerfSettingsModelController::OnEvent',
 'Runtime::Notifications::ChangeNotificationReadStatus','Runtime::Notifications::DeleteNotification']

def run(exe,procedures,out):
 pe=module.PE(exe.read_bytes());b=pe.b;procs=json.loads(procedures.read_text())['procedures'];addresses=collections.defaultdict(list)
 for p in procs:
  if not p['section'] or p['section']>len(pe.sections):continue
  va=pe.base+pe.sections[p['section']-1][0]+p['offset'];addresses[va].append(p['name'])
 imports={}
 rva,size=pe.dirs[1];off=pe.offset(rva)
 for i in range(size//20+1):
  orig,_,_,name,iat=struct.unpack_from('<5I',b,off+i*20)
  if not any((orig,name,iat)):break
  dll=pe.text(name)
  for j,func in enumerate(pe.thunks(orig or iat)):imports[pe.base+iat+j*(8 if pe.is64 else 4)]=dll+'!'+func
 out.mkdir(exist_ok=True);records=[];missing=[];model_file=procedures.parent/'native-models-and-enums.json';model_members=json.loads(model_file.read_text())['models'] if model_file.exists() else {}
 for n,target in enumerate(TARGETS):
  matches=[p for p in procs if p['name']==target and p['bytes']>0]
  folded=False
  if not matches:
   cls,member=target.rsplit('::',1);symbol=model_members.get(cls,{}).get(member)
   if symbol:
    matches=[p for p in procs if p['section']==symbol['section'] and p['offset']==symbol['offset'] and p['bytes']>0];folded=bool(matches)
  if not matches:missing.append(target);continue
  p=matches[0];start=pe.base+pe.sections[p['section']-1][0]+p['offset'];end=start+p['bytes']
  dis=subprocess.run(['objdump','-d',f'--start-address={start:#x}',f'--stop-address={end:#x}',str(exe)],capture_output=True,text=True,check=True).stdout
  (out/f'{n:02d}.asm').write_text(dis);calls=[]
  for line in dis.splitlines():
   m=re.match(r'^\s*([0-9a-f]+):\s+(?:[0-9a-f]{2}\s+)+\s*((?:call|jmp)\s+.+)$',line)
   if not m:continue
   inst=m[2];direct=re.match(r'(call|jmp)\s+(?:0x)?([0-9a-f]+)(?:\s|$)',inst)
   if direct:
    dest=int(direct[2],16);names=addresses.get(dest,[]);calls.append({'instruction_va':m[1],'kind':direct[1],'target_va':hex(dest),'candidate_symbols':sorted(set(names),key=len)[:4]})
   else:
    pointer=re.search(r'#\s*(0x[0-9a-f]+)',inst);address=int(pointer[1],16) if pointer else None
    calls.append({'instruction_va':m[1],'kind':'indirect','import':imports.get(address),'instruction':inst})
  records.append({'name':target,'resolved_procedure':p['name'],'shared_entrypoint_fallback':folded,'start_va':hex(start),'bytes':p['bytes'],'disassembly':f'{n:02d}.asm','calls':calls})
 result={'procedures':records,'missing_target_names':missing,'limitations':'Direct calls and imports only. Virtual/indirect calls and runtime state are unresolved. No execution or semantic decompilation.'};(out/'call-index.json').write_text(json.dumps(result,indent=2));print(json.dumps({'procedures_disassembled':len(records),'calls_recorded':sum(len(x['calls']) for x in records),'missing_target_names':missing},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('exe',type=Path);p.add_argument('procedures',type=Path);p.add_argument('output',type=Path);a=p.parse_args();run(a.exe,a.procedures,a.output)
