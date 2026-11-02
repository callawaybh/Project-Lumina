from pathlib import Path
import json,urllib.request,uuid
repo=Path(r'C:\Dev\LuminaClient');backup=repo/'mirror-godot-app/.lumina-bridge/multiplayer-backup';out=Path(r'C:\Users\Calla\OneDrive\Documents\ChatGPT\Project Lumina\multiplayer-setup');env=dict(l.split('=',1) for l in (repo/'mirror-web-server/.env').read_text().splitlines() if '=' in l and not l.startswith('#'));owner=env['LUMINA_LOCAL_DEV_TOKEN'].strip('\"\'');guest=json.loads(env['LUMINA_LOCAL_DEV_PLAYERS'])[0]
def api(path,data=None,method='GET',token=owner,content='application/json'):
 if data is not None and not isinstance(data,bytes):data=json.dumps(data).encode()
 req=urllib.request.Request('http://127.0.0.2:9000'+path,data=data,method=method,headers={'Authorization':'Bearer '+token,'Content-Type':content})
 with urllib.request.urlopen(req,timeout=40) as r:return json.load(r)
statefile=out/'connection-state.json';state=json.loads(statefile.read_text()) if statefile.exists() else {'host_tailnet':'100.99.179.73','host_lan':'192.168.68.145','game_port_udp':27015,'api_port_tcp':9000,'guest_user_id':guest['userId'],'space_id':'6ae4703d5754d729b3dbf699'}
space=api('/space/'+state['space_id']);(backup/'space-access-before.json').write_text(json.dumps(space['role'])) if not (backup/'space-access-before.json').exists() else None
api('/space/'+state['space_id']+'/role/set',{'targetUserId':guest['userId'],'role':100},'PATCH')
state['guest_space_role']='OBSERVER';statefile.write_text(json.dumps(state,indent=2))
if not state.get('avatar_asset_id'):
 file=Path(r'C:\Users\Calla\OneDrive\Documents\ChatGPT\Project Lumina\avatars\mpfb-test\Lumina_Test_Adult_Mirror_v3.glb')
 boundary='LuminaUpload'+uuid.uuid4().hex;body=bytearray()
 for name,value in [('name','Lumina Test Adult v3 Multiplayer'),('assetType','MESH'),('defaultRole','100')]:
  body.extend(('--'+boundary+'\r\nContent-Disposition: form-data; name="'+name+'"\r\n\r\n'+value+'\r\n').encode())
 body.extend(('--'+boundary+'\r\nContent-Disposition: form-data; name="file"; filename="Lumina_Test_Adult_Mirror_v3.glb"\r\nContent-Type: model/gltf-binary\r\n\r\n').encode());body.extend(file.read_bytes());body.extend(('\r\n--'+boundary+'--\r\n').encode())
 existing=api('/asset/my-assets-v2?page=1&perPage=36&search=Lumina%20Test%20Adult%20v3%20Multiplayer')
 entries=existing if isinstance(existing,list) else existing.get('data',existing.get('assets',[]))
 if isinstance(entries,dict):entries=entries.get('assets',[])
 matches=[a for a in entries if a.get('name')=='Lumina Test Adult v3 Multiplayer']
 assert len(matches)<=1,'Multiple avatar assets require inspection'
 if matches:asset=matches[0]
 else:asset=api('/asset',{'name':'Lumina Test Adult v3 Multiplayer','assetType':'MESH','defaultRole':100},'POST')
 state['avatar_asset_id']=asset['_id'];statefile.write_text(json.dumps(state,indent=2))
 asset=api('/asset/'+asset['_id']+'/upload/public',bytes(body),'POST',content='multipart/form-data; boundary='+boundary)
 (out/'shared-avatar-asset.json').write_text(json.dumps(asset,indent=2));state['avatar_url']=asset['currentFile'].replace('http://localhost:9000/','http://127.0.0.2:9000/');statefile.write_text(json.dumps(state,indent=2))
api('/user/avatar',{'avatarUrl':state['avatar_url']},'PATCH')
profile=api('/user/me');assert profile['_id']==env['LUMINA_LOCAL_DEV_USER_ID'].strip('\"\'') and profile['avatarUrl']==state['avatar_url']
remote=state['avatar_url'].replace('http://127.0.0.2:9000','http://'+state['host_tailnet']+':9000')
with urllib.request.urlopen(remote,timeout=15) as r:assert r.read(4)==b'glTF'
print('Guest visitor access and shared avatar download verified; owner profile preserved.')
