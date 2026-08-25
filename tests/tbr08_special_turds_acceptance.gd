extends SceneTree

const LEVEL_ID := "restroom_006"
const LEVEL_PATH := "res://levels/restroom_006.json"
const NORMAL := "normal"
const TURBO := "turbo"
const GHOST := "ghost"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _validate_schema_contract():
		return
	var result := TurdLevelLoader.load_level(LEVEL_ID)
	if not result.ok:
		_fail("restroom_006 load: %s" % result.error)
		return
	var level: Dictionary = result.level
	if not _validate_demo_level(level):
		return
	print("TBR08_RESTROOM_006_DATA_OK")

	var game: RestroomRuntime = await _spawn_game()
	if game == null:
		return
	var evidence := _argument_value(OS.get_cmdline_user_args(), "--evidence=")
	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-special=")
	if not screenshot_path.is_empty():
		await _prepare_and_capture(game, level, evidence, screenshot_path)
		return
	if not _validate_runtime_configuration(game, level):
		return
	if not await _validate_collection_and_door(game, level):
		return
	game.queue_free()
	await process_frame

	game = await _spawn_game()
	if game == null or not await _validate_effect_runtime(game):
		return
	game.queue_free()
	await process_frame

	game = await _spawn_game()
	if game == null or not await _validate_hazard_composition(game, level):
		return
	game.queue_free()
	await process_frame

	game = await _spawn_game()
	if game == null or not await _validate_final_exit(game):
		return
	print("TBR08_SPECIAL_TURDS_ACCEPTANCE_OK")
	quit(0)


func _spawn_game():
	var runtime_scene: PackedScene = load("res://scenes/restroom.tscn")
	var game: RestroomRuntime = runtime_scene.instantiate()
	game.level_path_override = LEVEL_PATH
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty():
		_fail("runtime load: %s" % game.load_error)
		return null
	game.player.set_physics_process(false)
	return game


func _validate_schema_contract() -> bool:
	for old_id in ["restroom_001", "restroom_002", "restroom_003", "restroom_004", "restroom_005"]:
		var old_result := TurdLevelLoader.load_level(old_id)
		if not old_result.ok:
			_fail("legacy level rejected: %s" % old_id)
			return false
		for toilet: Dictionary in old_result.level.toilets:
			if toilet.get("turd_type", "") != NORMAL:
				_fail("legacy toilet did not default to normal: %s/%s" % [old_id, toilet.id])
				return false
	print("TBR08_LEGACY_NORMAL_DEFAULT_OK")

	var base = JSON.parse_string(FileAccess.get_file_as_string("res://levels/restroom_001.json"))
	if typeof(base) != TYPE_DICTIONARY:
		_fail("schema fixture parse")
		return false
	base.toilets[0].turd_type = NORMAL
	if not TurdLevelLoader.validate_level(base.duplicate(true), "normal_explicit").ok:
		_fail("explicit normal rejected")
		return false
	base.toilets[0].turd_type = TURBO
	base.toilets[0].effect_duration = 1.0
	base.toilets[0].effect_value = 1.5
	var turbo_result := TurdLevelLoader.validate_level(base.duplicate(true), "turbo_valid")
	if not turbo_result.ok or turbo_result.level.toilets[0].turd_type != TURBO or not is_equal_approx(turbo_result.level.toilets[0].effect_duration, 1.0) or not is_equal_approx(turbo_result.level.toilets[0].effect_value, 1.5):
		_fail("valid turbo normalization")
		return false
	base.toilets[0].turd_type = GHOST
	base.toilets[0].effect_duration = 1.0
	base.toilets[0].erase("effect_value")
	var ghost_result := TurdLevelLoader.validate_level(base.duplicate(true), "ghost_valid")
	if not ghost_result.ok or ghost_result.level.toilets[0].turd_type != GHOST or not is_equal_approx(ghost_result.level.toilets[0].effect_duration, 1.0):
		_fail("valid ghost normalization")
		return false

	var invalid: Dictionary = base.duplicate(true)
	invalid.toilets[0].turd_type = "royal"
	if not _expect_invalid(invalid, "turd_type", "unknown turd type"):
		return false
	for bad_duration in [0.0, -1.0, "six"]:
		invalid = base.duplicate(true)
		invalid.toilets[0].effect_duration = bad_duration
		if not _expect_invalid(invalid, "effect_duration", "ghost invalid duration"):
			return false
	for bad_duration in [0.0, -1.0, "six"]:
		invalid = base.duplicate(true)
		invalid.toilets[0].turd_type = TURBO
		invalid.toilets[0].effect_duration = bad_duration
		invalid.toilets[0].effect_value = 1.5
		if not _expect_invalid(invalid, "effect_duration", "turbo invalid duration"):
			return false
	for bad_value in [1.0, 0.5, -2.0, "fast"]:
		invalid = base.duplicate(true)
		invalid.toilets[0].turd_type = TURBO
		invalid.toilets[0].effect_duration = 1.0
		invalid.toilets[0].effect_value = bad_value
		if not _expect_invalid(invalid, "effect_value", "turbo invalid multiplier"):
			return false
	print("TBR08_SCHEMA_CASES_OK")
	return true


