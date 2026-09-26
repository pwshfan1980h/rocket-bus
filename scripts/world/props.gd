class_name Props
extends Node2D
## Roadside scenery drawn once (cacti, trees, rocks...), plus the few props
## that need nodes: warning-sign blinkers, streetlights and the finish bus stop.
## `perches` lists spots where birds can sit (sign tops, tree tops, posts).

const LIGHT_TEX := preload("res://assets/sprites/light_radial.png")

var terrain: Terrain
var biome: Dictionary
var perches: Array[Vector2] = []
var trees: Array[Vector2] = []  # canopy centers (leaf bursts)
var _items: Array[Dictionary] = []
var _blinkers: Array[PointLight2D] = []
var _time := 0.0


func setup(t: Terrain) -> Props:
	terrain = t
	biome = t.biome
	return self


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.end_x) + hash(biome.title)
	var x := -360.0
	while x < terrain.end_x - 40:
		x += rng.randf_range(40, 110)
		var y := terrain.ground_y(x)
		if is_nan(y) or _near_gap_or_sign(x):
			continue
		var kind: String = biome.decor[rng.randi() % biome.decor.size()]
		_place(kind, Vector2(x, y), rng)
	for s in terrain.signs:
		var y := terrain.ground_y(s.x)
		if not is_nan(y):
			_add_warning_sign(Vector2(s.x, y))
	for cx in terrain.checkpoints:
		var cy := terrain.surface_y(cx)
		if not is_nan(cy):
			_items.append({"kind": "checkpoint", "at": Vector2(cx, cy), "s": 1.0, "flip": false})
			perches.append(Vector2(cx - 18, cy - 40))
	if terrain.finish_x > 0:
		_add_bus_stop(Vector2(terrain.finish_x, terrain.surface_y(terrain.finish_x)))


func _process(delta: float) -> void:
	_time += delta
	if biome.get("floating", false):
		queue_redraw()  # alien plants pulse and sway
	for i in _blinkers.size():
		_blinkers[i].energy = 1.2 if fmod(_time + i * 0.3, 1.0) < 0.5 else 0.15


func _near_gap_or_sign(x: float) -> bool:
	for g in terrain.gaps:
		if x > g.x0 - 30 and x < g.x1 + 30:
			return true
	for s in terrain.signs:
		if absf(x - s.x) < 24:
			return true
	return absf(x - terrain.finish_x) < 70


func _place(kind: String, at: Vector2, rng: RandomNumberGenerator) -> void:
	var item := {"kind": kind, "at": at, "s": rng.randf_range(0.8, 1.25), "flip": rng.randf() < 0.5}
	_items.append(item)
	match kind:
		"post":
			perches.append(at + Vector2(0, -12))
		"bigtree":
			perches.append(at + Vector2(rng.randf_range(-10, 10), -70 * item.s))
			trees.append(at + Vector2(0, -60 * item.s))
		"pine", "snowpine", "deadtree":
			perches.append(at + Vector2(0, -48 * item.s))
			trees.append(at + Vector2(0, -30 * item.s))
		"cactus":
			perches.append(at + Vector2(0, -34 * item.s))
		"streetlight":
			perches.append(at + Vector2(6, -76))
			var l := PointLight2D.new()
			l.texture = LIGHT_TEX
			l.position = at + Vector2(10, -70)
			l.color = Color(1, 0.65, 0.35)
			l.energy = 1.0
			l.texture_scale = 2.4
			add_child(l)


func _add_warning_sign(at: Vector2) -> void:
	_items.append({"kind": "warn", "at": at, "s": 1.0, "flip": false})
	perches.append(at + Vector2(0, -36))
	perches.append(at + Vector2(-5, -36))
	var l := PointLight2D.new()
	l.texture = LIGHT_TEX
	l.position = at + Vector2(0, -38)
	l.color = Color(1, 0.6, 0.1)
	l.texture_scale = 0.9
	add_child(l)
	_blinkers.append(l)


func _add_bus_stop(at: Vector2) -> void:
	_items.append({"kind": "busstop", "at": at, "s": 1.0, "flip": false})
	perches.append(at + Vector2(-24, -44))
	var l := PointLight2D.new()
	l.texture = LIGHT_TEX
	l.position = at + Vector2(-20, -40)
	l.color = Color(1, 0.95, 0.8)
	l.energy = 1.3
	l.texture_scale = 2.0
	add_child(l)


