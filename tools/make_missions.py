"""Builds the 20 missions (data/level4.json ... level20.json) and prints their unlock order.

Every mission is based on a real spaceflight from somewhere in the world. The game numbers
come from one of the three hand-made missions (level1 = camera, level2 = air instrument,
level3 = fast photos), scaled a little harder for each step up the list. Levels 1-3 are
kept exactly as they are and only get their "based_on" story added.

Run from the project root:  python3 tools/make_missions.py
Then check every level can still earn 3 stars:  godot --headless -s tests/mission_check.gd
The facts in MISSIONS are short summaries of the linked sources; check them before changing.
"""
import copy
import json

R, L, C = "rideshare", "launcher", "cargo"

# position in the list, file id (None = generate), data template, rocket, main problem,
# events this mission is likely to throw at you, and the real mission it is based on.
MISSIONS = [
    dict(id="level1", tpl=1, rocket=R, based_on=dict(
        mission="Landsat 1", agency="NASA", country="USA", year=1972, outcome="success",
        story="The first satellite built to photograph Earth's land. Its scanner sent back hundreds of thousands of pictures of farms, forests and coastlines.",
        lesson="A camera mission lives or dies by how much data it can get down.",
        source="NASA Landsat Science, \"Landsat 1\"", url="https://landsat.gsfc.nasa.gov/satellites/landsat-1/")),
    dict(name="Beep From Orbit", tpl=1, rocket=R, problem="Power", events=["ground_silent"], based_on=dict(
        mission="Sputnik 1", agency="Soviet space programme", country="USSR", year=1957, outcome="success",
        story="The first artificial satellite. It ran on batteries alone, with no solar panels, and fell silent after about three weeks when they ran flat.",
        lesson="Without a way to recharge, every mission has a short clock.",
        source="NASA NSSDCA Master Catalog, \"Sputnik 1\" (1957-001B)", url="https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1957-001B")),
    dict(name="Radiation Counter", tpl=1, rocket=C, problem="Data", events=["ground_rain"], based_on=dict(
        mission="Explorer 1", agency="NASA / JPL", country="USA", year=1958, outcome="success",
        story="America's first satellite found the Van Allen radiation belts. It had no data recorder, so readings were only caught while it passed over a ground station.",
        lesson="Data you cannot store or send is data you lose.",
        source="NASA Science, \"Explorer 1\"", url="https://science.nasa.gov/mission/explorer-1/")),
    dict(name="Second Try", tpl=1, rocket=C, problem="Testing", events=["software_bug"], readiness=5, based_on=dict(
        mission="Vanguard TV-3", agency="US Navy / NRL", country="USA", year=1957, outcome="failure",
        story="Broadcast live on TV, the rocket rose about a metre, lost thrust and exploded on the pad. The small satellite was thrown clear, still beeping.",
        lesson="A launch is only as ready as its least-tested part.",
        source="Wikipedia, \"Vanguard TV-3\"", url="https://en.wikipedia.org/wiki/Vanguard_TV-3")),
    dict(name="East Is Red", tpl=1, rocket=R, problem="Mass", events=["vibration_break"], based_on=dict(
        mission="Dong Fang Hong 1", agency="Chinese Academy of Space Technology", country="China", year=1970, outcome="success",
        story="China's first satellite, launched on a Long March 1. At 173 kg it was heavier than the first satellites of the USSR and USA put together.",
        lesson="Every kilogram has to be paid for by the rocket.",
        source="NASA NSSDCA Master Catalog, \"DFH 1\" (1970-034A)", url="https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1970-034A")),
    dict(name="Power Fault", tpl=2, rocket=R, problem="Power", events=["thermal_test"], based_on=dict(
        mission="Aryabhata", agency="ISRO", country="India", year=1975, outcome="partial",
        story="India's first satellite, launched on a Soviet Kosmos-3M. A fault in its power system stopped the experiments after only a few days in orbit.",
        lesson="Power is the part that, when it fails, takes everything else with it.",
        source="NASA NSSDCA Master Catalog, \"Aryabhata\" (1975-033A)", url="https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1975-033A")),
    dict(name="Student Satellite", tpl=1, rocket=L, problem="Budget", events=["radio_interference"], based_on=dict(
        mission="UoSAT-1", agency="University of Surrey", country="UK", year=1981, outcome="success",
        story="Built by a university team on a small budget, it sent data to radio amateurs and schools for about eight years.",
        lesson="A careful, cheap design can outlast an expensive one.",
        source="Wikipedia, \"UoSAT-1\"", url="https://en.wikipedia.org/wiki/UoSAT-1")),
    dict(id="level2", tpl=2, rocket=L, based_on=dict(
        mission="Sentinel-5 Precursor", agency="ESA (Copernicus)", country="Europe", year=2017, outcome="success",
        story="Launched on a small Rokot rocket, its TROPOMI instrument maps air pollution such as nitrogen dioxide over the whole planet every day.",
        lesson="Air instruments need steady power, all day and all night.",
        source="Wikipedia, \"Sentinel-5 Precursor\"", url="https://en.wikipedia.org/wiki/Sentinel-5_Precursor")),
    dict(name="Magnetic Map", tpl=2, rocket=R, problem="Power", events=["solar_storm"], based_on=dict(
        mission="Ørsted", agency="Danish Meteorological Institute", country="Denmark", year=1999, outcome="success",
        story="Denmark's first satellite rode up as a secondary passenger on a Delta II and mapped Earth's magnetic field for many years.",
        lesson="A rideshare seat is cheap, but you go where the main passenger goes.",
        source="Wikipedia, \"Ørsted (satellite)\"", url="https://en.wikipedia.org/wiki/%C3%98rsted_(satellite)")),
    dict(name="Check The Units", tpl=2, rocket=R, problem="Software", events=["software_bug", "software_glitch"], readiness=5, based_on=dict(
        mission="Mars Climate Orbiter", agency="NASA / JPL", country="USA", year=1999, outcome="failure",
        story="One team's software gave thruster figures in pound-force seconds, another expected newton-seconds. The orbiter flew too low into Mars' atmosphere and was lost.",
        lesson="Small mistakes in numbers can end a whole mission. Test everything twice.",
        source="NASA Science, \"Mars Climate Orbiter\"", url="https://science.nasa.gov/mission/mars-climate-orbiter/")),
    dict(name="Tiny And Tough", tpl=1, rocket=L, problem="Balance", events=["drift_off_course"], based_on=dict(
        mission="PROBA-1", agency="ESA", country="Europe", year=2001, outcome="success",
        story="A small test satellite launched on India's PSLV, planned for two years. It kept working for nearly two decades.",
        lesson="Good margins let a small satellite outlive its plan.",
        source="Wikipedia, \"PROBA-1\"", url="https://en.wikipedia.org/wiki/PROBA-1")),
    dict(name="Lost At Launch", tpl=1, rocket=L, problem="Launch risk", events=["vibration_break"], readiness=5, based_on=dict(
        mission="Dnepr launch failure", agency="ISC Kosmotras", country="Russia / Ukraine", year=2006, outcome="failure",
        story="A Dnepr rocket carrying 18 satellites, including 14 university CubeSats, failed soon after lift-off. Years of student work were lost in seconds.",
        lesson="On a shared rocket, its risk is your risk too.",
        source="Wikipedia, \"Dnepr (rocket)\"", url="https://en.wikipedia.org/wiki/Dnepr_(rocket)")),
    dict(name="Too Hot", tpl=2, rocket=C, problem="Heat", events=["thermal_test"], based_on=dict(
        mission="Chandrayaan-1", agency="ISRO", country="India", year=2008, outcome="partial",
        story="India's first Moon probe ran hotter than planned, so its orbit was raised to cool it down. Contact was lost after 312 days, but it helped find water on the Moon.",
        lesson="Heat is a power problem in disguise.",
        source="NASA NSSDCA Master Catalog, \"Chandrayaan-1\" (2008-052A)", url="https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2008-052A")),
    dict(id="level3", tpl=3, rocket=C, based_on=dict(
        mission="Flock-1 Doves", agency="Planet Labs", country="USA", year=2014, outcome="success",
        story="Dozens of 3U CubeSats rode a cargo ship to the space station and were pushed out from there. Their photos are used to watch floods and disasters.",
        lesson="When a disaster strikes, fast photos matter more than perfect ones.",
        source="Wikipedia, \"Planet Labs\"", url="https://en.wikipedia.org/wiki/Planet_Labs")),
    dict(name="Junk Collision", tpl=3, rocket=R, problem="Debris", events=["debris_alert"], based_on=dict(
        mission="Iridium 33 and Kosmos-2251", agency="Iridium / Russian MoD", country="USA / Russia", year=2009, outcome="failure",
        story="A working satellite and a dead one hit each other at about 11.7 km per second, the first accidental collision of two satellites. It made thousands of pieces of debris.",
        lesson="Space junk is real, and dodging it costs time and fuel.",
        source="Wikipedia, \"2009 satellite collision\"", url="https://en.wikipedia.org/wiki/2009_satellite_collision")),
    dict(name="Stuck In Orbit", tpl=3, rocket=R, problem="Fuel", events=["orbit_decay", "software_glitch"], based_on=dict(
        mission="Fobos-Grunt", agency="Roscosmos", country="Russia", year=2011, outcome="failure",
        story="Meant to bring back soil from Mars' moon Phobos, its engines never fired to leave Earth orbit. It fell back to Earth two months later.",
        lesson="If the spacecraft cannot fix itself, the mission is over.",
        source="Wikipedia, \"Fobos-Grunt\"", url="https://en.wikipedia.org/wiki/Fobos-Grunt")),
    dict(name="Spin Out", tpl=3, rocket=L, problem="Software", events=["software_glitch", "software_bug"], readiness=5, based_on=dict(
        mission="Hitomi", agency="JAXA", country="Japan", year=2016, outcome="failure",
        story="An attitude error and a bad thruster command made the X-ray telescope spin faster and faster until parts broke off, about a month after launch.",
        lesson="Software in orbit must be tested like hardware.",
        source="Wikipedia, \"Hitomi (satellite)\"", url="https://en.wikipedia.org/wiki/Hitomi_(satellite)")),
    dict(name="Shell Stuck", tpl=3, rocket=L, problem="Launch risk", events=["vibration_break"], readiness=5, based_on=dict(
        mission="PSLV-C39 / IRNSS-1H", agency="ISRO", country="India", year=2017, outcome="failure",
        story="The nose cone that protects the satellite on the way up did not come off, so the navigation satellite was trapped inside it and could not work.",
        lesson="One stage of the launch going wrong is enough.",
        source="Wikipedia, \"IRNSS-1H\"", url="https://en.wikipedia.org/wiki/IRNSS-1H")),
    dict(name="Storm Drag", tpl=3, rocket=C, problem="Space weather", events=["solar_storm", "orbit_decay"], based_on=dict(
        mission="Starlink Group 4-7", agency="SpaceX", country="USA", year=2022, outcome="failure",
        story="A geomagnetic storm made the upper air thicker just after launch. About 38 of 49 new satellites could not climb out of the drag and burned up.",
        lesson="Space weather can undo a launch in days.",
        source="Wikipedia, \"Starlink\"", url="https://en.wikipedia.org/wiki/Starlink")),
    dict(name="Storm Chasers", tpl=3, rocket=C, problem="Everything", events=["radio_interference", "ground_rain"], readiness=5, based_on=dict(
        mission="TROPICS", agency="NASA", country="USA", year=2023, outcome="success",
        story="The first two of these hurricane-watching CubeSats were lost when their small rocket failed in 2022. NASA flew the remaining four in 2023, and they worked.",
        lesson="Learn from a failure, fix it, and fly again.",
        source="NASA Science, \"TROPICS\"", url="https://science.nasa.gov/mission/tropics/")),
]

