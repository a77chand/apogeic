# Space Mission Designer: Software Specification (Plan C)

NASA Space Apps 2026, Space Mission Design Game. Godot 4, 2D, GDScript.
For Anusha, Aadhav and Bhairavi. Written so that each of you can hand a section to your own AI assistant and get code that fits with everyone else's.

---

## 0. Read this first

> **Updated 14 Nov:** The starter has now been run inside Godot 4.7.2 and the self-test passes there. The "NOT checked" row below is out of date. See 0.1.


**What exists already.** A starter project comes with this document (`space-mission-designer-starter.zip`). It contains the data files, the full rules engine, the game state, the screen router, a UI helper, a title screen, a stub screen and a test suite. About 1,400 lines.

**What has been checked, and what has not.**

| Item | Status |
|---|---|
| All game numbers and expected test values | Checked. I ran the same rules in a separate Python copy against the same JSON files. |
| GDScript syntax of every starter file | Checked with the gdtoolkit parser (`gdparse`). |
| The starter running inside Godot | **NOT checked.** Godot could not be installed in the environment this was written in. Nobody has opened this project in Godot yet. |
| Godot class, method and property names | Written from memory. Section 22 lists every one so you can confirm them. |

So nobody can promise "no bugs" yet. The first job on Saturday (Block 0) is to open the starter, press Play, and press **Run self-test** on the title screen. If the self-test says all checks passed, the rules engine is proven inside Godot. If something is red in the Output panel, fix that before anyone writes a screen.

**All game numbers are placeholders.** Every part and limit carries `"source": "placeholder"` or sits in a file with a placeholder note. They are tuned so the game is winnable, not taken from NASA data. Never show them as real figures. Replace them when the verified data is in hand, then update the tests in the same commit.

**Three rules that keep three coders from breaking each other's work.**

1. Rules live only in `scripts/core/sim.gd`. Screens never do game maths. They call Sim and show the answer.
2. One screen is one script file with one owner. Nobody edits another person's screen file.
3. Screens build their nodes in code, in `_ready()`. There is one `.tscn` in the whole project and nobody edits it. This avoids scene merge conflicts, and it means an AI assistant can write a complete working screen as plain text.

---

## 0.1 What changed since this spec was written (14 Nov)

This spec described the plan. The game has moved on. Everything below is built, tested and on `main`. Where an older section is now out of date, it has an "Updated 14 Nov" note pointing here.

**Status.** All 13 screens are real (no stubs left): title, ladder, the four puzzles, briefing, workshop, test lab, launch, operations, report, and the truck scenario. The project has been run inside Godot 4.7.2. The self-test and three more test files pass (see section 18).

**New rules (all in the sim, all data-driven):**

| Rule | Where | What it does |
|---|---|---|
| Launch can fail | `Sim.launch_outcome`, `Sim.fail_launch`; `level1.json` `launch_min_readiness_pct` (80) | Readiness must reach 80% or the rocket does not reach orbit. Below that it climbs only as far as the readiness number, the mission ends with `end_reason = "launch_failed"`, there is no operations phase, and the report explains why. No randomness. |
| Rocket size from mass | `Sim.rocket_for_mass`; `level1.json` `rocket_by_mass` | Small, medium or heavy rocket picture, chosen from the design's mass. |
| Craft size | `scripts/core/craft.gd`, `data/craft.json` | Player picks 1U, 3U or 6U on the briefing (LEO and rideshare are fixed, by team decision). The size sets the mass limit, bus mass and launch cost. 3U is identical to the original level. |
| Vibration test has 3 choices | `data/events.json` | Added "Fit the spare mount" ($10k, +25 days) next to Repair ($20k, +10 days) and Fly as it is. Early builders lose nothing to the wait (the licence already holds launch at day 121); late builders do. |
| Week history | `Sim.new_ops_state`, `Sim.ops_week` | `ops.history` keeps one record per week (battery, stored, delivered) for the report chart. |

**New screens and pieces:** `truck.gd` (NASA-problem scenario: sensor choice for an autonomous construction truck, with `truck_sim.gd` and `data/truck.json`; mostly illustrative numbers, one NASA-sourced sensor, see `docs/TRUCK_SOURCES.md`), `report.gd`, `ladder.gd`, `briefing.gd`, `tutorial.gd` + `data/tutorial.json` (first-visit tips), `sfx.gd` (sound), `sprites.gd`, `starfield.gd`, `orbit_ring.gd`, `week_chart.gd`.

**Look and feel.** Mission-control style in `ui.gd`: Rajdhani display font (OFL, in `art/fonts/`), slim angled buttons with a cyan edge, glassy panels with corner ticks, see-through top and tip bars, outlined text, a vignette. Missing art is drawn in code (Earth, satellite, rockets, launch pad, part icons, starfield with planets and shooting stars); any PNG with the tracker name replaces the drawing automatically. The orbit view has depth (the satellite passes behind the Earth), the workshop satellite builds itself as parts are fitted, and the launch has a flame, smoke and a camera pull-back.

**Sound.** Generated in code, no audio files: click, select, fit, countdown beeps and lift-off tone, rumble, ping, alert, chime, failure tone, and a short fanfare for puzzles and full success. Sound on/off on the title, saved.

**Web export.** Done and tested to build: see `docs/WEB_EXPORT.md` and `docs/export_presets.web.cfg` (adds `*.json`, threads off). Hosted on GitHub Pages.

---

## 1. What we are building

Four short puzzles teach one rule each. Then a full mission uses all four rules.

```
Title -> Ladder -> Puzzle 1 Mass -> Puzzle 2 Power -> Puzzle 3 Data link -> Puzzle 4 Budget and time
      -> Briefing -> Workshop <-> Test lab -> Launch scene -> Orbit operations (+ event cards) -> Report
```

- A failed test sends the player back to the Workshop with the design kept. Each trip back costs days.
- The player may launch with failed checks ("Launch anyway"), except when the spacecraft is over mass or incomplete.
- Failed checks have fixed, explainable consequences in orbit. Nothing in the game is random. The same choices always give the same result, which makes the demo safe and the report honest.
- The report gives 0 to 3 stars and a plain-language cause chain.

**Build order (do not change it).** Full mission first, then Puzzle 1, Puzzle 3, Puzzle 2, Puzzle 4. If the mission is not playable start to finish at the end of Block 2, cut Puzzles 3 and 4. To cut a puzzle, remove its id from `"order"` in `data/puzzles.json`. Nothing else needs to change.

---

## 2. Tools and setup

1. **Godot version.** All three of you install the same Godot 4 stable version, the standard build (not the .NET build). Agree the exact version number in the team chat before Block 0. The starter only uses features that have been in Godot since 4.2, to my knowledge. Do not mix versions: a newer editor rewrites project files and the others then get noise in git.
2. **Get the project.** Anusha unzips the starter, creates the GitHub repo, and pushes it. The others clone it.
3. **First open.** In the Godot Project Manager choose Import and select `project.godot`. Let the editor import. It will create a `.godot` folder (ignored by git) and may rewrite `project.godot` slightly. Anusha commits that rewrite once so everyone has the same file.
4. **First run.** Press F5. You should see the title screen with a labelled grey box where the logo will go. Press **Run self-test**. Expect "all checks passed".
5. **Click through.** Press Play. Every screen that is not written yet shows a stub with its id and a Next button. You can walk the whole flow on day one.
6. **Tests from a terminal (optional).** From the project folder: `godot --headless --path . --script res://tests/run_tests.gd`. Use your real Godot executable name. Exit code 0 means pass. Run the editor once first so the project is imported.

---

## 3. Project settings (already in `project.godot`)

| Setting | Value | Why |
|---|---|---|
| `application/run/main_scene` | `res://scenes/main.tscn` | The only scene |
| Autoload `GameState` | `res://scripts/autoload/game_state.gd` | Shared state |
| `display/window/size/viewport_width`, `viewport_height` | 1280, 720 | The art is drawn for this size |
| `display/window/stretch/mode` | `canvas_items` | The UI scales with the window |
| `display/window/stretch/aspect` | `keep` | No distortion, black bars if needed |
| `rendering/renderer/rendering_method` | `gl_compatibility` | Needed for the web export, as far as I know |

Check these in Project > Project Settings after the first open. If the editor shows different names, trust the editor.

Because the viewport is fixed at 1280 x 720 and stretched, you can place things with absolute pixel positions where that is easier (launch scene, orbit view). Use containers for panels and lists.

---

## 4. Folder layout and file ownership

