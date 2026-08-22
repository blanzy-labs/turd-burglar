class_name FirstFlushRestroom
extends Node3D

enum HeistState { PLAYING, EXIT_AVAILABLE, HEIST_COMPLETE }

const REQUIRED_TURDS := 3
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TOILET_SCENE := preload("res://scenes/toilet.tscn")
const EXIT_SCENE := preload("res://scenes/exit.tscn")

var state := HeistState.PLAYING
var collected_turds := 0
var toilets: Array[TurdToilet] = []
var player: BurglarPlayer
var heist_exit: HeistExit

var counter_label: Label
var prompt_label: Label
var status_label: Label
var completion_panel: ColorRect


func _ready() -> void:
	_build_environment()
	_spawn_gameplay()
	_build_hud()
	_update_hud()


func is_playing() -> bool:
	return state != HeistState.HEIST_COMPLETE


func set_interaction_prompt(visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = visible and state != HeistState.HEIST_COMPLETE


func complete_heist() -> void:
	if state != HeistState.EXIT_AVAILABLE:
		return
	state = HeistState.HEIST_COMPLETE
	completion_panel.visible = true
	prompt_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("TB001_HEIST_COMPLETE")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and state == HeistState.HEIST_COMPLETE:
			request_restart()


func request_restart() -> void:
	get_tree().reload_current_scene()


func _on_toilet_collected(_toilet: TurdToilet) -> void:
	collected_turds += 1
	if collected_turds == REQUIRED_TURDS:
		state = HeistState.EXIT_AVAILABLE
		heist_exit.set_locked(false)
		print("TB001_EXIT_UNLOCKED")
	_update_hud()


func _update_hud() -> void:
	counter_label.text = "TURDS: %d / %d" % [collected_turds, REQUIRED_TURDS]
	status_label.visible = state == HeistState.EXIT_AVAILABLE


func _spawn_gameplay() -> void:
	var toilet_positions := [Vector3(-5.0, 0.0, -5.25), Vector3(0.0, 0.0, -5.25), Vector3(5.0, 0.0, -5.25)]
	for index in REQUIRED_TURDS:
		var toilet: TurdToilet = TOILET_SCENE.instantiate()
		toilet.name = "Toilet%d" % (index + 1)
		toilet.position = toilet_positions[index]
		toilet.collected.connect(_on_toilet_collected)
		add_child(toilet)
		toilets.append(toilet)

	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = Vector3(-1.6, 0.05, 3.3)
	add_child(player)

	heist_exit = EXIT_SCENE.instantiate()
	heist_exit.name = "Exit"
	heist_exit.position = Vector3(7.2, 0.0, 5.85)
	add_child(heist_exit)


func _build_environment() -> void:
	_add_box("Floor", Vector3(18.0, 0.4, 14.0), Vector3(0.0, -0.2, 0.0), Color("43b6a2"), true)
	_add_box("BackWall", Vector3(18.0, 3.5, 0.4), Vector3(0.0, 1.75, -7.0), Color("f3df76"), true)
	_add_box("FrontWall", Vector3(18.0, 3.5, 0.4), Vector3(0.0, 1.75, 7.0), Color("f3df76"), true)
	_add_box("LeftWall", Vector3(0.4, 3.5, 14.0), Vector3(-9.0, 1.75, 0.0), Color("ed6f86"), true)
	_add_box("RightWall", Vector3(0.4, 3.5, 14.0), Vector3(9.0, 1.75, 0.0), Color("ed6f86"), true)

	var partition_x := [-7.45, -2.5, 2.5, 7.45]
	for index in partition_x.size():
		_add_box("StallWall%d" % (index + 1), Vector3(0.18, 2.45, 4.0), Vector3(partition_x[index], 1.23, -4.9), Color("85c9e8"), true)
	var stall_centers := [-5.0, 0.0, 5.0]
	for index in stall_centers.size():
		var sign_label := Label3D.new()
		sign_label.name = "StallSign%d" % (index + 1)
		sign_label.text = "STALL %d" % (index + 1)
		sign_label.font_size = 52
		sign_label.outline_size = 10
		sign_label.modulate = Color("482b54")
		sign_label.position = Vector3(stall_centers[index], 2.45, -2.82)
		add_child(sign_label)

	var directional := DirectionalLight3D.new()
	directional.name = "SunLamp"
	directional.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	directional.light_energy = 1.15
	directional.shadow_enabled = true
	add_child(directional)
	for light_x in [-5.0, 0.0, 5.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(light_x, 2.8, -3.0)
		light.omni_range = 8.0
		light.light_energy = 3.0
		light.light_color = Color("fff0a6")
		add_child(light)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("203b4c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4d9df")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var top_panel := ColorRect.new()
	top_panel.color = Color(0.05, 0.04, 0.08, 0.84)
	top_panel.position = Vector2(18.0, 16.0)
	top_panel.size = Vector2(270.0, 62.0)
	canvas.add_child(top_panel)

	counter_label = Label.new()
	counter_label.position = Vector2(18.0, 10.0)
	counter_label.add_theme_font_size_override("font_size", 30)
	counter_label.add_theme_color_override("font_color", Color("fff07a"))
	top_panel.add_child(counter_label)

	prompt_label = Label.new()
	prompt_label.text = "E — GRAB TURD"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-180.0, -95.0)
	prompt_label.size = Vector2(360.0, 52.0)
	prompt_label.add_theme_font_size_override("font_size", 28)
	prompt_label.add_theme_color_override("font_color", Color("ffffff"))
	prompt_label.add_theme_color_override("font_shadow_color", Color("000000"))
	prompt_label.add_theme_constant_override("shadow_offset_x", 3)
	prompt_label.add_theme_constant_override("shadow_offset_y", 3)
	prompt_label.visible = false
	canvas.add_child(prompt_label)

	status_label = Label.new()
	status_label.text = "EXIT UNLOCKED"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-190.0, 24.0)
	status_label.size = Vector2(380.0, 58.0)
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color("57ff74"))
	canvas.add_child(status_label)

	completion_panel = ColorRect.new()
	completion_panel.color = Color(0.08, 0.02, 0.12, 0.93)
	completion_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_panel.visible = false
	canvas.add_child(completion_panel)

	var completion_text := Label.new()
	completion_text.text = "HEIST COMPLETE\n\nTURDS STOLEN: 3 / 3\n\nR — RESTART"
	completion_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	completion_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_text.add_theme_font_size_override("font_size", 40)
	completion_text.add_theme_color_override("font_color", Color("fff07a"))
	completion_panel.add_child(completion_text)


func _add_box(node_name: String, size: Vector3, box_position: Vector3, color: Color, with_collision: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_position
	add_child(mesh_instance)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position = box_position
		body.add_child(collision)
		add_child(body)