func _expect_invalid(data: Dictionary, field_fragment: String, label: String) -> bool:
	var result := TurdLevelLoader.validate_level(data, label)
	if result.ok or field_fragment not in result.error:
		_fail("%s was not rejected at %s: %s" % [label, field_fragment, result.get("error", "ok")])
		return false
	return true


func _validate_demo_level(level: Dictionary) -> bool:
	if level.collectible_turd_count < 8 or level.collectible_turd_count > 10:
		_fail("restroom_006 collectible count outside 8-10")
		return false
	var counts := {NORMAL: 0, TURBO: 0, GHOST: 0, "empty": 0}
	for toilet: Dictionary in level.toilets:
		if not toilet.has_turd:
			counts.empty += 1
		else:
			counts[toilet.turd_type] += 1
	if counts.normal < 5 or counts.turbo < 2 or counts.ghost < 2 or counts.empty < 2 or counts.empty > 3:
		_fail("restroom_006 special/normal/empty counts: %s" % counts)
		return false
	if level.doors.size() != 2 or level.triggers.size() != 2 or level.hazards.size() < 2:
		_fail("restroom_006 door/trigger/hazard counts")
		return false
	var route_width := 16.0
	for hazard: Dictionary in level.hazards:
		if hazard.size.x >= route_width - 3.0:
			_fail("hazard leaves no reasonable safe route: %s" % hazard.id)
			return false
	print("TBR08_OPTIONAL_POWER_ROUTE_OK")
	return true


func _validate_runtime_configuration(game: RestroomRuntime, level: Dictionary) -> bool:
	var by_id := {}
	for toilet: TurdToilet in game.toilets:
		by_id[toilet.name] = toilet
	for definition: Dictionary in level.toilets:
		var toilet: TurdToilet = by_id[definition.id]
		if toilet.get("turd_type") != definition.turd_type:
			_fail("runtime turd type mismatch: %s" % definition.id)
			return false
		if definition.turd_type != NORMAL and (not is_equal_approx(float(toilet.get("effect_duration")), definition.effect_duration) or (definition.turd_type == TURBO and not is_equal_approx(float(toilet.get("effect_value")), definition.effect_value))):
			_fail("runtime effect configuration mismatch: %s" % definition.id)
			return false
	var normal := _first_toilet(game, NORMAL)
	var turbo := _first_toilet(game, TURBO)
	var ghost := _first_toilet(game, GHOST)
	var normal_color := _turd_color(normal)
	var turbo_color := _turd_color(turbo)
	var ghost_color := _turd_color(ghost)
	if normal_color.is_equal_approx(turbo_color) or normal_color.is_equal_approx(ghost_color) or turbo_color.is_equal_approx(ghost_color):
		_fail("special turds are not visually distinct")
		return false
	var turbo_material := _turd_material(turbo)
	var ghost_material := _turd_material(ghost)
	if not turbo_material.emission_enabled or not ghost_material.emission_enabled:
		_fail("special turds lack emission identity")
		return false
	var turbo_before := turbo_color
	turbo.set_targeted(true)
	if not _turd_color(turbo).is_equal_approx(turbo_before):
		_fail("targeting replaced special base color")
		return false
	turbo.set_targeted(false)
	print("TBR08_VISUAL_IDENTITY_OK")
	return true


