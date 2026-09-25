extends Node2D
## Opening cinematic: a bus in the middle of nowhere, a road that ends, a very
## bad idea, and a title card in slow motion. Any key skips.

const SEGMENTS := [
	{"t": "flat", "len": 560}, {"t": "ramp", "len": 150, "rise": 52},
	{"t": "gap", "len": 260, "kind": "chasm", "dy": 0}, {"t": "flat", "len": 1400},
]

var world: World
var bus: Bus
var _ui: CanvasLayer
var _phase := "arrive"
var _done := false
var _lip_x := 0.0


func _ready() -> void:
	GameState.seen_intro = true
	world = World.new().build("desert", SEGMENTS)
	add_child(world)
	_lip_x = world.terrain.ramps[0].lip_x
	bus = world.spawn_bus(Vector2(-320, world.terrain.surface_y(-320) - 31), 100.0, Vector2(220, 0))
	bus.landed.connect(_on_landed)
	Audio.music("")
	Audio.ambience("amb_desert_loop")
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_label("PRESS ANY KEY TO SKIP", Vector2(0, 256), 8, Color(1, 1, 1, 0.35), 0)
	_run()


func _run() -> void:
	_typewrite("SOMEWHERE IN THE MIDDLE OF NOWHERE...", Vector2(0, 36))
	await _until(func(): return bus.chassis.global_position.x > 200)
	_phase = "brake"
	await _until(func(): return absf(bus.get_speed()) < 6.0)
	_phase = "wait"
	await _wait(0.5)
	bus.passengers.chatter("UH... DRIVER?", "voice_hurt")
	await _wait(1.1)
	bus.passengers.chatter("IS THE BRIDGE OUT?!", "voice_hurt")
	await _wait(1.0)
	bus.honk()
	await _wait(0.5)
	bus.passengers.chatter("HOLD ON TO YOUR HATS!", "voice_happy")
	Audio.music("music_menu", 0.2)
	await _wait(0.6)
	_phase = "go"
	await _until(func(): return bus.airborne and bus.chassis.global_position.x > _lip_x + 50)
	Engine.time_scale = 0.3
	_title_slam()
	await get_tree().create_timer(1.4, true, false, true).timeout
	Engine.time_scale = 1.0


func _physics_process(_delta: float) -> void:
	if bus == null or bus.chassis == null:
		return
	var c := bus.chassis
	match _phase:
		"arrive":
			bus.ai_input = {"right": 0.5 if bus.get_speed() < 230.0 else 0.0, "fire": false}
		"brake", "wait":
			bus.ai_input = {"right": -1.0 if bus.get_speed() > 6.0 else 0.0, "fire": false}
		"go":
			var x := c.global_position.x
			var right := 1.0
			if bus.airborne:
				right = -clampf(wrapf(c.rotation, -PI, PI) * 2.0 + c.angular_velocity * 2.5, -1.0, 1.0)
			elif x > _lip_x + 100:
				right = 0.2
			bus.ai_input = {"right": right, "fire": x > _lip_x - 60 and x < _lip_x + 190}


func _on_landed(_grade: String, _i: float, _a: float) -> void:
	await _wait(1.8)
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	Transition.go("res://scenes/main_menu.tscn", 0.5)


func _title_slam() -> void:
	Audio.play("title_slam", 0.0)
	Fx.shake(10.0)
	var l := _label("ROCKET BUS", Vector2(0, 70), 32, Color("#ffcc26"), 6)
	l.label_settings.shadow_size = 2
	l.label_settings.shadow_color = Color("#ff4aa8")
	l.label_settings.shadow_offset = Vector2(3, 3)
	l.pivot_offset = Vector2(240, 16)
	l.scale = Vector2(3, 3)
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sub := _label("TIME THE ROCKET.  LAND IT LEVEL.", Vector2(0, 108), 8, Color.WHITE, 2)
	sub.modulate.a = 0.0
	tw.tween_property(sub, "modulate:a", 1.0, 0.3)


func _typewrite(text: String, pos: Vector2) -> void:
	var l := _label("", pos, 8, Color("#ffe6b0"), 2)
	for i in text.length():
		l.text = text.substr(0, i + 1)
		if text[i] != " ":
			Audio.play("typewriter", -10.0, 1.0, 0.2)
		await _wait(0.05)
	await _wait(1.2)
	create_tween().tween_property(l, "modulate:a", 0.0, 0.6)


func _until(cond: Callable) -> void:
	while not cond.call():
		await get_tree().physics_frame


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _label(text: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(480, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = PixelFont.settings(size, color, outline)
	_ui.add_child(l)
	return l
