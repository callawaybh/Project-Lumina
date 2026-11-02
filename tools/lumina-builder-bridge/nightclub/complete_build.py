"""Complete approved nightclub through native builder actions; safe explicit resume points."""
from pathlib import Path
import sys,json,math,time,shutil
import build_shell as b
MODELS=json.loads((b.HERE/'models/manifest.json').read_text());PLAN=[]
def add(stage,name,model,pos,yaw=0,collision=True,group=None):
    PLAN.append(dict(stage=stage,name='LAD.S%02d.'%stage+name,model=model,position=pos,rotation=[0,yaw,0],collision=collision,group=group or 'LAD.S%02d'%stage))
f=.005;vip=.405;stage=.805
add(4,'BarCounter.001','bar_counter',[-12.1,f,2.5],group='LAD.S04.Bar')
add(4,'Backbar.001','backbar',[-15.55,f,2.5],group='LAD.S04.Bar')
for i,z in enumerate([-4,-1.5,1,3.5,6,8.5],1):add(4,'Stool.%03d'%i,'stool',[-10.3,f,z],-math.pi/2,group='LAD.S04.Bar')
for i,z in enumerate([-4.5,0,4.5,9],1):
    add(5,'SocialSofa.%03d'%i,'sofa',[14.7,f,z],-math.pi/2,group='LAD.S05.SocialLounge')
    add(5,'SocialTable.%03d'%i,'table',[11.8,f,z],group='LAD.S05.SocialLounge')
    add(8,'SocialTableDetails.%03d'%i,'table_details',[11.8,.525,z],collision=False,group='LAD.S08.Details')
for i,x in enumerate([-11.5,11.5],1):
    add(5,'VIPSofa.%03d'%i,'sofa',[x,vip,-16.25],group='LAD.S05.VIPSeating')
    add(5,'VIPTable.%03d'%i,'table',[x,vip,-13.7],group='LAD.S05.VIPSeating')
    add(5,'VIPChair.%03d'%i,'armchair',[-14.4 if x<0 else 14.4,vip,-13.5],math.pi/2 if x<0 else -math.pi/2,group='LAD.S05.VIPSeating')
    add(8,'VIPTableDetails.%03d'%i,'table_details',[x,.925,-13.7],collision=False,group='LAD.S08.Details')
add(6,'DJBackdrop.001','dj_backdrop',[0,stage,-17.55],collision=False,group='LAD.S06.DJBooth')
add(6,'DJConsole.001','dj_console',[0,stage,-14.4],group='LAD.S06.DJBooth')
for i,x in enumerate([-4.75,4.75],1):add(6,'Speaker.%03d'%i,'speaker',[x,stage,-16.25],group='LAD.S06.DJBooth')
add(6,'Crescent.001','crescent',[0,4.45,-17.32],collision=False,group='LAD.S06.DJBooth')
add(6,'StageLightbars.001','stage_lightbars',[0,stage,-17.32],collision=False,group='LAD.S06.DJBooth')
add(6,'FrontSign.001','club_sign',[0,4.5,20.04],collision=False,group='LAD.S06.Entry')
add(6,'LobbySign.001','club_sign',[0,4.5,19.5],math.pi,False,'LAD.S06.Entry')
add(6,'ExitSign.001','exit_sign',[0,3.7,19.48],math.pi,False,'LAD.S06.Entry')
add(6,'EntranceTrim.001','entry_trim',[0,f,20.04],collision=False,group='LAD.S06.Entry')
add(7,'LightingRig.001','lighting_rig',[0,0,0],collision=False,group='LAD.S07.Lighting')
add(8,'StepMarkers.001','step_markers',[0,0,0],collision=False,group='LAD.S08.Details')
add(8,'WallAccents.001','wall_accents',[0,0,0],collision=False,group='LAD.S08.Details')
for i,(x,y,z) in enumerate([(-13.8,f,16),(13.8,f,16),(-14.7,vip,-16.25),(14.7,vip,-16.25)],1):add(8,'Plant.%03d'%i,'plant',[x,y,z],collision=False,group='LAD.S08.Details')
PLAN.sort(key=lambda p:p['stage'])
ENV={'skyTopColor':[.065,.075,.12],'skyHorizonColor':[.10,.075,.12],'skyBottomColor':[.06,.045,.065],'sunCount':0,'suns':[], 'fogEnabled':False,'fogVolumetric':False,'globalIllumination':False,'ssao':True,'ssr':False,'glow':True,'glowHdrThreshold':.8}