```
project.godot
scenes/main.tscn                  nobody edits
scripts/main.gd                   Anusha   (router, list of screens)
scripts/autoload/game_state.gd    Anusha
scripts/core/sim.gd               Anusha   (all rules)
scripts/core/data.gd              Anusha   (JSON loading)
scripts/ui/ui.gd                  Bhairavi (helpers: label, button, panel, meter, picture, frames, money)
scripts/ui/chrome.gd              Bhairavi (top bar and tip bar, to write)
scripts/ui/event_card.gd          Anusha   (popup, to write)
scripts/ui/part_card.gd           Aadhav   (draggable part, to write)
scripts/ui/drop_zone.gd           Aadhav   (drop target, to write)
scripts/ui/line_chart.gd          Bhairavi (Puzzle 2 chart, to write)
scripts/ui/gantt_chart.gd         Bhairavi (Puzzle 4 chart, to write)
scripts/screens/title.gd          Bhairavi (exists, restyle)
scripts/screens/stub.gd           nobody edits
scripts/screens/ladder.gd         Bhairavi
scripts/screens/briefing.gd       Bhairavi
scripts/screens/report.gd         Bhairavi
scripts/screens/puzzle_power.gd   Bhairavi
scripts/screens/puzzle_time.gd    Bhairavi
scripts/screens/workshop.gd       Aadhav
scripts/screens/puzzle_mass.gd    Aadhav
scripts/screens/puzzle_link.gd    Aadhav
scripts/screens/test_lab.gd       Anusha
scripts/screens/launch.gd         Anusha
scripts/screens/ops.gd            Anusha
data/parts.json level1.json events.json puzzles.json    Anusha
tests/sim_tests.gd run_tests.gd   Anusha
art/...                           files from Aditi and Tanvi, copied in by Bhairavi
docs/SOFTWARE_SPEC.md             this file
```

The screen file names are fixed. `main.gd` already lists all twelve, and a screen appears in the game the moment its file exists. You do not need to touch `main.gd` to add your screen.

If you need a new function in `sim.gd`, `game_state.gd` or `ui.gd`, ask the owner. Do not add it yourself in a hurry, because two people editing the same file is where merge conflicts come from.

---

## 5. Architecture

```
data/*.json  ->  Data (static loader)  ->  GameState (autoload: data + current play-through)
                                               |
Sim (static rules, pure) <---- called by ----- screens (one Control script each) ---- UI (static helpers)
                                               |
                                         main.gd (router: swaps one screen at a time)
```

- **Data** (`scripts/core/data.gd`): static functions that read JSON and return Dictionaries. Returns `{}` or `[]` and logs an error if a file is missing or broken. It never crashes.
- **Sim** (`scripts/core/sim.gd`): static functions, Dictionaries in and Dictionaries out. No nodes, no autoloads, no time, no input, no randomness. This is why it can be tested without opening a scene.
- **GameState** (autoload): holds the loaded data and the current attempt (design, schedule, ops state, log). Has small helpers. Emits `design_changed`.
- **main.gd**: owns the background and exactly one screen node at a time. `GameState.go("workshop")` swaps screens.
- **UI** (`scripts/ui/ui.gd`): makes labels, buttons, panels, meters and pictures that all look the same. Buttons and panels are drawn with `StyleBoxFlat`, so the game needs no button or panel art to look finished.

Scripts refer to each other with `const Sim = preload("res://scripts/core/sim.gd")`. Do not use `class_name`. Preloads work in headless tests and never depend on the editor's class cache.

---

## 6. How to write a screen

Every screen follows this contract.

1. The file is `scripts/screens/<id>.gd` and starts with `extends Control`.
2. It builds all its nodes in `_ready()`. The router has already made it fill the 1280 x 720 screen.
3. It reads data from `GameState` and gets every number from `Sim`.
4. It changes screen only with `GameState.go("<id>")`.
5. It must work when art is missing. Use `UI.picture(path, size, "name")`, which shows a labelled box when the file is not there.
6. It must not keep running after it is replaced. Timers and tweens that are children of the screen are freed with it. Do not create timers on the scene tree root.
7. It connects to `GameState.design_changed` only if it needs live updates, and it is safe if the signal fires during `_ready()`.

Template:

```gdscript
extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")

var _status: Label = null


func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel()
	center.add_child(panel)
	var col: VBoxContainer = UI.vbox(12)
	panel.add_child(col)
	col.add_child(UI.label("My screen", 28))
	_status = UI.label("", 14, UI.C_MUTED)
	col.add_child(_status)
	col.add_child(UI.button("Continue", _on_continue, 240.0, true))
	_refresh()


func _refresh() -> void:
	var ev: Dictionary = GameState.evaluate()
	_status.text = "Mass %.1f kg" % float(ev["mass_kg"])


func _on_continue() -> void:
	GameState.go("ladder")
```

`scripts/screens/title.gd` is a complete working example.

---

## 7. Data files

All in `data/`. Change numbers here, never in code. Every number read from JSON arrives in Godot as a `float`, even `120`. Wrap with `int()` when you need a whole number.

### 7.1 `parts.json`

`{"parts": [ ... ]}`. Each part:

| Field | Type | Meaning |
|---|---|---|
| `id` | String | Unique key, used everywhere |
| `name` | String | Shown to the player |
| `category` | String | `solar`, `battery`, `instrument`, `radio` or `extra`. Decides which slot it fits |
| `mass_kg` | number | Mass |
| `power_gen_w` | number | Average power made over one whole orbit, eclipse included |
| `power_use_w` | number | Power used |
| `battery_wh` | number | Energy stored |
| `make_mb_wk` | number | Data made per week (instruments) |
| `send_mb_wk` | number | Data sent per week (radio and extras). Counts only if a radio is fitted |
| `data_type` | String | `images` or `spectra` for instruments, otherwise `""` |
| `cost_k` | number | Cost in thousand dollars |
| `icon` | String | Path to the picture. May not exist yet |
| `blurb` | String | One line for the part card |
| `source` | String | `placeholder` until verified |

Current parts (placeholders):

| id | category | kg | makes W | uses W | Wh | makes MB/wk | sends MB/wk | $k |
|---|---|---|---|---|---|---|---|---|
| solar_small | solar | 0.6 | 14 | 0 | 0 | 0 | 0 | 60 |
| solar_large | solar | 0.9 | 22 | 0 | 0 | 0 | 0 | 110 |
| battery_small | battery | 0.25 | 0 | 0 | 20 | 0 | 0 | 25 |
| battery_std | battery | 0.5 | 0 | 0 | 40 | 0 | 0 | 40 |
| camera_std | instrument (images) | 0.7 | 0 | 4 | 0 | 60 | 0 | 150 |
| spectrometer | instrument (spectra) | 1.1 | 0 | 8 | 0 | 25 | 0 | 220 |
| radio_uhf | radio | 0.1 | 0 | 1 | 0 | 0 | 8 | 30 |
| radio_sband | radio | 0.3 | 0 | 6 | 0 | 0 | 36 | 90 |
| antenna_big | extra | 0.4 | 0 | 1 | 0 | 0 | +20 | 40 |
| ground2 | extra (a service) | 0 | 0 | 0 | 0 | 0 | +18 | 100 |
| shielding | extra | 0.2 | 0 | 0 | 0 | 0 | 0 | 40 |

### 7.2 `level1.json`

| Key | Content |
|---|---|
| `goal_text`, `goal_data_type` | The mission and the data type that counts (`images`) |
| `bus` | The fixed CubeSat body: 1.3 kg, uses 2.4 W, costs $200k |
| `launch` | Rideshare, $120k |
| `limits` | `mass_kg` 4.0, `budget_k` 1000, `deadline_day` 180 |
| `orbit` | `period_min` 95, `eclipse_min` 35 (rough figures, to verify) |
| `slots` | Six slots: `solar`, `battery`, `instrument`, `radio`, `extra_a`, `extra_b`. Each has `label`, `category`, `required` |
| `schedule` | `seconds_per_day` 2.0, `post_build_days` 50, `retest_days` 10, `licence_days` 120, `staff_cost_k_per_day` 1.0, `slip_days` 30, `slip_fee_k` 60 |
| `requirements` | Six checks, see 8.2. Each has `id`, `kind`, `target`, `unit`, `hard`, `text`, `reason`, `tip`, `consequence` |
| `ops` | `weeks` 12, `seconds_per_week` 5.0, `storage_mb` 80, `goal_mb` 480, extra pass settings, `lowres_mult` 0.67, `brownout_loss` 0.25, `safe_mode_recharge_pct` 10, `max_drain_pct` 30 |
| `stars` | `partial_fraction` 0.6, `reserve_pct` 10 |
| `concept_chips` | Chips for the briefing: `group`, `label`, `state` (`chosen` or `locked`), `why` |

### 7.3 `events.json`

`{"events": [ ... ]}`. Each event: `id`, `when` (`test_lab` or `ops`), `week` (0 for test lab), `title`, `body`, `picture`, `choices`.
Each choice: `label`, `detail`, `effects`, `log`, and optionally `protect_part` with `log_protected`.
If the design contains `protect_part`, the choice has no effects and the protected log line is used.

Effect kinds:

