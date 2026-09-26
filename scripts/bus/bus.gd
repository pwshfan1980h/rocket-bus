class_name Bus
extends Node2D
## The Rocket Bus: a double-decker built from rigid bodies and joints.
##
##   Chassis (RigidBody2D) --GrooveJoint2D + DampedSpringJoint2D--> Wheel x2
##
## The rigid core frame (lower deck floor, rail, pillars) is the chassis itself.
## Everything else - upper-deck cage, seats, engine, panels, door, hood, bumpers,
## fenders, sign, rocket - is a sprite on the chassis until a crash; then each is
## swapped for a loose debris body, the glass shatters, the joints are cut and the
## passengers are thrown out, leaving just the core.
## Call setup() before adding the bus to the tree.

signal landed(grade: String, impact: float, angle_deg: float)
signal crashed(reason: String)
signal hazard_hit(kind: String)

const TEX_CORE := preload("res://assets/sprites/bus_core.png")
const TEX_GLASS := preload("res://assets/sprites/bus_glass.png")
const TEX_WHEEL := preload("res://assets/sprites/wheel.png")
const TEX_ROCKET := preload("res://assets/sprites/rocket.png")
const TEX_FLAME := preload("res://assets/sprites/flame.png")
const TEX_AXLE := preload("res://assets/sprites/axle.png")
const TEX_RADIAL := preload("res://assets/sprites/light_radial.png")
const TEX_CONE := preload("res://assets/sprites/light_cone.png")
# Breakable pieces: name, texture, rect in body px (x 0..79 cabin, 80..99 hood; y 0..45 roof->skirt), mass.
const INTERIOR := [  # drawn behind the passengers
	["cage", preload("res://assets/sprites/bus_cage.png"), Rect2(0, 0, 80, 24), 0.3],
	["seats", preload("res://assets/sprites/bus_seats.png"), Rect2(4, 10, 74, 28), 0.15],
	["engine", preload("res://assets/sprites/bus_engine.png"), Rect2(81, 28, 16, 12), 0.35],
]
const SHELL := [  # drawn over the passengers
	["upper_r", preload("res://assets/sprites/bus_upper_r.png"), Rect2(0, 4, 40, 18), 0.15],
	["upper_f", preload("res://assets/sprites/bus_upper_f.png"), Rect2(40, 4, 40, 18), 0.15],
	["lower_r", preload("res://assets/sprites/bus_lower_r.png"), Rect2(0, 22, 43, 20), 0.18],
	["door", preload("res://assets/sprites/bus_door.png"), Rect2(43, 26, 10, 16), 0.06],
	["lower_f", preload("res://assets/sprites/bus_lower_f.png"), Rect2(53, 22, 27, 20), 0.12],
	["hood", preload("res://assets/sprites/bus_hood.png"), Rect2(80, 26, 18, 16), 0.15],
	["bumper_f", preload("res://assets/sprites/bus_bumper_f.png"), Rect2(78, 42, 22, 4), 0.08],
	["bumper_r", preload("res://assets/sprites/bus_bumper_r.png"), Rect2(0, 42, 5, 4), 0.03],
	["fender_rear", preload("res://assets/sprites/bus_fender_rear.png"), Rect2(4, 34, 29, 12), 0.06],
	["fender_front", preload("res://assets/sprites/bus_fender_front.png"), Rect2(60, 34, 29, 12), 0.06],
	["roof_r", preload("res://assets/sprites/bus_roof_r.png"), Rect2(0, 0, 40, 4), 0.08],
	["roof_f", preload("res://assets/sprites/bus_roof_f.png"), Rect2(40, 0, 40, 4), 0.08],
	["sign", preload("res://assets/sprites/bus_sign.png"), Rect2(26, -7, 28, 7), 0.05],
]
# Window rects (body px) the glass shatters from.
const WINDOWS: Array[Rect2] = [
	Rect2(4, 7, 68, 10), Rect2(74, 7, 4, 10), Rect2(4, 27, 38, 7), Rect2(44, 27, 8, 15), Rect2(54, 27, 24, 7),
]

const BODY_ORIGIN := Vector2(-40, -23)  # body px (0,0) in chassis space
const CANVAS_ORIGIN := Vector2(-40, -30)  # top-left of the 100x53 piece canvases
const WHEEL_X: Array[float] = [-22.0, 34.0]
const WHEEL_RADIUS := 9.0
const GROOVE_TOP := 12.0
const GROOVE_LENGTH := 16.0
const WHEEL_REST_Y := 21.0
const ROCKET_POS := Vector2(-64, 1)  # top-left of the 24x20 booster sprite
const ROCKET_SIZE := Vector2(24, 20)
const NOZZLES: Array[Vector2] = [Vector2(-64, 6.5), Vector2(-64, 15.5)]
const FLAME_SCALE := 1.7
const LAYER_WORLD := 1
const LAYER_BUS := 2
const LAYER_DEBRIS := 4
const LAYER_BLOCKERS := 16  # boulders, logs, barricades (see Obstacle)
const TEX_CANNON := preload("res://assets/sprites/cannon.png")
const CANNON_POS := Vector2(47, 10)  # top-left of the 16x8 cannon sprite
const MUZZLE := Vector2(64, 13.5)

