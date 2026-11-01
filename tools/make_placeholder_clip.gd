extends SceneTree
## Films the placeholder record clip: an original blocky speedcuber at a
## competition table solves the record scramble on the real cube model, the
## timer stops at 2.51, then a slow-mo replay from a closer angle. Record with:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/clip.avi \
##     -s res://tools/make_placeholder_clip.gd
## then give it the camcorder look with ffmpeg and drop it in video/source/.

const CubeView := preload("res://scenes/cube_view.gd")
const CUBE_SCALE := 0.034
const CUBE_AT := Vector3(0, 1.0, -0.06)
const SHOULDER_Y := 1.3
const BODY_Z := -0.38
const FPS := 30.0

var view
var cam: Camera3D
var hands := {}
var arms := {}
var timer_label: Label3D
var caption: Label3D
var sched: Array
var t := 0.0
var speed := 1.0
var next := 0
var phase := "solve"


func _init() -> void:
	var holder_ui := Control.new()
	holder_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder_ui)
	view = CubeView.new()
	view.interactive = false
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder_ui.add_child(view)
	await process_frame
	view._vp.transparent_bg = false
	var m := CubeModel.new()
	m.apply_all(CubeMoves.parse_alg(CubeRecord.SCRAMBLE))
	view.show_model(m)
	_build_world()
	sched = CubeRecord.schedule()
	t = CubeRecord.INSPECT_FROM - 1.0
	_wide_shot()
	while t < CubeRecord.TIME + 1.4:
		await _step()
	# Slow-mo replay, closer in.
	m = CubeModel.new()
	m.apply_all(CubeMoves.parse_alg(CubeRecord.SCRAMBLE))
	view.show_model(m)
	phase = "replay"
	speed = 0.3
	next = 0
	t = -0.2
	_arms_down()
	_close_shot()
	caption.visible = true
	while t < CubeRecord.TIME + 0.45:
		await _step()
	quit()


func _step() -> void:
	var dt := 1.0 / FPS
	t += dt * speed
	while next < sched.size() and sched[next].start <= t:
		var e: Dictionary = sched[next]
		view.queue_turn(e.move, (e.end - e.start) / speed)
		next += 1
	var shown := clampf(t, 0.0, CubeRecord.TIME)
	timer_label.text = "%d.%02d" % [int(shown), int(round(fmod(shown, 1.0) * 100.0)) % 100]
	timer_label.modulate = Color("#ff3b30") if t < CubeRecord.TIME else Color("#ffd23f")
	var turning: bool = not view._anim.is_empty()
	var side := "R"
	if turning and view._anim.move.axis == 0:
		side = "L" if -1 in view._anim.move.layers else "R"
	var up := 0.0
	if phase == "solve" and t >= CubeRecord.TIME + 0.25:
		up = minf((t - CubeRecord.TIME - 0.25) / 0.35, 1.0)
	for k in ["L", "R"]:
		var flick := sin(t / speed * 55.0) * 0.012 if turning and k == side else 0.0
		_set_arm(k, up, flick)
	cam.position.x += sin(t * 2.3) * 0.0006
	await process_frame


func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	b.mesh = mesh
	b.material_override = _mat(color)
	b.position = pos
	parent.add_child(b)
	return b


