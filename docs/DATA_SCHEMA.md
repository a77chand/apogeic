# Data schema

All game balance lives in `data/*.json`. Scripts must not contain balance numbers. Change a JSON file, re-run the tests, and the game uses the new values.

## The one rule: every number has a source

```json
"cost": {"value": 3, "source": "placeholder"}
```

- `source` is `"placeholder"` when we made the number up for game balance. **Placeholder numbers are not NASA data.** Never describe them as real.
- When a number comes from a real source, put the citation in `source` (for example a NASA page URL with a title) and add the source to `docs/CREDITS.md`.
- `note` is optional and explains the number.
- Text and lists of ids (`name`, `description`, `order`, `targets`) are not wrapped.
- Keys that start with `_` (like `_comment`) are ignored by the game.

`scripts/sim/game_data.gd` removes the wrappers when it loads the files, so the simulation sees `"cost": 3`. Run `tests/test_data.gd` (see README) to catch bare numbers, broken JSON and misspelled ids.

## Units

Game units are made up and are kept simple for young players: "power", "oxygen", "water" and "food" units, and "dose points" for radiation. One turn is one sol (on the Moon the UI says "Day").

## modules.json

`modules.<id>`:

| Field | Meaning |
|---|---|
| `name`, `description` | Shown in the build menu |
| `cost` | Build points to order one |
| `build_time` | Sols until it works. 0 means it works on the sol you order it |
| `max_count` | Most you can own |
| `inputs` | Per working unit per sol, e.g. `{"power": 3, "water": 2}` |
| `outputs` | Per working unit per sol, e.g. `{"oxygen": 4}`. Solar `power` output is multiplied by sunlight |
| `uses_sunlight` | (true/false) output is multiplied by the scenario's sunlight and by storms/night |
| `power_storage` | (battery) extra power the base can store |
| `crew_capacity`, `morale_per_sol` | (habitat) beds, and health gained per sol |
| `background_dose_reduction` | (shielding) fraction of everyday radiation blocked per unit |
| `storm_dose_factor` | (shelter) solar particle event dose is multiplied by this |

`power_priorities.<id>.order`: when power or water runs short, modules get them in this order. The crew's base power always comes first.

## crew.json

| Field | Meaning |
|---|---|
| `crew_size` | Number of crew |
| `needs_per_person_per_sol` | oxygen, water, food eaten per person per sol |
| `base_power_per_sol` | Heaters, fans, computers. If unmet, the crew gets cold (`health.cold_penalty`) |
| `radiation_limit` | Total exposure that ends the mission |
| `health.*` | Health/morale rules: daily stress, penalties, and thresholds |
| `fail_at_zero` | Meters that end the mission when they reach zero |

## events.json

`events.<id>`: `name`, `warning_text`, `start_text`, `warning_sols` (sols of warning before it starts; 0 = no warning), `duration_min`/`duration_max` (sols), and `effects`:

- `storm_dose`: extra radiation per sol
- `solar_multiplier`: solar output is multiplied by this while active
- `disable_units`: units of a random module in `targets` stop working

How often an event happens is set per scenario, not here.

## scenarios.json

`scenarios.<id>` (currently `moon` and `mars`). Moon and Mars must differ only here.

| Field | Meaning |
|---|---|
| `day_word` | "Day" or "Sol" in the UI |
| `max_sols` | Survive this many sols to win |
| `solar_multiplier` | Sunlight strength |
| `background_dose` | Everyday radiation per sol, before shielding |
| `base_power_storage` | Power storage with no batteries |
| `start_build_points`, `build_points_per_sol` | Build budget |
| `storage_max` | Max oxygen, water, food |
| `start_meters`, `start_modules` | Starting state |
| `event_chances` | Chance per sol that each random event is rolled |
| `scheduled_events` | Events that always happen, e.g. lunar night: `{"event": "lunar_night", "start_sol": ...}` |

## tutorial.json

`random_events_from_sol`: random events are off before this sol. `scripted_events`: events forced during the tutorial. `steps`: one per sol, with `title`, `text` and an optional `goal_build` module id.

## Text placeholders

In event texts, `{day}` becomes "sol" on Mars and "day" on the Moon.