func _validate_collection_and_door(game: RestroomRuntime, level: Dictionary) -> bool:
	var triggers: Array = level.triggers.duplicate()
	triggers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	if int(triggers[0].threshold) != 2:
		_fail("first door threshold is not 2")
		return false
	var normal := _first_toilet(game, NORMAL)
	var turbo := _first_toilet(game, TURBO)
	if not normal.collect() or game.collected_turds != 1 or game.trigger_fired[triggers[0].id]:
		_fail("normal first collection/door state")
		return false
	if not turbo.collect():
		_fail("turbo threshold collection")
		return false
	var door = game.doors_by_id[triggers[0].action.door_id]
	if game.collected_turds != 2 or not game.trigger_fired[triggers[0].id] or game.trigger_fire_count[triggers[0].id] != 1 or int(door.open_count) != 1 or not game.player.has_turd_effect(TURBO):
		_fail("special collection did not synchronously advance door and effect")
		return false
	var remaining: float = game.player.get_turd_effect_remaining(TURBO)
	var effect_starts := int(game.player.get("effect_start_count").get(TURBO, 0))
	if turbo.collect() or game.collected_turds != 2 or game.trigger_fire_count[triggers[0].id] != 1 or int(door.open_count) != 1:
		_fail("duplicate special collection advanced state")
		return false
	await process_frame
	if game.player.get_turd_effect_remaining(TURBO) >= remaining or int(game.player.get("effect_start_count").get(TURBO, 0)) != effect_starts:
		_fail("duplicate special collection refreshed/restarted effect")
		return false
	if not turbo.pickup_feedback_active or game.collection_feedback_count != 2:
		_fail("TB-R05 pickup/HUD feedback not preserved")
		return false
	print("TBR08_OBJECTIVE_DOOR_ORDER_OK")
	print("TBR08_DUPLICATE_PROTECTION_OK")
	return true


func _validate_effect_runtime(game: RestroomRuntime) -> bool:
	var player: BurglarPlayer = game.player
	if player.has_turd_effect(TURBO) or player.has_turd_effect(GHOST) or not is_equal_approx(player.get_effective_move_speed(), BurglarPlayer.MOVE_SPEED):
		_fail("initial effect state")
		return false
	var motion_origin := player.global_position
	var baseline_distance := _controlled_motion_distance(player, motion_origin)
	player.reset_to_position(motion_origin)
	player.apply_turd_effect(TURBO, 0.65, 1.5)
	if not player.has_turd_effect(TURBO) or not is_equal_approx(player.get_effective_move_speed(), BurglarPlayer.MOVE_SPEED * 1.5):
		_fail("turbo activation/multiplier")
		return false
	var turbo_distance := _controlled_motion_distance(player, motion_origin)
	player.reset_to_position(motion_origin)
	if baseline_distance <= 0.0 or turbo_distance <= baseline_distance * 1.35:
		_fail("Turbo did not move farther over controlled equivalent steps: baseline=%.3f turbo=%.3f" % [baseline_distance, turbo_distance])
		return false
	var turbo_hud := _effect_hud_text(game)
	if "HOT SHIT" not in turbo_hud or "GHOST TURD" in turbo_hud:
		_fail("turbo HUD state")
		return false
	await create_timer(0.18).timeout
	var before_refresh: float = player.get_turd_effect_remaining(TURBO)
	player.apply_turd_effect(TURBO, 0.7, 1.5)
	if not is_equal_approx(player.get_effective_move_speed(), BurglarPlayer.MOVE_SPEED * 1.5) or player.get_turd_effect_remaining(TURBO) <= before_refresh or int(player.get("effect_refresh_count").get(TURBO, 0)) < 1:
		_fail("turbo refresh/non-stacking")
		return false

	player.apply_turd_effect(GHOST, 0.95, 1.0)
	if not player.has_turd_effect(TURBO) or not player.has_turd_effect(GHOST):
		_fail("simultaneous effects")
		return false
	var both_hud := _effect_hud_text(game)
	if "HOT SHIT" not in both_hud or "GHOST TURD" not in both_hud:
		_fail("simultaneous HUD")
		return false
	await create_timer(0.75).timeout
	if player.has_turd_effect(TURBO) or not player.has_turd_effect(GHOST) or not is_equal_approx(player.get_effective_move_speed(), BurglarPlayer.MOVE_SPEED):
		_fail("independent turbo expiry")
		return false
	if "HOT SHIT" in _effect_hud_text(game) or "GHOST TURD" not in _effect_hud_text(game):
		_fail("turbo HUD expiry")
		return false
	var ghost_before: float = player.get_turd_effect_remaining(GHOST)
	player.apply_turd_effect(GHOST, 0.45, 1.0)
	if player.get_turd_effect_remaining(GHOST) <= ghost_before or int(player.get("effect_refresh_count").get(GHOST, 0)) < 1:
		_fail("ghost refresh")
		return false
	await create_timer(0.5).timeout
	if player.has_turd_effect(GHOST) or not _effect_hud_text(game).is_empty() or bool(game.get("effect_panel").visible):
		_fail("ghost expiry/HUD cleanup")
		return false
	print("TBR08_TURBO_RUNTIME_OK")
	print("TBR08_REFRESH_AND_COEXISTENCE_OK")
	print("TBR08_EFFECT_EXPIRY_HUD_OK")
	return true


