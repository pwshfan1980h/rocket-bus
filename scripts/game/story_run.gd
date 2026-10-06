class_name StoryRun
extends Node
## The jobs on a story leg, run alongside the level: bus stops (stop in the box,
## hold the brake while people board or get off), the tow trailer (snaps on hard
## landings, re-hooks when you back up to it), the mudslide chase, and passenger
## requests. The level calls in from its own loop; this keeps level.gd about driving.

const HOLD_TIME := 0.9  ## seconds stopped in the box before the doors open
const STOP_SPEED := 16.0

var level: Node  ## the Level (untyped to avoid a cycle)
var def: Dictionary
var world: World
var bus: Bus
var trailer: Trailer
var chase: Chase
var markers: StopMarkers
var requests: Array = []  # [{"who", "want", "tip", "state": "open" | "done" | "failed"}]
var walked := 0  ## riders who quit this leg
var lost_cargo := 0
var _hold := 0.0
var _busy := false  ## doors open
var _hud_line: Label
var _ring: Control
var _trailer_hint_cd := 0.0


func setup(lvl: Node, leg: Dictionary) -> StoryRun:
	level = lvl
	def = leg
	world = lvl.world
	bus = lvl.bus
	return self


func _ready() -> void:
	markers = StopMarkers.new().setup(world.terrain)
	world.add_child(markers)
	world.move_child(markers, bus.get_index())
	# Start with only the leg's riders aboard; the rest are waiting at stops.
	var p := bus.passengers
	var extra := p.aboard_count() - int(def.get("riders", p.seat_count()))
	for r in p.riders.duplicate():
		if extra > 0 and r != p.driver and r.aboard:
			p.set_aboard(r, false)
			extra -= 1
	if def.get("trailer", "") != "":
		trailer = Trailer.new().setup(bus, def.trailer)
		world.add_child(trailer)
		world.move_child(trailer, bus.get_index())
		trailer.unhooked.connect(func():
			bus.passengers.chatter(["THE TRAILER!", "WE LOST IT!", "BACK UP! BACK UP!"].pick_random(), "voice_hurt"))
		trailer.hooked.connect(func(): bus.passengers.driver_say(["GOT IT.", "HOOKED!", "NOT LEAVING IT AGAIN."].pick_random()))
	if not def.get("chase", {}).is_empty():
		chase = Chase.new().setup(world.terrain, def.chase)
		world.add_child(chase)
	for r in def.get("requests", []):
		var req: Dictionary = r.duplicate()
		req.state = "open"
		requests.append(req)


## Lines for the HUD (top left, under the gaps counter).
func build_hud(layer: CanvasLayer) -> void:
	_hud_line = Label.new()
	_hud_line.position = Vector2(8, 44)
	_hud_line.label_settings = PixelFont.settings(8, Color("#ffd23a"), 2)
	layer.add_child(_hud_line)
	_ring = Control.new()
	_ring.size = Vector2(480, 270)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	layer.add_child(_ring)
	_refresh_hud()


func start() -> void:
	if chase:
		chase.running = true


## Called every physics frame while playing. Returns a fail reason, or "".
func step(delta: float) -> String:
	_trailer_hint_cd -= delta
	_service_stops(delta)
	bus.brake_lock = _in_open_stop()
	if trailer and not trailer.attached and not trailer.lost:
		var g := world.terrain.gap_at(trailer.body.global_position.x)
		if not g.is_empty() and trailer.body.global_position.y > g.trigger_y:
			trailer.lost = true
			lost_cargo += 1
			return "cargo"
		if _trailer_hint_cd <= 0.0:
			_trailer_hint_cd = 6.0
			level._hint("BACK UP TO THE TRAILER TO RE-HOOK  (A / LEFT)")
	if chase and chase.running and chase.lead(bus.chassis.global_position.x - 60.0) < 0.0:
		return "mudslide"
	_refresh_hud()
	return ""


## Can the bus finish right now? (Trailer hooked, every stop served.)
func finish_block() -> String:
	if trailer and not trailer.attached:
		return "GO BACK FOR THE TRAILER!"
	for s in world.terrain.stops:
		if not s.done:
			return "missed"
	return ""


func on_landed(grade: String) -> void:
	if grade == "hard" and trailer and trailer.attached:
		trailer.unhook()


## A landed jump's flips (front, back) and airtime, for the passengers' requests.
func on_jump(front: int, back: int, air: float) -> void:
	for r in requests:
		if r.state != "open":
			continue
		match r.want:
			"front_flip":
				if front > 0:
					_grant(r, "%s: THAT WAS AWESOME!" % r.who)
			"big_air":
				if air > 2.0:
					_grant(r, "%s: WHEEE!" % r.who)
			"no_flips":
				if front + back > 0:
					r.state = "failed"
					bus.passengers.chatter("%s: I SAID NO FLIPS!" % r.who, "voice_hurt")
					Audio.play("sting_hard", -6.0)


func _grant(r: Dictionary, line: String) -> void:
	r.state = "done"
	bus.passengers.chatter(line, "voice_happy")
	Audio.play("cha_ching", -4.0)
	Fx.float_text(bus.chassis.global_position + Vector2(0, -90), "TIP +%d" % r.tip, Color("#7dff6a"), 16)


