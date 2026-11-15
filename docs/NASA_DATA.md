# NASA data and resources used

Everything below is also in the game's **Resources and sources** panel (with a formal citation), and the photo credits are in [`CREDITS.md`](CREDITS.md). Links were checked on 14 Nov 2026.

## 1. The NASA problem (a hopping rover at the Moon's south pole)

| Source | What we used it for |
|---|---|
| [NASA lighting study for driving at the lunar south pole (NTRS 20240011393)](https://ntrs.nasa.gov/citations/20240011393) | The Sun sits about 1 to 2 degrees above the horizon (8 to 50 during Apollo): long shadows, high contrast, hard driving. This is the setting of all three rover challenges. |
| [VIPER mobility hardware, LSIC 2024 (NTRS 20240013903)](https://ntrs.nasa.gov/api/citations/20240013903/downloads/LSIC_2024-Tech%20Infusion_Panel-VIPER_Mob-HW.pdf) | VIPER's LED lights tuned for permanently shadowed regions: the idea behind the headlights sensor. |
| [IPEx test facility (NTRS 20250000128)](https://ntrs.nasa.gov/api/citations/20250000128/downloads/ipex_tent.pdf) | NASA tests an autonomous lunar digger under south pole lighting, using cameras for hazard detection. |
| [VIPER lunar operations (NASA Science)](https://science.nasa.gov/mission/viper/lunar-operations/) | Hazard cameras, and route planning between waypoints. |
| [Artificial intelligence and NASA's first robotic lunar rover (NASA Artemis blog)](https://www.nasa.gov/blogs/artemis/2023/12/14/part-2-artificial-intelligence-and-nasas-first-robotic-lunar-rover/) | Routes that stay in sunlight because the rover is solar powered, and shadows that move (challenges 2 and 3). |
| [The Dark Side of the Crater (NASA Ames)](https://www.nasa.gov/centers-and-facilities/ames/the-dark-side-of-the-crater-how-light-looks-different-on-the-moon-and-what-nasa-is-doing-about-it) | How shadows and dust affect cameras (direction only, no numbers). |
| [Structured light system detects hazards (A. Nefian, NASA Ames, Laser Focus World)](https://www.laserfocusworld.com/detectors-imaging/article/14175339/structured-light-system-detects-hazards-for-planetary-surface-navigation) | The only **measured** detection rate in the game: about 97%. |

Details of how each source is used, and what is only illustrative, are in [`TRUCK_SOURCES.md`](TRUCK_SOURCES.md).

## 2. Spacecraft rules and engineering (puzzles, workshop, launch)

| Source | What we used it for |
|---|---|
| [CubeSat Design Specification Rev 14.1 (copy hosted on nasa.gov)](https://www.nasa.gov/wp-content/uploads/2018/01/cubesatdesignspecificationrev14_12022-02-09.pdf) | CubeSat sizes (a 1U is 100 x 100 x 113.5 mm) and mass limits (Table 1: 1U 2 kg, 3U 6 kg, 6U 12 kg). |
| [NASA CubeSat 101](https://www.nasa.gov/wp-content/uploads/2017/03/nasa_csli_cubesat_101_508.pdf) | The build, test, licence and launch order, and rideshare launches. |
| [NASA State-of-the-Art of Small Spacecraft Technology](https://www.nasa.gov/smallsat-institute/sst-soa/) | Typical ranges for panels, batteries, radios and cameras. |
| [NASA Glenn Beginner's Guide to Rockets](https://www.grc.nasa.gov/www/k-12/rocket/bgmr.html) | Stages, max-Q and why mass matters (the launch failure stages). |
| [NASA Earth Observatory: Catalog of Earth Satellite Orbits](https://earthobservatory.nasa.gov/features/OrbitsCatalog) | Orbit period and eclipse time (the power puzzle). |

## 3. NASA sources for the real missions

| Mission | Source |
|---|---|
| Landsat 1 | [NASA Landsat Science](https://landsat.gsfc.nasa.gov/satellites/landsat-1/) |
| Sputnik 1 | [NASA NSSDCA 1957-001B](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1957-001B) |
| Explorer 1 | [NASA Science](https://science.nasa.gov/mission/explorer-1/) |
| Dong Fang Hong 1 | [NASA NSSDCA 1970-034A](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1970-034A) |
| Aryabhata (ISRO) | [NASA NSSDCA 1975-033A](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1975-033A) |
| Mars Climate Orbiter | [NASA Science](https://science.nasa.gov/mission/mars-climate-orbiter/) |
| Chandrayaan-1 (ISRO) | [NASA NSSDCA 2008-052A](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2008-052A) |
| TROPICS | [NASA Science](https://science.nasa.gov/mission/tropics/) |

The other twelve missions (including ESA's Sentinel-5P and PROBA-1, JAXA's Hitomi and ISRO's IRNSS-1H) cite the reference pages listed in each level's `based_on` block in `data/level*.json` and in the in-game Resources panel.

## 4. NASA photographs (Space trivia, 20 images, each credited "Image: NASA")

From the [NASA Image and Video Library](https://images.nasa.gov) (usage: [NASA media guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/)). Image ids: Saturn V launch 6900540, ISS s134e010137, Curiosity selfie PIA19808, RS-25 engines SSC20210116_GR8438, lunar module Eagle as11-44-6642, Voyager Golden Record PIA14113, Hubble deploy s31-76-016, orbital sunset iss023e057948, CubeSat deployment iss038e044889, Katherine Johnson LRC-1962-B701_P-09381, Explorer 1 PIA04601, Orion heat shield jsc2022e044405, InSight vibration test PIA19815, aurora iss072e159172, Apollo 13 service module as13-58-8458 (cropped), MarCO PIA20344, Challenger 51l-s-156, Columbia STS107-S-015, Sojourner PIA04318, STS-7 crew S83-29016.

## 5. What is not NASA data

- Part prices, battery sizes, event effects and most sensor detection numbers are **placeholders or illustrative**, and the game says so on screen.
- Sensor coverage is shown as Covered / Weak / Blind, because only the structured-light figure is measured.
- Other mission and agency references (ESA, ISRO, JAXA missions via reference pages), fonts and tools are in [`CREDITS.md`](CREDITS.md).