| kind | Before launch | In orbit |
|---|---|---|
| `add_days` | Adds days to the schedule | Not used |
| `add_cost_k` | Adds cost | Takes money straight away |
| `mult_send` | Radio sends less for the whole mission | Same, from now on |
| `mult_make` | Instrument makes less | Same, from now on |
| `skip_week` | Not used | The next week runs in safe mode |
| `skip_send` | Not used | Nothing is sent in the next week |

Events in the file: `vibration_break` (test lab), `solar_storm` (week 4), `ground_silent` (week 8).

### 7.4 `puzzles.json`

`order` lists the puzzle ids in ladder order. Then one block per puzzle: `mass`, `power`, `link`, `time`. Each has `title`, `intro`, `lesson` and its own numbers. Section 12 describes each puzzle.

---

## 8. The rules (what `sim.gd` does)

### 8.1 Design numbers: `Sim.evaluate_design(level, parts, design, sched)`

`design` is `{slot_id: part_id or ""}`. `sched` is the schedule record from `Sim.new_schedule()`:
`day` (starts at 1), `retests`, `extra_days`, `extra_cost_k`, `send_mult`, `make_mult`.

| Output key | Formula |
|---|---|
| `mass_kg` | bus mass + sum of part masses |
| `power_gen_w` | sum of `power_gen_w` |
| `power_use_w` | bus use + sum of `power_use_w` |
| `power_spare_pct` | (gen - use) / gen x 100. It is -100 when there are no panels |
| `battery_wh` | sum of `battery_wh` |
| `eclipse_min_pct` | lowest battery level in eclipse: 100 x (1 - use x eclipse_min / 60 / battery_wh), never below 0. It is 0 with no battery |
| `make_mb_wk` | instrument `make_mb_wk` x `sched.make_mult` |
| `send_mb_wk` | sum of `send_mb_wk` x `sched.send_mult`. Zero if there is no radio |
| `data_useful` | true when the instrument's `data_type` equals the level's `goal_data_type` |
| `delivered_mb_wk` | the smaller of make and send. Zero if the data is not useful |
| `parts_cost_k` | sum of part costs |
| `launch_day` | the later of (day + post_build_days + retest_days x retests + extra_days) and (licence_days + 1) |
| `staff_cost_k` | staff cost per day x launch_day |
| `total_cost_k` | bus + launch + parts + staff + extra_cost_k |
| `reserve_pct` | (budget - total) / budget x 100 |
| `money_left_k` | budget - total |
| `missing` | labels of required slots that are empty |
| `part_ids` | the part ids fitted |

The clock matters because the staff are paid every day until launch. Building slowly eats the reserve and then the deadline.

### 8.2 Requirements: `Sim.check_requirements(level, ev)`

| id | kind | Passes when | Hard | Consequence if failed at launch |
|---|---|---|---|---|
| R1 | `mass_max` | mass_kg <= 4.0 | yes | Cannot launch at all |
| R2 | `delivered_min` | delivered_mb_wk >= 40 | no | Fewer photos reach the ground (this follows naturally in orbit) |
| R3 | `power_spare_min` | power_spare_pct >= 10 | no | If spare is below zero, the battery drains every week until empty |
| R4 | `budget_reserve_min` | reserve_pct >= 10 | no | Costs in orbit can take money below zero, which cancels the mission |
| R5 | `eclipse_min` | eclipse_min_pct >= 10 | no | Brownouts: 25% of each week's photos are lost. No battery at all: the satellite dies in week 1 |
| R6 | `launch_day_max` | launch_day <= 180 | no | The launch slips: $60k fee plus 30 days of staff, taken at release |

Returns one Dictionary per requirement: `id`, `text`, `passed`, `value`, `target`, `unit`, `hard`, `reason`, `tip`, `consequence`.
Comparisons use a tolerance of 0.0001, so a value that is exactly on the target passes.

- `Sim.readiness_pct(results)`: share of requirements passed, 0 to 100.
- `Sim.all_passed(results)`: true or false.
- `Sim.can_launch(ev, results)`: `{ok, reason}`. Not ok when a required slot is empty or a hard requirement fails.

### 8.3 Operations: `Sim.new_ops_state(...)` and `Sim.ops_week(level, ev, st, act)`

State keys: `week`, `battery_pct`, `stored_mb`, `delivered_mb`, `lost_mb`, `money_k`, `make_mult`, `send_mult`, `cooldown`, `passes_used`, `brownout_weeks`, `force_safe`, `force_skip_send`, `slipped`, `alive`, `ended`, `end_reason`.

`act` may hold three booleans: `safe_mode`, `lowres`, `extra_pass`.

One call advances one week, in this order:

1. If the mission has ended, nothing happens.
2. `week` goes up by 1.
3. Safe mode is on if the player chose it or an event forced it. Forced flags are used up.
4. Extra pass: happens only if asked for, the cooldown is 0, and the week is not safe mode or send-skipped. It costs $10k and sets the cooldown.
5. No battery fitted: the mission ends now with `end_reason = "no_battery"`.
6. Safe mode: nothing made, nothing sent, battery +10 points (up to 100).
7. Otherwise:
   - made = make_mb_wk x make_mult, x 0.67 in low-res mode, x 0.75 if `eclipse_min_pct` is below 10 (brownout).
   - send capacity = send_mb_wk x send_mult, x 1.5 with an extra pass, or 0 if send is skipped.
   - stored += made. sent = the smaller of stored and capacity. stored -= sent.
   - Anything above 80 MB of storage is lost and added to `lost_mb`.
   - delivered += sent, but only if the data is useful.
   - Battery: if power spare is below 0, it drops by the smaller of 30 and (2 x the shortfall percent). Otherwise +10 points.
8. Cooldown goes down by 1.
9. The mission ends if the battery reaches 0 (`battery_empty`), or money is below 0 (`out_of_money`), or the week is 12 (`complete`). Checked in that order.

It returns a summary of the week: `week`, `made`, `sent`, `lost`, `safe`, `extra_pass`, `brownout`.

Events in orbit: before the week that an event belongs to, call `Sim.apply_ops_choice(st, part_ids, event, index)`. It changes `st` and returns the log line.

### 8.4 Score: `Sim.score_mission(level, st, results)`

- Star 1 (goal): delivered_mb >= goal_mb (480).
- Star 2 (checks): every requirement passed at launch.
- Star 3 (budget): the mission ran to week 12 and money_k >= 10% of the budget.
- Grade: `success` with star 1. `partial` if delivered is at least 60% of the goal. Otherwise `failed`.

Returns `stars`, `grade`, `fraction`, `star_goal`, `star_checks`, `star_budget`.

### 8.5 Cause chain: `Sim.build_causes(ev, results, st)`

Returns a list of `{cause, effect, tip}`, most important first: how the mission ended early (if it did), a wrong instrument, each failed requirement with its consequence, and lost data. If nothing went wrong it returns one positive entry. The report shows the first three.

### 8.6 Reference outcomes (use these to test by hand)

> **Updated 14 Nov:** These numbers ignore the test-lab vibration event and predate the launch rule. With the launch rule, designs that fail two checks (readiness 67%) now fail at launch instead of flying: "without a battery" and "finished on day 131" both end at launch. With the vibration event, "Repair it" costs $20k, which leaves the second-ground-station design at 9.9% reserve (2 stars); "Fit the spare mount" keeps it at 3 stars when built early (for example by day 41).


Build finished on day 41 unless noted.

| Design | Result |
|---|---|
| Small panels, standard battery, camera, S-band | Mass 3.4, spare 11.4%, delivers 36 (fails R2 only), cost $781k, readiness 83% |
| Same, safe mode in the storm, wait at the ground fault | Delivers 360 of 480 MB, loses 220 MB, partial, 1 star |
| Same plus second ground station | Passes everything. Delivers 540 MB, $119k left, success, 3 stars |
| Same without a battery | Dies in week 1, failed, 0 stars |
| Small panels, standard battery, spectrometer, S-band, big antenna | Spare is -24%. Battery empty in week 5 |
| Large panels, standard battery, camera, S-band, big antenna, shielding | 4.3 kg. Cannot launch |
| First design but finished on day 131 | Launch day 181, fails R6, $69k left after the slip |

All six designs that pass every check, and the last workshop day on which they still pass:

| Panels | Battery | Radio | Extras | Mass | Last day |
|---|---|---|---|---|---|
| small | small | UHF | big antenna + ground2 | 3.35 | 125 |
| small | small | S-band | ground2 | 3.15 | 105 |
| small | standard | UHF | big antenna + ground2 | 3.60 | 110 |
| small | standard | S-band | ground2 | 3.40 | 90 |
| large | small | UHF | big antenna + ground2 | 3.65 | 75 |
| large | small | S-band | big antenna | 3.85 | 115 |

All use the camera. At 2 seconds per day, day 90 is three minutes of building. If testers find that too tight or too slack, change `seconds_per_day` in `level1.json`. Nothing else needs to change.