func _draw() -> void:
	for it in _items:
		var p: Vector2 = it.at + Vector2(0, 1)
		var s: float = it.s
		var f := -1.0 if it.flip else 1.0
		match it.kind:
			"cactus": _cactus(p, s, f)
			"rock": _rock(p, s)
			"skull": _skull(p, f)
			"post": _post(p)
			"fern": _fern(p, s)
			"bigtree": _bigtree(p, s, f)
			"pine": _pine(p, s, false)
			"snowpine": _pine(p, s, true)
			"snowman": _snowman(p, f)
			"deadtree": _deadtree(p, s, f)
			"guardrail": _guardrail(p)
			"streetlight": _streetlight(p)
			"palm": _palm(p, s, f)
			"hydrant": _hydrant(p)
			"warn": _warn(p)
			"checkpoint": _checkpoint(p)
			"alienplant": _alienplant(p, s)
			"crystal": _crystal(p, s)
			"stalk": _stalk(p, s, f)
			"moonrock": _rock(p, s * 0.8)
			"flag": _flag(p)
			"lander": _lander(p, f)
			"dish": _dish(p, f)
			"busstop": _busstop(p)


# --- Pixel-art painters -------------------------------------------------------

func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)


func _cactus(p: Vector2, s: float, f: float) -> void:
	var g := Color("#3a8a4a")
	var d := Color("#24603a")
	var h := 30 * s
	_r(p.x - 3, p.y - h, 6, h, g)
	_r(p.x - 1, p.y - h, 1, h, d)
	_r(p.x - 2, p.y - h - 1, 4, 1, g)
	_r(p.x + 3 * f - (5 if f < 0 else 0), p.y - h * 0.55, 5, 3, g)  # arm out
	_r(p.x + 6 * f - (3 if f < 0 else 0), p.y - h * 0.85, 3, h * 0.33, g)  # arm up
	_r(p.x - 3 * f - (4 if f > 0 else 0), p.y - h * 0.4, 4, 3, g)
	_r(p.x - 6 * f - (3 if f > 0 else 0), p.y - h * 0.62, 3, h * 0.24, g)
	_r(p.x + 1, p.y - h * 0.7, 1, 1, Color("#ff70a0"))  # flower


func _rock(p: Vector2, s: float) -> void:
	var c := Color(biome.ground.body[2]).darkened(0.25)
	var w := 14 * s
	_r(p.x - w / 2, p.y - 7 * s, w, 7 * s, c)
	_r(p.x - w / 2 + 2, p.y - 9 * s, w - 5, 3, c)
	_r(p.x - w / 2 + 2, p.y - 8 * s, w * 0.4, 1, c.lightened(0.25))


func _skull(p: Vector2, f: float) -> void:
	var b := Color("#f0e8d8")
	_r(p.x - 3, p.y - 4, 6, 4, b)
	_r(p.x - 6 * f - (0 if f > 0 else 2), p.y - 6, 3, 2, b)
	_r(p.x + 4 * f - (0 if f > 0 else 2), p.y - 6, 3, 2, b)
	_r(p.x - 2, p.y - 3, 1, 1, Color.BLACK)
	_r(p.x + 1, p.y - 3, 1, 1, Color.BLACK)


func _post(p: Vector2) -> void:
	_r(p.x - 1, p.y - 12, 2, 12, Color("#f0f0f0"))
	_r(p.x - 1, p.y - 11, 2, 2, Color("#ff5030"))


func _fern(p: Vector2, s: float) -> void:
	var g := Color("#3a9a4a")
	for k in 5:
		var a := -PI / 2 + (k - 2) * 0.45
		var tip := p + Vector2(cos(a), sin(a)) * 14 * s
		draw_line(p, tip, g, 2.0)
		draw_line(tip, tip + Vector2(cos(a + 0.8), sin(a + 0.8)) * 4, g, 1.0)


func _bigtree(p: Vector2, s: float, f: float) -> void:
	var trunk := Color("#5a3a24")
	var leaf := Color("#2a7a3a")
	var leaf_l := Color("#4aa048")
	var h := 62 * s
	_r(p.x - 3, p.y - h, 6, h, trunk)
	_r(p.x - 5, p.y - 4, 10, 4, trunk)  # roots
	for c in [Vector3(0, -h - 8, 18), Vector3(-14 * f, -h + 2, 13), Vector3(14 * f, -h, 14), Vector3(4 * f, -h - 18, 12)]:
		draw_circle(p + Vector2(c.x, c.y) * Vector2(1, 1), c.z * s, leaf)
		draw_circle(p + Vector2(c.x - 4, c.y - 4), c.z * s * 0.45, leaf_l)
	for k in 3:  # vines
		var vx := p.x + (k - 1) * 12 * s
		draw_line(Vector2(vx, p.y - h + 4), Vector2(vx + 2, p.y - h + 24 + k * 6), Color("#3a8a3a"), 1.0)


