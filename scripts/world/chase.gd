class_name Chase
extends Node2D
## A wall of trouble rolling along behind the bus (a mudslide). It starts when the
## level does, speeds up slowly, and swallows the bus if it catches it.

var terrain: Terrain
var front := -900.0  ## world x of the leading edge
var speed := 200.0
var accel := 3.0  ## px/s per second
var running := false
var _time := 0.0
var _rumble: AudioStreamPlayer
var _heard_at := -1.0  ## last time the run asked for the rumble (see hear())


func setup(t: Terrain, spec: Dictionary) -> Chase:
	terrain = t
	front = spec.get("start", -900.0)
	speed = spec.get("speed", 200.0)
	accel = spec.get("accel", 3.0)
	return self


func _physics_process(delta: float) -> void:
	_time += delta
	if not running:
		if _rumble:
			_rumble.stop()
		return
	speed += accel * delta
	front += speed * delta
	if _rumble == null:
		_rumble = Audio.make_loop("mudslide_loop", self, -40.0)
	if not _rumble.playing:
		_rumble.play()
	# Louder the closer the wave is to the middle of the screen; fades out once the
	# run stops calling hear() (won, caught, results screen).
	var cam := get_viewport().get_camera_2d()
	var gap := (cam.get_screen_center_position().x - front) if cam else 600.0
	var target := lerpf(-4.0, -28.0, clampf(gap / 1100.0, 0.0, 1.0))
	if _time - _heard_at > 0.2:
		target = -60.0
	_rumble.volume_db = move_toward(_rumble.volume_db, target, 40.0 * delta)


## Called by the story run every frame of play to keep the rumble going.
func hear() -> void:
	_heard_at = _time


## How far the bus is ahead of the wall (negative = caught).
func lead(x: float) -> float:
	return x - front


func _process(_delta: float) -> void:
	queue_redraw()


func _road(x: float) -> float:
	var y := terrain.surface_y(x)
	if is_nan(y):
		var g := terrain.gap_at(x)
		y = g.road_y if not g.is_empty() else 0.0
	return y


func _draw() -> void:
	# A churning brown wave: tall at the front, a long body of mud and debris behind.
	var mud := Color("#5a3a20")
	var mud_l := Color("#7a5230")
	var top := PackedVector2Array()
	var x := front - 700.0
	while x <= front + 24.0:
		var t := clampf((x - (front - 700.0)) / 700.0, 0.0, 1.0)
		var h := 30.0 + 90.0 * pow(t, 1.6) + sin(x * 0.05 + _time * 6.0) * 6.0
		if x > front - 24.0:
			h *= (front + 24.0 - x) / 48.0 + 0.2  # curling lip
		top.append(Vector2(x, _road(x) - h))
		x += 8.0
	var poly := top.duplicate()
	poly.append(Vector2(front + 24.0, _road(front) + 400.0))
	poly.append(Vector2(front - 700.0, _road(front - 700.0) + 400.0))
	draw_colored_polygon(poly, mud)
	draw_polyline(top, mud_l, 3.0)
	for k in 14:  # tumbling rocks and logs
		var a := _time * (2.0 + k * 0.3) + k
		var px := front - 40.0 - fposmod(k * 47.0 + _time * 30.0, 600.0)
		var py := _road(px) - 30.0 - 40.0 * absf(sin(a))
		if k % 3 == 0:
			draw_set_transform(Vector2(px, py), a)
			draw_rect(Rect2(-8, -2, 16, 4), Color("#3a2414"))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(Rect2(px - 2, py - 2, 5, 4), Color("#4a4248"))
	for k in 8:  # spray off the lip
		var sx := front + 10.0 + fposmod(k * 13.0 + _time * 90.0, 40.0)
		draw_rect(Rect2(sx, _road(front) - 100.0 - fmod(k * 17.0 + _time * 70.0, 60.0), 2, 2), mud_l)
