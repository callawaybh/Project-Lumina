extends SceneTree
func _initialize() -> void:
	var base := "C:/Users/Calla/OneDrive/Documents/ChatGPT/Project Lumina/multiplayer-setup/Lumina-Guest-Windows/Game/"
	var config := ConfigFile.new()
	assert(config.load(base + "override.cfg") == OK)
	assert(config.get_value("mirror", "local_dev_user_id") == "29e0de5410f1c49599a6012d")
	assert(config.get_value("mirror", "local_dev_peer_tokens").is_empty())
	assert(config.get_value("mirror_secrets", "WSS_SECRET").is_empty())
	assert(config.get_value("feature_flags", "always_spin_up_local_server") == false)
	var files: Array[String] = []
	walk(base, files)
	var references := 0
	for path in files:
		if path.ends_with(".import"):
			var imported := ConfigFile.new()
			assert(imported.load(path) == OK)
			for file in imported.get_value("deps", "dest_files", []):
				assert(FileAccess.file_exists(base + str(file).trim_prefix("res://")), "Missing imported resource: " + str(file))
				references += 1
	print("LUMINA_GUEST_PACKAGE_PASS: configuration and ", references, " imported resource references")
	quit()
func walk(path: String, files: Array[String]) -> void:
	for name in DirAccess.get_files_at(path): files.append(path.path_join(name))
	for name in DirAccess.get_directories_at(path): walk(path.path_join(name), files)
