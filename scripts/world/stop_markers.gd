class_name StopMarkers
extends Node2D
## Bus stops along a story road: a covered shelter on a raised kerb (bench, glass,
## a lit ad, BUS STOP on the fascia) behind a low concrete pad in the road with
## the yellow box painted on it, a stop sign, and the people waiting there. Boarding walks them to the door; dropping off
## walks riders out of the door to the kerb, where they wave goodbye.

const SHEET := preload("res://assets/sprites/passengers.png")
const LIGHT_TEX := preload("res://assets/sprites/light_radial.png")
const SHELTER_HALF := 105.0  ## half the shelter's length: ~1.5 buses in all
const KERB := 8.0  ## the waiting platform's height above the road
const STEEL := Color("#5a6070")
const CONCRETE := Color("#b8b4ac")

var terrain: Terrain
var _waiting := {}  # stop index -> Array[Node2D]
var _time := 0.0


func setup(t: Terrain) -> StopMarkers:
	terrain = t
	return self


func _ready() -> void:
	for i in terrain.stops.size():
		var s: Dictionary = terrain.stops[i]
		var crowd: Array[Node2D] = []
		var cx: float = (s.x0 + s.x1) / 2.0
		for k in s.board:
			var x: float = cx + 26 + k * 11  # by the bench
			var who := _person(1 + (i * 3 + k) % 4, Vector2(x, _stand_y(x)))
			crowd.append(who)
		_waiting[i] = crowd
		var lamp := PointLight2D.new()  # the shelter's roof light
		lamp.texture = LIGHT_TEX
		lamp.position = Vector2(cx, _base_y(s, cx) - 50)
		lamp.color = Color(1, 0.95, 0.8)
		lamp.energy = 1.1
		lamp.texture_scale = 2.2
		add_child(lamp)


func _process(delta: float) -> void:
	_time += delta
	for i in _waiting:
		for k in _waiting[i].size():
			var p: Node2D = _waiting[i][k]
			if p.has_meta("idle"):  # shuffle and wave while they wait
				p.get_child(0).position.y = -16 - absf(sin(_time * 3.0 + k)) * 1.5
	queue_redraw()