func _controlled_motion_distance(player: BurglarPlayer, origin: Vector3) -> float:
	player.reset_to_position(origin)
	Input.action_press("move_forward")
	for step in 8:
		player.call("_physics_process", 1.0 / 60.0)
	Input.action_release("move_forward")
	var delta := player.global_position - origin
	return Vector2(delta.x, delta.z).length()


func _validate_hazard_composition(game: RestroomRuntime, level: Dictionary) -> bool:
	var player: BurglarPlayer = game.player
	var definition: Dictionary = level.hazards[0]
	var hazard: ResetZoneHazard = game.hazards_by_id[definition.id]
	var count := hazard.activation_count
	if not await _enter_hazard(player, hazard, definition.position, count + 1):
		return false
	if not player.global_position.is_equal_approx(definition.reset_position):
		_fail("baseline post-Ghost hazard reset")
		return false
	await create_timer(hazard.cooldown + 0.05).timeout

	player.apply_turd_effect(GHOST, 0.55, 1.0)
	player.global_position = definition.reset_position
	if not await _enter_hazard(player, hazard, definition.position, count + 2):
		return false
	if not player.global_position.is_equal_approx(definition.position) or int(game.get("hazard_ghost_block_count")) < 1:
		_fail("ghost did not suppress reset consequence")
		return false
	player.global_position = definition.reset_position
	await create_timer(maxf(hazard.cooldown, 0.55) + 0.1).timeout
	if player.has_turd_effect(GHOST):
		_fail("ghost did not expire")
		return false
	if not await _enter_hazard(player, hazard, definition.position, count + 3):
		return false
	if not player.global_position.is_equal_approx(definition.reset_position):
		_fail("hazard reset did not resume after Ghost")
		return false

	await create_timer(hazard.cooldown + 0.05).timeout
	player.apply_turd_effect(TURBO, 0.8, 1.5)
	var turbo_remaining: float = player.get_turd_effect_remaining(TURBO)
	if not await _enter_hazard(player, hazard, definition.position, count + 4):
		return false
	if not player.global_position.is_equal_approx(definition.reset_position) or not player.has_turd_effect(TURBO) or player.get_turd_effect_remaining(TURBO) >= turbo_remaining:
		_fail("hazard reset cleared/refreshed Turbo")
		return false
	print("TBR08_GHOST_HAZARD_COMPOSITION_OK")
	print("TBR08_TURBO_SURVIVES_RESET_OK")
	return true


