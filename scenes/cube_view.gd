extends SubViewportContainer
## The 3D cube in its own little world. Swipe across a sticker to turn that
## row or column; drag the background to look around. Turns animate one after
## another from a queue. The view keeps its own copy of where each cubie is,
## so it can be animated while the game's model has already moved on.

signal turned(move: Dictionary)

const SIZE := 1.5
const DRAG_TURN := 22.0
const ORBIT_SENS := 0.01
const TURN_TIME := 0.16
const COLORS := {
	"U": Color("#f5f7f9"), "D": Color("#ffd500"), "F": Color("#00a651"),
	"B": Color("#2464d6"), "R": Color("#e0283c"), "L": Color("#ff7a1a"),
}

## Turning by swipe can be switched off (replays).
var interactive := true
## Controller turning (main.gd turns it on while a level is being played):
## a glowing sticker on the face looking at you. D-pad / left stick moves it;
## hold A and push a direction to turn that row or column that way, just like
## swiping it. The right stick looks around (always).
var pad_turns := false

const PAD_LOOK := 2.6
const PAD_DEAD := 0.5
const PAD_DIRS := {
	"ui_left": Vector2i(-1, 0), "ui_right": Vector2i(1, 0),
	"ui_up": Vector2i(0, 1), "ui_down": Vector2i(0, -1),
}
## The sticker cursor, in screen terms on the front face: x right, y up, -1..1.
var _cursor := Vector2i.ZERO
var _cursor_shown := false
var _a_held := false
var _dir_held := {}
## Right stick (events, not polling: in the office the pad only reaches this
## game while you sit at it).
var _look := Vector2.ZERO
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var yaw := 0.6
var pitch := 0.5

var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _pivot: Node3D
var _nodes: Array[Node3D] = []
var _queue: Array = []
var _anim := {}
var _press = null
var _mats := {}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.75
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 0.7
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 34
	_vp.add_child(_cam)
	_root = Node3D.new()
	_vp.add_child(_root)
	_pivot = Node3D.new()
	_root.add_child(_pivot)
	for k in COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[k]
		m.roughness = 0.45
		_mats[k] = m
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.6)
	_marker_mat.no_depth_test = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 0.86)
	_marker = MeshInstance3D.new()
	_marker.mesh = quad
	_marker.material_override = _marker_mat
	_marker.visible = false
	_vp.add_child(_marker)
	_place_camera()


## Rebuild the cubies to match a model, instantly.
func show_model(model: CubeModel) -> void:
	_queue.clear()
	_finish_anim()
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#101114")
	body_mat.roughness = 0.7
	var body := BoxMesh.new()
	body.size = Vector3.ONE * 0.96
	var sticker := BoxMesh.new()
	sticker.size = Vector3(0.84, 0.84, 0.03)
	for c in model.cubies:
		var n := Node3D.new()
		var b := MeshInstance3D.new()
		b.mesh = body
		b.material_override = body_mat
		n.add_child(b)
		for local in c.stickers:
			var s := MeshInstance3D.new()
			s.mesh = sticker
			s.material_override = _mats[c.stickers[local]]
			var d := Vector3(local)
			s.position = d * 0.485
			# Face the sticker outward along d.
			if abs(d.z) < 0.5:
				s.look_at_from_position(s.position, s.position + d, Vector3.UP if abs(d.y) < 0.5 else Vector3.BACK)
			n.add_child(s)
		n.position = Vector3(c.pos)
		n.basis = c.basis
		_root.add_child(n)
		_nodes.append(n)


func queue_turn(move: Dictionary, duration := TURN_TIME) -> void:
	_queue.append([move, duration])


func busy() -> bool:
	return not _queue.is_empty() or not _anim.is_empty()


func _process(delta: float) -> void:
	if _anim.is_empty() and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		_start_anim(next[0], next[1])
	if not _anim.is_empty():
		# Catch up quickly when turns pile up.
		var speed := 1.0 + _queue.size() * 0.75
		_anim.t = minf(1.0, _anim.t + delta * speed / maxf(_anim.duration, 0.001))
		var e: float = 1.0 - pow(1.0 - _anim.t, 3.0)
		_pivot.basis = Basis(CubeModel.axis_vector(_anim.move.axis), _anim.move.quarters * PI / 2.0 * e)
		if _anim.t >= 1.0:
			_finish_anim()
	if _look.length() > 0.2:
		yaw -= _look.x * PAD_LOOK * delta
		pitch = clampf(pitch - _look.y * PAD_LOOK * delta, -1.3, 1.3)
	_place_camera()
	_place_marker()


