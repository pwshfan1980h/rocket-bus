class_name Foreground
extends Node2D
## Dark silhouettes between the camera and the road (jungle leaves and hanging
## vines, pine boughs, big cacti). They scroll faster than the world, which sells
## the depth. Put this on a CanvasLayer above the world; it draws in screen space.

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
	while x < terrain.end_x * PARALLAX:
		_items.append(Vector3(x, rng.randi() % 4, rng.randf_range(0.8, 1.3)))
		x += rng.randf_range(220, 520) if style == "jungle" else rng.randf_range(500, 900)


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
