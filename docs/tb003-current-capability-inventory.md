# TB-003 Current Capability Inventory

This inventory is based on the current Turd Burglar loader, runtime scripts, scenes, level JSON, and TB-001/TB-002 acceptance tests. “Enabled” means the current runtime/data model exposes and uses the capability; it does not mean Godot merely supports it.

## ENABLED

### Player and interaction

- Ground-based character movement on the X/Z plane using W/A/S/D, gravity, collision, and a fixed movement speed.
- Third-person mouse camera with bounded pitch and free yaw.
- Proximity selection of the nearest collectible toilet within 2.65 units.
- E-key collection, an interaction prompt, and duplicate-collection protection.
- Escape mouse release/quit behavior and R-key restart after heist completion.

### Objective and exit

- A positive `objective.turds_required` value that must equal the number of collectible toilets.
- Dynamic collection and completion HUD counts.
- One normal exit position per level, locked until the exact objective count is reached.
- Exit color/sign state, player-only exit activation, heist completion, and restart.
- Deterministic level selection through `--level=<lowercase_id>` with `restroom_001` as default.

### Toilets

- Multiple toilets with unique IDs, positions, optional 3-axis rotation, and `has_turd` true/false state.
- Collectible and empty toilets. Empty toilets hide the turd, reject collection, and are excluded from proximity prompting.
- Reuse of the one existing toilet scene and visual/collision construction.

### Level composition

- Named, axis-aligned box geometry with position, positive size, hexadecimal color, and collision on/off.
- Multiple floor sectors, walls, corridors, alcoves, partitions, columns, overhead/decorative bands, and landmarks can be composed from boxes.
- Non-colliding decorative geometry and colliding traversal boundaries.
- Player spawn and exit position.
- 3D text labels with name, short text, position, optional rotation, and color.

### Lighting and environment

- Directional lights with rotation, color, positive energy, and optional shadow flag.
- Omni lights with position, color, positive energy, and positive range.
- Multiple lights and colors for visually distinct navigation zones.
- Environment background color, ambient color, and non-negative ambient energy.

### Validation and automation

- Fail-closed JSON parsing and normalized runtime validation.
- Identifier, vector, color, objective/count, duplicate toilet ID, duplicate geometry name, primitive, light, and missing-file checks.
- Runtime construction from data, self-test collection/completion, rendered screenshot capture, Linux x86_64 export, and exported level selection.

## NOT ENABLED

- Jumping, climbing, crouching, swimming, ladders, designed vertical traversal, or moving platforms.
- NPCs, janitors, enemies, patrols, stealth, detection, combat, health, or hazards.
- Doors, keys, switches, buttons, triggers, scripted events, checkpoints, or conditional geometry.
- New collectible types, inventory, carried items, scoring, timers, persistence, saves, or procedural generation.
- General-purpose interactions beyond collecting turds and entering the existing exit.
- Rotated box geometry or geometry primitive types other than boxes. Toilet and label rotation do not imply geometry rotation.
- Per-geometry materials beyond a flat albedo color/roughness, textures, custom meshes, imported props, shaders, animation, particles, or dynamic material behavior.
- Spotlights, animated/dynamic lights, per-light shadows for omni lights, fog, sky resources, post-processing, or environment effects beyond the three exposed environment fields.
- Audio, music, dialogue, cutscenes, minimap, compass, objective markers, level menu, or navigation UI.
- Multiple exits, exit rotation, configurable interaction range, player rotation/spawn facing, or configurable movement parameters.
- Runtime scripting embedded in level JSON or schema extension points.

## UNCERTAIN

- Very large box counts and overlapping non-colliding geometry are syntactically supported, but practical rendering/performance limits have not been stress-tested.
- Arbitrarily long 3D label text is accepted, but readability, clipping, and useful viewing distance depend on layout and camera placement.
- Dense collision mazes are representable, but the schema has no reachability solver; deterministic tests can prove ground-level placement and gameplay state, while human QA must judge navigation and stuck spots.
- Toilet rotations on arbitrary axes validate, but only sensible ground-level Y rotation is established by existing content.
- Ceiling-like boxes are possible, but camera occlusion and player comfort remain human-QA concerns.

## TB-003 design boundary

The stress level may combine only the ENABLED capabilities above. If an idea needs anything in NOT ENABLED or cannot be established safely from the UNCERTAIN group, the level must use an enabled workaround or omit it. No runtime gameplay feature may be added for TB-003.
