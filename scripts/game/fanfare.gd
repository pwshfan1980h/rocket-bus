class_name Fanfare
extends Node2D
## The big celebration for sticking a front flip: a beat of slow motion, a white
## flash, confetti cannons off both ends of the bus, fireworks overhead, a
## rainbow banner, a horn salute and the whole bus losing its mind.
## Add to the world (for the confetti) with play(); `hud` is the screen-space layer.

const SLOWMO := 0.3  ## fraction of normal speed during the hit-stop
const SLOWMO_TIME := 0.55  ## real seconds
const QUIPS := ["DO IT AGAIN!", "I SAW MY LIFE FLASH!", "DRIVER STUCK IT!", "THE DRIVER'S A LEGEND!",
	"10/10 WOULD FLIP AGAIN", "BEST. BUS. EVER.", "MY COFFEE DIDN'T SPILL!", "ENCORE!", "LEGENDARY!"]
const DRIVER_LINES := ["THAT'S WHY THEY PAY ME THE BIG BUCKS!", "STUCK IT!", "TWENTY YEARS OF PRACTICE!",
	"AND THEY SAID BUSES CAN'T FLIP!", "WHO'S THE DRIVER? I'M THE DRIVER!"]

var hud: CanvasLayer
var bus: Bus
var camera: Camera2D


## flips: how many front flips in the jump. perfect: the landing was perfect too.
func play(flips: int, perfect: bool, points: int) -> void:
	var at := bus.chassis.global_position
	_slowmo()
	_flash()
	Fx.shake(5.0)
	Audio.play("jingle_perfect", -1.0)
	Audio.play("cheer", -2.0)
	Audio.play("title_slam", -6.0)
	get_tree().create_timer(0.35, true, false, true).timeout.connect(_salute)
	_confetti(bus.chassis.to_global(Vector2(-38, -14)), Vector2(-0.5, -1))
	_confetti(bus.chassis.to_global(Vector2(50, -10)), Vector2(0.5, -1))
	for i in 3 + flips:
		var p := at + Vector2(randf_range(-140, 200), randf_range(-150, -90))
		get_tree().create_timer(0.25 + i * 0.28, true, false, true).timeout.connect(_firework.bind(p, i))
	var title := "FRONT FLIP!" if flips == 1 else "%s FRONT FLIP!" % ["", "", "DOUBLE", "TRIPLE"][mini(flips, 3)]
	if flips > 3:
		title = "%dx FRONT FLIP!" % flips
	_banner(title, "STUCK IT!" if not perfect else "PERFECTLY STUCK!", "+%d" % points)
	_crowd()
	_punch_zoom()
	get_tree().create_timer(4.0, true, false, true).timeout.connect(queue_free)


func _slowmo() -> void:
	Engine.time_scale = GameState.PACE * SLOWMO
	get_tree().create_timer(SLOWMO_TIME, true, false, true).timeout.connect(restore_time)


static func restore_time() -> void:
	Engine.time_scale = GameState.PACE


func _flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.size = Vector2(480, 270)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tw := flash.create_tween().set_ignore_time_scale()
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)


func _salute() -> void:
	if not is_instance_valid(bus) or bus.is_crashed:
		return
	bus.honk()
	get_tree().create_timer(0.22, true, false, true).timeout.connect(func(): if is_instance_valid(bus): bus.audio.honk())


func _crowd() -> void:
	var p := bus.passengers
	p.react("perfect")
	var riders := p.riders.filter(func(r): return r != p.driver)
	for i in riders.size():  # a Mexican wave down the bus, rear to front
		get_tree().create_timer(0.1 + i * 0.09, true, false, true).timeout.connect(func():
			if is_instance_valid(p):
				riders[i].vel.y -= 160.0)
	var lines := QUIPS.duplicate()
	lines.shuffle()
	for i in 2:
		get_tree().create_timer(0.5 + i * 0.45, true, false, true).timeout.connect(func():
			if is_instance_valid(p):
				p.chatter(lines[i], "voice_happy"))
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
		if is_instance_valid(p):
			p.driver_say(DRIVER_LINES.pick_random(), true, true))


