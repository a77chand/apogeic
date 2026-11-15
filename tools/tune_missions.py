"""Gives every mission its own spacecraft type, parts and targets, so no two missions have
the same best design, and writes them into data/level*.json. Run after make_missions.py:

    python3 tools/make_missions.py && python3 tools/tune_missions.py

Each mission has:
  craft_kind  "cubesat" (craft_sizes = the CubeSat sizes the real spacecraft came in) or
              "satellite" (a historical satellite that was not a CubeSat: no size choice).
  parts_offered  the parts in the workshop tray (the wrong instrument and the parts that
              would not exist for that mission are left out).
  numbers     T = data that must reach the ground each week (at 3U scale), spare = spare
              power %, ecl = minutes of shadow per orbit, shield = radiation shielding must
              be fitted, drop = parts left out.
The designs that earn 3 stars were found by search (see tests/mission_check.gd, which
prints the best design of every mission) and are different for each mission.
Real masses are approximate (see each mission's source). Game numbers are placeholders.
"""
import json

ALL = ["solar_small", "solar_large", "battery_small", "battery_std", "camera_std", "spectrometer",
       "radio_uhf", "radio_sband", "antenna_big", "ground2", "shielding"]

# id: (kind, T, spare, ecl, drop, shield, craft_kind, craft_sizes, class name, real mass, goal text)
M = {
 "level1": ("images", 40, 10, 35, [], False, "cubesat", ["1u", "3u", "6u"], "Imaging CubeSat (inspired by Landsat 1)", "1U, 3U or 6U",
            "Take photos of coastlines for 12 weeks and get them to the ground."),
 "level4": ("spectra", 6, 5, 75, ["radio_sband", "ground2"], False, "satellite", [], "First artificial satellite", "about 84 kg",
            "Send temperature readings for 12 weeks, on a simple battery-powered design."),
 "level5": ("spectra", 10, 5, 55, ["solar_large"], True, "satellite", [], "Early science satellite", "about 14 kg",
            "Count radiation for 12 weeks and make sure the readings reach the ground, even when no station is in view."),
 "level6": ("spectra", 6, 10, 75, ["battery_small", "ground2"], False, "satellite", [], "Small test satellite", "about 1.5 kg",
            "Get a small test satellite through testing and into orbit, then send its readings home for 12 weeks."),
 "level7": ("spectra", 10, 10, 55, ["antenna_big"], False, "satellite", [], "Large national satellite", "about 173 kg",
            "Launch a heavy satellite inside the rocket's mass limit and send its radio readings home for 12 weeks."),
 "level8": ("spectra", 15, 10, 36, ["battery_small"], False, "satellite", [], "Science satellite", "about 360 kg",
            "Run an X-ray experiment for 12 weeks without the power system failing, and send the readings to the ground."),
 "level9": ("images", 8, 5, 36, ["antenna_big"], False, "satellite", [], "University microsatellite", "about 52 kg",
            "Run a low-cost photo mission for 12 weeks, keeping money in reserve for surprises."),
 "level2": ("spectra", 22, 22, 70, ["solar_small"], False, "satellite", [], "Air-quality satellite", "about 820 kg",
            "Measure the gases in the air above a big city for 12 weeks and send the readings to the ground."),
 "level10": ("spectra", 15, 5, 55, ["ground2", "antenna_big"], False, "satellite", [], "Small science satellite", "about 61 kg",
            "Measure Earth's magnetic field for 12 weeks on a cheap shared ride, with power to spare."),
 "level11": ("images", 8, 10, 36, ["solar_small"], False, "satellite", [], "Mars orbiter", "about 640 kg",
            "Take photos of Mars' weather for 12 weeks, and catch any wrong numbers before they cost the mission."),
 "level12": ("images", 15, 5, 55, ["solar_large", "antenna_big"], False, "satellite", [], "Technology demonstrator", "about 94 kg",
            "Build a small photo satellite with enough margin to keep working the whole mission."),
 "level13": ("images", 15, 5, 36, ["radio_sband", "ground2"], False, "cubesat", ["1u", "3u"], "University CubeSats", "1U to 3U",
            "Get a university CubeSat safely through launch on a shared rocket, then send its photos home."),
 "level14": ("images", 15, 10, 55, ["battery_small", "antenna_big"], True, "satellite", [], "Lunar orbiter", "about 1,380 kg",
            "Photograph the Moon for 12 weeks without the spacecraft overheating, and send the photos to the ground."),
 "level3": None,   # Flock-1 is a 3U CubeSat: its hand-made numbers stay as they are
 "level15": ("images", 15, 22, 36, ["solar_small"], True, "satellite", [], "Communications satellite", "about 690 kg",
             "Send photos of space junk home for 10 weeks while dodging it, with shielding for the debris."),
 "level16": ("images", 8, 5, 36, ["battery_small"], False, "satellite", [], "Deep-space probe", "about 13,200 kg",
             "Send photos home for 10 weeks, and keep enough fuel and power to leave Earth orbit."),
 "level17": ("spectra", 6, 5, 36, ["ground2"], True, "satellite", [], "X-ray telescope", "about 2,700 kg",
             "Send X-ray readings home for 10 weeks, and never fly software you have not tested."),
 "level18": ("images", 15, 22, 55, ["antenna_big"], False, "satellite", [], "Navigation satellite", "about 1,425 kg",
             "Get through every stage of launch, then send photos home for 10 weeks."),
 "level19": ("images", 50, 5, 55, ["solar_large", "antenna_big"], False, "satellite", [], "Broadband satellite", "about 300 kg",
             "Send photos home fast for 10 weeks, and watch the space weather: storms drag low satellites down."),
 "level20": ("spectra", 6, 5, 75, ["solar_small"], True, "cubesat", ["3u"], "Storm-watching CubeSats", "3U",
             "Send storm-watching readings home for 10 weeks, with shielding for the radiation."),
}


