extends Control
## Arcade level select: 7 worlds, 25 levels, showing saved stars, best score, and best grade.
## Left/Right (or A/D) switches worlds, Up/Down (or W/S) picks a level, Enter/Click launches.

const WORLD_BIOMES := ["desert", "jungle", "mountain", "snow", "volcano", "moon", "border"]
const WORLD_SHORT := ["DESERT", "JUNGLE", "MTNS", "SNOW", "VOLCANO", "MOON", "BORDER"]
const GOLD := Color("#ffcc26")
const CYAN := Color("#3cf0dc")
const PINK := Color("#ff4aa8")

var _world := 0
var _row := 0
var _sky_layer: CanvasLayer
var _backdrop: Node2D
var _art: Control
var _active := true
var _time := 0.0


func _ready() -> void:
	size = Vector2(480, 270)
	_world = clampi(GameState.current_level / 4, 0, WORLD_BIOMES.size() - 1)
	_row = GameState.current_level % 4
	if _row >= _world_levels(_world).size():
		_row = 0

	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -10
	add_child(_sky_layer)
	_set_backdrop()

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.02, 0.1, 0.58)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_art = Control.new()
	_art.size = size
	_art.mouse_filter = Control.MOUSE_FILTER_STOP
	_art.draw.connect(_draw_ui)
	_art.gui_input.connect(_on_gui_input)
	add_child(_art)

	Audio.music("music_menu")


func _process(delta: float) -> void:
	_time += delta
	_art.queue_redraw()


func _world_levels(w: int) -> Array[int]:
	var out: Array[int] = []
	var start := w * 4
	var stop := mini(start + 4, Levels.count())
	for i in range(start, stop):
		out.append(i)
	return out