---

## 9. GameState reference (autoload)

| Member | Meaning |
|---|---|
| `parts`, `level`, `puzzles`, `events` | Loaded data |
| `design` | `{slot_id: part_id or ""}` |
| `sched` | Schedule record. The workshop adds to `sched["day"]` |
| `launch_eval`, `launch_results` | Frozen at launch by `begin_ops()` |
| `ops` | Ops state |
| `log_lines` | Event log for the report |
| `events_seen` | `{event_id: true}` so each event shows once |
| `puzzles_done`, `best_stars` | Saved progress |
| signal `design_changed` | Emitted by `set_slot`, `reset_mission`, `retry_mission` |
| `go(screen_id)` | Change screen |
| `reset_mission()` | New attempt, empty design |
| `retry_mission()` | New attempt, same parts |
| `evaluate()` | `Sim.evaluate_design` for the current design |
| `set_slot(slot_id, part_id)` | Returns false if the category is wrong or the part is already fitted. `""` empties the slot |
| `slot_category(slot_id)` | Category of a slot |
| `begin_ops()` | Freezes the design and creates `ops` |
| `add_log(line)` | Adds a report line |
| `puzzle_order()`, `is_puzzle_done(id)`, `is_puzzle_open(id)`, `mark_puzzle_done(id)` | Ladder progress |
| `record_stars(n)` | Keeps the best score and saves |
| `save_game()`, `load_save()`, `reset_progress()` | Save file `user://save.json` |

## 10. UI helper reference (`scripts/ui/ui.gd`)

| Function | Returns |
|---|---|
| `UI.label(text, size, color, wrap)` | Label. A wrapping label needs a width: set `custom_minimum_size.x` or put it in a container that gives it width |
| `UI.button(text, callable, min_width, primary)` | Styled Button |
| `UI.panel(border_color, margin)` | PanelContainer with the game's panel look |
| `UI.vbox(sep)`, `UI.hbox(sep)` | Containers |
| `UI.meter(width)`, `UI.set_meter(bar, percent, "green"/"yellow"/"red")` | ProgressBar |
| `UI.picture(path, size, fallback_text)` | TextureRect, or a labelled box if the file is missing |
| `UI.frames(folder, base, count, fps, loop)` | SpriteFrames from `base_01.png` onward, or null if frame 01 is missing |
| `UI.background(path)` | Full-screen background |
| `UI.money(k)` | `"$880k"`, `"$1.00M"` |
| `UI.box(fill, border, radius, border_width, margin)` | StyleBoxFlat |
| `UI.clear(node)` | Frees all children |
| Colours | `C_BG, C_PANEL, C_DEEP, C_OUTLINE, C_TEXT, C_MUTED, C_BORDER, C_HOVER, C_CYAN, C_GREEN, C_YELLOW, C_RED, C_ORANGE, C_DISABLED, C_DISABLED_BORDER` |

Bar colours on every screen follow one rule: red when the check fails, yellow when it passes but is within 10% of the target, green otherwise. Never rely on colour alone. Put the status icon or the words "OK", "Close", "Fail" next to each bar.

---

## 11. Shared UI pieces still to write

### 11.1 `scripts/ui/chrome.gd` (Bhairavi, Block 1)

Static helpers so every screen has the same frame.

- `static func top_bar(title: String, pills: Array) -> Control`: a 72 px bar across the top. Game name on the left, `title` in the centre, and one small rounded label per entry in `pills` on the right (for example `"Day 41 of 180"`, `"$219k left"`). Returns the bar. To update a pill, the screen keeps the bar and calls `set_pill(bar, index, text)`.
- `static func set_pill(bar: Control, index: int, text: String) -> void`.
- `static func tip_bar(text: String) -> Control`: a 58 px bar across the bottom with one line of tip text and the tag `PLACEHOLDER NUMBERS` on the right. `static func set_tip(bar, text)` updates it.
- Screens place content between y = 84 and y = 650.

### 11.2 `scripts/ui/event_card.gd` (Anusha, Block 3)

`extends Control`. A popup used by the test lab and by ops.

- `func setup(event: Dictionary) -> void`: call before adding it to the tree.
- `signal chosen(index: int)`.
- Builds: a full-screen `ColorRect` at 60% black that blocks clicks behind it (`mouse_filter = MOUSE_FILTER_STOP`), then a centred panel 600 wide with an orange border, the picture (`UI.picture(event["picture"], Vector2(480, 270), event["title"])`), the title, the body, and one button per choice showing `label` and `detail`.
- On a button press: emit `chosen(index)` and `queue_free()`.
- Usage:

```gdscript
var card: Control = EventCard.new()
card.call("setup", event)
add_child(card)
card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
var index: int = await card.chosen
```

The owner must stop its own clock while the card is open.

### 11.3 `scripts/ui/part_card.gd` and `drop_zone.gd` (Aadhav, Block 1)

- `part_card.gd`, `extends PanelContainer`. `func setup(part: Dictionary) -> void`. Shows icon (64 px), name, one line of numbers. `signal clicked(part_id)`. Overrides `_get_drag_data(at_position)` to return `{"type": "part", "id": part_id}` and calls `set_drag_preview()` with a small copy of the icon. Every child must have `mouse_filter = Control.MOUSE_FILTER_IGNORE`, or the card never receives the mouse.
- `drop_zone.gd`, `extends PanelContainer`. `var accept_category: String` (empty means any). `signal part_dropped(part_id)`. Overrides `_can_drop_data(at_position, data)` to return true when `data` is a Dictionary with `type == "part"` and the category fits. Overrides `_drop_data(at_position, data)` to emit `part_dropped`.
- **Click must work as well as drag.** Clicking a part card fits it. Build click first and add drag after. Drag and drop in a browser or on a trackpad is fiddly, and the demo must not depend on it.

---

## 12. Screen by screen

Each screen lists: owner, what it shows, exact behaviour, edge cases, and "done when".

### 12.1 `title` (Bhairavi). Exists.

Logo, tagline, buttons: **Play** (go `ladder`), **Skip to the mission** (`reset_mission()`, go `briefing`), **Run self-test**, **Reset progress**.
Keep Skip and Run self-test in the final build. Skip is the demo safety net.
Done when: restyled with `bg_title.png` if present, and all four buttons work.

### 12.2 `ladder` (Bhairavi, Block 3)

Shows the steps in a row or a staircase: one node per id in `GameState.puzzle_order()`, then a final node "Full mission".

- Node states: **done** (green tick), **open** (cyan, clickable), **locked** (grey, lock icon, shows "Finish the step before this one" in the tip bar when clicked).
- Use `GameState.is_puzzle_done(id)` and `is_puzzle_open(id)`. Titles come from `GameState.puzzles[id]["title"]`.
- Click an open or done puzzle: go `"puzzle_" + id`.
- The mission node is open when every puzzle in the order is done. Click: `reset_mission()`, go `briefing`.
- Shows best score: `GameState.best_stars` of 3.
- Back button to `title`.
- Edge case: `puzzle_order()` is empty (all puzzles cut). Then show only the mission node, open.

Done when: finishing Puzzle 1 unlocks Puzzle 2 after returning to the ladder, and progress survives closing the game.

### 12.3 Puzzle screens: shared behaviour

All four puzzles share this shape. Write Puzzle 1 first, then copy it.

- Top bar with the puzzle title. Left panel: `intro` text. Middle: the interactive part. Right panel: live result.
- The result updates on every change. Call the matching `Sim.puzzle_*` function and show its numbers.
- Under the result: the `reasons` list in red when it fails, or the `lesson` line in green when it passes.
- Button **Lock it in**: enabled only when `passed` is true. On press: `GameState.mark_puzzle_done(id)`, show the lesson for a moment, go `ladder`.
- Button **Back**: go `ladder` without marking.
- No timer, no tries limit. A puzzle cannot be lost, only solved.

### 12.4 `puzzle_mass` (Aadhav, Block 3)

`pz = GameState.puzzles["mass"]`. Call `Sim.puzzle_mass(pz, GameState.parts, selected_ids)`.

- Middle: a grid of toggle cards, one per id in `pz["bin"]` (8 parts). A card shows icon, name and mass. Use a `Button` with `toggle_mode = true`, or the part card with a selected border. Keep `selected_ids: Array` in the screen.
- Right: a mass meter (`mass_kg` of `limit_kg`) with the number, the small rocket picture, and a checklist of the four needs (camera, panels, battery, radio) with ticks.
- Start with nothing selected. It fails with four "You need..." reasons, which is the tutorial.
- Result keys: `mass_kg`, `limit_kg`, `passed`, `reasons`.
- Known answers: camera + small panels + standard battery + S-band = 3.4 kg, passes. Adding large panels and the big antenna = 4.1 kg, fails.

Done when: the two known answers behave as stated and Lock it in unlocks Puzzle 2.

### 12.5 `puzzle_power` (Bhairavi, Block 4)