# id: (orbit name, rocket name, one line on the real rocket). From each mission's source.
REAL = {
 "level1": ("Sun-synchronous orbit, about 920 km", "Delta 900", "NASA's workhorse Delta, with strap-on boosters."),
 "level4": ("Elliptical low Earth orbit, 215 x 939 km", "R-7", "A converted ballistic missile, the first rocket to reach orbit."),
 "level5": ("Elliptical orbit, 358 x 2,550 km", "Juno I", "A Jupiter-C missile with a fourth stage added."),
 "level6": ("Planned low Earth orbit", "Vanguard", "The US Navy's three-stage rocket for its first satellites."),
 "level7": ("Elliptical orbit, 441 x 2,368 km", "Long March 1", "China's first orbital rocket."),
 "level8": ("Low Earth orbit, about 600 km", "Kosmos-3M", "A Soviet rocket that launched many small satellites."),
 "level9": ("Sun-synchronous orbit, about 540 km", "Delta 2310", "A Delta with two strap-on boosters."),
 "level2": ("Sun-synchronous orbit, about 820 km", "Rokot", "A converted missile used for ESA's Sentinel satellites."),
 "level10": ("Elliptical orbit, 650 x 860 km", "Delta II", "A Delta rocket with nine strap-on solid boosters."),
 "level11": ("Planned Mars orbit", "Delta II", "A Delta rocket with nine strap-on solid boosters."),
 "level12": ("Sun-synchronous orbit, about 600 km", "PSLV", "India's reliable workhorse rocket."),
 "level13": ("Sun-synchronous orbit, about 600 km (planned)", "Dnepr", "A converted missile that carried many small satellites at once."),
 "level14": ("Lunar orbit, 100 km", "PSLV-XL", "PSLV with larger strap-on boosters."),
 "level3": None,
 "level15": ("Low Earth orbit, about 780 km", "Proton-K", "A heavy Russian rocket."),
 "level16": ("Low Earth orbit, then on to Mars (planned)", "Zenit-2SB", "A Ukrainian-Russian rocket."),
 "level17": ("Low Earth orbit, about 575 km", "H-IIA", "Japan's main rocket."),
 "level18": ("Geosynchronous transfer orbit", "PSLV-XL", "PSLV with larger strap-on boosters."),
 "level19": ("Low Earth orbit, about 210 km at release", "Falcon 9", "SpaceX's reusable rocket."),
 "level20": ("Low Earth orbit, about 550 km", "Astra Rocket 3.3", "A small low-cost launcher (its first TROPICS launch failed)."),
}


