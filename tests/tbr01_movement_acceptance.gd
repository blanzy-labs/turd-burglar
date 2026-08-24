extends SceneTree

const EPSILON := 0.02
const TURN_EPSILON := 0.04


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var game: RestroomRuntime = main.get_node("Restroom")
	var player: BurglarPlayer = game.player
	player.set_physics_process(false)

	player.camera_yaw = 0.0
	_step(player, ["move_forward"], 0.016)
	if not _horizontal(player.velocity).is_equal_approx(Vector3(0.0, 0.0, -BurglarPlayer.MOVE_SPEED)):
		_fail("camera yaw 0 forward movement")
		return
	print("TBR01_CAMERA_FORWARD_OK")

	player.camera_yaw = PI * 0.5
	_step(player, ["move_forward"], 0.016)
	var expected_rotated := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, player.camera_yaw) * BurglarPlayer.MOVE_SPEED
	if _horizontal(player.velocity).distance_to(expected_rotated) > EPSILON:
		_fail("camera yaw does not rotate movement")
		return
	print("TBR01_CAMERA_ROTATION_OK")

	var strafe_yaw := 0.35
	for action in ["move_left", "move_right"]:
		player.camera_yaw = strafe_yaw
		player.get_node("Body").rotation.y = strafe_yaw
		_step(player, [action], 0.1)
		if absf(angle_difference(player.get_node("Body").rotation.y, strafe_yaw)) > TURN_EPSILON:
			_fail("%s rotated body away from camera-forward" % action)
			return
	print("TBR01_STRAFE_FACING_OK")

	var backpedal_yaw := -0.4
	player.camera_yaw = backpedal_yaw
	player.get_node("Body").rotation.y = backpedal_yaw
	_step(player, ["move_back"], 0.1)
	if absf(angle_difference(player.get_node("Body").rotation.y, backpedal_yaw)) > TURN_EPSILON:
		_fail("backpedal turned body away from camera-forward")
		return
	print("TBR01_BACKPEDAL_FACING_OK")

	player.camera_yaw = 0.72
	_step(player, ["move_forward", "move_right"], 0.016)
	if absf(_horizontal(player.velocity).length() - BurglarPlayer.MOVE_SPEED) > EPSILON:
		_fail("diagonal movement exceeds configured speed")
		return
	print("TBR01_DIAGONAL_NORMALIZATION_OK")

	player.camera_yaw = PI * 0.5
	player.get_node("Body").rotation.y = 0.0
	_step(player, ["move_forward"], 0.016)
	var smooth_yaw: float = player.get_node("Body").rotation.y
	if smooth_yaw <= 0.0 or smooth_yaw >= player.camera_yaw - TURN_EPSILON:
		_fail("moving facing snapped or failed to approach camera yaw")
		return
	print("TBR01_SMOOTH_FACING_OK")

	player.get_node("Body").rotation.y = 0.27
	player.camera_yaw = -1.2
	_step(player, [], 0.1)
	if absf(angle_difference(player.get_node("Body").rotation.y, 0.27)) > TURN_EPSILON:
		_fail("idle camera movement forced body rotation")
		return
	print("TBR01_IDLE_CAMERA_FREEDOM_OK")

	player.camera_yaw = 0.0
	player.camera_pitch = 0.0
	player.apply_mouse_look(Vector2(-50.0, 20.0))
	if player.camera_yaw <= 0.0 or player.camera_pitch >= 0.0:
		_fail("mouse yaw/pitch behavior")
		return
	player.apply_mouse_look(Vector2(0.0, 10000.0))
	if not is_equal_approx(player.camera_pitch, -0.75):
		_fail("lower pitch clamp")
		return
	player.apply_mouse_look(Vector2(0.0, -10000.0))
	if not is_equal_approx(player.camera_pitch, 0.45):
		_fail("upper pitch clamp")
		return
	print("TBR01_CAMERA_PRESERVATION_OK")

	_release_movement()
	print("TBR01_MOVEMENT_ACCEPTANCE_OK")
	quit(0)


func _step(player: BurglarPlayer, actions: Array, delta: float) -> void:
	_release_movement()
	for action: String in actions:
		Input.action_press(action)
	player.velocity = Vector3.ZERO
	player._physics_process(delta)
	_release_movement()


func _release_movement() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


func _horizontal(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _fail(stage: String) -> void:
	_release_movement()
	push_error("TB-R01 movement acceptance failed: %s" % stage)
	quit(1)