`pz = GameState.puzzles["power"]`. Call `Sim.puzzle_power(pz, panel_w, battery_wh)`.

- Two `HSlider`s. Panel: `min_value = panel_min_w`, `max_value = panel_max_w`, `step = panel_step_w`, `value = panel_start_w`. Battery the same with the `battery_*` keys. Connect `value_changed`.
- Chart (`scripts/ui/line_chart.gd`, `extends Control`, custom minimum size about 720 x 260). In `_draw()`: dark background rect, a darker band from minute 0 to `eclipse_min` labelled "Eclipse", a dashed red line at `min_level_pct`, and the battery line through `result["points"]` (three `[minute, percent]` pairs). Map minute 0..period to x and percent 0..100 to y (100 at the top). Give it `func set_data(points: Array, eclipse_min: float, period_min: float, min_level: float)` which stores the values and calls `queue_redraw()`.
- Right: lowest level (`min_pct`), level at the end of the orbit (`end_pct`), mass (`mass_kg` of `mass_limit_kg`), reasons.
- The start values (8 W, 4 Wh) fail. 13 W and 10 Wh passes with a lowest level of 30% and 0.645 kg. 16 W and 8 Wh fails on mass.
- There are 12 passing slider combinations, so it is findable but not trivial.

Done when: moving a slider redraws the line immediately and the three known cases match.

### 12.6 `puzzle_link` (Aadhav, Block 3)

`pz = GameState.puzzles["link"]`. Call `Sim.puzzle_link(pz, selected_option_ids)`.

- Middle: a picture strip (satellite, dotted arc, ground station) and three bars: Made, Sent capacity, Delivered against `need_mb_wk`.
- Three toggle cards from `pz["options"]` showing `label` and `detail`.
- Right: spare mass used (`mass_kg` of `spare_mass_kg`), spare money used (`cost_k` of `spare_cost_k`), reasons.
- Result keys: `make`, `send`, `delivered`, `mass_kg`, `cost_k`, `passed`, `reasons`.
- Known answers: nothing selected fails (36). Big antenna alone fails on mass. Smaller photos alone fails (still 36, which is the lesson: the radio is the bottleneck). Second ground station alone passes (54).

### 12.7 `puzzle_time` (Bhairavi, Block 4)

`pz = GameState.puzzles["time"]`. Call `Sim.puzzle_time(pz, build_id, test_id, licence_start)`.

- Controls: two buttons for the build option, two for the test option (exactly one of each pair selected, show the selected one with the primary style), and an `HSlider` for the licence start day (`licence_start_min`, `_max`, `_step`, default `licence_start_default`). `licence_start` must be passed as `int(slider.value)`.
- Chart (`scripts/ui/gantt_chart.gd`, `extends Control`). In `_draw()`: one row per entry in `result["bars"]` (`label`, `start`, `end`), x scale 0 to 220 days, a vertical red line at `launch_day`. `func set_data(bars: Array, launch_day: int)` then `queue_redraw()`.
- Right: ready day (`finish_day`) against the launch day, cost (`cost_k`) against `cost_limit_k`, reasons.
- The default (normal, full, licence on day 60) fails both ways. Normal, full, licence on day 10 passes exactly on the limit ($360k, ready day 150). Rushing the build never passes, because the licence is the bottleneck. That is the lesson.

### 12.8 `briefing` (Bhairavi, Block 1)

Three panels side by side.

1. **The mission**: `level["name"]`, the default CubeSat picture (`res://art/modules/cubesat_3u.png`), `level["goal_text"]`, and the limits in words: 4.0 kg, $1.00M, launch by day 180.
2. **Your concept**: group `level["concept_chips"]` by `group`. A `chosen` chip is filled. A `locked` chip is grey with the lock icon. Clicking a locked chip puts its `why` in the tip bar. Chips do not change the game in Level 1. They are there to show the reasoning.
3. **You must hit**: the `text` of each entry in `level["requirements"]`.

Button **Start building**: go `workshop`. Do not reset the mission here. The title and the ladder already did, and Retry must keep the parts.

### 12.9 `workshop` (Aadhav, Blocks 1 and 2). The main screen.

Layout on 1280 x 720:

| Area | Position | Content |
|---|---|---|
| Top bar | y 0 to 72 | Title "Workshop", pills: `Day N of 180`, money left |
| Left panel | x 20, y 88, 290 x 420 | "On your satellite": six slot rows |
| Centre | x 326, y 88, 600 x 420 | The default CubeSat picture, as a drop zone |
| Right panel | x 942, y 88, 318 x 420 | Six bars and the readiness meter |
| Tray | x 20, y 520, 1240 x 110 | Part cards in a horizontal `ScrollContainer`, and the **Test it** button |
| Tip bar | bottom | Tip text |

Behaviour:

1. **Tray.** One part card per entry in `GameState.parts`, in file order.
2. **Fitting a part** (click or drop on the centre): find the slot. For `solar`, `battery`, `instrument`, `radio` it is the slot with that id, and the new part replaces the old one. For `extra` use `extra_a` if empty, else `extra_b` if empty, else show "Both extra slots are full. Remove one first." in the tip bar. Then call `GameState.set_slot(slot_id, part_id)`. If it returns false, show "That part is already fitted."
3. **Slot rows.** Each shows the slot label and the part name, or "empty" in yellow for required slots and grey for optional ones. A small remove button calls `GameState.set_slot(slot_id, "")`. Each row can also be a drop zone with `accept_category` set to the slot's category.
4. **Refresh.** Connect `GameState.design_changed` to `_refresh()`. Also refresh once a day when the clock ticks. `_refresh()` calls `GameState.evaluate()` and `Sim.check_requirements(GameState.level, ev)` and updates everything. Disconnect is automatic when the screen is freed, as long as you connect with a method of the screen.
5. **Bars** (value, fill percent, pass rule comes from the matching requirement):

| Bar | Text | Fill percent | Requirement |
|---|---|---|---|
| Mass | `3.4 kg of 4.0 kg` | mass / limit x 100 | R1 |
| Power | `12.4 W used of 14.0 W` | use / gen x 100 (100 if gen is 0) | R3 |
| Battery in eclipse | `lowest 82%` | eclipse_min_pct | R5 |
| Data | `36 of 40 MB/wk delivered (makes 60, sends 36)` | delivered / target x 100 | R2 |
| Budget | `$781k of $1.00M` | total / budget x 100 | R4 |
| Time | `launch day 121 of 180` | launch_day / 180 x 100 | R6 |

   Colour: red if the requirement fails, yellow if it passes within 10% of its target, else green. Readiness meter: `Sim.readiness_pct(results)` with the number.
6. **Clock.** In `_process(delta)`: if not paused, add `delta` to an accumulator. While the accumulator is at least `seconds_per_day`, subtract it and add 1 to `GameState.sched["day"]`, then refresh. Stop counting at day 250. Use `int(GameState.sched["day"])` when reading it.
7. **Pause.** A pause button stops the clock and dims the tray. The clock also stops while any popup is open.
8. **Why red?** A button that lists, for each failing requirement, its `reason` and `tip` in a small popup. The same text appears in the tip bar when the player hovers a red bar.
9. **Test it.** Always enabled. Goes to `test_lab`.
10. **Coming back from the test lab** re-enters this screen fresh. Everything is read from `GameState`, so the design and the day are still there. Do not store game state in the screen.

Edge cases: empty design (bars show zeros, power bar red, no crash), no panels (gen 0: do not divide by zero in the fill percent), all slots full, clicking a part that is already fitted.

Done when: you can build each of the six winning designs from section 8.6, the bars match the reference numbers for the first row of that section, and the day counter changes the budget bar while you watch.

### 12.10 `test_lab` (Anusha, Block 2)

> **Updated 14 Nov:** The Fix it button now states the real delay, worked out by the rules ("launch N days later" or "no launch delay yet", because the licence sets the earliest launch day). The vibration card has three choices.


On entry:

1. If `vibration_break` is not in `GameState.events_seen`: mark it seen, show the event card, then `var line: String = Sim.apply_prelaunch_choice(GameState.sched, ev["part_ids"], event, index)` and `GameState.add_log(line)`. Get the event with `Data.events_for(GameState.events, "test_lab", 0)`. Until the event card exists (Block 3), skip this step.
2. `ev = GameState.evaluate()`, `results = Sim.check_requirements(...)`, `launch = Sim.can_launch(ev, results)`.

Shows: a table with one row per result (`id`, `text`, value with unit, target, status icon and the word PASS or FAIL). For each failed row, a card with its `reason` and `tip`. The readiness meter with a marker at 80%.

Format values by unit: `kg` and `%` with one decimal, `MB/wk` and `day` as whole numbers.

Buttons:

