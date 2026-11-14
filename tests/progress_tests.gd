## Checks the mission unlock rules in GameState: one star opens the next mission, and a
## new stage of 7 needs 17 stars from the stage before. Only reads state, so the save file
## is never touched.
##   godot --headless --path . -s tests/progress_tests.gd
extends SceneTree
const Data = preload("res://scripts/core/data.gd")

var fails: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("FAIL  " + what)


func _initialize() -> void:
	var gs: Node = root.get_node("GameState")
	var ids: Array = Data.MISSIONS
	gs.mission_stars = {}
	check(gs.is_mission_open(str(ids[0])), "mission 1 is open at the start")
	check(not gs.is_mission_open(str(ids[1])), "mission 2 is locked at the start")
	gs.mission_stars[str(ids[0])] = 1
	check(gs.is_mission_open(str(ids[1])), "one star on mission 1 opens mission 2")
	check(gs.next_mission_id() == str(ids[1]), "next mission is mission 2")
	# fill stage 1 with 2 stars each: 14 stars, not enough for stage 2
	for i in range(7):
		gs.mission_stars[str(ids[i])] = 2
	check(not gs.is_mission_open(str(ids[7])), "14 of 21 stars keeps stage 2 locked")
	check(gs.lock_reason(str(ids[7])).contains("17"), "the lock reason names the 17 stars")
	for i in range(3):
		gs.mission_stars[str(ids[i])] = 3
	check(gs.stage_stars(0) == 17, "stage 1 now has 17 stars")
	check(gs.is_mission_open(str(ids[7])), "17 of 21 stars opens stage 2")
	check(not gs.is_mission_open(str(ids[8])), "mission 9 still needs a star on mission 8")
	check(gs.is_mission_open(str(ids[2])), "finished missions stay open for replay")
	check(gs.total_stars() == 17, "total stars")
	gs.mission_stars = {}
	print("PROGRESS TESTS PASSED" if fails.is_empty() else "%d progress test(s) failed" % fails.size())
	quit(0)
