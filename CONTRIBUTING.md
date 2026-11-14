# Contributing

Read `docs/SOFTWARE_SPEC.md` first (sections 4, 6, 17 and 19). Short version:

## Git

- `main` always runs. Only Anusha merges into `main`.
- Work on your own branch: `anusha`, `aadhav` or `bhairavi`. Pull `main` into your branch before each block, commit small and often, and push at the end of every block.
- If git reports a conflict in a file you do not own, stop and ask the owner.
- Commit `.gd`, `.json`, `.tscn`, `project.godot`, art `.png` files with their `.import` files, and `.uid` files. Never commit `.godot/`, builds or zips.
- Run the self-test before every push that touches `scripts/core/sim.gd` or `data/`:

```sh
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/truck_tests.gd
godot --headless --path . --script res://tests/craft_tests.gd
```

## Who owns what

One file, one owner. Do not edit another person's file; ask them (see spec section 4 for the full list).

| Owner | Files |
|---|---|
| Anusha | `main.gd`, `game_state.gd`, `sim.gd`, `truck_sim.gd`, `data.gd`, `test_lab`, `launch`, `ops`, `truck`, `event_card`, `data/*.json`, `tests/` |
| Aadhav | `workshop`, `puzzle_mass`, `puzzle_link`, `part_card`, `drop_zone` |
| Bhairavi | `ui.gd`, `chrome`, `title`, `ladder`, `briefing`, `report`, `puzzle_power`, `puzzle_time`, `line_chart`, `gantt_chart`, importing art |

## Rules

1. **All rules live in `sim.gd`** (and `truck_sim.gd` for the truck scenario). Screens never do game maths. They call the sim and show the answer.
2. **Numbers live in `data/*.json`.** Every number is a placeholder (`"source": "placeholder"`) until it has a real source. Never show a placeholder as a real NASA figure.
3. **Screens build their nodes in code in `_ready()`.** There is one `.tscn` in the project and nobody edits it.
4. **Use `preload`, not `class_name`.**
5. **Nothing random** in the rules. The same choices must always give the same result.
6. **Art is optional.** Use `UI.picture()` and `UI.frames()` so a missing file shows a labelled box. File names are lowercase with underscores and must match the art tracker exactly.
7. **Read spec section 19** (Godot 4 traps) before writing code, and tell your AI assistant "Godot 4, not Godot 3".
8. **Record every tool, library, sound, font and reference** in `docs/CREDITS.md`.

## Freeze

At the end of Block 5: no new features, bugs only. Tag the commit (`git tag freeze`) and back the project folder up.
