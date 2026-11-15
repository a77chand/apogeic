# AP0GEIC 11: one-page summary

**Play:** https://a77chand.github.io/apogeic-game/ · **Source:** https://github.com/a77chand/apogeic (press **Judge demo** on the start page for a 5-minute tour with everything unlocked)

## The problem

Space missions fail for reasons that are easy to explain afterwards and hard to see beforehand: a satellite too heavy for its rocket, a battery that cannot last through Earth's shadow, a radio too slow for the data, software flown untested, a schedule with no room for surprises. Most people, including students, never get to make these trade-offs themselves.

For the NASA problem, we took the judges' idea of autonomous trucks and set it where NASA needs it: a hopping rover that must find its own way near the Moon's south pole for Artemis. There the Sun stays 1 to 2 degrees above the horizon, rocks hide in long shadows, and some craters never see sunlight.

## What we built

- **Training (4 puzzles):** mass, power, data link, budget and time. Each ends with an animated simulation of what really happens to your design.
- **20 missions based on real spaceflights** from the USA, USSR/Russia, China, India, Europe, Japan, the UK, Denmark and SpaceX, from Sputnik 1 to TROPICS.
  - **Real decisions:** in 9 of the missions, one option is what the real team did, and the game tells you so after you choose.
  - **Feedback:** every choice is rated (optimal, fair, costly) with the reason.
- **The NASA problem, in three challenges:** pick sensors (camera, stereo, lidar, radar, VIPER-style headlights, NASA Ames structured light) and run a drive test where the rover hops over rocks it spots; plan safe routes (three map sets) for a solar-powered hopping rover; time the drive as the shadows sweep around the pole.
- **Logbook:** every lesson learned, next to what happened to the real mission.
- **Space trivia:** 40 questions with NASA photos.

## Sources and honesty

- The CubeSat sizes and mass limits come from the CubeSat Design Specification Rev 14.1, and the mission stories are summarised from NASA, ESA, ISRO and other agency or reference sources. All are cited with links in the game's **Resources and sources** panel.
- For the south pole setting we used a NASA lighting study (NTRS 20240011393), NASA's IPEx excavator tests (NTRS 20250000128) and VIPER's headlight hardware (NTRS 20240013903). See `docs/TRUCK_SOURCES.md`.
- **What is illustrative:**
  - **Measured:** only the structured-light figure (about 97%, NASA Ames) is a measured detection rate.
  - **Ranking only:** the other sensors are shown as a Covered / Weak / Blind ranking that follows the published direction of the evidence.
  - **Placeholders:** part prices, battery numbers and event effects. The game labels all of these as placeholder or illustrative numbers.

## Team

Amudha (lead), Anusha, Aadhav, Bhairavi, Tanvi and Aditi. Built in Godot 4.7 (GDScript), exported to the web.
