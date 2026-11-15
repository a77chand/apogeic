## Checks that trivia does not repeat questions until a level has run out.
##   godot --headless --path . -s tests/trivia_tests.gd
extends SceneTree
const Data = preload("res://scripts/core/data.gd")
const Trivia = preload("res://scripts/core/trivia_pick.gd")

var fails: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("FAIL  " + what)


func _initialize() -> void:
	var cfg: Dictionary = Data.load_dict("res://data/trivia.json")
	var all: Array = cfg.get("questions", [])
	var per: Array = cfg.get("per_round", [3, 3, 2, 2])
	check(all.size() == 40, "40 questions")
	var seen: Dictionary = {}
	var asked: Dictionary = {}
	var repeats: int = 0
	# levels 1 and 2 have 10 questions and 3 a round, so 3 rounds never repeat
	for r in range(3):
		var round_qs: Array = Trivia.pick_round(all, per, seen)
		check(round_qs.size() == 10, "a round has 10 questions")
		for q in round_qs:
			var id: String = str((q as Dictionary)["id"])
			if asked.has(id):
				repeats += 1
			asked[id] = true
			seen[id] = true
	check(repeats == 0, "no question repeats in the first three rounds")
	# the 4th round: level 1 has 1 unseen left, so it is asked first, then the level starts over
	var r4: Array = Trivia.pick_round(all, per, seen)
	var first_easy: String = str((r4[0] as Dictionary)["id"])
	check(not asked.has(first_easy), "when a level runs out, its unseen question still comes first")
	var levels: Array = r4.map(func(q: Variant) -> int: return int((q as Dictionary)["difficulty"]))
	check(levels == [1, 1, 1, 2, 2, 2, 3, 3, 4, 4], "a round gets harder: easy first, expert last")
	for q in all:
		check(str((q as Dictionary).get("image", "")) != "" or str((q as Dictionary).get("art", "")) != "", "question has a picture: " + str((q as Dictionary)["id"]))
	print("TRIVIA TESTS PASSED" if fails.is_empty() else "%d trivia test(s) failed" % fails.size())
	quit(0 if fails.is_empty() else 1)
