class_name Weather
extends Node2D
## Screen-space weather in front of the world: "rain" (with splashes and
## lightning), "sandstorm", "blizzard", "ash". Put it on a CanvasLayer above the
## world. Also exposes `headwind`, a small force the level applies to the bus.

const SIZE := Vector2(480, 270)

var kind := ""
var terrain: Terrain
var tint: CanvasModulate  ## the world's night tint; lightning flashes it
var headwind := 0.0
var _drops: Array[Vector4] = []  # x, y, speed, length/size
var _splashes: Array[Vector3] = []  # world x, world y, age
var _time := 0.0
var _flash := 0.0
var _bolt: PackedVector2Array
var _next_strike := 6.0
var _base_tint := Color.WHITE
var _loop: AudioStreamPlayer


func setup(k: String, t: Terrain, world_tint: CanvasModulate) -> Weather:
	kind = k
	terrain = t
	tint = world_tint
	return self


func _ready() -> void:
	if kind == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n: int = {"rain": 220, "sandstorm": 320, "blizzard": 260, "ash": 180}.get(kind, 0)
	for i in n:
		_drops.append(Vector4(rng.randf() * SIZE.x, rng.randf() * SIZE.y, rng.randf_range(0.6, 1.0), rng.randf_range(0.5, 1.0)))
	headwind = {"sandstorm": 35.0, "blizzard": 25.0}.get(kind, 0.0)
	var sound: String = {"rain": "rain_loop", "sandstorm": "sandstorm_loop", "blizzard": "blizzard_loop"}.get(kind, "")
	if sound != "":
		_loop = Audio.make_loop(sound, self, -10.0)
		_loop.play()
	if tint:
		if kind == "rain":
			tint.color = tint.color.darkened(0.2)
		_base_tint = tint.color


func _process(delta: float) -> void:
	if kind == "":
		return
	_time += delta
	for i in _drops.size():
		var d := _drops[i]
		match kind:
			"rain":
				d.y += 520 * d.z * delta
				d.x -= 90 * d.z * delta
			"sandstorm":
				d.x -= (380 + 120 * sin(_time + d.w * 10)) * d.z * delta
				d.y += sin(_time * 3 + d.w * 20) * 20 * delta
			"blizzard":
				d.x -= 260 * d.z * delta
				d.y += 140 * d.z * delta + sin(_time * 4 + d.w * 9) * 30 * delta
			"ash":
				d.y += 30 * d.z * delta
				d.x += sin(_time + d.w * 7) * 12 * delta
		d.x = fposmod(d.x, SIZE.x)
		d.y = fposmod(d.y, SIZE.y)
		_drops[i] = d
	if kind == "rain":
		_rain_splashes(delta)
		_lightning(delta)
	queue_redraw()


func _rain_splashes(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or terrain == null:
		return
	var c := cam.get_screen_center_position()
	for i in 4:
		var x := c.x + randf_range(-300, 300)
		var y := terrain.surface_y(x)
		if not is_nan(y):
			_splashes.append(Vector3(x, y, 0.0))
	for i in _splashes.size():
		_splashes[i].z += delta
	_splashes = _splashes.filter(func(s): return s.z < 0.25)


func _lightning(delta: float) -> void:
	_next_strike -= delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if tint:
		tint.color = _base_tint.lerp(Color(1.4, 1.4, 1.6), _flash * 0.8)
	if _next_strike <= 0.0:
		_next_strike = randf_range(7.0, 15.0)
		_flash = 1.0
		_bolt = PackedVector2Array()
		var p := Vector2(randf_range(60, SIZE.x - 60), 0)
		while p.y < SIZE.y * 0.55:
			_bolt.append(p)
			p += Vector2(randf_range(-14, 14), randf_range(10, 22))
		get_tree().create_timer(randf_range(0.2, 0.8)).timeout.connect(Audio.play.bind("thunder", -2.0, randf_range(0.85, 1.1)))


func _draw() -> void:
	match kind:
		"rain":
			for d in _drops:
				draw_line(Vector2(d.x, d.y), Vector2(d.x + 3 * d.z, d.y - 12 * d.w), Color(0.7, 0.8, 1.0, 0.35 * d.z), 1.0)
			var xf := get_viewport().get_canvas_transform()
			for s in _splashes:
				var p := xf * Vector2(s.x, s.y)
				var r := 1.0 + s.z * 14.0
				draw_line(p + Vector2(-r, -1), p + Vector2(-r * 0.4, -3), Color(0.8, 0.9, 1, 0.6 - s.z * 2), 1.0)
				draw_line(p + Vector2(r, -1), p + Vector2(r * 0.4, -3), Color(0.8, 0.9, 1, 0.6 - s.z * 2), 1.0)
			if _flash > 0.6 and _bolt.size() > 1:
				draw_polyline(_bolt, Color(1, 1, 1, _flash), 2.0)
			if _flash > 0.0:
				draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1, 1, 1, _flash * 0.35))
		"sandstorm":
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.85, 0.58, 0.32, 0.34 + 0.08 * sin(_time * 0.7)))
			for k in 4:  # rolling dust banks
				var y := fposmod(k * 71.0 + _time * 9.0, SIZE.y + 60) - 30
				draw_rect(Rect2(0, y, SIZE.x, 22), Color(0.9, 0.65, 0.4, 0.12))
			for d in _drops:
				draw_line(Vector2(d.x, d.y), Vector2(d.x + 16 * d.w, d.y + 1), Color(0.98, 0.82, 0.55, 0.6 * d.z), 1.0 + d.w)
		"blizzard":
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.85, 0.9, 1.0, 0.16 + 0.05 * sin(_time * 0.5)))
			for d in _drops:
				var sz := 1.0 if d.w < 0.8 else 2.0
				draw_rect(Rect2(d.x, d.y, sz, sz), Color(1, 1, 1, 0.8 * d.z))
		"ash":
			draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.35, 0.1, 0.08, 0.18))
			for d in _drops:
				var c := Color(0.5, 0.45, 0.45, 0.7) if d.w < 0.85 else Color(1, 0.55, 0.2, 0.9)
				draw_rect(Rect2(d.x, d.y, 1, 1), c)
