class_name CubeGame
extends RefCounted
## One attempt at a level: the scramble, your turns, the clock, undo, hints.
## The clock starts on your first turn. Hints make the next correct turn for
## you and add a time penalty.

## Level n is scrambled with LEVEL_MOVES[n - 1] turns; the boss is the record.
const LEVEL_MOVES := [1, 2, 3, 4, 5, 6, 7, 8]
const BOSS := 9
const HINT_PENALTY := 2.0
## Seconds per scramble turn for 3 stars / 2 stars (1 star = any solve).
const STAR3_PER_MOVE := 2.5
const STAR2_PER_MOVE := 5.0

var level := 1
var model := CubeModel.new()
var scramble: Array = []
## Turns that would undo everything since solved, newest last: hints pop it.
var trail: Array = []
var moves := 0
var hints := 0
var elapsed := 0.0
var started := false
var solved := false
var hint_penalty := HINT_PENALTY


func _init(p_level := 1, rng_seed := 0, penalty := HINT_PENALTY) -> void:
	level = p_level
	hint_penalty = penalty
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if level >= BOSS:
		scramble = CubeMoves.parse_alg(CubeRecord.SCRAMBLE)
	else:
		# Re-roll the rare scramble that happens to leave the cube solved.
		for i in 20:
			scramble = CubeMoves.scramble(rng, LEVEL_MOVES[level - 1])
			model.reset()
			model.apply_all(scramble)
			if not model.is_solved():
				break
	model.reset()
	model.apply_all(scramble)
	trail = scramble.duplicate()


static func level_name(n: int) -> String:
	return "THE 2.51 SCRAMBLE" if n >= BOSS else "LEVEL %d" % n


static func level_moves(n: int) -> int:
	return 19 if n >= BOSS else LEVEL_MOVES[n - 1]


## Seconds on the clock including hint penalties.
func time() -> float:
	return elapsed + hints * hint_penalty


func tick(delta: float) -> void:
	if started and not solved:
		elapsed += delta


## A turn by the player. Returns true if it solved the cube.
func play(move: Dictionary) -> bool:
	if solved:
		return false
	var whole_cube: bool = move.layers.size() == 3
	if not whole_cube:
		started = true
		moves += 1
	model.turn(move)
	if not trail.is_empty() and CubeMoves.undoes(trail[-1], move):
		trail.pop_back()
	else:
		trail.append(move)
	if model.is_solved():
		solved = true
		trail.clear()
	return solved


## The turn a hint makes: undo the newest thing still scrambled.
func hint_move() -> Dictionary:
	if trail.is_empty() or solved:
		return {}
	return CubeMoves.inverse(trail[-1])


func use_hint() -> Dictionary:
	var m := hint_move()
	if m.is_empty():
		return {}
	hints += 1
	play(m)
	return m


func stars() -> int:
	if not solved:
		return 0
	var n := level_moves(level)
	if level >= BOSS:
		# The boss: 3 stars under a minute, 2 under three minutes.
		return 3 if time() < 60.0 else (2 if time() < 180.0 else 1)
	if time() <= n * STAR3_PER_MOVE and hints == 0:
		return 3
	if time() <= n * STAR2_PER_MOVE:
		return 2
	return 1
