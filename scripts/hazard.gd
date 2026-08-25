class_name ResetZoneHazard
extends Node3D

signal activated(hazard: ResetZoneHazard, player: BurglarPlayer)

enum HazardState { READY, TRIGGERED, COOLDOWN }

var hazard_id := ""
var hazard_type := ""
var reset_position := Vector3.ZERO
var cooldown := 0.75
var activation_count := 0
var state := HazardState.READY
var active_player: BurglarPlayer


func configure(definition: Dictionary, player: BurglarPlayer) -> void:
	hazard_id = definition.id
	hazard_type = definition.type
	reset_position = definition.reset_position
	cooldown = definition.cooldown
	active_player = player
	name = hazard_id
	position = definition.position

	var surface_mesh := BoxMesh.new()
	surface_mesh.size = definition.size
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.color
	material.emission_enabled = true
	material.emission = definition.color.darkened(0.25)
	material.emission_energy_multiplier = 0.65
	material.roughness = 0.82
	surface_mesh.material = material
	$Surface.mesh = surface_mesh

	var shape := BoxShape3D.new()
	shape.size = definition.size
	$Area3D/CollisionShape3D.shape = shape


func _ready() -> void:
	$Area3D.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if hazard_type != "reset_zone" or state != HazardState.READY or body != active_player:
		return
	state = HazardState.TRIGGERED
	activation_count += 1
	print("TBR07_HAZARD_TRIGGERED=%s activation_count=%d" % [hazard_id, activation_count])
	activated.emit(self, active_player)
	state = HazardState.COOLDOWN
	_start_cooldown()


func _start_cooldown() -> void:
	await get_tree().create_timer(cooldown).timeout
	if state == HazardState.COOLDOWN:
		state = HazardState.READY