def main():
    for lid, spec in M.items():
        path = "data/%s.json" % lid
        d = json.load(open(path))
        b = d.get("based_on", {})
        if spec is None:
            d["craft_kind"] = "cubesat"
            d["craft_sizes"] = ["3u"]
            d["satellite_class"] = {"name": "Planet Labs Doves", "real_mass": "3U CubeSats"}
        else:
            kind, T, spare, ecl, drop, shield, ck, sizes, cname, cmass, goal = spec
            weeks = int(d["ops"]["weeks"])
            instr = "camera_std" if kind == "images" else "spectrometer"
            other = "spectrometer" if kind == "images" else "camera_std"
            d["goal_data_type"] = kind
            d["data_noun"] = "photos" if kind == "images" else "readings"
            d["goal_text"] = goal
            for r in d["requirements"]:
                if r["kind"] == "delivered_min":
                    r["target"] = T
                    r["text"] = "Deliver at least %d MB of %s per week" % (T, d["data_noun"])
                    r["consequence"] = "Fewer %s reach the ground each week." % d["data_noun"]
                if r["kind"] == "power_spare_min":
                    r["target"] = spare
                    r["text"] = "Keep at least %d%% spare power" % spare
            d["requirements"] = [r for r in d["requirements"] if r["kind"] != "part_fitted"]
            if shield:
                d["requirements"].append({"id": "R%d" % (len(d["requirements"]) + 1), "kind": "part_fitted", "part": "shielding", "target": 1, "unit": "", "hard": False,
                                          "text": "Radiation shielding fitted", "reason": "The spacecraft has no radiation shielding.",
                                          "tip": "Fit the radiation shielding in an extra slot.", "consequence": "Radiation can damage the instrument."})
            d["orbit"]["eclipse_min"] = ecl
            d["ops"]["goal_mb"] = float(T * weeks)
            d["parts_offered"] = [p for p in ALL if p not in drop and p != other]
            d["craft_kind"] = ck
            d["craft_sizes"] = sizes
            d["satellite_class"] = {"name": cname, "real_mass": cmass}
        real = REAL.get(lid)
        if real:
            d["orbit"]["name"] = real[0]
            d["launch"]["name"] = real[1] + " launch"
            d["rocket"]["name"] = real[1]
            d["rocket"]["why"] = real[2]
        # the concept: only what this mission really used (no locked options)
        sc = d["satellite_class"]
        chips = []
        if d["craft_kind"] == "satellite":
            chips.append({"group": "Spacecraft", "label": "%s (%s)" % (sc["name"], sc["real_mass"]), "state": "chosen", "why": ""})
        else:
            chips.append({"group": "Spacecraft", "label": sc["name"], "state": "chosen", "why": ""})
        chips.append({"group": "Orbit", "label": str(d["orbit"]["name"]), "state": "chosen", "why": ""})
        chips.append({"group": "Launch", "label": str(d["rocket"]["name"]) if real else "%s (%s)" % (str(d["launch"]["name"]), str(b.get("rocket", ""))), "state": "chosen", "why": ""})
        d["concept_chips"] = chips
        json.dump(d, open(path, "w"), indent=2, ensure_ascii=False)
        open(path, "a").write("\n")
    print("tuned", len(M), "missions")


main()