func _punch_zoom() -> void:
	if camera == null or not ("zoom_override" in camera):
		return
	if not is_nan(camera.zoom_override):
		return  # a cinematic (the finish) already owns the camera
	var punch: float = camera.zoom.x * 1.25
	camera.zoom_override = punch
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func():
		if is_instance_valid(camera) and camera.zoom_override == punch:
			camera.zoom_override = NAN)


func _banner(title: String, sub: String, points: String) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var big := _label(root, title, 48, 32, 6)
	var small := _label(root, sub, 86, 16, 4)
	var pts := _label(root, points, 106, 16, 4)
	pts.label_settings.font_color = Color("#7dff6a")
	big.scale = Vector2(2.4, 2.4)
	small.scale = Vector2.ZERO
	pts.scale = Vector2.ZERO
	var tw := root.create_tween().set_ignore_time_scale()
	tw.tween_property(big, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	tw.tween_property(small, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(Audio.play.bind("stamp", -4.0))
	tw.tween_property(pts, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(Audio.play.bind("cha_ching", -6.0))
	tw.tween_interval(1.4)
	tw.tween_property(root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(root.queue_free)
	var hue := root.create_tween().set_ignore_time_scale().set_loops(12)
	hue.tween_method(func(h: float):
		big.label_settings.font_color = Color.from_hsv(h, 0.7, 1.0)
		small.label_settings.font_color = Color.from_hsv(fmod(h + 0.5, 1.0), 0.5, 1.0), 0.0, 1.0, 0.2)


func _label(parent: Control, text: String, y: float, size: int, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(480, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(240, size / 2.0)
	l.label_settings = PixelFont.settings(size, Color.WHITE, outline)
	l.label_settings.shadow_size = 2
	l.label_settings.shadow_color = Color("#ff4aa8")
	l.label_settings.shadow_offset = Vector2(2, 2)
	parent.add_child(l)
	return l


func _confetti(at: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 90
	p.lifetime = 2.2
	p.direction = dir
	p.spread = 28.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 340.0
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_initial_ramp = _rainbow()
	p.color_ramp = _fade()
	_fire(p, 2.6)


func _firework(at: Vector2, i: int) -> void:
	if not is_inside_tree():
		return
	Audio.play_at("rocket_ignite" if i % 2 == 0 else "star", at, -8.0, 0.2)
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 48
	p.lifetime = 1.1
	p.spread = 180.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 120.0
	p.damping_min = 50.0
	p.damping_max = 70.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	var hue := randf()
	p.color_initial_ramp = _gradient([[0.0, Color.from_hsv(hue, 0.6, 1.0)], [1.0, Color.from_hsv(fmod(hue + 0.15, 1.0), 0.8, 1.0)]])
	p.color_ramp = _fade()
	_fire(p, 1.5)
	var glow := PointLight2D.new()
	glow.texture = preload("res://assets/sprites/light_radial.png")
	glow.color = Color.from_hsv(hue, 0.5, 1.0)
	glow.energy = 1.6
	glow.texture_scale = 3.0
	glow.position = at
	add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(glow, "energy", 0.0, 0.6)
	tw.tween_callback(glow.queue_free)


func _fire(p: CPUParticles2D, life: float) -> void:
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life).timeout.connect(p.queue_free)


static func _rainbow() -> Gradient:
	var stops := []
	for i in 7:
		stops.append([i / 6.0, Color.from_hsv(i / 7.0, 0.75, 1.0)])
	return _gradient(stops)


static func _fade() -> Gradient:
	return _gradient([[0.0, Color.WHITE], [0.75, Color.WHITE], [1.0, Color(1, 1, 1, 0)]])


static func _gradient(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	return g
