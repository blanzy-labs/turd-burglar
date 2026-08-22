extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if TurdLevelLoader.selected_level_id(OS.get_cmdline_user_args()) != "restroom_002":
		_fail("test must run with --level=restroom_002")
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var game: RestroomRuntime = main.get_node("Restroom")

	if game.level_id != "restroom_002" or game.level_name != "Second Flush":
		_fail("level identity")
		return
	if game.toilets.size() != 6 or game.collectible_turd_count != 5 or game.required_turds != 5:
		_fail("level counts")
		return
	var empty_toilets := game.toilets.filter(func(toilet: TurdToilet) -> bool: return not toilet.has_turd)
	if empty_toilets.size() != 1:
		_fail("empty toilet count")
		return
	if game.counter_label.text != "TURDS: 0 / 5" or game.collected_turds != 0 or not game.heist_exit.is_locked:
		_fail("initial state and HUD")
		return
	print("TB002_TEST_START_STATE_OK")

	var empty: TurdToilet = empty_toilets[0]
	if empty.turd_visual.visible or empty.collect() or game.collected_turds != 0:
		_fail("empty toilet collection")
		return
	game.player.global_position = empty.global_position + Vector3(0.0, 0.1, 2.0)
	game.player.velocity = Vector3.ZERO
	await physics_frame
	if game.player.nearby_toilet != null or game.prompt_label.visible:
		_fail("empty toilet interaction prompt")
		return
	print("TB002_TEST_EMPTY_TOILET_OK")

	var collectibles := game.toilets.filter(func(toilet: TurdToilet) -> bool: return toilet.has_turd)
	for index in 4:
		if not collectibles[index].collect() or game.collected_turds != index + 1:
			_fail("collection %d" % (index + 1))
			return
		if collectibles[index].collect() or game.collected_turds != index + 1:
			_fail("duplicate collection %d" % (index + 1))
			return
	if not game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.PLAYING:
		_fail("exit locked after four")
		return
	if game.counter_label.text != "TURDS: 4 / 5":
		_fail("HUD after four")
		return
	print("TB002_TEST_LOCKED_AFTER_FOUR_OK")
	print("TB002_TEST_DUPLICATE_PROTECTION_OK")

	if not collectibles[4].collect() or game.collected_turds != 5:
		_fail("fifth collection")
		return
	if game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE:
		_fail("exit unlock after five")
		return
	if game.counter_label.text != "TURDS: 5 / 5":
		_fail("HUD after five")
		return
	print("TB002_TEST_HUD_DYNAMIC_OK")
	print("TB002_EXIT_UNLOCKED")

	if not game.heist_exit.attempt_exit(game.player):
		_fail("exit trigger")
		return
	if game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist completion state")
		return
	if "TURDS STOLEN: 5 / 5" not in game.completion_text.text:
		_fail("completion HUD")
		return
	print("TB002_HEIST_COMPLETE")
	print("TB002_GAMEPLAY_ACCEPTANCE_OK")
	quit(0)


func _fail(stage: String) -> void:
	push_error("TB-002 Second Flush acceptance failed: %s" % stage)
	quit(1)
