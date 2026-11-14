extends SceneTree
## Headless test runner.
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 means every check passed.

const SimTests = preload("res://tests/sim_tests.gd")


func _init() -> void:
	var fails: Array = SimTests.run()
	if fails.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		for line in fails:
			print("FAIL  " + str(line))
		print("%d test(s) failed" % fails.size())
		quit(1)
