extends Node
const Dance=preload("res://lumina_dance.gd")
var checks=0
var failures=0
func check(value:bool,message:String):
	if not value:
		push_error(message)
		failures+=1
	checks+=1
func _ready():
	call_deferred("run")
func run():
	check(Dance.can_dance(Vector2.ZERO,false,true,false,false,false,false,false),"Standing can dance")
	check(not Dance.can_dance(Vector2.RIGHT,false,true,false,false,false,false,false),"Walking cancels")
	for i in range(7):
		var args=[Vector2.ZERO,false,true,false,false,false,false,false]
		if i==1: args[2]=false
		else: args[[1,2,3,4,5,6,7][i]]=true
		check(not Dance.can_dance.callv(args),"Cancellation condition "+str(i))
	check(abs(Dance.playback_position(16.2)-1.0)<.00001,"Dance wraps")
	check(Dance.remote_elapsed(true,6.0,true,6.4,.5)>6.19,"Remote interpolates phase")
	check(Dance.remote_elapsed(true,15.0,false,0,.25)==15.0,"Stop never scrubs halfway backwards")
	var clip=Dance.CLIP
	check(clip.loop_mode==Animation.LOOP_LINEAR and clip.get_track_count()==66,"Loop/retarget tracks")
	for track in range(clip.get_track_count()):
		var count=clip.track_get_key_count(track)
		var first=clip.track_get_key_value(track,0);var last=clip.track_get_key_value(track,count-1)
		if first is Quaternion:check(abs(first.dot(last))>.99999,"Loop quaternion seam")
		else:check(first.distance_to(last)<.00001,"Loop position seam")
	# Compare actual production input serialization with the native DataBuffer.
	var protocol=load("res://input_protocol.gd").new()
	var a=DataBuffer.new();a.begin_write(0);protocol._collect_inputs(.016,a);a.dry()
	var b=DataBuffer.new();b.begin_write(0);protocol._collect_inputs(.016,b);b.dry()
	a.begin_read();b.begin_read();check(not protocol._are_inputs_different(a,b),"Equal input frames compare equal")
	protocol._dance_intent=true
	var c=DataBuffer.new();c.begin_write(0);protocol._collect_inputs(.016,c);c.dry()
	a.begin_read();c.begin_read();check(protocol._are_inputs_different(a,c),"Dance intent is transmitted as an input difference")
	c.begin_read();check(protocol._count_input_size(c)==c.size(),"Input count includes dance bit")
	a.free();b.free();c.free()
	# Round-trip the production remote snapshot with real native DataBuffers.
	var sender=load("res://snapshot_protocol.gd").new()
	var receiver=load("res://snapshot_protocol.gd").new()
	var old=DataBuffer.new();old.begin_write(0);sender.dance_elapsed=18.6;sender.trickled_sync_state_collect(old,.1);old.dry()
	var newer=DataBuffer.new();newer.begin_write(0);sender.dance_elapsed=18.8;sender.trickled_sync_state_collect(newer,.1);newer.dry()
	old.begin_read();newer.begin_read();receiver.trickled_sync_state_apply(.1,.5,old,newer)
	check(receiver.model.dance_active and abs(receiver.model.dance_elapsed-18.7)<.002,"Remote snapshot carries dance and loop-independent elapsed time")
	old.begin_read();newer.begin_read();receiver.trickled_sync_state_apply(.1,1.0,old,newer)
	check(abs(receiver.model.dance_elapsed-18.8)<.002,"Later observer can join at current phase")
	old.free();newer.free()
	# Actual production graph and selection functions: two peers and a later joiner get the same pose.
	var graph=load("res://controller.tscn")
	var poses=[];var nodes=[]
	for i in range(3):
		var node=graph.instantiate();get_tree().root.add_child(node);nodes.append(node)
		var tree:AnimationTree=node.get_node("AnimationTree");tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;tree.active=true
		var display=load("res://presentation.gd").new();display._animation_tree=tree
		display.set_dance_state(true,6.4);display._set_animation(.016);tree.advance(.3)
		check(tree.get("parameters/Stance/current_state")=="Dance","Dance branch selected")
		var skeleton:Skeleton3D=node.get_node("default_model/Armature/Skeleton3D")
		var pose=[]
		for bone in range(skeleton.get_bone_count()):
			var rotation=skeleton.get_bone_pose_rotation(bone);check(rotation.is_finite(),"Finite dance pose");pose.append(rotation)
		poses.append(pose)
		display.set_dance_state(false,0);display._set_animation(.016);tree.advance(.3)
		check(tree.get("parameters/Stance/current_state")=="Unarmed","Stop returns to locomotion")
	for i in [1,2]:
		for bone in range(poses[0].size()):check(abs(poses[0][bone].dot(poses[i][bone]))>.99999,"Peer/late join pose consistency")
	for node in nodes:node.free()
	# Actual hotbar code with service stubs; programmatic selection cannot start a dance.
	var hotbar=Control.new();hotbar.set_script(load("res://hotbar.gd"))
	var panel=PanelContainer.new();panel.name="PanelContainer";hotbar.add_child(panel)
	var box=HBoxContainer.new();box.name="HBoxContainer";panel.add_child(box)
	var margin=MarginContainer.new();margin.name="MarginContainer";box.add_child(margin)
	var slots=HBoxContainer.new();slots.name="Slots";margin.add_child(slots)
	var slot_scene=load("res://slot.tscn")
	for i in range(9):var slot=slot_scene.instantiate();slot.name="Slot"+str(i);slots.add_child(slot)
	var creator=load("res://creator.gd").new();hotbar.setup(creator);get_tree().root.add_child(hotbar)
	check(PlayerData.player.toggles==0,"Initial slot selection does not auto-dance")
	var key=InputEventKey.new();key.keycode=KEY_1;key.pressed=true;hotbar._input(key)
	check(PlayerData.player.toggles==1,"1 starts dance")
	key.echo=true;hotbar._input(key);check(PlayerData.player.toggles==1,"Held key cannot toggle repeatedly")
	key.echo=false;hotbar._input(key);check(PlayerData.player.toggles==2,"Second 1 stops dance")
	GameUI.keyboard=true;hotbar._input(key);check(PlayerData.player.toggles==2,"Typing never dances");GameUI.keyboard=false
	creator.building=true;hotbar._input(key);check(PlayerData.player.toggles==2,"Build tools retain 1");creator.building=false
	var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
	var first=hotbar._slots[0];first._gui_input(down);first._gui_input(up);check(PlayerData.player.toggles==3,"One click toggles once")
	check(not first._can_drop_data(Vector2.ZERO,{"asset_id":"example"}),"Equipment cannot overwrite action")
	hotbar.clear_equipables_no_emit();check(first.action_id==&"dance_twerk" and first.preview.texture!=null,"Dance survives equipment reset")
	hotbar.set_equipables({0:"displaced-item"});check(hotbar._slots[1].asset_id=="displaced-item","Existing first-slot item preserved in slot 2")
	var full={0:"old-first"}
	for i in range(1,9):full[i]="saved-"+str(i)
	hotbar.set_equipables(full)
	check(hotbar._reserved_slot_equipment=="old-first","Full old hotbar retains displaced item")
	for i in range(1,9):check(hotbar._slots[i].asset_id=="saved-"+str(i),"No old equipment overwritten")
	hotbar.free();creator.free()
	if failures:
		print("LUMINA_DANCE_REGRESSION_FAIL: ",failures);get_tree().quit(1);return
	print("LUMINA_DANCE_REGRESSION_PASS: ",checks," checks; input protocol, loop, peer/late-join pose, cancellation and hotbar behavior")
	get_tree().quit()