def bounds(item):
    m=MODELS[item['model']]['bounds'];lo=m['position'];size=m['size'];yaw=item['rotation'][1];points=[]
    for x in [lo[0],lo[0]+size[0]]:
        for y in [lo[1],lo[1]+size[1]]:
            for z in [lo[2],lo[2]+size[2]]:points.append([item['position'][0]+x*math.cos(yaw)+z*math.sin(yaw),item['position'][1]+y,item['position'][2]-x*math.sin(yaw)+z*math.cos(yaw)])
    return {'position':[min(p[i] for p in points) for i in range(3)],'size':[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]}

def preflight(new=True):
    b.preflight()
    status=b.command({'action':'status'})[0]
    if new:assert 'prepared_models' in status['capabilities'],'Running client must load finishing extension'
    assert not b.state.get('pending_request'),'Inspect unresolved mutation before continuing'
    live=b.command({'action':'list_objects'})[0]['objects']
    assert {o['id'] for o in live}=={b.MAP}|{o['object_id'] for o in b.state['club_objects']},'Unexpected inventory: inspect before building'

def prepare():
    preflight(False)
    (b.HERE/'pre-finishing-snapshot.json').write_text(json.dumps({'space':b.api('/space/'+b.SPACE),'objects':b.api('/space-object/space/'+b.SPACE),'state':b.state},indent=2))
    target=b.PROJECT/'.lumina-bridge/models';target.mkdir(exist_ok=True)
    for file in (b.HERE/'models').iterdir():shutil.copy2(file,target/file.name)
    b.state.update(status='finishing_prepared_awaiting_bridge_reload',current_stage=4,authorized_scope='User explicitly authorized completing the entire remaining nightclub build without stage-by-stage inspections. Preserve shell, ground and circulation; no publishing or access restriction changes.')
    b.state['stage_reviews_required']=False
    b.state['stage_3_checks']['inspection_waived']=True
    b.state['finishing_plan']={'parts':PLAN,'models':MODELS,'environment':ENV,'music':'Original generated 16-second soft house loop, 18 percent native audio volume; client autoplay is not phase-synchronized multiplayer playback.'}
    b.state['pending_decisions']=['User restart to load validated finishing bridge if live reload unavailable','Final walkthrough, seating/stair use, audio and reload verification','Two-player test when available']
    b.save();b.log('User authorized full remaining build without per-stage reviews. Prepared 22 validated GLB modules and an original loop; narrow native import/environment/inspection bridge extension passed script scan. Complete bar, seating, DJ/crescent/signs, emissive replacements, eleven shadow-free lights, details and native audio. No publish/access changes.')
    print('Prepared complete build:',len(PLAN),'new mesh objects plus audio; replacement of eight existing accent objects.',flush=True)

def verify(entry):
    spec=MODELS[entry['model']]
    saved=b.api('/space-object/'+entry['object_id'])
    asset=saved.get('asset');asset=asset.get('_id') if isinstance(asset,dict) else asset
    assert asset==entry['asset_id'],(asset,entry['asset_id'])
    assert saved['bodyType']=='Static' and saved.get('collisionEnabled',True)==entry['collision']
    for key in ['position','rotation','scale']:
        assert all(abs(a-c)<.002 for a,c in zip(saved[key],entry[key])),(key,saved[key],entry[key])
    # Native peer transforms quantize angles (pi arrives as 3.140625 radians).
    # Verify that rounding is small, then derive expected mesh bounds from the actual pose.
    live=next(o for o in b.command({'action':'list_objects'})[0]['objects'] if o['id']==entry['object_id'])
    for key in ['position','rotation','scale']:
        assert all(abs(math.remainder(a-c,math.tau) if key=='rotation' else a-c)<.002 for a,c in zip(live[key],entry[key])),(entry['name'],key,live[key],entry[key])
    expected=bounds(dict(entry,position=live['position'],rotation=live['rotation']))
    entry['runtime_transform']={key:live[key] for key in ['position','rotation','scale']}
    for attempt in range(15):
        result=b.command({'action':'inspect_object','object_id':entry['object_id']})[0]
        livebounds=result.get('bounds',{})
        if result['meshes']>=1 and result['seats']==spec['seats'] and len(result['lights'])==spec['lights'] and result['emissive_surfaces']==spec['emissive_surfaces'] and livebounds and all(abs(a-c)<.005 for k in ['position','size'] for a,c in zip(livebounds[k],expected[k])):break
        time.sleep(1)
    else:raise AssertionError((entry['name'],result,expected,spec))
    assert all(not light['shadow'] and 0<light['energy']<=3 for light in result['lights'])
    assert result['body_type']=='Static' and result['collision_enabled']==entry['collision']
    entry.update(verified_saved=True,bounds=livebounds,feature_verification=result);b.save()

