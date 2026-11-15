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
	# the web build leaves out files matched by the export preset's exclude filter: a script
	# that loads one of those works on the desktop but breaks in the browser
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("res://docs/export_presets.web.cfg") == OK:
		var excluded: PackedStringArray = str(cfg.get_value("preset.0", "exclude_filter", "")).split(",", false)
		var re: RegEx = RegEx.create_from_string("(?:preload|load)\\(\"(res://[^\"]+)\"\\)")
		for dir in ["res://scripts", "res://scripts/screens", "res://scripts/ui", "res://scripts/core", "res://scripts/autoload"]:
			for f in DirAccess.get_files_at(dir):
				if not f.ends_with(".gd"):
					continue
				var text: String = FileAccess.get_file_as_string(dir + "/" + f)
				for m in re.search_all(text):
					var used: String = m.get_string(1).trim_prefix("res://")
					for pat in excluded:
						if used.match(pat.strip_edges()):
							print("WEB BUILD LEAVES OUT  %s (loaded by %s/%s)" % [used, dir, f])
							bad += 1
	print("LOAD CHECK PASSED" if bad == 0 else "LOAD CHECK: %d problem(s)" % bad)
	quit(0 if bad == 0 else 1)
