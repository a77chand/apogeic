# AP0GEIC 11

**Design it. Launch it. Learn.** A space mission design game for the NASA Space Apps Challenge 2026 (challenge: *Space Mission Design Game*), by team **Nebula Forge**.

You design a spacecraft, launch it, and keep it working in orbit. Every part you pick trades mass, power, data, money and time against the others, and every mission is based on a real spaceflight, so you see the same trade-offs real engineers faced and what happened when they got them wrong.

**Play it in your browser (no install):** https://a77chand.github.io/apogeic-game/
Judges: press **Judge demo** on the start page for a 5-minute tour with everything unlocked.

One-page summary: [`docs/SUBMISSION.md`](docs/SUBMISSION.md) · Sources: [`docs/CREDITS.md`](docs/CREDITS.md) and the in-game **Resources and sources** panel.

Built with Godot 4.7 (standard build) and GDScript, using the Compatibility renderer so it runs as a web (HTML5) export.

## What's in the game

**Training: four short puzzles**, one idea each
1. **Mass:** pack a satellite into a rocket slot.
2. **Power:** survive the dark part of every orbit.
3. **Data link:** the slowest step sets the pace.
4. **Budget and time:** plan the year, then play it and survive real surprises.

Puzzles 1, 2 and 4 end with a short animated simulation of what really happens to your design.

**20 missions, each based on a real spaceflight**
- From the USA, the USSR/Russia, China, India, Europe, Japan, the UK, Denmark and commercial operators (Sputnik 1, Explorer 1, Dong Fang Hong 1, Aryabhata, Chandrayaan-1, Hitomi, TROPICS and more). Each shows "Based on mission ___", the real story and its lesson, and a cited source.
- Every mission has its **own spacecraft type** (CubeSat sizes, or a historical satellite that was not a CubeSat), its own instrument, parts, orbit and targets, so **no two missions have the same best design**.
- Each mission is paired with **the real rocket it flew on**, drawn on its card.
- In nine missions, one decision option is **what the real team actually did**, and the game says so after you choose.
- A full mission runs through: briefing, workshop, test lab, launch (it can fail at max-Q, second stage or separation), operations, and a report that explains why it went right or wrong.

**Decisions under time pressure**
- Event cards give 30 seconds, a free clue, and paid expert advice (250 star dust). If time runs out there is a penalty.
- After each choice the game says whether it was optimal, fair or costly, and why.

**Progress**
- One star opens the next mission. Every 7 missions is a stage, and the next stage needs 17 of its 21 stars.
- You have 5 lives. A mission that ends with 0 stars, or leaving a mission part-way, costs one (the game warns you first). One life comes back every hour.
- The first 3-star result on a mission earns 500 star dust, and 1,500 star dust buys a life.
- A **logbook** lists what you learned next to what happened to the real mission.

**The NASA problem: a hopping rover at the Moon's south pole**
Artemis robots must drive themselves where the Sun sits 1 to 2 degrees above the horizon, so rocks hide in long shadows and some craters never see sunlight. Three challenges:
1. **Sensors:** pick sensors (including VIPER-style headlights) and run a drive test where the rover spots a rock and hops over it, or hits it.
2. **Route:** plan a path across three map sets around dust and shadow, with a battery that only charges in sunlight (WASD or arrow keys).
3. **Moving shadows:** time the drive while the shadows sweep round the pole.

The setting is sourced from NASA papers (see `docs/TRUCK_SOURCES.md`). Only the structured-light figure (about 97%, NASA Ames) is a measured detection rate. The other sensors are shown as Covered / Weak / Blind, not as precise percentages.

**Also**
- **Space trivia for star dust:** 40 questions with NASA photos (10 per round, never repeating until a level runs out, up to 3 rounds a day).
- **Your astronaut:** real suit styles from different decades and countries, mission patch emblems, and a cheer when a mission earns stars.
- **Comfort:** text size (small, medium, large), sound and music controls, and first-visit tips that can be switched off.

## Running it

1. Install the Godot 4.7 standard build.
2. Open `project.godot` and press F5.
3. Press **Self-test** on the title screen to run the rule checks in the game.

Tests from the command line:

```
godot --headless --path . -s tests/load_check.gd       # every script compiles, and nothing the web build leaves out is loaded (run before every merge)
godot --headless --path . -s tests/run_tests.gd        # the rules (sim)
godot --headless --path . -s tests/truck_tests.gd      # the rover problem
godot --headless --path . -s tests/progress_tests.gd   # mission unlock rules
godot --headless --path . -s tests/trivia_tests.gd     # trivia never repeats a question until a level runs out
godot --headless --path . -s tests/mission_check.gd    # every mission can earn 3 stars, with a different best design each (slow)
godot --headless --path . -s tests/flow_check.gd       # plays through every screen and flies missions
godot --headless --path . -s tests/craft_tests.gd      # CubeSat sizes (partly out of date since Earth Imager became a CubeSat mission)
```

The web export steps are in `docs/WEB_EXPORT.md`. Test the exported build in a real browser before publishing it.

## How the code is organised

- `scripts/core/`: the rules (`sim.gd`, `craft.gd`, `truck_sim.gd`, `trivia_pick.gd`, `data.gd`). Pure code, no screens.
- `scripts/autoload/game_state.gd`: the current play-through, lives, star dust and the save file.
- `scripts/screens/`: one script per screen. Each screen builds its UI in code.
- `scripts/ui/`: shared pieces such as style helpers, drawn sprites, the animated simulations, rocket drawings, event cards and the menu.
- `data/*.json`: every balance number, the 20 missions, the events, the puzzles, the trivia and the sources.
- `tools/make_missions.py` builds missions 4 to 20 from the hand-made ones, and `tools/tune_missions.py` gives each mission its own spacecraft, parts and targets.

## Honesty about the numbers

- Game numbers in `data/` (part prices, battery sizes, event effects) are placeholders chosen to teach the trade-offs. The game labels them "PLACEHOLDER" or "ILLUSTRATIVE" and never presents them as NASA data.
- CubeSat sizes and mass limits come from the CubeSat Design Specification Rev 14.1. The setting of the NASA problem comes from NASA's south-pole lighting study and the VIPER and IPEx papers.
- The mission stories summarise the linked sources. Trivia answers are public space-history facts checked against agency histories.
- Every source, with its link, is in the in-game **Resources and sources** panel and in `docs/CREDITS.md`.

## Team (Nebula Forge)

- **Software development:** Anusha Chandra, Aadhav Dijay, Bhairavi Swaminathan
- **Artistry and animation:** Adity Agrawal, Tanvi Padala
- **Team management:** Amudha Lakshmanan

## AI assistance (NASA Space Apps disclosure)

- **Code and documentation:** much of the code, the tests, the tools in `tools/` and the written documentation (including this README and `docs/`) were written with the help of Claude, an AI assistant from Anthropic, working through Claude Code. The team chose the idea, directed every design decision and reviewed the results. AI was not used to come up with the solution to the challenge.
- **Images:** no AI-generated images are used. The game's art is drawn in code or comes from NASA's image library (credited "Image: NASA").
- **Audio:** all sound effects and music are generated by code in the game, not by an AI audio tool.
- **Data:** the mission summaries were written from the cited public sources. Game numbers are labelled placeholder or illustrative.
