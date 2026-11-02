"""Sequential native-bridge stage-one construction. Never replays an uncertain mutation."""
from pathlib import Path
import importlib.util,json,datetime,uuid,sys,urllib.request,time
ROOT=Path('C:/Dev/LuminaClient'); PROJECT=ROOT/'mirror-godot-app'
STATE=ROOT/'docs/nightclub/BUILD_STATE.json';LOG=ROOT/'docs/nightclub/BUILD_LOG.md'
HERE=Path(__file__).resolve().parent
SPACE='6ae4703d5754d729b3dbf699';MAP='6ae4703d5754d729b3dbf6a0'
CLEANUP=['6ae4aeef3860363833592e4f','6ae4aeef3860363833592e3d','6ae4808ce15a3a671ca0f9cb','6ae4aec43860363833592cd6','6ae4834ae15a3a671ca10872','6ae473145754d729b3dc0938']
COLOR=[.055,.055,.065,1]
PLAN=[
 {'name':'LAD.S01.LeftWall.001','position':[-15.85,0,0],'size':[.3,7,39.4]},
 {'name':'LAD.S01.RightWall.001','copy':'LAD.S01.LeftWall.001','offset':[31.7,0,0],'position':[15.85,0,0],'size':[.3,7,39.4]},
 {'name':'LAD.S01.RearWall.001','position':[0,0,-19.85],'size':[32,7,.3]},
 {'name':'LAD.S01.FrontLeft.001','position':[-9,0,19.85],'size':[14,7,.3]},
 {'name':'LAD.S01.FrontRight.001','copy':'LAD.S01.FrontLeft.001','offset':[18,0,0],'position':[9,0,19.85],'size':[14,7,.3]},
 {'name':'LAD.S01.EntranceHeader.001','position':[0,3.5,19.85],'size':[4,3.5,.3]},
 {'name':'LAD.S01.Roof.001','position':[0,7,0],'size':[32,.3,40]},
]
spec=importlib.util.spec_from_file_location('lumina_bridge_cli',ROOT/'tools/lumina-builder-bridge/bridge.py')
bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
state=json.loads(STATE.read_text())
def save():
    state['updated_date']='2026-11-01'
    tmp=STATE.with_suffix('.json.tmp');tmp.write_text(json.dumps(state,indent=2)+'\n');tmp.replace(STATE)
def log(message):
    with LOG.open('a') as f:f.write('\n- 2026-11-01: '+message+'\n')
def command(payload,mutation=False):
    if mutation and state.get('pending_request'):raise RuntimeError('Unresolved prior mutation; inspect receipt before proceeding')
    request_id=uuid.uuid4().hex
    if mutation:
        state['pending_request']={'id':request_id,'command':payload};save()
    result=bridge.submit(PROJECT,payload,90,request_id=request_id)
    if mutation:
        (HERE/'receipts').mkdir(exist_ok=True)
        (HERE/'receipts'/(request_id+'.json')).write_text(json.dumps({'command':payload,'result':result},indent=2))
    if not result.get('ok'):raise RuntimeError(json.dumps(result))
    if mutation:
        state.pop('pending_request',None);save()
    return result,request_id
def api(path):
    settings=dict(line.split('=',1) for line in (ROOT/'mirror-web-server/.env').read_text().splitlines() if '=' in line and not line.startswith('#'))
    token=settings['LUMINA_LOCAL_DEV_TOKEN'].strip('"\'')
    req=urllib.request.Request('http://127.0.0.2:9000'+path,headers={'Authorization':'Bearer '+token})
    with urllib.request.urlopen(req,timeout=15) as response:return json.load(response)
def preflight():
    result,_=command({'action':'status'})
    assert result['space_id']==SPACE and result['ready'] and result['edit_mode'],result
    assert 'delete_objects' in result.get('capabilities',[]),'Running client must load updated bridge first'
def verify_object(entry):
    saved=api('/space-object/'+entry['object_id'])
    assert saved.get('bodyType')=='Static' and saved.get('collisionEnabled',True),saved.get('bodyType')
    for key in ['position','rotation','scale']:
        actual=saved.get(key);expected=entry[key]
        assert actual and all(abs(a-b)<.002 for a,b in zip(actual,expected)),(key,actual,expected)
    # Spawn receipts precede completion of the temporary loading-placeholder fade.
    # Retry read-only verification, never the creation command.
    for attempt in range(12):
        listed,_=command({'action':'list_objects'})
        obj=next(o for o in listed['objects'] if o['id']==entry['object_id'])
        bounds=obj.get('bounds',{})
        if bounds and all(abs(a-b)<.02 for a,b in zip(bounds['size'],entry['size'])):
            break
        time.sleep(1)
    assert obj['body_type']=='Static' and obj['collision_enabled']
    assert bounds and all(abs(a-b)<.02 for a,b in zip(bounds['size'],entry['size'])),bounds
    expected_min=[entry['position'][i]-(entry['size'][i]/2 if i!=1 else 0) for i in range(3)]
    assert all(abs(a-b)<.02 for a,b in zip(bounds['position'],expected_min)),bounds
    entry['name']=obj['name'];entry['bounds']=bounds;entry['verified_saved']=True;save()
    return obj
