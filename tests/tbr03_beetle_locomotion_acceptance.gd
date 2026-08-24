extends SceneTree

const TRIPOD_A := ["LegLeftFront", "LegLeftRear", "LegRightMiddle"]
const TRIPOD_B := ["LegRightFront", "LegRightRear", "LegLeftMiddle"]
const ALL_LEGS := [
	"LegLeftFront", "LegLeftMiddle", "LegLeftRear",
	"LegRightFront", "LegRightMiddle", "LegRightRear",
]
const ANTENNAE := ["AntennaLeft", "AntennaRight"]
const STEP_DELTA := 0.016

var neutral_transforms: Dictionary = {}
var neutral_body_transform: Transform3D
var initial_player_position: Vector3


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
	initial_player_position = player.global_position
	var body := player.get_node_or_null("Body") as Node3D
	if body == null:
		_fail("Body visual root")
		return
	for node_name in ALL_LEGS + ANTENNAE:
		var part := body.get_node_or_null(node_name) as Node3D
		if part == null:
			_fail("missing locomotion part %s" % node_name)
			return
		neutral_transforms[node_name] = part.transform
	neutral_body_transform = body.transform

	_release_movement()
	for frame in 24:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	if not _legs_near_neutral(body, 0.002, 0.004):
		_fail("idle leg transforms changed from rest")
		return
	if body.position.distance_to(neutral_body_transform.origin) > 0.002:
		_fail("idle body offset")
		return
	print("TBR03_IDLE_STATE_OK")

	var leg_max_motion := {}
	for leg_name in ALL_LEGS:
		leg_max_motion[leg_name] = 0.0
	var antenna_max_motion := {"AntennaLeft": 0.0, "AntennaRight": 0.0}
	var moving_path := 0.0
	var best_tripod_score := 0.0
	var max_body_bob := 0.0
	var max_body_sway := 0.0
	var previous_leg_transforms := _current_leg_transforms(body)
	for frame in 72:
		_step_player(player, ["move_forward"], 1.0, STEP_DELTA, true)
		var current_leg_transforms := _current_leg_transforms(body)
		for leg_name in ALL_LEGS:
			var neutral: Transform3D = neutral_transforms[leg_name]
			var current: Transform3D = current_leg_transforms[leg_name]
			leg_max_motion[leg_name] = maxf(leg_max_motion[leg_name], _transform_distance(neutral, current))
			moving_path += _transform_distance(previous_leg_transforms[leg_name], current)
		previous_leg_transforms = current_leg_transforms
		best_tripod_score = maxf(best_tripod_score, _tripod_opposition_score(body))
		max_body_bob = maxf(max_body_bob, absf(body.position.y - neutral_body_transform.origin.y))
		max_body_sway = maxf(max_body_sway, absf(angle_difference(neutral_body_transform.basis.get_euler().z, body.rotation.z)))
		for antenna_name in ANTENNAE:
			antenna_max_motion[antenna_name] = maxf(
				antenna_max_motion[antenna_name],
				_transform_distance(neutral_transforms[antenna_name], body.get_node(antenna_name).transform)
			)
	_release_movement()
	if moving_path < 0.25:
		_fail("moving gait did not advance through visible poses")
		return
	print("TBR03_PHASE_ADVANCEMENT_OK")
	for leg_name in ALL_LEGS:
		if leg_max_motion[leg_name] < 0.025:
			_fail("leg omitted from gait: %s" % leg_name)
			return
	print("TBR03_SIX_LEG_COVERAGE_OK")
	if best_tripod_score < 0.035:
		_fail("opposing tripod groups were not demonstrated")
		return
	print("TBR03_TRIPOD_OPPOSITION_OK")
	if max_body_bob < 0.005 or max_body_bob > 0.06:
		_fail("body bob absent or excessive: %.4f" % max_body_bob)
		return
	if max_body_sway > 0.1:
		_fail("body sway excessive: %.4f" % max_body_sway)
		return
	for antenna_name in ANTENNAE:
		if antenna_max_motion[antenna_name] < 0.008 or antenna_max_motion[antenna_name] > 0.35:
			_fail("antenna motion absent or excessive: %s %.4f" % [antenna_name, antenna_max_motion[antenna_name]])
			return
	print("TBR03_BODY_ANTENNA_MOTION_OK")

	for frame in 150:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	if not _legs_near_neutral(body, 0.012, 0.03):
		_fail("legs did not return toward neutral")
		return
	if body.position.distance_to(neutral_body_transform.origin) > 0.012:
		_fail("body did not return toward neutral")
		return
	var settled_transforms := _current_leg_transforms(body)
	for frame in 30:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	for leg_name in ALL_LEGS:
		if _transform_distance(settled_transforms[leg_name], body.get_node(leg_name).transform) > 0.006:
			_fail("idle gait continued accumulating: %s" % leg_name)
			return
	print("TBR03_IDLE_RETURN_OK")

	var half_speed_path := _measure_gait_path(player, body, 0.5, 150)
	for frame in 150:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	var full_speed_path := _measure_gait_path(player, body, 1.0, 150)
	_release_movement()
	if full_speed_path < half_speed_path * 1.12:
		_fail("gait frequency did not scale with horizontal speed: half %.3f full %.3f" % [half_speed_path, full_speed_path])
		return
	print("TBR03_SPEED_SCALING_OK")

	for frame in 150:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	var min_leg_y := INF
	for leg_name in ALL_LEGS:
		var leg := body.get_node(leg_name) as MeshInstance3D
		var local_bounds: AABB = body.transform * leg.transform * leg.get_aabb()
		min_leg_y = minf(min_leg_y, local_bounds.position.y)
	if min_leg_y < -0.1 or min_leg_y > 0.14:
		_fail("leg grounding outside practical floor range: %.3f" % min_leg_y)
		return
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	if not collision.shape is CapsuleShape3D:
		_fail("simple capsule collision was not preserved")
		return
	print("TBR03_GROUNDING_COLLISION_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-locomotion=")
	var screenshot_pose := _argument_value(OS.get_cmdline_user_args(), "--locomotion-pose=")
	if not screenshot_path.is_empty():
		await _capture_pose(player, body, screenshot_pose, screenshot_path)
		print("TBR03_%s_SCREENSHOT_OK=%s" % [screenshot_pose.to_upper(), screenshot_path])

	print("TBR03_BEETLE_LOCOMOTION_ACCEPTANCE_OK")
	quit(0)


