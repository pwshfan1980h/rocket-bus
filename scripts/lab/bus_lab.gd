extends Node2D
## Bus Lab: a test track for designing and tuning the Rocket Bus.
##
## 1-5 spawn scripted scenarios that show each physics outcome, 6 = free drive.
## A/D or arrows drive (tilt in the air), SPACE fires the rocket, R resets.
## User args:  -- --demo  (auto-play all scenarios)   --quit  (exit after demo)
##             --probe   (print physics telemetry, for tuning)

const BusScene := preload("res://scenes/bus.tscn")
const LIGHT_TEX := preload("res://assets/sprites/light_radial.png")
const REST_Y := -30.0  # chassis y when sitting on the road
const RAMP_LIP_X := 1076.0

const PRESETS := {
	1: {"name": "PERFECT LANDING", "pos": Vector2(200, REST_Y - 60), "rot": 0.0, "vel": Vector2(150, 0)},
	2: {"name": "GOOD LANDING", "pos": Vector2(200, REST_Y - 130), "rot": 9.0, "vel": Vector2(170, 0)},
	3: {"name": "HARD LANDING", "pos": Vector2(200, REST_Y - 200), "rot": 21.0, "vel": Vector2(180, 0)},
	4: {"name": "CRASH (TORSION)", "pos": Vector2(200, REST_Y - 220), "rot": 50.0, "vel": Vector2(210, 80), "spin": 1.0},
	5: {"name": "RAMP + ROCKET", "pos": Vector2(560, REST_Y), "rot": 0.0, "vel": Vector2(250, 0), "auto": true},
	6: {"name": "FREE DRIVE", "pos": Vector2(0, REST_Y), "rot": 0.0, "vel": Vector2.ZERO},
}
const DEMO := [[5, 5.2], [1, 3.0], [2, 3.0], [3, 3.4], [4, 4.6]]

var bus: Bus
var preset := 6
var camera: Camera2D
var _args := PackedStringArray()
var _demo_step := -1
var _demo_clock := 0.0
var _probe_clock := 0.0
var _clock := 0.0
var _hud := {}


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	var night := CanvasModulate.new()
	night.color = Color(0.68, 0.6, 0.84)
	add_child(night)

	var sky := CanvasLayer.new()
	sky.layer = -10
	sky.add_child(preload("res://scripts/lab/backdrop.gd").new())
	add_child(sky)

	add_child(preload("res://scripts/lab/lab_ground.gd").new())
	for x in range(-600, 4200, 380):
		_add_streetlight(x)

	camera = preload("res://scripts/lab/follow_camera.gd").new()
	add_child(camera)
	_build_hud()

	if "--demo" in _args:
		_next_demo_step()
	else:
		spawn(6)


func spawn(id: int) -> void:
	preset = id
	if bus:
		bus.queue_free()
	var p: Dictionary = PRESETS[id]
	bus = BusScene.instantiate()
	bus.setup(p.pos, deg_to_rad(p.rot), p.vel, p.get("spin", 0.0))
	add_child(bus)
	bus.landed.connect(_on_landed)
	bus.crashed.connect(_on_crashed)
	camera.target = bus.chassis
	camera.snap()
	_clock = 0.0
	_hud.preset.text = "%d  %s" % [id, p.name]
	_hud.result.text = ""
	_log("spawn %s" % p.name)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_0
		if PRESETS.has(n):
			_demo_step = -1
			spawn(n)
		elif event.is_action("reset"):
			spawn(preset)


func _physics_process(delta: float) -> void:
	_clock += delta
	if PRESETS[preset].get("auto", false) and bus and not bus.is_crashed:
		_autopilot()
	elif bus and not bus.ai_input.is_empty():
		bus.ai_input = {}

	if _demo_step >= 0:
		_demo_clock -= delta
		if _demo_clock <= 0.0:
			_next_demo_step()

	if "--probe" in _args and bus and is_instance_valid(bus.chassis):
		_probe_clock -= delta
		if _probe_clock <= 0.0:
			_probe_clock = 0.05
			var c := bus.chassis
			var travel := []
			for w in bus.wheels:
				travel.append("%.1f" % (c.to_local(w.global_position).y))
			_log("t=%.2f pos=(%.0f,%.0f) rot=%.1f spin=%.2f v=(%.0f,%.0f) wheelY=%s fuel=%.0f ai=%s%s" % [
				_clock, c.position.x, c.position.y, rad_to_deg(c.rotation), c.angular_velocity,
				c.linear_velocity.x, c.linear_velocity.y, travel, bus.fuel, bus.ai_input,
				" CRASHED" if bus.is_crashed else ""])