## Tips at the end of the leg ("no flips" pays out if you behaved).
func tips() -> int:
	var total := 0
	for r in requests:
		if r.state == "done" or (r.want == "no_flips" and r.state == "open"):
			total += int(r.tip)
	return total


## Everyone still aboard gets off at the last stop.
func unload_all() -> void:
	var door := bus.chassis.to_global(Vector2(6, 18))
	var rows := bus.passengers.drop(bus.passengers.aboard_count()).map(func(r): return r.row)
	markers.drop(rows, door)


func _in_open_stop() -> bool:
	for s in world.terrain.stops:
		if not s.done and _inside(s):
			return true
	return false


func _inside(s: Dictionary) -> bool:
	for w in bus.wheels:
		if w.global_position.x < s.x0 or w.global_position.x > s.x1:
			return false
	return true


func _service_stops(delta: float) -> void:
	if _busy:
		return
	for i in world.terrain.stops.size():
		var s: Dictionary = world.terrain.stops[i]
		if s.done or not _inside(s):
			continue
		if absf(bus.get_speed()) < STOP_SPEED and not bus.airborne:
			_hold += delta
			if _hold >= HOLD_TIME:
				_open_doors(i)
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
		return
	_hold = 0.0


func _open_doors(i: int) -> void:
	var s: Dictionary = world.terrain.stops[i]
	s.done = true
	_hold = 0.0
	_busy = true
	Audio.play("ui_select", -4.0)
	Fx.float_text(bus.chassis.global_position + Vector2(0, -70), s.name + "!", Color("#ffd23a"), 16)
	var door := bus.chassis.to_global(Vector2(6, 18))
	var wait := 0.0
	if s.drop > 0:
		var rows := bus.passengers.drop(s.drop).map(func(r): return r.row)
		wait = markers.drop(rows, door)
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree():
		return
	if s.board > 0:
		wait = markers.board(i, door)
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree():
			return
		bus.passengers.board(s.board)
	_busy = false
	if is_instance_valid(bus) and not bus.is_crashed:
		bus.passengers.driver_say(["ALL ABOARD!", "MIND THE GAP. LITERALLY.", "NEXT STOP!", "HOLD ON TO SOMETHING."].pick_random())
		level._update_riders()
	_refresh_hud()


func _refresh_hud() -> void:
	if _hud_line == null:
		return
	var parts: Array[String] = []
	var stops := world.terrain.stops
	if not stops.is_empty():
		parts.append("STOPS %d/%d" % [stops.filter(func(s): return s.done).size(), stops.size()])
	if trailer:
		parts.append("TRAILER " + ("OK" if trailer.attached else "LOOSE!"))
	if chase and chase.running:
		parts.append("MUD %dm" % maxi(0, int(chase.lead(bus.chassis.global_position.x) / 10.0)))
	for r in requests:
		var want: String = {"front_flip": "WANTS A FRONT FLIP", "no_flips": "SAYS NO FLIPS", "big_air": "WANTS BIG AIR"}[r.want]
		parts.append("%s %s%s" % [r.who, want, {"open": "", "done": " :)", "failed": " >:("}[r.state]])
	_hud_line.text = "\n".join(parts)
	_ring.queue_redraw()


## A filling ring over the bus while it holds still at a stop.
func _draw_ring() -> void:
	if _hold <= 0.0 or not is_instance_valid(bus):
		return
	var at := _ring.get_viewport().get_canvas_transform() * (bus.chassis.global_position + Vector2(0, -46))
	var t := clampf(_hold / HOLD_TIME, 0.0, 1.0)
	_ring.draw_arc(at, 8, 0, TAU, 24, Color(0, 0, 0, 0.5), 3.0)
	_ring.draw_arc(at, 8, -PI / 2, -PI / 2 + TAU * t, 24, Color("#ffd23a"), 3.0)


# --- Bot ----------------------------------------------------------------------

## Adjusts the autopilot for story jobs: pull into stops and hold, fetch the trailer.
## Returns the input to use, or {} to keep the bot's own.
func bot_input() -> Dictionary:
	if trailer and not trailer.attached and not trailer.lost:
		var dx := trailer.hitch_point().x - bus.chassis.to_global(Trailer.BUS_HITCH).x
		var v := bus.get_speed()
		var want := clampf(dx * 1.5, -70.0, 70.0)  # creep back onto the tongue
		return {"right": 0.6 if v < want - 8.0 else (-0.6 if v > want + 8.0 else 0.0), "fire": false}
	var x := bus.chassis.global_position.x
	for s in world.terrain.stops:
		if s.done:
			continue
		var mid: float = (s.x0 + s.x1) / 2.0
		var dist := mid - x
		if dist > 700.0:
			break
		if dist < -400.0:
			continue
		if _inside(s) and absf(dist) < (s.x1 - s.x0) / 2.0 - 60.0:
			return {"right": -1.0, "fire": false}  # hold the brake
		var want := clampf(dist * 0.7, -120.0, 320.0)  # crawl up to the middle of the box
		var v := bus.get_speed()
		return {"right": 1.0 if v < want - 10.0 else (-1.0 if v > want + 10.0 else 0.0), "fire": false}
	return {}
