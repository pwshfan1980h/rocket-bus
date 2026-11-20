extends Node2D
## One-shot pixel effects the bus leaves in the world: a dust shockwave where it
## lands, and the ring of flame that kicks out when the rocket lights.
## Drawn in hard-edged blocks (no soft gradients) sized for the zoomed-out camera
## (~0.4-0.6), so a 4 world-px block reads as about 2 screen pixels.

enum Kind { SHOCKWAVE, IGNITION, HONK }

var kind := Kind.SHOCKWAVE
var color := Color.WHITE
var color2 := Color.WHITE
var power := 1.0
var dir := Vector2.LEFT  # ignition: the way the flame points
var _t := 0.0
var _life := 0.45


## Flattened ring rolling out along the ground from a landing.
func shockwave(at: Vector2, strength: float, cols: Array) -> Node2D:
	kind = Kind.SHOCKWAVE
	position = at
	power = strength
	color = (cols[0] as Color).lightened(0.35)
	color2 = cols[0]
	_life = 0.32 + 0.18 * strength
	return self


## A burst ring at the nozzles the moment the rocket fires.
func ignition(at: Vector2, flame_dir: Vector2) -> Node2D:
	kind = Kind.IGNITION
	position = at
	dir = flame_dir.normalized()
	_life = 0.28
	color = Color("#fff4b0")
	color2 = Color("#ff7a2a")
	return self


## Sound-wave arcs out of the front of the bus: the horn, without the word "HONK".
func honk(at: Vector2, forward: Vector2) -> Node2D:
	kind = Kind.HONK
	position = at
	dir = forward.normalized()
	_life = 0.5
	color = Color("#ffe14a")
	return self


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _t / _life
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	if kind == Kind.SHOCKWAVE:
		var rx := 16.0 + ease_out * (80.0 + 60.0 * power)
		var ry := 4.0 + ease_out * (9.0 + 6.0 * power)
		var c := color if t < 0.45 else color2
		c.a = 1.0 - t
		_ellipse(rx, ry, c, 4 if t < 0.5 else 3)
		if power > 0.8 and t < 0.6:  # second, tighter ring for big hits
			_ellipse(rx * 0.6, ry * 0.6, Color(color, 0.8 * (1.0 - t / 0.6)), 3)
	elif kind == Kind.HONK:
		for k in 3:  # three arcs, each a little later and further out
			var tk := clampf(t * 1.6 - k * 0.3, 0.0, 1.0)
			if tk <= 0.0 or tk >= 1.0:
				continue
			var rr := 8.0 + tk * 30.0
			for j in 7:
				var a := lerpf(-0.7, 0.7, j / 6.0)
				draw_rect(Rect2((dir.rotated(a) * rr).round(), Vector2(4, 4)), Color(color, 1.0 - tk))
	else:
		var r := 6.0 + ease_out * 34.0
		var c := (color if t < 0.35 else color2)
		c.a = 1.0 - t
		# Ring, squashed along the flame, offset backwards out of the nozzles.
		var center := dir * ease_out * 22.0
		var n := 18
		for k in n:
			var a := TAU * k / n
			var v := Vector2(cos(a) * r * 0.55, sin(a) * r)
			var along := dir * v.x + dir.orthogonal() * v.y
			var p := (center + along).round()
			draw_rect(Rect2(p, Vector2(4, 4)), c)
		if t < 0.25:  # muzzle flash
			draw_rect(Rect2((center - Vector2(7, 7)).round(), Vector2(14, 14)), Color(1, 1, 0.9, 1.0 - t * 4.0))


## Pixel ellipse outline, plotted as points (crisp, no AA). Only the top half
## shows above ground, so the bottom is drawn faint.
func _ellipse(rx: float, ry: float, c: Color, thick: int) -> void:
	var steps := int(clampf(rx * 0.7, 20, 96))
	for k in steps:
		var a := TAU * k / steps
		var p := Vector2(cos(a) * rx, sin(a) * ry).round()
		var col := c if p.y <= 0.0 else Color(c, c.a * 0.35)
		draw_rect(Rect2(p, Vector2(thick, thick)), col)
