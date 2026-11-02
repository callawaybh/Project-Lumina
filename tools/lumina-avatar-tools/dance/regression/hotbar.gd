extends Control
const HotbarSlot=preload("res://hotbar_slot.gd")
const ZoneClass=preload("res://zone_class.gd")
const GameMode=preload("res://game_mode.gd")


signal hotbar_asset_selected(asset_id: String)

@onready var slots_parent = $PanelContainer/HBoxContainer/MarginContainer/Slots

var _creator_ui = null
var _current_game_mode: ZoneClass.ZONE_MODE = ZoneClass.ZONE_MODE.EDIT
var _slots: Array = []
var _currently_selected_slot: HotbarSlot = null
var _last_build_mode_tool_slot: HotbarSlot = null
var _persistent_hotbar: bool = false
var _reserved_slot_equipment: String = ""


func setup(creator_ui: Control) -> void:
	_creator_ui = creator_ui


func _ready() -> void:
	for slot in slots_parent.get_children():
		var index = slot.get_index()
		_slots.append(slot)
		slot.get_node(^"Text").text = str(index + 1)
		slot.slot_pressed.connect(_on_slot_pressed)
		slot.slot_updated.connect(_on_slot_updated)
	if _slots.size() > 1:
		_slots[0].set_action(&"dance_twerk", load("res://dance_icon.svg"), "Dance")
		select_slot(_slots[0])
	else:
		push_error("We have no slots on ready for hotbar.gd")
	Zone.script_network_sync.variables_ready.connect(_space_vars_loaded)
	Zone.script_network_sync.global_variable_changed.connect(_space_var_updated)
	Zone.mode_changed.connect(_on_mode_changed)


func _input(input_event: InputEvent) -> void:
	if not visible or (Zone.is_in_edit_mode() and _creator_ui.is_mouse_needed_for_ui()):
		return
	if GameUI.instance.is_keyboard_needed_for_ui() or GameUI.instance.is_mouse_needed_for_ui():
		return
	# Ignore key-repeat so holding 1 cannot repeatedly toggle the action.
	if input_event is InputEventKey and input_event.pressed and not input_event.echo:
		# Number keys select tools only while the build tools are active.
		if Zone.is_in_edit_mode() and _creator_ui.is_game_mode(GameMode.Mode.BUILD): return
		if input_event.ctrl_pressed or input_event.alt_pressed or input_event.meta_pressed: return
		match input_event.keycode:
			KEY_1:
				_activate_slot(_slots[0])
			KEY_2:
				_activate_slot(_slots[1])
			KEY_3:
				_activate_slot(_slots[2])
			KEY_4:
				_activate_slot(_slots[3])
			KEY_5:
				_activate_slot(_slots[4])
			KEY_6:
				_activate_slot(_slots[5])
			KEY_7:
				_activate_slot(_slots[6])
			KEY_8:
				_activate_slot(_slots[7])
			KEY_9:
				_activate_slot(_slots[8])


func add_equipable(asset_id: String) -> void:
	var chosen_slot: HotbarSlot = null
	for slot in _slots:
		if slot.action_id.is_empty() and slot.asset_id.is_empty():
			chosen_slot = slot
			break
	if not chosen_slot:
		chosen_slot = _currently_selected_slot if _currently_selected_slot and _currently_selected_slot.action_id.is_empty() else _slots[1]
	chosen_slot.set_slot(asset_id)


func clear_equipables() -> void:
	_reserved_slot_equipment = ""
	for slot in _slots:
		slot.clear_slot_no_emit()
	_refresh_selected_slot()


func clear_equipables_no_emit() -> void:
	_reserved_slot_equipment = ""
	for slot in _slots:
		slot.clear_slot_no_emit()


