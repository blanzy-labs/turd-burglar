extends SceneTree

const SOURCE_PATH := "res://levels/restroom_002.json"
const PROOF_PATH := "user://tb002-data-proof.json"
const PROOF_SPAWN := Vector3(-8.75, 0.05, 5.25)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	if source_file == null:
		_fail("could not read Second Flush source")
		return
	var source := source_file.get_as_text()
	var raw = JSON.parse_string(source)
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("source fixture did not parse")
		return

	var missing_field: Dictionary = raw.duplicate(true)
	missing_field.erase("player_spawn")
	var missing_result := TurdLevelLoader.parse_and_validate(JSON.stringify(missing_field), "missing_field")
	if missing_result.ok or "field=player_spawn" not in missing_result.error:
		_fail("missing required field was not rejected deterministically")
		return
	print("TB002_NEGATIVE_MISSING_FIELD_OK")

	var invalid_json_result := TurdLevelLoader.parse_and_validate("{ definitely not json", "invalid_json")
	if invalid_json_result.ok or "field=json" not in invalid_json_result.error:
		_fail("invalid JSON was not rejected deterministically")
		return
	print("TB002_NEGATIVE_INVALID_JSON_OK")

	var mismatch: Dictionary = raw.duplicate(true)
	mismatch.objective.turds_required = 8
	var mismatch_result := TurdLevelLoader.parse_and_validate(JSON.stringify(mismatch), "objective_mismatch")
	if mismatch_result.ok or "field=objective.turds_required" not in mismatch_result.error:
		_fail("objective mismatch was not rejected deterministically")
		return
	print("TB002_NEGATIVE_OBJECTIVE_MISMATCH_OK")

	var missing_file_result := TurdLevelLoader.load_level("restroom_999")
	if missing_file_result.ok or "field=file" not in missing_file_result.error:
		_fail("missing level file was not rejected deterministically")
		return
	print("TB002_NEGATIVE_MISSING_FILE_OK")

	var proof: Dictionary = raw.duplicate(true)
	proof.player_spawn = [PROOF_SPAWN.x, PROOF_SPAWN.y, PROOF_SPAWN.z]
	var proof_file := FileAccess.open(PROOF_PATH, FileAccess.WRITE)
	if proof_file == null:
		_fail("could not create temporary proof definition")
		return
	proof_file.store_string(JSON.stringify(proof, "  "))
	proof_file.close()

	var restroom_scene: PackedScene = load("res://scenes/restroom.tscn")
	var game: RestroomRuntime = restroom_scene.instantiate()
	game.level_path_override = PROOF_PATH
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty():
		_cleanup_proof()
		_fail("temporary definition failed to load: %s" % game.load_error)
		return
	if not game.player.position.is_equal_approx(PROOF_SPAWN):
		_cleanup_proof()
		_fail("runtime did not use modified player_spawn")
		return
	if game.level_id != "restroom_002" or game.required_turds != 5:
		_cleanup_proof()
		_fail("temporary definition changed unrelated runtime behavior")
		return
	_cleanup_proof()
	print("TB002_DATA_PROOF_PLAYER_SPAWN=%s" % PROOF_SPAWN)
	print("TB002_DATA_DRIVEN_PROOF_OK")
	quit(0)


func _cleanup_proof() -> void:
	if FileAccess.file_exists(PROOF_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROOF_PATH))


func _fail(stage: String) -> void:
	push_error("TB-002 level-data acceptance failed: %s" % stage)
	quit(1)
