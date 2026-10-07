extends CanvasLayer
## F1 (or ?) opens the field guide: a few illustrated pages on driving, jumping,
## landing, flips and the Story jobs. It opens on the page that fits the moment,
## because the current scene can answer help_topic() (e.g. a loose trailer -> TOWING).
## The game pauses while it's open. Left/right flips pages; Esc or F1 closes it.

const PAGES := [
	{"id": "basics", "title": "DRIVING", "lines": [
		"D / RIGHT: THROTTLE.",
		"A / LEFT: BRAKE. KEEP HOLDING WHEN STOPPED TO REVERSE.",
		"THE BUS IS HEAVY. SPEED CARRIES YOU UP HILLS AND OFF RAMPS.",
		"MUD SLOWS YOU. ICE SLIDES: BRAKE BEFORE IT, NOT ON IT.",
		"H HORN.  R RETRY.  ESC PAUSE.",
	]},
	{"id": "rocket", "title": "ROCKET + JUMPS", "lines": [
		"HOLD SPACE TO FIRE. IT PUSHES ALONG THE NOSE: THE ANGLE YOU FIRE AT IS WHERE YOU GO.",
		"HIT THE RAMP AT FULL SPEED. START BURNING ON THE RAMP.",
		"KEEP BURNING UNTIL THE FAR SIDE IS SAFE, THEN LET GO.",
		"WATCH THE FUEL BAR. RED CANS REFILL IT.",
	]},
	{"id": "air", "title": "IN THE AIR", "lines": [
		"D TIPS THE NOSE DOWN. A TIPS IT UP.",
		"MATCH THE SLOPE YOU'LL LAND ON. DOWNHILL? NOSE DOWN.",
		"THE SHADOW SHRINKS AS YOU CLIMB AND SHARPENS AS YOU FALL. SHARP SHADOW = TOUCHDOWN.",
	]},
	{"id": "landing", "title": "LANDING", "lines": [
		"PERFECT: LEVEL WITH THE ROAD, SOFT.",
		"GOOD: A LITTLE OFF.",
		"HARD: TOO STEEP OR FAST. A RIDER BONKS. 3 BONKS AND THEY WALK.",
		"WRECKED: WAY OFF ANGLE, OR BELLY FIRST.",
		"LET GO OF THE ROCKET BEFORE TOUCHDOWN.",
	]},
	{"id": "flips", "title": "FLIPS", "lines": [
		"HOLD D IN THE AIR: FRONT FLIP. HOLD A: BACKFLIP.",
		"A FLIP ONLY COUNTS IF YOU LAND IT.",
		"STICK A FRONT FLIP FOR THE FULL FANFARE: +2000, MORE IF PERFECT.",
		"KICKERS (LITTLE RAMPS ON THE ROAD) GIVE FREE AIR.",
	]},
	{"id": "stops", "title": "STORY: BUS STOPS", "lines": [
		"1. EASE OFF EARLY. A HEAVY BUS NEEDS ROOM.",
		"2. GET BOTH WHEELS INSIDE THE YELLOW BOX.",
		"3. HOLD A. IN THE BOX THE BRAKE LOCKS THE WHEELS: NO ROLLING, NO REVERSING.",
		"4. KEEP HOLDING UNTIL THE RING FILLS AND THE DOORS OPEN. ON HILLS, DON'T LET GO EARLY.",
		"OVERSHOT? STOP OUTSIDE THE BOX AND HOLD A TO BACK IN.",
		"SKIP A STOP AND THE LEG FAILS AT THE FINISH.",
	]},
	{"id": "towing", "title": "STORY: TOWING", "lines": [
		"THE TRAILER RIDES ON A LONG BAR BEHIND THE ROCKET.",
		"A HARD LANDING SNAPS THE HITCH.",
		"TO RE-HOOK: STOP, THEN HOLD A AND BACK UP SLOWLY. WHEN THE BAR MEETS THE BUS IT CLICKS ON: HOOKED!",
		"NO FINISH WITHOUT IT. LET IT FALL IN A GAP AND THE CARGO'S GONE.",
	]},
	{"id": "story", "title": "STORY RULES", "lines": [
		"7 LIVES, START TO FINISH. NO SAVES.",
		"CRASH, FALL, MISSED STOP, LOST CARGO OR RESTART: -1 LIFE.",
		"GRADE S OR SS ON A LEG: +1 LIFE.",
		"THE ROAD FORKS TWICE.",
		"DO WHAT PASSENGERS ASK (OR DON'T DO WHAT THEY FORBID) FOR TIPS.",
	]},
	{"id": "scoring", "title": "ARCADE + SCORING", "lines": [
		"ARCADE: EVERY MAP, 1-1 TO THE END.",
		"GRADE = SPEED (TIME VS PAR) + TECHNIQUE (LANDINGS, FLIPS, CLOSE CALLS, AIR).",
		"FULL BUS +1500. LEFTOVER FUEL = OVERTIME POINTS.",
		"RETRY TO RACE YOUR BEST RUN'S GHOST.",
		"FINISH HIGH IN THE AIR FOR A COMET EXIT.",
	]},
]

