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
	var head := body.get_node_or_null("Head") as Node3D
	var mask := body.get_node_or_null("Mask") as Node3D
	if not _node_has_mesh(head) or not _node_has_mesh(mask):
		_fail("mesh-bearing Head and Mask required")
		return
	print("TBR04_FACE_FOUNDATION_OK")

	var eyes: Array[Node] = []
	for eye_name in ["EyeLeft", "EyeRight"]:
		var eye := body.find_child(eye_name, true, false)
		if not _node_has_mesh(eye):
			_fail("missing mesh-bearing %s" % eye_name)
			return
		if not _is_descendant_of(eye, head) and not _is_descendant_of(eye, mask):
			_fail("%s is not integrated beneath Head or Mask" % eye_name)
			return
		eyes.append(eye)
	var eye_left := eyes[0] as Node3D
	var eye_right := eyes[1] as Node3D
	if eye_left.global_position.x >= eye_right.global_position.x:
		_fail("left/right eye placement")
		return
	if eye_left.global_position.distance_to(eye_right.global_position) < 0.12:
		_fail("eyes too close to read at gameplay distance")
		return
	if not _node_has_readable_material(eye_left) or not _node_has_readable_material(eye_right):
		_fail("eyes lack a readable bright or emissive material")
		return
	print("TBR04_INTEGRATED_EYES_OK")

	var shirt := body.find_child("Shirt", true, false)
	if not _node_has_mesh(shirt):
		_fail("mesh-bearing Shirt costume missing")
		return
	var stripes: Array[Node] = []
	_collect_named_meshes(shirt, "stripe", stripes)
	if stripes.size() < 3:
		_fail("Shirt requires at least three visible stripe meshes")
		return
	var darkest := 1.0
	var lightest := 0.0
	for stripe in stripes:
		var luminance := _node_luminance(stripe)
		darkest = minf(darkest, luminance)
		lightest = maxf(lightest, luminance)
	if lightest - darkest < 0.32:
		_fail("shirt stripes lack gameplay-distance contrast: %.3f" % (lightest - darkest))
		return
	var thorax := body.get_node("Thorax") as Node3D
	if shirt.global_position.distance_to(thorax.global_position) > 0.65:
		_fail("Shirt is not focused around the thorax")
		return
	print("TBR04_STRIPED_SHIRT_OK")

	for leg_name in LEGS:
		if not _node_has_mesh(body.get_node_or_null(leg_name)):
			_fail("six-leg silhouette regression: %s" % leg_name)
			return
	for antenna_name in ANTENNAE:
		if not _node_has_mesh(body.get_node_or_null(antenna_name)):
			_fail("antenna regression: %s" % antenna_name)
			return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(body, meshes)
	for mesh_node in meshes:
		if not _is_allowed_low_poly_mesh(mesh_node.mesh):
			_fail("unsupported non-primitive mesh at %s" % mesh_node.get_path())
			return
	print("TBR04_BEETLE_LOW_POLY_SILHOUETTE_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-character=")
	if not screenshot_path.is_empty():
		await _capture_character(player, screenshot_path)
		print("TBR04_CHARACTER_SCREENSHOT_OK=%s" % screenshot_path)

	print("TBR04_BEETLE_AESTHETIC_ACCEPTANCE_OK")
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


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)


func _collect_named_meshes(node: Node, token: String, output: Array[Node]) -> void:
	if node is MeshInstance3D and token in node.name.to_lower():
		output.append(node)
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


func _node_has_readable_material(node: Node) -> bool:
	var material := _first_material(node)
	if material == null:
		return false
	return material.emission_enabled or _node_luminance(node) >= 0.34


func _is_allowed_low_poly_mesh(mesh: Mesh) -> bool:
	if mesh is BoxMesh:
		return true
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		return sphere.radial_segments <= 16 and sphere.rings <= 8
	if mesh is CapsuleMesh:
		var capsule := mesh as CapsuleMesh
		return capsule.radial_segments <= 16 and capsule.rings <= 8
	if mesh is CylinderMesh:
		return (mesh as CylinderMesh).radial_segments <= 12
	return false


func _capture_character(player: BurglarPlayer, screenshot_path: String) -> void:
	var gameplay_camera := player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	gameplay_camera.current = false
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
	fill_light.position = Vector3(-1.4, 1.8, -1.7)
	fill_light.omni_range = 5.0
	fill_light.light_energy = 2.4
	fill_light.light_color = Color("f1c5ff")
	root.add_child(fill_light)
	var camera := Camera3D.new()
	camera.position = Vector3(1.8, 1.15, -2.55)
	camera.fov = 48.0
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.56, -0.12), Vector3.UP)
	camera.current = true
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(screenshot_path)
	if error != OK:
		_fail("character screenshot save: %s" % error_string(error))


func _argument_value(arguments: PackedStringArray, prefix: String) -> String:
	for argument in arguments:
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _fail(stage: String) -> void:
	push_error("TB-R04 beetle aesthetic acceptance failed: %s" % stage)
	quit(1)
