class_name TurdLevelLoader
extends RefCounted

const DEFAULT_LEVEL_ID := "restroom_001"
const LEVEL_DIRECTORY := "res://levels"
const TURD_TYPES := ["normal", "turbo", "ghost"]


static func selected_level_id(arguments: PackedStringArray) -> String:
	for argument in arguments:
		if argument.begins_with("--level="):
			return argument.trim_prefix("--level=")
	return DEFAULT_LEVEL_ID


static func load_selected(arguments: PackedStringArray) -> Dictionary:
	return load_level(selected_level_id(arguments))


static func load_level(level_id: String) -> Dictionary:
	if not _is_valid_identifier(level_id):
		return _failure(level_id, "id", "must contain only lowercase letters, digits, and underscores")
	return load_file("%s/%s.json" % [LEVEL_DIRECTORY, level_id], level_id)


static func load_file(path: String, expected_id: String = "") -> Dictionary:
	var level_label := expected_id if not expected_id.is_empty() else path
	if not FileAccess.file_exists(path):
		return _failure(level_label, "file", "not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(level_label, "file", "could not open: %s" % error_string(FileAccess.get_open_error()))
	return parse_and_validate(file.get_as_text(), level_label, expected_id)


static func parse_and_validate(source: String, level_label: String = "inline", expected_id: String = "") -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(source)
	if parse_error != OK:
		return _failure(
			level_label,
			"json",
			"parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		)
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure(level_label, "root", "must be a JSON object")
	return validate_level(parser.data, level_label, expected_id)


static func validate_level(raw: Dictionary, level_label: String = "inline", expected_id: String = "") -> Dictionary:
	var id_result := _required_string(raw, "id", level_label)
	if not id_result.ok:
		return id_result
	var level_id: String = id_result.value
	if not _is_valid_identifier(level_id):
		return _failure(level_label, "id", "must contain only lowercase letters, digits, and underscores")
	if not expected_id.is_empty() and level_id != expected_id:
		return _failure(level_label, "id", "expected %s but found %s" % [expected_id, level_id])
	level_label = level_id

	var name_result := _required_string(raw, "name", level_label)
	if not name_result.ok:
		return name_result
	if not raw.has("objective") or typeof(raw.objective) != TYPE_DICTIONARY:
		return _failure(level_label, "objective", "required object is missing")
	if not raw.objective.has("turds_required"):
		return _failure(level_label, "objective.turds_required", "required integer is missing")
	var required_value = raw.objective.turds_required
	if not _is_integer_number(required_value) or int(required_value) <= 0:
		return _failure(level_label, "objective.turds_required", "must be an integer greater than zero")
	var required_turds := int(required_value)

	var spawn_result := _required_vector(raw, "player_spawn", level_label)
	if not spawn_result.ok:
		return spawn_result
	if not raw.has("exit") or typeof(raw.exit) != TYPE_DICTIONARY:
		return _failure(level_label, "exit", "required object is missing")
	var exit_result := _required_vector(raw.exit, "position", level_label, "exit.position")
	if not exit_result.ok:
		return exit_result

	if not raw.has("toilets") or typeof(raw.toilets) != TYPE_ARRAY or raw.toilets.is_empty():
		return _failure(level_label, "toilets", "must be a non-empty array")
	var toilets: Array[Dictionary] = []
	var toilet_ids := {}
	var collectible_count := 0
	for index in raw.toilets.size():
		var field := "toilets[%d]" % index
		if typeof(raw.toilets[index]) != TYPE_DICTIONARY:
			return _failure(level_label, field, "must be an object")
		var toilet_data: Dictionary = raw.toilets[index]
		var toilet_id_result := _required_string(toilet_data, "id", level_label, "%s.id" % field)
		if not toilet_id_result.ok:
			return toilet_id_result
		var toilet_id: String = toilet_id_result.value
		if toilet_ids.has(toilet_id):
			return _failure(level_label, "%s.id" % field, "duplicate toilet id: %s" % toilet_id)
		toilet_ids[toilet_id] = true
		var toilet_position := _required_vector(toilet_data, "position", level_label, "%s.position" % field)
		if not toilet_position.ok:
			return toilet_position
		if not toilet_data.has("has_turd") or typeof(toilet_data.has_turd) != TYPE_BOOL:
			return _failure(level_label, "%s.has_turd" % field, "required boolean is missing or invalid")
		var rotation := Vector3.ZERO
		if toilet_data.has("rotation_degrees"):
			var rotation_result := _vector_result(toilet_data.rotation_degrees, level_label, "%s.rotation_degrees" % field)
			if not rotation_result.ok:
				return rotation_result
			rotation = rotation_result.value
		if toilet_data.has_turd:
			collectible_count += 1
		var turd_type = toilet_data.get("turd_type", "normal")
		if typeof(turd_type) != TYPE_STRING or turd_type not in TURD_TYPES:
			return _failure(level_label, "%s.turd_type" % field, "must be one of: normal, turbo, ghost")
		var normalized_toilet := {
			"id": toilet_id,
			"position": toilet_position.value,
			"rotation_degrees": rotation,
			"has_turd": toilet_data.has_turd,
			"turd_type": turd_type,
		}
		if turd_type != "normal":
			if not toilet_data.has("effect_duration") or not _is_number(toilet_data.effect_duration) or not is_finite(float(toilet_data.effect_duration)) or float(toilet_data.effect_duration) <= 0.0:
				return _failure(level_label, "%s.effect_duration" % field, "must be a finite number greater than zero")
			normalized_toilet.effect_duration = float(toilet_data.effect_duration)
			if turd_type == "turbo":
				if not toilet_data.has("effect_value") or not _is_number(toilet_data.effect_value) or not is_finite(float(toilet_data.effect_value)) or float(toilet_data.effect_value) <= 1.0:
					return _failure(level_label, "%s.effect_value" % field, "must be a finite speed multiplier greater than one")
				normalized_toilet.effect_value = float(toilet_data.effect_value)
		toilets.append(normalized_toilet)
	if collectible_count != required_turds:
		return _failure(
			level_label,
			"objective.turds_required",
			"must equal collectible toilet count (%d), found %d" % [collectible_count, required_turds]
		)

	var doors: Array[Dictionary] = []
	var door_ids := {}
	if raw.has("doors"):
		if typeof(raw.doors) != TYPE_ARRAY:
			return _failure(level_label, "doors", "must be an array")
		for index in raw.doors.size():
			var result := _normalize_door(raw.doors[index], index, level_label, door_ids)
			if not result.ok:
				return result
			doors.append(result.value)

	var triggers: Array[Dictionary] = []
	var trigger_ids := {}
	if raw.has("triggers"):
		if typeof(raw.triggers) != TYPE_ARRAY:
			return _failure(level_label, "triggers", "must be an array")
		for index in raw.triggers.size():
			var result := _normalize_trigger(raw.triggers[index], index, level_label, trigger_ids, door_ids, required_turds)
			if not result.ok:
				return result
			triggers.append(result.value)

	var hazards: Array[Dictionary] = []
	var hazard_ids := {}
	if raw.has("hazards"):
		if typeof(raw.hazards) != TYPE_ARRAY:
			return _failure(level_label, "hazards", "must be an array")
		for index in raw.hazards.size():
			var result := _normalize_hazard(raw.hazards[index], index, level_label, hazard_ids)
			if not result.ok:
				return result
			hazards.append(result.value)

	if not raw.has("geometry") or typeof(raw.geometry) != TYPE_ARRAY or raw.geometry.is_empty():
		return _failure(level_label, "geometry", "must be a non-empty array")
	var geometry: Array[Dictionary] = []
	var geometry_names := {}
	for index in raw.geometry.size():
		var result := _normalize_geometry(raw.geometry[index], index, level_label, geometry_names)
		if not result.ok:
			return result
		geometry.append(result.value)

	if not raw.has("lights") or typeof(raw.lights) != TYPE_ARRAY:
		return _failure(level_label, "lights", "required array is missing")
	var lights: Array[Dictionary] = []
	for index in raw.lights.size():
		var result := _normalize_light(raw.lights[index], index, level_label)
		if not result.ok:
			return result
		lights.append(result.value)
	if lights.is_empty():
		return _failure(level_label, "lights", "must contain at least one light")

	if not raw.has("environment") or typeof(raw.environment) != TYPE_DICTIONARY:
		return _failure(level_label, "environment", "required object is missing")
	var environment_result := _normalize_environment(raw.environment, level_label)
	if not environment_result.ok:
		return environment_result

	var labels: Array[Dictionary] = []
	if raw.has("labels"):
		if typeof(raw.labels) != TYPE_ARRAY:
			return _failure(level_label, "labels", "must be an array")
		for index in raw.labels.size():
			var result := _normalize_label(raw.labels[index], index, level_label)
			if not result.ok:
				return result
			labels.append(result.value)

	return {
		"ok": true,
		"level": {
			"id": level_id,
			"name": name_result.value,
			"objective": {"turds_required": required_turds},
			"player_spawn": spawn_result.value,
			"exit": {"position": exit_result.value},
			"toilets": toilets,
			"geometry": geometry,
			"lights": lights,
			"environment": environment_result.value,
			"labels": labels,
			"doors": doors,
			"triggers": triggers,
			"hazards": hazards,
			"collectible_turd_count": collectible_count,
		},
	}


static func _normalize_hazard(value, index: int, level_label: String, ids: Dictionary) -> Dictionary:
	var field := "hazards[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var hazard: Dictionary = value
	var id_result := _required_string(hazard, "id", level_label, "%s.id" % field)
	if not id_result.ok:
		return id_result
	var hazard_id: String = id_result.value
	if ids.has(hazard_id):
		return _failure(level_label, "%s.id" % field, "duplicate hazard id: %s" % hazard_id)
	ids[hazard_id] = true
	if not hazard.has("type") or typeof(hazard.type) != TYPE_STRING or hazard.type != "reset_zone":
		return _failure(level_label, "%s.type" % field, "unsupported hazard type; expected reset_zone")
	var position_result := _required_vector(hazard, "position", level_label, "%s.position" % field)
	if not position_result.ok:
		return position_result
	var size_result := _required_vector(hazard, "size", level_label, "%s.size" % field)
	if not size_result.ok:
		return size_result
	var size: Vector3 = size_result.value
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return _failure(level_label, "%s.size" % field, "components must be greater than zero")
	var reset_result := _required_vector(hazard, "reset_position", level_label, "%s.reset_position" % field)
	if not reset_result.ok:
		return reset_result
	var color := Color("ff5b45")
	if hazard.has("color"):
		var color_result := _required_color(hazard, "color", level_label, "%s.color" % field)
		if not color_result.ok:
			return color_result
		color = color_result.value
	var cooldown_value = hazard.get("cooldown", 0.75)
	if not _is_number(cooldown_value) or not is_finite(float(cooldown_value)) or float(cooldown_value) <= 0.0:
		return _failure(level_label, "%s.cooldown" % field, "must be a finite number greater than zero")
	return {"ok": true, "value": {
		"id": hazard_id,
		"type": "reset_zone",
		"position": position_result.value,
		"size": size,
		"reset_position": reset_result.value,
		"color": color,
		"cooldown": float(cooldown_value),
	}}


static func _normalize_door(value, index: int, level_label: String, ids: Dictionary) -> Dictionary:
	var field := "doors[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var door: Dictionary = value
	var id_result := _required_string(door, "id", level_label, "%s.id" % field)
	if not id_result.ok:
		return id_result
	var door_id: String = id_result.value
	if ids.has(door_id):
		return _failure(level_label, "%s.id" % field, "duplicate door id: %s" % door_id)
	ids[door_id] = true
	var position_result := _required_vector(door, "position", level_label, "%s.position" % field)
	if not position_result.ok:
		return position_result
	var size_result := _required_vector(door, "size", level_label, "%s.size" % field)
	if not size_result.ok:
		return size_result
	var size: Vector3 = size_result.value
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return _failure(level_label, "%s.size" % field, "components must be greater than zero")
	var color_result := _required_color(door, "color", level_label, "%s.color" % field)
	if not color_result.ok:
		return color_result
	var offset_result := _required_vector(door, "open_offset", level_label, "%s.open_offset" % field)
	if not offset_result.ok:
		return offset_result
	var duration = door.get("open_duration", 0.5)
	if not _is_number(duration) or not is_finite(float(duration)) or float(duration) <= 0.0:
		return _failure(level_label, "%s.open_duration" % field, "must be a finite number greater than zero")
	return {"ok": true, "value": {
		"id": door_id,
		"position": position_result.value,
		"size": size,
		"color": color_result.value,
		"open_offset": offset_result.value,
		"open_duration": float(duration),
	}}


static func _normalize_trigger(value, index: int, level_label: String, ids: Dictionary, door_ids: Dictionary, required_turds: int) -> Dictionary:
	var field := "triggers[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var trigger: Dictionary = value
	var id_result := _required_string(trigger, "id", level_label, "%s.id" % field)
	if not id_result.ok:
		return id_result
	var trigger_id: String = id_result.value
	if ids.has(trigger_id):
		return _failure(level_label, "%s.id" % field, "duplicate trigger id: %s" % trigger_id)
	ids[trigger_id] = true
	if not trigger.has("type") or typeof(trigger.type) != TYPE_STRING or trigger.type != "collect_count":
		return _failure(level_label, "%s.type" % field, "unsupported trigger type; expected collect_count")
	if not trigger.has("threshold") or not _is_integer_number(trigger.threshold):
		return _failure(level_label, "%s.threshold" % field, "must be an integer")
	var threshold := int(trigger.threshold)
	if threshold < 1 or threshold > required_turds:
		return _failure(level_label, "%s.threshold" % field, "must be from 1 through objective.turds_required (%d)" % required_turds)
	if not trigger.has("action") or typeof(trigger.action) != TYPE_DICTIONARY:
		return _failure(level_label, "%s.action" % field, "required object is missing")
	var action: Dictionary = trigger.action
	if not action.has("type") or typeof(action.type) != TYPE_STRING or action.type != "open_door":
		return _failure(level_label, "%s.action.type" % field, "unsupported action type; expected open_door")
	var door_id_result := _required_string(action, "door_id", level_label, "%s.action.door_id" % field)
	if not door_id_result.ok:
		return door_id_result
	var door_id: String = door_id_result.value
	if not door_ids.has(door_id):
		return _failure(level_label, "%s.action.door_id" % field, "unknown door reference: %s" % door_id)
	return {"ok": true, "value": {
		"id": trigger_id,
		"type": "collect_count",
		"threshold": threshold,
		"action": {"type": "open_door", "door_id": door_id},
	}}


static func _normalize_geometry(value, index: int, level_label: String, names: Dictionary) -> Dictionary:
	var field := "geometry[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var primitive: Dictionary = value
	if not primitive.has("type") or primitive.type != "box":
		return _failure(level_label, "%s.type" % field, "unsupported geometry primitive; expected box")
	var name_result := _required_string(primitive, "name", level_label, "%s.name" % field)
	if not name_result.ok:
		return name_result
	if names.has(name_result.value):
		return _failure(level_label, "%s.name" % field, "duplicate geometry name: %s" % name_result.value)
	names[name_result.value] = true
	var size_result := _required_vector(primitive, "size", level_label, "%s.size" % field)
	if not size_result.ok:
		return size_result
	var size: Vector3 = size_result.value
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return _failure(level_label, "%s.size" % field, "components must be greater than zero")
	var position_result := _required_vector(primitive, "position", level_label, "%s.position" % field)
	if not position_result.ok:
		return position_result
	var color_result := _required_color(primitive, "color", level_label, "%s.color" % field)
	if not color_result.ok:
		return color_result
	if not primitive.has("collision") or typeof(primitive.collision) != TYPE_BOOL:
		return _failure(level_label, "%s.collision" % field, "required boolean is missing or invalid")
	return {"ok": true, "value": {
		"type": "box",
		"name": name_result.value,
		"size": size,
		"position": position_result.value,
		"color": color_result.value,
		"collision": primitive.collision,
	}}


static func _normalize_light(value, index: int, level_label: String) -> Dictionary:
	var field := "lights[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var light: Dictionary = value
	var name_result := _required_string(light, "name", level_label, "%s.name" % field)
	if not name_result.ok:
		return name_result
	if not light.has("type") or light.type not in ["directional", "omni"]:
		return _failure(level_label, "%s.type" % field, "must be directional or omni")
	if not light.has("energy") or not _is_number(light.energy) or float(light.energy) <= 0.0:
		return _failure(level_label, "%s.energy" % field, "must be a number greater than zero")
	var color_result := _required_color(light, "color", level_label, "%s.color" % field)
	if not color_result.ok:
		return color_result
	var normalized := {
		"name": name_result.value,
		"type": light.type,
		"energy": float(light.energy),
		"color": color_result.value,
	}
	if light.type == "directional":
		var rotation_result := _required_vector(light, "rotation_degrees", level_label, "%s.rotation_degrees" % field)
		if not rotation_result.ok:
			return rotation_result
		normalized.rotation_degrees = rotation_result.value
		normalized.shadow = bool(light.get("shadow", true))
	else:
		var position_result := _required_vector(light, "position", level_label, "%s.position" % field)
		if not position_result.ok:
			return position_result
		if not light.has("range") or not _is_number(light.range) or float(light.range) <= 0.0:
			return _failure(level_label, "%s.range" % field, "must be a number greater than zero")
		normalized.position = position_result.value
		normalized.range = float(light.range)
	return {"ok": true, "value": normalized}


static func _normalize_environment(value: Dictionary, level_label: String) -> Dictionary:
	var background := _required_color(value, "background_color", level_label, "environment.background_color")
	if not background.ok:
		return background
	var ambient := _required_color(value, "ambient_color", level_label, "environment.ambient_color")
	if not ambient.ok:
		return ambient
	if not value.has("ambient_energy") or not _is_number(value.ambient_energy) or float(value.ambient_energy) < 0.0:
		return _failure(level_label, "environment.ambient_energy", "must be a non-negative number")
	return {"ok": true, "value": {
		"background_color": background.value,
		"ambient_color": ambient.value,
		"ambient_energy": float(value.ambient_energy),
	}}


static func _normalize_label(value, index: int, level_label: String) -> Dictionary:
	var field := "labels[%d]" % index
	if typeof(value) != TYPE_DICTIONARY:
		return _failure(level_label, field, "must be an object")
	var label: Dictionary = value
	var name_result := _required_string(label, "name", level_label, "%s.name" % field)
	if not name_result.ok:
		return name_result
	var text_result := _required_string(label, "text", level_label, "%s.text" % field)
	if not text_result.ok:
		return text_result
	var position_result := _required_vector(label, "position", level_label, "%s.position" % field)
	if not position_result.ok:
		return position_result
	var color_result := _required_color(label, "color", level_label, "%s.color" % field)
	if not color_result.ok:
		return color_result
	var rotation := Vector3.ZERO
	if label.has("rotation_degrees"):
		var rotation_result := _vector_result(label.rotation_degrees, level_label, "%s.rotation_degrees" % field)
		if not rotation_result.ok:
			return rotation_result
		rotation = rotation_result.value
	return {"ok": true, "value": {
		"name": name_result.value,
		"text": text_result.value,
		"position": position_result.value,
		"rotation_degrees": rotation,
		"color": color_result.value,
	}}


static func _required_string(data: Dictionary, key: String, level_label: String, field: String = "") -> Dictionary:
	var resolved_field := key if field.is_empty() else field
	if not data.has(key) or typeof(data[key]) != TYPE_STRING or data[key].strip_edges().is_empty():
		return _failure(level_label, resolved_field, "required non-empty string is missing or invalid")
	return {"ok": true, "value": data[key]}


static func _required_vector(data: Dictionary, key: String, level_label: String, field: String = "") -> Dictionary:
	var resolved_field := key if field.is_empty() else field
	if not data.has(key):
		return _failure(level_label, resolved_field, "required Vector3 array is missing")
	return _vector_result(data[key], level_label, resolved_field)


static func _vector_result(value, level_label: String, field: String) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return _failure(level_label, field, "must be a 3-value array")
	for component in value:
		if not _is_number(component) or not is_finite(float(component)):
			return _failure(level_label, field, "components must be finite numbers")
	return {"ok": true, "value": Vector3(float(value[0]), float(value[1]), float(value[2]))}


static func _required_color(data: Dictionary, key: String, level_label: String, field: String) -> Dictionary:
	if not data.has(key) or typeof(data[key]) != TYPE_STRING or not _is_valid_color(data[key]):
		return _failure(level_label, field, "must be a 6- or 8-digit hexadecimal color")
	return {"ok": true, "value": Color(data[key])}


static func _is_valid_color(value: String) -> bool:
	var candidate := value.trim_prefix("#")
	if candidate.length() not in [6, 8]:
		return false
	for character in candidate.to_lower():
		if character not in "0123456789abcdef":
			return false
	return true


static func _is_valid_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


static func _is_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


static func _is_integer_number(value) -> bool:
	return _is_number(value) and is_finite(float(value)) and is_equal_approx(float(value), roundf(float(value)))


static func _failure(level_label: String, field: String, reason: String) -> Dictionary:
	return {"ok": false, "error": "level=%s field=%s reason=%s" % [level_label, field, reason]}
