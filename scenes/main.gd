extends Control
## Cube Desk: watch the 2.51 world record on a 3D cube, then climb a ladder of
## levels (1 scrambled turn, 2 turns... up to 8, then the record's own scramble).
## Swipe a row to turn it, drag the background to look around.
## Upright: cube on top, buttons below. Sideways: side by side.

const CubeView := preload("res://scenes/cube_view.gd")

const COLOR_INK := Color("#e7ecff")
const COLOR_DIM := Color(0.9, 0.93, 1.0, 0.55)
const COLOR_GOLD := Color("#ffd23f")
const COLOR_TEAL := Color("#3ee6c1")
const COLOR_RED := Color("#ff5d73")
const SAVE_PATH := "user://cube_desk.cfg"
const SAVE_VERSION := 1
const SFX := ["turn", "tap", "star", "solved", "beep"]
## Real turns per second in the record solve (32 turns / 2.51 s).
const RECORD_TPS := 12.75

var _font: Font = preload("res://fonts/press_start_2p.ttf")

## Levels solved so far, total, and the last one (read by the office link).
var solves := 0
var last_level := 0
## Seconds a hint costs (an office relic can lower it).
var hint_penalty := CubeGame.HINT_PENALTY
var _stars := {}
var _game: CubeGame
var _history: Array = []
## Replay of the record: null when not watching.
var _replay = null
var _sfx := {}

var _body: BoxContainer
var _view: CubeView
var _panel: VBoxContainer
var _title: Label
var _clock: Label
var _info: Label
var _coach: Label
var _buttons: HBoxContainer
var _overlay: ColorRect
var _overlay_box: VBoxContainer
var _pad: Node


func _ready() -> void:
	_load()
	for id in SFX:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % id)
		add_child(p)
		_sfx[id] = p
	_build_ui()
	# Controller / arrow keys: a frame that moves between buttons, A presses.
	# While a level is played the cube takes the D-pad and A instead.
	_pad = preload("res://scenes/cube_pad.gd").new()
	add_child(_pad)
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	_show_title()


# ---------------------------------------------------------------- layout

func _owns_window() -> bool:
	return get_viewport() == get_window()


func _on_resized() -> void:
	var s := get_viewport_rect().size
	var landscape := s.x > s.y
	var base := Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	if _owns_window() and get_window().content_scale_size != base:
		get_window().content_scale_size = base
	_body.vertical = not landscape
	_view.size_flags_stretch_ratio = 1.5 if landscape else 1.6


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = ShaderMaterial.new()
	bg.material.shader = preload("res://scenes/backdrop.gdshader")
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	margin.add_child(_body)

	_view = CubeView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(300, 300)
	_view.turned.connect(_on_turn)
	_body.add_child(_view)

	_panel = VBoxContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 12)
	_body.add_child(_panel)
	_title = _label("", 24, COLOR_GOLD)
	_panel.add_child(_title)
	_clock = _label("0.00", 64, COLOR_INK)
	_panel.add_child(_clock)
	_info = _label("", 18, COLOR_DIM)
	_panel.add_child(_info)
	_coach = _label("", 16, COLOR_TEAL)
	_coach.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(_coach)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_panel.add_child(_buttons)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.04, 0.08, 0.93)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 36)
	scroll.add_child(pad)
	_overlay_box = VBoxContainer.new()
	_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay_box.add_theme_constant_override("separation", 18)
	pad.add_child(_overlay_box)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_constant_override("line_spacing", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, COLOR_INK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color.darkened(0.55)
	normal.border_color = color
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	for k in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, normal)
	var down := normal.duplicate()
	down.bg_color = color.darkened(0.2)
	b.add_theme_stylebox_override("pressed", down)
	var off := normal.duplicate()
	off.bg_color = Color(0.1, 0.11, 0.16)
	off.border_color = Color(0.25, 0.27, 0.35)
	b.add_theme_stylebox_override("disabled", off)
	b.pressed.connect(_play.bind("tap"))
	return b