def create(index):
    item=PLAN[index]
    assert not any(o['name']==item['name'] for o in state['club_objects']),'Already recorded; do not duplicate'
    current,_=command({'action':'list_objects'})
    assert not any(o['name']==item['name'] for o in current['objects']),'Already exists; inspect before creating'
    if 'copy' in item:
        source=next(o for o in state['club_objects'] if o['name']==item['copy'])
        payload={'action':'duplicate_object','object_id':source['object_id'],'name':item['name'],'offset':item['offset']}
    else:
        payload={'action':'create_primitive','name':item['name'],'shape':'box','position':item['position'],'size':item['size'],'color':COLOR}
    result,receipt=command(payload,True)
    entry={'object_id':result['object_id'],'asset_id':result['asset_id'],'name':item['name'],'stage':1,
        'position':item['position'],'rotation':[0,0,0],'scale':[1,1,1],'size':item['size'],
        'source_receipt':receipt,'verified_saved':False}
    state['club_objects'].append(entry);save() # Record IDs immediately, before follow-up checks.
    verify_object(entry);log('Created and verified '+entry['name']+'; object '+entry['object_id']+', asset '+entry['asset_id']+', receipt '+receipt+'.')
    print(json.dumps({'created':entry['name'],'id':entry['object_id'],'saved':True}),flush=True)
def phase_prepare():
    state.update(construction_authorized=True,current_stage=1,status='stage_1_preparing',world_anchor=[0,0,0],world_yaw_radians=0)
    state['authorized_scope']='Remove six confirmed non-map test objects; construct walls/roof only, then stop for inspection.'
    state['shell_plan']={'outer_size_m':[32,40],'wall_height_m':7,'wall_thickness_m':.3,'entrance_width_m':4,'entrance_height_m':3.5,'front_direction':'+Z','roof_bottom_m':7,'roof_thickness_m':.3,'parts':PLAN}
    state['cleanup_authorized_ids']=CLEANUP;state['protected_preexisting_object_ids_last_known']=[MAP]
    state['pending_decisions']=['User inspection of stage-one shell and collision','Reload verification of saved shell','Authorization for any stage after walls/roof']
    save();log('User authorized six-object cleanup, ground preservation, current-area placement, and stage-one walls/roof only. Anchor [0,0,0], front +Z. No world mutation yet.')
def phase_cleanup():
    preflight();actual=api('/space-object/space/'+SPACE)
    ids={o['_id'] for o in actual};assert ids==set(CLEANUP+[MAP]),ids
    (HERE/'before-cleanup.json').write_text(json.dumps({'objects':actual,'space':api('/space/'+SPACE)},indent=2))
    result,receipt=command({'action':'delete_objects','space_id':SPACE,'object_ids':CLEANUP},True)
    state['cleanup']={'deleted_ids':result['deleted_ids'],'source_receipt':receipt,'native_backup':result['backup'],'groups_saved':result['groups_saved']};save()
    after=api('/space-object/space/'+SPACE);assert {o['_id'] for o in after}=={MAP}
    state['status']='stage_1_building';save();log('Removed all six approved non-map objects through native delete packet, verified only ground remains; cleared their empty groups. Receipt '+receipt+'.')
    print('Cleanup saved and verified; original ground preserved.',flush=True)
def phase_finish():
    preflight()
    for item in state['club_objects']:verify_object(item)
    assert len(state['club_objects'])==7
    for name,members in [('LAD.S01.Shell',[o['object_id'] for o in state['club_objects'] if '.Roof.' not in o['name']]),('LAD.S01.Roof',[o['object_id'] for o in state['club_objects'] if '.Roof.' in o['name']])]:
        result,receipt=command({'action':'create_group','name':name,'object_ids':members},True)
        state['club_groups'].append({'group_id':result['group_id'],'name':name,'object_ids':members,'stage':1,'source_receipt':receipt});save();log('Saved group '+name+' ('+result['group_id']+').')
    final=api('/space-object/space/'+SPACE)
    assert {o['_id'] for o in final}=={MAP}|{o['object_id'] for o in state['club_objects']}
    state['status']='stage_1_awaiting_user_inspection';state['stage_1_checks']={'saved_state_verified':True,'user_walkthrough':False,'reload_verified':False};save()
    log('Stage-one shell saved: six static wall/header pieces and one static roof, ground retained, no later stages built. User walkthrough and reload remain pending.')
    print('STAGE_ONE_SAVED_AWAITING_INSPECTION',flush=True)

if __name__=='__main__':
    phase=sys.argv[1]
    if phase=='prepare':phase_prepare()
    elif phase=='cleanup':phase_cleanup()
    elif phase=='prototype':preflight();create(0)
    elif phase=='rest':
        preflight()
        for index in range(1,len(PLAN)):create(index)
    elif phase=='finish':phase_finish()
    else:raise ValueError(phase)
