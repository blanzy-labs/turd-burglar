# Turd Burglar

An intentionally crude third-person Godot game. TB-002, **Second Flush**, turns
the original restroom into a data-driven level runtime. First Flush and Second
Flush are JSON definitions built by the same gameplay controller.

## Run

Requires Godot 4.7.2 Standard:

```bash
godot --path . -- --level=restroom_001
godot --path . -- --level=restroom_002
```

Controls: WASD move, mouse look, E interact, R restart after completion, Esc
release mouse/quit.

Omit `--level` to default to First Flush. Deterministic checks, schema details,
and artifact instructions are documented in
[`docs/slices/TB-002-second-flush.md`](docs/slices/TB-002-second-flush.md).
