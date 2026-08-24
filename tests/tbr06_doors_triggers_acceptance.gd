extends SceneTree

const DOOR_SCENE_PATH := "res://scenes/door.tscn"
const LEVEL_PATH := "res://levels/restroom_004.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _validate_schema_contract():
		return
	var level_result := TurdLevelLoader.load_level("restroom_004")
	if not level_result.ok:
		_fail("restroom_004 load: %s" % level_result.error)
		return
	var level: Dictionary = level_result.level
	if not _validate_demo_level(level):
		return
	print("TBR06_RESTROOM_004_PROGRESSION_DATA_OK")

	var runtime_scene: PackedScene = load("res://scenes/restroom.tscn")
	var game: Node = runtime_scene.instantiate()
	game.level_path_override = LEVEL_PATH
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty():
		_fail("restroom_004 runtime load: %s" % game.load_error)
		return
	game.player.set_physics_process(false)
	var evidence := _argument_value(OS.get_cmdline_user_args(), "--evidence=")
	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-door=")
	if not screenshot_path.is_empty():
		await _prepare_and_capture(game, level, evidence, screenshot_path)
		print("TBR06_%s_SCREENSHOT_OK=%s" % [evidence.to_upper().replace("-", "_"), screenshot_path])
		quit(0)
		return

	if not await _validate_runtime_flow(game, level):
		return
	print("TBR06_DOORS_TRIGGERS_ACCEPTANCE_OK")
	quit(0)


