## Opens the game, plays some sols, and saves a screenshot. Needs a window (not --headless).
##   godot --path . --script res://tests/screenshot.gd -- out=/tmp/shot.png sols=3 mode=moon
## Optional: build=solar_panel,electrolyzer orders those modules on each sol before ending it.
extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := {"out": "user://screenshot.png", "sols": "0", "mode": "mars", "build": "", "tutorial": "1"}
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	main.scenario_id = args.mode
	main.tutorial_on = args.tutorial == "1"
	root.add_child(main)
	await process_frame
	for i in int(args.sols):
		if args.build != "" and main.has_method("plan_build"):
			for id in args.build.split(","):
				main.plan_build(id)
		main.end_sol()
	# Wait until the frame has really been drawn before grabbing it.
	for i in 3:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args.out)
	print("Saved ", args.out)
	quit()
