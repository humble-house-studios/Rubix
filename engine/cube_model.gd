class_name CubeModel
extends RefCounted
## A 3x3 cube as 26 visible cubies, each with an integer position (-1..1 on
## every axis) and an orientation. Stickers are fixed on each cubie in its own
## space, so turning a layer just rotates positions and orientations.
## Axes match the 3D view: +x = right (R), +y = up (U), +z = front (F).

## Sticker colour per outward direction on a solved cube.
const FACE_COLORS := {
	Vector3i(1, 0, 0): "R", Vector3i(-1, 0, 0): "L",
	Vector3i(0, 1, 0): "U", Vector3i(0, -1, 0): "D",
	Vector3i(0, 0, 1): "F", Vector3i(0, 0, -1): "B",
}
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## Each: {home: Vector3i, pos: Vector3i, basis: Basis, stickers: {local dir: colour}}
var cubies: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	cubies.clear()
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				var p := Vector3i(x, y, z)
				if p == Vector3i.ZERO:
					continue
				var stickers := {}
				for d in DIRS:
					if (d.x != 0 and d.x == p.x) or (d.y != 0 and d.y == p.y) or (d.z != 0 and d.z == p.z):
						stickers[d] = FACE_COLORS[d]
				cubies.append({"home": p, "pos": p, "basis": Basis.IDENTITY, "stickers": stickers})


static func axis_vector(axis: int) -> Vector3:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][axis]


static func coord(v: Vector3i, axis: int) -> int:
	return [v.x, v.y, v.z][axis]


## Turn the given layers (-1, 0, 1 along axis) by quarter turns (+ = counter-
## clockwise looking down the positive axis, like Godot's rotations).
func turn(move: Dictionary) -> void:
	var rot := Basis(axis_vector(move.axis), move.quarters * PI / 2.0)
	for c in cubies:
		if coord(c.pos, move.axis) in move.layers:
			c.pos = _round_v(rot * Vector3(c.pos))
			c.basis = _round_b(rot * c.basis)


func apply_all(moves: Array) -> void:
	for m in moves:
		turn(m)


## Solved = every face shows one colour (whole-cube rotations don't matter).
func is_solved() -> bool:
	var seen := {}
	for c in cubies:
		for local in c.stickers:
			var world := _round_v(c.basis * Vector3(local))
			var col: String = c.stickers[local]
			if seen.has(world) and seen[world] != col:
				return false
			seen[world] = col
	return true


## Cubies a layer turn would move (for the view's animation).
func in_layers(move: Dictionary) -> Array:
	return cubies.filter(func(c): return coord(c.pos, move.axis) in move.layers)


static func _round_v(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x), roundi(v.y), roundi(v.z))


static func _round_b(b: Basis) -> Basis:
	return Basis(Vector3(_round_v(b.x)), Vector3(_round_v(b.y)), Vector3(_round_v(b.z)))
