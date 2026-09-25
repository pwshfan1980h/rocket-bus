extends Node2D
## Screen-space parallax backdrop: dusk sky, sun, bay bridge, city skyline with
## lit windows and neon, palm silhouettes. Lives on its own CanvasLayer so the
## world's CanvasModulate (night tint) doesn't darken the sky.

const SIZE := Vector2(480, 270)
const SKY := [
	Color8(34, 18, 70), Color8(60, 26, 100), Color8(104, 36, 128), Color8(170, 52, 132),
	Color8(226, 86, 118), Color8(252, 136, 96), Color8(255, 184, 104),
]
const HILLS := Color8(118, 46, 108)
const BRIDGE := Color8(196, 60, 72)
const CITY := Color8(62, 26, 84)
const CITY_LIT := Color8(255, 210, 120)
const NEON := [Color8(255, 70, 170), Color8(60, 240, 220), Color8(255, 220, 60)]
const PALMS := Color8(30, 12, 42)

var _stars: Array[Vector3] = []
var _hills: PackedFloat32Array
var _buildings: Array[Dictionary] = []
var _palms: Array[Vector2] = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 70:
		_stars.append(Vector3(rng.randf() * 960, rng.randf() * 90, rng.randf() * TAU))
	_hills = PackedFloat32Array()
	for i in 240:  # 4px columns across a 960px loop
		var x := i * 4.0
		_hills.append(22 + 12 * sin(x / 70.0) + 7 * sin(x / 23.0 + 1.3))
	var x := 0.0
	while x < 960:
		var w := rng.randi_range(14, 34)
		var h := rng.randi_range(24, 76)
		var lit := []
		for wy in range(4, h - 3, 5):
			for wx in range(3, w - 3, 4):
				if rng.randf() < 0.3:
					lit.append(Vector2(wx, wy))
		var neon := -1 if rng.randf() < 0.6 else rng.randi() % NEON.size()
		_buildings.append({"x": x, "w": w, "h": h, "lit": lit, "neon": neon})
		x += w + rng.randi_range(1, 6)
	for i in 6:
		_palms.append(Vector2(i * 160 + rng.randf_range(0, 90), rng.randf_range(0.8, 1.2)))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cx := cam.get_screen_center_position().x if cam else 0.0
	var cy := cam.get_screen_center_position().y if cam else 0.0
	var horizon := roundf(190.0 - (cy + 40.0) * 0.15)

	var band := horizon / SKY.size()
	for i in SKY.size():  # dithered sky bands
		var y0 := roundf(i * band)
		draw_rect(Rect2(0, y0, SIZE.x, band + 1), SKY[i])
		if i + 1 < SKY.size():
			for dx in range(0, int(SIZE.x), 2):
				draw_rect(Rect2(dx + (int(y0 + band) % 2), y0 + band - 1, 1, 1), SKY[i + 1])
	for s in _stars:
		var sx := fposmod(s.x - cx * 0.02, 960.0)
		if sx < SIZE.x and s.y < horizon - 90:
			var tw := 0.5 + 0.5 * sin(_time * 2.0 + s.z)
			draw_rect(Rect2(sx, s.y, 1, 1), Color(1, 0.95, 0.9, 0.35 + tw * 0.6))

	# Big arcade sun sinking into the bay, with scanline cuts.
	var sun := Vector2(340, horizon - 18)
	for dy in range(-30, 31):
		var y := sun.y + dy
		if dy > 4 and (dy % 5) < 2:
			continue
		var half := sqrt(maxf(0.0, 30.0 * 30.0 - dy * dy))
		var c := Color8(255, 236, 140).lerp(Color8(255, 90, 120), (dy + 30) / 60.0)
		draw_rect(Rect2(roundf(sun.x - half), y, roundf(half * 2), 1), c)

	# Hills + bridge (slowest layer).
	var hx := fposmod(cx * 0.05, 960.0)
	for i in _hills.size():
		var x := fposmod(i * 4.0 - hx, 960.0)
		if x < SIZE.x + 4:
			draw_rect(Rect2(x, horizon - _hills[i], 4, _hills[i] + 2), HILLS)
	_draw_bridge(fposmod(180.0 - hx, 960.0), horizon)

	# City skyline.
	var bx := fposmod(cx * 0.15, 960.0)
	for b in _buildings:
		var x := fposmod(b.x - bx, 960.0)
		if x > SIZE.x:
			continue
		var top: float = horizon - b.h + 6
		draw_rect(Rect2(x, top, b.w, b.h), CITY)
		for p in b.lit:
			draw_rect(Rect2(x + p.x, top + p.y, 2, 1), CITY_LIT)
		if b.neon >= 0:
			var nc: Color = NEON[b.neon]
			nc.a = 0.75 + 0.25 * sin(_time * 5.0 + b.x)
			draw_rect(Rect2(x + 2, top - 3, b.w - 4, 2), nc)

	# Palms (fastest layer) and the ground fill below everything.
	var px := fposmod(cx * 0.35, 960.0)
	for p in _palms:
		var x := fposmod(p.x - px, 960.0)
		if x < SIZE.x + 30:
			_draw_palm(Vector2(x, horizon + 14), p.y)
	draw_rect(Rect2(0, horizon + 12, SIZE.x, SIZE.y), PALMS)


func _draw_bridge(x: float, horizon: float) -> void:
	var deck := horizon - 14
	for tx in [x, x + 120]:
		draw_rect(Rect2(tx, deck - 46, 4, 60), BRIDGE)
		draw_rect(Rect2(tx - 1, deck - 30, 6, 2), BRIDGE)
	draw_rect(Rect2(x - 60, deck, 240, 2), BRIDGE)
	for i in 60:  # cables sag between and outside the towers
		var t := i / 59.0
		var cxp: float = x + 2 + t * 120
		draw_rect(Rect2(cxp, deck - 44 + 40 * sin(t * PI), 2, 1), BRIDGE)
		draw_rect(Rect2(x - 60 + t * 62, deck - 44 * t + 2, 2, 1), BRIDGE)
		draw_rect(Rect2(x + 122 + t * 58, deck - 44 * (1 - t) + 2, 2, 1), BRIDGE)


func _draw_palm(base: Vector2, s: float) -> void:
	var h := 44.0 * s
	var top := base
	for i in int(h):  # curved trunk
		var t := i / h
		top = base + Vector2(8 * s * t * t, -i)
		draw_rect(Rect2(top.x, top.y, 2, 1), PALMS)
	for a in [-2.6, -2.1, -1.2, -0.5, 0.1]:
		for r in range(1, int(16 * s)):
			var droop := r * r * 0.03
			draw_rect(Rect2(top.x + cos(a) * r, top.y + sin(a) * r * 0.6 + droop, 2, 1), PALMS)
