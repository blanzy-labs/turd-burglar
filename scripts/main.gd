extends Node3D

@onready var game: FirstFlushRestroom = $Restroom


func _ready() -> void:
	print("TURD_BURGLAR_RUNTIME_OK")
	call_deferred("_run_automation_if_requested")


func _run_automation_if_requested() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--self-test" in arguments or "--export-self-test" in arguments:
		var success := _run_self_test()
		if success:
			print("TB001_TURDS=3")
			print("TB001_EXIT_UNLOCKED")
			print("TB001_HEIST_COMPLETE")
			if "--export-self-test" in arguments:
				print("TB001_EXPORT_RUNTIME_OK")
		get_tree().quit(0 if success else 1)
		return

	var start_path := _argument_value(arguments, "--screenshot-start=")
	if not start_path.is_empty():
		await _capture_screenshot(start_path)
		print("TB001_SCREENSHOT_START_OK=%s" % start_path)
		get_tree().quit()
		return

	var complete_path := _argument_value(arguments, "--screenshot-complete=")
	if not complete_path.is_empty():
		if not _run_self_test():
			get_tree().quit(1)
			return
		await _capture_screenshot(complete_path)
		print("TB001_SCREENSHOT_COMPLETE_OK=%s" % complete_path)
		get_tree().quit()


func _run_self_test() -> bool:
	if game.collected_turds != 0 or not game.heist_exit.is_locked:
		push_error("TB001 self-test initial state failed")
		return false
	if not game.toilets[0].collect():
		return false
	if game.collected_turds != 1 or game.toilets[0].has_turd:
		return false
	if game.toilets[0].collect() or game.collected_turds != 1:
		return false
	game.toilets[1].collect()
	game.toilets[2].collect()
	if game.collected_turds != 3 or game.heist_exit.is_locked:
		return false
	if not game.heist_exit.attempt_exit(game.player):
		return false
	return game.state == FirstFlushRestroom.HeistState.HEIST_COMPLETE


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
