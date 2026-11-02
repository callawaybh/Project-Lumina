extends SceneTree

func _initialize():
	var source = FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../../../mirror-godot-app/scripts/autoload/net.gd"))
	var methods = source.split("var _local_dev_session_active:",true,1)[1].split("func _ready()",true,1)[0]
	var stub = "extends RefCounted\nclass MockAuth:\n\tvar auth = {\"refreshtoken\":\"normal-refresh\"}\n\tfunc get_jwt(): return \"normal-token\"\nclass MockFirebase:\n\tvar Auth = MockAuth.new()\nvar Firebase = MockFirebase.new()\n"
	stub += "class MockJWT:\n\tfunc get_user_id_from_jwt(_token, _key): return \"normal-user\"\nvar JWT = MockJWT.new()\n"
	var script = GDScript.new()
	script.source_code = stub + "var _local_dev_session_active:" + methods
	assert(script.reload() == OK)
	var net = script.new()
	ProjectSettings.set_setting("mirror/env_name","local")
	ProjectSettings.set_setting("mirror/local_dev_auth_enabled",true)
	ProjectSettings.set_setting("mirror/local_dev_auth_token","lumina-local-dev."+"a".repeat(64))
	ProjectSettings.set_setting("mirror/local_dev_user_id","6ae46e485754d729b3dbf613")
	ProjectSettings.set_setting("mirror/connection_server","http://127.0.0.2:9000")
	ProjectSettings.set_setting("mirror/connection_server_ws","ws://127.0.0.2:9000")
	assert(net.is_local_development_auth())
	assert(net.get_auth_token().is_empty())
	assert(net.begin_local_development_session())
	assert(net.get_auth_token().begins_with("lumina-local-dev."))
	assert(net.get_host_login_credential()=="local-development")
	assert(net.get_user_id_from_auth_token(net.get_auth_token())=="6ae46e485754d729b3dbf613")
	assert(net.get_user_id_from_auth_token("lumina-local-dev.wrong").is_empty())
	assert(net.get_user_id_from_auth_token("normal-token").is_empty())
	for host in ["https://remote.example", "http://localhost.evil:9000", "http://127.0.0.2@remote.example:9000"]:
		ProjectSettings.set_setting("mirror/connection_server",host)
		assert(not net.is_local_development_auth())
		assert(net.get_auth_token()=="normal-token")
	ProjectSettings.set_setting("mirror/connection_server","http://127.0.0.2:9000")
	ProjectSettings.set_setting("mirror/connection_server_ws","wss://remote.example")
	assert(not net.is_local_development_auth())
	ProjectSettings.set_setting("mirror/connection_server_ws","ws://127.0.0.2:9000")
	ProjectSettings.set_setting("mirror/env_name","official")
	assert(not net.is_local_development_auth())
	assert(net.get_auth_token()=="normal-token")
	assert(net.get_user_id_from_auth_token("lumina-local-dev."+"a".repeat(64)).is_empty())
	assert(net.get_user_id_from_auth_token("normal-token")=="normal-user")
	ProjectSettings.set_setting("mirror/env_name","local")
	ProjectSettings.set_setting("mirror/local_dev_auth_enabled",false)
	assert(not net.is_local_development_auth())
	print("LUMINA_LOCAL_ACCESS_POLICY_PASS")
	quit()
