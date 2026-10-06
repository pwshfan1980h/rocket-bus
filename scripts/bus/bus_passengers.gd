class_name BusPassengers
extends Node2D
## Riders sitting behind the windows. They sway with the bus's acceleration
## (float up in free fall, get squashed on landings), change faces with the
## action, shout colourful quips, and get thrown out when the bus breaks apart.
## The last seat is the driver, who has a gruff voice and answers back.

enum Mood { IDLE, CHEER, SHOCK }

const SHEET := preload("res://assets/sprites/passengers.png")
const DRIVER_SHEET := preload("res://assets/sprites/driver.png")  # profile, facing the road
const SWAY_GAIN := 0.004
const SWAY_LIMIT := Vector2(2.0, 3.0)

# Top-left of each 8x10 rider sprite in bus-local px, plus sprite-sheet row. One rider per
# window (see tools/gen_art.py), heads and shoulders above the sill, all facing forward.
const SEATS := [
	[Vector2(-36, -5), 0], [Vector2(-23, -5), 2], [Vector2(-10, -5), 1], [Vector2(15, -5), 3],
	[Vector2(28, -5), 5],  # last = driver
]
const SHIRTS := [
	Color("#28c8b4"), Color("#b060ff"), Color("#ff9030"),
	Color("#ff60b0"), Color("#70e060"), Color("#60a0ff"),
]
const QUIPS := {
	"perfect": ["WOOO!", "AGAIN!", "10/10!", "LEGEND!", "YEAH!"],
	"good": ["NICE!", "SMOOTH!", "OK OK!", "COOL!"],
	"hard": ["OW!", "MY BACK!", "HEY!!", "MY COFFEE!", "DRIVER!!", "OOF!"],
	"air": ["WHEEE!", "WOAH!", "AAAH!"],
	"crash": ["AAAAH!", "MY HAT!", "NOOO!", "MOMMY!", "MY SPLEEN!", "I QUIT!", "WORTH IT!",
		"SUE THE DRIVER!", "NOT AGAIN!", "WHEEEEE-OW"],
	"bonk": ["BONK!", "OOF!", "OW!", "MY FACE!", "UGH", "BOING!"],
}

const DRIVER_ROW := 5
const DRIVER_COLOR := Color("#ffe14a")
const DRIVER_LINES := {
	"rocket": ["HOLD ON!", "HANG ON TIGHT!", "HERE WE GO!", "PUNCH IT!", "BRACE YOURSELVES!"],
	"perfect": ["NAILED IT!", "STILL GOT IT!", "SMOOTH AS BUTTER!", "TEXTBOOK!"],
	"good": ["NOT BAD!", "EASY.", "TOLD YOU."],
	"hard": ["SIT DOWN BACK THERE!", "NO REFUNDS!", "YOU'RE FINE!", "WALK IT OFF!", "READ THE TICKET!"],
	"gap": ["RELAX, I DO THIS DAILY", "TRUST ME!", "WHAT GAP?", "SEATBELTS, PEOPLE!"],
	"start": ["ALL ABOARD!", "NEXT STOP: WHO KNOWS!", "FARES PLEASE!", "BUCKLE UP!"],
	"finish": ["END OF THE LINE!", "EVERYBODY OFF!", "THAT'LL BE $2.50", "ON TIME, BABY!"],
	"fuel_low": ["RUNNING ON FUMES!", "NEED GAS!", "UH OH, FUEL!"],
	"crash": ["NOT MY BUS!", "MY PENSION!", "2 DAYS TO RETIREMENT!"],
	"chasm": ["WE'RE GOING DOWN!"], "water": ["ABANDON BUS!"], "swamp": ["ABANDON BUS!"],
	"ice": ["IT'S COLD!"], "lava": ["IT'S GETTING WARM!"],
	"reply": ["QUIET BACK THERE!", "UH HUH.", "NO SINGING!", "I'M DRIVING HERE!", "WHO SAID THAT?"],
}

