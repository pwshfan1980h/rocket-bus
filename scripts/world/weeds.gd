class_name Weeds
extends Node2D
## Grass and weeds along the roadside that sway in the wind and get blown flat
## by the bus as it passes. Only the blades near the camera are drawn.

var terrain: Terrain
var bus: Bus
var _blades: Array[Vector4] = []  # x, ground y, height, colour index
var _colors: Array[Color] = []
var _time := 0.0
var _wind := 1.0


func setup(t: Terrain) -> Weeds:
	terrain = t
	return self


func _ready() -> void:
	var palette := {
		"DESERT": ["#b89a50", "#8a7a3a", "#c8b070"], "JUNGLE": ["#3aa048", "#2a7a3a", "#6ac050"],
		"MOUNTAINS": ["#4a8a4a", "#6aa060", "#3a6a3a"], "SNOW": ["#8a8a7a", "#6a6a60"],
		"VOLCANO": ["#4a3a30", "#5a4a3a"], "BAY CITY": ["#4a8a4a", "#3a6a3a"],
	}
	var dense := {"JUNGLE": 3, "MOUNTAINS": 2, "DESERT": 1, "BAY CITY": 1, "SNOW": 1, "VOLCANO": 1}
	var title: String = terrain.biome.title
	for c in palette.get(title, palette.DESERT):
		_colors.append(Color(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := -380.0
	while x < terrain.end_x:
		x += rng.randf_range(6, 40) / dense.get(title, 1)
		var y := terrain.ground_y(x)
		if is_nan(y):
			continue
		for k in rng.randi_range(2, 5):
			var h := rng.randf_range(4, 11 if title != "JUNGLE" else 16)
			_blades.append(Vector4(x + k * 1.5, y + 1, h, rng.randi() % _colors.size()))


func _process(delta: float) -> void:
	_time += delta
	_wind = 1.0 + 0.6 * sin(_time * 0.4)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cx := cam.get_screen_center_position().x
	var bx := INF
	var bvx := 0.0
	var by := 0.0
	if is_instance_valid(bus) and bus.chassis:
		bx = bus.chassis.global_position.x
		by = bus.chassis.global_position.y
		bvx = bus.chassis.linear_velocity.x
	for b in _blades:
		if absf(b.x - cx) > 260:
			continue
		var sway := sin(_time * 2.2 + b.x * 0.13) * 0.35 * _wind + 0.15 * _wind
		var dx := b.x - bx
		if absf(dx) < 70 and absf(b.y - by) < 60:
			# Blown flat by the bus's wake, then spring back.
			sway += clampf(bvx / 300.0, -1.5, 1.5) * (1.0 - absf(dx) / 70.0)
		var mid := Vector2(b.x + sway * b.z * 0.35, b.y - b.z * 0.55)
		var tip := Vector2(b.x + sway * b.z, b.y - b.z * (1.0 - absf(sway) * 0.2))
		var col := _colors[int(b.w)]
		draw_line(Vector2(b.x, b.y), mid, col, 1.0)
		draw_line(mid, tip, col.lightened(0.15), 1.0)
