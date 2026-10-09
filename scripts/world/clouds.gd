class_name Clouds
extends RefCounted
## Pixel-art clouds for the Backdrop. Each cloud is baked once into a small
## texture: a clump of round puffs on a flat base, shaded like spheres lit from
## the sun's side, quantised to four tones with a 2x2 dither. Tones come from the
## sky's own palette, so a sunset city gets pink-topped clouds and noon gets white.
## Weather swaps the kind: storm decks in rain, grey blankets in a blizzard, dust
## banks in a sandstorm, lava-lit smoke over volcanoes.

const LOOP := 960.0
const BAYER := [0.0, 0.5, 0.75, 0.25]  # 2x2 ordered dither

## Fair-weather cloud counts per biome: [near, far, cirrus]. Missing = clear sky.
const FAIR := {
	"BAY CITY": [4, 6, 3], "DESERT": [2, 3, 5], "JUNGLE": [6, 8, 0], "MOUNTAINS": [4, 6, 2],
}

var style := ""  ## "fair" | "storm" | "snow" | "dust" | "smoke" | ""
var overcast := false  ## a solid deck across the top of the sky
var _clouds: Array[Dictionary] = []  # {tex, x, y, speed, par, lift}
var _tones: Array[Color] = []


func setup(biome: Dictionary, weather: String) -> Clouds:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(biome.title + weather)
	var sky: Array[Color] = []
	for c in biome.sky:
		sky.append(Color(c))
	var counts: Array = FAIR.get(biome.title, [0, 0, 0])
	style = "fair" if counts[0] + counts[1] > 0 else ""
	if biome.title == "VOLCANO":
		style = "smoke"
		counts = [5, 6, 0]
	match weather:
		"rain":
			style = "storm"
			counts = [7, 8, 0]
			overcast = true
		"blizzard":
			style = "snow"
			counts = [6, 7, 0]
			overcast = true
		"sandstorm":
			style = "dust"
			counts = [4, 5, 0]
		"ash":
			style = "smoke"
			counts = [7, 8, 0]
			overcast = true
	if style == "":
		return self
	_tones = _palette(style, sky)
	var light := Vector3(signf(float(biome.sun.get("x", 240)) - 240.0) * 0.6, -0.75, 0.45).normalized()
	if style == "smoke":
		light = Vector3(0.0, 0.8, 0.5).normalized()  # lit from below by the lava
	var far_tones: Array[Color] = []
	for t in _tones:  # far clouds sink into the sky colour
		far_tones.append(t.lerp(sky[3], 0.4))
	var big := 1.35 if style in ["storm", "snow", "smoke"] else 1.0
	for i in counts[1]:
		var w := int(rng.randf_range(36, 80) * big)
		_add(rng, _bake(rng, w, int(w * rng.randf_range(0.32, 0.42)), far_tones, light),
				rng.randf_range(50, 100), 0.012, rng.randf_range(1.5, 3.0), 0.25)
	for i in counts[0]:
		var w := int(rng.randf_range(70, 150) * big)
		_add(rng, _bake(rng, w, int(w * rng.randf_range(0.34, 0.46)), _tones, light),
				rng.randf_range(40, 110), 0.03, rng.randf_range(4.0, 7.0), 0.5)
	for i in counts[2]:
		_add(rng, _bake_cirrus(rng, int(rng.randf_range(60, 140)), far_tones), rng.randf_range(100, 140),
				0.006, rng.randf_range(1.0, 2.0), 0.15)
	_clouds.sort_custom(func(a, b): return a.par < b.par)  # far first
	return self


func _add(rng: RandomNumberGenerator, tex: ImageTexture, above_horizon: float, par: float, speed: float,
		lift: float) -> void:
	_clouds.append({"tex": tex, "x": rng.randf() * LOOP, "y": -above_horizon, "speed": speed, "par": par,
			"lift": lift})


## Draws behind the backdrop hills. `horizon` is the screen y the hills sit on.
func draw(n: CanvasItem, horizon: float, cam_x: float, time: float, width: float) -> void:
	if style == "":
		return
	if overcast:
		_draw_deck(n, time, width)
	for c in _clouds:
		var tex: ImageTexture = c.tex
		var w := float(tex.get_width())
		var x := fposmod(c.x - cam_x * c.par + time * c.speed, LOOP + w) - w
		if x > width:
			continue
		# Clouds rise and fall less than the hills as the camera climbs: they're farther away.
		var y: float = roundf(176.0 + c.y + (horizon - 176.0) * c.lift - tex.get_height())
		n.draw_texture(tex, Vector2(roundf(x), y))


