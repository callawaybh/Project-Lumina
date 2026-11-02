extends SceneTree
var checks := 0
func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error(message);quit(1);assert(value, message)
func _initialize() -> void:
	var source := FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/scripts/autoload/net.gd")
	var methods := "var _local_dev_session_active:" + source.split("var _local_dev_session_active:",true,1)[1].split("func _ready()",true,1)[0]
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nclass MockAuth:\n\tvar auth = {\"refreshtoken\":\"normal-refresh\"}\n\tfunc get_jwt(): return \"normal-token\"\nclass MockFirebase:\n\tvar Auth = MockAuth.new()\nvar Firebase = MockFirebase.new()\nclass MockJWT:\n\tfunc get_user_id_from_jwt(_token,_key): return \"normal-user\"\nvar JWT = MockJWT.new()\n" + methods
	verify(script.reload() == OK,"Production provider methods compile")
	var net = script.new()
	var owner := "lumina-local-dev." + "a".repeat(64)
	var guest := "lumina-local-dev." + "b".repeat(64)
	ProjectSettings.set_setting("mirror/env_name","local")
	ProjectSettings.set_setting("mirror/local_dev_auth_enabled",true)
	ProjectSettings.set_setting("mirror/local_dev_auth_token",owner)
	ProjectSettings.set_setting("mirror/local_dev_user_id","6ae46e485754d729b3dbf613")
	ProjectSettings.set_setting("mirror/connection_server","http://127.0.0.2:9000")
	ProjectSettings.set_setting("mirror/connection_server_ws","ws://127.0.0.2:9000")
	verify(net.is_local_development_auth(),"Owner remains local")
	verify(net.begin_local_development_session(),"Owner starts")
	verify(net.get_user_id_from_auth_token(owner)=="6ae46e485754d729b3dbf613","Existing owner unchanged")
	verify(net.get_user_id_from_auth_token(guest).is_empty(),"Unregistered guest denied")
	ProjectSettings.set_setting("mirror/local_dev_peer_tokens",{guest:"6ae46e485754d729b3dbf614"})
	verify(net.get_user_id_from_auth_token(guest)=="6ae46e485754d729b3dbf614","Host recognizes guest identity")
	verify(net.get_user_id_from_auth_token("lumina-local-dev."+"c".repeat(64)).is_empty(),"Unknown player denied")
	for host in ["100.99.179.73","192.168.68.145","10.0.0.1","172.16.0.1"]:
		ProjectSettings.set_setting("mirror/local_dev_server_host",host)
		ProjectSettings.set_setting("mirror/connection_server","http://"+host+":9000")
		ProjectSettings.set_setting("mirror/connection_server_ws","ws://"+host+":9000")
		verify(net.is_local_development_auth(),"Explicit private host accepted")
	for host in ["8.8.8.8","example.com","100.63.0.1","100.128.0.1","172.32.0.1"]:
		ProjectSettings.set_setting("mirror/local_dev_server_host",host)
		ProjectSettings.set_setting("mirror/connection_server","http://"+host+":9000")
		ProjectSettings.set_setting("mirror/connection_server_ws","ws://"+host+":9000")
		verify(not net.is_local_development_auth(),"Public destination rejected")
	ProjectSettings.set_setting("mirror/local_dev_server_host","100.99.179.73")
	for address in ["http://100.99.179.73@evil.test:9000","http://100.99.179.73.evil:9000","https://evil.test","file://100.99.179.73:9000"]:
		ProjectSettings.set_setting("mirror/connection_server",address)
		verify(not net.is_local_development_auth(),"Lookalike/unsupported URL rejected")
	ProjectSettings.set_setting("mirror/connection_server","http://100.99.179.73:9000")
	ProjectSettings.set_setting("mirror/connection_server_ws","ws://100.99.179.73:9000")
	ProjectSettings.set_setting("mirror/local_dev_peer_tokens",{})
	ProjectSettings.set_setting("mirror/local_dev_auth_token",guest)
	ProjectSettings.set_setting("mirror/local_dev_user_id","6ae46e485754d729b3dbf614")
	verify(net.begin_local_development_session(),"Guest starts")
	verify(net.get_user_id_from_auth_token(guest)=="6ae46e485754d729b3dbf614","Guest is not owner")
	verify(net.get_user_id_from_auth_token(owner).is_empty(),"Guest configuration has no owner credential")
	var files := FileAccess.get_file_as_string("C:/Dev/LuminaClient/mirror-godot-app/scripts/net/file_client.gd")
	var resolver := GDScript.new()
	resolver.source_code = "extends RefCounted\nvar Net\nfunc " + files.split("func _development_download_url",true,1)[1].insert(0,"_development_download_url")
	verify(resolver.reload()==OK,"Production file resolver compiles")
	var file = resolver.new();file.Net=net
	for host in ["localhost","127.0.0.1","127.0.0.2"]:
		verify(file._development_download_url("http://"+host+":9000/assets-storage/a.glb")=="http://100.99.179.73:9000/assets-storage/a.glb","Local asset routed to host")
	for url in ["https://example.com/a.glb","http://localhost:9000/not-storage/a.glb","http://localhost:9000.evil/assets-storage/a.glb"]:
		verify(file._development_download_url(url)==url,"Unrelated downloads unchanged")
	ProjectSettings.set_setting("mirror/env_name","official")
	verify(not net.is_local_development_auth(),"Hosted provider preserved")
	verify(net.get_user_id_from_auth_token(guest).is_empty(),"Guest credential rejected in hosted mode")
	verify(net.get_auth_token()=="normal-token","Normal login provider retained")
	print("LUMINA_LAN_LOGIN_PASS: ",checks," checks")
	quit()