@export_group("Body")
@export var chassis_mass := 1.0
@export var center_of_mass := Vector2(5, 5)  ## +y is lower. The engine pulls it forward.
@export_group("Suspension")
@export var spring_stiffness := 85.0
@export var spring_damping := 0.5  ## low = bouncy landings
@export var spring_preload := 5.0  ## extra rest length; holds the ride height
@export_group("Drive")
@export var drive_torque := 2600.0
@export var brake_torque := 3200.0
@export var max_wheel_spin := 45.0
@export_group("Rocket")
@export var rocket_thrust := 950.0
@export var rocket_nose_lift := 900.0  ## low-mounted nozzles lift the nose a little
@export var fuel_capacity := 100.0
@export var fuel_burn_rate := 34.0
@export_group("Cannon")
@export var cannon_cooldown := 0.35
@export var cannon_recoil := 35.0
@export_group("Air control")
@export var air_torque := 3600.0
@export var max_air_spin := 2.2
@export_group("Landing")
@export var min_air_time := 0.3
@export var perfect_impact := 460.0
@export var perfect_angle := 5.0
@export var hard_impact := 640.0
@export var hard_angle := 15.0
@export var crash_impact := 900.0
@export var crash_angle := 34.0
@export var body_crash_speed := 340.0

var chassis: RigidBody2D
var wheels: Array[RigidBody2D] = []
var passengers: BusPassengers
var fuel := 0.0
var rocket_firing := false
var is_crashed := false
var last_landing := {}
var airborne := false
var throttle := 0.0  ## current -1..1 drive input
var wants_fire := false
var controls_enabled := true
var ammo := 0
## Road surface under the wheels, set by the level: "", "mud" or "ice".
var surface := "":
	set(v):
		if v != surface:
			_on_surface(surface, v)
		surface = v
var headwind := 0.0  ## weather push against the bus (px/s^2-ish force)
var in_hazard := ""
var audio: BusAudio
## Scripted input (lab demos, replays): {"right": -1..1, "fire": bool}. Empty = player.
var ai_input := {}

var _spawn := Transform2D.IDENTITY
var _spawn_vel := Vector2.ZERO
var _spawn_spin := 0.0
var _gravity := 700.0
var _joints: Array[Joint2D] = []
var _shell := {}
var _flames: Array[Sprite2D] = []
var _exhaust: CPUParticles2D
var _rocket_sprite: Sprite2D
var _rocket_light: PointLight2D
var _rocket_fx: Node2D
var _headlight: PointLight2D
var _cabin_lights: Array[PointLight2D] = []
var _sign_light: PointLight2D
var _rocket_debris: RigidBody2D
var _debris_burn := 0.0
var _flame_clock := 0.0
var _air_time := 0.0
var _flip_time := 0.0
var _prev_vel := Vector2.ZERO
var _since_landing := 99.0
var _skin: Node2D
var _cannon: Sprite2D
var _cannon_cd := 0.0
var _reload := 0.0  ## an empty cannon slowly reloads one slug at a time
const RELOAD_TIME := 3.0
var _glass: Sprite2D
var _smoke: CPUParticles2D


func setup(pos: Vector2, rot := 0.0, vel := Vector2.ZERO, spin := 0.0) -> Bus:
	_spawn = Transform2D(rot, pos)
	_spawn_vel = vel
	_spawn_spin = spin
	return self


func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	fuel = fuel_capacity
	_build_chassis()
	_build_skin()
	_build_wheels()
	_build_lights()
	_prev_vel = _spawn_vel
	audio = BusAudio.new(self)
	add_child(audio)


func get_speed() -> float:
	return chassis.linear_velocity.dot(chassis.global_transform.x)


func fuel_ratio() -> float:
	return fuel / fuel_capacity


# --- Build ------------------------------------------------------------------

func _build_chassis() -> void:
	chassis = RigidBody2D.new()
	chassis.name = "Chassis"
	chassis.mass = chassis_mass
	chassis.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	chassis.center_of_mass = center_of_mass
	chassis.physics_material_override = _material(0.5, 0.0)
	chassis.contact_monitor = true
	chassis.max_contacts_reported = 4
	chassis.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	chassis.collision_layer = LAYER_BUS
	chassis.collision_mask = LAYER_WORLD | LAYER_BLOCKERS
	chassis.transform = _spawn
	chassis.linear_velocity = _spawn_vel
	chassis.angular_velocity = _spawn_spin
	var poly := CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-40, -21), Vector2(-38, -23), Vector2(38, -23), Vector2(40, -21),
		Vector2(40, 4), Vector2(55, 8), Vector2(58, 10), Vector2(58, 18), Vector2(-40, 18),
	])
	chassis.add_child(poly)
	add_child(chassis)