## A low, solid deck along the top with a scalloped underside, drifting slowly.
func _draw_deck(n: CanvasItem, time: float, width: float) -> void:
	var drift := time * 3.0
	for x in range(0, int(width), 2):
		var u := x + drift
		var bottom := 34.0 + sin(u * 0.045) * 7.0 + sin(u * 0.11 + 1.3) * 4.0 + absf(sin(u * 0.023)) * 10.0
		n.draw_rect(Rect2(x, 0, 2, bottom), _tones[0])
		n.draw_rect(Rect2(x, bottom - 4, 2, 3), _tones[1])
		if (x / 2) % 2 == 0:
			n.draw_rect(Rect2(x, bottom - 1, 2, 1), _tones[1])  # dithered lip


static func _palette(kind: String, sky: Array[Color]) -> Array[Color]:
	match kind:
		"storm":
			return _hex(["#2e3242", "#454a5c", "#5e6476", "#7e8496"], sky[0], 0.25)
		"snow":
			return _hex(["#4e586c", "#6c768c", "#8e98ae", "#b8c2d4"], sky[2], 0.2)
		"dust":
			return _hex(["#8a5a3a", "#a8704a", "#c48e5e", "#dcae7a"], sky[-1], 0.15)
		"smoke":
			return _hex(["#1a0e10", "#2e1816", "#5e2a18", "#b44e1c"], sky[1], 0.1)
	return [  # fair weather: shadows from the upper sky, tops from the glow at the horizon
		sky[2].lerp(Color.WHITE, 0.22), sky[3].lerp(Color.WHITE, 0.45),
		sky[-2].lerp(Color.WHITE, 0.62), sky[-1].lerp(Color.WHITE, 0.82),
	]


static func _hex(cols: Array, tint: Color, amount: float) -> Array[Color]:
	var out: Array[Color] = []
	for c in cols:
		out.append(Color(c).lerp(tint, amount))
	return out


## A cumulus clump: puffs along a flat base, biggest in the middle, each shaded
## as a sphere; the lowest rows darken toward the base.
static func _bake(rng: RandomNumberGenerator, w: int, h: int, tones: Array[Color], light: Vector3) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := h - 1.0
	var puffs: Array[Vector3] = []
	var n := maxi(3, w / 16)
	for i in n:
		var t := (i + 0.5) / n
		var r := h * 0.55 * (0.5 + 0.5 * sin(PI * t)) * rng.randf_range(0.8, 1.15)
		r = maxf(r, 4.0)
		var cx := lerpf(r, w - r, t) + rng.randf_range(-3, 3)
		puffs.append(Vector3(cx, base - r * rng.randf_range(0.35, 0.7), r))
	for i in maxi(1, n / 3):  # a few on top for a towering silhouette
		var r := h * rng.randf_range(0.28, 0.4)
		puffs.append(Vector3(w * rng.randf_range(0.3, 0.7), base - h * 0.55 - r * 0.2, r))
	for y in h:
		for x in w:
			var best := -1.0
			var nrm := Vector3.ZERO
			for p in puffs:
				var d := Vector2(x + 0.5 - p.x, y + 0.5 - p.y)
				var z2 := p.z * p.z - d.length_squared()
				if z2 > 0.0 and y <= base:
					var z := sqrt(z2)
					if z > best:
						best = z
						nrm = Vector3(d.x, d.y, z) / p.z
			if best < 0.0:
				continue
			var s := nrm.dot(light) * 0.7 + 0.35 - (float(y) / h) * 0.35
			s += (BAYER[(y % 2) * 2 + (x % 2)] - 0.375) * 0.12
			var k := clampi(int(s * 4.0), 0, 3)
			img.set_pixel(x, y, tones[k])
	return ImageTexture.create_from_image(img)


## A thin high streak: a few stacked, tapering lines.
static func _bake_cirrus(rng: RandomNumberGenerator, w: int, tones: Array[Color]) -> ImageTexture:
	var h := 6
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in 3:
		var y := 1 + row * 2
		var x0 := int(rng.randf_range(0, w * 0.3))
		var x1 := int(rng.randf_range(w * 0.6, w))
		for x in range(x0, x1):
			var edge := minf(x - x0, x1 - x) / 10.0
			if edge < 1.0 and BAYER[(y % 2) * 2 + (x % 2)] > edge:
				continue  # dither the tapered ends away
			var c := tones[3 - row]
			c.a = 0.75
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
