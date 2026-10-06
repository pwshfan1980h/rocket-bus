class_name TripReport
extends Control
## The end-of-level score card ("ROCKET BUS TRIP REPORT"): stats tick in, Speed and
## Technique stars pop, the score counts up, then the grade letter is stamped on
## with a cha-ching (C or better) or a sigh (D and below). Runs while the tree is
## paused (freeze frame), so everything here uses PROCESS_MODE_ALWAYS.

signal chosen(id: String)

var data: Dictionary  # see Level._finish_report
var _grade_label: Label
var _time := 0.0


func setup(d: Dictionary) -> TripReport:
	data = d
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(480, 270)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.55)
	dim.size = size
	add_child(dim)
	var card := ColorRect.new()
	card.color = Color(0.1, 0.05, 0.16, 0.96)
	card.position = Vector2(70, 20)
	card.size = Vector2(340, 232)
	add_child(card)
	var border := ReferenceRect.new()
	border.border_color = Color("#ffcc26")
	border.border_width = 2
	border.editor_only = false
	border.position = card.position
	border.size = card.size
	add_child(border)
	_text("ROCKET BUS TRIP REPORT", Vector2(70, 28), 8, Color("#ff4aa8"), 340, HORIZONTAL_ALIGNMENT_CENTER)
	_text("%s  %s" % [data.code, data.title], Vector2(70, 38), 16, Color("#ffcc26"), 340, HORIZONTAL_ALIGNMENT_CENTER)
	if data.comet:
		_text("COMET EXIT!  +BONUS", Vector2(70, 57), 8, Color("#ff9a2e"), 340, HORIZONTAL_ALIGNMENT_CENTER)
	var box := ReferenceRect.new()  # the grade's own corner of the card
	box.border_color = Color(1, 1, 1, 0.25)
	box.border_width = 1
	box.editor_only = false
	box.position = Vector2(314, 74)
	box.size = Vector2(82, 88)
	add_child(box)
	_play()


func _process(delta: float) -> void:
	_time += delta
	if _grade_label and data.grade == "SS":
		_grade_label.label_settings.font_color = Color.from_hsv(fmod(_time * 0.8, 1.0), 0.6, 1.0)


func _play() -> void:
	var rows := [
		["TIME", "%.1fs" % data.time],
		["PAR", "%ds" % int(data.par)],
		["LANDINGS", "%dP %dG %dH" % [data.landings.count("perfect"), data.landings.count("good"), data.landings.count("hard")]],
		["FLIPS", str(data.style.flips) + (" (%d FRONT)" % data.style.front if data.style.get("front", 0) > 0 else "")],
		["CLOSE CALLS", str(data.style.close)],
		["BEST AIR", "%.1fs" % data.style.air],
		["FUEL LEFT", "%d%%" % data.fuel_pct],
		["RETRIES", str(data.retries)],
	]
	var tw := create_tween()
	for i in rows.size():
		var y := 72 + i * 11
		var l := _text(rows[i][0], Vector2(84, y), 8, Color("#d8f8ff"), 110, HORIZONTAL_ALIGNMENT_LEFT)
		var v := _text(rows[i][1], Vector2(196, y), 8, Color.WHITE, 104, HORIZONTAL_ALIGNMENT_RIGHT)
		l.modulate.a = 0.0
		v.modulate.a = 0.0
		tw.tween_property(l, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(v, "modulate:a", 1.0, 0.08)
		tw.tween_callback(Audio.play.bind("score_tick", -10.0))
	tw.tween_interval(0.15)
	_star_row(tw, "SPEED", data.speed, 164)
	_star_row(tw, "TECHNIQUE", data.technique, 180)
	var score_l := _text("SCORE 0", Vector2(84, 196), 8, Color("#7dff6a"), 200, HORIZONTAL_ALIGNMENT_LEFT)
	tw.tween_method(func(v: int): score_l.text = "SCORE %d" % v, 0, data.score, 0.8)
	tw.tween_interval(0.2)
	tw.tween_callback(_stamp_grade)
	tw.tween_interval(0.6)
	tw.tween_callback(_menu)


func _star_row(tw: Tween, label: String, count: int, y: float) -> void:
	_text(label, Vector2(84, y), 8, Color("#d8f8ff"), 120, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 3:
		var star := StarIcon.new()
		star.filled = i < count
		star.position = Vector2(200 + i * 18, y + 4)
		star.scale = Vector2.ZERO
		add_child(star)
		tw.tween_property(star, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
		if i < count:
			tw.tween_callback(Audio.play.bind("star", -6.0, 1.0 + i * 0.12))


func _stamp_grade() -> void:
	var g: String = data.grade
	_grade_label = _text(g, Vector2(310, 112), 32, Grading.color(g), 90, HORIZONTAL_ALIGNMENT_CENTER, 6)
	_grade_label.pivot_offset = Vector2(45, 16)
	_grade_label.rotation = -0.2
	_grade_label.scale = Vector2(4, 4)
	_grade_label.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_grade_label, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_grade_label, "modulate:a", 1.0, 0.1)
	_text("GRADE", Vector2(310, 80), 8, Color("#d8f8ff"), 90, HORIZONTAL_ALIGNMENT_CENTER)
	Audio.play("stamp", 0.0)
	Fx.shake(4.0)
	if Grading.is_good(g):
		Audio.play("cha_ching", -2.0)
	else:
		Audio.play("sigh", -2.0)


func _menu() -> void:
	var entries := [["next", "NEXT LEVEL"], ["restart", "RETRY"], ["menu", "MENU"]]
	if data.last:
		entries = [["menu", "YOU BEAT THE GAME!"], ["restart", "RETRY"]]
	var menu := MenuList.new().setup(entries, 8, 11)
	menu.position = Vector2(240, 212)
	add_child(menu)
	menu.chosen.connect(func(id): chosen.emit(id))


func _text(t: String, pos: Vector2, font_size: int, color: Color, width: float,
		align: HorizontalAlignment, outline := 2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(width, font_size)
	l.horizontal_alignment = align
	l.label_settings = PixelFont.settings(font_size, color, outline)
	add_child(l)
	return l


class StarIcon:
	extends Node2D
	var filled := true

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var r := 7.0 if i % 2 == 0 else 3.0
			var a := -PI / 2 + i * PI / 5
			pts.append(Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color("#ffcc26") if filled else Color(1, 1, 1, 0.15))
		pts.append(pts[0])
		draw_polyline(pts, Color("#1a0f29"), 1.0)
