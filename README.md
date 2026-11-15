# AP0GEIC 11

A space mission design game for the NASA Space Apps Challenge 2026. You design a small satellite, launch it, and keep it working in orbit. Every part you pick trades mass, power, data, money and time against each other, and every mission is based on a real spaceflight.

**Play it in your browser:** https://a77chand.github.io/space-mission-designer/ (judges: press **Judge demo** on the start page)

One-page summary: [`docs/SUBMISSION.md`](docs/SUBMISSION.md)

Built with Godot 4.7 (standard build), GDScript, and the Compatibility renderer, so it runs as a web (HTML5) export.

## What's in the game

- **Training: four short puzzles**, one idea each:
  1. **Mass:** pack a satellite into a rocket slot.
  2. **Power:** survive the dark part of every orbit.
  3. **Data link:** the slowest step sets the pace.
  4. **Budget and time:** plan the year, then play it and survive real surprises.

  Puzzles 1, 2 and 4 end with a short animated simulation of what really happens to your design.
- **20 missions, each based on a real spaceflight** from the USA, the USSR/Russia, China, India, Europe, Japan, the UK and Denmark (Sputnik 1, Explorer 1, Dong Fang Hong 1, Aryabhata, Chandrayaan-1, Hitomi, TROPICS and more). Each one shows "Based on mission ___", the real story and its lesson, with a cited source.
- **A full mission flow:** briefing, workshop, test lab, launch, operations, and a report that explains why the mission went right or wrong.
- **Decisions under time pressure:** event cards with a 22-second timer, a free clue, paid expert advice, and a penalty if time runs out. After each choice the game says whether it was optimal, fair or costly, and why.
- **Progress:**
  - One star opens the next mission.
  - Every 7 missions is a stage, and the next stage needs 17 of its 21 stars.
  - You have 5 lives (a 0-star mission costs one; one comes back every 30 minutes).
  - The first 3-star result on a mission earns 500 star dust, and 1500 star dust buys a life.
- **A "NASA problem" scenario:** a digging robot at the Moon's south pole must spot rocks in low sun, black shadows, dark craters, dust and slopes. Three challenges: pick sensors (including VIPER-style headlights) and run a drive test; plan a route around dust and shadow; then time the drive while the shadows sweep round. The setting is sourced from NASA papers. Only the structured-light figure (about 97%, NASA Ames) is a measured detection rate; the others are illustrative and labelled as such.
- **Space trivia for star dust:** 40 questions on rockets, missions and the people behind them (with NASA photos), 10 per round, up to 3 rounds a day.
- **Real decisions:** nine missions include the decision the real team faced, with what they actually chose as one of the options.
- **Your astronaut:** real suit styles from different decades and countries, mission patch emblems, and a cheer when a mission earns stars.

## Running it

1. Install the Godot 4.7 standard build.
2. Open `project.godot` and press F5.
3. Press **Self-test** on the title screen to run the rule checks in the game.

Tests from the command line:

```
godot --headless --path . -s tests/run_tests.gd        # the rules (sim)
godot --headless --path . -s tests/truck_tests.gd      # the truck scenario
godot --headless --path . -s tests/craft_tests.gd      # 1U / 3U / 6U sizes
godot --headless --path . -s tests/progress_tests.gd   # mission unlock rules
godot --headless --path . -s tests/mission_check.gd    # every mission can still get 3 stars (slow)
godot --headless --path . -s tests/load_check.gd       # every script compiles (run before every merge)
godot --headless --path . -s tests/flow_check.gd       # plays through every screen and flies missions
```

The web export steps are in `docs/WEB_EXPORT.md`.

## How the code is organised

- `scripts/core/` contains the rules (`sim.gd`, `craft.gd`, `truck_sim.gd`, `data.gd`). It is pure code with no screens.
- `scripts/autoload/game_state.gd` holds the current play-through and the save file.
- `scripts/screens/` has one script per screen. Each screen builds its UI in code.
- `scripts/ui/` holds shared pieces: style helpers, drawn sprites, the animated simulations, event cards and the menu.
- `data/*.json` holds all balance numbers, the 20 missions, the events and the puzzles.
- `tools/make_missions.py` builds missions 4 to 20 from the three hand-made ones.

## Honesty about the numbers

- Game numbers in `data/` are placeholders chosen to teach the trade-offs. They are labelled "PLACEHOLDER NUMBERS" in the game and are not presented as NASA data.
- The mission stories summarise the linked sources.
- Every source, with its link, is listed in the in-game **Resources and sources** panel and in `docs/CREDITS.md`.

## Team

Amudha (lead), Anusha, Aadhav, Bhairavi, Tanvi and Aditi.
