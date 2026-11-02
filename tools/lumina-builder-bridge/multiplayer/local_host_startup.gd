extends RefCounted
## A local child must prove it bound the game port before the parent connects.
static func path_for(ticket: String) -> String:
	if ticket.length() != 32 or not ticket.is_valid_hex_number(false): return ""
	return "user://lumina-host-" + ticket + ".json"

static func report_bound(ticket: String, child_pid: int, space_id: String, port: int) -> bool:
	var path := path_for(ticket)
	if path.is_empty(): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"pid": child_pid, "space_id": space_id, "port": port}))
	file.close()
	return true

static func matches(ticket: String, child_pid: int, space_id: String, port: int) -> bool:
	var path := path_for(ticket)
	if path.is_empty() or not FileAccess.file_exists(path): return false
	var receipt = JSON.parse_string(FileAccess.get_file_as_string(path))
	return receipt is Dictionary and receipt.get("pid") == child_pid and receipt.get("space_id") == space_id and receipt.get("port") == port

static func clear(ticket: String) -> void:
	var path := path_for(ticket)
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
