class_name StatefulDoor
extends Node3D

enum { CLOSED, OPENING, OPEN }

var state := CLOSED
var closed_position := Vector3.ZERO
var open_offset := Vector3.ZERO
var open_duration := 0.5
var open_count := 0


func configure(definition: Dictionary) -> void:
	name = definition.id
	position = definition.position
	closed_position = position
	open_offset = definition.open_offset
	open_duration = definition.open_duration

	var mesh := BoxMesh.new()
	mesh.size = definition.size
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.color
	material.roughness = 0.85
	mesh.material = material
	$Visual.mesh = mesh

	var shape := BoxShape3D.new()
	shape.size = definition.size
	$StaticBody3D/CollisionShape3D.shape = shape


func open() -> bool:
	if state != CLOSED:
		return false
	state = OPENING
	open_count += 1
	var tween := create_tween()
	tween.tween_property(self, "position", closed_position + open_offset, open_duration)
	tween.tween_callback(_finish_opening)
	return true


func _finish_opening() -> void:
	state = OPEN
