class_name BurglarPlayer
extends CharacterBody3D

const MOVE_SPEED := 5.0
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.003
const INTERACTION_RANGE := 2.65
const GAIT_IDLE_SPEED := 0.08
const GAIT_BLEND_SPEED := 4.5
const GAIT_MIN_FREQUENCY := 2.2
const GAIT_MAX_FREQUENCY := 4.8
const TRIPOD_A := [&"LegLeftFront", &"LegLeftRear", &"LegRightMiddle"]
const LEG_NAMES := [
	&"LegLeftFront", &"LegLeftMiddle", &"LegLeftRear",
	&"LegRightFront", &"LegRightMiddle", &"LegRightRear",
]

@onready var camera_pivot: Node3D = $CameraPivot
@onready var visual_body: Node3D = $Body

var camera_yaw := 0.0
var camera_pitch := -0.18
var game: Node
var nearby_toilet: Node
var gait_phase := 0.0
var locomotion_weight := 0.0
var neutral_body_transform: Transform3D
var neutral_part_transforms: Dictionary = {}
var neutral_upper_transforms: Dictionary = {}
var neutral_lower_transforms: Dictionary = {}


func _ready() -> void:
	add_to_group("player")
	game = get_parent()
	_ensure_input_actions()
	_capture_neutral_visual_transforms()
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	if not _automation_requested():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if game != null and game.is_playing():
		var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := Vector3(input_vector.x, 0.0, input_vector.y).rotated(Vector3.UP, camera_yaw)
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
		if direction.length_squared() > 0.01:
			$Body.rotation.y = lerp_angle($Body.rotation.y, camera_yaw, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	_update_locomotion(delta)
	_update_interaction_target()


func _capture_neutral_visual_transforms() -> void:
	neutral_body_transform = visual_body.transform
	for part_name in LEG_NAMES + [&"Thorax", &"Abdomen", &"AntennaLeft", &"AntennaRight"]:
		var part := visual_body.get_node(NodePath(part_name)) as Node3D
		neutral_part_transforms[part_name] = part.transform
	for leg_name: StringName in LEG_NAMES:
		var leg := visual_body.get_node(NodePath(leg_name)) as Node3D
		neutral_upper_transforms[leg_name] = (leg.get_node("Upper") as Node3D).transform
		neutral_lower_transforms[leg_name] = (leg.get_node("Upper/Lower") as Node3D).transform


func _update_locomotion(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := horizontal_speed > GAIT_IDLE_SPEED
	var target_weight := 1.0 if is_moving else 0.0
	locomotion_weight = move_toward(locomotion_weight, target_weight, GAIT_BLEND_SPEED * delta)

	if is_moving:
		var speed_factor := clampf(horizontal_speed / MOVE_SPEED, 0.0, 1.0)
		var frequency := lerpf(GAIT_MIN_FREQUENCY, GAIT_MAX_FREQUENCY, speed_factor)
		gait_phase = fposmod(gait_phase + TAU * frequency * delta, TAU)

	_pose_legs()
	_pose_body_and_antennae()


func _pose_legs() -> void:
	for leg_name: StringName in LEG_NAMES:
		var leg := visual_body.get_node(NodePath(leg_name)) as Node3D
		var upper := leg.get_node("Upper") as Node3D
		var lower := leg.get_node("Upper/Lower") as Node3D
		var neutral_root: Transform3D = neutral_part_transforms[leg_name]
		var neutral_upper: Transform3D = neutral_upper_transforms[leg_name]
		var neutral_lower: Transform3D = neutral_lower_transforms[leg_name]
		var tripod_sign := 1.0 if leg_name in TRIPOD_A else -1.0
		var stride := sin(gait_phase) * tripod_sign
		var role_scale := 0.86 if "Middle" in leg_name else (1.0 if "Front" in leg_name else 0.92)
		var side_sign := -1.0 if "Left" in leg_name else 1.0
		var swing_curve := pow(maxf(0.0, stride), 1.25)
		var support_curve := maxf(0.0, -stride)
		var root_offset := Vector3(stride * 0.10 * role_scale, stride * side_sign * 0.035, 0.0) * locomotion_weight
		var upper_offset := Vector3(stride * 0.44 * role_scale, stride * side_sign * 0.055, 0.0) * locomotion_weight
		var lower_offset := Vector3(
			-stride * 0.14 * role_scale,
			0.0,
			side_sign * (swing_curve * 0.42 + support_curve * -0.045)
		) * locomotion_weight
		leg.transform = Transform3D(
			neutral_root.basis * Basis.from_euler(root_offset),
			neutral_root.origin
		)
		upper.transform = Transform3D(neutral_upper.basis * Basis.from_euler(upper_offset), neutral_upper.origin)
		lower.transform = Transform3D(neutral_lower.basis * Basis.from_euler(lower_offset), neutral_lower.origin)


func _pose_body_and_antennae() -> void:
	var double_step := sin(gait_phase * 2.0)
	var support_transfer := sin(gait_phase)
	var body_euler := neutral_body_transform.basis.get_euler()
	visual_body.position = neutral_body_transform.origin + Vector3(
		0.0,
		0.026 * (0.5 + 0.5 * double_step) * locomotion_weight,
		0.0
	)
	visual_body.rotation = Vector3(
		body_euler.x,
		visual_body.rotation.y,
		0.035 * support_transfer * locomotion_weight + body_euler.z
	)

	var thorax := visual_body.get_node("Thorax") as Node3D
	var neutral_thorax: Transform3D = neutral_part_transforms[&"Thorax"]
	var thorax_offset := Vector3(0.018 * double_step, 0.0, 0.024 * support_transfer) * locomotion_weight
	thorax.transform = Transform3D(neutral_thorax.basis * Basis.from_euler(thorax_offset), neutral_thorax.origin)

	var abdomen := visual_body.get_node("Abdomen") as Node3D
	var neutral_abdomen: Transform3D = neutral_part_transforms[&"Abdomen"]
	var abdomen_offset := Vector3(-0.008 * double_step, 0.0, -0.014 * support_transfer) * locomotion_weight
	abdomen.transform = Transform3D(neutral_abdomen.basis * Basis.from_euler(abdomen_offset), neutral_abdomen.origin)

	for antenna_name: StringName in [&"AntennaLeft", &"AntennaRight"]:
		var antenna := visual_body.get_node(NodePath(antenna_name)) as Node3D
		var neutral: Transform3D = neutral_part_transforms[antenna_name]
		var side_sign := -1.0 if antenna_name == &"AntennaLeft" else 1.0
		var response := Vector3(
			0.04 * sin(gait_phase + side_sign * 0.35),
			0.0,
			side_sign * 0.018 * double_step
		) * locomotion_weight
		antenna.transform = Transform3D(neutral.basis * Basis.from_euler(response), neutral.origin)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and nearby_toilet != null and game.is_playing():
			if nearby_toilet.collect():
				_update_interaction_target()
		elif event.physical_keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()


func _update_interaction_target() -> void:
	var next_toilet: TurdToilet
	var nearest_distance := INTERACTION_RANGE
	if game == null or game.is_playing():
		for toilet: TurdToilet in get_tree().get_nodes_in_group("toilets"):
			if not toilet.has_turd:
				continue
			var distance := global_position.distance_to(toilet.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				next_toilet = toilet
	if nearby_toilet != next_toilet:
		if is_instance_valid(nearby_toilet):
			nearby_toilet.set_targeted(false)
		nearby_toilet = next_toilet
		if nearby_toilet != null:
			nearby_toilet.set_targeted(true)
	if game != null:
		game.set_interaction_prompt(nearby_toilet != null)


func apply_mouse_look(relative_motion: Vector2) -> void:
	camera_yaw -= relative_motion.x * MOUSE_SENSITIVITY
	camera_pitch = clamp(camera_pitch - relative_motion.y * MOUSE_SENSITIVITY, -0.75, 0.45)
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)


func _automation_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--self-test") or argument.begins_with("--screenshot") or argument == "--export-self-test":
			return true
	return false


func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
