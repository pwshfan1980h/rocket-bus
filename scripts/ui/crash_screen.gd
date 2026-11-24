class_name CrashScreen
extends Control
## Polished failure / crash overlay: crimson vignette, animated hazard-stripe card,
## cause icon + telemetry badge, animated course progress strip with crash X marker,
## shattering pixel hearts in Story mode, and snappy retry controls.

signal chosen(id: String)

const CARD_RECT := Rect2(86, 36, 308, 198)
const RED := Color("#ff3b4e")
const RED_SOFT := Color("#ff5a78")
const GOLD := Color("#ffcc26")
const CYAN := Color("#3cf0dc")
const GREEN := Color("#7dff6a")
const INK := Color("#140a1e")

var data: Dictionary = {}
var _time := 0.0
var _progress_anim := 0.0
var _heart_break := 0.0  # 0..1 animation for the newly-lost Story heart
var _card_root: Control
var _art: Control
var _menu: MenuList


func setup(d: Dictionary) -> CrashScreen:
	data = d
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	var bg := Control.new()
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_vignette.bind(bg))
	add_child(bg)

	_card_root = Control.new()
	_card_root.size = size
	_card_root.pivot_offset = Vector2(240, 135)
	_card_root.scale = Vector2(0.88, 0.88)
	_card_root.modulate.a = 0.0
	add_child(_card_root)

	_art = Control.new()
	_art.size = size
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_card)
	_card_root.add_child(_art)

	var story: bool = data.get("story", false)
	var lives: int = data.get("lives", 0)
	var title_text: String = data.get("title", "WRECKED")
	if story and lives <= 0:
		title_text = "GAME OVER"

	var title := _text(_card_root, title_text, Vector2(CARD_RECT.position.x, CARD_RECT.position.y + 6),
			16, Color.WHITE, CARD_RECT.size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
	title.label_settings.shadow_size = 2
	title.label_settings.shadow_color = Color("#5a0818")
	title.label_settings.shadow_offset = Vector2(2, 2)
	title.pivot_offset = Vector2(CARD_RECT.size.x * 0.5, 8)
	title.scale = Vector2(2.0, 2.0)

	var detail: String = data.get("detail", "")
	if detail != "":
		_text(_card_root, detail, Vector2(CARD_RECT.position.x, CARD_RECT.position.y + 38),
				8, GOLD, CARD_RECT.size.x, HORIZONTAL_ALIGNMENT_CENTER, 2)

	var pct := int(roundf(clampf(float(data.get("progress", 0.0)), 0.0, 1.0) * 100.0))
	var cleared: int = data.get("cleared", 0)
	var total_gaps: int = data.get("total_gaps", 0)
	var clock: float = data.get("time", 0.0)
	var stat_y := CARD_RECT.position.y + 84
	_text(_card_root, "%d%%" % pct, Vector2(CARD_RECT.position.x + 22, stat_y),
			8, RED_SOFT, 60, HORIZONTAL_ALIGNMENT_LEFT, 2)
	_text(_card_root, "GAPS %d/%d" % [cleared, total_gaps], Vector2(CARD_RECT.position.x, stat_y),
			8, CYAN, CARD_RECT.size.x, HORIZONTAL_ALIGNMENT_CENTER, 2)
	_text(_card_root, "%.1fs" % clock, Vector2(CARD_RECT.end.x - 82, stat_y),
			8, Color("#e8e0f0"), 60, HORIZONTAL_ALIGNMENT_RIGHT, 2)

	var entries := []
	var has_cp: bool = data.get("has_checkpoint", false)
	if story:
		if lives > 0:
			entries.append(["retry", "RETRY CHECKPOINT" if has_cp else "TRY AGAIN"])
			if has_cp:
				entries.append(["restart", "RESTART LEG"])
			entries.append(["give_up", "END RUN"])
		else:
			entries.append(["give_up", "CONTINUE"])
	else:
		entries.append(["retry", "RETRY CHECKPOINT" if has_cp else "TRY AGAIN"])
		if has_cp:
			entries.append(["restart", "RESTART LEVEL"])
		entries.append(["menu", "LEVEL SELECT"])

	var spacing := 16 if entries.size() <= 2 else 14
	var menu_y := CARD_RECT.position.y + (126 if story else (126 if entries.size() <= 2 else 118))
	if entries.size() == 1:
		menu_y += 10
	_menu = MenuList.new().setup(entries, 8, spacing)
	_menu.position = Vector2(240, menu_y)
	_card_root.add_child(_menu)
	_menu.chosen.connect(func(id): chosen.emit(id))

	var hint_text := "ENTER CONTINUE" if (story and lives <= 0) else "R RETRY   ESC MENU"
	if story and lives > 0:
		hint_text = "R RETRY   UP/DOWN SELECT"
	_text(_card_root, hint_text, Vector2(CARD_RECT.position.x, CARD_RECT.end.y - 14),
			8, Color(1, 1, 1, 0.4), CARD_RECT.size.x, HORIZONTAL_ALIGNMENT_CENTER, 0)

	# Choreographed entrance: card pops, title slams, progress bar fills, Story heart breaks.
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_card_root, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_card_root, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(title, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Fx.shake(3.0))
	var target_p := clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	tw.tween_method(func(v: float): _progress_anim = v, 0.0, target_p, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if story:
		tw.tween_method(func(v: float): _heart_break = v, 0.0, 1.0, 0.5)


func _process(delta: float) -> void:
	_time += delta
	_art.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _menu == null or not _menu.active:
		return
	var story: bool = data.get("story", false)
	var lives: int = data.get("lives", 0)
	if event.is_action_pressed("reset") and (not story or lives > 0):
		_menu.active = false
		Audio.play("ui_select", -4.0)
		chosen.emit("retry")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not story:
		_menu.active = false
		Audio.play("ui_back", -6.0)
		chosen.emit("menu")
		get_viewport().set_input_as_handled()


func _draw_vignette(n: Control) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.01, 0.04, 0.62))
	# Crimson danger edge strips (stepped pixel vignette).
	for i in 4:
		var a := (4 - i) * 0.055
		var t := 6 + i * 8
		var c := Color(0.75, 0.06, 0.14, a)
		n.draw_rect(Rect2(0, i * 6, 480, 6), c)
		n.draw_rect(Rect2(0, 270 - (i + 1) * 6, 480, 6), c)
		n.draw_rect(Rect2(i * 6, t, 6, 270 - t * 2), c)
		n.draw_rect(Rect2(480 - (i + 1) * 6, t, 6, 270 - t * 2), c)


