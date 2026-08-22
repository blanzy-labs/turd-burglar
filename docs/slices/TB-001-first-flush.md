# TB-001 — First Flush

## Objective

Prove Game Foundry can autonomously produce a playable 3D loop: enter one
restroom, steal exactly one turd from each of three toilets, unlock the exit,
complete the heist, and restart.

## Implementation

Godot 4.7.2 Standard and GDScript build the room entirely from engine primitive
meshes. `CharacterBody3D` provides gravity and collision; a pivot, spring arm,
and camera provide third-person mouse look. Toilets enforce one-shot collection,
the restroom owns the tiny state machine, and the exit only completes the heist
after all three collections.

## Gameplay loop

WASD moves, the mouse rotates the camera, E steals an in-range turd, Esc releases
the mouse (then quits), and R reloads the scene after `HEIST COMPLETE`.

## Automated acceptance

The deterministic gameplay test validates the zero/locked start state, first
collection, duplicate protection, exact three-turd unlock, and exit completion.
Runtime modes emit exact markers and the exported binary supports
`--export-self-test`.

## Artifacts

Game Foundry writes the run manifest, logs, screenshots, patch, and Linux build
under `game-foundry/artifacts/tb-001/<run-id>/`. Generated binaries are not
committed to this repository.

## Known limitations

- Primitive geometry and default fonts intentionally look crude.
- Camera collision uses only the basic spring arm.
- The exit is an interior trigger/door rather than a second room.
- There is no audio, animation, save data, menu, NPC, or expanded game system.

## Automation metrics

The evidence manifest records human implementation touches/minutes and measured
agent, Godot, build, and total pipeline time. Supplying this slice, reviewing its
evidence, and performing the final play-test are not implementation touches.

## Manual QA

Launch the exact executable reported by Game Foundry. Verify movement, mouse
camera, all three toilets, one collection per toilet, HUD increments, exit unlock,
heist completion, and R restart. Human QA alone decides whether this stupid little
game is worth continuing.