func _build_skin() -> void:
	var skin := Node2D.new()
	_skin = skin
	skin.name = "Skin"
	chassis.add_child(skin)
	var core := _sprite(TEX_CORE, CANVAS_ORIGIN)
	core.light_mask = 3  # interior also catches the cabin lights
	skin.add_child(core)
	for piece in INTERIOR:
		var s := _sprite(piece[1], CANVAS_ORIGIN)
		s.light_mask = 3
		skin.add_child(s)
		_shell[piece[0]] = s
	passengers = BusPassengers.new()
	skin.add_child(passengers)
	_glass = _sprite(TEX_GLASS, CANVAS_ORIGIN)
	skin.add_child(_glass)
	for piece in SHELL:
		var s := _sprite(piece[1], CANVAS_ORIGIN)
		skin.add_child(s)
		_shell[piece[0]] = s
	_rocket_sprite = _sprite(TEX_ROCKET, ROCKET_POS)
	skin.add_child(_rocket_sprite)
	_cannon = _sprite(TEX_CANNON, CANNON_POS)
	skin.add_child(_cannon)

	# Everything that burns lives under one node so it can follow the rocket
	# when the rocket tears off.
	_rocket_fx = Node2D.new()
	skin.add_child(_rocket_fx)
	for n in NOZZLES:
		var f := Sprite2D.new()
		f.texture = TEX_FLAME
		f.hframes = 3
		f.position = n + Vector2(-8 * FLAME_SCALE, 0)
		f.scale = Vector2(FLAME_SCALE, FLAME_SCALE)
		f.visible = false
		_rocket_fx.add_child(f)
		_flames.append(f)
	_exhaust = CPUParticles2D.new()
	_exhaust.position = Vector2(-70, 11)
	_exhaust.emitting = false
	_exhaust.amount = 130
	_exhaust.lifetime = 0.45
	_exhaust.local_coords = false
	_exhaust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_exhaust.emission_rect_extents = Vector2(2, 7)
	_exhaust.direction = Vector2.LEFT
	_exhaust.spread = 9.0
	_exhaust.gravity = Vector2(0, -60)
	_exhaust.initial_velocity_min = 140.0
	_exhaust.initial_velocity_max = 230.0
	_exhaust.scale_amount_min = 1.5
	_exhaust.scale_amount_max = 3.5
	_exhaust.color_ramp = _gradient([
		[0.0, Color(1, 1, 0.85)], [0.2, Color(1, 0.8, 0.3)], [0.45, Color(1, 0.35, 0.15)],
		[0.7, Color(0.45, 0.35, 0.5, 0.7)], [1.0, Color(0.3, 0.25, 0.35, 0)],
	])
	_rocket_fx.add_child(_exhaust)
	# A lingering smoke trail behind the boosters.
	_smoke = CPUParticles2D.new()
	_smoke.position = Vector2(-80, 11)
	_smoke.emitting = false
	_smoke.amount = 60
	_smoke.lifetime = 1.8
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(3, 6)
	_smoke.direction = Vector2.LEFT
	_smoke.spread = 25.0
	_smoke.gravity = Vector2(0, -25)
	_smoke.initial_velocity_min = 30.0
	_smoke.initial_velocity_max = 70.0
	_smoke.damping_min = 20.0
	_smoke.damping_max = 40.0
	_smoke.scale_amount_min = 3.0
	_smoke.scale_amount_max = 6.0
	_smoke.scale_amount_curve = _grow_curve()
	_smoke.color_ramp = _gradient([
		[0.0, Color(0.9, 0.86, 0.86, 0.0)], [0.08, Color(0.88, 0.84, 0.86, 0.8)],
		[0.6, Color(0.6, 0.56, 0.62, 0.5)], [1.0, Color(0.45, 0.42, 0.48, 0.0)],
	])
	_rocket_fx.add_child(_smoke)
	_rocket_light = _light(TEX_RADIAL, Vector2(-86, 11), Color(1, 0.55, 0.2), 1.8, 2.6)
	_rocket_light.enabled = false
	_rocket_fx.add_child(_rocket_light)


