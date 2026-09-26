extends Control
## First screen. Browsers only allow audio after a click/keypress, so we wait for one.

var _time := 0.0
var _prompt: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1a0f29")
	bg.size = Vector2(480, 270)
	add_child(bg)
	var title := _center("ROCKET BUS", 96, 32, Color("#ffcc26"), 6)
	title.label_settings.shadow_size = 2
	title.label_settings.shadow_color = Color("#ff4aa8")
	title.label_settings.shadow_offset = Vector2(3, 3)
	_prompt = _center("CLICK OR PRESS ANY KEY", 160, 8, Color.WHITE, 2)
	_center("HEADPHONES RECOMMENDED", 250, 8, Color(1, 1, 1, 0.35), 0)
	# Test hook: ?autotest in the page URL skips the "press any key" wait.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("autotest"):
		get_tree().create_timer(1.0).timeout.connect(_start)


func _process(delta: float) -> void:
	_time += delta
	_prompt.visible = fmod(_time, 1.0) < 0.65


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	_start()


func _start() -> void:
	set_process_input(false)
	print("AUDIO buses=%d sfx_bus=%d mix_rate=%d" % [AudioServer.bus_count, AudioServer.get_bus_index("SFX"), AudioServer.get_mix_rate()])
	Audio.play("ui_start", -4.0)
	Transition.go("res://scenes/intro.tscn" if not GameState.seen_intro else "res://scenes/main_menu.tscn")


func _center(text: String, y: float, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = PixelFont.settings(size, color, outline)
	l.position = Vector2(0, y)
	l.size = Vector2(480, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l
