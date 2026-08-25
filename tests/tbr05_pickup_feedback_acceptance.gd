extends SceneTree

const LEVEL_PATH := "res://levels/restroom_004.json"
const RESTROOM_SCENE := preload("res://scenes/restroom.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: RestroomRuntime = RESTROOM_SCENE.instantiate()
	game.level_path_override = LEVEL_PATH
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty():
		_fail("restroom_004 runtime load: %s" % game.load_error)
		return
	game.player.set_physics_process(false)

	var evidence := _argument_value(OS.get_cmdline_user_args(), "--evidence=")
	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-feedback=")
	if not screenshot_path.is_empty():
		await _prepare_evidence(game, evidence, screenshot_path)
		return

	if not await _validate_toilet_contract():
		return
	if not _validate_targeting_and_prompt(game):
		return
	if not await _validate_runtime_feedback_and_tbr06(game):
		return
	print("TBR05_PICKUP_FEEDBACK_ACCEPTANCE_OK")
	quit(0)


func _validate_toilet_contract() -> bool:
	var toilet: TurdToilet = load("res://scenes/toilet.tscn").instantiate()
	root.add_child(toilet)
	await process_frame
	var signal_count := [0]
	toilet.collected.connect(func(_source: TurdToilet) -> void: signal_count[0] += 1)
	if not toilet.has_turd or toilet.turd_visual == null or not toilet.turd_visual.visible:
		_fail("collectible initial state")
		return false
	if not toilet.has_method("set_targeted"):
		_fail("toilet set_targeted API missing")
		return false
	toilet.set_targeted(true)
	if not toilet.targeted:
		_fail("valid collectible did not enter targeted state")
		return false
	toilet.set_targeted(false)
	if toilet.targeted:
		_fail("targeted state did not clear")
		return false
	if not toilet.collect():
		_fail("first collect was rejected")
		return false
	if toilet.has_turd or signal_count[0] != 1:
		_fail("collection state/signal was not authoritative immediately")
		return false
	if not toilet.pickup_feedback_active or not toilet.turd_visual.visible:
		_fail("pickup visual did not begin after authoritative collection")
		return false
	if toilet.collect() or signal_count[0] != 1:
		_fail("immediate duplicate collection was accepted")
		return false
	toilet.set_targeted(true)
	if toilet.targeted:
		_fail("collected toilet became targeted")
		return false
	var pickup_duration := float(toilet.get("pickup_duration"))
	if pickup_duration < 0.15 or pickup_duration > 0.35:
		_fail("pickup duration outside 0.15-0.35 seconds")
		return false
	await create_timer(pickup_duration + 0.12).timeout
	if toilet.pickup_feedback_active or toilet.turd_visual.visible or toilet.has_turd:
		_fail("pickup feedback did not finish safely")
		return false

	var empty: TurdToilet = load("res://scenes/toilet.tscn").instantiate()
	empty.has_turd = false
	root.add_child(empty)
	await process_frame
	var empty_signals := [0]
	empty.collected.connect(func(_source: TurdToilet) -> void: empty_signals[0] += 1)
	empty.set_targeted(true)
	if empty.targeted or empty.collect() or empty_signals[0] != 0 or empty.pickup_feedback_active:
		_fail("empty toilet exposed collectible behavior")
		return false
	print("TBR05_COLLECTION_ONCE_OK")
	print("TBR05_TARGET_STATE_OK")
	print("TBR05_EMPTY_TOILET_OK")
	toilet.queue_free()
	empty.queue_free()
	return true


func _validate_targeting_and_prompt(game: RestroomRuntime) -> bool:
	if game.prompt_label.text != "E — STEAL TURD":
		_fail("interaction prompt text")
		return false
	var collectibles := _collectibles(game)
	var empty := _first_empty(game)
	if collectibles.size() < 2 or empty == null:
		_fail("restroom_004 targeting fixtures")
		return false
	game.player.global_position = collectibles[0].global_position
	game.player.call("_update_interaction_target")
	if game.player.nearby_toilet != collectibles[0] or not collectibles[0].targeted or not game.prompt_label.visible:
		_fail("nearest collectible targeting/prompt")
		return false
	game.player.global_position = collectibles[1].global_position
	game.player.call("_update_interaction_target")
	if game.player.nearby_toilet != collectibles[1] or collectibles[0].targeted or not collectibles[1].targeted:
		_fail("target handoff did not clear prior collectible")
		return false
	game.player.global_position = empty.global_position
	for collectible: TurdToilet in collectibles:
		collectible.global_position = empty.global_position + Vector3(20.0, 0.0, 0.0)
	game.player.call("_update_interaction_target")
	if game.player.nearby_toilet != null or empty.targeted or game.prompt_label.visible:
		_fail("empty-only range exposed prompt/target")
		return false
	game.player.global_position = Vector3(1000.0, 0.0, 1000.0)
	game.player.call("_update_interaction_target")
	if game.prompt_label.visible:
		_fail("out-of-range prompt remained visible")
		return false
	print("TBR05_NEAREST_PROMPT_OK")
	return true


func _validate_runtime_feedback_and_tbr06(game: RestroomRuntime) -> bool:
	# Recreate the runtime because the targeting proof deliberately moved fixtures.
	game.queue_free()
	await process_frame
	game = RESTROOM_SCENE.instantiate()
	game.level_path_override = LEVEL_PATH
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	var collectibles := _collectibles(game)
	var empty := _first_empty(game)
	var trigger: Dictionary = _sorted_triggers(game)[0]
	var door: StatefulDoor = game.doors_by_id[trigger.action.door_id]
	if trigger.threshold != 2 or door.state != StatefulDoor.CLOSED:
		_fail("TB-R06 threshold fixture was not closed at two")
		return false
	var feedback_before: int = game.collection_feedback_count
	if empty.collect() or game.collected_turds != 0 or game.collection_feedback_count != feedback_before:
		_fail("empty toilet advanced runtime feedback/state")
		return false
	if not collectibles[0].collect():
		_fail("first threshold collection")
		return false
	if game.collected_turds != 1 or game.trigger_fired[trigger.id] or door.state != StatefulDoor.CLOSED:
		_fail("door fired before collect_count threshold")
		return false
	if game.counter_label.text != "TURDS: 1 / %d" % game.required_turds or game.collection_feedback_count != 1 or game.counter_punch_count != 1:
		_fail("first HUD feedback was not immediate/once")
		return false
	if not game.plus_one_label.visible or game.plus_one_label.text != "+1 TURD":
		_fail("+1 TURD feedback missing")
		return false
	if not collectibles[1].collect():
		_fail("second threshold collection")
		return false
	if game.collected_turds != 2 or not game.trigger_fired[trigger.id] or game.trigger_fire_count[trigger.id] != 1:
		_fail("collect_count trigger was not authoritative at threshold")
		return false
	if door.state not in [StatefulDoor.OPENING, StatefulDoor.OPEN] or door.open_count != 1:
		_fail("door did not begin opening immediately at threshold")
		return false
	if not collectibles[1].pickup_feedback_active:
		_fail("door timing proof did not overlap pickup animation")
		return false
	if game.collection_feedback_count != 2 or game.counter_punch_count != 2 or game.counter_label.text != "TURDS: 2 / %d" % game.required_turds:
		_fail("second HUD feedback did not occur exactly once")
		return false
	if collectibles[0].collect() or collectibles[1].collect():
		_fail("duplicate threshold collection accepted")
		return false
	if game.collected_turds != 2 or game.trigger_fire_count[trigger.id] != 1 or door.open_count != 1 or game.collection_feedback_count != 2 or game.counter_punch_count != 2:
		_fail("duplicate collection advanced trigger/HUD")
		return false
	print("TBR05_TBR06_IMMEDIATE_THRESHOLD_OK")

	for index in range(2, collectibles.size()):
		if not collectibles[index].collect():
			_fail("remaining collection %d" % index)
			return false
	if game.collected_turds != game.required_turds or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE or game.heist_exit.is_locked:
		_fail("final exit did not unlock")
		return false
	if not game.status_label.visible or game.exit_unlock_feedback_count != 1:
		_fail("EXIT UNLOCKED feedback missing/not once")
		return false
	for configured_trigger: Dictionary in game.level_definition.triggers:
		var configured_door: StatefulDoor = game.doors_by_id[configured_trigger.action.door_id]
		if game.trigger_fire_count[configured_trigger.id] != 1 or configured_door.open_count != 1:
			_fail("restroom_004 one-shot progression regression")
			return false
	if game.collection_feedback_count != game.required_turds or game.counter_punch_count != game.required_turds:
		_fail("HUD feedback count did not match successful collections")
		return false
	if not game.heist_exit.attempt_exit(game.player) or game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist completion regression")
		return false
	game.player.call("_update_interaction_target")
	if game.prompt_label.visible:
		_fail("prompt visible after completed heist")
		return false
	print("TBR05_HUD_FEEDBACK_OK")
	print("TBR05_FINAL_EXIT_OK")
	print("TBR05_RESTROOM_004_OK")
	return true


func _prepare_evidence(game: RestroomRuntime, evidence: String, path: String) -> void:
	var collectibles := _collectibles(game)
	var focus: Vector3 = collectibles[0].global_position + Vector3(0.0, 0.8, 0.0)
	match evidence:
		"normal-collectible":
			pass
		"targeted-collectible":
			game.player.global_position = collectibles[0].global_position
			game.player.call("_update_interaction_target")
		"pickup-feedback", "hud-feedback":
			collectibles[0].collect()
		"final-exit":
			for toilet: TurdToilet in collectibles:
				toilet.collect()
			focus = game.heist_exit.global_position + Vector3(0.0, 1.0, 0.0)
		"door-threshold":
			collectibles[0].collect()
			collectibles[1].collect()
			var trigger: Dictionary = _sorted_triggers(game)[0]
			focus = game.doors_by_id[trigger.action.door_id].global_position + Vector3(0.0, 1.0, 0.0)
		_:
			_fail("unknown evidence mode: %s" % evidence)
			return
	await _capture_scene(game, focus, path)
	print("TBR05_%s_SCREENSHOT_OK=%s" % [evidence.to_upper().replace("-", "_"), path])
	quit(0)


func _capture_scene(game: RestroomRuntime, focus: Vector3, path: String) -> void:
	(game.player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.global_position = focus + Vector3(4.7, 3.2, 5.4)
	camera.look_at(focus, Vector3.UP)
	camera.fov = 50.0
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("screenshot save: %s" % error_string(error))


func _collectibles(game: RestroomRuntime) -> Array[TurdToilet]:
	var result: Array[TurdToilet] = []
	for toilet: TurdToilet in game.toilets:
		if toilet.has_turd:
			result.append(toilet)
	return result


func _first_empty(game: RestroomRuntime) -> TurdToilet:
	for toilet: TurdToilet in game.toilets:
		if not toilet.has_turd:
			return toilet
	return null


func _sorted_triggers(game: RestroomRuntime) -> Array:
	var result: Array = game.level_definition.triggers.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.threshold < b.threshold)
	return result


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R05 pickup feedback acceptance failed: %s" % stage)
	quit(1)
