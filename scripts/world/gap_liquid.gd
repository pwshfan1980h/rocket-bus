class_name GapLiquid
extends Node2D
## Animated pool filling a gap: water, swamp, icy water or lava (which glows).

const LOOKS := {
	"water": {"body": "#2a6ad0", "top": "#8ad0ff", "foam": "#e8f8ff"},
	"swamp": {"body": "#3a5a24", "top": "#6a8a3a", "foam": "#a8c070"},
	"ice": {"body": "#2a5a9a", "top": "#a8d8ff", "foam": "#ffffff"},
	"lava": {"body": "#e0400a", "top": "#ffb030", "foam": "#fff0a0"},
}

var gap: Dictionary
var _look: Dictionary
var _time := 0.0
var _floats: Array[Vector3] = []  # lily pads / ice floes: x, width, phase
var _crust: Array[Vector3] = []  # lava crust plates: x, width, phase
var _glow: Node2D


func setup(g: Dictionary) -> void:
	gap = g
	_look = LOOKS[g.kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(g.x0)
	if g.kind in ["swamp", "ice"]:
		var x: float = g.x0 + 20
		while x < g.x1 - 30:
			_floats.append(Vector3(x, rng.randf_range(8, 22) if g.kind == "ice" else 6, rng.randf() * TAU))
			x += rng.randf_range(30, 70)
	if g.kind == "lava":
		# Stepped glow washing up the cliff walls (and over anything flying past), additive.
		_glow = Node2D.new()
		_glow.z_index = 2
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = add
		_glow.draw.connect(_draw_glow)
		add_child(_glow)
		for k in int((g.x1 - g.x0) / 26):  # crust plates drifting on the surface
			_crust.append(Vector3(rng.randf_range(g.x0 + 4, g.x1 - 30), rng.randf_range(10, 26), rng.randf() * TAU))
		var light := PointLight2D.new()
		light.texture = preload("res://assets/sprites/light_radial.png")
		light.color = Color(1, 0.45, 0.1)
		light.energy = 1.4
		light.texture_scale = maxf(3.0, (g.x1 - g.x0) / 40.0)
		light.position = Vector2((g.x0 + g.x1) / 2, g.liquid_y - 10)
		add_child(light)
		var embers := CPUParticles2D.new()
		embers.position = Vector2((g.x0 + g.x1) / 2, g.liquid_y)
		embers.amount = 30
		embers.lifetime = 2.2
		embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		embers.emission_rect_extents = Vector2((g.x1 - g.x0) / 2, 2)
		embers.direction = Vector2.UP
		embers.spread = 15
		embers.gravity = Vector2(0, -20)
		embers.initial_velocity_min = 20
		embers.initial_velocity_max = 60
		embers.color = Color(1, 0.7, 0.2)
		add_child(embers)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _glow:
		_glow.queue_redraw()


func _draw() -> void:
	var y0: float = gap.liquid_y
	var body := Color(_look.body)
	var lava: bool = gap.kind == "lava"
	if lava:  # lava is its own light source; keep it bright under the night tint
		body = body.lightened(0.2)
	var w: float = gap.x1 - gap.x0
	draw_rect(Rect2(gap.x0, y0 + 3, w, 900), Color(body, 0.92))
	if lava:  # hot yellow just under the skin, cooling to red below
		draw_rect(Rect2(gap.x0, y0 + 3, w, 6), Color("#ffb838"))
		_dither_row(y0 + 9, Color("#ffb838"), 2)
		_dither_row(y0 + 11, Color("#ff8a26"), 2)
	else:  # stepped, dithered fall-off into the deep
		for k in 4:
			var yk := y0 + 22 + k * 22
			draw_rect(Rect2(gap.x0, yk + 2, w, 22), Color(body.darkened(0.12 + k * 0.1), 0.5))
			_dither_row(yk, Color(body.darkened(0.12 + k * 0.1), 0.6), 2)
	var x: float = gap.x0
	while x < gap.x1:
		var wave := sin(x * 0.08 + _time * (1.5 if lava else 3.0)) * 1.5 + sin(x * 0.03 - _time) * 1.0
		draw_rect(Rect2(x, y0 + wave, 2, 4), Color(_look.top))
		if int(x + _time * 20) % 23 == 0:
			draw_rect(Rect2(x, y0 + wave - 1, 3, 1), Color(_look.foam))
		x += 2
	for k in 5:  # depth streaks
		draw_rect(Rect2(gap.x0, y0 + 14 + k * 16, gap.x1 - gap.x0, 2), body.darkened(0.15 + k * 0.08))
	for f in _floats:
		var bob := sin(_time * 1.5 + f.z) * 1.5
		if gap.kind == "ice":
			draw_rect(Rect2(f.x, y0 - 2 + bob, f.y, 4), Color("#e8f4ff"))
			draw_rect(Rect2(f.x, y0 + 2 + bob, f.y, 2), Color("#9ac0e8"))
		else:
			draw_rect(Rect2(f.x, y0 - 1 + bob, 8, 2), Color("#4aa040"))
			draw_rect(Rect2(f.x + 2, y0 - 2 + bob, 3, 1), Color("#ff80c0"))
	if not lava and gap.kind != "swamp":  # sky glints sliding over the surface
		for k in int(w / 40) + 1:
			var gx: float = gap.x0 + fposmod(k * 53.0 + _time * (8.0 + (k % 3) * 4.0), w - 8)
			var gy: float = y0 + 8 + (k * 7) % 16
			draw_rect(Rect2(roundf(gx), gy, 8 + (k % 3) * 4, 2), Color(1, 1, 1, 0.35))
	if gap.kind == "swamp":  # marsh gas bubbles
		for k in 4:
			var t := fmod(_time * 0.4 + k * 0.29, 1.0)
			var bx: float = lerpf(gap.x0 + 12, gap.x1 - 12, fmod(k * 0.43 + 0.2, 1.0))
			if t > 0.75:
				draw_rect(Rect2(bx - 2, y0 - 2 - (t - 0.75) * 12, 6, 3), Color(_look.foam))
			else:
				draw_rect(Rect2(bx, y0 + 30 - t * 36, 3, 3), Color(_look.top, 0.8))
	if lava:
		for c in _crust:  # dark cooled plates riding the flow, cracked with light
			var cx: float = gap.x0 + fposmod(c.x - gap.x0 + _time * 3.0, w - c.y)
			var cy := y0 + 1 + sin(_time * 1.2 + c.z) * 1.0
			draw_rect(Rect2(roundf(cx), roundf(cy), c.y, 4), Color("#5a1a10"))
			draw_rect(Rect2(roundf(cx) + 2, roundf(cy) - 2, c.y - 4, 2), Color("#7a2a14"))
			draw_rect(Rect2(roundf(cx + c.y * 0.5), roundf(cy), 2, 4), Color("#ffd060"))
		for k in 6:  # bubbles popping
			var t := fmod(_time * 0.7 + k * 0.37, 1.0)
			var bx: float = lerpf(gap.x0 + 10, gap.x1 - 10, fmod(k * 0.61, 1.0))
			draw_circle(Vector2(bx, y0 + 2 - t * 4), 1.5 + t * 2.5, Color(1, 0.85, 0.4, 1.0 - t))


## A checkerboard row: a crisp, dithered edge between two bands.
func _dither_row(y: float, c: Color, every: int) -> void:
	var x: float = gap.x0 + (int(y / 2.0) % 2) * 2
	while x < gap.x1:
		draw_rect(Rect2(x, y, 2, 2), c)
		x += every * 2


func _draw_glow() -> void:
	var y0: float = gap.liquid_y
	var flick := 0.85 + 0.15 * sin(_time * 5.3) * sin(_time * 3.1 + 1.0)
	# Bands of light, wider and fainter the higher they reach (hard steps, pixel style).
	var bands := [[8.0, 4.0, 0.5], [22.0, 10.0, 0.3], [42.0, 16.0, 0.18], [72.0, 22.0, 0.1], [110.0, 28.0, 0.05]]
	for b in bands:
		var r := Rect2(gap.x0 - b[1], y0 + 4 - b[0], gap.x1 - gap.x0 + b[1] * 2, b[0])
		_glow.draw_rect(r, Color(1.0, 0.42, 0.08, b[2] * flick))
	for k in int((gap.x1 - gap.x0) / 18):  # heat shimmer: specks rising off the surface
		var t := fmod(_time * 0.5 + k * 0.173, 1.0)
		var sx: float = gap.x0 + fposmod(k * 37.0, gap.x1 - gap.x0) + sin(_time * 3.0 + k) * 2.0
		_glow.draw_rect(Rect2(roundf(sx), roundf(y0 - 4 - t * 70), 2, 4), Color(1.0, 0.6, 0.2, 0.4 * (1.0 - t)))