- **Back to workshop**: if any requirement failed, add 1 to `GameState.sched["retests"]` first (each failed test costs 10 days). Then go `workshop`. Show this cost on the button: "Fix it (costs 10 days)".
- **Launch** (all passed): go `launch`.
- **Launch anyway** (some failed, `launch["ok"]` is true): show a confirm popup listing the `consequence` of each failed requirement, then go `launch`.
- If `launch["ok"]` is false: the launch button is disabled and `launch["reason"]` is shown beside it.

Done when: the reference design fails R2 only, the heavy design cannot launch, and going back adds 10 days to the launch day.

### 12.11 `launch` (Anusha, Block 2)

> **Updated 14 Nov:** The scene now plays the sim's launch outcome: success reaches orbit; failure climbs only as far as readiness allows and goes to the report. Countdown beeps, flame and smoke particles, camera pull-back.


About 10 seconds, no input needed, with a **Skip** button.

1. First line of `_ready()`: `GameState.begin_ops()`. Doing it first means Skip is always safe.
2. Background `bg_launch_pad.png`. Rocket `rocket_medium.png` standing at the pad. Flame as an `AnimatedSprite2D` child of the rocket holder, using `UI.frames("res://art/animations/exhaust_flame", "exhaust_flame", 6, 12.0, true)`. If `frames` returns null, show nothing for the flame.
3. Sequence with one `Tween` made by `create_tween()` on the screen: countdown 3, 2, 1 (one second each), flame on, rocket moves up and off the top over 4 seconds, fade to `bg_earth_orbit.png`, play `cubesat_open` once at about 4 frames per second (4 frames at 12 fps is too quick to see), show "Satellite released".
4. If `GameState.ops["slipped"]` is true, show "You missed your slot. Rebooking cost $90k." before the countdown.
5. At the end, or on Skip: go `ops`. Guard against going twice with a boolean.

An `AnimatedSprite2D` is a 2D node. It can be a child of a Control and is positioned in that Control's local pixels. Set `sprite.sprite_frames = sf` and then `sprite.play("exhaust_flame")`.

### 12.12 `ops` (Anusha, Blocks 2 and 3)

Layout: Earth in the middle (`earth_large.png`, about 440 px), a dashed orbit circle, the satellite marker moving along it, the ground station bottom left. Left panel: battery, stored data (of 80 MB), delivered (of 480 MB), money. Right panel: actions. Top bar: `Week N of 12`.

Loop:

1. A week timer counts `seconds_per_week` (5 s), divided by the speed (1 or 2). Pause stops it.
2. When the timer fires, and before running the week: `next_week = int(GameState.ops["week"]) + 1`. For each event in `Data.events_for(GameState.events, "ops", next_week)` not yet seen: mark seen, pause, show the card, `line = Sim.apply_ops_choice(GameState.ops, GameState.launch_eval["part_ids"], event, index)`, `GameState.add_log(line)`, resume.
3. Run the week: `summary = Sim.ops_week(GameState.level, GameState.launch_eval, GameState.ops, act)` with `act = {"safe_mode": safe_on, "lowres": lowres_on, "extra_pass": pass_queued}`. Then set `pass_queued = false`.
4. Update the panels and write one line under them: "Week 5: made 60 MB, sent 36 MB, lost 24 MB".
5. If `GameState.ops["ended"]`: stop the timer, wait about 1.5 seconds, compute `score = Sim.score_mission(GameState.level, GameState.ops, GameState.launch_results)`, call `GameState.record_stars(int(score["stars"]))`, go `report`.

Actions:

- **Safe mode** (toggle). No photos, nothing sent, battery recovers.
- **Smaller photos** (toggle). Makes 33% less data, so storage fills more slowly.
- **Buy an extra ground pass ($10k)**. Sets `pass_queued = true` for the coming week. Disabled when `int(GameState.ops["cooldown"]) > 0`, when already queued, or when `float(GameState.ops["money_k"])` is below 10. Show the cooldown on the button.
- **Pause**, **1x**, **2x**.

Visuals (all optional polish, none may block the loop):

- Marker position: `centre + Vector2(cos(angle), sin(angle)) * radius`, with `angle += delta * speed` in `_process`. One lap per week looks right.
- `signal_pulse` plays at the marker for a second when `summary["sent"]` is above 0.
- `warning_light_blink` shows while the battery is below 30% or `summary["brownout"]` is true.
- `sparks_burst` plays once when the storm damages the camera.
- If the mission ends early, dim the marker (`modulate = Color(0.4, 0.4, 0.45)`).

Done when: the three flown reference outcomes in section 8.6 match exactly.

### 12.13 `report` (Bhairavi, Block 2)

Reads only from `GameState`. Recompute, do not pass data between screens:

```gdscript
var score: Dictionary = Sim.score_mission(GameState.level, GameState.ops, GameState.launch_results)
var causes: Array = Sim.build_causes(GameState.launch_eval, GameState.launch_results, GameState.ops)
```

Shows:

- Title by grade: "Mission success", "Partial success", "Mission failed".
- Three stars (`icon_star.png`, tinted grey with `modulate` for an empty star), each with its label: goal reached, all checks passed, finished with 10% in reserve. Use `star_goal`, `star_checks`, `star_budget`.
- Numbers: delivered of goal, lost, money left (`UI.money`), weeks flown of 12.
- **Why it happened**: the first three entries of `causes` as cards: cause, arrow, effect, then the tip underneath.
- **What happened on the way**: `GameState.log_lines`.
- A panel "Compare with a real mission". Until verified data exists it says "Real mission figures will be added from verified NASA data." Do not invent numbers.
- Buttons: **Retry with changes** (`GameState.retry_mission()`, go `workshop`), **New design** (`reset_mission()`, go `briefing`), **Title**.

Edge case: the report opened with an empty `ops` (for example from the stub flow). Check `GameState.ops.is_empty()` and show "No mission flown yet" with a Title button.

---

## 13. Art

- Files arrive from Aditi (animations) and Tanvi (stills). Bhairavi copies them into `art/` with the exact names from the art tracker and commits them together with the `.import` files Godot creates next to them.
- Code never fails on missing art. `UI.picture` and `UI.frames` handle it.
- Never list a folder at run time to find frames. It works in the editor and breaks in an exported game. Build the paths from numbers, as `UI.frames` does.

| Art | Used in | Shown at about |
|---|---|---|
| `art/modules/cubesat_3u.png` | briefing, workshop centre | 560 x 187 |
| `art/modules/spacecraft_marker.png` | ops | 64 x 64 |
| `art/modules/rocket_small.png` | puzzle_mass | 110 x 330 |
| `art/modules/rocket_medium.png` | launch | 150 x 450 |
| `art/modules/ground_station.png` | ops, puzzle_link | 100 x 100 |
| `art/modules/part_*.png`, `art/icons/part_camera.png`, `part_spectrometer.png` | part cards | 64 x 64 |
| `art/icons/icon_mass, icon_power, icon_budget, icon_data, icon_comms, icon_time, icon_health` | bars | 24 x 24 |
| `art/icons/icon_status_green, _yellow, _red` | bars, test table | 22 x 22 |
| `art/icons/icon_locked.png` | ladder, briefing | 22 x 22 |
| `art/icons/icon_star.png` | report, ladder | 54 x 54 |
| `art/icons/icon_sun.png` | puzzle_power | 48 x 48 |
| `art/backgrounds/bg_space.png` | every screen (loaded by `main.gd`) | full screen |
| `art/backgrounds/bg_earth_orbit.png`, `earth_large.png` | ops, launch end | full screen, 440 |
| `art/backgrounds/bg_launch_pad.png` | launch | full screen |
| `art/ui/ui_logo.png` | title | 640 x 240 |
| `art/events/event_*.png` | event card | 480 x 270 |
| `art/animations/exhaust_flame` (6 frames, loop) | launch | under the rocket |
| `art/animations/cubesat_open` (4 frames, once) | launch end | centre |
| `art/animations/signal_pulse` (6, loop) | ops | at the marker |
| `art/animations/sparks_burst` (6, once) | ops | at the marker |
| `art/animations/warning_light_blink` (2, loop, 2 fps) | ops | beside the battery bar |

Two things for Amudha and the animators:

1. Buttons, panels, meters, the tooltip box and the event card frame are drawn by code. The art files `ui_button_*`, `ui_panel`, `ui_meter_*`, `ui_tooltip_bg` and `ui_card_frame` are therefore optional. That takes a little under an hour off Tanvi's must-do list by my rough estimate.
2. The mission uses three events: vibration break, solar storm, ground station silent. The solar storm picture was not on the earlier list, and the licence delay, launch moved up and compliance pictures are not used in Level 1. The art tracker that comes with this document has been updated to match.

---

## 14. Sound

> **Updated 14 Nov:** Done, generated in code (scripts/ui/sfx.gd). No audio files, so nothing to license.


Optional, last. If there is time: one click sound for buttons, one rumble for launch, one chime for a star. Use `AudioStreamPlayer` nodes that are children of the screen. Credit every sound in the credits file with its licence. A browser will not play sound until the player has clicked once, so do not rely on sound at start-up.

