from pathlib import Path
import json,re
ROOT=Path('C:/Dev/LuminaClient/mirror-godot-app');OUT=Path('animations/dance-test/regression');OUT.mkdir(exist_ok=True)
def put(n,s): (OUT/n).write_text(s,encoding='utf-8')
put('project.godot','''config_version=5
[application]
config/name="Lumina dance isolated regression"
[autoload]
Zone="*res://zone.gd"
GameUI="*res://game_ui.gd"
PlayerData="*res://player_data.gd"
Net="*res://net.gd"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
put('zone_class.gd','extends RefCounted\nenum ZONE_MODE {EDIT,PLAY}\n')
put('game_mode.gd','extends RefCounted\nenum Mode {NORMAL,INSPECT,BUILD}\n')
put('enums.gd','extends RefCounted\nenum DownloadPriority {SPACE_OBJECT_HIGH,UI_THUMBNAILS}\n')
put('zone.gd','''extends Node
signal mode_changed(mode)
const SERVER_PEER_ID=1
class Variables:
	extends RefCounted
	signal variables_ready()
	signal global_variable_changed(name,value)
	func get_global_variable(_name): return false
	func set_global_variable(_name,_value): pass
var script_network_sync=Variables.new()
func is_host():return false
func is_in_edit_mode():return true
func is_in_play_mode():return false
''')
put('game_ui.gd','''extends Node
var instance=self
var keyboard=false
var mouse=false
func is_keyboard_needed_for_ui():return keyboard
func is_mouse_needed_for_ui():return mouse
''')
put('player_data.gd','''extends Node
class Rpc:
	extends RefCounted
	func rpc_id(_peer,_key,_items):pass
class Store:
	extends RefCounted
	func get_value(_key,default):return default
class FakePlayer:
	extends Node
	var dance_active=false
	var toggles=0
	var stops=0
	var save_equipables=Rpc.new()
	var data_store=Store.new()
	func request_dance_toggle():toggles+=1;dance_active=not dance_active
	func request_dance_stop():stops+=1;dance_active=false
var player=FakePlayer.new()
func has_local_player():return true
func get_local_player():return player
func _exit_tree():player.free()
''')
put('net.gd','''extends Node
class Assets:
	extends RefCounted
	signal asset_deleted(asset)
	func get_asset_json(id):return {"_id":id}
	func get_asset_url(_id):return ""
var asset_client=Assets.new()
''')
put('asset_data.gd','''extends RefCounted
signal preview_generated()
signal preview_downloaded()
signal files_loaded()
var type="MESH"
var is_equipable=false
var preview_texture:Texture2D
func populate(_data):pass
func try_get_preview_texture(_priority):pass
func try_download_file(_priority):pass
''')
put('creator.gd','''extends Control
var building=false
func is_mouse_needed_for_ui():return false
func is_game_mode(mode):return building and mode==2
''')
s=(ROOT/'creator/asset_inventory/hotbar/hotbar_slot.gd').read_text().replace('class_name HotbarSlot\n','')
s=s.replace('extends Panel','extends Panel\nconst AssetData=preload("res://asset_data.gd")\nconst Enums=preload("res://enums.gd")',1);put('hotbar_slot.gd',s)
s=(ROOT/'creator/asset_inventory/hotbar/hotbar.gd').read_text().replace('CreatorUI','Control').replace(': Player','').replace('_creator_ui: Control','_creator_ui')
s=s.replace('extends Control','extends Control\nconst HotbarSlot=preload("res://hotbar_slot.gd")\nconst ZoneClass=preload("res://zone_class.gd")\nconst GameMode=preload("res://game_mode.gd")',1).replace('res://player/animations/dances/dance_icon.svg','res://dance_icon.svg');put('hotbar.gd',s)
put('slot.tscn','''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://hotbar_slot.gd" id="1"]
[node name="Slot" type="Panel"]
script=ExtResource("1")
[node name="Preview" type="TextureRect" parent="."]
[node name="IsEquipable" type="TextureRect" parent="."]
[node name="Text" type="Label" parent="."]
[node name="Outline" type="Panel" parent="."]
''')
s=(ROOT/'player/animations/dances/lumina_dance.gd').read_text().replace('class_name LuminaDance\n','').replace('res://player/animations/dances/dance_twerk.tres','C:/Dev/LuminaClient/mirror-godot-app/player/animations/dances/dance_twerk.tres');put('lumina_dance.gd',s)
# Use actual production animation graph with a minimal canonical skeleton and stand-in locomotion clips.
source=(ROOT/'player/animations/animation_controller.tscn').read_text()
animations=sorted(set(re.findall(r'animation = &"humanoid_animations/([^\"]+)"',source)))
library=['[gd_resource type="AnimationLibrary" load_steps=%d format=3]'%(len(animations)+1)]
for i,name in enumerate(animations):library += [f'[sub_resource type="Animation" id="a{i}"]','length=1.0','loop_mode=1']
library+=['[resource]','_data={'+','.join('"%s":SubResource("a%d")'%(n,i) for i,n in enumerate(animations))+'}'];put('locomotion.tres','\n'.join(library))
ref=json.loads(Path('avatars/mpfb-test/compatibility/rig-comparison.json').read_text())['reference']['bones'];bones=list(ref)
rig=['[gd_scene format=3]','[node name="default_model" type="Node3D"]','[node name="Armature" type="Node3D" parent="."]','[node name="Skeleton3D" type="Skeleton3D" parent="Armature"]']
for i,name in enumerate(bones):
    b=ref[name];rig += [f'bones/{i}/name="{name}"',f'bones/{i}/parent={bones.index(b["parent"]) if b["parent"] else -1}',f'bones/{i}/enabled=true',f'bones/{i}/position=Vector3('+','.join(map(str,b['position']))+')',f'bones/{i}/rotation=Quaternion('+','.join(map(str,b['rotation']))+')',f'bones/{i}/scale=Vector3(1,1,1)']
put('rig.tscn','\n'.join(rig))
lines=[]
for line in source.splitlines():
    if '[ext_resource type="Script"' in line or line.startswith('script = '):continue
    if '[ext_resource type="PackedScene"' in line:line='[ext_resource type="PackedScene" path="res://rig.tscn" id="2_aa1ea"]'
    elif '[ext_resource type="AnimationLibrary"' in line:line='[ext_resource type="AnimationLibrary" path="res://locomotion.tres" id="2_fbv3n"]'
    elif '[ext_resource type="Animation"' in line:line=line.replace('res://player/animations/dances/','C:/Dev/LuminaClient/mirror-godot-app/player/animations/dances/')
    lines.append(line)
put('controller.tscn','\n'.join(lines))
# Extract production animation-selection functions unchanged, with only runtime dependencies supplied.
s=(ROOT/'player/animations/animation_controller.gd').read_text()
def fn(src,name):return 'func '+src.split('func '+name+'(',1)[1].join([]) if False else 'func '+name+'('+src.split('func '+name+'(',1)[1].split('\nfunc ',1)[0]
prefix='''extends RefCounted
const LuminaDance=preload("res://lumina_dance.gd")
var _animation_tree:AnimationTree
var stance="Unarmed"
var _dance_active=false
var _dance_elapsed=0.0
var _grounded=true
var _sitting=false
var _dead=false
var _running=false
var _is_aiming=false
var _movement=Vector2.ZERO
var _animation_velocity=Vector2.ZERO
'''
put('presentation.gd',prefix+fn(s,'_set_animation')+'\n'+fn(s,'set_dance_state'))
# Real DataBuffer serialization methods, isolated from rendering/physics and user sessions.
s=(ROOT/'player/player.gd').read_text();prefix='''extends RefCounted
const LuminaDance=preload("res://lumina_dance.gd")
var _input_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _hori_rotation_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _vert_rotation_compression_level=DataBuffer.COMPRESSION_LEVEL_2
var _vr_compression_level=DataBuffer.COMPRESSION_LEVEL_1
var _constant_buffer_size=-1
var _dance_intent=false
var VRManager={"vr_is_active":false}
var global_transform=Transform3D.IDENTITY
var global_position=Vector3.ZERO
class Equipment:
	func is_current_equipable_aiming():return false
var equipable_controller=Equipment.new()
func get_head_global_transform():return Transform3D.IDENTITY
func _lumina_guard(_stage,_values):return true
func get_intended_movement_direction():return Vector3.ZERO
func is_intent_to_run():return false
func is_intent_to_jump():return false
func camera_get_rotation():return Vector2.ZERO
func get_look_target():return Vector3.FORWARD
func write_pending_interactions_to_buffer(buffer):buffer.add_bool(false)
func get_current_seat_path_or_null():return null
func get_body_position():return Vector3.ZERO
func count_interactions_buffer_size(buffer):assert(not buffer.read_bool());return buffer.get_bool_size()
func are_interactions_different(a,b):return a.read_bool()!=b.read_bool()
'''
put('input_protocol.gd',prefix+'\n'.join(fn(s,n) for n in ['_collect_inputs','_count_input_size','_are_inputs_different']))
print('Prepared isolated production-logic hotbar, animation-tree and native input-buffer checks.')

import shutil
shutil.copy2(ROOT/"player/animations/dances/dance_icon.svg",OUT/"dance_icon.svg")
