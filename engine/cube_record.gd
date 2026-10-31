class_name CubeRecord
extends RefCounted
## The 3x3 single world record: Xuanyi Geng, 2.51 s, Guangzhou Grand Open 2026.
## Official scramble plus the community reconstruction (Ruwix), with the
## reconstruction's step splits: F2L done at 1.23 s, last layer from 1.41 s.

const HOLDER := "XUANYI GENG"
const TIME := 2.51
const EVENT := "GUANGZHOU GRAND OPEN 2026"
const SCRAMBLE := "B2 D2 B2 D R2 U' F2 D' U' B' D2 B2 U2 R2 D F D' F2 R"
## [step name, moves]
const STEPS := [
	["INSPECTION", "x' z'"],
	["DOUBLE X-CROSS", "U' r' R2 U' R2' D' R2 U R' U' D'"],
	["3RD PAIR", "R' U' R"],
	["4TH PAIR", "L' U' L"],
	["LAST LAYER", "R' U R U R' U2 R U R D R' U2 R D' R'"],
]
const F2L_END := 1.23
const LL_START := 1.41
## Inspection turns play before the clock starts (negative times).
const INSPECT_FROM := -1.25


## Every move with its start/end time and step index:
## [{move, start, end, step}]. Half turns get a bit more time.
static func schedule() -> Array:
	var out := []
	for si in STEPS.size():
		for m in CubeMoves.parse_alg(STEPS[si][1]):
			out.append({"move": m, "step": si, "start": 0.0, "end": 0.0})
	out[0].start = -1.25
	out[0].end = -0.85
	out[1].start = -0.7
	out[1].end = -0.3
	_spread(out.filter(func(e): return e.step >= 1 and e.step <= 3), 0.0, F2L_END)
	_spread(out.filter(func(e): return e.step == 4), LL_START, TIME)
	return out


static func _spread(list: Array, a: float, b: float) -> void:
	var weight := func(e): return 1.4 if abs(e.move.quarters) == 2 else 1.0
	var total := 0.0
	for e in list:
		total += weight.call(e)
	var t := a
	for e in list:
		var d: float = (b - a) * weight.call(e) / total
		e.start = t
		e.end = t + d
		t += d


static func solution() -> Array:
	return schedule().map(func(e): return e.move)
