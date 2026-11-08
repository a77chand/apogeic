# Art guide

The game runs on grey boxes until art exists. To swap one in, drop a PNG with the right name into `art/`. No code changes are needed: `scripts/ui/art.gd` checks for the file and falls back to the grey box if it isn't there.

| What | Path | Size |
|---|---|---|
| Module tile | `art/modules/<module_id>.png` | 128 x 128 |
| Meter icon | `art/icons/<meter>.png` | 32 x 32 |
| Background | `art/backgrounds/<scenario_id>.png` | 1280 x 720 |

- Module ids: `solar_panel`, `battery`, `electrolyzer`, `ice_miner`, `greenhouse`, `habitat`, `regolith_shielding`, `storm_shelter`
- Meters: `power`, `oxygen`, `water`, `food`, `radiation`, `health`
- Scenarios: `moon`, `mars`

Rules:
- PNG with a transparent background, lowercase file names, no spaces.
- Keep it readable at small size: bold shapes, high contrast, simple colors. Young players should recognise a greenhouse in one glance.
- Original art, or art with a licence that allows reuse. Record every asset you didn't draw yourself in `docs/CREDITS.md` (author, link, licence).
- NASA images are generally free to use but have their own guidelines (no implied endorsement, and the NASA insignia is restricted). Check the guidelines before using one, and credit it.
- After adding a PNG, open the project in the Godot editor once so it imports the file. Commit the generated `.import` file together with the PNG.