---

## 15. Saving

`user://save.json` holds `puzzles_done` and `best_stars`. `GameState` reads it at start and writes it when a puzzle is finished or a score improves. A missing or broken file means a fresh start, never a crash. **Reset progress** on the title clears it. In the web build, `user://` is browser storage, which should persist between visits on the same browser, but treat that as unconfirmed.

---

## 16. Export (Anusha, Block 5)

> **Updated 14 Nov:** Done. Preset in docs/export_presets.web.cfg, steps in docs/WEB_EXPORT.md, hosted on GitHub Pages.


Do a first web export at the end of Block 2, not at the end of the day. Export problems found early are small.

1. Editor > Manage Export Templates: download the templates for your exact Godot version. This needs internet and takes a while, so do it in Block 0.
2. Project > Export > Add > Web. Also add a Windows Desktop preset (and macOS or Linux if a laptop used for the demo needs it).
3. In the preset, Resources tab, add `*.json` to "Filters to export non-resource files/folders". I am not certain Godot packs the data files without this, so add it and stay safe.
4. Export the web build to a folder outside the project (for example `build/web/`, which git ignores).
5. A web build does not run by double-clicking `index.html`. Serve the folder (for example `python -m http.server` inside it, then open `http://localhost:8000`) or upload it to a host such as itch.io or GitHub Pages. Check the current Godot web export docs for the options your version needs, especially the threads setting, which changes what the host must support.
6. Play the whole game in the exported build once. Check: data loads (the title self-test passes), art shows, save works, drag or click fitting works.
7. Keep the desktop export as the backup for the demo and the video. If the web build misbehaves on Sunday, record from the desktop build.

`export_presets.cfg` is ignored by git in the starter. Only Anusha exports, so that is fine.

---

## 17. Git

- `main` always runs. Only Anusha merges into it.
- Each person works on their own branch: `anusha`, `aadhav`, `bhairavi`. Commit small and often. Push at least at the end of every block.
- Before starting a block: pull `main` into your branch.
- Because each of you owns different files, merges should be clean. If git reports a conflict in a file you do not own, stop and ask the owner.
- Commit: `.gd`, `.json`, `.tscn`, `project.godot`, art `.png` files and their `.import` files. If your Godot version creates `.uid` files next to scripts, commit those too.
- Never commit: the `.godot/` folder, builds, zips. The `.gitignore` already covers them.
- Run the self-test before every push that touches `sim.gd` or `data/`.
- At the end of Block 5, tag the commit (`git tag freeze`) and copy the project folder to a USB stick or a cloud drive.

---

## 18. Testing

> **Updated 14 Nov:** Also run tests/truck_tests.gd and tests/craft_tests.gd. The self-test now includes the launch rule and the spare-mount choice.


**Self-test.** `tests/sim_tests.gd` has about 70 checks on the rules and all four puzzles. Run it from the title screen or the terminal. If you change a number in `data/` on purpose, the matching expected values in the test must change in the same commit.

**Manual test script (run it at the end of Blocks 2, 4 and 5, in the editor and in the exported build).**

1. Title: self-test passes.
2. Skip to the mission. Briefing shows three panels. Click a locked chip: a reason appears.
3. Workshop: fit small panels, standard battery, camera, S-band. Bars read 3.4 kg, 12.4 of 14.0 W, delivered 36 of 40 (red).
4. Try to fit the camera twice: refused with a message. Fill both extra slots and try a third: refused.
5. Wait and watch the day and the budget move. Pause stops them.
6. Test it: the vibration card shows once. R2 fails. Go back: launch day is 10 later.
7. Add the second ground station. Test: all pass. Launch.
8. Launch scene plays. Skip works on a second run.
9. Ops: week counter advances, storm card at week 4, ground card at week 8, extra pass has a cooldown, 2x speed works.
10. Report: stars, numbers, three causes, log lines. Retry keeps the parts. New design clears them.
11. Remove the battery and launch anyway: the satellite dies in week 1 and the report says why.
12. Build a 4.3 kg design: launch is blocked with the reason.
13. Ladder: Puzzle 2 is locked until Puzzle 1 is done. Close and reopen the game: progress is kept.
14. Resize the window: the screen scales with black bars and nothing is cut off.
15. Play the whole thing using only clicks, no drags.

---

## 19. Godot 4 traps (read before coding, paste into your AI)

1. **JSON numbers are floats.** `120` loads as `120.0`. Use `int()` before using a value as an index, a day count or in `range()`.
2. **Dictionary values are untyped.** `var x := some_dict["key"]` does not compile, because the type cannot be inferred. Write `var x: float = float(some_dict["key"])`.
3. **Arrays from JSON are plain `Array`.** Do not declare `Array[Dictionary]` or `Array[String]` for anything that came from JSON or from Sim. Assigning a plain array to a typed one is an error.
4. **`min` and `max` return untyped values.** Use `minf`, `maxf`, `mini`, `maxi`, `clampf`, `clampi`.
5. **Never compare floats with `==`.** Use the Sim results (`passed`) and never redo a comparison in a screen.
6. **Integer division.** `5 / 2` is `2`. Write `5.0 / 2.0` when you want `2.5`.
7. **A wrapping Label with no width becomes a one-letter-wide column.** Give it `custom_minimum_size.x` or a parent that sets its width.
8. **Mouse filters.** A Control with `MOUSE_FILTER_STOP` (the default for most) eats clicks meant for what is behind it. Labels and pictures inside a clickable or draggable card must be `MOUSE_FILTER_IGNORE`. A full-screen overlay must be `STOP` so clicks do not leak to the screen behind a popup.
9. **Anchors.** A Control added to a plain Control parent has size zero until you call `set_anchors_and_offsets_preset(...)` or put it in a container. Containers ignore the position and anchors of their children.
10. **Nodes are not ready in `_init`.** Build children in `_ready()`.
11. **`queue_free()` is delayed.** The node still exists until the end of the frame. Do not touch a screen after calling `GameState.go()`. Return straight away.
12. **Signals and freed nodes.** Connect signals to methods of the screen itself (`_on_x`), so the connection goes away with the screen. Do not connect lambdas that capture nodes to autoload signals.
13. **`await` and screen changes.** After `await`, the screen may be gone. After every `await` in a screen, check `if not is_inside_tree(): return`.
14. **Timers and tweens** must belong to the screen (`add_child(timer)`, `create_tween()` called on the screen). Do not use `get_tree().create_timer()` for anything that changes the game state, because it keeps running after the screen changes.
15. **`_process` keeps running while a popup is open.** Guard clocks with a `_paused` flag.
16. **Do not use `get_tree().paused`.** It also freezes the popup unless process modes are set. A flag is simpler.
17. **`load()` of a missing file prints an error and returns null.** Check `ResourceLoader.exists(path)` first, or use the UI helpers.
18. **No folder listing at run time** (`DirAccess`) for resources. It breaks in exports.
19. **File names are case sensitive in exports and on Linux.** `Rocket_Small.png` is not `rocket_small.png`. All lowercase with underscores.
20. **`String % value`.** `"%d" % x` needs an int, so write `"%d" % int(x)`. With two or more values use an array: `"%d of %d" % [a, b]`.
21. **`Button.pressed` is a signal in Godot 4**, and the toggle state is `button_pressed`. Tutorials for Godot 3 are wrong about this and about much else. Tell your AI "Godot 4, not Godot 3".
22. **Do not rename or move files outside the Godot editor** once they are imported, or paths and import data go stale.
23. **Do not use `class_name`** in this project. Use `preload`.
24. **Do not name a variable after a built-in** (`name`, `position`, `size`, `scale`, `owner`, `process`, `ready`) inside a node script. It shadows the node's own property.
25. **`_draw()` only runs when asked.** Call `queue_redraw()` after changing chart data.
26. **Sliders emit `value_changed` when you set `value` in code.** Set the range first, then the value, then connect the signal. Otherwise the handler runs before the screen is built.
27. **Nothing random.** Do not call `randf()` or `randi()` in game rules. The demo must be repeatable.
28. **Tabs for indentation** in GDScript. Mixing tabs and spaces is a parse error.

---

## 20. Plan by block

Amudha sets the clock times. Each block ends with everyone pushing, Anusha merging, and one play-through.

