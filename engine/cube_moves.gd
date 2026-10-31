class_name CubeMoves
extends RefCounted
## Cube notation <-> moves. A move is {axis: 0/1/2, layers: [ints], quarters: int}.
## Face letters turn clockwise looking at that face, like real cubing notation.

## letter -> [axis, layers, quarters for a clockwise turn]
const DEF := {
	"R": [0, [1], -1], "L": [0, [-1], 1],
	"U": [1, [1], -1], "D": [1, [-1], 1],
	"F": [2, [1], -1], "B": [2, [-1], 1],
	"M": [0, [0], 1], "E": [1, [0], 1], "S": [2, [0], -1],
	"r": [0, [0, 1], -1], "l": [0, [-1, 0], 1],
	"u": [1, [0, 1], -1], "d": [1, [-1, 0], 1],
	"f": [2, [0, 1], -1], "b": [2, [-1, 0], 1],
	"x": [0, [-1, 0, 1], -1], "y": [1, [-1, 0, 1], -1], "z": [2, [-1, 0, 1], -1],
}
const FACES := ["R", "L", "U", "D", "F", "B"]


static func parse(token: String) -> Dictionary:
	var letter := token.substr(0, 1)
	if not DEF.has(letter):
		return {}
	var d: Array = DEF[letter]
	var q: int = d[2]
	if token.contains("2"):
		q *= 2
	if token.contains("'"):
		q = -q
	return {"axis": d[0], "layers": d[1], "quarters": q, "name": token}


static func parse_alg(alg: String) -> Array:
	var out := []
	for t in alg.split(" ", false):
		var m := parse(t)
		if not m.is_empty():
			out.append(m)
	return out


static func inverse(m: Dictionary) -> Dictionary:
	var name: String = m.get("name", "")
	if name.contains("2"):
		pass
	elif name.ends_with("'"):
		name = name.trim_suffix("'")
	elif name != "":
		name += "'"
	return {"axis": m.axis, "layers": m.layers, "quarters": -m.quarters, "name": name}


## A move that does nothing (full turns) after normalising.
static func is_identity(m: Dictionary) -> bool:
	return posmod(m.quarters, 4) == 0


## True when b undoes a.
static func undoes(a: Dictionary, b: Dictionary) -> bool:
	return a.axis == b.axis and a.layers == b.layers and posmod(a.quarters + b.quarters, 4) == 0


## A random face-turn scramble: no two turns of the same axis in a row,
## so nothing cancels and every turn counts.
static func scramble(rng: RandomNumberGenerator, length: int) -> Array:
	var out := []
	var last_axis := -1
	while out.size() < length:
		var face: String = FACES[rng.randi_range(0, FACES.size() - 1)]
		var axis: int = DEF[face][0]
		if axis == last_axis:
			continue
		last_axis = axis
		var suffix: String = ["", "'", "2"][rng.randi_range(0, 2)] if length > 3 else ["", "'"][rng.randi_range(0, 1)]
		out.append(parse(face + suffix))
	return out


static func to_text(moves: Array) -> String:
	return " ".join(moves.map(func(m): return m.get("name", "?")))