func _process(_delta: float) -> void:
	if bus:
		_hud.fuel.size.x = roundf(60 * bus.fuel_ratio())


## Scripted run for the ramp preset: floor it, light the rocket off the lip,
## then level the bus in the air.
func _autopilot() -> void:
	var c := bus.chassis
	var x := c.global_position.x
	var in_air := c.global_position.y < REST_Y - 6 and x > RAMP_LIP_X
	var right := 1.0
	if in_air:
		var gains := _gains()
		right = clampf(-(wrapf(c.rotation, -PI, PI) - gains.x) * gains.y - c.angular_velocity * gains.z, -1.0, 1.0)
	elif x > RAMP_LIP_X + 60:
		right = 0.0
	bus.ai_input = {"right": right, "fire": x > RAMP_LIP_X - 50 and x < RAMP_LIP_X + 170}


func _gains() -> Vector3:  # target rot, P, D  (override: --gains=t,p,d)
	for a in _args:
		if a.begins_with("--gains="):
			var g := a.substr(8).split_floats(",")
			return Vector3(g[0], g[1], g[2])
	return Vector3(-0.05, 2.0, 2.5)


func _next_demo_step() -> void:
	_demo_step += 1
	if _demo_step >= DEMO.size():
		_demo_step = -1
		if "--quit" in _args:
			get_tree().quit()
		return
	var step: Array = DEMO[_demo_step]
	for a in _args:  # --only=N plays a single scenario
		if a.begins_with("--only=") and int(a.substr(7)) != step[0]:
			_next_demo_step()
			return
	spawn(step[0])
	_demo_clock = step[1]


func _on_landed(grade: String, impact: float, angle: float) -> void:
	_hud.result.text = "%s  IMPACT %d  ANGLE %.1f" % [grade.to_upper(), impact, angle]
	_log("LANDED %s impact=%.0f angle=%.1f" % [grade, impact, angle])


func _on_crashed(reason: String) -> void:
	var l: Dictionary = bus.last_landing
	_hud.result.text = "CRASH: %s" % reason
	if l.has("impact"):
		_hud.result.text += "  IMPACT %d  ANGLE %.1f" % [l.impact, l.angle]
	_log("CRASHED %s %s" % [reason, l])


func _add_streetlight(x: float) -> void:
	var pole := Polygon2D.new()
	pole.color = Color8(46, 40, 60)
	pole.polygon = PackedVector2Array([
		Vector2(x, 0), Vector2(x, -74), Vector2(x + 14, -74), Vector2(x + 14, -71),
		Vector2(x + 2, -71), Vector2(x + 2, 0),
	])
	add_child(pole)
	var lamp := Polygon2D.new()
	lamp.color = Color8(255, 236, 170)
	lamp.polygon = PackedVector2Array([
		Vector2(x + 9, -71), Vector2(x + 16, -71), Vector2(x + 16, -69), Vector2(x + 9, -69),
	])
	add_child(lamp)
	var light := PointLight2D.new()
	light.texture = LIGHT_TEX
	light.position = Vector2(x + 12, -66)
	light.color = Color(1, 0.62, 0.35)
	light.energy = 1.1
	light.texture_scale = 2.6
	add_child(light)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var title := _label(layer, "ROCKET BUS", Vector2(8, 8), 16, Color("#ffcc26"), 4)
	title.label_settings.shadow_size = 1
	_label(layer, "BUS LAB", Vector2(176, 16), 8, Color("#ff4aa8"), 2)
	_hud.preset = _label(layer, "", Vector2(8, 28), 8, Color("#3cf0dc"), 2)
	_hud.result = _label(layer, "", Vector2(8, 232), 8, Color.WHITE, 2)
	_label(layer, "1 PERFECT 2 GOOD 3 HARD 4 CRASH 5 RAMP 6 DRIVE\n<- -> DRIVE/TILT   SPACE ROCKET   R RESET",
			Vector2(8, 248), 8, Color("#d8f8ff"), 2)
	_label(layer, "FUEL", Vector2(364, 10), 8, Color("#ffcc26"), 2)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.12, 0.8)
	back.position = Vector2(399, 9)
	back.size = Vector2(64, 10)
	layer.add_child(back)
	var fill := ColorRect.new()
	fill.color = Color("#ff4aa8")
	fill.position = Vector2(401, 11)
	fill.size = Vector2(60, 6)
	layer.add_child(fill)
	_hud.fuel = fill


func _label(parent: Node, text: String, pos: Vector2, size: int, color: Color,
		outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(size, color, outline)
	parent.add_child(l)
	return l


func _log(msg: String) -> void:
	if "--probe" in _args:
		print(msg)
