extends Control
## ROUTE 99's map: the legs as stops on a transit map, the way you've come lit up,
## lives and score. Starts a run, picks a fork, sends you down the next leg, or
## shows how the run ended. Nothing here is saved (roguelike).

const LINE := Color("#ffcc26")
const DIM := Color(1, 1, 1, 0.18)

var menu: MenuList
var _time := 0.0
var _choices: Array = []  # leg ids offered at a fork
var _about: Label  ## describes the highlighted fork


func _ready() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -10
	sky.add_child(Backdrop.new().setup("city@night", 0.0))
	add_child(sky)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.08, 0.55)
	shade.size = Vector2(480, 270)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	Audio.music("music_menu")
	_text("ROUTE 99", Vector2(0, 8), 16, LINE, 4)
	_text("STORY  -  7 LIVES, NO SAVES. ONE BAD WEEK TO RETIREMENT.", Vector2(0, 30), 8, Color(1, 1, 1, 0.55), 0)
	var run: Dictionary = GameState.story
	var entries := []
	if run.is_empty():
		_text("THE DRIVER HAS ONE WEEK LEFT. THE ROUTE NOBODY FINISHES.", Vector2(0, 206), 8, Color.WHITE, 2)
		entries = [["new", "START THE ROUTE"], ["menu", "MAIN MENU"]]
	elif run.over == "dead":
		_text("ROUTE CANCELLED.  YOU MADE IT %d LEG%s.  SCORE %d" % [run.path.size(),
				"" if run.path.size() == 1 else "S", run.score], Vector2(0, 206), 8, Color("#ff5a78"), 2)
		entries = [["new", "TRY THE ROUTE AGAIN"], ["menu", "MAIN MENU"]]
	elif run.over == "won":
		var end := Story.ending(run)
		_text(end.title, Vector2(0, 52), 16, Color("#7dff6a"), 4)
		for i in end.lines.size():
			_text(end.lines[i], Vector2(0, 186 + i * 11), 8, Color.WHITE, 2)
		_text("FINAL SCORE %d   LIVES LEFT %d" % [run.score, run.lives], Vector2(0, 222), 8, LINE, 2)
		entries = [["new", "DRIVE IT AGAIN"], ["menu", "MAIN MENU"]]
		Audio.play("level_clear", -4.0)
	else:
		_text("LIVES %d/%d    SCORE %d" % [run.lives, Story.LIVES, run.score], Vector2(0, 44), 8, Color("#ff5a78"), 2)
		if run.at == "":  # a fork: pick the way
			var last: String = run.path[-1]
			_choices = Story.leg(last).next
			_text("THE ROAD SPLITS. WHICH WAY?", Vector2(0, 202), 8, Color.WHITE, 2)
			_about = _text("", Vector2(0, 214), 8, Color("#3cf0dc"), 2)
			for id in _choices:
				entries.append([id, Story.leg(id).title])
		else:
			var leg := Story.leg(run.at)
			_text(leg.blurb.to_upper(), Vector2(0, 208), 8, Color.WHITE, 2)
			entries.append(["go", "DRIVE: " + leg.title])
		entries.append(["menu", "MAIN MENU (RUN STAYS OPEN)"])
	menu = MenuList.new().setup(entries, 8, 11)
	menu.position = Vector2(240, 226)
	if run.is_empty() or run.over != "":
		menu.position.y = 236
	add_child(menu)
	menu.chosen.connect(_on_choice)


func _process(delta: float) -> void:
	_time += delta
	if _about and menu.index < _choices.size():
		_about.text = Story.leg(_choices[menu.index]).blurb.to_upper()
	elif _about:
		_about.text = ""
	queue_redraw()


func _draw() -> void:
	var run: Dictionary = GameState.story
	var path: Array = run.get("path", [])
	if run.get("over", "") == "won":
		return
	# Track lines first, then the stops on top.
	for id in Story.ids():
		for n in Story.leg(id).next:
			var lit: bool = id in path and (n in path or n == run.get("at", ""))
			_rail(Story.MAP[id], Story.MAP[n], LINE if lit else DIM)
	for id in Story.ids():
		var p: Vector2 = Story.MAP[id]
		var here: bool = id == run.get("at", "") or (run.get("at", "x") == "" and id in _choices)
		var done: bool = id in path
		var r := 7.0 + (sin(_time * 5.0) * 1.5 if here else 0.0)
		draw_circle(p, r + 2, Color("#1a0f29"))
		draw_circle(p, r, LINE if done else (Color.WHITE if here else Color(1, 1, 1, 0.3)))
		if done:
			draw_circle(p, 3, Color("#1a0f29"))
		var leg := Story.leg(id)
		var font := PixelFont.get_font()
		var col := Color.WHITE if here or done else Color(1, 1, 1, 0.45)
		var words: PackedStringArray = leg.title.split(" ")
		for k in words.size():
			draw_string(font, p + Vector2(-44, 20 + k * 9), words[k], HORIZONTAL_ALIGNMENT_CENTER, 88, 8, col)
		draw_string(font, p + Vector2(-44, -14), Biomes.get_biome(leg.biome).title, HORIZONTAL_ALIGNMENT_CENTER, 88, 8,
				Color("#3cf0dc", 0.6))


## Transit-map style: across, then a 45-degree jog to the other row.
func _rail(a: Vector2, b: Vector2, col: Color) -> void:
	var mid := (a.x + b.x) / 2.0
	var dy := b.y - a.y
	var p1 := Vector2(mid - absf(dy) / 2.0, a.y)
	var p2 := Vector2(mid + absf(dy) / 2.0, b.y)
	for pair in [[a, p1], [p1, p2], [p2, b]]:
		draw_line(pair[0], pair[1], col, 3.0)


func _on_choice(id: String) -> void:
	menu.active = false
	match id:
		"new":
			GameState.new_story()
			_go()
		"go":
			_go()
		"menu":
			GameState.story_mode = false
			Transition.go("res://scenes/main_menu.tscn")
		_:  # a fork choice
			GameState.story.at = id
			_go()


func _go() -> void:
	GameState.story_mode = true
	GameState.checkpoint = {}
	Transition.go("res://scenes/level.tscn")


func _text(t: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.size = Vector2(480, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = PixelFont.settings(size, color, outline)
	add_child(l)
	return l