## A standing person (a rider sprite plus legs), feet at `at`.
func _person(row: int, at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.set_meta("idle", true)
	var s := Sprite2D.new()
	s.texture = SHEET
	s.hframes = 3
	s.vframes = 6
	s.frame = row * 3
	s.centered = false
	s.position = Vector2(-4, -16)
	n.add_child(s)
	var legs := ColorRect.new()
	legs.color = Color("#3a3a5a")
	legs.position = Vector2(-2, -6)
	legs.size = Vector2(4, 6)
	n.add_child(legs)
	add_child(n)
	return n


## Waiting people walk to `door` (world pos) and vanish into the bus, one by one.
func board(index: int, door: Vector2) -> float:
	var crowd: Array = _waiting.get(index, [])
	for k in crowd.size():
		var p: Node2D = crowd[k]
		p.remove_meta("idle")
		var tw := p.create_tween()
		tw.tween_interval(k * 0.25)
		tw.tween_property(p, "position", door, 0.5)
		tw.parallel().tween_property(p, "scale", Vector2(0.8, 0.8), 0.5)
		tw.tween_callback(Audio.play.bind("voice_blip", -10.0, 1.0 + k * 0.1))
		tw.tween_callback(p.queue_free)
	_waiting[index] = []
	return crowd.size() * 0.25 + 0.5


## Riders (rows) step out of `door` and walk to the kerb, waving.
func drop(rows: Array, door: Vector2) -> float:
	for k in rows.size():
		var p := _person(rows[k], door)
		p.remove_meta("idle")
		p.scale = Vector2(0.8, 0.8)
		var dest := door + Vector2(30 + k * 12, 0)
		var y := _stand_y(dest.x)
		dest.y = y if not is_nan(y) else door.y
		var tw := p.create_tween()
		tw.tween_interval(k * 0.25)
		tw.tween_property(p, "position", dest, 0.5)
		tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.5)
		tw.tween_callback(func(): (p.get_child(0) as Sprite2D).frame += 1)  # cheer
		tw.tween_interval(2.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.tween_callback(p.queue_free)
	return rows.size() * 0.25 + 0.5


## The stop whose shelter covers x, or {}.
func _stop_at(x: float) -> Dictionary:
	for s in terrain.stops:
		if absf(x - (s.x0 + s.x1) / 2.0) <= SHELTER_HALF:
			return s
	return {}


## Road height along a stop's box without the pad (the box is a straight line).
func _base_y(s: Dictionary, x: float) -> float:
	var y0 := terrain.surface_y(s.x0)
	var y1 := terrain.surface_y(s.x1)
	return lerpf(y0, y1, (x - s.x0) / (s.x1 - s.x0))


## Where a person's feet go: on the kerb under a shelter, else on the road.
func _stand_y(x: float) -> float:
	var s := _stop_at(x)
	return _base_y(s, x) - KERB if not s.is_empty() else terrain.surface_y(x)


func _draw() -> void:
	for s in terrain.stops:
		_draw_shelter(s)
		_draw_pad(s)
		# Stop sign on a pole just past the box.
		var done: bool = s.done
		var px: float = s.x1 + 10
		var py := terrain.surface_y(px)
		draw_rect(Rect2(px, py - 34, 2, 34), Color("#9a9aa8"))
		draw_rect(Rect2(px - 5, py - 44, 12, 11), Color("#2a5ad8"))
		draw_rect(Rect2(px - 4, py - 43, 10, 9), Color("#3a7af0"))
		draw_rect(Rect2(px - 1, py - 41, 4, 5), Color.WHITE)  # a little bus pictogram
		draw_rect(Rect2(px - 2, py - 37, 6, 1), Color.WHITE)
		if not done:
			var label := "%s%s" % ["BOARD %d " % s.board if s.board > 0 else "", "DROP %d" % s.drop if s.drop > 0 else ""]
			if label == "":
				label = "STOP"
			var cx: float = (s.x0 + s.x1) / 2.0
			var bob := absf(sin(_time * 3.0)) * 2.0
			draw_string(PixelFont.get_font(), Vector2(cx - 50, _base_y(s, cx) - 88 - bob), label.strip_edges(),
					HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color("#ffd23a"))


## The low concrete pad in the road (it's real: the terrain rises under it) with
## the yellow box painted on top, zig-zag ends like a real bus bay.
func _draw_pad(s: Dictionary) -> void:
	var top := PackedVector2Array()
	var x: float = s.x0
	while x <= s.x1:
		top.append(Vector2(x, terrain.surface_y(x)))
		x += 4.0
	var poly := top.duplicate()
	poly.append(Vector2(s.x1, _base_y(s, s.x1) + 1))
	poly.append(Vector2(s.x0, _base_y(s, s.x0) + 1))
	draw_colored_polygon(poly, CONCRETE.darkened(0.1))
	draw_polyline(top, CONCRETE.lightened(0.3), 1.0)
	var paint := Color("#ffd23a") if not s.done else Color("#ffd23a", 0.35)
	x = s.x0 + Terrain.STOP_PAD_RAMP
	while x < s.x1 - Terrain.STOP_PAD_RAMP:
		draw_rect(Rect2(x, terrain.surface_y(x) - 1, 6, 2), paint)
		x += 10
	for end in [s.x0 + Terrain.STOP_PAD_RAMP, s.x1 - Terrain.STOP_PAD_RAMP]:
		var y := terrain.surface_y(end)
		draw_rect(Rect2(end - 1, y - 7, 2, 7), paint)


## The shelter, drawn in a frame sheared to the road's slope so posts stay upright:
## local x along the road from the stop's middle, y = 0 on the road.
func _draw_shelter(s: Dictionary) -> void:
	var cx: float = (s.x0 + s.x1) / 2.0
	var slope: float = (_base_y(s, s.x1) - _base_y(s, s.x0)) / (s.x1 - s.x0)
	draw_set_transform_matrix(Transform2D(Vector2(1, slope), Vector2(0, 1), Vector2(cx, _base_y(s, cx))))
	var w := SHELTER_HALF
	var floor_y := -KERB
	# Glass back wall with mullions.
	draw_rect(Rect2(-w + 6, -56, w * 2 - 12, 46), Color(0.62, 0.85, 1.0, 0.28))
	draw_rect(Rect2(-w + 6, -56, w * 2 - 12, 1), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(-w + 6, -11, w * 2 - 12, 1), STEEL)
	for mx in [-w * 0.5, 0.0, w * 0.5]:
		draw_rect(Rect2(mx, -56, 1, 46), STEEL.lightened(0.2))
	for k in 3:  # a few streaks of reflection
		draw_line(Vector2(-w + 20 + k * 70, -50), Vector2(-w + 32 + k * 70, -18), Color(1, 1, 1, 0.18), 2.0)
	# Lit ad panel at the far end.
	draw_rect(Rect2(w - 40, -54, 30, 42), STEEL.darkened(0.3))
	draw_rect(Rect2(w - 38, -52, 26, 38), Color("#fff2c8"))
	draw_rect(Rect2(w - 38, -52, 26, 12), Color("#ff6a3a"))
	draw_rect(Rect2(w - 34, -32, 16, 7), Color("#ffcc26"))  # a bus, obviously
	draw_rect(Rect2(w - 32, -25, 3, 3), Color("#1a0f29"))
	draw_rect(Rect2(w - 23, -25, 3, 3), Color("#1a0f29"))
	draw_rect(Rect2(w - 40, -30, 6, 3), Color("#ff9a2e"))  # its rocket
	# Posts and the canopy.
	for px in [-w + 2, w - 5]:
		draw_rect(Rect2(px, -62, 3, 62 + floor_y), STEEL)
		draw_rect(Rect2(px, -62, 1, 62 + floor_y), STEEL.lightened(0.3))
	draw_rect(Rect2(-w - 6, -68, w * 2 + 12, 4), Color("#3a4150"))
	draw_rect(Rect2(-w - 8, -70, w * 2 + 16, 2), Color("#5a6478"))
	draw_rect(Rect2(-w + 4, -64, w * 2 - 8, 11), Color("#1e5ad8"))
	draw_rect(Rect2(-w + 4, -54, w * 2 - 8, 1), Color("#123a90"))
	var title := "BUS STOP" if s.name == "BUS STOP" else "BUS STOP  -  %s" % s.name
	draw_string(PixelFont.get_font(), Vector2(-w, -55), title, HORIZONTAL_ALIGNMENT_CENTER, w * 2, 8, Color.WHITE)
	# Bench by the far end: back rest, seat, legs.
	var bx := 22.0
	draw_rect(Rect2(bx, floor_y - 18, 40, 3), Color("#a0623a"))
	draw_rect(Rect2(bx, floor_y - 10, 40, 3), Color("#b8744a"))
	draw_rect(Rect2(bx, floor_y - 10, 40, 1), Color("#d8946a"))
	for lx in [bx + 3, bx + 34]:
		draw_rect(Rect2(lx, floor_y - 7, 3, 7), STEEL)
		draw_rect(Rect2(lx, floor_y - 18, 2, 8), STEEL)
	# The raised kerb they wait on.
	draw_rect(Rect2(-w - 4, floor_y, w * 2 + 8, KERB), CONCRETE)
	draw_rect(Rect2(-w - 4, floor_y, w * 2 + 8, 1), CONCRETE.lightened(0.3))
	draw_rect(Rect2(-w - 4, -1, w * 2 + 8, 1), CONCRETE.darkened(0.3))
	draw_set_transform_matrix(Transform2D.IDENTITY)
