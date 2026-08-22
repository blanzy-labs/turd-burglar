class_name RestroomRuntime
extends Node3D

enum HeistState { PLAYING, EXIT_AVAILABLE, HEIST_COMPLETE }

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const TOILET_SCENE := preload("res://scenes/toilet.tscn")
const EXIT_SCENE := preload("res://scenes/exit.tscn")

@export_file("*.json") var level_path_override := ""

var state := HeistState.PLAYING
var collected_turds := 0
var required_turds := 0
var collectible_turd_count := 0
var level_id := ""
var level_name := ""
var level_definition: Dictionary = {}
var load_error := ""
var toilets: Array[TurdToilet] = []
var player: BurglarPlayer
var heist_exit: HeistExit

var counter_label: Label
var prompt_label: Label
var status_label: Label
var completion_panel: ColorRect
var completion_text: Label


func _ready() -> void:
	var load_result: Dictionary
	if level_path_override.is_empty():
		load_result = TurdLevelLoader.load_selected(OS.get_cmdline_user_args())
	else:
		load_result = TurdLevelLoader.load_file(level_path_override)
	if not load_result.ok:
		load_error = load_result.error
		push_error("TB_LEVEL_LOAD_FAILED %s" % load_error)
		get_tree().quit(1)
		return

	level_definition = load_result.level
	level_id = level_definition.id
	level_name = level_definition.name
	required_turds = level_definition.objective.turds_required
	collectible_turd_count = level_definition.collectible_turd_count
	_build_environment()
	_spawn_gameplay()
	_build_hud()
	_update_hud()
	print("TB_LEVEL_LOADED=%s" % level_id)
	print("TB_LEVEL_NAME=%s" % level_name)
	print("TB_TOILETS=%d" % toilets.size())
	print("TB_COLLECTIBLE_TURDS=%d" % collectible_turd_count)
	print("TB_REQUIRED_TURDS=%d" % required_turds)


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
	print("TB_HEIST_COMPLETE")
	if level_id == "restroom_001":
		print("TB001_HEIST_COMPLETE")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R and state == HeistState.HEIST_COMPLETE:
			request_restart()


func request_restart() -> void:
	get_tree().reload_current_scene()


func _on_toilet_collected(_toilet: TurdToilet) -> void:
	collected_turds += 1
	if collected_turds == required_turds:
		state = HeistState.EXIT_AVAILABLE
		heist_exit.set_locked(false)
		print("TB_EXIT_UNLOCKED")
		if level_id == "restroom_001":
			print("TB001_EXIT_UNLOCKED")
	_update_hud()


func _update_hud() -> void:
	counter_label.text = "TURDS: %d / %d" % [collected_turds, required_turds]
	status_label.visible = state == HeistState.EXIT_AVAILABLE
	completion_text.text = "HEIST COMPLETE\n\nTURDS STOLEN: %d / %d\n\nR — RESTART" % [collected_turds, required_turds]


func _spawn_gameplay() -> void:
	for toilet_data: Dictionary in level_definition.toilets:
		var toilet: TurdToilet = TOILET_SCENE.instantiate()
		toilet.name = toilet_data.id
		toilet.position = toilet_data.position
		toilet.rotation_degrees = toilet_data.rotation_degrees
		toilet.has_turd = toilet_data.has_turd
		toilet.collected.connect(_on_toilet_collected)
		add_child(toilet)
		toilets.append(toilet)

	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = level_definition.player_spawn
	add_child(player)

	heist_exit = EXIT_SCENE.instantiate()
	heist_exit.name = "Exit"
	heist_exit.position = level_definition.exit.position
	add_child(heist_exit)


func _build_environment() -> void:
	for primitive: Dictionary in level_definition.geometry:
		_add_box(
			primitive.name,
			primitive.size,
			primitive.position,
			primitive.color,
			primitive.collision
		)
	for label_data: Dictionary in level_definition.labels:
		var sign_label := Label3D.new()
		sign_label.name = label_data.name
		sign_label.text = label_data.text
		sign_label.font_size = 52
		sign_label.outline_size = 10
		sign_label.modulate = label_data.color
		sign_label.position = label_data.position
		sign_label.rotation_degrees = label_data.rotation_degrees
		add_child(sign_label)
	for light_data: Dictionary in level_definition.lights:
		if light_data.type == "directional":
			var directional := DirectionalLight3D.new()
			directional.name = light_data.name
			directional.rotation_degrees = light_data.rotation_degrees
			directional.light_energy = light_data.energy
			directional.light_color = light_data.color
			directional.shadow_enabled = light_data.shadow
			add_child(directional)
		else:
			var omni := OmniLight3D.new()
			omni.name = light_data.name
			omni.position = light_data.position
			omni.omni_range = light_data.range
			omni.light_energy = light_data.energy
			omni.light_color = light_data.color
			add_child(omni)

	var world := WorldEnvironment.new()
	world.name = "LevelEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = level_definition.environment.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = level_definition.environment.ambient_color
	environment.ambient_light_energy = level_definition.environment.ambient_energy
	world.environment = environment
	add_child(world)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var top_panel := ColorRect.new()
	top_panel.color = Color(0.05, 0.04, 0.08, 0.84)
	top_panel.position = Vector2(18.0, 16.0)
	top_panel.size = Vector2(290.0, 62.0)
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

	completion_text = Label.new()
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
