extends Node3D

@onready var game: RestroomRuntime = $Restroom


func _ready() -> void:
	if not game.load_error.is_empty():
		return
	print("TURD_BURGLAR_RUNTIME_OK")
	call_deferred("_run_automation_if_requested")


func _run_automation_if_requested() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--self-test" in arguments or "--export-self-test" in arguments:
		var success := _run_self_test()
		if success:
			print("TB_SELF_TEST_OK=%s" % game.level_id)
			if game.level_id == "restroom_001":
				print("TB001_TURDS=3")
				print("TB001_EXIT_UNLOCKED")
				print("TB001_HEIST_COMPLETE")
			if "--export-self-test" in arguments:
				print("TB_EXPORT_RUNTIME_OK=%s" % game.level_id)
				if game.level_id == "restroom_001":
					print("TB001_EXPORT_RUNTIME_OK")
		get_tree().quit(0 if success else 1)
		return

	var start_path := _argument_value(arguments, "--screenshot-start=")
	if not start_path.is_empty():
		await _capture_screenshot(start_path)
		print("TB_SCREENSHOT_OK=%s" % start_path)
		if game.level_id == "restroom_001":
			print("TB001_SCREENSHOT_START_OK=%s" % start_path)
		get_tree().quit()
		return

	var complete_path := _argument_value(arguments, "--screenshot-complete=")
	if not complete_path.is_empty():
		if not _run_self_test():
			get_tree().quit(1)
			return
		await _capture_screenshot(complete_path)
		print("TB_SCREENSHOT_OK=%s" % complete_path)
		if game.level_id == "restroom_001":
			print("TB001_SCREENSHOT_COMPLETE_OK=%s" % complete_path)
		get_tree().quit()


func _run_self_test() -> bool:
	if game.collected_turds != 0 or not game.heist_exit.is_locked:
		push_error("Self-test initial state failed for %s" % game.level_id)
		return false
	var collected := 0
	for toilet in game.toilets:
		if not toilet.has_turd:
			if toilet.collect():
				return false
			continue
		if not toilet.collect():
			return false
		collected += 1
		if toilet.collect() or game.collected_turds != collected:
			return false
		if collected < game.required_turds and not game.heist_exit.is_locked:
			return false
	if game.collected_turds != game.required_turds or game.heist_exit.is_locked:
		return false
	if not game.heist_exit.attempt_exit(game.player):
		return false
	return game.state == RestroomRuntime.HeistState.HEIST_COMPLETE


func _capture_screenshot(path: String) -> void:
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save screenshot: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
