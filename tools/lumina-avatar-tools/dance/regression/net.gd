extends Node
class Assets:
	extends RefCounted
	signal asset_deleted(asset)
	func get_asset_json(id):return {"_id":id}
	func get_asset_url(_id):return ""
var asset_client=Assets.new()
