## Loads every script in the game and fails if any of them does not compile. A screen that
## does not compile shows nothing at all when the game goes to it, so run this before every
## merge (run_tests.gd only checks the rules, not the screens).
##   godot --headless --path . -s tests/load_check.gd
extends SceneTree


func _initialize() -> void:
	var bad: int = 0
	for dir in ["res://scripts", "res://scripts/screens", "res://scripts/ui", "res://scripts/core", "res://scripts/autoload"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var s: GDScript = load(dir + "/" + f)
			if s == null or not s.can_instantiate():
				print("BROKEN  " + dir + "/" + f)
				bad += 1
	print("LOAD CHECK PASSED" if bad == 0 else "LOAD CHECK: %d script(s) do not compile" % bad)
	quit(0 if bad == 0 else 1)
