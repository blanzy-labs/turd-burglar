# Turd Burglar repository guide

## Authority hierarchy

1. Human — creative and release authority.
2. OpenClaw — orchestration authority.
3. Codex — implementation authority.
4. Godot — executable truth.
5. Automated acceptance — regression truth.
6. Human play-test — final gameplay judgment.

Codex reporting that a feature works is not evidence that it works.

No automated agent may publish a game release without explicit human approval.

## Working rules

- Keep TB-001 crude, dependency-free, and limited to the First Flush loop.
- Treat deterministic failures as failures; prose cannot override them.
- Validate project changes with Godot 4.7.2 and the bounded checks in `tests/`.
- Do not commit generated builds, logs, Godot cache data, or local orchestration state.