var riders: Array[Dictionary] = []
var driver: Dictionary
var _driver_cd := 0.0
var _filtered_accel := Vector2.ZERO
var _air_quipped := false


func _ready() -> void:
	for seat in SEATS:
		var s := Sprite2D.new()
		var is_driver: bool = seat[1] == DRIVER_ROW
		s.texture = DRIVER_SHEET if is_driver else SHEET
		s.hframes = 3
		s.vframes = 1 if is_driver else 6
		s.centered = false
		s.position = seat[0] + (Vector2(-2, -1) if is_driver else Vector2.ZERO)
		s.light_mask = 3  # lit by the world and by the cabin lights
		add_child(s)
		riders.append({
			"sprite": s, "base": s.position, "row": seat[1],
			"offset": Vector2.ZERO, "vel": Vector2.ZERO,
			"stiff": randf_range(160.0, 240.0), "mood_time": 0.0,
		})
		_set_mood(riders[-1], Mood.IDLE)
		if seat[1] == DRIVER_ROW:
			driver = riders[-1]


## proper_accel_local: the bus's acceleration minus gravity, in bus space.
## At rest upright this is (0, -g); in free fall it is zero.
func update_sway(proper_accel_local: Vector2, gravity: float, delta: float) -> void:
	_filtered_accel = _filtered_accel.lerp(proper_accel_local, 0.35)
	var target := -(_filtered_accel + Vector2(0, gravity)) * SWAY_GAIN
	target = target.clamp(-SWAY_LIMIT, SWAY_LIMIT)
	_driver_cd -= delta
	for r in riders:
		r.vel += (target - r.offset) * r.stiff * delta - r.vel * 14.0 * delta
		r.offset = (r.offset + r.vel * delta).clamp(-SWAY_LIMIT * 1.5, SWAY_LIMIT * 1.5)
		r.sprite.position = r.base + r.offset.round()
		if r.mood_time > 0.0:
			r.mood_time -= delta
			if r.mood_time <= 0.0:
				_set_mood(r, Mood.IDLE)


func on_airborne(air_time: float, rocket_on: bool) -> void:
	if air_time > 0.3:
		for r in riders:
			if r.mood_time <= 0.0 or r.sprite.frame % 3 == Mood.IDLE:
				_set_mood(r, Mood.CHEER if rocket_on and r.row % 2 == 0 else Mood.SHOCK, 0.3)
		if not _air_quipped and air_time > 0.55:
			_air_quipped = true
			_quip(_riders_only().pick_random(), QUIPS.air.pick_random(), "air")


func react(grade: String) -> void:
	_air_quipped = false
	match grade:
		"perfect":
			for r in riders:
				_set_mood(r, Mood.CHEER, 1.4)
				r.vel.y -= 90.0
			_quip_some(2, "perfect")
			if randf() < 0.6:
				_later(0.8, driver_say.bind(DRIVER_LINES.perfect.pick_random()))
		"good":
			for r in riders:
				_set_mood(r, Mood.CHEER if randf() < 0.6 else Mood.IDLE, 1.0)
				r.vel.y -= 40.0
			_quip_some(1, "good")
			if randf() < 0.3:
				_later(0.7, driver_say.bind(DRIVER_LINES.good.pick_random()))
		"hard":
			for r in riders:
				_set_mood(r, Mood.SHOCK, 1.3)
				r.vel.y += 160.0
				r.vel.x += randf_range(-60.0, 60.0)
			_quip_some(2, "hard")
			if randf() < 0.8:  # the driver snaps back at the complaints
				_later(0.95, driver_say.bind(DRIVER_LINES.hard.pick_random()))


## Says a flavor line from a random visible rider, with a little voice.
func chatter(line: String, voice := "voice_blip") -> void:
	var pool := _riders_only().filter(func(r): return r.sprite.visible)
	if pool.is_empty():
		return
	var r: Dictionary = pool.pick_random()
	Audio.play(voice, -8.0, 0.8 + r.row * 0.12, 0.05)
	Fx.float_text(r.sprite.global_position + Vector2(4, -2), line, SHIRTS[r.row].lightened(0.25))
	_set_mood(r, Mood.CHEER if voice == "voice_happy" else Mood.SHOCK if voice == "voice_hurt" else Mood.IDLE, 0.8)


