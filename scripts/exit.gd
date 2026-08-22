class_name HeistExit
extends Area3D

var is_locked := true
var game: Node
var door_mesh: MeshInstance3D
var sign_label: Label3D


func _ready() -> void:
	add_to_group("exit")
	game = get_parent()
	_build_exit()
	body_entered.connect(_on_body_entered)
	set_locked(true)


func set_locked(locked: bool) -> void:
	is_locked = locked
	if door_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("bd3045") if locked else Color("42d65c")
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.25
	door_mesh.material_override = material
	sign_label.text = "EXIT LOCKED" if locked else "EXIT OPEN"


func attempt_exit(body: Node) -> bool:
	if is_locked or game == null or not body.is_in_group("player"):
		return false
	game.complete_heist()
	return true


func _on_body_entered(body: Node) -> void:
	attempt_exit(body)


func _build_exit() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.2, 2.8, 1.4)
	shape.shape = box_shape
	shape.position = Vector3(0.0, 1.4, 0.0)
	add_child(shape)

	door_mesh = MeshInstance3D.new()
	door_mesh.name = "Door"
	var door_box := BoxMesh.new()
	door_box.size = Vector3(2.1, 2.8, 0.18)
	door_mesh.mesh = door_box
	door_mesh.position = Vector3(0.0, 1.4, -0.62)
	add_child(door_mesh)

	sign_label = Label3D.new()
	sign_label.name = "ExitSign"
	sign_label.text = "EXIT LOCKED"
	sign_label.font_size = 64
	sign_label.outline_size = 12
	sign_label.position = Vector3(0.0, 3.15, -0.75)
	add_child(sign_label)