func _pine(p: Vector2, s: float, snowy: bool) -> void:
	var g := Color("#1e5a3a") if not snowy else Color("#2a5048")
	_r(p.x - 1, p.y - 8, 3, 8, Color("#4a3020"))
	for k in 4:
		var w := (18 - k * 4) * s
		var y := p.y - 8 - k * 10 * s
		var pts := PackedVector2Array([Vector2(p.x - w, y), Vector2(p.x + w, y), Vector2(p.x, y - 16 * s)])
		draw_colored_polygon(pts, g)
		if snowy:
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - w * 0.45, y - 9 * s), Vector2(p.x + w * 0.45, y - 9 * s),
					Vector2(p.x, y - 16 * s)]), Color("#f0f6ff"))
			_r(p.x - w, y - 1, w * 2, 1, Color("#e8f0ff"))


func _snowman(p: Vector2, f: float) -> void:
	var w := Color("#f4f8ff")
	draw_circle(p + Vector2(0, -6), 6, w)
	draw_circle(p + Vector2(0, -16), 4.5, w)
	draw_circle(p + Vector2(0, -24), 3.5, w)
	_r(p.x - 3, p.y - 31, 6, 4, Color("#20202a"))
	_r(p.x - 4, p.y - 28, 8, 1, Color("#20202a"))
	_r(p.x + 1 * f - (3 if f < 0 else 0), p.y - 24, 3, 1, Color("#ff8a20"))
	draw_line(p + Vector2(-4, -16), p + Vector2(-11, -21), Color("#5a3a24"), 1.0)
	draw_line(p + Vector2(4, -16), p + Vector2(11, -19), Color("#5a3a24"), 1.0)
	_r(p.x - 2, p.y - 18, 4, 1, Color("#d03040"))  # scarf


func _deadtree(p: Vector2, s: float, f: float) -> void:
	var c := Color("#1a1216")
	var h := 44 * s
	draw_line(p, p + Vector2(0, -h), c, 3.0)
	draw_line(p + Vector2(0, -h * 0.6), p + Vector2(12 * f, -h * 0.9), c, 2.0)
	draw_line(p + Vector2(0, -h * 0.4), p + Vector2(-10 * f, -h * 0.65), c, 2.0)
	draw_line(p + Vector2(12 * f, -h * 0.9), p + Vector2(16 * f, -h * 0.85), c, 1.0)


func _guardrail(p: Vector2) -> void:
	var y := terrain.ground_y(p.x + 50)
	if is_nan(y):
		return
	var end := Vector2(p.x + 50, y + 1)
	for k in 3:
		var q := p.lerp(end, k / 2.0)
		_r(q.x - 1, q.y - 9, 2, 9, Color("#8a8a96"))
	draw_line(p + Vector2(0, -7), end + Vector2(0, -7), Color("#c8c8d4"), 2.0)


func _streetlight(p: Vector2) -> void:
	_r(p.x - 1, p.y - 74, 2, 74, Color("#2e2a3a"))
	_r(p.x, p.y - 74, 14, 2, Color("#2e2a3a"))
	_r(p.x + 8, p.y - 72, 6, 2, Color("#ffeca8"))


func _palm(p: Vector2, s: float, f: float) -> void:
	var top := p
	for i in int(44 * s):
		top = p + Vector2(8 * s * f * pow(i / (44.0 * s), 2), -i)
		_r(top.x, top.y, 2, 1, Color("#6a4a30"))
	for a in [-2.6, -2.1, -1.2, -0.5, 0.1]:
		for r in range(1, int(16 * s)):
			_r(top.x + cos(a) * r, top.y + sin(a) * r * 0.6 + r * r * 0.03, 2, 1, Color("#2a7a3a"))


func _hydrant(p: Vector2) -> void:
	_r(p.x - 2, p.y - 8, 5, 8, Color("#d8303a"))
	_r(p.x - 3, p.y - 5, 7, 2, Color("#d8303a"))
	_r(p.x - 1, p.y - 9, 3, 1, Color("#f05060"))


func _alienplant(p: Vector2, s: float) -> void:
	var glow := 0.7 + 0.3 * sin(_time * 2.0 + p.x)
	draw_line(p, p + Vector2(0, -14 * s), Color("#3a6a4a"), 2.0)
	draw_circle(p + Vector2(0, -16 * s), 4 * s, Color(0.45, 1.0, 0.75, glow))
	draw_circle(p + Vector2(0, -16 * s), 2 * s, Color(0.9, 1.0, 0.9, glow))
	for k in [-1, 1]:
		draw_line(p + Vector2(0, -5), p + Vector2(k * 6 * s, -9 * s), Color("#3a6a4a"), 1.0)


func _crystal(p: Vector2, s: float) -> void:
	for k in 3:
		var h := (12 + k * 6) * s
		var x := p.x + (k - 1) * 4
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, p.y), Vector2(x + 2, p.y), Vector2(x, p.y - h)]),
				Color("#b070ff").lightened(0.1 * k))


