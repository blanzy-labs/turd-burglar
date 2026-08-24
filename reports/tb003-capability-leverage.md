# TB-003 Capability Leverage

## Result

`restroom_003` ("The Porcelain Dimension") was accepted as a new playable level using only the data-driven capabilities present in the locked target baseline. The accepted autonomous source delta is exactly one file: `levels/restroom_003.json`.

Capability leverage: **HIGH**. The factory produced a materially larger, four-zone level with a central nexus, branching routes, deliberate false rewards, navigational lighting, and signage while adding zero runtime gameplay capabilities.

## Existing capabilities used

- Axis-aligned box geometry, including colliding floors, perimeter walls, partitions, islands, columns, gates, and non-colliding overhead decoration
- Per-primitive colors and collision selection
- Ground-based player movement and mouse camera control
- Data-driven spawn and exit placement
- Multiple toilets, toilet rotation, collectible toilets, and empty toilets
- Objective counting, duplicate-collection protection, locked-exit progression, and heist completion
- Rotated and colored 3D labels for zone identity, directions, jokes, and misdirection
- Directional and omni lights with per-light color, energy, range, and shadow settings
- Environment background, ambient color, and ambient energy
- Runtime level selection and Linux export loading

## Quantitative content

| Metric | Result |
| --- | ---: |
| Geometry primitives | 53 |
| Colliding / non-colliding geometry | 41 / 12 |
| Total toilets | 13 |
| Collectible toilets | 9 |
| Empty toilets | 4 |
| Labels | 12 |
| Lights | 10 |
| Unique light colors | 6 |
| Unique geometry colors | 24 |
| Approximate footprint | 48.5 × 48.5 world units |
| Runtime code added | 0 lines |
| Runtime files modified | 0 |
| Scenes modified | 0 |
| Schemas modified | 0 |
| New gameplay mechanics | 0 |

## Factory execution

- Milestone: `TB-CAP-M001`
- Task: `TB-CAP-001`
- Accepted run: `gf004-20260824T154345Z-1d6d61bb`
- Base target commit: `d2e9ce460a34c787348cd3d06865db374360d6bd`
- Accepted target commit: `73f2146671faff57538a9298ef6fe8a70ccc164b`
- Milestone tasks: 1
- Codex calls: 2 (one per task attempt)
- Critic calls: 2 (one incomplete infrastructure response, one valid PASS)
- Critic blockers: 0
- Automatic repair attempts: 0
- Recovery events: 0
- Accepted commits: 1
- Total autonomous execution time: 791.178 seconds across both attempts
- Accepted-attempt autonomous time: 327.627 seconds
- Human implementation interventions: 0
- Human prompt interventions after execution began: 0
- Operator retry transitions: 1, solely to retry an incomplete critic response caused by its output-token ceiling

The first task attempt passed scope and deterministic validation, but the `gpt-5.5` critic response ended `incomplete` after using 1,499 of its fixed 1,600 output tokens for reasoning. Game Foundry correctly rejected that attempt. The legal second task attempt used the real OpenAI `gpt-4.1-2025-04-14` critic and passed with 0 blockers, 0 warnings, and 6 observations. No candidate repair was requested or performed.

## Validation and regression

- Godot static validation: PASS
- TB-003 structural/gameplay acceptance: PASS
- Runtime markers and level selection: PASS
- TB-001 regression: PASS
- TB-002 regression: PASS
- Rendered 960×540 screenshot: PASS and visually inspected
- Linux export: PASS
- Exported binary runtime selection for `restroom_003`: PASS

Persistent evidence is under `artifacts/tb-003/final-20260824T155300Z/`. The playable Linux binary is `artifacts/tb-003/final-20260824T155300Z/build/turd-burglar.x86_64`; the starting-view screenshot is `artifacts/tb-003/final-20260824T155300Z/restroom-003-start.png`.

## Creative observations

- **Visual distinctness:** Four quadrant zones use cyan, acid green, magenta, and gold identities around a pale central Flush Nexus.
- **Layout complexity:** Four spatial sectors connect through a central transition with partitions, gates, alcoves, islands, and return routes instead of a single stall row.
- **Misdirection:** Four empty toilets are presented as deliberate bait, including `VIP TURD INSIDE`, `EMERGENCY TURD`, `STAFF TURDS ONLY`, and `PREMIUM NOTHING` concepts.
- **Lighting:** Paired colored beacons reinforce each zone, while the nexus has its own contrasting beacon and a directional fill.
- **Signage:** Twelve labels establish zones, directions, jokes, false promises, and the exit hint.
- **Existing-mechanic reuse:** Objective/exit progression, empty-toilet behavior, colors, collision, lights, and labels create the level's structure without a new mechanic.

These are automated/critic-supported observations, not a claim that the level is fun. Human gameplay QA remains pending.