ROCKETS = {R: 1, L: 2, C: 3}   # which hand-made mission each rocket's block is copied from


def label(i):
    tier = "Easy" if i < 5 else "Medium" if i < 10 else "Hard" if i < 15 else "Expert"
    return "Level %d  ·  %s" % (i + 1, tier)


def main():
    tpl = {k: json.load(open("data/level%d.json" % k)) for k in (1, 2, 3)}
    pos_of_tpl = {1: 0, 2: 7, 3: 13}
    order = []
    n = 4
    for i, m in enumerate(MISSIONS):
        if m.get("id"):
            lvl = tpl[int(m["id"][-1])]
            lvl["based_on"] = m["based_on"]
            if lvl["differences"][0] != m["based_on"]["story"]:
                lvl["differences"] = [m["based_on"]["story"]] + lvl["differences"][:2]
            lvl["level_label"] = label(i)
            json.dump(lvl, open("data/%s.json" % m["id"], "w"), indent=2, ensure_ascii=False)
            open("data/%s.json" % m["id"], "a").write("\n")
            order.append(m["id"])
            continue
        lvl = copy.deepcopy(tpl[m["tpl"]])
        rk = copy.deepcopy(tpl[ROCKETS[m["rocket"]]])
        # the rocket decides how you get up and where you end up
        for key in ("rocket", "launch", "orbit"):
            lvl[key] = rk[key]
        for key in ("fuel_base_pct_wk", "fuel_mass_pct_wk"):
            lvl["ops"][key] = rk["ops"][key]
        # harder further down the list, relative to where the template sits
        step = (i - pos_of_tpl[m["tpl"]]) / 19.0
        money = 1.0 - 0.08 * step
        time = 1.0 - 0.10 * step
        # the fast-photo mission already needs the fastest radio there is, so its data goal stays put
        data = 1.0 if m["tpl"] == 3 else 1.0 + 0.12 * step
        # a dearer rocket comes with the money to pay for it
        rocket_extra = rk["launch"]["cost_k"] - tpl[m["tpl"]]["launch"]["cost_k"]
        lvl["limits"]["budget_k"] = int(round((lvl["limits"]["budget_k"] * money + 1.5 * rocket_extra) / 10.0) * 10)
        deadline = int(round(lvl["limits"]["deadline_day"] * time / 5.0) * 5)
        lvl["limits"]["deadline_day"] = deadline
        lvl["schedule"]["licence_days"] = min(lvl["schedule"]["licence_days"], deadline - 20)
        for req in lvl["requirements"]:
            if req["kind"] == "delivered_min":
                req["target"] = round(req["target"] * data)
                req["text"] = req["text"].split(" at least ")[0] + " at least %d MB" % req["target"] + req["text"].split(" MB", 1)[1]
            if req["kind"] == "launch_day_max":
                req["target"] = float(deadline)
                req["text"] = "Ready to launch by day %d" % deadline
        lvl["ops"]["goal_mb"] = round(lvl["ops"]["goal_mb"] * (1.0 + 0.5 * (data - 1.0)))
        lvl["launch_min_readiness_pct"] = min(90, lvl["launch_min_readiness_pct"] + int(round(10 * max(0.0, step))) + m.get("readiness", 0))
        b = m["based_on"]
        lvl["id"] = "level%d" % n
        lvl["name"] = m["name"]
        lvl["main_problem"] = m["problem"]
        lvl["level_label"] = label(i)
        lvl["blurb"] = b["lesson"]
        lvl["teaches"] = b["lesson"]
        lvl["differences"] = [
            b["story"],
            "Main problem: %s." % m["problem"].lower(),
            "Launch by day %d with %s." % (deadline, "$%dk" % lvl["limits"]["budget_k"]),
        ]
        lvl["event_bias"] = m.get("events", [])
        lvl["based_on"] = b
        lvl["_note"] = "GENERATED by tools/make_missions.py from level%d.json. Game numbers are placeholders; the based_on story is a summary of the linked source." % m["tpl"]
        json.dump(lvl, open("data/level%d.json" % n, "w"), indent=2, ensure_ascii=False)
        open("data/level%d.json" % n, "a").write("\n")
        order.append(lvl["id"])
        n += 1
    # paste this order into Data.MISSIONS (scripts/core/data.gd)
    print("\n".join(order))


main()
