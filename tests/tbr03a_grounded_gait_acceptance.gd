extends SceneTree

const TRIPOD_A := ["LegLeftFront", "LegLeftRear", "LegRightMiddle"]
const TRIPOD_B := ["LegRightFront", "LegRightRear", "LegLeftMiddle"]
const ALL_LEGS := [
	"LegLeftFront", "LegLeftMiddle", "LegLeftRear",
	"LegRightFront", "LegRightMiddle", "LegRightRear",
]
const STEP_DELTA := 0.016
const TB_R03_BASELINE_APPROX_FOOT_Y := 0.0891

var neutral: Dictionary = {}
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
	var body := player.get_node("Body") as Node3D

	print("TBR03A_PRE_REFINEMENT_APPROX_FOOT_Y=%.4f" % TB_R03_BASELINE_APPROX_FOOT_Y)

	for part_name in ["Body", "Thorax", "Abdomen"]:
		var part: Node3D = body if part_name == "Body" else body.get_node(part_name)
		neutral[part_name] = part.transform
	for leg_name in ALL_LEGS:
		var leg := body.get_node(leg_name) as Node3D
		var upper := leg.find_child("Upper", true, false) as Node3D
		var lower := leg.find_child("Lower", true, false) as Node3D
		if upper == null or lower == null or not _node_has_mesh(upper) or not _node_has_mesh(lower):
			_fail("articulated upper/lower structure missing for %s" % leg_name)
			return
		neutral["%s/Root" % leg_name] = leg.transform
		neutral["%s/Upper" % leg_name] = upper.transform
		neutral["%s/Lower" % leg_name] = lower.transform
	print("TBR03A_SIX_ARTICULATED_LEGS_OK")

	var neutral_foot_y := {}
	var neutral_min := INF
	var neutral_max := -INF
	for leg_name in ALL_LEGS:
		var lower := (body.get_node(leg_name) as Node3D).find_child("Lower", true, false) as Node3D
		var foot_y := _part_min_y(body, lower)
		neutral_foot_y[leg_name] = foot_y
		neutral_min = minf(neutral_min, foot_y)
		neutral_max = maxf(neutral_max, foot_y)
		print("TBR03A_NEUTRAL_%s_FOOT_Y=%.4f" % [leg_name.to_upper(), foot_y])
	if neutral_min < -0.05 or neutral_max > 0.08:
		_fail("neutral lower-leg endpoints are not near floor: %.4f..%.4f" % [neutral_min, neutral_max])
		return
	print("TBR03A_GROUNDING_TOLERANCE_OK")

	var upper_max := {}
	var lower_max := {}
	var foot_min := {}
	var foot_max := {}
	for leg_name in ALL_LEGS:
		upper_max[leg_name] = 0.0
		lower_max[leg_name] = 0.0
		foot_min[leg_name] = INF
		foot_max[leg_name] = -INF
	var best_tripod_score := 0.0
	var best_counter_score := 0.0
	var max_body_y := 0.0
	var max_body_roll := 0.0
	var max_thorax_angle := 0.0
	var max_abdomen_angle := 0.0
	for frame in 100:
		_step(player, ["move_forward"], true)
		for leg_name in ALL_LEGS:
			var leg := body.get_node(leg_name) as Node3D
			var upper := leg.find_child("Upper", true, false) as Node3D
			var lower := leg.find_child("Lower", true, false) as Node3D
			upper_max[leg_name] = maxf(upper_max[leg_name], _transform_distance(neutral["%s/Upper" % leg_name], upper.transform))
			lower_max[leg_name] = maxf(lower_max[leg_name], _transform_distance(neutral["%s/Lower" % leg_name], lower.transform))
			var foot_y := _part_min_y(body, lower)
			foot_min[leg_name] = minf(foot_min[leg_name], foot_y)
			foot_max[leg_name] = maxf(foot_max[leg_name], foot_y)
		best_tripod_score = maxf(best_tripod_score, _tripod_score(body))
		best_counter_score = maxf(best_counter_score, _body_counter_score(body))
		var neutral_body: Transform3D = neutral.Body
		max_body_y = maxf(max_body_y, absf(body.position.y - neutral_body.origin.y))
		max_body_roll = maxf(max_body_roll, absf(angle_difference(neutral_body.basis.get_euler().z, body.rotation.z)))
		max_thorax_angle = maxf(max_thorax_angle, _rotation_distance(neutral.Thorax, (body.get_node("Thorax") as Node3D).transform))
		max_abdomen_angle = maxf(max_abdomen_angle, _rotation_distance(neutral.Abdomen, (body.get_node("Abdomen") as Node3D).transform))
	_release_movement()

	for leg_name in ALL_LEGS:
		if upper_max[leg_name] < 0.12:
			_fail("upper leg articulation too weak: %s %.4f" % [leg_name, upper_max[leg_name]])
			return
		if lower_max[leg_name] < 0.08:
			_fail("lower leg articulation too weak: %s %.4f" % [leg_name, lower_max[leg_name]])
			return
		if foot_min[leg_name] > 0.08 or foot_min[leg_name] < -0.08:
			_fail("support phase misses floor tolerance: %s %.4f" % [leg_name, foot_min[leg_name]])
			return
		if foot_max[leg_name] - foot_min[leg_name] < 0.025:
			_fail("swing/support height difference too small: %s %.4f" % [leg_name, foot_max[leg_name] - foot_min[leg_name]])
			return
	print("TBR03A_UPPER_LOWER_ARTICULATION_OK")
	print("TBR03A_SUPPORT_SWING_HEIGHT_OK")
	if best_tripod_score < 0.05:
		_fail("articulated tripod opposition not demonstrated")
		return
	print("TBR03A_TRIPOD_OPPOSITION_OK")

	if max_body_y < 0.008 or max_body_y > 0.06:
		_fail("body compression absent or excessive: %.4f" % max_body_y)
		return
	if max_body_roll < 0.008 or max_body_roll > 0.07:
		_fail("body weight transfer absent or excessive: %.4f" % max_body_roll)
		return
	if max_thorax_angle < 0.008 or max_thorax_angle > 0.07:
		_fail("thorax articulation absent or excessive: %.4f" % max_thorax_angle)
		return
	if max_abdomen_angle < 0.004 or max_abdomen_angle > 0.05:
		_fail("abdomen counter-motion absent or excessive: %.4f" % max_abdomen_angle)
		return
	if best_counter_score < 0.01:
		_fail("thorax/abdomen counter-motion not demonstrated")
		return
	print("TBR03A_BODY_ARTICULATION_LIMITS_OK")

	for frame in 180:
		_step(player, [], true)
	for leg_name in ALL_LEGS:
		var leg := body.get_node(leg_name) as Node3D
		var upper := leg.find_child("Upper", true, false) as Node3D
		var lower := leg.find_child("Lower", true, false) as Node3D
		if _transform_distance(neutral["%s/Upper" % leg_name], upper.transform) > 0.035:
			_fail("upper leg did not recover: %s" % leg_name)
			return
		if _transform_distance(neutral["%s/Lower" % leg_name], lower.transform) > 0.035:
			_fail("lower leg did not recover: %s" % leg_name)
			return
	if _transform_distance(neutral.Body, body.transform) > 0.04:
		_fail("Body did not recover")
		return
	if _transform_distance(neutral.Thorax, (body.get_node("Thorax") as Node3D).transform) > 0.035:
		_fail("Thorax did not recover")
		return
	if _transform_distance(neutral.Abdomen, (body.get_node("Abdomen") as Node3D).transform) > 0.035:
		_fail("Abdomen did not recover")
		return
	print("TBR03A_IDLE_RECOVERY_OK")

	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	if not collision.shape is CapsuleShape3D:
		_fail("simple capsule collision not preserved")
		return
	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-grounded=")
	var screenshot_pose := _argument_value(OS.get_cmdline_user_args(), "--grounded-pose=")
	if not screenshot_path.is_empty():
		await _capture_grounded_pose(main, player, screenshot_pose, screenshot_path)
		print("TBR03A_%s_SCREENSHOT_OK=%s" % [screenshot_pose.to_upper(), screenshot_path])

	print("TBR03A_GROUNDED_GAIT_ACCEPTANCE_OK")
	quit(0)


