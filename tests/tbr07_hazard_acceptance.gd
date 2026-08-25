extends SceneTree

const LEVEL_ID := "restroom_005"
const LEVEL_PATH := "res://levels/restroom_005.json"
const EXPECTED_HAZARD_TYPE := "reset_zone"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _validate_schema_contract():
		return
	var level_result := TurdLevelLoader.load_level(LEVEL_ID)
	if not level_result.ok:
		_fail("restroom_005 load: %s" % level_result.error)
		return
	var level: Dictionary = level_result.level
	if not _validate_demo_level(level):
		return
	print("TBR07_RESTROOM_005_DATA_OK")

	var runtime_scene: PackedScene = load("res://scenes/restroom.tscn")
	var game: RestroomRuntime = runtime_scene.instantiate()
	game.level_path_override = LEVEL_PATH
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty():
		_fail("restroom_005 runtime load: %s" % game.load_error)
		return
	game.player.set_physics_process(false)
	var evidence := _argument_value(OS.get_cmdline_user_args(), "--evidence=")
	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-hazard=")
	if not screenshot_path.is_empty():
		await _prepare_and_capture(game, level, evidence, screenshot_path)
		return
	if not await _validate_runtime(game, level):
		return
	print("TBR07_HAZARD_ACCEPTANCE_OK")
	quit(0)


func _validate_schema_contract() -> bool:
	for old_id in ["restroom_001", "restroom_002", "restroom_003", "restroom_004"]:
		var old_result := TurdLevelLoader.load_level(old_id)
		if not old_result.ok or not old_result.level.has("hazards") or not old_result.level.hazards.is_empty():
			_fail("existing-level optional hazards compatibility: %s" % old_id)
			return false
	print("TBR07_EXISTING_LEVELS_OPTIONAL_HAZARDS_OK")

	var base = JSON.parse_string(FileAccess.get_file_as_string("res://levels/restroom_001.json"))
	if typeof(base) != TYPE_DICTIONARY:
		_fail("schema fixture parse")
		return false
	base.hazards = [_hazard_fixture("hazard_a")]
	var valid := TurdLevelLoader.validate_level(base.duplicate(true), "valid_hazard")
	if not valid.ok or valid.level.hazards.size() != 1:
		_fail("valid reset_zone rejected: %s" % valid.get("error", "missing normalized hazard"))
		return false
	var hazard: Dictionary = valid.level.hazards[0]
	if hazard.type != EXPECTED_HAZARD_TYPE or not hazard.position.is_equal_approx(Vector3(0.0, 0.1, 0.0)) or not hazard.size.is_equal_approx(Vector3(2.0, 0.5, 2.0)) or not hazard.reset_position.is_equal_approx(Vector3(0.0, 0.05, 4.0)) or not is_equal_approx(hazard.cooldown, 0.75):
		_fail("valid reset_zone normalization")
		return false

	var invalid: Dictionary = base.duplicate(true)
	invalid.hazards.append(_hazard_fixture("hazard_a"))
	if not _expect_invalid(invalid, "id", "duplicate hazard id"):
		return false
	invalid = base.duplicate(true)
	invalid.hazards[0].type = "damage_zone"
	if not _expect_invalid(invalid, "type", "unsupported hazard type"):
		return false
	for bad_size in [[0.0, 0.5, 2.0], [2.0, -0.5, 2.0]]:
		invalid = base.duplicate(true)
		invalid.hazards[0].size = bad_size
		if not _expect_invalid(invalid, "size", "non-positive hazard size"):
			return false
	invalid = base.duplicate(true)
	invalid.hazards[0].position = [0.0, "bad", 0.0]
	if not _expect_invalid(invalid, "position", "malformed hazard position"):
		return false
	invalid = base.duplicate(true)
	invalid.hazards[0].erase("reset_position")
	if not _expect_invalid(invalid, "reset_position", "missing reset position"):
		return false
	invalid = base.duplicate(true)
	invalid.hazards[0].reset_position = [0.0, 1.0]
	if not _expect_invalid(invalid, "reset_position", "malformed reset position"):
		return false
	for bad_cooldown in [0.0, -0.25]:
		invalid = base.duplicate(true)
		invalid.hazards[0].cooldown = bad_cooldown
		if not _expect_invalid(invalid, "cooldown", "non-positive cooldown"):
			return false
	print("TBR07_INVALID_SCHEMA_CASES_OK")
	return true


func _hazard_fixture(id: String) -> Dictionary:
	return {"id": id, "type": EXPECTED_HAZARD_TYPE, "position": [0.0, 0.1, 0.0], "size": [2.0, 0.5, 2.0], "color": "7cff45", "reset_position": [0.0, 0.05, 4.0], "cooldown": 0.75}