func _draw_card() -> void:
	var r := CARD_RECT
	# Drop shadow + dark fill.
	_art.draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0.03, 0.01, 0.06, 0.72))
	_art.draw_rect(r, Color(0.08, 0.04, 0.13, 0.96))

	# Hazard-stripe header band (28px tall).
	var band := Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 26)
	_art.draw_rect(band, Color("#2a0b18"))
	var scroll := int(_time * 20.0) % 16
	var x := int(band.position.x) - 32 + scroll
	while x < int(band.end.x) + 16:
		var pts := PackedVector2Array([
			Vector2(clampf(x, band.position.x, band.end.x), band.end.y),
			Vector2(clampf(x + 8, band.position.x, band.end.x), band.end.y),
			Vector2(clampf(x + 18, band.position.x, band.end.x), band.position.y),
			Vector2(clampf(x + 10, band.position.x, band.end.x), band.position.y),
		])
		_art.draw_colored_polygon(pts, Color(0.55, 0.08, 0.18, 0.55))
		x += 16
	_art.draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 2), RED)

	# Cause icons flanking the title inside the header band.
	var kind: String = data.get("kind", "crash")
	_draw_cause_icon(Vector2(band.position.x + 16, band.position.y + 13), kind)
	_draw_cause_icon(Vector2(band.end.x - 16, band.position.y + 13), kind)

	# Outer & inner borders + corner rivets.
	_art.draw_rect(r, RED, false, 2.0)
	_art.draw_rect(Rect2(r.position + Vector2(3, 30), r.size - Vector2(6, 33)), Color(1, 1, 1, 0.08), false, 1.0)
	for corner in [
		r.position + Vector2(4, 4),
		Vector2(r.end.x - 7, r.position.y + 4),
		Vector2(r.position.x + 4, r.end.y - 7),
		r.end - Vector2(7, 7),
	]:
		_art.draw_rect(Rect2(corner, Vector2(3, 3)), GOLD)

	# Detail telemetry pill frame.
	if data.get("detail", "") != "":
		var pill := Rect2(r.position.x + 42, r.position.y + 35, r.size.x - 84, 14)
		_art.draw_rect(pill, Color(0.16, 0.08, 0.22, 0.9))
		_art.draw_rect(pill, Color(1.0, 0.8, 0.15, 0.35), false, 1.0)

	# Course progress bar.
	_draw_progress_bar(Rect2(r.position.x + 24, r.position.y + 66, r.size.x - 48, 8))

	# Divider above menu.
	var div_y := r.position.y + (116 if data.get("story", false) else 102)
	_art.draw_rect(Rect2(r.position.x + 20, div_y, r.size.x - 40, 1), Color(1, 1, 1, 0.12))

	# Story hearts row (7 pixel hearts, lost heart cracks & fades).
	if data.get("story", false):
		_draw_hearts(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 101))


