class_name BusPassengers
extends Node2D
## Riders sitting behind the windows. They sway with the bus's acceleration
## (float up in free fall, get squashed on landings), change faces with the
## action, shout colourful quips, and get thrown out when the bus breaks apart.

enum Mood { IDLE, CHEER, SHOCK }

const SHEET := preload("res://assets/sprites/passengers.png")
const SWAY_GAIN := 0.004
const SWAY_LIMIT := Vector2(2.0, 3.0)

# Top-left of each 8x10 rider sprite in bus-local px, plus sprite-sheet row.
const SEATS := [
	[Vector2(-34, -15), 0], [Vector2(-6, -15), 3], [Vector2(8, -15), 1], [Vector2(22, -15), 4],
	[Vector2(-22, 5), 2], [Vector2(14, 5), 3], [Vector2(31, 5), 5],  # last = driver
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
	"crash": ["AAAAH!", "MY HAT!", "NOOO!", "MOMMY!"],
}

var riders: Array[Dictionary] = []
var _filtered_accel := Vector2.ZERO
var _air_quipped := false


func _ready() -> void:
	for seat in SEATS:
		var s := Sprite2D.new()
		s.texture = SHEET
		s.hframes = 3
		s.vframes = 6
		s.centered = false
		s.position = seat[0]
		s.light_mask = 3  # lit by the world and by the cabin lights
		add_child(s)
		riders.append({
			"sprite": s, "base": seat[0], "row": seat[1],
			"offset": Vector2.ZERO, "vel": Vector2.ZERO,
			"stiff": randf_range(160.0, 240.0), "mood_time": 0.0,
		})
		_set_mood(riders[-1], Mood.IDLE)


## proper_accel_local: the bus's acceleration minus gravity, in bus space.
## At rest upright this is (0, -g); in free fall it is zero.
func update_sway(proper_accel_local: Vector2, gravity: float, delta: float) -> void:
	_filtered_accel = _filtered_accel.lerp(proper_accel_local, 0.35)
	var target := -(_filtered_accel + Vector2(0, gravity)) * SWAY_GAIN
	target = target.clamp(-SWAY_LIMIT, SWAY_LIMIT)
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
			_quip(riders.pick_random(), QUIPS.air.pick_random())


func react(grade: String) -> void:
	_air_quipped = false
	match grade:
		"perfect":
			for r in riders:
				_set_mood(r, Mood.CHEER, 1.4)
				r.vel.y -= 90.0
			_quip_some(2, "perfect")
		"good":
			for r in riders:
				_set_mood(r, Mood.CHEER if randf() < 0.6 else Mood.IDLE, 1.0)
				r.vel.y -= 40.0
			_quip_some(1, "good")
		"hard":
			for r in riders:
				_set_mood(r, Mood.SHOCK, 1.3)
				r.vel.y += 160.0
				r.vel.x += randf_range(-60.0, 60.0)
			_quip_some(2, "hard")


## Throws every rider out of the bus as a small tumbling physics body.
func eject(into: Node, bus_velocity: Vector2) -> void:
	var delay := 0.0
	for r in riders:
		var s: Sprite2D = r.sprite
		var body := RigidBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 1
		body.mass = 0.08
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 3.5
		shape.shape = circle
		body.add_child(shape)
		var face := Sprite2D.new()
		face.texture = SHEET
		face.hframes = 3
		face.vframes = 6
		face.frame = r.row * 3 + Mood.SHOCK
		body.add_child(face)
		body.global_position = s.global_position + Vector2(4, 5).rotated(s.global_rotation)
		body.rotation = s.global_rotation
		body.linear_velocity = bus_velocity * 0.6 + Vector2(randf_range(-140, 140), randf_range(-340, -180))
		body.angular_velocity = randf_range(-14.0, 14.0)
		into.add_child(body)
		s.hide()
		if randf() < 0.5:
			var text: String = QUIPS.crash.pick_random()
			var color: Color = SHIRTS[r.row].lightened(0.2)
			delay += 0.15
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(body):
					Fx.float_text(body.global_position, text, color))


func _set_mood(r: Dictionary, mood: Mood, duration := 0.0) -> void:
	r.sprite.frame = r.row * 3 + mood
	r.mood_time = duration


func _quip_some(count: int, kind: String) -> void:
	var pool := riders.duplicate()
	pool.shuffle()
	var lines: Array = QUIPS[kind].duplicate()
	lines.shuffle()
	for i in mini(count, pool.size()):
		var r: Dictionary = pool[i]
		get_tree().create_timer(0.12 + i * 0.22).timeout.connect(_quip.bind(r, lines[i % lines.size()]))


func _quip(r: Dictionary, line: String) -> void:
	if not is_instance_valid(r.sprite) or not r.sprite.visible:
		return
	var at: Vector2 = r.sprite.global_position + Vector2(4, -2)
	Fx.float_text(at, line, SHIRTS[r.row].lightened(0.25))