| Block | Anusha | Aadhav | Bhairavi | End check |
|---|---|---|---|---|
| 0 Setup | Repo, open starter, run self-test, fix anything red, download export templates, confirm Godot version | Clone, run, read sections 6, 11.3, 12.9, 19 | Clone, run, read sections 6, 10, 11.1, 12, 19. Import the art test pack | Everyone sees the title and a passing self-test |
| 1 Core | `test_lab` (table and buttons, no event card yet) | `part_card`, `drop_zone`, `workshop` with click-to-fit and live bars | `chrome.gd`, `briefing`, restyle `title` | Build a design in the workshop and see pass or fail in the test lab |
| 2 Loop | `launch` (simple version), `ops` (loop without events), first web export | Workshop clock, pause, Why red, drag and drop | `report` | **Cut line.** One full mission from title to report. Reference outcomes match |
| 3 Puzzles | `event_card`, events in test lab and ops | `puzzle_mass`, then `puzzle_link` | `ladder`, art import | Puzzles 1 and 3 playable from the ladder |
| 4 More | Ops visuals (marker, pulse, warning), launch animation polish | Workshop polish, hover tips, help text | `puzzle_power` with `line_chart`, `puzzle_time` with `gantt_chart` | All four puzzles, if on schedule |
| 5 Freeze | Bugs only, exports, tag, backup, record a rough run | Bugs only. Run the manual test script | Bugs only. Final art swap. Run the manual test script in the export | Frozen build that passes the manual script |

Who waits for whom:

- Nobody waits for art. Placeholders are automatic.
- Aadhav's workshop needs nothing that is not already in the starter.
- Bhairavi's report needs a flown mission to look at. Until `ops` exists she can test it with a temporary button that fills `GameState` by calling `begin_ops()` and `Sim.ops_week` twelve times. Remove the button afterwards.
- The event card (Block 3) is the only shared piece that two screens wait for, and both work without it.

Sunday: no new features. Record the video from the frozen build, and fix only what breaks the recording.

---

## 21. Definition of done

- The self-test passes in the editor and in the exported build.
- The manual test script passes in the exported build.
- The game can be finished from title to report with clicks only.
- No red errors in the Godot Output or Debugger panel during a full play-through. Yellow warnings are acceptable.
- Every failure the player can reach is explained in plain words, in the test lab or the report.
- No number is presented as a real NASA figure unless it has a verified source.
- The credits file lists every tool, library, sound and reference.

**Demo path for the video (about three minutes).** Title. Puzzle 1 solved quickly. Skip to the mission. Build the reference design. Test: R2 fails, read the reason. Launch anyway. Solar storm: keep imaging with no shielding. Report: partial success and the cause chain. Retry with changes: add the second ground station. Test: all pass. Launch. Report: three stars. This shows failure, explanation and improvement, which is the point of the challenge.

---

## 22. Godot names used, to confirm in the docs

These were written from memory and not run. Each is standard Godot 4 as far as I know. Check any that the editor underlines.

- Global: `preload`, `load`, `str`, `int`, `float`, `bool`, `typeof`, `TYPE_DICTIONARY`, `minf`, `maxf`, `mini`, `maxi`, `clampf`, `absf`, `round`, `range`, `push_error`, `push_warning`, `OK`.
- `FileAccess`: `file_exists`, `open`, `FileAccess.READ`, `FileAccess.WRITE`, `get_as_text`, `store_string`, `close`.
- `JSON`: `new`, `parse`, `data`, `get_error_line`, `get_error_message`, `JSON.stringify`.
- `ResourceLoader.exists`. `GDScript.new()` on a loaded script.
- `SceneTree`: a script that `extends SceneTree` with `_init()` and `quit(code)`, run with `--headless --script`.
- `Node`: `add_child`, `remove_child`, `queue_free`, `get_children`, `call`, `call_deferred`, `set`, `is_inside_tree`, `create_tween`.
- `Control`: `set_anchors_and_offsets_preset`, `Control.PRESET_FULL_RECT`, `custom_minimum_size`, `size_flags_horizontal`, `Control.SIZE_EXPAND_FILL`, `mouse_filter`, `MOUSE_FILTER_IGNORE`, `MOUSE_FILTER_STOP`, `focus_mode`, `FOCUS_NONE`, `add_theme_font_size_override`, `add_theme_color_override`, `add_theme_stylebox_override`, `add_theme_constant_override`, `modulate`, `queue_redraw`, `_draw`, `draw_rect`, `draw_line`, `draw_polyline`, `draw_string`, `_get_drag_data`, `_can_drop_data`, `_drop_data`, `set_drag_preview`.
- `Label`: `text`, `autowrap_mode`, `TextServer.AUTOWRAP_WORD_SMART`, `horizontal_alignment`, `vertical_alignment`, `HORIZONTAL_ALIGNMENT_CENTER`, `VERTICAL_ALIGNMENT_CENTER`.
- `Button`: `text`, `pressed` (signal), `disabled`, `toggle_mode`, `button_pressed`, `toggled` (signal). Theme names `normal`, `hover`, `pressed`, `disabled`, `font_color`, `font_hover_color`, `font_pressed_color`, `font_disabled_color`, `font_size`.
- `StyleBoxFlat`: `bg_color`, `border_color`, `set_border_width_all`, `set_corner_radius_all`, `set_content_margin_all`.
- `PanelContainer` (theme name `panel`), `VBoxContainer`, `HBoxContainer` (theme constant `separation`, `alignment`, `BoxContainer.ALIGNMENT_CENTER`), `CenterContainer`, `ScrollContainer`, `GridContainer` (`columns`), `ColorRect` (`color`).
- `ProgressBar`: `min_value`, `max_value`, `value`, `show_percentage`. Theme names `background`, `fill`.
- `HSlider`: `min_value`, `max_value`, `step`, `value`, `value_changed` (signal).
- `TextureRect`: `texture`, `expand_mode`, `TextureRect.EXPAND_IGNORE_SIZE`, `stretch_mode`, `STRETCH_KEEP_ASPECT_CENTERED`, `STRETCH_KEEP_ASPECT_COVERED`.
- `SpriteFrames`: `has_animation`, `add_animation`, `set_animation_speed`, `set_animation_loop`, `add_frame`. `AnimatedSprite2D`: `sprite_frames`, `play`, `animation_finished` (signal).
- `Tween`: `tween_property`, `tween_interval`, `tween_callback`, `finished` (signal). `Timer`: `wait_time`, `one_shot`, `start`, `stop`, `timeout` (signal).
- `Color`: `Color(r, g, b)`, `lightened`. `Vector2`. `String`: `ends_with`, `get_file`, `join`. `PackedStringArray(array)`.
- Project settings keys in section 3.

---

## 23. Prompts for your AI assistant

Paste this block first, every time, followed by the files named in it.

```
You are helping build one screen of a Godot 4 game in GDScript. This is Godot 4, not Godot 3.
I will paste: the spec section for my screen, and the files sim.gd, game_state.gd, ui.gd and title.gd.

Hard rules:
- Write ONE file: scripts/screens/<id>.gd. It extends Control and builds all nodes in _ready(). No .tscn.
- Do not change or re-implement sim.gd, game_state.gd, data.gd, ui.gd or main.gd. If something is
  missing from them, tell me what function you need instead of writing around it.
- All game numbers come from Sim functions or GameState. No game maths and no magic numbers in the screen.
- Use const UI = preload("res://scripts/ui/ui.gd") and const Sim = preload("res://scripts/core/sim.gd").
  Do not use class_name.
- Change screen only with GameState.go("<id>"), then return.
- Every variable has an explicit type. Never use := with a value read from a Dictionary or Array.
  Wrap Dictionary values with float(), int(), str() or bool().
- Arrays that come from JSON or Sim are plain Array, never Array[Type].
- Use minf, maxf, mini, maxi, clampf. Use tabs for indentation.
- Missing art must not break the screen: use UI.picture(path, size, fallback_text) and UI.frames(...).
- Timers and tweens are children of the screen. After any await, check is_inside_tree() before continuing.
- No randomness.
- Use only Godot 4 built-in classes. If you are not sure a method or property exists in Godot 4,
  say so and name the docs page to check. Do not invent API names.
Return the complete file, then a short list of anything I should verify in the Godot docs.
```

Then add the task, for example:

```
Task: write scripts/screens/puzzle_mass.gd following spec sections 12.3 and 12.4 (pasted below).
Done when: selecting camera_std, solar_small, battery_std and radio_sband shows 3.4 kg and passes.
```

When the AI's code shows an error in Godot, paste the exact error line and the function back to it. Do not let it rewrite files it was told not to touch.

---

## 24. Open items

> **Updated 14 Nov:** Still open: verify the craft table and the truck figures against primary sources before presenting them; art from Tanvi and Aditi.


| Item | Who |
|---|---|
| Agree one Godot 4 version, and confirm the starter opens and the self-test passes | Anusha, Block 0 |
| Replace placeholder numbers with verified ones, with sources, and update the tests | Anusha, when data is confirmed |
| Verify orbit period, eclipse time and any margin rules before describing them as real | Anusha, Amudha |
| Confirm the submission deadline in your time zone, the submission steps, and what pre-built work is allowed | Amudha |
| Decide whether the web build or the desktop build is the one submitted | Anusha, end of Block 2 |
| Levels 2 and 3 | Not in scope. The ladder can show them as locked cards if there is time |