func _draw_progress_bar(bar: Rect2) -> void:
	# Track background & subtle outline.
	_art.draw_rect(bar, Color(0.05, 0.02, 0.09, 0.95))
	_art.draw_rect(bar, Color(1, 1, 1, 0.22), false, 1.0)

	# Filled progress up to crash point.
	var fill_w := roundf((bar.size.x - 2) * _progress_anim)
	if fill_w > 0:
		_art.draw_rect(Rect2(bar.position.x + 1, bar.position.y + 1, fill_w, bar.size.y - 2), Color("#c82848"))
		_art.draw_rect(Rect2(bar.position.x + 1, bar.position.y + 1, fill_w, 2), RED_SOFT)

	# Checkpoint flags along the strip.
	var cps: Array = data.get("checkpoints", [])
	var prog := float(data.get("progress", 0.0))
	for cp in cps:
		var cx := bar.position.x + clampf(float(cp), 0.0, 1.0) * bar.size.x
		var passed := float(cp) <= prog + 0.005
		_art.draw_rect(Rect2(cx, bar.position.y - 6, 1, 14), Color("#d8d8e0") if passed else Color(1, 1, 1, 0.3))
		_art.draw_rect(Rect2(cx + 1, bar.position.y - 6, 4, 3), GREEN if passed else Color(1, 1, 1, 0.22))

	# Finish checkered flag on the right end.
	var fx := bar.end.x
	_art.draw_rect(Rect2(fx, bar.position.y - 8, 1, 16), Color.WHITE)
	for row in 2:
		for col in 2:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color("#140a1e")
			_art.draw_rect(Rect2(fx + 1 + col * 2, bar.position.y - 8 + row * 2, 2, 2), c)

	# Pulsing red X at the crash site.
	var mx := bar.position.x + clampf(_progress_anim, 0.0, 1.0) * bar.size.x
	var my := bar.position.y + bar.size.y * 0.5
	var pulse := 1.0 if fmod(_time, 0.6) < 0.35 else 0.7
	var xc := RED.lerp(Color.WHITE, 0.35 * pulse)
	for d in range(-4, 5):
		_art.draw_rect(Rect2(roundf(mx + d - 1), roundf(my + d - 1), 2, 2), INK)
		_art.draw_rect(Rect2(roundf(mx + d - 1), roundf(my - d - 1), 2, 2), INK)
	for d in range(-3, 4):
		_art.draw_rect(Rect2(roundf(mx + d), roundf(my + d), 1, 1), xc)
		_art.draw_rect(Rect2(roundf(mx + d), roundf(my - d), 1, 1), xc)


func _draw_hearts(center: Vector2) -> void:
	var max_lives: int = data.get("max_lives", Story.LIVES)
	var lives: int = maxi(0, data.get("lives", 0))
	var step := 18.0
	var start_x := center.x - (max_lives - 1) * step * 0.5 - 6.0
	for i in max_lives:
		var pos := Vector2(start_x + i * step, center.y - 5.0)
		if i < lives:
			_heart(pos, RED_SOFT, true)
		elif i == lives:
			# Just-lost heart: shakes, flashes white, then fades to empty socket.
			var shake := Vector2(sin(_heart_break * 45.0) * 2.5 * (1.0 - _heart_break),
					cos(_heart_break * 33.0) * 1.5 * (1.0 - _heart_break))
			_heart(pos, Color(1, 1, 1, 0.14), false)
			var alpha := 1.0 - clampf((_heart_break - 0.35) / 0.65, 0.0, 1.0)
			if alpha > 0.02:
				var col := Color.WHITE.lerp(RED, clampf(_heart_break * 2.0, 0.0, 1.0))
				col.a = alpha
				_heart(pos + shake + Vector2(0, _heart_break * 6.0), col, false)
		else:
			_heart(pos, Color(1, 1, 1, 0.14), false)