func _set_backdrop() -> void:
	if _backdrop:
		_backdrop.queue_free()
	_backdrop = Backdrop.new().setup(WORLD_BIOMES[_world], 0.0)
	_sky_layer.add_child(_backdrop)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	var lvls := _world_levels(_world)
	if event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_D):
		_select_world((_world + 1) % WORLD_BIOMES.size())
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_A):
		_select_world((_world - 1 + WORLD_BIOMES.size()) % WORLD_BIOMES.size())
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_S):
		_row = (_row + 1) % lvls.size()
		Audio.play("ui_move", -8.0)
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_W):
		_row = (_row - 1 + lvls.size()) % lvls.size()
		Audio.play("ui_move", -8.0)
	elif event.is_action_pressed("ui_accept"):
		_launch(lvls[_row])
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if not _active:
		return
	var pos := Vector2.ZERO
	if event is InputEventMouseMotion:
		pos = event.position
		var hit_row := _row_at(pos)
		if hit_row >= 0 and hit_row != _row:
			_row = hit_row
			Audio.play("ui_move", -8.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		var tab := _tab_at(pos)
		if tab >= 0:
			_select_world(tab)
			return
		var hit_row := _row_at(pos)
		if hit_row >= 0:
			_row = hit_row
			_launch(_world_levels(_world)[_row])
			return
		if Rect2(14, 246, 90, 16).has_point(pos):
			_back()


func _tab_at(p: Vector2) -> int:
	for i in WORLD_SHORT.size():
		if _tab_rect(i).has_point(p):
			return i
	return -1


func _row_at(p: Vector2) -> int:
	var lvls := _world_levels(_world)
	for i in lvls.size():
		if _card_rect(i).has_point(p):
			return i
	return -1


func _tab_rect(i: int) -> Rect2:
	var w := 64.0
	var gap := 2.0
	var total := WORLD_SHORT.size() * w + (WORLD_SHORT.size() - 1) * gap
	var x0 := (480.0 - total) * 0.5
	return Rect2(x0 + i * (w + gap), 38, w, 16)


func _card_rect(i: int) -> Rect2:
	return Rect2(36, 68 + i * 40, 408, 34)


func _select_world(w: int) -> void:
	if w == _world:
		return
	_world = w
	_row = mini(_row, _world_levels(_world).size() - 1)
	_set_backdrop()
	Audio.play("ui_move", -8.0)


func _launch(idx: int) -> void:
	_active = false
	Audio.play("ui_select", -4.0)
	GameState.story_mode = false
	GameState.checkpoint = {}
	GameState.current_level = idx
	Transition.go("res://scenes/level.tscn", 0.2)


func _back() -> void:
	_active = false
	Audio.play("ui_back", -6.0)
	Transition.go("res://scenes/main_menu.tscn", 0.25)


func help_topic() -> String:
	return "scoring"


func _draw_ui() -> void:
	var font := PixelFont.get_font()
	# Header
	_art.draw_string(font, Vector2(18, 24), "ARCADE", HORIZONTAL_ALIGNMENT_LEFT, 200, 16, GOLD)
	var stars_txt := "STARS %d/%d" % [GameState.total_stars(), Levels.count() * 3]
	_art.draw_string(font, Vector2(260, 22), stars_txt, HORIZONTAL_ALIGNMENT_RIGHT, 202, 8, GOLD)

	# World tabs
	for i in WORLD_SHORT.size():
		var r := _tab_rect(i)
		var sel := i == _world
		var w_lvls := _world_levels(i)
		var w_cleared := 0
		for li in w_lvls:
			if GameState.grades.has(li):
				w_cleared += 1
		var bg := Color(0.18, 0.08, 0.26, 0.95) if sel else Color(0.08, 0.04, 0.14, 0.78)
		_art.draw_rect(r, bg)
		_art.draw_rect(r, GOLD if sel else Color(1, 1, 1, 0.22), false, 1.5 if sel else 1.0)
		if w_cleared == w_lvls.size() and w_lvls.size() > 0:
			_art.draw_rect(Rect2(r.position.x + 2, r.end.y - 3, r.size.x - 4, 2), Color("#7dff6a"))
		_art.draw_string(font, Vector2(r.position.x, r.position.y + 11), WORLD_SHORT[i],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, GOLD if sel else Color(1, 1, 1, 0.65))

	# Level cards for selected world
	var lvls := _world_levels(_world)
	for i in lvls.size():
		var idx := lvls[i]
		var def := Levels.get_level(idx)
		var r := _card_rect(i)
		var sel := i == _row
		var bg := Color(0.16, 0.08, 0.25, 0.96) if sel else Color(0.08, 0.04, 0.14, 0.85)
		_art.draw_rect(r, bg)
		_art.draw_rect(r, GOLD if sel else Color(1, 1, 1, 0.18), false, 2.0 if sel else 1.0)
		if sel:
			var pulse := 1.0 if fmod(_time, 0.6) < 0.35 else 0.6
			_art.draw_rect(Rect2(r.position.x + 3, r.position.y + 3, 4, r.size.y - 6), GOLD * Color(1, 1, 1, pulse))

		# Code + title
		var code := Levels.code(idx)
		_art.draw_string(font, Vector2(r.position.x + 14, r.position.y + 15), code,
				HORIZONTAL_ALIGNMENT_LEFT, 44, 8, CYAN)
		_art.draw_string(font, Vector2(r.position.x + 56, r.position.y + 15), def.title,
				HORIZONTAL_ALIGNMENT_LEFT, 190, 8, GOLD if sel else Color.WHITE)

		# Sub-line: weather / best score
		var sub_parts: Array[String] = []
		if GameState.best.has(idx):
			sub_parts.append("BEST %d" % GameState.best[idx])
		if def.get("weather", "") != "":
			sub_parts.append(str(def.weather).to_upper())
		var sub := "  /  ".join(sub_parts)
		if sub != "":
			_art.draw_string(font, Vector2(r.position.x + 56, r.position.y + 27), sub,
					HORIZONTAL_ALIGNMENT_LEFT, 220, 8, Color(1, 1, 1, 0.5))

		# Stars
		var sc: int = GameState.stars.get(idx, 0)
		for s in 3:
			_draw_star(Vector2(r.end.x - 104 + s * 16, r.position.y + 17), s < sc)

		# Grade box
		var gbox := Rect2(r.end.x - 42, r.position.y + 5, 34, 24)
		_art.draw_rect(gbox, Color(0.05, 0.02, 0.09, 0.9))
		_art.draw_rect(gbox, Color(1, 1, 1, 0.2), false, 1.0)
		var g: String = GameState.grades.get(idx, "")
		if g != "":
			var gc := Color.from_hsv(fmod(_time * 0.8, 1.0), 0.6, 1.0) if g == "SS" else Grading.color(g)
			var gsize := 16 if g.length() == 1 else 8
			var gy := gbox.position.y + (20 if gsize == 16 else 16)
			_art.draw_string(font, Vector2(gbox.position.x, gy), g,
					HORIZONTAL_ALIGNMENT_CENTER, gbox.size.x, gsize, gc)
		else:
			_art.draw_string(font, Vector2(gbox.position.x, gbox.position.y + 16), "--",
					HORIZONTAL_ALIGNMENT_CENTER, gbox.size.x, 8, Color(1, 1, 1, 0.25))

	# Footer
	_art.draw_string(font, Vector2(18, 258), "ESC BACK", HORIZONTAL_ALIGNMENT_LEFT, 100, 8, Color(1, 1, 1, 0.55))
	_art.draw_string(font, Vector2(120, 258), "A/D WORLD   W/S LEVEL   ENTER PLAY",
			HORIZONTAL_ALIGNMENT_RIGHT, 342, 8, Color(1, 1, 1, 0.45))


func _draw_star(at: Vector2, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := 6.0 if i % 2 == 0 else 2.6
		var a := -PI / 2 + i * PI / 5
		pts.append(at + Vector2(cos(a), sin(a)) * rad)
	_art.draw_colored_polygon(pts, GOLD if filled else Color(1, 1, 1, 0.14))
	pts.append(pts[0])
	_art.draw_polyline(pts, Color("#1a0f29"), 1.0)