func _build_wheels() -> void:
	for x in WHEEL_X:
		var w := RigidBody2D.new()
		w.name = "Wheel"
		w.mass = 0.2
		w.physics_material_override = _material(1.2, 0.05)
		w.contact_monitor = true
		w.max_contacts_reported = 2
		w.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		w.collision_layer = LAYER_BUS
		w.collision_mask = LAYER_WORLD | LAYER_BLOCKERS
		w.position = _spawn * Vector2(x, WHEEL_REST_Y)
		w.linear_velocity = _spawn_vel
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = WHEEL_RADIUS
		shape.shape = circle
		w.add_child(shape)
		var s := Sprite2D.new()
		s.texture = TEX_WHEEL
		w.add_child(s)
		add_child(w)
		wheels.append(w)

		# The wheel slides along a vertical groove (suspension travel)...
		var groove := GrooveJoint2D.new()
		groove.position = Vector2(x, GROOVE_TOP)
		groove.length = GROOVE_LENGTH
		groove.initial_offset = WHEEL_REST_Y - GROOVE_TOP
		_attach(groove, w)
		# ...and a damped spring pushes it back down.
		var spring := DampedSpringJoint2D.new()
		spring.position = Vector2(x, 0)
		spring.length = WHEEL_REST_Y
		spring.rest_length = WHEEL_REST_Y + spring_preload
		spring.stiffness = spring_stiffness
		spring.damping = spring_damping
		_attach(spring, w)


func _attach(joint: Joint2D, wheel: RigidBody2D) -> void:
	chassis.add_child(joint)
	joint.node_a = joint.get_path_to(chassis)
	joint.node_b = joint.get_path_to(wheel)
	_joints.append(joint)


func _build_lights() -> void:
	_headlight = _light(TEX_CONE, Vector2(57, 10), Color(1, 0.95, 0.75), 1.4, 1.0)
	_headlight.offset = Vector2(64, 0)
	chassis.add_child(_headlight)
	chassis.add_child(_light(TEX_RADIAL, Vector2(55, 10), Color(1, 0.95, 0.8), 1.0, 0.3))
	chassis.add_child(_light(TEX_RADIAL, Vector2(-40, 15), Color(1, 0.15, 0.1), 0.9, 0.4))
	for y in [-11.0, 9.0]:
		var cabin := _light(TEX_RADIAL, Vector2(0, y), Color(1, 0.82, 0.55), 1.3, 1.7)
		cabin.range_item_cull_mask = 2  # only the interior + riders
		chassis.add_child(cabin)
		_cabin_lights.append(cabin)
	_sign_light = _light(TEX_RADIAL, Vector2(0, -26), Color(1, 0.3, 0.7), 0.9, 0.9)
	chassis.add_child(_sign_light)


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_crashed or in_hazard != "":
		_burn_loose_rocket(delta)
		return
	var right: float = ai_input.get("right", 0.0) if not ai_input.is_empty() \
			else Input.get_axis("move_left", "move_right")
	var fire: bool = ai_input.get("fire", false) if not ai_input.is_empty() \
			else Input.is_action_pressed("rocket")
	if not controls_enabled:
		right = 0.0
		fire = false
	elif ai_input.is_empty() and Input.is_action_just_pressed("horn"):
		honk()
	throttle = right
	wants_fire = fire
	_cannon_cd -= delta
	if ammo <= 0:
		_reload += delta
		if _reload >= RELOAD_TIME:
			_reload = 0.0
			ammo = 1
			Audio.play("ammo_pickup", -8.0)
	else:
		_reload = 0.0
	var shoot: bool = ai_input.get("shoot", false) if not ai_input.is_empty() \
			else Input.is_action_just_pressed("fire")
	if shoot and controls_enabled:
		fire_cannon()

	var wheel_contacts := 0
	for w in wheels:
		if w.get_contact_count() > 0:
			wheel_contacts += 1
	var body_contact := chassis.get_contact_count() > 0
	airborne = wheel_contacts == 0
	if not controls_enabled and not airborne:
		_hold_brakes()

	if headwind != 0.0:
		chassis.apply_central_force(Vector2(-headwind, 0) * chassis.mass)
	if wheel_contacts > 0:
		_drive(right)
	else:
		_air_control(right)
	_rocket(fire and fuel > 0.0, delta)
	_check_landing(wheel_contacts, body_contact, delta)
	if is_crashed:
		return

	var accel := (chassis.linear_velocity - _prev_vel) / delta
	var proper := (accel - Vector2(0, _gravity)).rotated(-chassis.rotation)
	passengers.update_sway(proper, _gravity, delta)
	if wheel_contacts == 0:
		passengers.on_airborne(_air_time, rocket_firing)
	_prev_vel = chassis.linear_velocity


