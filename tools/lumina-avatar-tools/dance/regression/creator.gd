extends Control
var building=false
func is_mouse_needed_for_ui():return false
func is_game_mode(mode):return building and mode==2
