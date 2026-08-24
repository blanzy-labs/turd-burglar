extends SceneTree

const REQUIRED_PARTS := ["Abdomen", "Thorax", "Head", "Mask"]
const LEFT_LEGS := ["LegLeftFront", "LegLeftMiddle", "LegLeftRear"]
const RIGHT_LEGS := ["LegRightFront", "LegRightMiddle", "LegRightRear"]
const ANTENNAE := ["AntennaLeft", "AntennaRight"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_text := FileAccess.get_file_as_string("res://scenes/player.tscn")
	for forbidden in [".glb", ".gltf", ".fbx", ".obj", "AnimationPlayer", "AnimationTree"]:
		if forbidden.to_lower() in scene_text.to_lower():
			_fail("forbidden external asset or animation dependency: %s" % forbidden)
			return

	var packed: PackedScene = load("res://scenes/player.tscn")
	if packed == null:
		_fail("player scene does not load")
		return
	var player: BurglarPlayer = packed.instantiate()
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame

	var visual_root := player.get_node_or_null("Body") as Node3D
	if visual_root == null:
		_fail("Body visual root")
		return
	for part_name in REQUIRED_PARTS:
		if not _node_has_mesh(visual_root.get_node_or_null(part_name)):
			_fail("missing mesh-bearing part %s" % part_name)
			return
	print("TBR02_CORE_ANATOMY_OK")

	for leg_name in LEFT_LEGS:
		var leg := visual_root.get_node_or_null(leg_name) as Node3D
		if not _node_has_mesh(leg) or leg.position.x >= -0.15:
			_fail("left leg structure %s" % leg_name)
			return
	for leg_name in RIGHT_LEGS:
		var leg := visual_root.get_node_or_null(leg_name) as Node3D
		if not _node_has_mesh(leg) or leg.position.x <= 0.15:
			_fail("right leg structure %s" % leg_name)
			return
	print("TBR02_SIX_LEGS_OK")

	for antenna_name in ANTENNAE:
		if not _node_has_mesh(visual_root.get_node_or_null(antenna_name)):
			_fail("antenna structure %s" % antenna_name)
			return
	print("TBR02_TWO_ANTENNAE_OK")

	var abdomen := visual_root.get_node("Abdomen") as Node3D
	var thorax := visual_root.get_node("Thorax") as Node3D
	var head := visual_root.get_node("Head") as Node3D
	var mask := visual_root.get_node("Mask") as Node3D
	if not (head.position.z < thorax.position.z and thorax.position.z < abdomen.position.z):
		_fail("head/thorax/abdomen do not establish -Z as visual forward")
		return
	if mask.position.z >= head.position.z:
		_fail("burglar mask is not in front of head")
		return
	var antenna_left := visual_root.get_node("AntennaLeft") as Node3D
	var antenna_right := visual_root.get_node("AntennaRight") as Node3D
	if antenna_left.position.z >= thorax.position.z or antenna_right.position.z >= thorax.position.z:
		_fail("antennae do not project toward visual front")
		return
	if antenna_left.position.x >= 0.0 or antenna_right.position.x <= 0.0:
		_fail("antennae left/right placement")
		return
	print("TBR02_FORWARD_AND_MASK_OK")

	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_meshes(visual_root, mesh_nodes)
	if mesh_nodes.size() < 12:
		_fail("insufficient primitive construction")
		return
	var bounds := AABB()
	var has_bounds := false
	for mesh_node in mesh_nodes:
		if not _is_allowed_low_poly_mesh(mesh_node.mesh):
			_fail("non-low-poly or unsupported mesh at %s" % mesh_node.get_path())
			return
		var transformed := mesh_node.global_transform * mesh_node.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	if not has_bounds or bounds.size.y < 0.85 or bounds.size.y > 1.4:
		_fail("visual height outside beetle target: %.3f" % bounds.size.y)
		return
	if bounds.size.x < 0.8 or bounds.size.z < 0.8:
		_fail("beetle silhouette is too narrow or short")
		return
	print("TBR02_LOW_POLY_SCALE_OK")
	print("TBR02_VISUAL_HEIGHT=%.3f" % bounds.size.y)

	var collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not collision.shape is CapsuleShape3D:
		_fail("single capsule collision")
		return
	var capsule := collision.shape as CapsuleShape3D
	if capsule.radius < 0.25 or capsule.radius > 0.5 or capsule.height < 0.75 or capsule.height > 1.4:
		_fail("collision dimensions do not approximate a traversable beetle")
		return
	if player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") == null:
		_fail("third-person camera rig")
		return
	print("TBR02_COLLISION_CAMERA_OK")

	var screenshot_path := _argument_value(OS.get_cmdline_user_args(), "--screenshot-character=")
	if not screenshot_path.is_empty():
		await _capture_character(player, screenshot_path)
		print("TBR02_CHARACTER_SCREENSHOT_OK=%s" % screenshot_path)

	print("TBR02_PLAYER_IDENTITY_ACCEPTANCE_OK")
	quit(0)


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
	environment.background_color = Color("171020")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a7698")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	root.add_child(environment_node)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("45324f")
	plane.material = floor_material
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_energy = 1.3
	key_light.shadow_enabled = true
	root.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.5, 1.8, -1.5)
	fill_light.omni_range = 5.0
	fill_light.light_energy = 2.2
	fill_light.light_color = Color("d696ff")
	root.add_child(fill_light)

	var camera := Camera3D.new()
	camera.position = Vector3(2.3, 1.45, -3.1)
	camera.fov = 52.0
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.55, 0.0), Vector3.UP)
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
	push_error("TB-R02 player identity acceptance failed: %s" % stage)
	quit(1)