func _validate_final_exit(game: RestroomRuntime) -> bool:
	var collected := 0
	var last_type := ""
	for toilet: TurdToilet in game.toilets:
		if not toilet.has_turd:
			continue
		last_type = toilet.turd_type
		if not toilet.collect():
			_fail("final objective collection")
			return false
		collected += 1
		if game.collected_turds != collected:
			_fail("special objective increment")
			return false
	if collected != game.required_turds or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE or game.heist_exit.is_locked:
		_fail("final exit progression with specials")
		return false
	if last_type != NORMAL and not game.player.has_turd_effect(last_type):
		_fail("final special effect did not coexist with exit unlock")
		return false
	if not game.heist_exit.attempt_exit(game.player) or game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist completion with special effects")
		return false
	print("TBR08_FINAL_EXIT_OK")
	return true


func _enter_hazard(player: BurglarPlayer, hazard: ResetZoneHazard, position: Vector3, expected_count: int) -> bool:
	player.global_position = position
	for frame in 12:
		await physics_frame
		if hazard.activation_count >= expected_count:
			return true
	_fail("hazard did not activate to count %d" % expected_count)
	return false


func _first_toilet(game: RestroomRuntime, type: String) -> TurdToilet:
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd and toilet.get("turd_type") == type:
			return toilet
	return null


func _toilets_of_type(game: RestroomRuntime, type: String) -> Array[TurdToilet]:
	var result: Array[TurdToilet] = []
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd and toilet.get("turd_type") == type:
			result.append(toilet)
	return result


func _turd_material(toilet: TurdToilet) -> StandardMaterial3D:
	return ((toilet.turd_visual.get_node("Lump1") as MeshInstance3D).mesh.material as StandardMaterial3D)


func _turd_color(toilet: TurdToilet) -> Color:
	return _turd_material(toilet).albedo_color


func _effect_hud_text(game: RestroomRuntime) -> String:
	var label = game.get("effect_label")
	return "" if label == null else String(label.text)


func _prepare_and_capture(game: RestroomRuntime, level: Dictionary, evidence: String, path: String) -> void:
	var normal := _first_toilet(game, NORMAL)
	var turbo := _first_toilet(game, TURBO)
	var ghost := _first_toilet(game, GHOST)
	var focus := normal.global_position
	match evidence:
		"normal-turd":
			focus = normal.global_position
		"hot-shit":
			focus = turbo.global_position
		"ghost-turd":
			focus = ghost.global_position
		"turbo-hud":
			turbo.collect()
			focus = turbo.global_position
		"ghost-hud":
			ghost.collect()
			focus = ghost.global_position
		"both-effects":
			turbo.collect()
			ghost.collect()
			focus = (turbo.global_position + ghost.global_position) * 0.5
		"ghost-hazard":
			ghost.collect()
			var definition: Dictionary = level.hazards[0]
			var hazard: ResetZoneHazard = game.hazards_by_id[definition.id]
			if not await _enter_hazard(game.player, hazard, definition.position, 1):
				return
			focus = definition.position
		"restroom-006":
			focus = level.player_spawn + Vector3(0.0, 0.0, -5.0)
		"final-exit":
			for toilet: TurdToilet in game.toilets:
				if toilet.has_turd:
					toilet.collect()
			focus = game.heist_exit.global_position
		_:
			_fail("unknown evidence mode: %s" % evidence)
			return
	await _capture_scene(game, focus, path)
	print("TBR08_%s_SCREENSHOT_OK=%s" % [evidence.to_upper().replace("-", "_"), path])
	quit(0)


func _capture_scene(game: RestroomRuntime, focus: Vector3, path: String) -> void:
	(game.player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = focus + Vector3(5.2, 3.5, 6.2)
	camera.look_at(focus + Vector3(0.0, 0.7, 0.0), Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("special-turd screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R08 special turds acceptance failed: %s" % stage)
	quit(1)
