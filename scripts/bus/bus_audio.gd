class_name BusAudio
extends Node
## All the noises the bus makes, driven by its physics state each frame.

var bus: Bus
var _engine: AudioStreamPlayer
var _rocket: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _prev_travel: Array[float] = [0.0, 0.0]
var _creak_cd := 0.0
var _skid_cd := 0.0
var _sputter_cd := 0.0
var _low_fuel_warned := false
var _was_firing := false
var _groan_cd := 0.0
var _rattle_cd := 0.0
var _prev_spin := 0.0


func _init(owner_bus: Bus) -> void:
	bus = owner_bus


func _ready() -> void:
	_engine = Audio.make_loop("engine_loop", self, -12.0)
	_rocket = Audio.make_loop("rocket_loop", self, -60.0)
	_wind = Audio.make_loop("wind_loop", self, -60.0)
	_engine.play()
	_rocket.play()
	_wind.play()
	bus.landed.connect(_on_landed)
	bus.crashed.connect(_on_crashed)


func _physics_process(delta: float) -> void:
	if bus.is_crashed or bus.chassis == null:
		return
	_creak_cd -= delta
	_groan_cd -= delta
	_rattle_cd -= delta
	_skid_cd -= delta
	_sputter_cd -= delta

	var spin := 0.0
	for w in bus.wheels:
		spin += absf(w.angular_velocity)
	spin /= maxf(1.0, bus.wheels.size())
	var rev := clampf(spin / bus.max_wheel_spin, 0.0, 1.2)
	var throttle := absf(bus.throttle)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.75 + rev * 1.1 + throttle * 0.2, 0.15)
	_engine.volume_db = lerpf(_engine.volume_db, -15.0 + throttle * 5.0 + rev * 3.0, 0.1)

	var target_rocket := -5.0 if bus.rocket_firing else -60.0
	_rocket.volume_db = move_toward(_rocket.volume_db, target_rocket, 300.0 * delta)
	if bus.rocket_firing and not _was_firing:
		Audio.play("rocket_ignite", -4.0, 1.0, 0.05)
	_was_firing = bus.rocket_firing
	if bus.wants_fire and bus.fuel <= 0.0 and _sputter_cd <= 0.0:
		_sputter_cd = 0.8
		Audio.play("rocket_sputter", -4.0)
	if not _low_fuel_warned and bus.fuel < bus.fuel_capacity * 0.25:
		_low_fuel_warned = true
		Audio.play("fuel_low", -6.0)
	elif bus.fuel > bus.fuel_capacity * 0.3:
		_low_fuel_warned = false

	var speed := bus.chassis.linear_velocity.length()
	var wind_target := linear_to_db(clampf(speed / 700.0, 0.0001, 1.0)) - 4.0 if bus.airborne else -60.0
	_wind.volume_db = move_toward(_wind.volume_db, wind_target, 80.0 * delta)

	# The old frame groans when it twists: sudden changes in pitch, or one axle
	# being shoved up harder than the other.
	var spin_change := absf(bus.chassis.angular_velocity - _prev_spin) / delta
	_prev_spin = bus.chassis.angular_velocity
	var twist := absf(_prev_travel[0] - _prev_travel[1])
	if _groan_cd <= 0.0 and (spin_change > 14.0 or (twist > 7.0 and not bus.airborne)):
		_groan_cd = randf_range(0.7, 1.4)
		Audio.play(["creak_a", "creak_b", "creak_c"].pick_random(), -10.0, randf_range(0.85, 1.15))

	# Suspension creaks when a wheel is shoved up into the body quickly.
	for i in bus.wheels.size():
		var travel := bus.chassis.to_local(bus.wheels[i].global_position).y
		var v := (_prev_travel[i] - travel) / delta
		_prev_travel[i] = travel
		if v > 60.0 and _creak_cd <= 0.0 and not bus.airborne:
			_creak_cd = 0.3
			Audio.play("spring_creak", linear_to_db(clampf(v / 250.0, 0.1, 1.0)) - 8.0, 1.0, 0.15)
			if speed > 150.0 and _rattle_cd <= 0.0:  # loose panels rattle over bumps
				_rattle_cd = 0.5
				Audio.play("rattle", -14.0, randf_range(0.9, 1.2))

	if bus.throttle < 0.0 and bus.get_speed() > 120.0 and not bus.airborne and _skid_cd <= 0.0:
		_skid_cd = 0.6
		Audio.play("skid", -12.0, 1.0, 0.1)


func honk() -> void:
	Audio.play("horn", -3.0)


func stop_loops() -> void:
	for p in [_engine, _rocket, _wind]:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, 0.4)


func _on_landed(grade: String, _impact: float, _angle: float) -> void:
	match grade:
		"perfect":
			Audio.play("land_soft", -2.0)
			Audio.play("jingle_perfect", -4.0)
			Audio.play("cheer", -6.0)
		"good":
			Audio.play("land_soft", -2.0)
			Audio.play("jingle_good", -6.0)
		"hard":
			Audio.play("land_hard", 0.0)
			Audio.play("creak_b", -6.0)
			Audio.play("sting_hard", -6.0)
			Audio.play("groan", -6.0)


func _on_crashed(_reason: String) -> void:
	stop_loops()
	Audio.play("crash", 0.0)
	Audio.play("sting_crash", -6.0)
	Audio.play("voice_scream", -6.0, 1.0, 0.2)
	for i in 5:
		get_tree().create_timer(0.3 + i * randf_range(0.15, 0.3)).timeout.connect(
				Audio.play.bind("clank", -8.0, randf_range(0.7, 1.4)))