func _stalk(p: Vector2, s: float, f: float) -> void:
	var prev := p
	for i in 12:
		var t := i / 11.0
		var q := p + Vector2(sin(t * 3.0 + _time * 0.8) * 5 * f, -t * 40 * s)
		draw_line(prev, q, Color("#4a3a5a"), 2.0 - t)
		prev = q
	draw_circle(prev, 2.5, Color(1.0, 0.6, 0.9, 0.8 + 0.2 * sin(_time * 3.0)))


func _checkpoint(p: Vector2) -> void:
	for side in [-18, 16]:
		_r(p.x + side, p.y - 40, 2, 40, Color("#c8c8d0"))
	_r(p.x - 18, p.y - 42, 36, 8, Color("#28c8b4"))
	for k in 9:
		_r(p.x - 17 + k * 4, p.y - 41, 2, 2, Color.WHITE if k % 2 == 0 else Color("#1a1420"))
		_r(p.x - 15 + k * 4, p.y - 39, 2, 2, Color.WHITE if k % 2 == 1 else Color("#1a1420"))


func _flag(p: Vector2) -> void:
	_r(p.x, p.y - 34, 1, 34, Color("#c8c8d0"))
	_r(p.x + 1, p.y - 34, 16, 10, Color("#ffcc26"))
	_r(p.x + 1, p.y - 30, 16, 2, Color("#1a1420"))  # checker band
	for k in 8:
		_r(p.x + 1 + k * 2, p.y - 30 + (k % 2), 1, 1, Color.WHITE)
	_r(p.x + 4, p.y - 33, 8, 2, Color("#ff4aa8"))


func _lander(p: Vector2, f: float) -> void:
	var gold := Color("#d8a830")
	_r(p.x - 10, p.y - 22, 20, 12, gold)
	_r(p.x - 10, p.y - 22, 20, 2, gold.lightened(0.3))
	_r(p.x - 7, p.y - 32, 14, 10, Color("#b8b8c4"))
	_r(p.x - 3, p.y - 29, 5, 4, Color("#1a1a2a"))
	for side in [-1, 1]:
		draw_line(Vector2(p.x + side * 9, p.y - 12), Vector2(p.x + side * 15, p.y), Color("#a0a0aa"), 1.0)
		_r(p.x + side * 15 - 2, p.y - 1, 4, 1, Color("#a0a0aa"))
	_r(p.x + 5 * f, p.y - 36, 1, 4, Color("#c8c8d0"))


func _dish(p: Vector2, f: float) -> void:
	_r(p.x - 1, p.y - 16, 2, 16, Color("#a0a0aa"))
	draw_arc(Vector2(p.x + 2 * f, p.y - 22), 8, PI * 0.1, PI * 1.1, 10, Color("#e0e0ea"), 3.0)
	draw_line(Vector2(p.x + 2 * f, p.y - 22), Vector2(p.x + 8 * f, p.y - 28), Color("#c8c8d0"), 1.0)
	_r(p.x + 8 * f - 1, p.y - 29, 2, 2, Color("#ff4040"))


func _warn(p: Vector2) -> void:
	_r(p.x - 1, p.y - 30, 2, 30, Color("#6a6a74"))
	var c := p + Vector2(0, -30)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0)]), Color("#ffc828"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), Color("#1a1420"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), Color("#ffc828"))
	_r(c.x - 0.5, c.y - 4, 1, 5, Color("#1a1420"))  # "!"
	_r(c.x - 0.5, c.y + 2, 1, 1, Color("#1a1420"))
	_r(c.x - 2, c.y - 12, 4, 2, Color("#ff9020"))  # blinker housing


func _busstop(p: Vector2) -> void:
	var frame := Color("#3a4a6a")
	_r(p.x - 40, p.y - 34, 2, 34, frame)
	_r(p.x - 8, p.y - 34, 2, 34, frame)
	_r(p.x - 42, p.y - 36, 38, 3, Color("#ff4aa8"))  # roof
	_r(p.x - 38, p.y - 30, 30, 18, Color(0.6, 0.85, 1.0, 0.35))  # glass
	_r(p.x - 36, p.y - 12, 26, 2, Color("#8a5a3a"))  # bench
	_r(p.x - 25, p.y - 50, 2, 50, Color("#8a8a96"))  # sign pole
	_r(p.x - 31, p.y - 56, 14, 10, Color("#28c8b4"))
	_r(p.x - 29, p.y - 54, 10, 6, Color("#f4f8ff"))
	_r(p.x - 27, p.y - 53, 6, 4, Color("#28c8b4"))  # bus icon
	# Checkered finish line across the road.
	for k in 4:
		for j in 2:
			_r(p.x + 6 + j * 4, p.y - 1 + k * 2 - 1, 4, 2, Color.WHITE if (k + j) % 2 == 0 else Color.BLACK)