func _step_player(player: BurglarPlayer, actions: Array, strength: float, delta: float, anchor: bool) -> void:
	_release_movement()
	for action: String in actions:
		Input.action_press(action, strength)
	var anchored_position := player.global_position
	player._physics_process(delta)
	if anchor:
		player.global_position = anchored_position
	_release_movement()


func _measure_gait_path(player: BurglarPlayer, body: Node3D, strength: float, frames: int) -> float:
	var path := 0.0
	var previous := _current_leg_transforms(body)
	for frame in frames:
		_step_player(player, ["move_forward"], strength, STEP_DELTA, true)
		var current := _current_leg_transforms(body)
		for leg_name in ALL_LEGS:
			path += _transform_distance(previous[leg_name], current[leg_name])
		previous = current
	return path


func _tripod_opposition_score(body: Node3D) -> float:
	var best := 0.0
	for axis in 3:
		var a := _average_rotation_delta(body, TRIPOD_A, axis)
		var b := _average_rotation_delta(body, TRIPOD_B, axis)
		if a * b < 0.0:
			best = maxf(best, absf(a) + absf(b))
	return best


func _average_rotation_delta(body: Node3D, names: Array, axis: int) -> float:
	var total := 0.0
	for node_name in names:
		var neutral_euler: Vector3 = (neutral_transforms[node_name] as Transform3D).basis.get_euler()
		var current_euler: Vector3 = (body.get_node(node_name) as Node3D).rotation
		total += angle_difference(neutral_euler[axis], current_euler[axis])
	return total / names.size()


func _current_leg_transforms(body: Node3D) -> Dictionary:
	var result := {}
	for leg_name in ALL_LEGS:
		result[leg_name] = (body.get_node(leg_name) as Node3D).transform
	return result


func _legs_near_neutral(body: Node3D, position_tolerance: float, angle_tolerance: float) -> bool:
	for leg_name in ALL_LEGS:
		var neutral: Transform3D = neutral_transforms[leg_name]
		var current: Transform3D = body.get_node(leg_name).transform
		if neutral.origin.distance_to(current.origin) > position_tolerance:
			return false
		if neutral.basis.get_rotation_quaternion().angle_to(current.basis.get_rotation_quaternion()) > angle_tolerance:
			return false
	return true


func _transform_distance(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())


func _capture_pose(player: BurglarPlayer, body: Node3D, pose: String, screenshot_path: String) -> void:
	player.global_position = initial_player_position
	player.velocity = Vector3.ZERO
	for frame in 150:
		_step_player(player, [], 1.0, STEP_DELTA, true)
	if pose == "moving":
		for frame in 18:
			_step_player(player, ["move_forward"], 1.0, STEP_DELTA, true)
	elif pose != "idle":
		_fail("unknown screenshot pose %s" % pose)
		return
	var spring_arm := player.get_node("CameraPivot/SpringArm3D") as SpringArm3D
	spring_arm.spring_length = 3.0
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(screenshot_path)
	if error != OK:
		_fail("locomotion screenshot save: %s" % error_string(error))


func _release_movement() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	_release_movement()
	push_error("TB-R03 beetle locomotion acceptance failed: %s" % stage)
	quit(1)
