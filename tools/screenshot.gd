extends SceneTree
## Renders Cube Desk screens to PNGs in $OUT (needs a display):
##   OUT=/dir xvfb-run -a -s "-screen 0 1280x1280x24" \
##     godot --rendering-driver opengl3 --resolution 720x1280 -s res://tools/screenshot.gd
## Shots: 0 title, 1 record replay mid-solve, 2 level 3 after a swipe,
## 3 solved, 4 level select. Prints what the swipe turned.

var main


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _f(15)
	await _shot(0)
	main._start_replay()
	await _f(110)
	await _shot(1)
	main._start_level(3)
	await _f(20)
	# Swipe right across the middle of the front face's top row.
	var v = main._view
	var top_front: Vector2 = v._cam.unproject_position(Vector3(0, 1, 1.5)) * v.size / Vector2(v._vp.size)
	_mouse(v, top_front, true)
	for k in 8:
		_motion(v, top_front + Vector2(k * 8, 0))
		await _f(1)
	_mouse(v, top_front + Vector2(64, 0), false)
	print("swipe made: ", main._history.map(func(m): return m.name))
	await _f(30)
	await _shot(2)
	while not main._game.solved:
		main._hint()
		await _f(12)
	await _f(150)
	await _shot(3)
	main._show_levels()
	await _f(10)
	await _shot(4)
	quit()


func _mouse(v, at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	v._gui_input(e)


func _motion(v, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.relative = Vector2(8, 0)
	v._gui_input(e)


func _f(n: int) -> void:
	for i in n:
		await process_frame


func _shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("OUT")
	root.get_texture().get_image().save_png("%s/shot_%d.png" % [out if out != "" else ".", i])
