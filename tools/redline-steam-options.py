#!/usr/bin/env python3
"""Edit one Steam game's launch options, preserving other VDF bytes and a backup."""
import argparse, json, os, re, sys, tempfile, time
from pathlib import Path
TOKEN = re.compile(r'//[^\n]*|"(?:\\.|[^"\\])*"|[{}]|\s+', re.S)
def parse(text):
    if TOKEN.sub("",text).strip():raise ValueError("Unsupported Steam config tokens")
    tokens=[(m.group(),m.start(),m.end()) for m in TOKEN.finditer(text) if not m.group().isspace() and not m.group().startswith('//')]
    pos=0
    def block():
        nonlocal pos
        result=[]
        while pos<len(tokens) and tokens[pos][0]!='}':
            raw,start,end=tokens[pos];pos+=1
            if not raw.startswith('"') or pos>=len(tokens):raise ValueError('Unsupported Steam config syntax')
            key=raw[1:-1];value,vs,ve=tokens[pos];pos+=1
            if value=='{':
                children=block()
                if pos>=len(tokens) or tokens[pos][0]!='}':raise ValueError('Unbalanced Steam config')
                close=tokens[pos][1];pos+=1;result.append(dict(key=key,children=children,close=close,start=start,end=tokens[pos-1][2]))
            elif value.startswith('"'):result.append(dict(key=key,value=value[1:-1],vs=vs,ve=ve,start=start,end=ve))
            else:raise ValueError('Unsupported Steam config value')
        return result
    result=block()
    if pos!=len(tokens):raise ValueError('Invalid Steam config')
    return result

def child(nodes,key):
    found=[n for n in nodes if n['key'].lower()==key.lower()]
    if len(found)>1:raise ValueError('Ambiguous duplicate Steam config keys')
    return found[0] if found else None

def locate(text,app):
    nodes=parse(text);parent=None
    for key in ['UserLocalConfigStore','Software','Valve','Steam','apps',app]:
        node=child(nodes,key)
        if node is None:return parent,key
        parent=node;nodes=node.get('children',[])
    return parent,None

def rewrite(text,app,encoded):
    node,missing=locate(text,app)
    if missing:
        if node is None:raise ValueError('Steam account configuration missing')
        chain=['UserLocalConfigStore','Software','Valve','Steam','apps',app];i=chain.index(missing)
        insertion='\n'
        for k in chain[i:]:insertion+='"'+k+'"\n{\n'
        if encoded is not None:insertion+='"LaunchOptions" "'+encoded+'"\n'
        insertion+='}\n'*(len(chain)-i)
        return text[:node['close']]+insertion+text[node['close']:]
    options=child(node.get('children',[]),'LaunchOptions')
    if options:
        if encoded is None:return text[:options['start']]+text[options['end']:]
        return text[:options['vs']]+'"'+encoded+'"'+text[options['ve']:]
    if encoded is None:return text
    return text[:node['close']]+'\n"LaunchOptions" "'+encoded+'"\n'+text[node['close']:]

def steam_running():
    for p in Path('/proc').iterdir():
        if p.name.isdigit():
            try:
                if (p/'comm').read_text().strip()=='steam':return True
            except OSError:pass
    return False

def atomic(path,data):
    fd,tmp=tempfile.mkstemp(prefix='.redline-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as stream:stream.write(data);stream.flush();os.fsync(stream.fileno())
        os.chmod(tmp,path.stat().st_mode & 0o777 if path.exists() else 0o600);os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def main():
    a=argparse.ArgumentParser();a.add_argument('--steam-root',required=True);a.add_argument('--app-id',required=True);a.add_argument('--options');a.add_argument('--restore',action='store_true');args=a.parse_args()
    if not args.app_id.isdigit():raise ValueError('Invalid Steam game identifier')
    if steam_running():raise ValueError('Close Steam completely, then press Apply to Steam again. You can copy the launch option while Steam is open.')
    root=Path(args.steam_root).resolve();files=list((root/'userdata').glob('*/config/localconfig.vdf'))
    if len(files)!=1:raise ValueError('Cannot select a unique Steam account. Copy the launch option into Steam game properties instead.')
    path=files[0];raw=path.read_bytes();text=raw.decode('utf-8');node,missing=locate(text,args.app_id)
    old=child(node.get('children',[]),'LaunchOptions') if node and not missing else None
    record=path.with_name('redline-launch-backup.json');state=json.loads(record.read_text()) if record.exists() else {};app=args.app_id
    if app in state and "managed" in state[app] and (old["value"] if old else None) not in (state[app]["managed"],state[app]["original"]):raise ValueError("Steam launch options were edited outside Redline. Existing changes were preserved; use Copy launch option.")
    if args.restore:
        if app not in state:raise ValueError('No Redline backup exists for this game')
        value=state[app]['original']
    else:
        if not args.options or '%command%' not in args.options:raise ValueError('Invalid launch recipe')
        if app not in state:state[app]={'original':old['value'] if old else None}
        original=state[app]['original']
        # Keep all pre-existing user options. Refuse an opaque custom command wrapper.
        decoded=(original or '').replace('\\"','"').replace('\\\\','\\')
        if '%command%' in decoded:raise ValueError('Existing custom Steam wrapper detected. Copy and combine the Redline launch option manually; existing options were left unchanged.')
        value=args.options+(' '+decoded if decoded else '')
        value=value.replace('\\','\\\\').replace('"','\\"')
    if not args.restore:state[app]["managed"]=value
    new=rewrite(text,app,value);parse(new)
    if path.read_bytes()!=raw:raise ValueError('Steam settings changed during editing; retry with Steam closed')
    backup=path.with_name('localconfig.vdf.redline-'+str(time.time_ns())+'.bak');backup.write_bytes(raw);os.chmod(backup,0o600)
    atomic(record,json.dumps(state,indent=2).encode());atomic(path,new.encode())
    print(json.dumps({'ok':True,'message':'Steam launch options restored.' if args.restore else 'Connected. Start the game again to use the selected tools.'}))
if __name__=='__main__':
    try:main()
    except Exception as exc:print(json.dumps({'ok':False,'message':str(exc)}));sys.exit(1)
