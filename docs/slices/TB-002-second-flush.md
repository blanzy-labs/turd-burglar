# TB-002 — Second Flush

## Outcome

TB-002 converts Turd Burglar into a small restroom factory. First Flush and
Second Flush are data files interpreted by one validated loader and one runtime
builder. No Second Flush scene or gameplay script exists.

## Level-data schema

Level definitions live in `levels/` as JSON. Every definition requires:

- `id` and `name`: stable lowercase identifier and displayed name.
- `objective.turds_required`: positive integer exactly equal to the number of
  toilets whose `has_turd` value is `true`.
- `player_spawn`: three finite numbers.
- `exit.position`: three finite numbers.
- `toilets`: unique IDs, positions, `has_turd`, and optional rotation.
- `geometry`: one or more named `box` primitives with positive size, position,
  hexadecimal color, and a collision flag.
- `lights`: named `directional` or `omni` lights with the fields appropriate to
  that type.
- `environment`: background color, ambient color, and non-negative ambient
  energy.
- Optional `labels`: runtime-built `Label3D` signs used for stall identification.

The schema intentionally contains presentation data, not gameplay expressions,
scripts, random generation, or general-purpose scene serialization.

## Loader and validation

`scripts/level_loader.gd` resolves `--level=<id>` to
`res://levels/<id>.json`, reads it, reports JSON parser errors, validates required
fields, and returns normalized dictionaries containing Godot `Vector3` and
`Color` values. The default ID is `restroom_001`.

Loading fails closed for a missing file, invalid JSON, absent critical field,
invalid vector, invalid objective, duplicate object ID, unsupported primitive,
invalid light, or objective/collectible mismatch. Errors use the form
`level=<level> field=<field> reason=<reason>` where practical.

## Runtime builder behavior

`scripts/restroom.gd` owns the shared heist state, collection count, HUD, exit
lock, completion, restart, and construction of validated geometry, labels,
lights, toilets, player, and exit. `scripts/player.gd`, `scripts/toilet.gd`, and
`scripts/exit.gd` remain the single implementations for both levels. Empty
toilets build the same toilet body but hide the turd, reject collection, and are
excluded from the player's interaction target.

The HUD and completion overlay use `objective.turds_required`; there is no
global three-turd constant.

## Included levels

- `levels/restroom_001.json` migrates First Flush's three stalls, three
  collectible toilets, spawn, exit, primitive room, colors, signs, and lights.
- `levels/restroom_002.json` defines Second Flush's larger L-shaped floor, two
  stall banks, six stalls/toilets, five collectibles, one empty toilet, distinct
  spawn and exit, colors, and lighting.

Removing `restroom_002.json` makes `--level=restroom_002` fail with a missing-file
error. The acceptance script temporarily moves that file, verifies the failure,
restores it, and verifies the restored level in both editor runtime and the same
exported build.

## Running a level

With Godot 4.7.2:

```bash
godot --path . -- --level=restroom_001
godot --path . -- --level=restroom_002
```

With the exported build beside its generated `.pck`:

```bash
./turd-burglar.x86_64 -- --level=restroom_001
./turd-burglar.x86_64 -- --level=restroom_002
```

No argument selects `restroom_001`.

## Automated acceptance

Run the complete deterministic gate with an artifact directory outside the game
repository:

```bash
tests/run_tb002_acceptance.sh /absolute/path/to/tb-002-artifacts
```

The gate runs Godot import/static validation, First Flush regression, Second
Flush gameplay acceptance, loader negative tests, a runtime data-mutation proof,
the JSON-presence proof, both runtime selectors, two screenshots, one Linux
export, and both level selectors against that same export. It writes exact logs,
`timing.json`, and `manifest.json`.

The data-driven proof creates a temporary copy of `restroom_002.json`, changes
only `player_spawn` from the checked-in value to `[-8.75, 0.05, 5.25]`, loads it
through the real restroom runtime, and checks the generated player's position.
No gameplay source is modified.

Negative coverage confirms deterministic rejection of a missing required field,
invalid JSON, an objective of eight with only five collectible toilets, and a
missing level file.

## Automation metrics

The acceptance manifest records measured Godot validation, build, and total gate
time. This implementation required zero human implementation interventions,
zero human implementation minutes, zero manual Godot-editor changes, and zero
human manual source changes. Therefore Human Implementation Minutes Per New
Level for Second Flush is **0 actual minutes**. Human play-testing is excluded
from implementation time and remains pending.

## Creating Level 3

1. Copy or create a JSON specification in `levels/`.
2. Give it a unique lowercase ID matching its filename.
3. Define box geometry, colors, environment, and lights.
4. Define toilets and set each `has_turd` value.
5. Define player spawn and exit position.
6. Run `tests/validate.gd` or the complete TB-002 gate.
7. Run Game Foundry acceptance and perform the human play-test.

Creating Level 3 does not require a new GDScript class or `.tscn` level scene.

## Known limitations

- Geometry supports only axis-aligned boxes; toilets can be rotated but geometry
  cannot yet be rotated.
- Level discovery is by deterministic ID, not a menu or directory browser.
- Primitive meshes and labels remain intentionally crude.
- The schema does not support procedural generation, scripting, NPCs, audio,
  persistence, or other post-TB-002 systems.
- Automated evidence does not constitute human gameplay approval or authorize a
  release.