## Throws every rider out of the bus as a floppy ragdoll (head, torso, arms, legs).
func eject(into: Node, bus_velocity: Vector2) -> void:
	var delay := 0.0
	for r in riders:
		var s: Sprite2D = r.sprite
		var at := s.global_position + Vector2(4, 5).rotated(s.global_rotation)
		var launch := bus_velocity * 0.6 + Vector2(randf_range(-160, 160), randf_range(-360, -180))
		var doll := Ragdoll.new()
		doll.build(into, at, s.global_rotation, launch, r.row, SHIRTS[r.row])
		s.hide()
		if randf() < 0.6:
			delay += 0.12
			var text: String = QUIPS.crash.pick_random()
			var color: Color = SHIRTS[r.row].lightened(0.2)
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(doll.torso):
					Audio.play("voice_scream", -12.0, 0.9 + r.row * 0.1, 0.05)
					Fx.float_text(doll.torso.global_position + Vector2(0, -10), text, color))


func _set_mood(r: Dictionary, mood: Mood, duration := 0.0) -> void:
	r.sprite.frame = mood if r.row == DRIVER_ROW else r.row * 3 + mood
	r.mood_time = duration


## The driver speaks (in yellow, gruff voice). A short cooldown stops them talking over themselves.
func driver_say(line: String, shout := false, force := false) -> void:
	if driver.is_empty() or not driver.sprite.visible or (_driver_cd > 0.0 and not force):
		return
	_driver_cd = 1.2
	Audio.play("voice_driver_shout" if shout else "voice_driver", -5.0, randf_range(0.95, 1.05))
	Fx.float_text(driver.sprite.global_position + Vector2(4, -4), line, DRIVER_COLOR, 8, false, 1.5)
	_set_mood(driver, Mood.SHOCK if shout else Mood.CHEER, 0.8)


## A passenger says something, then the driver answers.
func exchange(passenger_line: String, driver_line: String, voice := "voice_hurt") -> void:
	chatter(passenger_line, voice)
	_later(1.0, driver_say.bind(driver_line, false, true))


## Named moments from the bus/level: "rocket", "start", "finish", "fuel_low", "crash", hazards...
func event(kind: String) -> void:
	match kind:
		"rocket":
			driver_say(DRIVER_LINES.rocket.pick_random(), true)
		"crash":
			driver_say(DRIVER_LINES.crash.pick_random(), true, true)
		"chatter":  # a random passenger remark, sometimes answered
			pass
		_:
			if DRIVER_LINES.has(kind):
				driver_say(DRIVER_LINES[kind].pick_random(), kind in ["chasm", "water", "swamp", "lava"], true)


func _riders_only() -> Array[Dictionary]:
	return riders.filter(func(r): return r != driver)


func _later(t: float, fn: Callable) -> void:
	get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(self): fn.call())


func _quip_some(count: int, kind: String) -> void:
	var pool := _riders_only()
	pool.shuffle()
	var lines: Array = QUIPS[kind].duplicate()
	lines.shuffle()
	for i in mini(count, pool.size()):
		var r: Dictionary = pool[i]
		get_tree().create_timer(0.12 + i * 0.22).timeout.connect(_quip.bind(r, lines[i % lines.size()], kind))


func _quip(r: Dictionary, line: String, kind: String) -> void:
	if not is_instance_valid(r.sprite) or not r.sprite.visible:
		return
	var voice: String = {"perfect": "voice_happy", "good": "voice_happy", "hard": "voice_hurt",
			"air": "voice_happy"}.get(kind, "voice_blip")
	Audio.play(voice, -8.0, 0.8 + r.row * 0.12, 0.05)
	var at: Vector2 = r.sprite.global_position + Vector2(4, -2)
	Fx.float_text(at, line, SHIRTS[r.row].lightened(0.25))