def create(item):
    assert not any(o['name']==item['name'] for o in b.state['club_objects']),'Object already recorded; verify, do not replay'
    b.state['current_stage']=item['stage'];b.state['status']='finishing_building';b.save()
    source=next((o for o in b.state['club_objects'] if o.get('model')==item['model'] and o.get('collision')==item['collision'] and o.get('rotation')==item['rotation'] and o.get('verified_saved')),None)
    if source:
        payload={'action':'duplicate_object','object_id':source['object_id'],'name':item['name'],'offset':[a-c for a,c in zip(item['position'],source['position'])]}
    else:payload={'action':'create_model','space_id':b.SPACE,'file':MODELS[item['model']]['file'],'name':item['name'],'position':item['position'],'rotation':item['rotation'],'collision_enabled':item['collision']}
    result,receipt=b.command(payload,True)
    entry=dict(item,object_id=result['object_id'],asset_id=result['asset_id'],scale=[1,1,1],source_receipt=receipt,verified_saved=False)
    b.state['club_objects'].append(entry);b.save()
    if source and source['rotation']!=item['rotation']:
        update,rotation_receipt=b.command({'action':'update_object','object_id':entry['object_id'],'changes':{'rotation':item['rotation']}},True)
        entry['rotation_receipt']=rotation_receipt;b.save()
    verify(entry);b.log('Created '+entry['name']+' object '+entry['object_id']+', asset '+entry['asset_id']+', receipt '+receipt+'; native saved geometry/features verified.')
    print(json.dumps({'created':entry['name'],'saved':True}),flush=True)

def replacement():
    # This Mirror revision refreshes cached model replacements in the wrong order.
    # Fresh native instances correctly import emission; retain an exact before snapshot.
    assert not b.state.get('accent_replacement_completed'),'Accent replacement already finished'
    old_entries=[o for o in b.state['club_objects'] if o['stage']==2 and ('.Border' in o['name'] or '.Inset.' in o['name'])]
    assert len(old_entries)==8
    for old in old_entries:
        name=old['name']
        if '.BorderLeft.' in name or '.BorderRight.' in name:model='border_side'
        elif '.BorderRear.' in name or '.BorderFront.' in name:model='border_end'
        elif '.Inset.001' in name or '.Inset.002' in name:model='inset_red'
        else:model='inset_violet'
        newname=name.replace('LAD.S02.','LAD.S07.Glow')
        item={'stage':7,'name':newname,'model':model,'position':old['position'],'rotation':old['rotation'],'collision':True,'group':'LAD.S07.DanceAccents'}
        existing=next((o for o in b.state['club_objects'] if o['name']==newname),None)
        if existing:verify(existing)
        else:create(item)
    old_ids=[o['object_id'] for o in old_entries]
    result,receipt=b.command({'action':'delete_objects','space_id':b.SPACE,'object_ids':old_ids},True)
    b.state.setdefault('superseded_objects',[]).extend(old_entries)
    b.state['club_objects']=[o for o in b.state['club_objects'] if o['object_id'] not in old_ids]
    for group in b.state['club_groups']:group['object_ids']=[i for i in group['object_ids'] if i not in old_ids]
    b.state['accent_replacement_completed']={'deleted_original_ids':old_ids,'receipt':receipt,'backup':result['backup']}
    b.save();b.log('Live cached-asset refresh bug detected by emission inspection. Created eight fresh verified emissive accent instances, removed exactly eight superseded originals through native delete, retained archived IDs and backup '+result['backup']+'. Original DanceFloor group now retains base surface; glow accents use a separate stage-seven group.')
    print('Eight emissive accents verified; superseded originals removed',flush=True)