func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _sfx.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()


func _set_buttons(list: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	for b in list:
		_buttons.add_child(b)


# ---------------------------------------------------------------- save

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_stars = cfg.get_value("progress", "stars", {})
	solves = int(cfg.get_value("progress", "solves", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", SAVE_VERSION)
	cfg.set_value("progress", "stars", _stars)
	cfg.set_value("progress", "solves", solves)
	cfg.save(SAVE_PATH)


func _stars_for(level: int) -> int:
	return int(_stars.get(level, 0))


func _unlocked(level: int) -> bool:
	return level == 1 or _stars_for(level - 1) > 0


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if _replay != null:
		_tick_replay(delta)
	elif _game != null and not _overlay.visible:
		_game.tick(delta)
		if _game.moves == 0 and _game.level == 1:
			_refresh_play()
		_clock.text = "%.2f" % _game.time()
		_clock.add_theme_color_override("font_color", COLOR_TEAL if _game.started else COLOR_INK)


# ---------------------------------------------------------------- title

func _open_overlay() -> void:
	for c in _overlay_box.get_children():
		c.queue_free()
	_overlay.visible = true
	_pad_play(false)


## Hand the D-pad and A to the cube (playing a level) or to the menus.
func _pad_play(on: bool) -> void:
	_view.pad_turns = on
	if _pad:
		_pad.hold = on


func _show_title() -> void:
	_replay = null
	_game = null
	var m := CubeModel.new()
	m.apply_all(CubeMoves.parse_alg(CubeRecord.SCRAMBLE))
	_view.show_model(m)
	_open_overlay()
	_overlay_box.add_child(_label("CUBE\nDESK", 64, COLOR_GOLD))
	_overlay_box.add_child(_label("WORLD RECORD  %.2f\n%s" % [CubeRecord.TIME, CubeRecord.HOLDER], 20, COLOR_TEAL))
	var watch := _button("WATCH THE 2.51", COLOR_TEAL, 24)
	watch.custom_minimum_size.y = 110
	watch.pressed.connect(_start_replay)
	watch.set_meta("pad_button", JOY_BUTTON_Y)
	_overlay_box.add_child(watch)
	var play := _button("PLAY", COLOR_GOLD, 32)
	play.custom_minimum_size.y = 120
	play.pressed.connect(_show_levels)
	play.set_meta("pad_button", JOY_BUTTON_START)
	play.set_meta("pad_default", true)
	_overlay_box.add_child(play)
	var total := 0
	for l in _stars:
		total += int(_stars[l])
	_overlay_box.add_child(_label("STARS %d/%d" % [total, CubeGame.BOSS * 3], 18, COLOR_DIM))


func _show_levels() -> void:
	_open_overlay()
	_overlay_box.add_child(_label("PICK A LEVEL", 36, COLOR_GOLD))
	_overlay_box.add_child(_label("Each level is scrambled one more turn. Undo them all.", 16, COLOR_DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for lvl in range(1, CubeGame.BOSS):
		var st := _stars_for(lvl)
		var b := _button("%d\n%s" % [lvl, "*".repeat(st) + "-".repeat(3 - st)], COLOR_GOLD if st > 0 else COLOR_TEAL, 24)
		b.custom_minimum_size = Vector2(150, 120)
		b.disabled = not _unlocked(lvl)
		b.pressed.connect(_start_level.bind(lvl))
		grid.add_child(b)
	_overlay_box.add_child(grid)
	var boss_st := _stars_for(CubeGame.BOSS)
	var boss := _button("THE 2.51 SCRAMBLE  %s" % ("*".repeat(boss_st) + "-".repeat(3 - boss_st)), COLOR_RED, 20)
	boss.disabled = not _unlocked(CubeGame.BOSS)
	boss.pressed.connect(_start_level.bind(CubeGame.BOSS))
	_overlay_box.add_child(boss)
	if not _unlocked(CubeGame.BOSS):
		_overlay_box.add_child(_label("Beat level 8 to face the real record scramble.", 14, COLOR_DIM))
	var back := _button("BACK", COLOR_DIM, 20)
	back.pressed.connect(_show_title)
	back.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(back)


# ---------------------------------------------------------------- watch

func _start_replay() -> void:
	_overlay.visible = false
	_game = null
	_view.interactive = false
	_pad_play(false)
	var m := CubeModel.new()
	m.apply_all(CubeMoves.parse_alg(CubeRecord.SCRAMBLE))
	_view.show_model(m)
	_replay = {"t": CubeRecord.INSPECT_FROM - 0.6, "speed": 1.0, "next": 0, "sched": CubeRecord.schedule(), "beeped": false}
	_title.text = "%s  %.2f" % [CubeRecord.HOLDER, CubeRecord.TIME]
	_info.text = CubeRecord.EVENT
	_coach.text = "DRAG TO LOOK AROUND"
	var real := _button("REAL SPEED", COLOR_TEAL, 18)
	real.pressed.connect(_restart_replay.bind(1.0))
	var slow := _button("SLOW-MO", COLOR_GOLD, 18)
	slow.pressed.connect(_restart_replay.bind(0.2))
	var back := _button("BACK", COLOR_DIM, 18)
	back.pressed.connect(_show_title)
	back.set_meta("pad_button", JOY_BUTTON_B)
	_set_buttons([real, slow, back])


func _restart_replay(speed: float) -> void:
	_start_replay()
	_replay.speed = speed


func _tick_replay(delta: float) -> void:
	var r: Dictionary = _replay
	r.t += delta * r.speed
	var sched: Array = r.sched
	while r.next < sched.size() and sched[r.next].start <= r.t:
		var e: Dictionary = sched[r.next]
		_view.queue_turn(e.move, (e.end - e.start) / r.speed)
		_play("turn", randf_range(0.9, 1.15))
		r.next += 1
	if r.t >= 0.0 and not r.beeped:
		r.beeped = true
		_play("beep")
	var shown := clampf(r.t, 0.0, CubeRecord.TIME)
	_clock.text = "%.2f" % shown
	var step := "INSPECTION"
	if r.t >= CubeRecord.TIME:
		step = "SOLVED!"
	elif r.next > 0:
		step = CubeRecord.STEPS[sched[r.next - 1].step][0]
		if r.t > CubeRecord.F2L_END and r.t < CubeRecord.LL_START:
			step = "SPOTTING THE LAST LAYER"
	_clock.add_theme_color_override("font_color", COLOR_GOLD if r.t >= CubeRecord.TIME else (COLOR_TEAL if r.t >= 0 else COLOR_INK))
	var now: String = "" if r.next == 0 else sched[r.next - 1].move.name
	_coach.text = "%s\n\n%s" % [step, now if r.t < CubeRecord.TIME else "32 TURNS. 12.75 PER SECOND."]
	if r.t >= CubeRecord.TIME + 0.05 and not r.has("done"):
		r.done = true
		_play("solved")


# ---------------------------------------------------------------- play

func _start_level(level: int) -> void:
	_replay = null
	_game = CubeGame.new(level, randi(), hint_penalty)
	_history.clear()
	_view.interactive = true
	_view.show_model(_game.model)
	_overlay.visible = false
	_pad_play(true)
	_title.text = CubeGame.level_name(level)
	_clock.text = "0.00"
	_refresh_play()
	var undo := _button("UNDO", COLOR_DIM, 20)
	undo.pressed.connect(_undo)
	undo.set_meta("pad_button", JOY_BUTTON_X)
	var hint := _button("HINT +%ds" % int(hint_penalty), COLOR_GOLD, 20)
	hint.pressed.connect(_hint)
	hint.set_meta("pad_button", JOY_BUTTON_Y)
	var back := _button("MENU", COLOR_RED, 20)
	back.pressed.connect(_show_levels)
	back.set_meta("pad_button", JOY_BUTTON_B)
	_set_buttons([undo, hint, back])


func _refresh_play() -> void:
	if _game == null:
		return
	var n := CubeGame.level_moves(_game.level)
	_info.text = "SCRAMBLED %d TURN%s   YOUR TURNS %d" % [n, "" if n == 1 else "S", _game.moves]
	if _game.level == 1 and _game.moves == 0 and _view.pad_active():
		_coach.text = "HOLD A AND PUSH A DIRECTION TO TURN THAT ROW.\nRIGHT STICK LOOKS AROUND."
	elif _game.level == 1 and _game.moves == 0:
		_coach.text = "SWIPE ACROSS A ROW TO TURN IT.\nDRAG THE BACKGROUND TO LOOK AROUND."
	elif _game.level <= 2:
		_coach.text = "STUCK? TAP HINT AND WATCH WHICH WAY IT TURNS."
	elif _game.level >= CubeGame.BOSS:
		_coach.text = "THE EXACT SCRAMBLE XUANYI SOLVED IN 2.51.\nHINTS WALK YOU BACK ONE TURN AT A TIME."
	else:
		_coach.text = "THE CLOCK STARTS ON YOUR FIRST TURN."


func _on_turn(move: Dictionary) -> void:
	if _game == null or _game.solved or _overlay.visible:
		return
	_history.append(move)
	_apply(move)


func _apply(move: Dictionary) -> void:
	var won := _game.play(move)
	_view.queue_turn(move)
	_play("turn", randf_range(0.9, 1.15))
	_refresh_play()
	if won:
		_on_solved()


func _undo() -> void:
	if _game == null or _game.solved or _history.is_empty():
		return
	_apply(CubeMoves.inverse(_history.pop_back()))


func _hint() -> void:
	if _game == null or _game.solved:
		return
	var m := _game.hint_move()
	if m.is_empty():
		return
	_game.hints += 1
	_history.append(m)
	_apply(m)


func _on_solved() -> void:
	solves += 1
	last_level = _game.level
	var st := _game.stars()
	var best := maxi(st, _stars_for(_game.level))
	_stars[_game.level] = best
	_save()
	_play("solved")
	await get_tree().create_timer(0.9).timeout
	_open_overlay()
	_overlay_box.add_child(_label("SOLVED!", 56, COLOR_GOLD))
	var stars_label := _label("", 56, COLOR_GOLD)
	_overlay_box.add_child(stars_label)
	_overlay_box.add_child(_label("%.2f s   %d TURNS%s" % [_game.time(), _game.moves, "   %d HINT%s" % [_game.hints, "" if _game.hints == 1 else "S"] if _game.hints else ""], 20, COLOR_INK))
	_overlay_box.add_child(_label("Xuanyi would have taken %.2f s." % (_game.moves / RECORD_TPS), 16, COLOR_DIM))
	if _game.level < CubeGame.BOSS:
		var next := _button("NEXT LEVEL", COLOR_GOLD, 26)
		next.pressed.connect(_start_level.bind(_game.level + 1))
		next.set_meta("pad_default", true)
		next.set_meta("pad_button", JOY_BUTTON_START)
		_overlay_box.add_child(next)
	else:
		_overlay_box.add_child(_label("YOU SOLVED THE WORLD RECORD SCRAMBLE.", 18, COLOR_TEAL))
	var again := _button("TRY AGAIN", COLOR_TEAL, 20)
	again.pressed.connect(_start_level.bind(_game.level))
	_overlay_box.add_child(again)
	var menu := _button("LEVELS", COLOR_DIM, 20)
	menu.pressed.connect(_show_levels)
	menu.set_meta("pad_button", JOY_BUTTON_B)
	_overlay_box.add_child(menu)
	# Stars pop in one at a time.
	for i in 3:
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(stars_label):
			return
		stars_label.text = "*".repeat(mini(i + 1, st)) + "-".repeat(3 - mini(i + 1, st))
		if i < st:
			_play("star", 1.0 + i * 0.12)