var _open := false
var _page := 0
var _was_paused := false
var _root: Control
var _art: Control
var _title: Label
var _body: Label
var _footer: Label
var _time := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("help"):
		InputMap.add_action("help")
		for key in [KEY_F1, KEY_SLASH]:  # "?" too: browsers may keep F1 for themselves
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event("help", ev)
	_build()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE:
			_turn(1)
		KEY_LEFT, KEY_A:
			_turn(-1)
		KEY_ESCAPE, KEY_P:
			close()
	get_viewport().set_input_as_handled()  # the game underneath doesn't see keys while reading


func open(topic := "") -> void:
	if topic == "":
		var scene := get_tree().current_scene
		topic = scene.help_topic() if scene and scene.has_method("help_topic") else "basics"
	_page = maxi(0, PAGES.map(func(p): return p.id).find(topic))
	_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.show()
	_show_page()
	Audio.play("ui_select", -6.0)


func close() -> void:
	_open = false
	_root.hide()
	get_tree().paused = _was_paused
	Audio.play("ui_back", -6.0)


func is_open() -> bool:
	return _open


func _turn(step: int) -> void:
	_page = wrapi(_page + step, 0, PAGES.size())
	Audio.play("ui_move", -8.0)
	_show_page()


func _process(delta: float) -> void:
	_time += delta
	if _open:
		_art.queue_redraw()


func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(480, 270)
	_root.hide()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.06, 0.75)
	dim.size = _root.size
	_root.add_child(dim)
	var card := ColorRect.new()
	card.color = Color(0.1, 0.05, 0.16, 0.97)
	card.position = Vector2(14, 14)
	card.size = Vector2(452, 242)
	_root.add_child(card)
	var border := ReferenceRect.new()
	border.border_color = Color("#3cf0dc")
	border.border_width = 2
	border.editor_only = false
	border.position = card.position
	border.size = card.size
	_root.add_child(border)
	_label("ROCKET BUS FIELD GUIDE", Vector2(24, 22), 8, Color("#ff4aa8"))
	_title = _label("", Vector2(24, 36), 16, Color("#ffcc26"))
	_body = _label("", Vector2(24, 62), 8, Color("#e8f4ff"))
	_body.label_settings.line_spacing = 3
	_body.size = Vector2(296, 170)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_art = Control.new()
	_art.position = Vector2(330, 60)
	_art.size = Vector2(124, 120)
	_art.draw.connect(_draw_art)
	_root.add_child(_art)
	_footer = _label("", Vector2(24, 238), 8, Color(1, 1, 1, 0.5))


