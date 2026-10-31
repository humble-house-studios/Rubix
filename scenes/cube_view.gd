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
	_place_camera()


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
