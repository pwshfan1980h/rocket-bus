class_name Backdrop
extends Node2D
## Screen-space parallax scenery for a biome. Put it on a CanvasLayer below the
## world so the world's CanvasModulate (time-of-day tint) doesn't darken the sky.

const SIZE := Vector2(480, 270)
const LOOP := 960.0
const COL := 2  # column width of the silhouette height maps
const NEONS: Array[Color] = [Color(1, 0.27, 0.67), Color(0.24, 0.94, 0.86), Color(1, 0.86, 0.24), Color(0.6, 0.4, 1.0)]

var biome: Dictionary
## World y of the "normal" road height; the horizon drifts as the camera climbs.
var base_y := 0.0

var _sky: Array[Color] = []
var _layers: Array[Dictionary] = []
var _stars: Array[Vector3] = []
var _clouds: Clouds
var _time := 0.0


func setup(biome_name: String, road_y := 0.0) -> Backdrop:
	biome = Biomes.get_biome(biome_name)
	base_y = road_y
	return self


func _ready() -> void:
	for c in biome.sky:
		_sky.append(Color(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome.title)
	for i in int(120 * biome.stars):
		_stars.append(Vector3(rng.randf() * LOOP, rng.randf() * 110, rng.randf() * TAU))
	set_weather("")
	for i in biome.layers.size():
		var spec: Dictionary = biome.layers[i]
		var layer := spec.duplicate()
		layer.color = Color(spec.color)
		layer.cap = Color(spec.cap) if spec.has("cap") else Color.TRANSPARENT
		layer.stripe = Color(spec.stripes) if spec.has("stripes") else Color.TRANSPARENT
		layer.heights = _heights(spec.kind, spec.h, rng)
		layer.index = i
		if spec.kind == "city":
			_bake_city(layer, rng)
		if spec.kind == "volcanoes":
			layer.craters = _pending_craters
		if spec.kind == "islands":
			layer.islands = []
			var ix := 0.0
			while ix < LOOP:
				layer.islands.append({"x": ix, "y": rng.randf_range(-40, 40), "w": rng.randf_range(24, 70)})
				ix += rng.randf_range(70, 160)
		_layers.append(layer)


## Rebuilds the clouds for the level's weather ("" = the biome's fair-weather sky).
func set_weather(kind: String) -> void:
	_clouds = Clouds.new().setup(biome, kind)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position() if cam else Vector2.ZERO
	var horizon := roundf(clampf(176.0 - (center.y - base_y + 40.0) * 0.12, 120.0, 230.0))
	_draw_sky(horizon, center.x)
	for layer in _layers:
		var base: float = horizon + layer.get("dy", layer.index * 10.0)
		var scroll := fposmod(center.x * layer.parallax, LOOP)
		if layer.kind == "city":
			_draw_city(layer, base, scroll)
		elif layer.kind == "islands":
			_draw_islands(layer, base, scroll)
			continue  # floating: nothing below them but void
		else:
			_draw_heights(layer, base, scroll)
		draw_rect(Rect2(0, base, SIZE.x, SIZE.y - base + 1), layer.color)


func _draw_sky(horizon: float, cam_x: float) -> void:
	var band := ceilf(horizon / _sky.size())
	for i in _sky.size():
		var y0 := i * band
		draw_rect(Rect2(0, y0, SIZE.x, band + 1), _sky[i])
		if i + 1 < _sky.size():  # dithered seam between bands
			for dx in range(0, int(SIZE.x), 2):
				draw_rect(Rect2(dx + int(y0) % 2, y0 + band - 1, 1, 1), _sky[i + 1])
	var clear := not _clouds.overcast  # an overcast deck hides the stars and aurora
	for s in _stars if clear else []:
		var sx := fposmod(s.x - cam_x * 0.01, LOOP)
		if sx < SIZE.x and s.y < horizon - 40:
			var tw := 0.5 + 0.5 * sin(_time * 2.0 + s.z)
			draw_rect(Rect2(sx, s.y, 1, 1), Color(1, 0.96, 0.9, 0.3 + tw * 0.7))
	if biome.aurora and clear:
		for x in range(0, int(SIZE.x), 2):
			var wave := sin(x * 0.02 + _time * 0.6) * 14 + sin(x * 0.051 - _time * 0.4) * 8
			var top := 30 + wave
			var a := 0.18 + 0.12 * sin(x * 0.03 + _time)
			draw_rect(Rect2(x, top, 2, 26), Color(0.3, 1.0, 0.7, a))
			draw_rect(Rect2(x, top + 26, 2, 14), Color(0.5, 0.4, 1.0, a * 0.6))
	var sun: Dictionary = biome.sun
	if sun.r > 0:
		var c := Vector2(sun.x, horizon - 22 - (40 if sun.get("moon", false) else 0))
		var r: float = sun.r
		for dy in range(-int(r), int(r) + 1):
			if sun.stripes and dy > 4 and (dy % 5) < 2:
				continue
			var half := sqrt(maxf(0.0, r * r - dy * dy))
			var col := Color(sun.top).lerp(Color(sun.bottom), (dy + r) / (2 * r))
			draw_rect(Rect2(roundf(c.x - half), c.y + dy, roundf(half * 2), 1), col)
		if sun.get("moon", false):
			for crater in [Vector3(-4, -3, 3), Vector3(5, 4, 2), Vector3(2, -7, 1.5)]:
				draw_circle(c + Vector2(crater.x, crater.y), crater.z, Color(0.7, 0.74, 0.88))
	if biome.get("nebula", false):
		for k in 5:  # slow swirling bands of green and violet
			for x in range(0, int(SIZE.x), 3):
				var y := 40 + k * 34 + sin(x * 0.012 + _time * 0.15 + k) * 22 + sin(x * 0.031 - _time * 0.1) * 9
				var col := Color(0.3, 0.9, 0.6, 0.07) if k % 2 == 0 else Color(0.6, 0.3, 0.9, 0.06)
				draw_rect(Rect2(x, y, 3, 18 + k * 4), col)
	if biome.get("earth", false):
		_draw_earth(Vector2(360, 58), 20.0)
	_clouds.draw(self, horizon, cam_x, _time, SIZE.x)


func _draw_earth(c: Vector2, r: float) -> void:
	for dy in range(-int(r), int(r) + 1):
		var half := sqrt(maxf(0.0, r * r - dy * dy))
		for dx in range(-int(half), int(half) + 1):
			var land := sin((dx + _time * 2.0) * 0.35) * cos(dy * 0.4) + sin(dx * 0.17 + dy * 0.23) > 0.9
			var col := Color("#3a7ae0") if not land else Color("#4aa050")
			if sin(dx * 0.5 + dy * 0.9 + _time) > 0.93:
				col = Color("#f0f4ff")  # clouds
			if dx > half - 6:  # night side
				col = col.darkened(0.6)
			draw_rect(Rect2(c.x + dx, c.y + dy, 1, 1), col)
	draw_arc(c, r + 1.5, 0, TAU, 32, Color(0.5, 0.7, 1.0, 0.35), 2.0)


func _draw_heights(layer: Dictionary, base: float, scroll: float) -> void:
	var heights: PackedFloat32Array = layer.heights
	var n := heights.size()
	var first := int(scroll / COL)
	for i in int(SIZE.x / COL) + 2:
		var h := heights[(first + i) % n]
		if h <= 0.5:
			continue
		var x := i * COL - fmod(scroll, COL)
		draw_rect(Rect2(x, base - h, COL, h + 1), layer.color)
		if layer.cap.a > 0.0 and h > layer.h * 0.55:
			var cap_h: float = (h - layer.h * 0.55) * 0.55 + ((first + i) % 3)
			draw_rect(Rect2(x, base - h, COL, cap_h), layer.cap)
		if layer.stripe.a > 0.0 and h > 14:
			draw_rect(Rect2(x, base - h * 0.55, COL, 3), layer.stripe)
	if layer.kind == "volcanoes":
		_draw_volcano_fx(layer, base, scroll)


func _draw_islands(layer: Dictionary, base: float, scroll: float) -> void:
	for isl in layer.islands:
		var x := fposmod(isl.x - scroll, LOOP) - 60
		if x > SIZE.x + 60:
			continue
		var y: float = base - layer.h * 1.6 + isl.y + sin(_time * 0.4 + isl.x) * 3.0
		var w: float = isl.w
		var pts := PackedVector2Array([Vector2(x, y), Vector2(x + w * 0.2, y - 4), Vector2(x + w * 0.7, y - 5),
			Vector2(x + w, y), Vector2(x + w * 0.75, y + w * 0.25), Vector2(x + w * 0.5, y + w * 0.55),
			Vector2(x + w * 0.3, y + w * 0.2)])
		draw_colored_polygon(pts, layer.color)
		draw_rect(Rect2(x + w * 0.2, y - 5, w * 0.5, 2), layer.color.lightened(0.25))
		draw_rect(Rect2(x + w * 0.45, y + w * 0.5, 3, 3), Color(0.4, 1.0, 0.7, 0.5))  # glowing underside


func _draw_volcano_fx(layer: Dictionary, base: float, scroll: float) -> void:
	for peak in layer.get("craters", []):
		var x := fposmod(peak.x - scroll, LOOP)
		if x > SIZE.x + 40:
			continue
		var top: float = base - peak.y
		var glow := 0.6 + 0.4 * sin(_time * 3.0 + peak.x)
		draw_rect(Rect2(x - 6, top, 12, 3), Color(1, 0.55, 0.1, glow))
		draw_rect(Rect2(x - 3, top + 3, 6, 6), Color(1, 0.35, 0.05, glow * 0.7))
		for k in 6:  # smoke plume
			var t := fmod(_time * 0.25 + k / 6.0, 1.0)
			var size := 6 + t * 26
			draw_rect(Rect2(x - size / 2 + t * 30, top - t * 90, size, size * 0.6), Color(0.15, 0.08, 0.08, 0.5 * (1 - t)))


## A skyline layer: the baked texture (tiled across the loop), then the blinking
## aviation lights on the antennas. A haze of city glow
## settles over its foot so the farther rows read as farther.
func _draw_city(layer: Dictionary, base: float, scroll: float) -> void:
	var tex: ImageTexture = layer.tex
	var top := base - tex.get_height() + 1
	for k in 2:
		var ox := -scroll + k * LOOP
		if ox < SIZE.x and ox + LOOP > 0:
			draw_texture(tex, Vector2(ox, top))
	for b in layer.blinks:
		var x := fposmod(b.x - scroll, LOOP)
		if x < SIZE.x and fmod(_time + b.x * 0.013, 1.6) < 0.5:
			draw_rect(Rect2(x, top + b.y, 1, 1), Color(1, 0.2, 0.25))
	if layer.has("haze"):
		var haze := Color(layer.haze)
		for k in 6:
			haze.a = 0.05 + k * 0.035
			draw_rect(Rect2(0, base - 36 + k * 6, SIZE.x, 6), haze)


# --- Height map generators ----------------------------------------------------

func _heights(kind: String, max_h: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(LOOP / COL)
	var h := PackedFloat32Array()
	h.resize(n)
	match kind:
		"hills":
			var p1 := rng.randf() * TAU
			for i in n:
				var x := i * COL
				h[i] = max_h * (0.55 + 0.3 * sin(x / 80.0 + p1) + 0.15 * sin(x / 27.0))
		"dunes":
			for i in n:
				var x := i * COL
				var ph := fmod(x / 130.0, 1.0)
				h[i] = max_h * (0.4 + 0.6 * (ph if ph < 0.7 else (1 - ph) / 0.3 * 0.7))
		"mesas":
			for i in n:
				h[i] = max_h * 0.15
			var x := 0
			while x < n:
				var w := rng.randi_range(20, 70)
				var top := max_h * rng.randf_range(0.5, 1.0)
				var slope := rng.randi_range(3, 6)
				for k in w:
					if x + k < n:
						var edge := mini(k, w - 1 - k)
						h[x + k] = maxf(h[x + k], top - maxf(0, slope - edge) * top / slope * 0.7)
				x += w + rng.randi_range(10, 60)
		"peaks", "volcanoes":
			var peaks := []
			var count := 7 if kind == "peaks" else 2
			for k in count:
				peaks.append(Vector3(rng.randf() * n, max_h * rng.randf_range(0.55, 1.0), rng.randf_range(0.7, 1.4)))
			var craters := []
			for i in n:
				var best := max_h * 0.1
				for p in peaks:
					var d := absf(i - p.x)
					d = minf(d, n - d)  # wrap around the loop
					var v: float = p.y - d * COL * p.z * (1.0 if kind == "peaks" else 0.55)
					if kind == "peaks":
						v += sin(i * 1.7) * 2.0
					else:
						v = minf(v, p.y - 4.0)  # flat crater top
					best = maxf(best, v)
				h[i] = best
			if kind == "volcanoes":
				for p in peaks:
					craters.append(Vector2(p.x * COL, p.y - 4.0))
				_pending_craters = craters
		"forest":
			for i in n:
				h[i] = max_h * 0.3
			var x := 0
			while x < n:
				var w := rng.randi_range(4, 9)
				var th := max_h * rng.randf_range(0.6, 1.0)
				for k in range(-w, w + 1):
					var idx := (x + k + n) % n
					h[idx] = maxf(h[idx], th - absf(k) * th / w)
				x += rng.randi_range(3, 7)
		"craters":
			var p1 := rng.randf() * TAU
			for i in n:
				h[i] = max_h * (0.5 + 0.25 * sin(i * COL / 90.0 + p1))
			for k in 9:  # scoop out craters with raised rims
				var cx := rng.randi() % n
				var r := rng.randi_range(8, 22)
				for d in range(-r - 3, r + 4):
					var idx := (cx + d + n) % n
					var t := absf(d) / float(r)
					if t < 1.0:
						h[idx] -= (1.0 - t * t) * r * 0.9
					elif t < 1.3:
						h[idx] += 3.0
		"canopy":
			for i in n:
				h[i] = max_h * 0.35
			var x := 0
			while x < n:
				var r := rng.randi_range(6, 16)
				var cy := max_h * rng.randf_range(0.55, 0.95) - r * COL
				for k in range(-r, r + 1):
					var idx := (x + k + n) % n
					h[idx] = maxf(h[idx], cy + sqrt(float(r * r - k * k)) * COL)
				x += rng.randi_range(r, r * 2)
	return h


var _pending_craters := []


## Bakes one skyline row into a LOOP-wide texture. Spec keys: h (tallest),
## wmin/wmax (building widths), windows (lit share), detail: 0 far towers,
## 1 + antennas and setbacks, 2 + rooftop tanks and neon, 3 street front with shops.
## Buildings overlap so rows look packed, each with a 1px glow-lit edge.
func _bake_city(layer: Dictionary, rng: RandomNumberGenerator) -> void:
	var max_h: int = layer.h
	var detail: int = layer.get("detail", 2)
	var img := Image.create(int(LOOP), max_h + 14, false, Image.FORMAT_RGBA8)
	var floor_y := img.get_height()
	var body: Color = layer.color
	var rim := body.lightened(0.12)
	var warm := Color(1, 0.82, 0.47)
	var cool := Color(0.62, 0.86, 1.0)
	var win_mix: float = [0.55, 0.35, 0.15, 0.0][detail]  # far windows fade toward the wall colour
	var blinks: Array[Vector2] = []
	var x := 0
	while x < LOOP:
		var w: int = rng.randi_range(layer.wmin, layer.wmax)
		var h: int = rng.randi_range(int(max_h * 0.35), max_h)
		if detail < 3 and rng.randf() < 0.12:
			h = max_h  # a landmark tower
		if detail == 3:
			h = rng.randi_range(int(max_h * 0.55), max_h)
		var top := floor_y - h
		var shape := rng.randi() % 4 if detail >= 1 else rng.randi() % 2
		_fill(img, x, top, w, h, body)
		match shape:
			1:  # setback crown
				var sw := int(w * 0.6)
				var sh := rng.randi_range(4, 10)
				_fill(img, x + (w - sw) / 2, top - sh, sw, sh, body)
				top -= sh
			2:  # spire and antenna
				var ax := x + w / 2
				var ah := rng.randi_range(5, 12)
				_fill(img, ax - 1, top - 3, 3, 3, body)
				_fill(img, ax, top - 3 - ah, 1, ah, body)
				blinks.append(Vector2(ax, max_h + 14 - h - 3 - ah))
			3:  # stepped roof
				for k in 3:
					_fill(img, x + k * 2, top - (k + 1) * 2, w - k * 4, 2, body)
		_fill(img, x, floor_y - h, 1, h, rim)  # glow on the edge facing the light
		# Windows: a grid, some floors burning bright (offices), the rest scattered.
		var hue := warm if rng.randf() < 0.7 else cool
		var step_x := 3 if detail == 0 else 4
		var step_y := 3 if detail == 0 else 4
		var ww := 1 if detail == 0 else 2
		var shop := 10 if detail == 3 else 0
		for wy in range(floor_y - h + 3, floor_y - 2 - shop, step_y):
			var office := rng.randf() < 0.08
			for wx in range(x + 2, x + w - 2, step_x):
				if office or rng.randf() < layer.windows:
					var c := hue.lerp(body, win_mix + rng.randf() * 0.25)
					_fill(img, wx, wy, ww, 1, c)
		if detail >= 2 and rng.randf() < 0.15 and w > 14:  # rooftop water tank
			var tx := x + rng.randi_range(2, w - 10)
			_fill(img, tx + 1, floor_y - h - 3, 1, 3, body)
			_fill(img, tx + 6, floor_y - h - 3, 1, 3, body)
			_fill(img, tx, floor_y - h - 9, 8, 6, body)
		if detail == 3:  # shop fronts: lit window, awning, sometimes a neon sign
			_fill(img, x + 2, floor_y - 7, w - 4, 5, warm.lerp(Color.WHITE, 0.2))
			_fill(img, x + 1, floor_y - 9, w - 2, 2, NEONS[rng.randi() % NEONS.size()].darkened(0.3))
			if rng.randf() < 0.5:
				_fill(img, x + 3, floor_y - 15 - rng.randi_range(0, 8), mini(w - 6, 14), 2, NEONS.pick_random())
		elif detail == 2 and rng.randf() < 0.3:  # a vertical sign down the side
			_fill(img, x + w - 3, floor_y - h + 6, 2, rng.randi_range(8, 16), NEONS.pick_random())
		x += int(w * rng.randf_range(0.65, 1.0)) + (rng.randi_range(0, 2) if detail < 3 else 0)
	layer.tex = ImageTexture.create_from_image(img)
	# Only antenna tips still against the sky (not swallowed by a later, taller building).
	layer.blinks = blinks.filter(func(b): return b.y < 1 or img.get_pixelv(Vector2i(b) - Vector2i(0, 1)).a == 0.0)


func _fill(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, c)