func _build_world() -> void:
	var w: Node3D = Node3D.new()
	view._vp.add_child(w)
	view._cam.current = false
	cam = Camera3D.new()
	cam.fov = 40
	view._vp.add_child(cam)
	cam.current = true
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.6, 2.4, 1.2)
	lamp.omni_range = 6
	lamp.light_energy = 0.8
	w.add_child(lamp)

	# Hall: back wall, floor, banners, a second table out of focus.
	_box(w, Vector3(8, 4, 0.1), Vector3(0, 2, -2.2), Color("#e9e4da"))
	_box(w, Vector3(8, 0.1, 6), Vector3(0, -0.05, 0), Color("#5d6470"))
	for i in 5:
		var c: Color = [Color("#e8505b"), Color("#3ee6c1"), Color("#ffd23f"), Color("#4f7cff"), Color("#ff8c42")][i]
		_box(w, Vector3(0.7, 1.0, 0.03), Vector3(-2.4 + i * 1.2, 2.3, -2.13), c)
	_box(w, Vector3(1.6, 0.05, 0.7), Vector3(1.6, 0.75, -1.4), Color("#2d4a8a"))
	_person(w, Vector3(1.6, 0, -1.75), Color("#c45b3c"), Color("#d8a27c"), false)

	# Competition table, mat and timer.
	_box(w, Vector3(1.5, 0.05, 0.8), Vector3(0, 0.75, 0), Color("#2d4a8a"))
	_box(w, Vector3(1.5, 0.75, 0.04), Vector3(0, 0.375, 0.38), Color("#24407a"))
	_box(w, Vector3(0.5, 0.01, 0.32), Vector3(0, 0.78, 0.08), Color("#1c1d22"))
	var timer := _box(w, Vector3(0.22, 0.06, 0.1), Vector3(-0.34, 0.81, 0.2), Color("#141418"))
	timer.rotation.y = 0.35
	timer_label = Label3D.new()
	timer_label.text = "0.00"
	timer_label.font = load("res://fonts/press_start_2p.ttf")
	timer_label.font_size = 28
	timer_label.pixel_size = 0.0012
	timer_label.outline_size = 0
	timer_label.position = Vector3(0, 0.032, 0.051)
	timer_label.modulate = Color("#ff3b30")
	timer.add_child(timer_label)

	# The cuber (original, made of boxes) and the real cube in their hands.
	_person(w, Vector3(0, 0, BODY_Z), Color("#1fa58c"), Color("#c99a78"), true)
	var holder := Node3D.new()
	holder.position = CUBE_AT
	holder.scale = Vector3.ONE * CUBE_SCALE
	w.add_child(holder)
	view._root.reparent(holder, false)
	view._root.rotation = Vector3(0.25, -0.5, 0)

	caption = Label3D.new()
	caption.text = "REPLAY  0.3x"
	caption.font = load("res://fonts/press_start_2p.ttf")
	caption.font_size = 24
	caption.pixel_size = 0.0015
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.no_depth_test = true
	caption.position = Vector3(-0.12, 1.17, 0.0)
	caption.visible = false
	w.add_child(caption)


func _person(w: Node3D, at: Vector3, shirt: Color, skin: Color, main_one: bool) -> void:
	var p := Node3D.new()
	p.position = at
	w.add_child(p)
	_box(p, Vector3(0.3, 0.8, 0.2), Vector3(0, 0.4, 0), Color("#2b2f3a"))
	_box(p, Vector3(0.42, 0.56, 0.22), Vector3(0, 1.08, 0), shirt)
	_box(p, Vector3(0.1, 0.08, 0.1), Vector3(0, 1.39, 0), skin)
	var head := _box(p, Vector3(0.22, 0.25, 0.22), Vector3(0, 1.55, 0.01), skin)
	_box(head, Vector3(0.24, 0.07, 0.24), Vector3(0, 0.12, -0.01), Color("#2a1d16"))
	for x in [-0.05, 0.05]:
		_box(head, Vector3(0.03, 0.03, 0.01), Vector3(x, 0.02, 0.11), Color("#1b1b1b"))
	if not main_one:
		return
	head.rotation.x = 0.3
	for k in ["L", "R"]:
		var parts := []
		for i in 2:
			parts.append(_box(w, Vector3(0.085, 0.085, 1.0), Vector3.ZERO, shirt))
		var hand := _box(w, Vector3(0.05, 0.09, 0.08), Vector3.ZERO, skin)
		arms[k] = parts
		hands[k] = hand
		_set_arm(k, 0.0, 0.0)


## Shoulder -> elbow -> hand. up = 0: hands on the cube's sides; 1: arms in the air.
func _set_arm(k: String, up: float, flick: float) -> void:
	var sx := -1.0 if k == "L" else 1.0
	var s := Vector3(0.24 * sx, SHOULDER_Y, BODY_Z)
	var half := 1.5 * CUBE_SCALE + 0.03
	var hold := CUBE_AT + Vector3(half * sx, flick, 0.0)
	var cheer := Vector3(0.3 * sx, 1.95, BODY_Z + 0.05)
	var h := hold.lerp(cheer, up)
	var e := (s + h) * 0.5 + Vector3(0.1 * sx, lerpf(-0.16, 0.05, up), lerpf(-0.02, 0.0, up))
	_limb(arms[k][0], s, e)
	_limb(arms[k][1], e, h)
	hands[k].position = h
	hands[k].rotation.x = flick * 25.0


func _limb(b: MeshInstance3D, a: Vector3, c: Vector3) -> void:
	b.position = (a + c) * 0.5
	b.scale = Vector3(1, 1, maxf(a.distance_to(c), 0.01))
	b.look_at_from_position(b.position, c, Vector3.UP)


func _arms_down() -> void:
	for k in ["L", "R"]:
		_set_arm(k, 0.0, 0.0)


func _wide_shot() -> void:
	cam.position = Vector3(0.78, 1.48, 1.2)
	cam.look_at(Vector3(-0.06, 1.2, -0.25), Vector3.UP)


func _close_shot() -> void:
	cam.position = Vector3(0.2, 1.1, 0.3)
	cam.look_at(CUBE_AT, Vector3.UP)
