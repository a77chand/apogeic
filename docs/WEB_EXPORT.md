# Web export

Tested on 2026-11-14 with Godot 4.7.2 (standard build): the export succeeds and the build is served correctly. It was exported and served but **not yet confirmed in every browser**, so open it in Chrome and play through once before submitting.

## One-time setup

1. Open the project in Godot. Go to **Editor > Manage Export Templates > Download and Install** for your exact Godot version (about 1.2 GB), or install only the `web_*` files.
2. Copy `docs/export_presets.web.cfg` to `export_presets.cfg` in the project root. (That file is ignored by git, so each person who exports does this once.)
3. The preset already includes `*.json`. Godot does **not** pack JSON data files unless it is told to, and without them the game starts with no data.
4. It also turns threads off, so the build runs on a plain host (itch.io, GitHub Pages, `python3 -m http.server`) without special headers.

## Export

```sh
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

Or in the editor: Project > Export > Web > Export Project.

## Test it locally

A web build does not run by double-clicking `index.html`. Serve the folder:

```sh
cd build/web
python3 -m http.server 8765
```

Then open http://localhost:8765/index.html and run the manual test script in `docs/SOFTWARE_SPEC.md` section 18.

## Check that the data is packed

```sh
for f in level1 parts events puzzles truck craft tutorial; do grep -aq "data/$f.json" build/web/index.pck && echo "packed: $f" || echo "MISSING: $f"; done
```

## Upload

Upload the whole `build/web` folder to itch.io (as an HTML5 game) or GitHub Pages. Keep the desktop build as the backup for the demo video.
