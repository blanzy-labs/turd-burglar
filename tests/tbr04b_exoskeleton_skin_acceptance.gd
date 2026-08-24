extends SceneTree

const LEGS := [
	"LegLeftFront", "LegLeftMiddle", "LegLeftRear",
	"LegRightFront", "LegRightMiddle", "LegRightRear",
]
const ANTENNAE := ["AntennaLeft", "AntennaRight"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/player.tscn")
	for forbidden in [".glb", ".gltf", ".fbx", ".obj", "Skeleton3D", "AnimationPlayer", "AnimationTree"]:
		if forbidden.to_lower() in scene_text.to_lower():
			_fail("forbidden external asset or rig dependency: %s" % forbidden)
			return
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
	if body.get_node_or_null("Shirt") != null:
		_fail("separate Body/Shirt construction still exists")
		return
	print("TBR04B_SEPARATE_SHIRT_REMOVED_OK")

	var head := body.get_node_or_null("Head") as Node3D
	var mask := body.get_node_or_null("Mask") as Node3D
	var thorax := body.get_node_or_null("Thorax") as Node3D
	var abdomen := body.get_node_or_null("Abdomen") as Node3D
	if not _node_has_mesh(head) or not _node_has_mesh(mask) or not _node_has_mesh(thorax) or not _node_has_mesh(abdomen):
		_fail("mesh-bearing head, face, thorax, and abdomen required")
		return
	var approach := _validate_shader_shell(thorax)
	if approach.is_empty():
		approach = _validate_segmented_shell(body, thorax, head, abdomen)
	if approach.is_empty():
		_fail("front shell has neither a Z-driven striped shader nor joined shell segments")
		return
	print("TBR04B_STRIPED_EXOSKELETON_APPROACH=%s" % approach)
	print("TBR04B_FRONT_TO_BACK_SHELL_STRIPES_OK")

	var abdomen_material := _first_material(abdomen)
	if abdomen_material == null or abdomen_material is ShaderMaterial:
		_fail("rear abdomen must retain a separate non-striped material")
		return
	if _material_luminance(abdomen_material) > 0.24:
		_fail("rear abdomen is no longer a dark shell segment")
		return
	print("TBR04B_DARK_REAR_ABDOMEN_OK")

	for eye_name in ["EyeLeft", "EyeRight"]:
		var eye := body.find_child(eye_name, true, false)
		if not _node_has_mesh(eye) or (not _is_descendant_of(eye, head) and not _is_descendant_of(eye, mask)):
			_fail("integrated face regression: %s" % eye_name)
			return
	for leg_name in LEGS:
		var leg := body.get_node_or_null(leg_name) as Node3D
		if not _node_has_mesh(leg) or not _node_has_mesh(leg.get_node_or_null("Upper")) or not _node_has_mesh(leg.get_node_or_null("Upper/Lower")):
			_fail("articulated leg regression: %s" % leg_name)
			return
	for antenna_name in ANTENNAE:
		if not _node_has_mesh(body.get_node_or_null(antenna_name)):
			_fail("antenna regression: %s" % antenna_name)
			return
	print("TBR04B_FACE_LOCOMOTION_HIERARCHY_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-exoskeleton=")
	var view := _argument_value(OS.get_cmdline_user_args(), "--view=")
	if not screenshot_path.is_empty():
		await _capture_character(player, view, screenshot_path)
		print("TBR04B_%s_SCREENSHOT_OK=%s" % [view.to_upper(), screenshot_path])

	print("TBR04B_EXOSKELETON_SKIN_ACCEPTANCE_OK")
	quit(0)


func _validate_shader_shell(thorax: Node3D) -> String:
	if not thorax is MeshInstance3D:
		return ""
	var material := _mesh_material(thorax as MeshInstance3D)
	if not material is ShaderMaterial:
		return ""
	var shader_material := material as ShaderMaterial
	if shader_material.shader == null:
		return ""
	var code := shader_material.shader.code
	if "vertex.z" not in code.to_lower() or "albedo" not in code.to_lower():
		return ""
	var light = shader_material.get_shader_parameter("stripe_light")
	var dark = shader_material.get_shader_parameter("stripe_dark")
	var count = shader_material.get_shader_parameter("stripe_count")
	if typeof(light) != TYPE_COLOR or typeof(dark) != TYPE_COLOR or typeof(count) not in [TYPE_FLOAT, TYPE_INT]:
		return ""
	if _color_luminance(light) - _color_luminance(dark) < 0.32:
		return ""
	if float(count) < 3.0 or float(count) > 5.0:
		return ""
	return "shader_material"


func _validate_segmented_shell(body: Node3D, thorax: Node3D, head: Node3D, abdomen: Node3D) -> String:
	if thorax is MeshInstance3D and (thorax as MeshInstance3D).mesh != null:
		return ""
	var segments: Array[MeshInstance3D] = []
	_collect_named_meshes(thorax, "shellstripe", segments)
	if segments.size() < 3 or segments.size() > 5:
		return ""
	var min_y := INF
	var max_y := -INF
	var min_z := INF
	var max_z := -INF
	var darkest := 1.0
	var lightest := 0.0
	for segment in segments:
		if segment.mesh is CylinderMesh:
			return ""
		var body_position := body.to_local(segment.global_position)
		min_y = minf(min_y, body_position.y)
		max_y = maxf(max_y, body_position.y)
		min_z = minf(min_z, body_position.z)
		max_z = maxf(max_z, body_position.z)
		var material := _mesh_material(segment)
		if material == null:
			return ""
		var luminance := _material_luminance(material)
		darkest = minf(darkest, luminance)
		lightest = maxf(lightest, luminance)
	var y_span := max_y - min_y
	var z_span := max_z - min_z
	if z_span < 0.26 or y_span > 0.14 or z_span < y_span * 1.8:
		return ""
	if min_z < head.position.z + 0.02 or max_z >= abdomen.position.z - 0.08:
		return ""
	if lightest - darkest < 0.32:
		return ""
	return "joined_shell_segments"


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	if node == null or ancestor == null:
		return false
	var current := node.get_parent()
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


func _collect_named_meshes(node: Node, token: String, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and token in node.name.to_lower():
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_named_meshes(child, token, output)


func _mesh_material(mesh_node: MeshInstance3D) -> Material:
	if mesh_node.material_override != null:
		return mesh_node.material_override
	if mesh_node.mesh != null:
		return mesh_node.mesh.material
	return null


func _first_material(node: Node) -> Material:
	if node is MeshInstance3D:
		var found := _mesh_material(node as MeshInstance3D)
		if found != null:
			return found
	for child in node.get_children():
		var found := _first_material(child)
		if found != null:
			return found
	return null


func _material_luminance(material: Material) -> float:
	if material is StandardMaterial3D:
		return _color_luminance((material as StandardMaterial3D).albedo_color)
	return 0.0


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
	if view == "top":
		camera.position = Vector3(2.25, 2.75, -2.15)
	elif view == "side":
		camera.position = Vector3(3.0, 1.15, -1.15)
	else:
		_fail("unknown exoskeleton screenshot view: %s" % view)
		return
	camera.fov = 48.0
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, -0.1), Vector3.UP)
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(screenshot_path)
	if error != OK:
		_fail("exoskeleton screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R04B exoskeleton skin acceptance failed: %s" % stage)
	quit(1)
