extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var game: RestroomRuntime = main.get_node("Restroom")
	if game.level_id != "restroom_001" or game.level_name != "First Flush" or game.required_turds != 3:
		_fail("First Flush level data")
		return
	if game.counter_label.text != "TURDS: 0 / 3":
		_fail("dynamic initial HUD")
		return

	if game.collected_turds != 0 or not game.heist_exit.is_locked:
		_fail("start state")
		return
	print("TB001_TEST_START_STATE_OK")

	var movement_start := game.player.global_position
	Input.action_press("move_forward")
	for frame in 8:
		await physics_frame
	Input.action_release("move_forward")
	if game.player.global_position.z >= movement_start.z - 0.05:
		_fail("W movement")
		return
	print("TB001_TEST_MOVEMENT_OK")

	var camera_start := game.player.camera_pivot.rotation
	game.player.apply_mouse_look(Vector2(42.0, -18.0))
	if game.player.camera_pivot.rotation.is_equal_approx(camera_start):
		_fail("mouse camera")
		return
	print("TB001_TEST_CAMERA_OK")

	game.player.global_position = game.toilets[0].global_position + Vector3(0.0, 0.1, 2.0)
	game.player.velocity = Vector3.ZERO
	await physics_frame
	if game.player.nearby_toilet != game.toilets[0] or not game.prompt_label.visible:
		_fail("interaction prompt")
		return
	var interact_event := InputEventKey.new()
	interact_event.physical_keycode = KEY_E
	interact_event.pressed = true
	game.player._unhandled_input(interact_event)
	if game.collected_turds != 1 or game.toilets[0].has_turd:
		_fail("first collection")
		return
	print("TB001_TEST_FIRST_COLLECTION_OK")

	game.player._unhandled_input(interact_event)
	if game.collected_turds != 1:
		_fail("duplicate protection")
		return
	print("TB001_TEST_DUPLICATE_PROTECTION_OK")

	if not game.toilets[1].collect() or not game.toilets[2].collect():
		_fail("remaining collections")
		return
	if game.collected_turds != 3 or game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE:
		_fail("objective completion")
		return
	if game.counter_label.text != "TURDS: 3 / 3":
		_fail("dynamic completed HUD")
		return
	print("TB001_TURDS=3")
	print("TB001_EXIT_UNLOCKED")

	if not game.heist_exit.attempt_exit(game.player):
		_fail("exit trigger")
		return
	if game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist completion")
		return
	print("TB001_HEIST_COMPLETE")

	current_scene = main
	game.request_restart()
	await process_frame
	await process_frame
	var restarted_game: RestroomRuntime = current_scene.get_node("Restroom")
	if restarted_game.collected_turds != 0 or not restarted_game.heist_exit.is_locked:
		_fail("restart")
		return
	print("TB001_TEST_RESTART_OK")
	print("TURD_BURGLAR_RUNTIME_OK")
	quit(0)


func _fail(stage: String) -> void:
	push_error("TB001 acceptance failed: %s" % stage)
	quit(1)
