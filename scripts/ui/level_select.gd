extends Control
## 5 worlds x 4 levels. Arrows/WASD + Enter, or click. Esc goes back.
## U unlocks everything (handy while testing).

const BIOME_OF := ["desert", "jungle", "mountain", "snow", "volcano", "moon", "border"]
const CELL := Vector2(66, 22)
const ORIGIN := Vector2(98, 36)

var sel := 0
var _cells: Array[Dictionary] = []
var _info_title: Label
var _info_blurb: Label
var _info_best: Label
var _sky_layer: CanvasLayer
var _shown_world := -1


func _ready() -> void:
	sel = clampi(GameState.current_level, 0, GameState.unlocked - 1)
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -10
	add_child(_sky_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.02, 0.1, 0.45)
	shade.size = Vector2(480, 270)
	add_child(shade)
	_text("LEVEL SELECT", Vector2(0, 10), 16, Color("#ffcc26"), 4, 480)
	for w in BIOME_OF.size():
		_text(Levels.WORLDS[w], Vector2(8, ORIGIN.y + w * CELL.y + 9), 8, Color("#3cf0dc"), 2, 90).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		for l in 4:
			var i := w * 4 + l
			if i >= Levels.count():
				break
			var pos := ORIGIN + Vector2(l * (CELL.x + 6), w * CELL.y)
			var box := ColorRect.new()
			box.position = pos
			box.size = CELL - Vector2(0, 4)
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			box.gui_input.connect(_on_cell_input.bind(i))
			add_child(box)
			var code := _text(Levels.code(i), pos + Vector2(0, 4), 8, Color.WHITE, 2, CELL.x)
			var stars := _text("", pos + Vector2(0, 11), 8, Color("#ffcc26"), 2, CELL.x)
			_cells.append({"box": box, "code": code, "stars": stars})
	_info_title = _text("", Vector2(0, 202), 8, Color("#ffcc26"), 2, 480)
	_info_blurb = _text("", Vector2(0, 216), 8, Color.WHITE, 2, 480)
	_info_best = _text("", Vector2(0, 230), 8, Color("#7dff6a"), 2, 480)
	_text("ENTER PLAY   ESC BACK   U UNLOCK ALL (TESTING)", Vector2(0, 254), 8, Color(1, 1, 1, 0.4), 0, 480)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key: int = event.physical_keycode if event is InputEventKey else 0
	var move := Vector2i.ZERO
	if event.is_action_pressed("ui_right") or key == KEY_D:
		move.x = 1
	elif event.is_action_pressed("ui_left") or key == KEY_A:
		move.x = -1
	elif event.is_action_pressed("ui_down") or key == KEY_S:
		move.y = 1
	elif event.is_action_pressed("ui_up") or key == KEY_W:
		move.y = -1
	elif event.is_action_pressed("ui_accept"):
		_play(sel)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Audio.play("ui_back", -4.0)
		Transition.go("res://scenes/main_menu.tscn")
	elif key == KEY_U:
		GameState.unlocked = Levels.count()
		GameState.save()
		Audio.play("star", -4.0)
		_refresh()
	if move != Vector2i.ZERO:
		var col := clampi(sel % 4 + move.x, 0, 3)
		var row := clampi(sel / 4 + move.y, 0, BIOME_OF.size() - 1)
		sel = mini(row * 4 + col, Levels.count() - 1)
		Audio.play("ui_move", -8.0)
		_refresh()


func _on_cell_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sel == i:
			_play(i)
		else:
			sel = i
			Audio.play("ui_move", -8.0)
			_refresh()


var _leaving := false


func _play(i: int) -> void:
	if _leaving:
		return
	if i >= GameState.unlocked:
		Audio.play("sting_hard", -6.0)
		return
	_leaving = true
	Audio.play("ui_select", -4.0)
	GameState.current_level = i
	GameState.checkpoint = {}
	Transition.go("res://scenes/level.tscn")


func _refresh() -> void:
	for i in _cells.size():
		var c := _cells[i]
		var locked := i >= GameState.unlocked
		var s: int = GameState.stars.get(i, 0)
		c.box.color = Color("#ffcc26") if i == sel else (Color(0.1, 0.06, 0.16, 0.9) if not locked else Color(0.05, 0.03, 0.08, 0.8))
		c.code.label_settings.font_color = Color("#1a0f29") if i == sel else (Color.WHITE if not locked else Color(1, 1, 1, 0.3))
		var g: String = GameState.grades.get(i, "")
		c.stars.text = "LOCKED" if locked else "*".repeat(s) + "-".repeat(3 - s) + (" " + g if g != "" else "")
		c.stars.label_settings.font_color = Color("#1a0f29") if i == sel else Color("#ffcc26")
	var def := Levels.get_level(sel)
	_info_title.text = "%s  %s" % [Levels.code(sel), def.title]
	_info_blurb.text = def.blurb if sel < GameState.unlocked else "BEAT THE PREVIOUS LEVEL TO UNLOCK"
	_info_best.text = "BEST %d" % GameState.best[sel] if GameState.best.has(sel) else ""
	var w := sel / 4
	if w != _shown_world:
		_shown_world = w
		for child in _sky_layer.get_children():
			child.queue_free()
		_sky_layer.add_child(Backdrop.new().setup(BIOME_OF[w], 0.0))
		Audio.music(Biomes.get_biome(BIOME_OF[w]).music)


func _text(t: String, pos: Vector2, size: int, color: Color, outline: int, width: float) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(width, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = PixelFont.settings(size, color, outline)
	add_child(l)
	return l
