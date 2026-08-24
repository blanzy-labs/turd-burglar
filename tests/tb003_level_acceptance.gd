extends SceneTree

const LEVEL_ID := "restroom_003"
const MIN_TOILETS := 10
const MAX_TOILETS := 16
const MIN_COLLECTIBLES := 6
const MIN_EMPTY := 3
const MIN_GEOMETRY := 30
const MAX_GEOMETRY := 70
const MIN_LABELS := 6
const MAX_LABELS := 14
const MIN_LIGHTS := 6
const MAX_LIGHTS := 12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if TurdLevelLoader.selected_level_id(OS.get_cmdline_user_args()) != LEVEL_ID:
		_fail("test must run with --level=restroom_003")
		return
	var load_result := TurdLevelLoader.load_level(LEVEL_ID)
	if not load_result.ok:
		_fail("loader rejected level: %s" % load_result.error)
		return
	var level: Dictionary = load_result.level
	var raw_file := FileAccess.open("res://levels/restroom_003.json", FileAccess.READ)
	if raw_file == null:
		_fail("source JSON is unreadable")
		return
	var raw = JSON.parse_string(raw_file.get_as_text())
	if typeof(raw) != TYPE_DICTIONARY:
		_fail("source JSON root")
		return

	var toilet_count: int = level.toilets.size()
	var collectible_count: int = level.collectible_turd_count
	var empty_count := toilet_count - collectible_count
	if toilet_count < MIN_TOILETS or toilet_count > MAX_TOILETS:
		_fail("toilet complexity range")
		return
	if collectible_count < MIN_COLLECTIBLES or empty_count < MIN_EMPTY:
		_fail("collectible/empty counts")
		return
	if level.objective.turds_required != collectible_count:
		_fail("objective mismatch")
		return
	if level.geometry.size() < MIN_GEOMETRY or level.geometry.size() > MAX_GEOMETRY:
		_fail("geometry complexity range")
		return
	if level.labels.size() < MIN_LABELS or level.labels.size() > MAX_LABELS:
		_fail("label complexity range")
		return
	if level.lights.size() < MIN_LIGHTS or level.lights.size() > MAX_LIGHTS:
		_fail("light complexity range")
		return

	var toilet_ids := {}
	var quadrants := {}
	var empty_quadrants := {}
	for toilet: Dictionary in level.toilets:
		if toilet_ids.has(toilet.id):
			_fail("duplicate toilet id")
			return
		toilet_ids[toilet.id] = true
		if absf(toilet.position.y) > 0.25:
			_fail("toilet requires vertical traversal")
			return
		var quadrant := _quadrant(toilet.position)
		quadrants[quadrant] = true
		if not toilet.has_turd:
			empty_quadrants[quadrant] = true
	if quadrants.size() < 4:
		_fail("toilets do not represent four spatial zones")
		return
	if empty_quadrants.size() < 2:
		_fail("empty-toilet decoys are not spatially distinct")
		return

	var geometry_names := {}
	var geometry_colors := {}
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for primitive: Dictionary in level.geometry:
		if geometry_names.has(primitive.name):
			_fail("duplicate geometry name")
			return
		geometry_names[primitive.name] = true
		geometry_colors[primitive.color.to_html(false)] = true
		min_x = minf(min_x, primitive.position.x - primitive.size.x * 0.5)
		max_x = maxf(max_x, primitive.position.x + primitive.size.x * 0.5)
		min_z = minf(min_z, primitive.position.z - primitive.size.z * 0.5)
		max_z = maxf(max_z, primitive.position.z + primitive.size.z * 0.5)
	if geometry_colors.size() < 4:
		_fail("insufficient geometry color zoning")
		return
	var width := max_x - min_x
	var depth := max_z - min_z
	if width < 24.0 or depth < 24.0 or width > 80.0 or depth > 80.0:
		_fail("level footprint outside practical stress range")
		return

	var label_names := {}
	var label_colors := {}
	for label: Dictionary in level.labels:
		if label_names.has(label.name):
			_fail("duplicate label name")
			return
		label_names[label.name] = true
		label_colors[label.color.to_html(false)] = true
	if label_colors.size() < 3:
		_fail("signage lacks visual zoning")
		return

	var light_names := {}
	var light_colors := {}
	for light: Dictionary in level.lights:
		if light_names.has(light.name):
			_fail("duplicate light name")
			return
		light_names[light.name] = true
		light_colors[light.color.to_html(false)] = true
	if light_colors.size() < 3:
		_fail("fewer than three light colors")
		return
	if level.player_spawn.distance_to(level.exit.position) < 20.0:
		_fail("spawn and exit are not meaningfully separated")
		return
	if absf(level.player_spawn.y) > 0.25 or absf(level.exit.position.y) > 0.25:
		_fail("spawn/exit require vertical traversal")
		return
	print("TB003_LEVEL_DATA_OK")
	print("TB003_GEOMETRY=%d" % level.geometry.size())
	print("TB003_TOILETS=%d" % toilet_count)
	print("TB003_COLLECTIBLE_TURDS=%d" % collectible_count)
	print("TB003_EMPTY_TOILETS=%d" % empty_count)
	print("TB003_LABELS=%d" % level.labels.size())
	print("TB003_LIGHTS=%d" % level.lights.size())
	print("TB003_LIGHT_COLORS=%d" % light_colors.size())
	print("TB003_FOOTPRINT=%.1fx%.1f" % [width, depth])

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	var game: RestroomRuntime = main.get_node("Restroom")
	if game.level_id != LEVEL_ID or game.toilets.size() != toilet_count or game.required_turds != collectible_count:
		_fail("runtime identity/counts")
		return
	if game.collected_turds != 0 or not game.heist_exit.is_locked:
		_fail("initial gameplay state")
		return
	print("TB003_TEST_START_STATE_OK")

	var empty_toilets := game.toilets.filter(func(toilet: TurdToilet) -> bool: return not toilet.has_turd)
	for empty: TurdToilet in empty_toilets:
		if empty.collect() or game.collected_turds != 0 or empty.turd_visual.visible:
			_fail("empty toilet collection")
			return
	print("TB003_TEST_EMPTY_TOILETS_OK")

	if game.heist_exit.attempt_exit(game.player):
		_fail("exit accepted before objective")
		return
	var collectibles := game.toilets.filter(func(toilet: TurdToilet) -> bool: return toilet.has_turd)
	for index in collectibles.size():
		var toilet: TurdToilet = collectibles[index]
		if not toilet.collect() or game.collected_turds != index + 1:
			_fail("collection %d" % (index + 1))
			return
		if toilet.collect() or game.collected_turds != index + 1:
			_fail("duplicate collection %d" % (index + 1))
			return
		if index < collectibles.size() - 1 and (not game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.PLAYING):
			_fail("exit unlocked early")
			return
	if game.collected_turds != collectible_count or game.heist_exit.is_locked or game.state != RestroomRuntime.HeistState.EXIT_AVAILABLE:
		_fail("objective completion/unlock")
		return
	print("TB003_TEST_DUPLICATE_PROTECTION_OK")
	print("TB003_EXIT_UNLOCKED")
	if not game.heist_exit.attempt_exit(game.player) or game.state != RestroomRuntime.HeistState.HEIST_COMPLETE:
		_fail("heist completion")
		return
	print("TB003_HEIST_COMPLETE")
	print("TB003_GAMEPLAY_ACCEPTANCE_OK")
	quit(0)


func _quadrant(position: Vector3) -> String:
	return "%s_%s" % ["east" if position.x >= 0.0 else "west", "south" if position.z >= 0.0 else "north"]


func _fail(stage: String) -> void:
	push_error("TB-003 acceptance failed: %s" % stage)
	quit(1)
