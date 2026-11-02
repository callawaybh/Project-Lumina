extends Node
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