func _start_anim(move: Dictionary, duration: float) -> void:
	_pivot.basis = Basis.IDENTITY
	var list: Array[Node3D] = []
	for n in _nodes:
		var p := CubeModel._round_v(n.position)
		if CubeModel.coord(p, move.axis) in move.layers:
			list.append(n)
	for n in list:
		n.reparent(_pivot, true)
	_anim = {"move": move, "duration": duration, "t": 0.0, "list": list}


func _finish_anim() -> void:
	if _anim.is_empty():
		return
	_pivot.basis = Basis(CubeModel.axis_vector(_anim.move.axis), _anim.move.quarters * PI / 2.0)
	for n: Node3D in _anim.list:
		n.reparent(_root, true)
		n.position = Vector3(CubeModel._round_v(n.position))
		n.basis = CubeModel._round_b(n.basis)
	_pivot.basis = Basis.IDENTITY
	_anim = {}


func _place_camera() -> void:
	if _cam == null:
		return
	var r := 9.0
	_cam.position = Vector3(r * cos(pitch) * sin(yaw), r * sin(pitch), r * cos(pitch) * cos(yaw))
	_cam.look_at(Vector3.ZERO, Vector3.UP)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_cursor_shown = false
		return
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X:
			_look.x = event.axis_value
		elif event.axis == JOY_AXIS_RIGHT_Y:
			_look.y = event.axis_value
	if not pad_turns or not interactive:
		return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		_a_held = event.pressed
		_cursor_shown = true
		get_viewport().set_input_as_handled()
		return
	var used := false
	for action in PAD_DIRS:
		if not event.is_action(action) or event is InputEventKey and event.is_echo():
			continue
		used = true
		var on: bool = event.get_action_strength(action) > PAD_DEAD
		var was: bool = _dir_held.get(action, false)
		_dir_held[action] = on
		if on and not was:
			_pad_step(PAD_DIRS[action])
	if used:
		get_viewport().set_input_as_handled()


## The player is steering the cube with a controller.
func pad_active() -> bool:
	return _cursor_shown and pad_turns and interactive


## A direction on the pad: move the sticker cursor, or (A held) turn its row
## or column that way.
func _pad_step(dir: Vector2i) -> void:
	if not _cursor_shown:
		_cursor_shown = true
		return
	if not _a_held:
		_cursor = Vector2i(clampi(_cursor.x + dir.x, -1, 1), clampi(_cursor.y + dir.y, -1, 1))
		return
	var hit := _cursor_hit()
	var m := _swipe_move(hit, Vector2(dir.x, -dir.y) * 100.0)
	if not m.is_empty():
		turned.emit(m)


## The face looking at the camera: [normal axis, sign, right axis+sign, up axis+sign].
func _front() -> Dictionary:
	var c := _cam.position.normalized()
	var a := 0
	for i in 3:
		if absf(c[i]) > absf(c[a]):
			a = i
	var n := Vector3i.ZERO
	n[a] = 1 if c[a] > 0 else -1
	var center := Vector3(n) * SIZE
	var o := _cam.unproject_position(center)
	var right := Vector3i.ZERO
	var up := Vector3i.ZERO
	var best_x := 0.0
	for i in 3:
		if i == a:
			continue
		var t := Vector3.ZERO
		t[i] = 1.0
		var d := _cam.unproject_position(center + t) - o
		if absf(d.x) > absf(best_x):
			best_x = d.x
			right = Vector3i.ZERO
			right[i] = 1 if d.x > 0 else -1
	for i in 3:
		if i == a or right[i] != 0:
			continue
		var t := Vector3.ZERO
		t[i] = 1.0
		var d := _cam.unproject_position(center + t) - o
		up[i] = 1 if d.y < 0 else -1
	return {"n": n, "right": right, "up": up}


