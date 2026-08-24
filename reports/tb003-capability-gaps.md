# TB-003 Capability Gaps

TB-003 deliberately did not implement any of these capabilities. Each gap below was exposed by a concrete compromise in `restroom_003`, not added as a general wishlist item.

## Prioritized gaps

### HIGH VALUE — Stateful doors and simple triggers

The level can lock only the final exit. Its branches therefore remain statically open, and its false routes rely on walls, signs, and empty toilets rather than changing traversal state. Data-driven doors plus simple objective/area triggers would unlock gated shortcuts, staged reveals, return-path changes, and more meaningful route planning without requiring a full NPC or stealth system.

### HIGH VALUE — Rotated geometry and additional primitive shapes

All 53 primitives are axis-aligned boxes. The level achieves complexity through cross-shaped spines, partitions, bands, and columns, but corridors, landmarks, and sightlines retain a rectilinear character. Rotation and a small set of primitives such as cylinders, wedges, or ramps would materially expand room silhouettes, diagonal routing, visual landmarks, and composition.

### MEDIUM VALUE — Reusable environmental props/prefabs

The four zones are differentiated primarily by floor/wall color, lights, labels, toilet placement, and box-built decoration. A constrained data-driven prop/prefab vocabulary—pipes, sinks, bins, signs, puddles, and restroom clutter—would strengthen spatial storytelling and zone identity while keeping authoring deterministic.

### MEDIUM VALUE — Zone and event audio

Navigation currently depends entirely on visuals. Ambient loops, positional one-shots, and objective/decoy stingers could reinforce zone boundaries, draw players toward or away from branches, and make empty-toilet misdirection more expressive.

### LOW VALUE — Dynamic light behavior

The static colored lights already communicate the four-zone structure effectively. Pulsing, flickering, or trigger-driven lighting would improve reveals and atmosphere, but it would unlock less layout possibility than stateful doors, richer geometry, or props.

### LOW VALUE — Vertical traversal

The level is intentionally flat and fully exercises the existing ground movement. Stairs, ramps, jumping, or elevators would add another spatial dimension, but they would also broaden collision, camera, reachability, and testing requirements substantially. TB-003 did not demonstrate that this complexity should precede simpler route-state tools.

## Top three candidates for future slices

1. Stateful data-driven doors and simple triggers
2. Rotated geometry plus a small additional primitive set
3. Reusable environmental props/prefabs

## Recommendation

The single highest-value capability to add next is **stateful data-driven doors and simple triggers**. It would turn the existing objective system and multi-zone layouts into changing routes, gated branches, unlockable shortcuts, and staged reveals—the largest immediate increase in level-design possibility shown by this experiment.

No capability slice has been started, and GF-009 has not been started.
