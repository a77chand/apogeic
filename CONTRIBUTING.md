# Contributing

## Golden rules

1. **One scene, one owner.** Godot `.tscn` files merge badly. Before you edit a scene in `scenes/`, say so in the team chat. If you need something new, make a new small scene instead of growing someone else's.
2. **Numbers go in `data/`, not in scripts.** Wrap each one as `{"value": x, "source": "placeholder"}` unless you have a real source. See [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md).
3. **The sim knows nothing about the UI.** Code in `scripts/sim/` must not use nodes, `get_node`, `$`, or signals from UI. UI scripts read the state dictionary and call `main.gd`.
4. **Don't claim real NASA data unless you cite it.** Add every source, asset and tutorial to [docs/CREDITS.md](docs/CREDITS.md).
5. **Everything must work in the Web export.** Use only built-in Godot features. No file writes outside `user://`, no threads, no OS-specific code.

## Workflow

1. `git pull` before you start.
2. Work on a branch: `git checkout -b yourname/short-topic`.
3. Run both tests (see README) before you push.
4. Write a short commit message in the present tense: `Add greenhouse sprite`, `Fix trend arrow on water bar`.
5. Push your branch and open a pull request. Ask one teammate to look at it.
6. During the hackathon weekend it's fine to merge your own PR once the tests pass.

## Style

- GDScript: tabs for indentation, `snake_case` for variables and functions, and `PascalCase` for the `preload` constants of scripts.
- Comment anything a Godot beginner would not understand.
- Prefer `preload("res://...")` over `class_name`. It works in headless tests without an editor import.
- Art file names: see [docs/ART_GUIDE.md](docs/ART_GUIDE.md).

## Before Nov 14

Anything made before the event goes in [docs/PREPARED_IN_ADVANCE.md](docs/PREPARED_IN_ADVANCE.md).