def groups():
    for name in dict.fromkeys(o.get('group') for o in b.state['club_objects'] if o.get('group')):
        assert not any(g['name']==name for g in b.state['club_groups']),'Group already exists; verify, do not replay'
        members=[o['object_id'] for o in b.state['club_objects'] if o.get('group')==name]
        result,receipt=b.command({'action':'create_group','name':name,'object_ids':members},True)
        b.state['club_groups'].append({'group_id':result['group_id'],'name':name,'object_ids':members,'stage':next(o['stage'] for o in b.state['club_objects'] if o.get('group')==name),'source_receipt':receipt});b.save()
        print('Saved group '+name,flush=True)

def environment():
    assert not b.state.get('finishing_environment'),'Already recorded; verify, do not replay'
    result,receipt=b.command({'action':'set_environment','space_id':b.SPACE,'changes':ENV},True)
    b.state['finishing_environment']={'changes':ENV,'receipt':receipt,'backup':result['backup']};b.save();print('Saved nightclub environment',flush=True)

def audio():
    assert not any(o.get('audio') for o in b.state['club_objects'])
    result,receipt=b.command({'action':'create_audio','space_id':b.SPACE,'file':'lumina_original_loop.wav','name':'LAD.S09.Music.001','position':[0,2,-14],'rotation':[0,0,0],'collision_enabled':False},True)
    entry={'name':'LAD.S09.Music.001','stage':9,'object_id':result['object_id'],'asset_id':result['asset_id'],'source_receipt':receipt,'audio':True,'position':[0,2,-14],'rotation':[0,0,0],'scale':[1,1,1],'verified_saved':False}
    b.state['club_objects'].append(entry);b.save()
    saved=b.api('/space-object/'+entry['object_id'])
    for k,v in {'audioAutoPlay':True,'audioLoop':True,'audioIsSpatial':False,'audioBaseVolume':18,'collisionEnabled':False}.items():assert saved[k]==v,(k,saved.get(k))
    entry['verified_saved']=True;b.save();print('Original loop saved with native autoplay/loop settings',flush=True)

def finish():
    preflight()
    for entry in b.state['club_objects']:
        if entry.get('model'):verify(entry)
        elif not entry.get('audio'):b.verify_object(entry)
    saved=b.api('/space-object/space/'+b.SPACE)
    assert {o['_id'] for o in saved}=={b.MAP}|{o['object_id'] for o in b.state['club_objects']}
    s=b.api('/space/'+b.SPACE);g=json.loads(s['customData']['data']['luminaBuilderGroups'])
    assert set(g)=={i['group_id'] for i in b.state['club_groups']}
    for group in b.state['club_groups']:assert set(g[group['group_id']]['object_ids'])==set(group['object_ids'])
    for k,v in ENV.items():assert s['environment'][k]==v
    b.state.update(status='build_saved_awaiting_final_walkthrough',current_stage=9)
    b.state['construction_stages_saved']=list(range(1,10))
    b.state['final_checks']={'native_saved_inventory_verified':True,'native_saved_groups_verified':True,'models_materials_seats_lights_verified':True,'native_audio_settings_verified':True,'user_walkthrough':False,'reload_verified':False,'multiplayer_verified':False,'music_phase_synchronized':False,'publishing_changed':False}
    b.state['pending_decisions']=['Final user walkthrough: seating, stairs, lighting and music','User reload then persistence verification','Two-player test when available; audio loops autoplay independently']
    b.save();b.log('All nine construction stages saved through native bridge. Final native inventory/groups/environment and model material/seat/light features verified. Original music autoplay/loop configured; audio is not phase-synchronized. User walkthrough/reload/two-player checks remain; no publishing/access changes.')
    (b.HERE/'completed-build-snapshot.json').write_text(json.dumps({'state':b.state,'space':s,'objects':saved},indent=2))
    print('BUILD_SAVED_FINAL_WALKTHROUGH_PENDING',len(saved),'objects',len(g),'groups',flush=True)

if __name__=='__main__':
    phase=sys.argv[1]
    if phase=='prepare':prepare()
    elif phase=='prototype':preflight();create(PLAN[0])
    elif phase=='rest':
        preflight()
        for item in PLAN[1:]:create(item)
    elif phase=='resume':
        preflight()
        for item in PLAN:
            existing=next((o for o in b.state['club_objects'] if o['name']==item['name']),None)
            if existing:
                if not existing.get('verified_saved'):verify(existing)
            else:create(item)
    elif phase=='materials':preflight();replacement()
    elif phase=='groups':preflight();groups()
    elif phase=='environment':preflight();environment()
    elif phase=='audio':preflight();audio()
    elif phase=='finish':finish()