## The cursor's sticker as a swipe hit: {point, normal, cubie}.
func _cursor_hit() -> Dictionary:
	var f := _front()
	var cubie: Vector3i = f.n + f.right * _cursor.x + f.up * _cursor.y
	var point := Vector3(cubie)
	for i in 3:
		if f.n[i] != 0:
			point[i] = f.n[i] * SIZE
	return {"point": point, "normal": f.n, "cubie": cubie}


func _place_marker() -> void:
	if _marker == null:
		return
	_marker.visible = _cursor_shown and pad_turns and interactive
	if not _marker.visible:
		return
	var hit := _cursor_hit()
	var n := Vector3(hit.normal)
	_marker.position = hit.point + n * 0.03
	var up_hint := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	_marker.basis = Basis.looking_at(-n, up_hint)
	var pulse := 0.45 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
	_marker_mat.albedo_color = Color(1.0, 0.95, 0.5, pulse + (0.25 if _a_held else 0.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit = _hit(event.position)
			_press = {"at": event.position, "hit": hit, "done": false}
		else:
			_press = null
		accept_event()
	elif event is InputEventMouseMotion and _press != null:
		if _press.hit == null or not interactive:
			yaw -= event.relative.x * ORBIT_SENS
			pitch = clampf(pitch + event.relative.y * ORBIT_SENS, -1.3, 1.3)
		elif not _press.done and event.position.distance_to(_press.at) > DRAG_TURN:
			_press.done = true
			var m := _swipe_move(_press.hit, event.position - _press.at)
			if not m.is_empty():
				turned.emit(m)
		accept_event()


## Where a point on this control hits the cube: {point, normal, cubie} or null.
func _hit(at: Vector2):
	var px := at * Vector2(_vp.size) / size
	var o := _cam.project_ray_origin(px)
	var d := _cam.project_ray_normal(px)
	var tmin := -INF
	var tmax := INF
	var normal := Vector3i.ZERO
	for a in 3:
		if abs(d[a]) < 0.00001:
			if abs(o[a]) > SIZE:
				return null
			continue
		var t1 := (-SIZE - o[a]) / d[a]
		var t2 := (SIZE - o[a]) / d[a]
		var near := minf(t1, t2)
		if near > tmin:
			tmin = near
			normal = Vector3i.ZERO
			normal[a] = -1 if d[a] > 0 else 1
		tmax = minf(tmax, maxf(t1, t2))
	if tmin > tmax or tmax < 0:
		return null
	var p := o + d * tmin
	var cubie := Vector3i(clampi(roundi(p.x), -1, 1), clampi(roundi(p.y), -1, 1), clampi(roundi(p.z), -1, 1))
	return {"point": p, "normal": normal, "cubie": cubie}


## Which turn a swipe on a sticker means: the layer moves the way you swiped.
func _swipe_move(hit: Dictionary, drag: Vector2) -> Dictionary:
	var n: Vector3i = hit.normal
	var origin := _cam.unproject_position(hit.point)
	var best := Vector3.ZERO
	var best_dot := 0.0
	for a in 3:
		if n[a] != 0:
			continue
		var t := Vector3.ZERO
		t[a] = 1.0
		var sdir := _cam.unproject_position(hit.point + t * 0.5) - origin
		if sdir.length() < 0.001:
			continue
		var dt := drag.normalized().dot(sdir.normalized())
		if abs(dt) > abs(best_dot):
			best_dot = dt
			best = t * signf(dt)
	if best == Vector3.ZERO:
		return {}
	var axis_v := Vector3(n).cross(best)
	var axis := 0
	for a in 3:
		if abs(axis_v[a]) > 0.5:
			axis = a
	var quarters := 1 if axis_v[axis] > 0 else -1
	var layer := CubeModel.coord(hit.cubie, axis)
	return named({"axis": axis, "layers": [layer], "quarters": quarters})


## Give a turn its notation name (R, U', M...) for display and hints.
static func named(m: Dictionary) -> Dictionary:
	for letter in ["R", "L", "U", "D", "F", "B", "M", "E", "S"]:
		var d: Array = CubeMoves.DEF[letter]
		if d[0] == m.axis and d[1] == m.layers:
			m.name = letter + ("" if d[2] == m.quarters else "'")
	return m
