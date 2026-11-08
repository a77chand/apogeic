# Balance

Goal from the brief: a thoughtful player can win, and a careless one fails around sol 8 to 15. No build is perfect.

Check balance after every change to `data/*.json`:

```sh
godot --headless --path . --script res://tests/balance.gd -- games=300
godot --headless --path . --script res://tests/balance.gd -- trace=mars:thoughtful:1006   # replay one game sol by sol
```

The script plays every game with the tutorial on, using these bot players:

| Bot | Plays like |
|---|---|
| thoughtful | Keeps power, water, oxygen and food budgets positive, builds the shelter, adds batteries (with spare solar to charge them), switches to "Food first" when food will run out before oxygen |
| no_shelter | Same as thoughtful, but never builds a storm shelter or shielding |
| careless | Buys greenhouses and habitats first, little power, no batteries |
| random | Buys random affordable modules |
| idle | Does the tutorial, then builds nothing |

## Results (300 games each, 2026-11-08)

| Mode | Bot | Win % | Fail sol p10 / median / p90 | Runs out of |
|---|---|---|---|---|
| Moon | thoughtful | 100 | - | - |
| Moon | no_shelter | 21 | 14 / 27 / 27 | radiation |
| Moon | careless | 0 | 8 / 8 / 8 | water |
| Moon | random | 2 | 8 / 10 / 13 | food, water |
| Moon | idle | 0 | 10 / 10 / 10 | food |
| Mars | thoughtful | 97 | 13 / 18 / 29 | water (dust storms) |
| Mars | no_shelter | 68 | 12 / 21 / 29 | radiation |
| Mars | careless | 0 | 9 / 9 / 11 | water |
| Mars | random | 0 | 9 / 10 / 12 | food, water |
| Mars | idle | 0 | 10 / 10 / 10 | food |

The thoughtful bot plans better than most first-time players, so expect real players to win less often. Playtest with real students before making the game harder.

## What changed in the balance pass

| Change | Why |
|---|---|
| Electrolyzer oxygen 4 -> 5 | With exactly 4 the oxygen tank could never build a buffer before a dark spell |
| Start oxygen 20 -> 30, start water 50 -> 60 | Careless players failed on sol 6 to 7, before the target window |
| "Life support first" order: electrolyzer, ice miner, habitat, greenhouse | Before, at night the ice miner kept running while oxygen production stopped |
| Lunar night 4 -> 3 sols | A 4-sol night was not survivable on solar and batteries with this build budget |

All values are still placeholders, not NASA data.
