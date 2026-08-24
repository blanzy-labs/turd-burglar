class_name BurglarPlayer
extends CharacterBody3D

const MOVE_SPEED := 5.0
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.003
const INTERACTION_RANGE := 2.65

@onready var camera_pivot: Node3D = $CameraPivot

var camera_yaw := 0.0
var camera_pitch := -0.18
var game: Node
var nearby_toilet: Node


func _ready() -> void:
	add_to_group("player")
	game = get_parent()
	_ensure_input_actions()
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
	_update_interaction_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_mouse_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and nearby_toilet != null and game.is_playing():
			nearby_toilet.collect()
		elif event.physical_keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				get_tree().quit()


func _update_interaction_target() -> void:
	nearby_toilet = null
	var nearest_distance := INTERACTION_RANGE
	for toilet in get_tree().get_nodes_in_group("toilets"):
		if toilet.has_turd:
			var distance := global_position.distance_to(toilet.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearby_toilet = toilet
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
