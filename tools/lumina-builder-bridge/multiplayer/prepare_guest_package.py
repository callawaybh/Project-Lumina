from pathlib import Path
import shutil,json,os,re,hashlib,zipfile,time
repo=Path(r'C:\Dev\LuminaClient');source=repo/'mirror-godot-app';out=Path(r'C:\Users\Calla\OneDrive\Documents\ChatGPT\Project Lumina\multiplayer-setup');bundle=out/'Lumina-Guest-Windows';game=bundle/'Game';bundle.mkdir(exist_ok=True)
state=json.loads((out/'connection-state.json').read_text());guest=json.loads((source/'.lumina-bridge/multiplayer-backup/test-player.json').read_text())
# Source distribution uses the already built custom engine and existing imported resources.
# No export/build step can accidentally bake the owner's active ProjectSettings into a pack.
def ignore(directory,names):
 rel=Path(directory).relative_to(source)
 blocked={n for n in names if (n.endswith('.import') and not (Path(directory)/n[:-7]).is_file()) or n.startswith('.') or n in ['override.cfg','export_presets.cfg'] or n.endswith(('.log','.tmp','.bak','.pem','.key','.pfx','.p12'))}
 if str(rel).replace('\\','/')=='addons/mirror_internal':blocked.add('env_configs')
 return blocked
shutil.copytree(source,game,ignore=ignore,dirs_exist_ok=True)
cache=game/'.godot';cache.mkdir(exist_ok=True)
shutil.copytree(source/'.godot/imported',cache/'imported',dirs_exist_ok=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg','scene_groups_cache.cfg']:
 if (source/'.godot'/name).exists():shutil.copy2(source/'.godot'/name,cache/name)
shutil.copy2(repo/'godot-engine/bin/godot.windows.editor.x86_64.exe',bundle/'Lumina.exe')
# Retain ordinary client feature settings, but never host secrets/integration accounts.
text=(source/'override.cfg').read_text();sections={};section=''
for line in text.splitlines():
 if line.startswith('['):section=line[1:-1];sections.setdefault(section,[])
 elif '=' in line and section in ['feature_flags','debug_flags','firebase']:
  key=line.split('=',1)[0]
  if key not in ['os_shell']:sections[section].append(line)
sections['feature_flags']=[l for l in sections.get('feature_flags',[]) if not l.startswith(('always_spin_up_local_server=','check_version_on_start='))]+['always_spin_up_local_server=false','check_version_on_start=false']
sections['app_protocol']=['enable_app_protocol=true','protocol_name="lumina-guest-test"','socket_name="LuminaGuestTest"']
sections['mirror']=[
 'env_name="local"','local_dev_auth_enabled=true','local_dev_auth_token='+json.dumps(guest['token']),
 'local_dev_user_id='+json.dumps(guest['userId']),'local_dev_peer_tokens={}',
 'local_dev_server_host='+json.dumps(state['host_tailnet']),'local_dev_join_space='+json.dumps(state['space_id']),
 'connection_server="http://'+state['host_tailnet']+':9000"','connection_server_ws="ws://'+state['host_tailnet']+':9000"',
 'zone_server_port=27015','test_accounts=[]','integration_test_acct={}','integration_test_ids=[]','posthog_api_key=""','mixpanel_api_key=""','auto_updater_bucket_uri=""']
sections['mirror_secrets']=['WSS_SECRET=""']
sections['application']=['run/max_fps=60','config/name="Lumina Guest Test"','config/use_custom_user_dir=true','config/custom_user_dir_name="LuminaGuestTest"']
sections['threading']=['worker_pool/max_threads=2']
override='\n\n'.join('['+k+']\n'+'\n'.join(v) for k,v in sections.items())+'\n'
(game/'override.cfg').write_text(override)
configs=game/'addons/mirror_internal/env_configs';configs.mkdir(exist_ok=True);(configs/'local.cfg').write_text(override)
(bundle/'Join Nightclub.cmd').write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" "%~dp0Lumina.exe" --path "%~dp0Game" --uri "themirror://space/'+state['space_id']+'"\r\n',newline='')
(bundle/'READ ME FIRST.txt').write_text('''LUMINA: TWO-PLAYER NIGHTCLUB TEST

On the host PC:
1. Stop the current game and press F5 again to load guest login support.
2. Enter luminara1 as usual. Keep that game open while the guest is playing.

On the second Windows PC:
1. Connect Tailscale to the same tailnet as The_Beast.
2. Extract the entire ZIP into a normal local folder (do not run inside the ZIP).
3. Double-click Join Nightclub.cmd.
4. The app signs in as Lumina Guest and joins the existing nightclub automatically.
5. Confirm both players can see each other. Press 1 to dance; walk to stop.

The first visit downloads the club models and textures. Allow time for loading.
No Docker, Godot editor installation, Blender, email/password, router changes,
or second backend is required on the guest PC. Do not press F5 on the guest PC.
This client uses its own saved-settings folder and a visitor account. The guest
uses the default astronaut avatar so the two players are easy to distinguish.

Host connection: 100.99.179.73 (Tailscale)
Game: UDP 27015. Data/assets: TCP 9000.
The host must stay in the nightclub; closing its game also stops the local host.
If connection fails, confirm both Tailscale clients are connected and the host
has restarted since this package was prepared. Keep any error text or screenshot.

This package contains a test-player credential for your private test. Share it
only with the intended tester. It contains no owner login or server credentials.
The bundled engine includes the native physics fix, dances and nightclub effects.
Live two-computer verification is still pending.
''')
# Scan every delivered file for the exact private credentials, not generic public client API keys.
protected=[json.loads((source/'.lumina-bridge/multiplayer-backup/owner-profile-before.json').read_text())['_id']]
ownerconfig=(source/'override.cfg').read_text();secrets=[]
for line in ownerconfig.splitlines():
 if line.startswith(('local_dev_auth_token=','WSS_SECRET=')):
  value=line.split('=',1)[1].strip().strip('"')
  if value:secrets.append(value.encode())
secrets.append((repo/'mirror-web-server/.env').read_bytes())
count=0;total=0
for p in bundle.rglob('*'):
 if p.is_file():
  raw=p.read_bytes();assert all(secret not in raw for secret in secrets),'Private credential found: '+str(p.relative_to(bundle));count+=1;total+=len(raw)
assert not (game/'.lumina-bridge').exists()
assert 'always_spin_up_local_server=false' in override
manifest={'file_count':count,'uncompressed_mib':round(total/1024**2,1),'owner_and_server_credentials_excluded':True,'host':state['host_tailnet'],'guest_user_id':guest['userId'],'space_id':state['space_id'],'engine_sha256':hashlib.sha256((bundle/'Lumina.exe').read_bytes()).hexdigest()}
(out/'package-manifest.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