func _drive(right: float) -> void:
	var speed := get_speed()
	var grip: float = {"mud": 0.55, "ice": 0.35}.get(surface, 1.0)
	if surface == "mud":  # sticky: drags the bus down
		chassis.apply_central_force(Vector2(-chassis.linear_velocity.x * 1.4, 0) * chassis.mass)
	for w in wheels:
		if right > 0.0:
			if w.angular_velocity < max_wheel_spin:
				w.apply_torque(drive_torque * right * grip)
		elif right < 0.0:
			if speed > 25.0:
				w.apply_torque(-brake_torque * grip * signf(w.angular_velocity))
			elif w.angular_velocity > -max_wheel_spin * 0.4:
				w.apply_torque(drive_torque * right * 0.6)


## Bumper cannon: one slug straight ahead, with a kick.
func fire_cannon() -> void:
	if _cannon_cd > 0.0 or is_crashed or in_hazard != "":
		return
	_cannon_cd = cannon_cooldown
	if ammo <= 0:
		Audio.play("ui_back", -6.0)
		passengers.driver_say(["OUT OF AMMO!", "CLICK. CLICK.", "NEED AMMO!"].pick_random())
		return
	ammo -= 1
	if "--trace" in OS.get_cmdline_user_args():
		print("FIRE at x=%d rot=%.2f ammo=%d" % [chassis.global_position.x, chassis.rotation, ammo])
	var xf := chassis.global_transform
	# The cannon self-levels: shots keep most of their aim toward the road ahead
	# even when the bus is pitched up a hill or nose-down in the air.
	var dir := Vector2(xf.x.x, xf.x.y * 0.15).normalized()
	var muzzle := xf * MUZZLE
	add_child(Slug.new().fire(muzzle, dir, chassis.linear_velocity, xf * Vector2(20, 10)))
	chassis.apply_central_impulse(-dir * cannon_recoil * chassis.mass)
	Audio.play("cannon", -2.0, 1.0, 0.05)
	Fx.shake(2.5)
	var tw := create_tween()
	tw.tween_property(_cannon, "position:x", CANNON_POS.x - 4, 0.04)
	tw.tween_property(_cannon, "position:x", CANNON_POS.x, 0.18)
	var flash := _light(TEX_RADIAL, MUZZLE + Vector2(4, 0), Color(1, 0.85, 0.5), 2.2, 1.2)
	chassis.add_child(flash)
	var tw2 := create_tween()
	tw2.tween_property(flash, "energy", 0.0, 0.12)
	tw2.tween_callback(flash.queue_free)
	var smoke := CPUParticles2D.new()
	smoke.position = muzzle
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.amount = 14
	smoke.lifetime = 0.6
	smoke.direction = dir
	smoke.spread = 25.0
	smoke.gravity = Vector2(0, -30)
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 120.0
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.0
	smoke.color_ramp = _gradient([[0.0, Color(1, 0.9, 0.6)], [0.25, Color(0.75, 0.72, 0.7, 0.8)], [1.0, Color(0.6, 0.6, 0.6, 0)]])
	add_child(smoke)
	smoke.emitting = true
	get_tree().create_timer(0.8).timeout.connect(smoke.queue_free)
	if randf() < 0.25:
		passengers.driver_say(["EAT THIS!", "FIRE!", "OUTTA MY WAY!", "BOOM!"].pick_random(), true)


## Something outside the bus (an obstacle) wrecks it.
func crash_into(reason: String) -> void:
	_crash(reason)


func _on_surface(old: String, new: String) -> void:
	for w in wheels:
		w.physics_material_override.friction = 0.25 if new == "ice" else 1.2
	if new == "mud":
		Audio.play("mud_splash", -4.0, 1.0, 0.1)
		_mud_spray()
		passengers.chatter(["EWW, MUD!", "SPLASH!", "MY SHOES!"].pick_random())
	elif new == "ice" and old == "":
		passengers.chatter(["ICE!", "WHOA, SLIPPY!", "HOLD ON!"].pick_random(), "voice_hurt")


## Brown spray off the wheels, and mud splats that stay on the bus.
func _mud_spray() -> void:
	for w in wheels:
		var p := CPUParticles2D.new()
		p.position = w.global_position + Vector2(0, 6)
		p.one_shot = true
		p.explosiveness = 0.8
		p.amount = 24
		p.lifetime = 0.7
		p.direction = Vector2(-1, -1)
		p.spread = 40.0
		p.gravity = Vector2(0, 600)
		p.initial_velocity_min = 80.0
		p.initial_velocity_max = 200.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.0
		p.color = Color("#5a3a1e")
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	var splats := Node2D.new()
	var blobs := []
	for i in 10:
		blobs.append(Rect2(randf_range(-38, 50), randf_range(12, 21), randf_range(2, 5), randf_range(1, 3)))
	splats.draw.connect(func():
		for b in blobs:
			splats.draw_rect(b, Color("#5a3a1e")))
	_skin.add_child(splats)


func _hold_brakes() -> void:
	# Lock the wheels and scrub speed; the tires alone can't stop a sliding bus.
	for w in wheels:
		w.angular_velocity = 0.0
	chassis.linear_velocity.x = move_toward(chassis.linear_velocity.x, 0.0, 6.0)


