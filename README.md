# Sol by Sol

A turn-based outpost game for the **NASA Space Apps Challenge 2026**. You run a base on the Moon or Mars for 30 sols. Balance power, oxygen, water, food, radiation and crew health, and learn why there is no perfect build.

> All numbers in the game are **placeholders** chosen for fun and balance. They are not real NASA data. See [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md).

## How to play

- One turn is one sol (a Martian day; on the Moon the game says "Day").
- Each sol you spend build points on modules, choose which systems get power first, and press **End sol**.
- A report then explains what changed and why.
- If oxygen, water, food or crew health hits zero, or radiation hits the limit, the mission fails. The debrief shows the chain of causes.
- Survive 30 sols to win. Sols 1 to 5 are a guided tutorial.

## Run it

1. Install **Godot 4.7.x, standard version** (not .NET) from https://godotengine.org/download.
2. In Godot, choose Import and pick this folder's `project.godot`.
3. Press F5 to play.

Run the tests from a terminal in this folder (replace `godot` with the path to your Godot binary; on a Mac that's `/Applications/Godot.app/Contents/MacOS/Godot`):

```sh
godot --headless --path . --script res://tests/test_data.gd   # data files are valid
godot --headless --path . --script res://tests/test_sim.gd    # 30-sol scripted game
```

## Web export (HTML5)

You need the export templates first: in the editor, open Editor > Manage Export Templates > Download. Then choose Project > Export > **Web** > Export Project, which writes `build/web/index.html`. The preset turns threads off, so the build runs on itch.io or GitHub Pages without special server headers. To test the build locally, serve the folder (for example `python3 -m http.server` inside `build/web`). Opening the file directly from disk doesn't work.

## Folder layout

```
data/            Balance numbers (JSON). Edit these, not the scripts.
docs/            DATA_SCHEMA, ART_GUIDE, CREDITS, PREPARED_IN_ADVANCE
art/             PNGs (modules/, icons/, backgrounds/). See docs/ART_GUIDE.md
scripts/sim/     Pure simulation. No nodes, no UI. Testable headless.
scripts/ui/      Scripts attached to UI scenes. They read state and send actions.
scenes/main.tscn Root scene. Wires the UI pieces to the simulation.
scenes/ui/       One small scene per UI piece (HUD, build menu, report, ...)
tests/           Headless test scripts
```

## How the code fits together

```
 UI scenes ──actions──▶ main.gd ──tick(state, actions)──▶ scripts/sim/outpost_sim.gd
     ▲                     │                                       │
     └──── reads state ────┴───────── new state + report ◀─────────┘
```

The simulation never touches nodes, so `tests/test_sim.gd` can play a whole game in the terminal.

## Team

See [CONTRIBUTING.md](CONTRIBUTING.md) before your first commit.
