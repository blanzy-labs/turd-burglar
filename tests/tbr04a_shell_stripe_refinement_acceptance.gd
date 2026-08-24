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
	var head := body.get_node_or_null("Head") as Node3D if body != null else null
	var mask := body.get_node_or_null("Mask") as Node3D if body != null else null
	var thorax := body.get_node_or_null("Thorax") as Node3D if body != null else null
	var abdomen := body.get_node_or_null("Abdomen") as Node3D if body != null else null
	var shirt := body.find_child("Shirt", true, false) as Node3D if body != null else null
	if body == null or not _node_has_mesh(head) or not _node_has_mesh(mask) or not _node_has_mesh(thorax) or not _node_has_mesh(abdomen) or not _node_has_mesh(shirt):
		_fail("body, face, shell segments, or striped element missing")
		return
	print("TBR04A_CHARACTER_STRUCTURE_OK")

	var stripes: Array[MeshInstance3D] = []
	_collect_named_meshes(shirt, "stripe", stripes)
	if stripes.size() < 3:
		_fail("at least three broad shell stripes required")
		return
	var min_y := INF
	var max_y := -INF
	var min_z := INF
	var max_z := -INF
	for stripe in stripes:
		var body_position := body.to_local(stripe.global_position)
		min_y = minf(min_y, body_position.y)
		max_y = maxf(max_y, body_position.y)
		min_z = minf(min_z, body_position.z)
		max_z = maxf(max_z, body_position.z)
	var y_span := max_y - min_y
	var z_span := max_z - min_z
	print("TBR04A_STRIPE_CENTER_Y_SPAN=%.4f" % y_span)
	print("TBR04A_STRIPE_CENTER_Z_SPAN=%.4f" % z_span)
	if z_span < 0.26:
		_fail("stripes do not travel along the beetle body: Z span %.4f" % z_span)
		return
	if y_span > 0.14 or z_span < y_span * 1.8:
		_fail("stripes remain stacked like a vertical shirt: Y %.4f Z %.4f" % [y_span, z_span])
		return
	print("TBR04A_HORIZONTAL_BODY_BANDING_OK")

	if min_z < head.position.z + 0.02:
		_fail("shell band projects ahead of the head")
		return
	if max_z >= abdomen.position.z - 0.08:
		_fail("shell band extends too far into the dark rear abdomen")
		return
	var midpoint_z := (min_z + max_z) * 0.5
	if absf(midpoint_z - thorax.position.z) > 0.32:
		_fail("shell band is not centered on the front body segment")
		return
	print("TBR04A_FRONT_SHELL_PLACEMENT_OK")

	var stripe_lightest := 0.0
	var stripe_darkest := 1.0
	for stripe in stripes:
		var luminance := _node_luminance(stripe)
		stripe_lightest = maxf(stripe_lightest, luminance)
		stripe_darkest = minf(stripe_darkest, luminance)
	if stripe_lightest - stripe_darkest < 0.32:
		_fail("shell-band contrast is too weak")
		return
	var abdomen_luminance := _node_luminance(abdomen)
	if abdomen_luminance >= stripe_lightest - 0.25:
		_fail("rear abdomen no longer provides dark contrast")
		return
	print("TBR04A_DARK_REAR_SEGMENT_OK")

	for eye_name in ["EyeLeft", "EyeRight"]:
		var eye := body.find_child(eye_name, true, false)
		if not _node_has_mesh(eye) or (not _is_descendant_of(eye, head) and not _is_descendant_of(eye, mask)):
			_fail("integrated face regression: %s" % eye_name)
			return
	for leg_name in LEGS:
		if not _node_has_mesh(body.get_node_or_null(leg_name)):
			_fail("leg silhouette regression: %s" % leg_name)
			return
	for antenna_name in ANTENNAE:
		if not _node_has_mesh(body.get_node_or_null(antenna_name)):
			_fail("antenna regression: %s" % antenna_name)
			return
	print("TBR04A_IDENTITY_PRESERVED_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-shell-band=")
	if not screenshot_path.is_empty():
		await _capture_side_three_quarter(player, screenshot_path)
		print("TBR04A_SHELL_BAND_SCREENSHOT_OK=%s" % screenshot_path)

	print("TBR04A_SHELL_STRIPE_REFINEMENT_ACCEPTANCE_OK")
	quit(0)


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


func _first_material(node: Node) -> StandardMaterial3D:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var material := mesh_node.material_override
		if material == null and mesh_node.mesh != null:
			material = mesh_node.mesh.material
		if material is StandardMaterial3D:
			return material as StandardMaterial3D
	for child in node.get_children():
		var found := _first_material(child)
		if found != null:
			return found
	return null


func _node_luminance(node: Node) -> float:
	var material := _first_material(node)
	if material == null:
		return 0.0
	var color := material.albedo_color
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _capture_side_three_quarter(player: BurglarPlayer, screenshot_path: String) -> void:
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
	camera.position = Vector3(3.0, 1.15, -1.25)
	camera.fov = 48.0
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.55, -0.12), Vector3.UP)
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(screenshot_path)
	if error != OK:
		_fail("shell-band screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R04A shell stripe refinement acceptance failed: %s" % stage)
	quit(1)
