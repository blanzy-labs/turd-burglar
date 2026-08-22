extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scenes/main.tscn",
	"res://scenes/restroom.tscn",
	"res://scenes/player.tscn",
	"res://scenes/toilet.tscn",
	"res://scenes/exit.tscn",
]


func _initialize() -> void:
	call_deferred("_validate")


func _validate() -> void:
	for resource_path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(resource_path):
			push_error("Missing resource: %s" % resource_path)
			quit(1)
			return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var game: FirstFlushRestroom = main.get_node("Restroom")
	if game.toilets.size() != 3 or game.player == null or game.heist_exit == null:
		push_error("Required gameplay nodes were not instantiated")
		quit(1)
		return
	if not game.player is CharacterBody3D or game.player.get_node_or_null("CollisionShape3D") == null:
		push_error("Player character/collision rig is invalid")
		quit(1)
		return
	if not game.player.get_node("CameraPivot/SpringArm3D/Camera3D") is Camera3D:
		push_error("Third-person camera rig is invalid")
		quit(1)
		return
	for required_node in ["Floor", "BackWall", "FrontWall", "LeftWall", "RightWall"]:
		if game.get_node_or_null(required_node) == null:
			push_error("Missing level node: %s" % required_node)
			quit(1)
			return
	print("TB001_LEVEL_STRUCTURE_OK")
	print("TB001_PLAYER_RIG_OK")
	print("TB001_STATIC_OK")
	print("TB001_ENGINE=%s" % Engine.get_version_info().string)
	quit(0)