func honk() -> void:
	audio.honk()
	Fx.float_text(chassis.global_position + Vector2(62, -10), "HONK!", Color("#ffe14a"))


## The bus has dropped into a gap: "chasm", "water", "swamp", "ice" or "lava".
func hazard(kind: String, surface: Vector2) -> void:
	if in_hazard != "" or is_crashed:
		return
	passengers.event(kind)
	in_hazard = kind
	_set_flames(false)
	rocket_firing = false
	audio.stop_loops()
	hazard_hit.emit(kind)
	var bodies: Array[RigidBody2D] = [chassis]
	bodies.append_array(wheels)
	match kind:
		"chasm":
			Audio.play("fall_whistle", -2.0)
			Audio.play("voice_scream", -6.0, 1.1, 0.1)
			get_tree().create_timer(1.7).timeout.connect(Audio.play.bind("crash", -14.0, 0.7))
		"lava":
			Audio.play("lava_sizzle", 0.0)
			Audio.play("voice_scream", -4.0, 1.2, 0.1)
			_sink(bodies, 0.12, 5.0)
			_skin_tint(Color(1.0, 0.35, 0.2), 1.2)
			_add_fx(_fire_particles(), chassis)
			_splash(surface, Color(1.0, 0.55, 0.15))
		_:  # water, swamp, icy water
			Audio.play("splash", 0.0)
			get_tree().create_timer(0.6).timeout.connect(Audio.play.bind("bubbles", -4.0))
			get_tree().create_timer(0.8).timeout.connect(Audio.play.bind("voice_glub", -4.0, 1.0, 0.2))
			_sink(bodies, 0.25, 3.0)
			var c := Color(0.55, 0.85, 1.0) if kind != "swamp" else Color(0.5, 0.7, 0.3)
			_splash(surface, c)
			_skin_tint(Color(0.55, 0.75, 1.0) if kind != "swamp" else Color(0.55, 0.7, 0.4), 2.0)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(_set_bus_lights.bind(false))


func _sink(bodies: Array[RigidBody2D], gravity_scale: float, damp: float) -> void:
	for b in bodies:
		b.gravity_scale = gravity_scale
		b.linear_damp = damp
		b.angular_damp = damp


func _skin_tint(c: Color, time: float) -> void:
	create_tween().tween_property(_skin, "modulate", c, time)


func _splash(at: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 90
	p.lifetime = 1.1
	p.direction = Vector2.UP
	p.spread = 35.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 2)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.color_ramp = _gradient([[0.0, Color.WHITE], [0.3, color], [1.0, Color(color, 0.0)]])
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _fire_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(44, 10)
	p.direction = Vector2.UP
	p.spread = 20.0
	p.gravity = Vector2(0, -90)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color_ramp = _gradient([
		[0.0, Color(1, 0.95, 0.5)], [0.3, Color(1, 0.5, 0.1)], [0.6, Color(0.5, 0.15, 0.1, 0.8)],
		[1.0, Color(0.2, 0.15, 0.15, 0.0)],
	])
	return p


func _add_fx(node: Node2D, parent: Node) -> void:
	parent.add_child(node)
	if node is CPUParticles2D:
		node.emitting = true


func _air_control(right: float) -> void:
	# Right = nose down (clockwise), left = nose up.
	if right != 0.0 and chassis.angular_velocity * signf(right) < max_air_spin:
		chassis.apply_torque(air_torque * right)


func _rocket(on: bool, delta: float) -> void:
	if on:
		# Thrust through the whole rig's centre of mass (chassis + wheels). Pushing
		# only the chassis COM lets the dangling wheels drag the nose down.
		chassis.apply_force(chassis.global_transform.x * rocket_thrust, _rig_center() - chassis.global_position)
		chassis.apply_torque(-rocket_nose_lift)
		fuel = maxf(0.0, fuel - fuel_burn_rate * delta)
	if on != rocket_firing:
		rocket_firing = on
		_set_flames(on)
		if on:
			passengers.event("rocket")
	_animate_flames(delta)


func _rig_center() -> Vector2:
	var total := chassis.mass
	var sum := chassis.to_global(chassis.center_of_mass) * chassis.mass
	for w in wheels:
		total += w.mass
		sum += w.global_position * w.mass
	return sum / total