func _label(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(size, color, 0)
	_root.add_child(l)
	return l


func _show_page() -> void:
	var p: Dictionary = PAGES[_page]
	_title.text = p.title
	_body.text = "\n".join(p.lines.map(func(l): return l if l.left(1).is_valid_int() else "- " + l))
	_footer.text = "<  A / D  >  PAGE %d/%d        ESC / F1  CLOSE" % [_page + 1, PAGES.size()]


# --- Illustrations (tiny animated diagrams, one per page) ---------------------

const YEL := Color("#ffcc26")
const ROAD := Color("#8a8296")
const INK := Color("#e8f4ff")


func _draw_art() -> void:
	var a := _art
	a.draw_rect(Rect2(Vector2.ZERO, a.size), Color(0, 0, 0, 0.25))
	var t := _time
	match PAGES[_page].id:
		"basics":
			a.draw_line(Vector2(4, 96), Vector2(120, 70), ROAD, 2.0)
			var x := fposmod(t * 30.0, 80.0) + 10.0
			_bus(Vector2(x, 96 - (x * 26.0 / 116.0) - 10), -0.22)
			_key(Vector2(14, 10), "D", true)
			_key(Vector2(38, 10), "A", false)
		"rocket":
			a.draw_line(Vector2(4, 100), Vector2(40, 100), ROAD, 2.0)
			a.draw_polyline(PackedVector2Array([Vector2(40, 100), Vector2(60, 96), Vector2(70, 88)]), Color("#b87a3e"), 2.0)
			var k := fmod(t, 2.0) / 2.0
			var p := Vector2(70 + k * 50, 86 - sin(k * PI) * 40 - k * 6)
			_bus(p, -0.35 + k * 0.5)
			if k < 0.5:
				a.draw_rect(Rect2(p + Vector2(-22, 2), Vector2(8, 3)), Color("#ffb040"))
			_key(Vector2(10, 10), "SPACE", true)
		"air":
			a.draw_line(Vector2(4, 104), Vector2(120, 104), ROAD, 2.0)
			var y := 40 + fmod(t * 20.0, 50.0)
			var tilt := sin(t * 2.0) * 0.4
			_bus(Vector2(60, y), tilt)
			var w := 30.0 * (0.5 + (y - 40) / 100.0)
			a.draw_rect(Rect2(60 - w / 2, 102, w, 2), Color(0, 0, 0, 0.5))  # the shadow
			_key(Vector2(10, 10), "A", tilt < 0)
			_key(Vector2(34, 10), "D", tilt > 0)
		"landing":
			a.draw_line(Vector2(4, 100), Vector2(120, 100), ROAD, 2.0)
			var labels := [["PERFECT", 0.0, Color("#7dff6a")], ["HARD", 0.35, Color("#ff9a2e")], ["WRECK", 0.8, Color("#ff3b4e")]]
			var pick: Array = labels[int(t / 1.5) % 3]
			_bus(Vector2(62, 88), pick[1])
			a.draw_string(PixelFont.get_font(), Vector2(0, 30), pick[0], HORIZONTAL_ALIGNMENT_CENTER, 124, 8, pick[2])
		"flips":
			_bus(Vector2(62, 60), t * 3.0)
			a.draw_arc(Vector2(62, 60), 34, -PI / 2, -PI / 2 + fmod(t * 3.0, TAU), 24, YEL, 1.0)
			_key(Vector2(10, 10), "D", true)
		"stops":
			a.draw_line(Vector2(4, 100), Vector2(120, 82), ROAD, 2.0)
			a.draw_line(Vector2(50, 100 - 46 * 0.155 - 2), Vector2(90, 100 - 86 * 0.155 - 2), YEL, 2.0)  # the box, on the slope
			a.draw_rect(Rect2(96, 50, 2, 34), Color("#9a9aa8"))
			a.draw_rect(Rect2(92, 42, 10, 9), Color("#3a7af0"))
			var k := clampf(fmod(t, 3.0) / 1.2, 0.0, 1.0)
			_bus(Vector2(20 + 50 * ease(k, 0.4), 90 - (20 + 50 * ease(k, 0.4)) * 0.155 - 4), -0.155)
			if k >= 1.0:
				var fill := clampf((fmod(t, 3.0) - 1.2) / 1.2, 0.0, 1.0)
				a.draw_arc(Vector2(70, 50), 7, -PI / 2, -PI / 2 + TAU * fill, 20, YEL, 2.0)
			_key(Vector2(10, 10), "A", k >= 0.6)
		"towing":
			a.draw_line(Vector2(4, 100), Vector2(120, 100), ROAD, 2.0)
			var k := fmod(t, 3.0) / 3.0
			var bx := 92.0 - 26.0 * minf(k * 1.6, 1.0)
			_bus(Vector2(bx, 88), 0.0)
			a.draw_rect(Rect2(14, 82, 24, 12), Color("#3a7ad8"))  # trailer
			a.draw_circle(Vector2(26, 96), 4, Color("#14121a"))
			a.draw_line(Vector2(38, 90), Vector2(48, 90), INK, 1.0)
			if k > 0.62:
				a.draw_string(PixelFont.get_font(), Vector2(0, 30), "HOOKED!", HORIZONTAL_ALIGNMENT_CENTER, 124, 8, Color("#7dff6a"))
			_key(Vector2(10, 10), "A", k < 0.62)
		"story":
			for i in 7:
				var alive := i < 7 - int(t) % 8
				_heart(Vector2(10 + i * 15, 40), Color("#ff5a78") if alive else Color(1, 1, 1, 0.15))
			a.draw_string(PixelFont.get_font(), Vector2(0, 80), "7 LIVES", HORIZONTAL_ALIGNMENT_CENTER, 124, 8, INK)
		"scoring":
			var g: String = ["C", "B", "A", "S", "SS"][int(t) % 5]
			a.draw_string(PixelFont.get_font(), Vector2(0, 70), g, HORIZONTAL_ALIGNMENT_CENTER, 124, 16, Grading.color(g))


## A tiny bus: body, windows, wheels, rotated about its centre.
func _bus(at: Vector2, rot: float) -> void:
	_art.draw_set_transform(at, rot)
	_art.draw_rect(Rect2(-14, -8, 28, 10), YEL)
	_art.draw_rect(Rect2(14, -3, 5, 5), YEL)
	for x in [-11, -5, 1, 7]:
		_art.draw_rect(Rect2(x, -6, 4, 3), Color("#4a7a98"))
	_art.draw_rect(Rect2(-19, -4, 5, 4), Color("#6a6e80"))  # rocket
	for x in [-8, 10]:
		_art.draw_circle(Vector2(x, 3), 3.5, Color("#14121a"))
	_art.draw_set_transform(Vector2.ZERO)


func _key(at: Vector2, label: String, lit: bool) -> void:
	var w := 8.0 + label.length() * 8.0
	_art.draw_rect(Rect2(at, Vector2(w, 14)), YEL if lit else Color(1, 1, 1, 0.2))
	_art.draw_string(PixelFont.get_font(), at + Vector2(4, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Color("#1a0f29") if lit else INK)


func _heart(at: Vector2, c: Color) -> void:
	_art.draw_rect(Rect2(at + Vector2(1, 0), Vector2(4, 3)), c)
	_art.draw_rect(Rect2(at + Vector2(7, 0), Vector2(4, 3)), c)
	_art.draw_rect(Rect2(at + Vector2(0, 2), Vector2(12, 4)), c)
	_art.draw_rect(Rect2(at + Vector2(2, 6), Vector2(8, 2)), c)
	_art.draw_rect(Rect2(at + Vector2(4, 8), Vector2(4, 2)), c)
