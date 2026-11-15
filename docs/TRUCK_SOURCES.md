# Truck scenario: where the numbers come from

**The problem (14 Nov update):** an autonomous digging robot near the Moon's south pole must spot rocks while driving itself. The setting and the problem are sourced:

| Fact | Source |
|---|---|
| At the south pole the Sun sits about 1 to 2 degrees above the horizon (8 to 50 degrees during Apollo), giving long shadows and high contrast that can seriously affect safe driving. | NASA lighting study, [NTRS 20240011393](https://ntrs.nasa.gov/citations/20240011393) |
| NASA tests an autonomous lunar excavator (IPEx) under simulated south pole lighting, using onboard cameras for localisation and hazard detection. | [IPEx test facility, NTRS 20250000128](https://ntrs.nasa.gov/api/citations/20250000128/downloads/ipex_tent.pdf) |
| VIPER is designed with eight LED-array lights tuned for permanently shadowed regions, with headlights for long-range stereo imaging (the first headlights on a lunar rover). | [VIPER mobility hardware, LSIC 2024, NTRS 20240013903](https://ntrs.nasa.gov/api/citations/20240013903/downloads/LSIC_2024-Tech%20Infusion_Panel-VIPER_Mob-HW.pdf) |

**Route challenges (2 and 3):** a light scout rover (camera, stereo, headlights) must plan a path. The rules (solar charging only in sunlight, shadows that sweep as the Sun circles low around the horizon) follow the real situation at the south pole; the battery numbers and shadow lengths are illustrative. Levels were checked solvable by search, and challenge 3 can only be solved by waiting for the shadow to move (tests/truck_tests.gd).

The thermal camera was removed: no evidence supported it. LED headlights were added (the idea is from VIPER; the improvement numbers are illustrative).

**Short version:** no published study gives detection rates for these sensors (camera, stereo, lidar, radar, thermal) in these Moon conditions (dust, long shadows, darkness, slopes). The judges gave no data either. So **most numbers in `data/truck.json` are illustrative** and the game says so on screen ("Mostly illustrative numbers" and the "Where is the data from?" button).

## What is real

| What | Used for | Source |
|---|---|---|
| About 97% positive-obstacle detection (over 99% after discarding transition images). False alarms 1.7% at night to 4.1% in the worst daytime test. 1,158 day and 1,544 night images, lit to recreate direct sunlight and shadowed craters. | The structured-light sensor's `clear`, `shadow` and `dark` values (0.97) | A. Nefian (NASA Ames, K-REX2 rover), [Structured light system detects hazards for planetary surface navigation](https://www.laserfocusworld.com/detectors-imaging/article/14175339/structured-light-system-detects-hazards-for-planetary-surface-navigation), Laser Focus World |

Caveat: that 97% is an overall accuracy over image sets, not a separate figure per condition. We use it for all three conditions it covered.

## What is only a direction (qualitative)

| Statement | Source |
|---|---|
| Cameras lack the sensitivity to detect rocks and craters in very dark shadows; long polar shadows hide hazards; dust loses texture at some lighting angles; early stereo results are promising. No detection rates given. | NASA Ames, [The Dark Side of the Crater](https://www.nasa.gov/centers-and-facilities/ames/the-dark-side-of-the-crater-how-light-looks-different-on-the-moon-and-what-nasa-is-doing-about-it) |
| Lidar performance degrades in dust. | [Design of Dust-Filtering Algorithms for LiDAR Sensors... in Off-Road Vehicles](https://ouci.dntb.gov.ua/works/456o3j2l) (Sensors) |
| Radar shows relatively low attenuation in dust compared with optical sensing. | Visage Technologies, [Why Dust Is One of the Most Complex Problems in Off-Highway Autonomy](https://visagetechnologies.com/dust-one-of-the-most-complex-problems-in-off-highway-autonomy/) (a company article, not a measurement study) |

These support only the **ranking** (radar most robust in dust, lidar and cameras hurt by dust, cameras blind in the dark), not any percentage.

## To verify before relying on it

- CraterGrader (arXiv 2311.01697) reportedly chose passive stereo because infrared scattering is expected in dusty terrain. This came from a search summary and was **not read in full**. It is the reason the structured-light dust value is set low.

## Everything else

All other detection values, and every sensor's mass, power and cost, are placeholders chosen to show the trade-offs. Replace a value and set its `detect_basis` to `"sourced"` only when you have a source you can cite here.

## Model simplification

Sensors are combined as if independent: the chance every sensor misses is the product of each miss chance. Real sensors share failure causes, so this is optimistic.