func _check_landing(wheel_contacts: int, body_contact: bool, delta: float) -> void:
	if body_contact:
		var upright := absf(wrapf(chassis.rotation, -PI, PI)) < deg_to_rad(110.0)
		_flip_time = 0.0 if upright else _flip_time + delta
		if _flip_time > 0.4:
			_crash("FLIPPED IT")
			return
		# Slamming the nose into a wall while driving. Scraping the belly on a
		# landing (suspension bottoming out) doesn't count; landings are graded below.
		var driving := _air_time < min_air_time and _since_landing > 0.6
		if driving and absf(_prev_vel.x - chassis.linear_velocity.x) > body_crash_speed * 2.0:
			_crash("HEAD-ON")
			return
	_since_landing += delta
	if wheel_contacts == 0 and not body_contact:
		_air_time += delta
		return
	if _air_time >= min_air_time:
		_since_landing = 0.0
		_touchdown(wheel_contacts == 0)
	_air_time = 0.0


func _touchdown(body_first: bool) -> void:
	var normal := _ground_normal()
	var impact := maxf(0.0, _prev_vel.dot(-normal))
	var angle := absf(rad_to_deg(angle_difference(normal.angle() + PI / 2, chassis.rotation)))
	last_landing = {"impact": impact, "angle": angle, "grade": ""}
	if angle >= crash_angle:
		_crash("TORSION FAILURE")
	elif body_first and (impact > body_crash_speed or angle > crash_angle * 0.5):
		_crash("BELLY FLOP")
	elif impact >= crash_impact:
		_crash("TOO HARD!")
	if is_crashed:
		return
	var grade := "good"
	if impact >= hard_impact or angle >= hard_angle:
		grade = "hard"
	elif impact < perfect_impact and angle < perfect_angle:
		grade = "perfect"
	last_landing.grade = grade
	passengers.react(grade)
	_announce(grade)
	landed.emit(grade, impact, angle)


func _ground_normal() -> Vector2:
	var from := chassis.global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 140), LAYER_WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.normal if hit else Vector2.UP


func _announce(grade: String) -> void:
	var at := chassis.global_position + Vector2(0, -52)
	match grade:
		"perfect":
			Fx.float_text(at, "PERFECT!!", Color.WHITE, 16, true, 1.7)
		"good":
			Fx.float_text(at, ["NICE LANDING!", "SMOOTH!", "BUS-TASTIC!"].pick_random(),
					Color("#7dff6a"), 16)
		"hard":
			Fx.float_text(at, "HARD LANDING", Color("#ff9a2e"), 16)
			Fx.shake(3.0)


# --- Crash / break apart ----------------------------------------------------

func _crash(reason: String) -> void:
	if is_crashed:
		return
	passengers.event("crash")
	is_crashed = true
	last_landing.grade = "crash"
	var at := chassis.global_position + Vector2(0, -52)
	Fx.float_text(at, "WRECKED!", Color("#ff3b4e"), 16, false, 2.2)
	Fx.float_text(at + Vector2(0, 18), reason, Color("#ffd23a"), 8, false, 2.2)
	Fx.shake(9.0)
	_break_apart()
	crashed.emit(reason)


func _break_apart() -> void:
	var xf := chassis.global_transform
	var vel := chassis.linear_velocity
	for j in _joints:
		j.queue_free()
	_joints.clear()

	for piece in SHELL + INTERIOR:
		var rect: Rect2 = piece[2]
		var local := Rect2(rect.position + BODY_ORIGIN, rect.size)
		var body := _debris(piece[1], CANVAS_ORIGIN, local, piece[3], xf)
		var outward := local.get_center().normalized()
		body.linear_velocity = vel * 0.8 + outward * randf_range(70, 170) \
				+ Vector2(randf_range(-70, 70), randf_range(-280, -110))
		body.angular_velocity = randf_range(-8.0, 8.0)
		_shell[piece[0]].hide()
		if piece[0] == "sign":
			_sign_light.reparent(body)
	_shatter_glass(xf, vel)
	var gun := _debris(TEX_CANNON, CANNON_POS, Rect2(CANNON_POS, Vector2(16, 8)), 0.08, xf)
	gun.linear_velocity = vel + Vector2(randf_range(20, 120), randf_range(-240, -120))
	gun.angular_velocity = randf_range(-12.0, 12.0)
	_cannon.hide()

	_rocket_debris = _debris(TEX_ROCKET, ROCKET_POS, Rect2(ROCKET_POS, ROCKET_SIZE), 0.25, xf)
	_rocket_debris.linear_velocity = vel + Vector2(randf_range(-80, 20), randf_range(-220, -140))
	_rocket_debris.angular_velocity = randf_range(-9.0, 9.0)
	_rocket_sprite.hide()
	_rocket_fx.reparent(_rocket_debris)
	_debris_burn = 1.6
	_set_flames(true)

	for i in wheels.size():
		var w := wheels[i]
		w.linear_velocity += Vector2(randf_range(-80, 80), randf_range(-200, -90))
		w.angular_velocity += randf_range(-25.0, 25.0)
		var axle_at := Rect2(Vector2(WHEEL_X[i] - 6, 19), Vector2(12, 3))
		var axle := _debris(TEX_AXLE, axle_at.position, axle_at, 0.1, xf)
		axle.linear_velocity = vel * 0.5 + Vector2(randf_range(-60, 60), -150)
		axle.angular_velocity = randf_range(-12.0, 12.0)

	passengers.eject(self, vel)
	if Gore.enabled():
		_blood_smear()
	_spark_burst(xf * Vector2(0, 18))
	var tw := create_tween()
	for i in 3:  # lights die with a flicker
		tw.tween_callback(_set_bus_lights.bind(false)).set_delay(0.06)
		tw.tween_callback(_set_bus_lights.bind(true)).set_delay(0.08)
	tw.tween_callback(_set_bus_lights.bind(false)).set_delay(0.1)