func set_equipables(items: Dictionary = {}) -> void:
	if Zone.is_host() or not PlayerData.has_local_player():
		return
	clear_equipables_no_emit()
	_reserved_slot_equipment = str(items.get(0, ""))
	for slot in _slots:
		var index = slot.get_index()
		if slot.action_id.is_empty() and items.has(index):
			slot.set_slot(items[index])
	# Preserve any old saved item displaced by the newly reserved action slot.
	if not _reserved_slot_equipment.is_empty():
		for slot in _slots:
			if slot.action_id.is_empty() and slot.asset_id.is_empty():
				var displaced = _reserved_slot_equipment
				_reserved_slot_equipment = ""
				slot.set_slot(displaced)
				break


func save_equipables() -> void:
	if Zone.is_host() or not PlayerData.has_local_player():
		return
	var items: Dictionary = {}
	# A full legacy hotbar keeps its old first item saved until another slot is free.
	if not _reserved_slot_equipment.is_empty(): items[0] = _reserved_slot_equipment
	for slot in _slots:
		if not slot.asset_id.is_empty():
			items[slot.get_index()] = slot.asset_id
	var local_player = PlayerData.get_local_player()
	var data_store_value: String = "saved_build_items"
	if _current_game_mode == ZoneClass.ZONE_MODE.PLAY:
		data_store_value = "saved_play_items"
	local_player.save_equipables.rpc_id(Zone.SERVER_PEER_ID, data_store_value, items)


func load_equipables() -> void:
	if Zone.is_host() or not PlayerData.has_local_player():
		return
	var local_player = PlayerData.get_local_player()
	match _current_game_mode:
		ZoneClass.ZONE_MODE.EDIT:
			set_equipables(local_player.data_store.get_value("saved_build_items", {}))
			select_slot(_last_build_mode_tool_slot)
		ZoneClass.ZONE_MODE.PLAY:
			if _persistent_hotbar:
				set_equipables(local_player.data_store.get_value("saved_play_items", {}))
			else:
				clear_equipables_no_emit()
			_last_build_mode_tool_slot = _currently_selected_slot
			select_slot(_slots[0])


func select_slot(selected_slot: Panel) -> void:
	if not selected_slot:
		return
	for slot in _slots:
		slot.deselect()
	selected_slot.select()
	_currently_selected_slot = selected_slot
	hotbar_asset_selected.emit(_currently_selected_slot.asset_id)


func _refresh_selected_slot() -> void:
	if _currently_selected_slot == null:
		hotbar_asset_selected.emit("")
	else:
		hotbar_asset_selected.emit(_currently_selected_slot.asset_id)


func _on_mode_changed(new_zone_mode: ZoneClass.ZONE_MODE) -> void:
	_current_game_mode = new_zone_mode
	load_equipables()


func _on_slot_pressed(slot: HotbarSlot) -> void:
	_activate_slot(slot)


func _on_slot_updated(slot: HotbarSlot) -> void:
	if slot == _currently_selected_slot:
		hotbar_asset_selected.emit(slot.asset_id)
	save_equipables()


func _set_persistent_hotbar() -> void:
	var persistent = Zone.script_network_sync.get_global_variable("persistent_hotbar")
	if persistent is bool:
		_persistent_hotbar = persistent
		return
	# Default to false.
	Zone.script_network_sync.set_global_variable("persistent_hotbar", false)


func _space_var_updated(variable_name: String, _variable_value: Variant) -> void:
	if variable_name == "persistent_hotbar":
		_set_persistent_hotbar()


func _space_vars_loaded() -> void:
	_set_persistent_hotbar()


func _activate_slot(slot: HotbarSlot) -> void:
	select_slot(slot)
	if not PlayerData.has_local_player(): return
	var player = PlayerData.get_local_player()
	if slot.action_id == &"dance_twerk":
		player.request_dance_toggle()
	else:
		player.request_dance_stop()

func _process(_delta: float) -> void:
	if _slots.is_empty() or not PlayerData.has_local_player(): return
	var player = PlayerData.get_local_player()
	_slots[0].set_action_active(player.dance_active)
