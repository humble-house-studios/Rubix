extends SceneTree
## Headless test runner. Usage:
##   godot --headless --path . -s tests/run_tests.gd
## Discovers tests/test_*.gd. Each extends RefCounted with
## `func run() -> Array[String]` returning failure messages.


func _init() -> void:
	var failures: Array[String] = []
	var files := 0
	var dir := DirAccess.open("res://tests")
	for file in dir.get_files():
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		files += 1
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failures.append("%s: failed to compile" % file)
			continue
		var suite: RefCounted = script.new()
		for msg: String in suite.run():
			failures.append("%s: %s" % [file, msg])

	for f in failures:
		printerr("FAIL  ", f)
	print("%d test files, %d failures" % [files, failures.size()])
	quit(1 if failures.size() > 0 else 0)
