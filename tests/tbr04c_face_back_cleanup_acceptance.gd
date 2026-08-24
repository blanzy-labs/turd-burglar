extends SceneTree

const LEGS := [
	"LegLeftFront", "LegLeftMiddle", "LegLeftRear",
	"LegRightFront", "LegRightMiddle", "LegRightRear",
]
const ANTENNAE := ["AntennaLeft", "AntennaRight"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/player.tscn")
	if packed == null:
		_fail("player scene does not load")
		return
	var player: BurglarPlayer = packed.instantiate()
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame
	var body := player.get_node_or_null("Body") as Node3D
	if body == null:
		_fail("Body visual root missing")
		return
	if body.get_node_or_null("ShellSeam") != null:
		_fail("unwanted ShellSeam back bar still exists")
		return
	for child in body.get_children():
		var lower_name := child.name.to_lower()
		if "backbar" in lower_name or "handle" in lower_name:
			_fail("unwanted back-bar replacement exists: %s" % child.name)
			return
	print("TBR04C_BACK_BAR_REMOVED_OK")

	var head := body.get_node_or_null("Head") as Node3D
	var mask := body.get_node_or_null("Mask") as MeshInstance3D
	if not _node_has_mesh(head) or mask == null or not mask.mesh is BoxMesh:
		_fail("mesh-bearing head and box mask required")
		return
	var mask_box := mask.mesh as BoxMesh
	var mask_front_z := -mask_box.size.z * 0.5
	var eye_nodes: Array[MeshInstance3D] = []
	for eye_name in ["EyeLeft", "EyeRight"]:
		var eye := body.find_child(eye_name, true, false) as MeshInstance3D
		if eye == null or not eye.mesh is BoxMesh or not _is_descendant_of(eye, mask):
			_fail("%s is not a mask-integrated box slit" % eye_name)
			return
		var eye_box := eye.mesh as BoxMesh
		if eye_box.size.x < 0.06 or eye_box.size.x > 0.13 or eye_box.size.y > 0.045 or eye_box.size.z > 0.014:
			_fail("%s dimensions do not read as a restrained slit: %s" % [eye_name, eye_box.size])
			return
		var eye_front_z := eye.position.z - eye_box.size.z * 0.5
		var eye_back_z := eye.position.z + eye_box.size.z * 0.5
		if eye_front_z < mask_front_z - 0.008 or eye_front_z > mask_front_z + 0.004 or eye_back_z <= mask_front_z:
			_fail("%s does not intersect the mask surface as an inset slit" % eye_name)
			return
		var eye_material := _mesh_material(eye)
		if not eye_material is StandardMaterial3D or not (eye_material as StandardMaterial3D).emission_enabled:
			_fail("%s lost glowing readability" % eye_name)
			return
		eye_nodes.append(eye)
	if eye_nodes[0].global_position.x >= eye_nodes[1].global_position.x or eye_nodes[0].global_position.distance_to(eye_nodes[1].global_position) < 0.12:
		_fail("left/right eye separation regression")
		return
	print("TBR04C_INSET_EYE_SLITS_OK")
	print("TBR04C_FACE_COHESION_STRUCTURE_OK")

	if body.get_node_or_null("Shirt") != null:
		_fail("separate Shirt regression")
		return
	var thorax := body.get_node_or_null("Thorax") as MeshInstance3D
	var abdomen := body.get_node_or_null("Abdomen") as MeshInstance3D
	if thorax == null or not _is_striped_shell_material(_mesh_material(thorax)):
		_fail("TB-R04B striped thorax shader regression")
		return
	var abdomen_material := _mesh_material(abdomen) if abdomen != null else null
	if not abdomen_material is StandardMaterial3D or _color_luminance((abdomen_material as StandardMaterial3D).albedo_color) > 0.24:
		_fail("dark rear abdomen regression")
		return
	print("TBR04C_STRIPED_SHELL_DARK_REAR_OK")

	for leg_name in LEGS:
		var leg := body.get_node_or_null(leg_name) as Node3D
		if not _node_has_mesh(leg) or not _node_has_mesh(leg.get_node_or_null("Upper")) or not _node_has_mesh(leg.get_node_or_null("Upper/Lower")):
			_fail("articulated leg regression: %s" % leg_name)
			return
	for antenna_name in ANTENNAE:
		if not _node_has_mesh(body.get_node_or_null(antenna_name)):
			_fail("antenna regression: %s" % antenna_name)
			return
	print("TBR04C_CHARACTER_HIERARCHY_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-cleanup=")
	var view := _argument_value(OS.get_cmdline_user_args(), "--view=")
	if not screenshot_path.is_empty():
		await _capture_character(player, view, screenshot_path)
		print("TBR04C_%s_SCREENSHOT_OK=%s" % [view.to_upper().replace("-", "_"), screenshot_path])

	print("TBR04C_FACE_BACK_CLEANUP_ACCEPTANCE_OK")
	quit(0)


func _is_striped_shell_material(material: Material) -> bool:
	if not material is ShaderMaterial:
		return false
	var shader_material := material as ShaderMaterial
	if shader_material.shader == null:
		return false
	var code := shader_material.shader.code.to_lower()
	if "vertex.z" not in code or "albedo" not in code:
		return false
	var light = shader_material.get_shader_parameter("stripe_light")
	var dark = shader_material.get_shader_parameter("stripe_dark")
	var count = shader_material.get_shader_parameter("stripe_count")
	return typeof(light) == TYPE_COLOR and typeof(dark) == TYPE_COLOR and typeof(count) in [TYPE_FLOAT, TYPE_INT] and float(count) >= 3.0 and float(count) <= 5.0 and _color_luminance(light) - _color_luminance(dark) >= 0.32


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent() if node != null else null
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _node_has_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child in node.get_children():
		if _node_has_mesh(child):
			return true
	return false


func _mesh_material(mesh_node: MeshInstance3D) -> Material:
	if mesh_node == null:
		return null
	if mesh_node.material_override != null:
		return mesh_node.material_override
	if mesh_node.mesh != null:
		return mesh_node.mesh.material
	return null


func _color_luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _capture_character(player: BurglarPlayer, view: String, screenshot_path: String) -> void:
	(player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).current = false
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("24112d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b89bc7")
	environment.ambient_light_energy = 0.9
	environment_node.environment = environment
	root.add_child(environment_node)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("563260")
	plane.material = floor_material
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	key_light.light_energy = 1.5
	key_light.shadow_enabled = true
	root.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.2, 1.8, -1.5)
	fill_light.omni_range = 5.0
	fill_light.light_energy = 2.4
	fill_light.light_color = Color("f1c5ff")
	root.add_child(fill_light)
	var camera := Camera3D.new()
	if view == "front-three-quarter":
		camera.position = Vector3(1.55, 1.1, -2.75)
	elif view == "rear-side":
		camera.position = Vector3(2.8, 1.35, 2.35)
	else:
		_fail("unknown cleanup screenshot view: %s" % view)
		return
	camera.fov = 46.0
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.54, -0.12), Vector3.UP)
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(screenshot_path)
	if error != OK:
		_fail("cleanup screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R04C face/back cleanup acceptance failed: %s" % stage)
	quit(1)
