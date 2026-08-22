extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scenes/main.tscn",
	"res://scenes/restroom.tscn",
	"res://scenes/player.tscn",
	"res://scenes/toilet.tscn",
	"res://scenes/exit.tscn",
	"res://scripts/level_loader.gd",
	"res://levels/restroom_001.json",
	"res://levels/restroom_002.json",
]


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	for resource_path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(resource_path) and not FileAccess.file_exists(resource_path):
			_fail("Missing resource: %s" % resource_path)
			return

	for expected in [
		{"id": "restroom_001", "name": "First Flush", "toilets": 3, "turds": 3, "labels": 3},
		{"id": "restroom_002", "name": "Second Flush", "toilets": 6, "turds": 5, "labels": 6},
	]:
		var result := TurdLevelLoader.load_level(expected.id)
		if not result.ok:
			_fail("Level validation failed: %s" % result.error)
			return
		var definition: Dictionary = result.level
		if definition.name != expected.name or definition.toilets.size() != expected.toilets:
			_fail("Level identity/count mismatch: %s" % expected.id)
			return
		if definition.collectible_turd_count != expected.turds or definition.labels.size() != expected.labels:
			_fail("Level collectible/stall mismatch: %s" % expected.id)
			return

	var packed: PackedScene = load("res://scenes/restroom.tscn")
	var first: RestroomRuntime = packed.instantiate()
	first.level_path_override = "res://levels/restroom_001.json"
	root.add_child(first)
	await process_frame
	if first.toilets.size() != 3 or first.player == null or first.heist_exit == null:
		_fail("First Flush gameplay nodes were not instantiated")
		return
	if not first.player is CharacterBody3D or first.player.get_node_or_null("CollisionShape3D") == null:
		_fail("Player character/collision rig is invalid")
		return
	if not first.player.get_node("CameraPivot/SpringArm3D/Camera3D") is Camera3D:
		_fail("Third-person camera rig is invalid")
		return
	for required_node in ["Floor", "BackWall", "FrontWall", "LeftWall", "RightWall"]:
		if first.get_node_or_null(required_node) == null:
			_fail("Missing First Flush generated node: %s" % required_node)
			return
	first.queue_free()
	await process_frame

	var second: RestroomRuntime = packed.instantiate()
	second.level_path_override = "res://levels/restroom_002.json"
	root.add_child(second)
	await process_frame
	if second.toilets.size() != 6 or second.collectible_turd_count != 5:
		_fail("Second Flush runtime count mismatch")
		return
	if second.get_node_or_null("FloorNorth") == null or second.get_node_or_null("FloorEast") == null:
		_fail("Second Flush L-shaped geometry was not generated")
		return
	for index in 6:
		if second.get_node_or_null("StallSign%02d" % (index + 1)) == null:
			_fail("Missing generated Second Flush stall label")
			return

	print("TB001_LEVEL_STRUCTURE_OK")
	print("TB001_PLAYER_RIG_OK")
	print("TB001_STATIC_OK")
	print("TB002_LEVEL_DATA_OK")
	print("TB002_SHARED_RUNTIME_OK")
	print("TB002_STATIC_OK")
	print("TB_ENGINE=%s" % Engine.get_version_info().string)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
