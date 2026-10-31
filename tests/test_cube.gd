extends RefCounted
## The cube model, notation, the record solve and the level game.

var _fails: Array[String] = []


func run() -> Array[String]:
	_model()
	_notation()
	_record()
	_game()
	_hints()
	return _fails


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _model() -> void:
	var m := CubeModel.new()
	_check(m.cubies.size() == 26, "26 cubies")
	_check(m.is_solved(), "starts solved")
	m.turn(CubeMoves.parse("R"))
	_check(not m.is_solved(), "R scrambles it")
	m.turn(CubeMoves.parse("R'"))
	_check(m.is_solved(), "R' undoes R")
	for face in ["R", "L", "U", "D", "F", "B", "M", "E", "S", "r"]:
		m.reset()
		for i in 4:
			m.turn(CubeMoves.parse(face))
		_check(m.is_solved(), "%s four times is solved" % face)
		m.reset()
		m.turn(CubeMoves.parse(face + "2"))
		m.turn(CubeMoves.parse(face + "2"))
		_check(m.is_solved(), "%s2 twice is solved" % face)
	m.reset()
	m.turn(CubeMoves.parse("x"))
	m.turn(CubeMoves.parse("y'"))
	_check(m.is_solved(), "whole-cube turns keep it solved")
	# The sexy move (R U R' U') six times is the identity.
	m.reset()
	for i in 6:
		m.apply_all(CubeMoves.parse_alg("R U R' U'"))
	_check(m.is_solved(), "(R U R' U') x6 is solved")
	m.reset()
	m.apply_all(CubeMoves.parse_alg("R U R' U'"))
	_check(not m.is_solved(), "(R U R' U') once is not")
	# Clockwise check: R moves the front-right-top corner to the back (up face).
	m.reset()
	m.turn(CubeMoves.parse("R"))
	var c = m.cubies.filter(func(c): return c.home == Vector3i(1, 1, 1))[0]
	_check(c.pos == Vector3i(1, 1, -1), "R takes the UFR corner to UBR: %s" % [c.pos])


func _notation() -> void:
	var r := CubeMoves.parse("R'")
	_check(r.axis == 0 and r.quarters == 1 and r.layers == [1], "R' parses")
	_check(CubeMoves.inverse(CubeMoves.parse("U")).name == "U'", "inverse name")
	_check(CubeMoves.undoes(CubeMoves.parse("F2"), CubeMoves.parse("F2")), "F2 undoes F2")
	_check(CubeMoves.parse_alg(CubeRecord.SCRAMBLE).size() == 19, "record scramble is 19 turns")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := CubeMoves.scramble(rng, 25)
	for i in range(1, s.size()):
		_check(s[i].axis != s[i - 1].axis, "no same-axis turns in a row")


func _record() -> void:
	var m := CubeModel.new()
	m.apply_all(CubeMoves.parse_alg(CubeRecord.SCRAMBLE))
	_check(not m.is_solved(), "record scramble is scrambled")
	var sched := CubeRecord.schedule()
	_check(sched.size() == 34, "2 inspection turns + 32 solve turns: %d" % sched.size())
	m.apply_all(CubeRecord.solution())
	_check(m.is_solved(), "the 2.51 reconstruction solves the official scramble")
	_check(is_equal_approx(sched[-1].end, CubeRecord.TIME), "last turn ends at 2.51")
	for i in range(1, sched.size()):
		_check(sched[i].start >= sched[i - 1].end - 0.0001, "turns don't overlap (%d)" % i)


func _game() -> void:
	for lvl in range(1, CubeGame.BOSS + 1):
		var g := CubeGame.new(lvl, lvl * 11)
		_check(not g.model.is_solved(), "level %d starts scrambled" % lvl)
		_check(g.scramble.size() == CubeGame.level_moves(lvl), "level %d has %d turns" % [lvl, CubeGame.level_moves(lvl)])
	var g := CubeGame.new(3, 5)
	_check(not g.started, "clock waits")
	g.tick(1.0)
	_check(g.elapsed == 0.0, "clock waits for the first turn")
	# Undo the scramble by hand.
	var rev := g.scramble.duplicate()
	rev.reverse()
	for i in rev.size():
		var done := g.play(CubeMoves.inverse(rev[i]))
		g.tick(0.5)
		_check(done == (i == rev.size() - 1), "solved only on the last turn")
	_check(g.solved and g.moves == 3, "solved in 3")
	_check(g.stars() == 3, "fast and no hints = 3 stars: %d" % g.stars())


func _hints() -> void:
	var g := CubeGame.new(5, 9)
	g.play(CubeMoves.parse("R"))
	g.play(CubeMoves.parse("U2"))
	var n := 0
	while not g.solved and n < 50:
		g.use_hint()
		n += 1
	_check(g.solved, "hints always lead back to solved")
	_check(n == 7, "5 scramble turns + 2 wrong turns = 7 hints: %d" % n)
	_check(g.hints == 7 and g.time() == 7 * CubeGame.HINT_PENALTY, "hints cost time")
	_check(g.stars() < 3, "no 3 stars with hints")
	var b := CubeGame.new(CubeGame.BOSS)
	_check(CubeMoves.to_text(b.scramble) == CubeRecord.SCRAMBLE, "boss is the record scramble")