func _step(player: BurglarPlayer, actions: Array, anchor: bool) -> void:
	_release_movement()
	for action: String in actions:
		Input.action_press(action)
	var anchored := player.global_position
	player._physics_process(STEP_DELTA)
	if anchor:
		player.global_position = anchored
	_release_movement()


func _tripod_score(body: Node3D) -> float:
	var best := 0.0
	for axis in 3:
		var a := _average_upper_delta(body, TRIPOD_A, axis)
		var b := _average_upper_delta(body, TRIPOD_B, axis)
		if a * b < 0.0:
			best = maxf(best, absf(a) + absf(b))
	return best


func _average_upper_delta(body: Node3D, names: Array, axis: int) -> float:
	var total := 0.0
	for leg_name in names:
		var upper := (body.get_node(leg_name) as Node3D).find_child("Upper", true, false) as Node3D
		var base: Transform3D = neutral["%s/Upper" % leg_name]
		total += angle_difference(base.basis.get_euler()[axis], upper.rotation[axis])
	return total / names.size()


func _body_counter_score(body: Node3D) -> float:
	var thorax := body.get_node("Thorax") as Node3D
	var abdomen := body.get_node("Abdomen") as Node3D
	var thorax_base: Transform3D = neutral.Thorax
	var abdomen_base: Transform3D = neutral.Abdomen
	var thorax_roll := angle_difference(thorax_base.basis.get_euler().z, thorax.rotation.z)
	var abdomen_roll := angle_difference(abdomen_base.basis.get_euler().z, abdomen.rotation.z)
	return absf(thorax_roll) + absf(abdomen_roll) if thorax_roll * abdomen_roll < 0.0 else 0.0


func _rotation_distance(base: Transform3D, current: Transform3D) -> float:
	return base.basis.get_rotation_quaternion().angle_to(current.basis.get_rotation_quaternion())


func _transform_distance(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + _rotation_distance(a, b)


func _part_min_y(body: Node3D, part: Node3D) -> float:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(part, meshes)
	var result := INF
	for mesh_node in meshes:
		var relative := body.global_transform.affine_inverse() * mesh_node.global_transform
		var bounds: AABB = body.transform * relative * mesh_node.get_aabb()
		result = minf(result, bounds.position.y)
	return result


func _node_has_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child in node.get_children():
		if _node_has_mesh(child):
			return true
	return false


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _capture_grounded_pose(main: Node3D, player: BurglarPlayer, pose: String, path: String) -> void:
	player.global_position = initial_player_position
	player.velocity = Vector3.ZERO
	for frame in 180:
		_step(player, [], true)
	if pose == "moving":
		for frame in 20:
			_step(player, ["move_forward"], true)
	elif pose != "idle":
		_fail("unknown grounded screenshot pose %s" % pose)
		return
	var gameplay_camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	gameplay_camera.current = false
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_position = player.global_position + Vector3(2.35, 0.82, 2.55)
	camera.look_at(player.global_position + Vector3(0.0, 0.42, 0.0), Vector3.UP)
	camera.fov = 48.0
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("grounded screenshot save: %s" % error_string(error))


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
	push_error("TB-R03A grounded gait acceptance failed: %s" % stage)
	quit(1)
