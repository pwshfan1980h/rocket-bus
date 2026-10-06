class_name StopMarkers
extends Node2D
## Bus stops along a story road: a yellow box painted on the road, a stop sign,
## and the people waiting there. Boarding walks them to the door; dropping off
## walks riders out of the door to the kerb, where they wave goodbye.

const SHEET := preload("res://assets/sprites/passengers.png")

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
		for k in s.board:
			var x: float = s.x1 + 24 + k * 11
			var who := _person(1 + (i * 3 + k) % 4, Vector2(x, terrain.surface_y(x)))
			crowd.append(who)
		_waiting[i] = crowd


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
		var y := terrain.surface_y(dest.x)
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


func _draw() -> void:
	for s in terrain.stops:
		var done: bool = s.done
		# The box painted on the road (zig-zag ends, like a real bus bay).
		var paint := Color("#ffd23a") if not done else Color("#ffd23a", 0.35)
		var x: float = s.x0 + 4
		while x < s.x1 - 4:
			var y := terrain.surface_y(x)
			draw_rect(Rect2(x, y - 1, 6, 2), paint)
			x += 10
		for end in [s.x0, s.x1]:
			var y := terrain.surface_y(end)
			draw_rect(Rect2(end - 1, y - 7, 2, 7), paint)
		# Stop sign on a pole at the far end of the box.
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
			var bob := absf(sin(_time * 3.0)) * 2.0
			draw_string(PixelFont.get_font(), Vector2(px - 30, py - 52 - bob), label.strip_edges(),
					HORIZONTAL_ALIGNMENT_CENTER, 64, 8, Color("#ffd23a"))
