class_name TurdToilet
extends Node3D

signal collected(toilet: TurdToilet)

var has_turd := true
var turd_visual: Node3D


func _ready() -> void:
	add_to_group("toilets")
	_build_toilet()
	turd_visual.visible = has_turd


func collect() -> bool:
	if not has_turd:
		return false
	has_turd = false
	turd_visual.visible = false
	collected.emit(self)
	return true


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
	for index in 3:
		var lump := MeshInstance3D.new()
		lump.name = "Lump%d" % (index + 1)
		lump.mesh = _sphere_mesh(0.5, 1.0)
		lump.mesh.material = _material(Color("6d321c"))
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
