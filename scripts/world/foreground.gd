class_name Foreground
extends Node2D
## Dark silhouettes between the camera and the road (jungle leaves and hanging
## vines, pine boughs, big cacti, basalt spires, moon boulders, alien tendrils,
## city lamp posts). They scroll faster than the world, which sells the depth.
## Every few items is a giant one that sweeps across most of the screen.
## Put this on a CanvasLayer above the world; it draws in screen space.

const PARALLAX := 1.45
const SIZE := Vector2(480, 270)

var terrain: Terrain
var style := ""
var _items: Array[Vector3] = []  # world x, kind seed, scale
var _time := 0.0


func setup(t: Terrain) -> Foreground:
	terrain = t
	style = t.biome.fg
	return self


func _ready() -> void:
	if style == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := 300.0
	var n := 0
	while x < terrain.end_x * PARALLAX:
		n += 1
		var giant := n % 5 == 0  # rare, huge, close to the lens
		_items.append(Vector3(x, rng.randi() % 4, rng.randf_range(1.9, 2.5) if giant else rng.randf_range(0.8, 1.3)))
		x += rng.randf_range(260, 560) if style == "jungle" else rng.randf_range(700, 1200)
		if giant:
			x += 300.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or style == "":
		return
	var c := cam.get_screen_center_position()
	for it in _items:
		var sx := (it.x - c.x * PARALLAX) + SIZE.x / 2
		if sx < -120 or sx > SIZE.x + 120:
			continue
		match style:
			"jungle":
				_jungle(sx, int(it.y), it.z)
			"pine", "snowpine":
				_pine(sx, it.z * 0.6, style == "snowpine")
			"cactus":
				_cactus(sx, it.z)
			"spire":
				_spire(sx, it.z, int(it.y))
			"boulder":
				_boulder(sx, it.z, int(it.y))
			"tendril":
				_tendril(sx, it.z, int(it.y))
			"lamppost":
				_lamppost(sx, it.z)


func _jungle(x: float, kind: int, s: float) -> void:
	var dark := Color("#06140c")
	var mid := Color("#0c2416")
	if kind % 2 == 0:  # vines hanging from the top of the screen
		for k in 4:
			var vx := x + k * 9 * s
			var length := (40 + (k * 23) % 50) * s
			var sway := sin(_time * 1.2 + vx * 0.05) * 4
			draw_line(Vector2(vx, 0), Vector2(vx + sway, length), dark, 2.0)
			for j in range(8, int(length), 9):
				var p := Vector2(vx + sway * j / length, j)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(5, 2), p + Vector2(1, 5)]), mid)
		draw_rect(Rect2(x - 20, 0, 70 * s, 10), dark)
	if kind != 1:  # big leaves rising from the bottom
		for k in 3:
			var base := Vector2(x + k * 16 * s, SIZE.y + 6)
			var a := -PI / 2 + (k - 1) * 0.5 + sin(_time * 0.9 + x * 0.01 + k) * 0.06
			var tip := base + Vector2(cos(a), sin(a)) * 60 * s
			var side := Vector2(-sin(a), cos(a)) * 12 * s
			draw_colored_polygon(PackedVector2Array([base, base.lerp(tip, 0.5) + side, tip, base.lerp(tip, 0.5) - side]),
					dark if k % 2 == 0 else mid)
			draw_line(base, tip, mid, 1.0)


func _pine(x: float, s: float, snowy: bool) -> void:
	var dark := Color("#0a1420") if not snowy else Color("#101a2a")
	draw_rect(Rect2(x - 4 * s, SIZE.y - 90 * s, 8 * s, 90 * s), dark)
	for k in 3:
		var y := SIZE.y - 20 * s - k * 26 * s
		var w := (40 - k * 8) * s
		draw_colored_polygon(PackedVector2Array([Vector2(x - w, y), Vector2(x + w, y), Vector2(x, y - 34 * s)]), dark)
		if snowy:
			draw_rect(Rect2(x - w * 0.8, y - 3, w * 1.6, 2), Color("#8898b8"))


func _cactus(x: float, s: float) -> void:
	var dark := Color("#140a10")
	var h := 110 * s
	draw_rect(Rect2(x - 8 * s, SIZE.y - h, 16 * s, h), dark)
	draw_rect(Rect2(x + 8 * s, SIZE.y - h * 0.55, 14 * s, 8 * s), dark)
	draw_rect(Rect2(x + 16 * s, SIZE.y - h * 0.85, 8 * s, h * 0.35), dark)
	draw_rect(Rect2(x - 20 * s, SIZE.y - h * 0.4, 12 * s, 8 * s), dark)
	draw_rect(Rect2(x - 22 * s, SIZE.y - h * 0.65, 8 * s, h * 0.28), dark)


func _spire(x: float, s: float, kind: int) -> void:
	var dark := Color("#0c0406")
	var h := (100 + kind * 12) * s
	draw_colored_polygon(PackedVector2Array([Vector2(x - 18 * s, SIZE.y), Vector2(x - 6 * s, SIZE.y - h),
			Vector2(x + 2 * s, SIZE.y - h * 0.8), Vector2(x + 16 * s, SIZE.y)]), dark)
	var glow := Color(1, 0.4, 0.1, 0.35 + 0.2 * sin(_time * 2.0 + x))
	draw_line(Vector2(x - 4 * s, SIZE.y - h * 0.6), Vector2(x + 2 * s, SIZE.y - h * 0.2), glow, 1.0)


func _boulder(x: float, s: float, kind: int) -> void:
	var dark := Color("#08080e")
	var r := (24 + kind * 6) * s
	var pts := PackedVector2Array()
	for k in 10:
		var a := PI + k * PI / 9.0
		var rr := r * (0.85 + 0.15 * sin(k * 2.7 + kind))
		pts.append(Vector2(x + cos(a) * rr * 1.4, SIZE.y + 8 + sin(a) * rr))
	draw_colored_polygon(pts, dark)


func _tendril(x: float, s: float, kind: int) -> void:
	var dark := Color("#040c0a")
	var glow := Color(0.5, 1, 0.8, 0.5)
	var prev := Vector2(x, SIZE.y + 4)
	for k in 12:
		var y := SIZE.y - k * 9 * s
		var p := Vector2(x + sin(_time * 1.3 + k * 0.6 + kind) * 6 * s * k / 6.0, y)
		draw_line(prev, p, dark, maxf(1.0, (12 - k) * 0.7 * s))
		prev = p
	draw_circle(prev, 3 * s, glow)


func _lamppost(x: float, s: float) -> void:
	var dark := Color("#0a0610")
	var h := 140 * s
	draw_rect(Rect2(x - 3 * s, SIZE.y - h, 6 * s, h), dark)
	draw_rect(Rect2(x - 3 * s, SIZE.y - h, 30 * s, 5 * s), dark)
	draw_rect(Rect2(x + 22 * s, SIZE.y - h + 5 * s, 8 * s, 3 * s), Color(1, 0.85, 0.5, 0.8))