func _validate_schema_contract() -> bool:
	for old_id in ["restroom_001", "restroom_002", "restroom_003"]:
		var old_result := TurdLevelLoader.load_level(old_id)
		if not old_result.ok or not old_result.level.has("doors") or not old_result.level.has("triggers") or not old_result.level.doors.is_empty() or not old_result.level.triggers.is_empty():
			_fail("existing-level optional doors/triggers compatibility: %s" % old_id)
			return false
	print("TBR06_EXISTING_LEVELS_OPTIONAL_FIELDS_OK")

	var source := FileAccess.get_file_as_string("res://levels/restroom_001.json")
	var base = JSON.parse_string(source)
	if typeof(base) != TYPE_DICTIONARY:
		_fail("schema fixture parse")
		return false
	base.doors = [_door_fixture("door_a")]
	base.triggers = [_trigger_fixture("trigger_a", "door_a", 2)]
	if not TurdLevelLoader.validate_level(base.duplicate(true), "valid_extended").ok:
		_fail("valid doors/triggers fixture rejected")
		return false

	var invalid: Dictionary = base.duplicate(true)
	invalid.doors.append(_door_fixture("door_a"))
	if not _expect_invalid(invalid, "doors", "duplicate door id"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers.append(_trigger_fixture("trigger_a", "door_a", 2))
	if not _expect_invalid(invalid, "triggers", "duplicate trigger id"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers[0].action.door_id = "door_missing"
	if not _expect_invalid(invalid, "door_id", "unknown door reference"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers[0].threshold = 0
	if not _expect_invalid(invalid, "threshold", "threshold zero"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers[0].threshold = 4
	if not _expect_invalid(invalid, "threshold", "threshold above objective"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers[0].type = "area_enter"
	if not _expect_invalid(invalid, "type", "unsupported trigger"):
		return false
	invalid = base.duplicate(true)
	invalid.triggers[0].action.type = "spawn_enemy"
	if not _expect_invalid(invalid, "action", "unsupported action"):
		return false
	invalid = base.duplicate(true)
	invalid.doors[0].size = [2.4, 0.0, 0.35]
	if not _expect_invalid(invalid, "size", "invalid door size"):
		return false
	invalid = base.duplicate(true)
	invalid.doors[0].open_duration = 0.0
	if not _expect_invalid(invalid, "open_duration", "invalid duration"):
		return false
	print("TBR06_INVALID_SCHEMA_CASES_OK")
	return true


func _door_fixture(id: String) -> Dictionary:
	return {"id": id, "position": [0.0, 1.4, -2.0], "size": [2.4, 2.8, 0.35], "color": "cc4d4d", "open_offset": [0.0, 3.1, 0.0], "open_duration": 0.1}


func _trigger_fixture(id: String, door_id: String, threshold: int) -> Dictionary:
	return {"id": id, "type": "collect_count", "threshold": threshold, "action": {"type": "open_door", "door_id": door_id}}


func _expect_invalid(data: Dictionary, field_fragment: String, label: String) -> bool:
	var result := TurdLevelLoader.validate_level(data, label)
	if result.ok or field_fragment not in result.error:
		_fail("%s was not rejected with %s: %s" % [label, field_fragment, result.get("error", "ok")])
		return false
	return true


func _validate_demo_level(level: Dictionary) -> bool:
	if level.doors.size() != 2 or level.triggers.size() != 2:
		_fail("restroom_004 requires exactly two doors/triggers")
		return false
	if level.collectible_turd_count < 6 or level.collectible_turd_count > 8:
		_fail("restroom_004 collectible count outside 6-8")
		return false
	var empty_count := 0
	for toilet: Dictionary in level.toilets:
		if not toilet.has_turd:
			empty_count += 1
	if empty_count < 2 or empty_count > 3:
		_fail("restroom_004 empty toilet count outside 2-3")
		return false
	var triggers: Array = level.triggers.duplicate()
	triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	if triggers[0].threshold != 2 or triggers[1].threshold < 4 or triggers[1].threshold > 5:
		_fail("demonstration thresholds must be 2 then 4/5")
		return false
	var doors_by_id := {}
	for door: Dictionary in level.doors:
		doors_by_id[door.id] = door
		if door.size.y < 2.2 or door.open_offset.length() < 1.0:
			_fail("door does not visibly block/move: %s" % door.id)
			return false
	var spawn: Vector3 = level.player_spawn
	var exit_position: Vector3 = level.exit.position
	var travel := Vector3(exit_position.x - spawn.x, 0.0, exit_position.z - spawn.z)
	if travel.length() < 12.0:
		_fail("restroom_004 route is too short for three areas")
		return false
	travel = travel.normalized()
	var door_progress: Array[float] = []
	for trigger: Dictionary in triggers:
		var door: Dictionary = doors_by_id[trigger.action.door_id]
		var progress: float = (door.position - spawn).dot(travel)
		door_progress.append(progress)
		var reachable_collectibles := 0
		for toilet: Dictionary in level.toilets:
			if toilet.has_turd and (toilet.position - spawn).dot(travel) < progress - 0.5:
				reachable_collectibles += 1
		if reachable_collectibles < trigger.threshold:
			_fail("soft-lock risk before %s: reachable=%d threshold=%d" % [door.id, reachable_collectibles, trigger.threshold])
			return false
		var perpendicular_size: float = door.size.x if absf(travel.z) >= absf(travel.x) else door.size.z
		if perpendicular_size < 2.4:
			_fail("door is too narrow to be a meaningful corridor gate: %s" % door.id)
			return false
	if door_progress[0] < 3.0 or door_progress[1] - door_progress[0] < 5.0 or travel.length() == 0.0:
		_fail("doors do not establish three ordered progression areas")
		return false
	var after_second := 0
	for toilet: Dictionary in level.toilets:
		if toilet.has_turd and (toilet.position - spawn).dot(travel) > door_progress[1] + 0.5:
			after_second += 1
	if after_second < 1:
		_fail("no final collectible area exists beyond Door B")
		return false
	return true


func _validate_runtime_flow(game, level: Dictionary) -> bool:
	if game.get("doors_by_id") == null or game.get("trigger_fired") == null or game.get("trigger_fire_count") == null:
		_fail("runtime door/trigger registries missing")
		return false
	if game.doors_by_id.size() != 2 or game.trigger_fired.size() != 2:
		_fail("runtime did not register two doors/triggers")
		return false
	var triggers: Array = level.triggers.duplicate()
	triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	var collectibles: Array[TurdToilet] = []
	var empty: TurdToilet
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd:
			collectibles.append(toilet)
		elif empty == null:
			empty = toilet
	if empty == null or empty.collect() or game.collected_turds != 0:
		_fail("empty toilet advanced objective")
		return false
	var collected := 0
	for trigger_index in triggers.size():
		var trigger: Dictionary = triggers[trigger_index]
		var door: Node3D = game.doors_by_id[trigger.action.door_id]
		if int(door.get("state")) != 0 or not _door_collision_enabled(door):
			_fail("door not initially CLOSED/blocking: %s" % trigger.action.door_id)
			return false
		while collected < trigger.threshold - 1:
			if not collectibles[collected].collect():
				_fail("pre-threshold collection failed")
				return false
			collected += 1
		if game.trigger_fired[trigger.id] or int(door.get("state")) != 0:
			_fail("trigger fired before threshold: %s" % trigger.id)
			return false
		if not collectibles[collected].collect():
			_fail("threshold collection failed: %s" % trigger.id)
			return false
		collected += 1
		if not game.trigger_fired[trigger.id] or game.trigger_fire_count[trigger.id] != 1 or int(door.get("state")) not in [1, 2] or int(door.get("open_count")) != 1:
			_fail("trigger/door did not fire once at threshold: %s" % trigger.id)
			return false
		if collectibles[collected - 1].collect() or game.collected_turds != collected:
			_fail("duplicate collection advanced objective")
			return false
		if bool(door.call("open")) or int(door.get("open_count")) != 1:
			_fail("door open is not idempotent: %s" % trigger.action.door_id)
			return false
		var closed_position: Vector3 = door.get("closed_position")
		var open_offset: Vector3 = door.get("open_offset")
		var collision := door.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
		var collision_start := collision.global_position
		await create_timer(float(door.get("open_duration")) + 0.2).timeout
		if int(door.get("state")) != 2 or not door.position.is_equal_approx(closed_position + open_offset):
			_fail("door did not reach OPEN destination: %s" % trigger.action.door_id)
			return false
		if collision.global_position.distance_to(collision_start + open_offset) > 0.02:
			_fail("door collision did not move with visual: %s" % trigger.action.door_id)
			return false
		print("TBR06_DOOR_FLOW_OK=%s" % trigger.action.door_id)
	while collected < collectibles.size():
		if not collectibles[collected].collect():
			_fail("final collection failed")
			return false
		collected += 1
	if game.collected_turds != level.objective.turds_required or game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE:
		_fail("final exit progression regression")
		return false
	for trigger: Dictionary in triggers:
		var door: Node3D = game.doors_by_id[trigger.action.door_id]
		if game.trigger_fire_count[trigger.id] != 1 or int(door.get("open_count")) != 1:
			_fail("trigger/door fired more than once")
			return false
	print("TBR06_ONE_SHOT_TRIGGER_OK")
	print("TBR06_FINAL_EXIT_PRESERVED_OK")
	return true


func _door_collision_enabled(door: Node3D) -> bool:
	var collision := door.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	return collision != null and collision.shape != null and not collision.disabled


func _prepare_and_capture(game, level: Dictionary, evidence: String, path: String) -> void:
	var triggers: Array = level.triggers.duplicate()
	triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	var collectibles: Array[TurdToilet] = []
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd:
			collectibles.append(toilet)
	var collect_target := 0
	var target_position: Vector3
	match evidence:
		"door-a-closed":
			target_position = game.doors_by_id[triggers[0].action.door_id].global_position
		"door-a-open", "middle-area", "door-b-closed":
			collect_target = triggers[0].threshold
			target_position = game.doors_by_id[triggers[0].action.door_id].global_position if evidence != "door-b-closed" else game.doors_by_id[triggers[1].action.door_id].global_position
		"door-b-open":
			collect_target = triggers[1].threshold
			target_position = game.doors_by_id[triggers[1].action.door_id].global_position
		_:
			_fail("unknown door evidence state: %s" % evidence)
			return
	for index in collect_target:
		collectibles[index].collect()
	if collect_target > 0:
		var last_trigger: Dictionary = triggers[1] if collect_target >= triggers[1].threshold else triggers[0]
		var last_door: Node3D = game.doors_by_id[last_trigger.action.door_id]
		await create_timer(float(last_door.get("open_duration")) + 0.15).timeout
	if evidence == "middle-area":
		var door_a: Node3D = game.doors_by_id[triggers[0].action.door_id]
		var door_b: Node3D = game.doors_by_id[triggers[1].action.door_id]
		target_position = (door_a.get("closed_position") + door_b.get("closed_position")) * 0.5
		game.player.global_position = target_position
	await _capture_scene(game, target_position, path)


func _capture_scene(game, target: Vector3, path: String) -> void:
	(game.player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = target + Vector3(6.5, 4.4, 7.5)
	camera.look_at(target + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	camera.fov = 52.0
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("door screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R06 doors/triggers acceptance failed: %s" % stage)
	quit(1)
