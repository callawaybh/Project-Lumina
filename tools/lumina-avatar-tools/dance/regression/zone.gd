extends Node
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