## Red smears inside the wreck (the core frame is all that's left).
func _blood_smear() -> void:
	var smear := Node2D.new()
	var blobs := []
	for i in 16:
		blobs.append(Rect2(randf_range(-38, 36), randf_range(4, 16), randf_range(2, 6), randf_range(1, 3)))
	smear.draw.connect(func():
		for b in blobs:
			smear.draw_rect(b, Gore.BLOOD.lerp(Gore.BLOOD_DARK, randf()))
			smear.draw_rect(Rect2(b.position + Vector2(1, b.size.y), Vector2(1, randf_range(2, 5))), Gore.BLOOD_DARK))
	_skin.add_child(smear)


func _shatter_glass(xf: Transform2D, vel: Vector2) -> void:
	_glass.hide()
	for r in WINDOWS:
		var p := CPUParticles2D.new()
		p.position = xf * (r.get_center() + BODY_ORIGIN)
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = int(clampf(r.get_area() / 6.0, 8, 60))
		p.lifetime = 1.1
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = r.size / 2
		p.direction = Vector2(vel.normalized().x, -1)
		p.spread = 70.0
		p.gravity = Vector2(0, 700)
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 220.0
		p.angular_velocity_min = -400
		p.angular_velocity_max = 400
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		p.color_ramp = _gradient([[0.0, Color(0.85, 0.97, 1.0)], [0.6, Color(0.5, 0.8, 0.9, 0.8)],
				[1.0, Color(0.5, 0.8, 0.9, 0.0)]])
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	Audio.play("glass", -2.0)


func _burn_loose_rocket(delta: float) -> void:
	if _debris_burn <= 0.0 or not is_instance_valid(_rocket_debris):
		return
	_debris_burn -= delta
	_rocket_debris.apply_central_force(_rocket_debris.global_transform.x * 260.0)
	_rocket_debris.apply_torque(randf_range(-900.0, 900.0))
	_animate_flames(delta)
	if _debris_burn <= 0.0:
		_set_flames(false)


func _set_bus_lights(on: bool) -> void:
	_headlight.enabled = on
	for c in _cabin_lights:
		c.enabled = on


func _spark_burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 48
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 80.0
	p.gravity = Vector2(0, 600)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color_ramp = _gradient([
		[0.0, Color(1, 1, 0.8)], [0.4, Color(1, 0.7, 0.2)], [1.0, Color(1, 0.2, 0.1, 0)],
	])
	add_child(p)
	p.emitting = true
	var flash := _light(TEX_RADIAL, at, Color(1, 0.8, 0.5), 3.0, 3.0)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "energy", 0.0, 0.4)
	tw.tween_callback(flash.queue_free)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# --- Helpers ----------------------------------------------------------------

func _set_flames(on: bool) -> void:
	for f in _flames:
		f.visible = on
	_exhaust.emitting = on
	_smoke.emitting = on
	_rocket_light.enabled = on


func _animate_flames(delta: float) -> void:
	if not _flames[0].visible:
		return
	_flame_clock += delta
	if _flame_clock >= 0.05:
		_flame_clock = 0.0
		for f in _flames:
			f.frame = randi() % 3
			f.scale.x = randf_range(0.85, 1.2)
		_rocket_light.energy = randf_range(1.2, 1.9)


func _debris(tex: Texture2D, sprite_pos: Vector2, shape_rect: Rect2, mass: float,
		xf: Transform2D) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.mass = mass
	body.collision_layer = LAYER_DEBRIS
	body.collision_mask = LAYER_WORLD
	body.physics_material_override = _material(0.8, 0.15)
	body.transform = xf
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = shape_rect.size
	shape.shape = rect
	shape.position = shape_rect.get_center()
	body.add_child(shape)
	body.add_child(_sprite(tex, sprite_pos))
	add_child(body)
	return body


static func _sprite(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	return s


static func _light(tex: Texture2D, pos: Vector2, color: Color, energy: float,
		tex_scale: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = tex_scale
	return l


static func _material(friction: float, bounce: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = friction
	m.bounce = bounce
	return m


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1))
	return c


static func _gradient(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	return g
