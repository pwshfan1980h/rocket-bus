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


func _draw() -> void:
	var y0: float = gap.liquid_y
	var body := Color(_look.body)
	var lava: bool = gap.kind == "lava"
	if lava:  # lava is its own light source; keep it bright under the night tint
		body = body.lightened(0.2)
	draw_rect(Rect2(gap.x0, y0 + 3, gap.x1 - gap.x0, 900), Color(body, 0.92))
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
	if lava:
		for k in 6:  # bubbles popping
			var t := fmod(_time * 0.7 + k * 0.37, 1.0)
			var bx: float = lerpf(gap.x0 + 10, gap.x1 - 10, fmod(k * 0.61, 1.0))
			draw_circle(Vector2(bx, y0 + 2 - t * 4), 1.5 + t * 2.5, Color(1, 0.85, 0.4, 1.0 - t))