func _heart(at: Vector2, c: Color, shine: bool) -> void:
	var p := at.round()
	_art.draw_rect(Rect2(p + Vector2(1, 0), Vector2(4, 3)), c)
	_art.draw_rect(Rect2(p + Vector2(7, 0), Vector2(4, 3)), c)
	_art.draw_rect(Rect2(p + Vector2(0, 2), Vector2(12, 4)), c)
	_art.draw_rect(Rect2(p + Vector2(2, 6), Vector2(8, 2)), c)
	_art.draw_rect(Rect2(p + Vector2(4, 8), Vector2(4, 2)), c)
	if shine:
		_art.draw_rect(Rect2(p + Vector2(2, 1), Vector2(2, 1)), Color(1, 1, 1, 0.75))


func _draw_cause_icon(center: Vector2, kind: String) -> void:
	var p := (center - Vector2(5, 5)).round()
	match kind:
		"lava":
			_art.draw_rect(Rect2(p + Vector2(3, 0), Vector2(4, 3)), GOLD)
			_art.draw_rect(Rect2(p + Vector2(1, 3), Vector2(8, 4)), Color("#ff6a1a"))
			_art.draw_rect(Rect2(p + Vector2(2, 7), Vector2(6, 3)), RED)
		"water", "swamp":
			var c := Color("#5aa8ff") if kind == "water" else Color("#7acc52")
			_art.draw_rect(Rect2(p + Vector2(0, 3), Vector2(10, 2)), c)
			_art.draw_rect(Rect2(p + Vector2(2, 1), Vector2(3, 2)), c)
			_art.draw_rect(Rect2(p + Vector2(6, 1), Vector2(3, 2)), c)
			_art.draw_rect(Rect2(p + Vector2(0, 7), Vector2(10, 2)), c.darkened(0.25))
		"ice":
			var c := Color("#b8e8ff")
			_art.draw_rect(Rect2(p + Vector2(4, 0), Vector2(2, 10)), c)
			_art.draw_rect(Rect2(p + Vector2(0, 4), Vector2(10, 2)), c)
			_art.draw_rect(Rect2(p + Vector2(2, 2), Vector2(6, 6)), Color("#7ac4ff"))
		"chasm":
			_art.draw_rect(Rect2(p + Vector2(4, 0), Vector2(2, 7)), GOLD)
			_art.draw_rect(Rect2(p + Vector2(1, 5), Vector2(8, 2)), GOLD)
			_art.draw_rect(Rect2(p + Vector2(3, 7), Vector2(4, 2)), GOLD)
			_art.draw_rect(Rect2(p + Vector2(4, 9), Vector2(2, 1)), GOLD)
		"mudslide":
			_art.draw_rect(Rect2(p + Vector2(0, 4), Vector2(10, 6)), Color("#8a5a30"))
			_art.draw_rect(Rect2(p + Vector2(3, 1), Vector2(6, 3)), Color("#a87040"))
		"cargo":
			_art.draw_rect(Rect2(p + Vector2(1, 2), Vector2(8, 6)), Color("#ff9a2e"))
			_art.draw_rect(Rect2(p + Vector2(3, 8), Vector2(4, 2)), Color("#d8d8e0"))
		"missed":
			_art.draw_rect(Rect2(p + Vector2(1, 1), Vector2(8, 8)), Color("#3a7af0"))
			_art.draw_rect(Rect2(p + Vector2(2, 2), Vector2(6, 6)), Color.WHITE, false, 1.0)
		_:  # crash skull
			_art.draw_rect(Rect2(p + Vector2(2, 1), Vector2(6, 6)), Color("#f0ecf8"))
			_art.draw_rect(Rect2(p + Vector2(1, 2), Vector2(8, 4)), Color("#f0ecf8"))
			_art.draw_rect(Rect2(p + Vector2(3, 7), Vector2(4, 2)), Color("#f0ecf8"))
			_art.draw_rect(Rect2(p + Vector2(2, 3), Vector2(2, 2)), INK)
			_art.draw_rect(Rect2(p + Vector2(6, 3), Vector2(2, 2)), INK)


func _text(parent: Node, t: String, pos: Vector2, font_size: int, color: Color, width: float,
		align: HorizontalAlignment, outline := 2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(width, font_size)
	l.horizontal_alignment = align
	l.label_settings = PixelFont.settings(font_size, color, outline)
	parent.add_child(l)
	return l