func _expect_invalid(data: Dictionary, field_fragment: String, label: String) -> bool:
	var result := TurdLevelLoader.validate_level(data, label)
	if result.ok or field_fragment not in result.error:
		_fail("%s was not rejected at %s: %s" % [label, field_fragment, result.get("error", "ok")])
		return false
	return true


func _validate_demo_level(level: Dictionary) -> bool:
	if level.hazards.size() < 2 or level.hazards.size() > 3:
		_fail("restroom_005 requires 2-3 hazards")
		return false
	if level.collectible_turd_count < 7 or level.collectible_turd_count > 10:
		_fail("restroom_005 collectible count outside 7-10")
		return false
	var empty_count := 0
	for toilet: Dictionary in level.toilets:
		if not toilet.has_turd:
			empty_count += 1
	if empty_count < 2 or empty_count > 4 or level.doors.size() != 2 or level.triggers.size() != 2:
		_fail("restroom_005 fixture counts")
		return false
	for hazard: Dictionary in level.hazards:
		if hazard.type != EXPECTED_HAZARD_TYPE:
			_fail("restroom_005 unsupported normalized hazard")
			return false
		for other: Dictionary in level.hazards:
			if other.id != hazard.id and _point_inside_box(hazard.reset_position, other.position, other.size, 0.6):
				_fail("reset position overlaps another hazard: %s" % hazard.id)
				return false
		if _point_inside_box(hazard.reset_position, hazard.position, hazard.size, 0.6):
			_fail("reset position overlaps triggering hazard: %s" % hazard.id)
			return false
	print("TBR07_SAFE_RESET_LAYOUT_OK")
	return true


func _point_inside_box(point: Vector3, center: Vector3, size: Vector3, margin: float) -> bool:
	var delta := point - center
	return absf(delta.x) <= size.x * 0.5 + margin and absf(delta.y) <= size.y * 0.5 + margin and absf(delta.z) <= size.z * 0.5 + margin


func _validate_runtime(game: RestroomRuntime, level: Dictionary) -> bool:
	var hazards = game.get("hazards_by_id")
	if typeof(hazards) != TYPE_DICTIONARY or hazards.size() != level.hazards.size():
		_fail("runtime hazard registry")
		return false
	for definition: Dictionary in level.hazards:
		if not hazards.has(definition.id):
			_fail("unregistered hazard: %s" % definition.id)
			return false
		var hazard: Node3D = hazards[definition.id]
		if hazard.get("hazard_id") != definition.id or hazard.get("hazard_type") != EXPECTED_HAZARD_TYPE or not hazard.position.is_equal_approx(definition.position) or not hazard.get("reset_position").is_equal_approx(definition.reset_position):
			_fail("configured hazard mismatch: %s" % definition.id)
			return false
		var collision := hazard.get_node_or_null("Area3D/CollisionShape3D") as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D or not (collision.shape as BoxShape3D).size.is_equal_approx(definition.size):
			_fail("hazard Area3D geometry mismatch: %s" % definition.id)
			return false
	print("TBR07_RUNTIME_INSTANTIATION_OK")

	var first_definition: Dictionary = level.hazards[0]
	var first_hazard: Node3D = hazards[first_definition.id]
	var initial_count := int(first_hazard.get("activation_count"))
	var intruder := CharacterBody3D.new()
	intruder.name = "NonPlayerFixture"
	var intruder_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.0
	intruder_shape.shape = capsule
	intruder.add_child(intruder_shape)
	game.add_child(intruder)
	intruder.global_position = first_definition.position
	await _physics_frames(4)
	if int(first_hazard.get("activation_count")) != initial_count:
		_fail("non-player body activated hazard")
		return false
	intruder.queue_free()
	print("TBR07_NON_PLAYER_IGNORED_OK")

	var triggers: Array = level.triggers.duplicate()
	triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	var collectibles: Array[TurdToilet] = []
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd:
			collectibles.append(toilet)
	var threshold := int(triggers[0].threshold)
	for index in threshold:
		if not collectibles[index].collect():
			_fail("pre-hazard collection")
			return false
	var trigger: Dictionary = triggers[0]
	var door = game.doors_by_id[trigger.action.door_id]
	await create_timer(float(door.open_duration) + 0.1).timeout
	var before := _progress_snapshot(game, trigger, door, collectibles[0])
	if before.collected_turds != threshold or not before.trigger_fired or before.trigger_fire_count != 1 or before.door_state != 2 or before.door_open_count != 1 or before.toilet_has_turd:
		_fail("pre-hazard progression fixture")
		return false

	game.player.velocity = Vector3(3.0, -5.0, 4.0)
	if not await _enter_hazard(game.player, first_hazard, first_definition.position, initial_count + 1):
		return false
	if not game.player.global_position.is_equal_approx(first_definition.reset_position) or not game.player.velocity.is_zero_approx():
		_fail("player reset position/velocity")
		return false
	var after := _progress_snapshot(game, trigger, door, collectibles[0])
	if after != before:
		_fail("progression changed across hazard: before=%s after=%s" % [before, after])
		return false
	print("TBR07_PLAYER_RESET_OK")
	print("TBR07_PROGRESSION_PRESERVED_OK")

	await create_timer(float(first_hazard.get("cooldown")) + 0.05).timeout
	if not await _enter_hazard(game.player, first_hazard, first_definition.position, initial_count + 2):
		return false
	if int(first_hazard.get("activation_count")) != initial_count + 2:
		_fail("re-entry activation count")
		return false
	print("TBR07_REENTRY_OK")

	for index in range(threshold, collectibles.size()):
		if not collectibles[index].collect():
			_fail("final collection")
			return false
	if game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE or game.heist_exit.is_locked:
		_fail("exit did not unlock")
		return false
	var completed_count := game.collected_turds
	await create_timer(float(first_hazard.get("cooldown")) + 0.05).timeout
	if not await _enter_hazard(game.player, first_hazard, first_definition.position, initial_count + 3):
		return false
	if game.collected_turds != completed_count or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE or game.heist_exit.is_locked:
		_fail("exit state changed across hazard")
		return false
	if not game.heist_exit.attempt_exit(game.player) or game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist cannot complete after hazard")
		return false
	print("TBR07_EXIT_PRESERVED_OK")
	return true


