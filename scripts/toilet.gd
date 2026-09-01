class_name TurdToilet
extends Node3D

signal collected(toilet: TurdToilet)

var has_turd := true
var turd_type := "normal"
var effect_duration := 0.0
var effect_value := 1.0
var turd_visual: Node3D
var targeted := false
var pickup_feedback_active := false
var pickup_duration := 0.24

var _target_tween: Tween
var _pickup_tween: Tween
var _neutral_turd_position := Vector3.ZERO
var _neutral_turd_scale := Vector3.ONE


func _ready() -> void:
	add_to_group("toilets")
	_build_toilet()
	_neutral_turd_position = turd_visual.position
	_neutral_turd_scale = turd_visual.scale
	turd_visual.visible = has_turd


func _exit_tree() -> void:
	_kill_tween(_target_tween)
	_kill_tween(_pickup_tween)


func set_targeted(value: bool) -> void:
	var next_targeted := value and has_turd and not pickup_feedback_active
	if targeted == next_targeted:
		return
	targeted = next_targeted
	_kill_tween(_target_tween)
	if pickup_feedback_active or turd_visual == null:
		return
	_target_tween = create_tween()
	_target_tween.set_parallel(true)
	if targeted:
		_target_tween.set_loops()
		_target_tween.tween_property(turd_visual, "position", _neutral_turd_position + Vector3(0.0, 0.10, 0.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_target_tween.tween_property(turd_visual, "scale", _neutral_turd_scale * 1.12, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_target_tween.chain().tween_property(turd_visual, "position", _neutral_turd_position + Vector3(0.0, 0.15, 0.0), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.parallel().tween_property(turd_visual, "scale", _neutral_turd_scale * 1.18, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.chain().tween_property(turd_visual, "position", _neutral_turd_position + Vector3(0.0, 0.10, 0.0), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_target_tween.parallel().tween_property(turd_visual, "scale", _neutral_turd_scale * 1.12, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_target_tween.tween_property(turd_visual, "position", _neutral_turd_position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_target_tween.tween_property(turd_visual, "scale", _neutral_turd_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func collect() -> bool:
	if not has_turd:
		return false
	has_turd = false
	targeted = false
	_kill_tween(_target_tween)
	_start_pickup_feedback()
	collected.emit(self)
	return true


func _start_pickup_feedback() -> void:
	_kill_tween(_pickup_tween)
	pickup_feedback_active = true
	turd_visual.visible = true
	var start_position := turd_visual.position
	var start_scale := turd_visual.scale
	_pickup_tween = create_tween()
	_pickup_tween.set_parallel(true)
	_pickup_tween.tween_property(turd_visual, "position", start_position + Vector3(0.0, 0.30, 0.0), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pickup_tween.tween_property(turd_visual, "scale", start_scale * 1.30, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pickup_tween.chain().tween_property(turd_visual, "position", start_position + Vector3(0.0, 0.52, 0.0), pickup_duration - 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pickup_tween.parallel().tween_property(turd_visual, "scale", Vector3.ZERO, pickup_duration - 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pickup_tween.chain().tween_callback(_finish_pickup_feedback)


func _finish_pickup_feedback() -> void:
	pickup_feedback_active = false
	if turd_visual == null:
		return
	turd_visual.visible = false
	turd_visual.position = _neutral_turd_position
	turd_visual.scale = _neutral_turd_scale


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _build_toilet() -> void:
	_add_mesh("Tank", _box_mesh(Vector3(1.05, 1.05, 0.45)), Vector3(0.0, 0.65, 0.38), Color("d7f3ee"))
	_add_mesh("Base", _cylinder_mesh(0.48, 0.55), Vector3(0.0, 0.28, -0.15), Color("e6fff9"))
	_add_mesh("Bowl", _sphere_mesh(0.68, 0.30), Vector3(0.0, 0.68, -0.28), Color("f4fff8"))
	_add_mesh("Water", _cylinder_mesh(0.42, 0.035), Vector3(0.0, 0.86, -0.30), Color("54c7e8"))

	var body := StaticBody3D.new()
	body.name = "ToiletCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.15, 1.25)
	shape.shape = box
	shape.position = Vector3(0.0, 0.55, 0.0)
	body.add_child(shape)
	add_child(body)

	turd_visual = Node3D.new()
	turd_visual.name = "TurdVisual"
	turd_visual.position = Vector3(0.0, 1.14, -0.31)
	add_child(turd_visual)
	var offsets := [Vector3(-0.13, 0.0, 0.0), Vector3(0.10, 0.10, 0.0), Vector3(0.0, 0.22, 0.0)]
	var scales := [Vector3(0.36, 0.18, 0.24), Vector3(0.31, 0.17, 0.22), Vector3(0.20, 0.14, 0.18)]
	var turd_color := Color("6d321c")
	if turd_type == "turbo":
		turd_color = Color("ff5a24")
	elif turd_type == "ghost":
		turd_color = Color("72e8ff")
	for index in 3:
		var lump := MeshInstance3D.new()
		lump.name = "Lump%d" % (index + 1)
		lump.mesh = _sphere_mesh(0.5, 1.0)
		var material := _material(turd_color)
		if turd_type != "normal":
			material.emission_enabled = true
			material.emission = turd_color
			material.emission_energy_multiplier = 1.25
		lump.mesh.material = material
		lump.position = offsets[index]
		lump.scale = scales[index]
		turd_visual.add_child(lump)


func _add_mesh(node_name: String, mesh: PrimitiveMesh, mesh_position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = mesh_position
	add_child(instance)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return mesh


func _sphere_mesh(radius: float, height_scale: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * height_scale
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