func _progress_snapshot(game: RestroomRuntime, trigger: Dictionary, door, toilet: TurdToilet) -> Dictionary:
	return {"collected_turds": game.collected_turds, "trigger_fired": game.trigger_fired[trigger.id], "trigger_fire_count": game.trigger_fire_count[trigger.id], "door_state": int(door.state), "door_open_count": int(door.open_count), "toilet_has_turd": toilet.has_turd, "exit_locked": game.heist_exit.is_locked, "heist_state": int(game.state)}


func _enter_hazard(player: BurglarPlayer, hazard: Node3D, position: Vector3, expected_count: int) -> bool:
	player.global_position = position
	for frame in 12:
		await physics_frame
		if int(hazard.get("activation_count")) >= expected_count:
			return true
	_fail("hazard entry did not reach activation count %d" % expected_count)
	return false


func _physics_frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _prepare_and_capture(game: RestroomRuntime, level: Dictionary, evidence: String, path: String) -> void:
	var definition: Dictionary = level.hazards[0]
	var hazard: Node3D = game.hazards_by_id[definition.id]
	var focus: Vector3 = definition.position
	match evidence:
		"restroom-005", "hazard-before-entry":
			game.player.global_position = definition.position + Vector3(0.0, 0.0, 3.0)
		"hazard-entry":
			game.player.global_position = definition.position
		"post-reset":
			if not await _enter_hazard(game.player, hazard, definition.position, 1):
				return
			focus = (definition.position + definition.reset_position) * 0.5
		"door-preserved":
			var triggers: Array = level.triggers.duplicate()
			triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
			var collectibles: Array[TurdToilet] = []
			for toilet: TurdToilet in game.toilets:
				if toilet.has_turd:
					collectibles.append(toilet)
			for index in int(triggers[0].threshold):
				collectibles[index].collect()
			await create_timer(float(game.doors_by_id[triggers[0].action.door_id].open_duration) + 0.1).timeout
			if not await _enter_hazard(game.player, hazard, definition.position, 1):
				return
			focus = game.doors_by_id[triggers[0].action.door_id].global_position
		"exit-unlocked":
			for toilet: TurdToilet in game.toilets:
				if toilet.has_turd:
					toilet.collect()
			focus = game.heist_exit.global_position
		_:
			_fail("unknown evidence mode: %s" % evidence)
			return
	await _capture_scene(game, focus, path)
	print("TBR07_%s_SCREENSHOT_OK=%s" % [evidence.to_upper().replace("-", "_"), path])
	quit(0)


func _capture_scene(game: RestroomRuntime, focus: Vector3, path: String) -> void:
	(game.player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = focus + Vector3(6.0, 4.5, 7.0)
	camera.look_at(focus + Vector3(0.0, 0.5, 0.0), Vector3.UP)
	camera.fov = 52.0
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("hazard screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R07 hazard acceptance failed: %s" % stage)
	quit(1)
