extends Node2D
## Plays GameState.current_level: title card, countdown, the run, and the
## results or retry screen.
## User args: --level=N (start at N)  --bot (autopilot)  --botall (bot plays every level, prints a report)
## (Always test at normal speed: raising time_scale enlarges physics steps and changes outcomes.)

enum State { INTRO, PLAY, WON, FAILED }

const FAIL_TEXT := {
	"chasm": "FELL IN!", "water": "SPLASHDOWN!", "swamp": "SWAMPED!", "ice": "ON THIN ICE!",
	"lava": "TOASTED!", "crash": "WRECKED!",
}
const POINTS := {"perfect": 1000, "good": 500, "hard": 150}
const FRONT_FLIP_POINTS := 2000  ## per front flip stuck (+half again for a perfect landing)
const BACKFLIP_POINTS := 750

var index := 0
var def: Dictionary
var world: World
var bus: Bus
var state := State.INTRO
var clock := 0.0
var landings: Array[String] = []
var cleared := 0
var _args := PackedStringArray()
var _bot := false
var _skip_intro := false  ## batch bot runs skip the roll-in and countdown
var _hud := {}
var _hint_step := 0
var _chatter_timer := 8.0
var _warned_gaps := {}
var _stuck_time := 0.0
var _pause_panel: Control
var _pause_menu: MenuList
var _end_panel: Control
var _anchor: Node2D
var _teeter_time := 0.0
var _arrival := ""  # "", "drive", "brake": scripted roll-in before the countdown

static var bot_report: Array = []
static var bot_retries := 0

var _resume := {}  # checkpoint we're restarting from (empty = fresh start)
var _retries := 0  # checkpoint retries used on this run
var _style := {"flips": 0, "close": 0, "air": 0.0, "front": 0}
var _air_now := 0.0
var _spin_acc := 0.0
var _jump_flips := {"front": 0, "back": 0}  ## flips in the current jump, cashed in on landing
var _comet := false
var _speed_lines: Control
var _cp_passed := -INF
var _flip_points := 0  ## bonus banked from flips that were landed


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	for a in _args:
		if a.begins_with("--level=") and bot_report.is_empty():
			GameState.current_level = int(a.substr(8))
	_bot = "--bot" in _args or "--botall" in _args
	if _bot and bot_retries == 0:
		GameState.checkpoint = {}
	_skip_intro = "--botall" in _args
	index = GameState.current_level
	def = Levels.get_level(index)
	if GameState.checkpoint.get("level", -1) == index:
		_resume = GameState.checkpoint.duplicate(true)
		_cp_passed = _resume.x
	world = World.new().build(def.biome, def.segments)
	add_child(world)
	world.fuel_collected.connect(func(_c): if bus: bus.passengers.chatter(["YUM, GAS!", "REFUEL!", "GLUG GLUG"].pick_random(), "voice_happy"))
	world.life.birds_flushed.connect(_on_birds)
	var start := world.terrain.start_position()
	if not _resume.is_empty():
		start = Vector2(_resume.x, world.terrain.surface_y(_resume.x) - 31)
	if _skip_intro or not _resume.is_empty():
		bus = world.spawn_bus(start, def.fuel)
	else:  # roll in from off-screen, then stop at the line
		bus = world.spawn_bus(start + Vector2(-560, 0), def.fuel, Vector2(260, 0))
		_anchor = Node2D.new()
		_anchor.position = start + Vector2(40, -10)
		add_child(_anchor)
		world.camera.target = _anchor
		world.camera.snap()
	if not _resume.is_empty():
		bus.fuel = _resume.fuel
		clock = _resume.clock
		landings.assign(_resume.landings)
		cleared = _resume.cleared
		_style.merge(_resume.get("style", {}), true)
		_flip_points = _resume.get("flip_points", 0)
		_retries = _resume.get("retries", 0) + 1
		GameState.checkpoint.retries = _retries
	world.set_weather(def.get("weather", ""))
	bus.headwind = world.weather.headwind if world.weather else 0.0
	_hook_bus()
	world.start_ambience()
	_build_hud()
	_intro()


func _hook_bus() -> void:
	bus.controls_enabled = false
	bus.landed.connect(_on_landed)
	bus.crashed.connect(func(r): _fail("crash", r))
	bus.hazard_hit.connect(func(kind): _fail(kind))


func _intro() -> void:
	state = State.INTRO
	if not _skip_intro and _resume.is_empty():
		bus.controls_enabled = true
		_arrival = "drive"
		Audio.play("vroom", -2.0)
		while is_inside_tree() and _arrival != "":
			await get_tree().physics_frame
		if not is_inside_tree(): return
		bus.ai_input = {}
		bus.controls_enabled = false
		world.camera.target = bus.chassis
		bus.passengers.event("start")
	var card_text := "%s  %s" % [Levels.code(index), def.title]
	if not _resume.is_empty():
		card_text = "CHECKPOINT"
	var card := _label(_hud.layer, card_text, Vector2(0, 90), 16, Color("#ffcc26"), 4)
	card.size.x = 480
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var blurb := _label(_hud.layer, def.blurb, Vector2(0, 114), 8, Color.WHITE, 2)
	blurb.size.x = 480
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gaps_l := _label(_hud.layer, "%d GAP%s" % [world.terrain.gaps.size(), "S" if world.terrain.gaps.size() > 1 else ""],
			Vector2(0, 128), 8, Color("#3cf0dc"), 2)
	gaps_l.size.x = 480
	gaps_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wait := 0.3 if _skip_intro else 1.6
	await get_tree().create_timer(wait).timeout
	if not is_inside_tree(): return
	for n in [card, blurb, gaps_l]:
		n.queue_free()
	if not _skip_intro and _resume.is_empty():
		for c in ["3", "2", "1"]:
			_big_center(c, Color.WHITE)
			Audio.play("count_beep", -4.0)
			await get_tree().create_timer(0.55).timeout
			if not is_inside_tree(): return
	_big_center("GO!", Color("#7dff6a"))
	Audio.play("count_go", -4.0)
	state = State.PLAY
	bus.controls_enabled = true
	if index == 0 and not _bot:
		_hint("HOLD  D / RIGHT  TO DRIVE")


func _physics_process(delta: float) -> void:
	if _arrival != "" and is_instance_valid(bus):
		_drive_in()
	if _comet and is_instance_valid(bus):
		_comet_step(delta)
	if state != State.PLAY or not is_instance_valid(bus) or bus.chassis == null:
		return
	clock += delta
	var c := bus.chassis
	var x := c.global_position.x
	_hud.time.text = "%d.%d" % [int(clock), int(fmod(clock, 1.0) * 10)]
	_hud.fuel.size.x = roundf(60 * bus.fuel_ratio())
	_hud.fuel.color = Color("#ff4aa8") if bus.fuel_ratio() > 0.25 else Color("#ff3b3b")

	var zone := ""
	for w in bus.wheels:
		var z := world.terrain.zone_at(w.global_position.x)
		if z != "" and not bus.airborne:
			zone = z
	bus.surface = zone
	var gap := world.terrain.gap_at(x)
	if not gap.is_empty() and c.global_position.y > gap.trigger_y:
		bus.hazard(gap.kind, Vector2(x, gap.liquid_y))
		return
	_track_style(delta)
	if x > world.terrain.finish_x:
		# Soaring past the finish in the top half of the screen = comet exit.
		var screen_y := (get_viewport().get_canvas_transform() * c.global_position).y
		_win("--comet" in _args or (bus.airborne and screen_y < get_viewport().get_visible_rect().size.y * 0.5))
		return
	for cx in world.terrain.checkpoints:
		if x > cx and cx > _cp_passed:
			_reach_checkpoint(cx)
	if _bot:
		_bot_drive()
		if clock > 240.0:
			_bot_done("FAILED", "timeout: stuck at x=%d speed=%d" % [x, bus.get_speed()])
			state = State.FAILED
			return
	_tutorial(x)
	_chatter(delta, x)
	# Help a player who is stuck (flipped wheels-up, or sitting still for ages).
	_stuck_time = _stuck_time + delta if absf(bus.get_speed()) < 5.0 and clock > 3.0 else 0.0
	_teeter(delta)
	if _stuck_time > 4.0 and _hud.hint.text == "":
		_hint("STUCK?  PRESS R TO RETRY")


## Stalled with a wheel hanging over a gap (e.g. beached on the far lip): wobble,
## then tip off into it instead of sitting there forever.
func _teeter(delta: float) -> void:
	var hanging := false
	for w in bus.wheels:
		if not world.terrain.gap_at(w.global_position.x).is_empty():
			hanging = true
	if not hanging or absf(bus.get_speed()) > 12.0:
		_teeter_time = 0.0
		return
	_teeter_time += delta
	if _teeter_time > 0.4 and _teeter_time - delta <= 0.4:
		bus.passengers.chatter(["WE'RE TEETERING!", "DON'T MOVE!", "UH OH..."].pick_random(), "voice_hurt")
		Audio.play("creak_b", -4.0)
	if _teeter_time > 1.4:
		# Tip toward the gap the wheel is hanging over (never fling the bus away).
		var over := 0.0
		for w in bus.wheels:
			var g := world.terrain.gap_at(w.global_position.x)
			if not g.is_empty():
				over = signf((g.x0 + g.x1) / 2.0 - bus.chassis.global_position.x)
		bus.chassis.apply_central_impulse(Vector2(over * 60.0, 40.0) * bus.chassis.mass)
		bus.chassis.apply_torque_impulse(over * 1500.0)
		_teeter_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and state != State.INTRO:
		Transition.go("res://scenes/level.tscn")
	elif event.is_action_pressed("pause") and state == State.PLAY:
		_toggle_pause()


# --- Events -------------------------------------------------------------------

## Flips, big air and close calls, for Technique and the score.
func _track_style(delta: float) -> void:
	var c := bus.chassis
	if bus.airborne:
		_air_now += delta
		_spin_acc += c.angular_velocity * delta
		if absf(_spin_acc) >= TAU * 0.92:
			# Clockwise = nose over the front = a front flip (the hard, scary one).
			var front := _spin_acc > 0.0
			_spin_acc -= signf(_spin_acc) * TAU
			_style.flips += 1
			_jump_flips["front" if front else "back"] += 1
			var n: int = _jump_flips.front + _jump_flips.back
			Fx.float_text(c.global_position + Vector2(0, -60), ("FRONT FLIP!" if front else "BACKFLIP!")
					+ (" x%d" % n if n > 1 else ""), Color.WHITE, 16, true)
			Audio.play("jingle_good", -4.0)
			bus.passengers.driver_say(["WOOHOO!", "DID YOU SEE THAT?!", "I MEANT TO DO THAT!"].pick_random(), true)
	elif _air_now > 0.0:
		if _air_now > 2.0:
			Fx.float_text(c.global_position + Vector2(0, -70), "BIG AIR %.1fs!" % _air_now, Color("#3cf0dc"), 8)
		_style.air = maxf(_style.air, _air_now)
		_air_now = 0.0
		_spin_acc = 0.0
		_jump_flips = {"front": 0, "back": 0}


func _reach_checkpoint(cx: float) -> void:
	_cp_passed = cx
	GameState.checkpoint = {"level": index, "x": cx, "fuel": bus.fuel, "clock": clock,
		"landings": landings.duplicate(), "cleared": cleared, "retries": _retries, "style": _style.duplicate(),
		"flip_points": _flip_points}
	Audio.play("star", -4.0)
	Fx.float_text(bus.chassis.global_position + Vector2(0, -60), "CHECKPOINT!", Color("#3cf0dc"), 16)
	bus.passengers.driver_say(["HALFWAY THERE!", "KEEP IT TOGETHER!", "STILL IN ONE PIECE!"].pick_random())


func _on_landed(grade: String, _impact: float, _angle: float) -> void:
	if state != State.PLAY:
		return
	landings.append(grade)
	_cash_flips(grade)
	var x := bus.chassis.global_position.x
	var now_cleared := 0
	for g in world.terrain.gaps:
		if x > g.x1:
			now_cleared += 1
	if now_cleared > cleared:
		var g: Dictionary = world.terrain.gaps[now_cleared - 1]
		if x - g.x1 < 75.0:  # landed right on the lip
			_style.close += 1
			Fx.float_text(bus.chassis.global_position + Vector2(0, -60), "CLOSE ONE!", Color("#ff9a2e"), 16)
		cleared = now_cleared
		_hud.gaps.text = "GAPS %d/%d" % [cleared, world.terrain.gaps.size()]
		Audio.play("gap_cleared", -6.0)
		if index == 0 and _hint_step < 4:
			_hint_step = 4
			_hint("NICE!  NOW GET TO THE BUS STOP")


## Landed in one piece after flipping: front flips get the full fanfare.
func _cash_flips(grade: String) -> void:
	var front: int = _jump_flips.front
	var back: int = _jump_flips.back
	_jump_flips = {"front": 0, "back": 0}
	if front > 0:
		_style.front = _style.get("front", 0) + front
		var points := FRONT_FLIP_POINTS * front + (FRONT_FLIP_POINTS / 2 if grade == "perfect" else 0)
		_flip_points += points
		var party := Fanfare.new()
		party.hud = _hud.layer
		party.bus = bus
		party.camera = world.camera
		world.add_child(party)
		party.play(front, grade == "perfect", points)
	elif back > 0:
		_flip_points += BACKFLIP_POINTS * back
		Fx.float_text(bus.chassis.global_position + Vector2(0, -78), "BACKFLIP LANDED! +%d" % (BACKFLIP_POINTS * back),
				Color("#3cf0dc"), 8, false, 1.6)
		Audio.play("cha_ching", -8.0)


func _exit_tree() -> void:
	Fanfare.restore_time()  # never leave the game stuck in slow motion


func _on_birds(count: int) -> void:
	if count >= 2 and randf() < 0.3 and is_instance_valid(bus):
		bus.passengers.chatter(["BIRDS!", "LOOK, BIRDIES!", "SHOO!", "FLY, BIRDS, FLY!"].pick_random(), "voice_happy")


func _chatter(delta: float, x: float) -> void:
	_chatter_timer -= delta
	if _chatter_timer <= 0.0:
		_chatter_timer = randf_range(9.0, 16.0)
		var remark: String = Biomes.get_biome(def.biome).chatter.pick_random()
		if randf() < 0.4:
			bus.passengers.exchange(remark, bus.passengers.DRIVER_LINES.reply.pick_random(), "voice_blip")
		else:
			bus.passengers.chatter(remark)
	for r in world.terrain.ramps:
		if not _warned_gaps.has(r.x0) and x > r.x0 - 260 and x < r.x0:
			_warned_gaps[r.x0] = true
			if randf() < 0.6:
				bus.passengers.exchange(["IS THAT A GAP?!", "UH... DRIVER?", "WE'RE NOT STOPPING?!",
						"THE ROAD ENDS!"].pick_random(), bus.passengers.DRIVER_LINES.gap.pick_random())


func _tutorial(x: float) -> void:
	if index != 0 or _bot:
		return
	var ramp: Dictionary = world.terrain.ramps[0]
	if _hint_step == 0 and x > ramp.x0 - 320:
		_hint_step = 1
		_hint("RAMP AHEAD!  HOLD SPACE FOR ROCKET")
	elif _hint_step == 1 and bus.airborne and x > ramp.lip_x:
		_hint_step = 2
		_hint("IN THE AIR:  A / D  TO TILT.  LAND FLAT!")


## Scripted roll-in: drive toward the start line and brake to a stop on it.
func _drive_in() -> void:
	var x := bus.chassis.global_position.x - world.terrain.start_position().x
	if _arrival == "drive" and x > -150:
		_arrival = "brake"
	if _arrival == "drive":
		bus.ai_input = {"right": 0.8, "fire": false}
	else:
		bus.ai_input = {"right": -1.0 if bus.get_speed() > 8.0 else 0.0, "fire": false}
		if absf(bus.get_speed()) < 8.0:
			_arrival = ""


## Level end. Airborne and high on screen = COMET EXIT (cutscene, grade floor C,
## big bonus); otherwise the computer drives off-screen. Then freeze frame + report.
func _win(comet := false) -> void:
	state = State.WON
	bus.passengers.react("perfect")
	bus.passengers.event("finish")
	Audio.play("level_clear", -2.0)
	Audio.play("cheer", -6.0)
	_style.air = maxf(_style.air, _air_now)
	var report := _finish_report(comet)
	GameState.checkpoint = {}
	var showcase := "--showcase" in _args  # bot plays the real ending, nothing is saved
	if _bot and not showcase:  # the tester bot must never touch the player's save
		_bot_done("WON", "grade=%s spd=%d tech=%d fuel=%d landings=%s time=%.1f par=%.0f%s" % [report.grade,
				report.speed, report.technique, bus.fuel, landings, clock, report.par, " COMET" if comet else ""])
		return
	if not _bot:
		GameState.record(index, report.score, report.stars, report.grade)
	if comet:
		_start_comet()
	else:
		# The computer takes the wheel and drives off-screen while the camera pulls back.
		bus.ai_input = {"right": 0.9, "fire": false}
		world.camera.target = null
		world.camera.zoom_override = 0.72
		Audio.music("music_results")
		_big_center("BUS STOP!", Color("#ffcc26"))
	await get_tree().create_timer(3.4 if comet else 2.6).timeout
	if not is_inside_tree(): return
	_freeze_and_report(report)


func _finish_report(comet: bool) -> Dictionary:
	var par := Grading.par_time(world.terrain.finish_x)
	var speed := Grading.speed_stars(clock, par)
	var tech := Grading.technique_stars(landings, _retries, _style)
	var bonus := Grading.style_bonus(_style)
	var grade := Grading.grade(speed, tech, bonus, comet, _retries)
	var score := 0
	for g in landings:
		score += POINTS.get(g, 0)
	score += int(bus.fuel * 10) + maxi(0, int((par - clock) * 50))
	score += _flip_points + _style.close * 400 + int(_style.air * 100) + (2500 if comet else 0)
	return {
		"code": Levels.code(index), "title": def.title, "time": clock, "par": par, "landings": landings.duplicate(),
		"style": _style.duplicate(), "fuel_pct": int(bus.fuel / bus.fuel_capacity * 100), "retries": _retries,
		"speed": speed, "technique": tech, "grade": grade, "score": score, "comet": comet,
		"stars": int(round((speed + tech) / 2.0)), "last": index + 1 >= Levels.count(),
	}


## The bus keeps sailing like a comet: no gravity, climbing, heating up red-hot.
func _start_comet() -> void:
	_comet = true
	for b in [bus.chassis] + Array(bus.wheels):
		b.gravity_scale = 0.0
		b.collision_mask = 0
	bus.ai_input = {"right": 0.0, "fire": false}
	bus._set_flames(true)
	world.camera.zoom_override = 0.6
	Audio.music("music_comet", 0.2)
	Audio.play("comet_whoosh", 0.0)
	bus.passengers.driver_say("WE'RE NOT COMING BACK!", true, true)
	_big_center("COMET EXIT!", Color("#ff9a2e"))
	create_tween().tween_property(bus._skin, "modulate", Color(1.7, 0.95, 0.55), 1.6)
	var trail := CPUParticles2D.new()
	trail.amount = 160
	trail.lifetime = 0.9
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trail.emission_rect_extents = Vector2(40, 18)
	trail.direction = Vector2.LEFT
	trail.spread = 12.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 60.0
	trail.initial_velocity_max = 160.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 5.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 0.9), Color(1, 0.8, 0.3), Color(1, 0.35, 0.1, 0.8), Color(0.4, 0.1, 0.1, 0)])
	trail.color_ramp = g
	bus.chassis.add_child(trail)
	trail.emitting = true
	var glow := PointLight2D.new()
	glow.texture = preload("res://assets/sprites/light_radial.png")
	glow.color = Color(1, 0.6, 0.25)
	glow.energy = 2.2
	glow.texture_scale = 5.0
	bus.chassis.add_child(glow)
	_speed_lines = Control.new()
	_speed_lines.size = Vector2(480, 270)
	_speed_lines.draw.connect(_draw_speed_lines)
	_hud.layer.add_child(_speed_lines)


func _comet_step(delta: float) -> void:
	var c := bus.chassis
	c.linear_velocity = c.linear_velocity.lerp(Vector2(780, -260), 1.0 - exp(-1.5 * delta))
	c.angular_velocity = angle_difference(c.rotation, c.linear_velocity.angle()) * 4.0
	bus._animate_flames(delta)
	if _speed_lines:
		_speed_lines.queue_redraw()


func _draw_speed_lines() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 26:
		var y := fmod(i * 37.0, 270.0)
		var x := fposmod(480.0 - (t * 900.0 + i * 131.0), 560.0) - 40
		_speed_lines.draw_line(Vector2(x, y), Vector2(x + 30 + (i % 3) * 14, y), Color(1, 0.9, 0.7, 0.35), 1.0)


## Freeze frame: the world stops, a flash, and the Trip Report slides in.
func _freeze_and_report(report: Dictionary) -> void:
	get_tree().paused = true
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.8)
	flash.size = Vector2(480, 270)
	_hud.layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	Audio.play("stamp", -6.0)
	var card := TripReport.new().setup(report)
	_hud.layer.add_child(card)
	card.chosen.connect(_on_menu_choice)


func _fail(kind: String, reason := "") -> void:
	if state != State.PLAY:
		return
	state = State.FAILED
	if _bot:
		_bot_done("FAILED", "%s %s at x=%d fuel=%d landings=%s" % [kind, reason, bus.chassis.global_position.x, bus.fuel, landings])
		return
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree(): return
	if kind != "crash":
		_big_center(FAIL_TEXT.get(kind, "OOPS!"), Color("#ff3b4e"))
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree(): return
	Audio.play("fail_jingle", -4.0)
	_show_retry(FAIL_TEXT.get(kind, "OOPS!"))


# --- Bot --------------------------------------------------------------------------

## Simple autopilot used to prove levels are beatable: floor it, burn the rocket
## until the predicted landing clears the gap, and level out to the landing slope.
func _bot_drive() -> void:
	var c := bus.chassis
	var p := c.global_position
	var v := c.linear_velocity
	var next: Dictionary = {}
	for g in world.terrain.gaps:
		if p.x < g.x1 + 20:
			next = g
			break
	var fire := false
	var right := 1.0
	var target_angle := 0.0
	if not next.is_empty():
		var land_x: float = next.x1 + 130
		var land_y: float = world.terrain.surface_y(land_x)
		var ahead := world.terrain.surface_y(land_x + 30)
		target_angle = atan2(ahead - land_y, 30.0)
		if p.x > next.x0 - 70 and p.x < next.x1:
			var dy := land_y - 31 - p.y
			var g: float = PhysicsServer2D.area_get_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY)
			var t := (-v.y + sqrt(maxf(0.0, v.y * v.y + 2 * g * dy))) / g  # time to fall to the landing height
			# Keep burning until the ballistic arc lands past the gap AND clears the far lip.
			var t_lip: float = maxf(0.0, (next.x1 + 20 - p.x) / maxf(v.x, 1.0))
			var y_at_lip: float = p.y + v.y * t_lip + g * 0.5 * t_lip * t_lip
			var clears: bool = y_at_lip < next.land_y - 42 or p.x > next.x1
			fire = p.x + v.x * t < next.x1 + 130 or not clears or not bus.airborne
			if not clears and bus.airborne:
				target_angle = -0.3  # too low for the far lip: nose up so the rocket lifts
	if bus.airborne:
		var err := wrapf(c.rotation - target_angle, -PI, PI)
		right = -clampf(err * 2.0 + c.angular_velocity * 2.5, -1.0, 1.0)  # + = nose down
	bus.ai_input = {"right": right, "fire": fire and not "--norocket" in _args}
	if "--trace" in _args and Engine.get_physics_frames() % 6 == 0:
		print("TRACE x=%d y=%d rot=%.1f tgt=%.1f spin=%.2f air=%s fire=%s right=%.2f v=(%d,%d)" % [p.x, p.y,
				rad_to_deg(c.rotation), rad_to_deg(target_angle), c.angular_velocity, bus.airborne, fire, right, v.x, v.y])


func _bot_done(result: String, detail: String) -> void:
	if result == "FAILED" and not GameState.checkpoint.is_empty() and bot_retries < 2:
		bot_retries += 1
		print("BOT   %s retry %d from checkpoint (%s)" % [Levels.code(index), bot_retries, detail.get_slice(" ", 0)])
		await get_tree().create_timer(0.3).timeout
		get_tree().change_scene_to_file("res://scenes/level.tscn")
		return
	if bot_retries > 0:
		detail += " (checkpoint retries: %d)" % bot_retries
	bot_retries = 0
	GameState.checkpoint = {}
	if not _skip_intro:  # single showcase run: let the finish play out
		await get_tree().create_timer(3.5).timeout
	var line := "%s %-16s %s  %s" % [Levels.code(index), def.title, result, detail]
	print("BOT ", line)
	bot_report.append(line)
	var bot_end := Levels.count()
	for a in _args:  # --botend=N stops a --botall batch before level N
		if a.begins_with("--botend="):
			bot_end = int(a.substr(9))
	if "--botall" in _args and index + 1 < bot_end:
		GameState.current_level = index + 1
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree(): return
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	else:
		print("BOT REPORT\n  " + "\n  ".join(bot_report))
		get_tree().quit()


# --- HUD / panels -----------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_hud.layer = layer
	_label(layer, "%s %s" % [Levels.code(index), def.title], Vector2(8, 8), 8, Color("#ffcc26"), 2)
	_hud.gaps = _label(layer, "GAPS 0/%d" % world.terrain.gaps.size(), Vector2(8, 20), 8, Color("#3cf0dc"), 2)
	var minimap := Minimap.new().setup(world, bus)
	minimap.position = Vector2(156, 5)
	layer.add_child(minimap)
	_hud.time = _label(layer, "0.0", Vector2(0, 34), 8, Color.WHITE, 2)
	_hud.time.size.x = 480
	_hud.time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(layer, "FUEL", Vector2(364, 10), 8, Color("#ffcc26"), 2)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.04, 0.12, 0.8)
	back.position = Vector2(399, 9)
	back.size = Vector2(64, 10)
	layer.add_child(back)
	var fill := ColorRect.new()
	fill.color = Color("#ff4aa8")
	fill.position = Vector2(401, 11)
	fill.size = Vector2(60, 6)
	layer.add_child(fill)
	_hud.fuel = fill
	_hud.hint = _label(layer, "", Vector2(0, 238), 8, Color("#ffffff"), 2)
	_hud.hint.size.x = 480
	_hud.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(layer, "R RETRY   ESC PAUSE   H HORN", Vector2(0, 256), 8, Color(1, 1, 1, 0.45), 0).size.x = 480
	layer.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _hint(text: String) -> void:
	_hud.hint.text = text
	var tw := create_tween()
	_hud.hint.modulate.a = 1.0
	tw.tween_interval(4.0)
	tw.tween_property(_hud.hint, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): if _hud.hint.text == text: _hud.hint.text = "")


func _big_center(text: String, color: Color) -> void:
	var l := _label(_hud.layer, text, Vector2(0, 100), 32, color, 6)
	l.size.x = 480
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(240, 16)
	l.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.45)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _panel(title: String, color: Color) -> Control:
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.6)
	dim.size = Vector2(480, 270)
	root.add_child(dim)
	var box := ColorRect.new()
	box.color = Color(0.1, 0.05, 0.16, 0.95)
	box.position = Vector2(110, 46)
	box.size = Vector2(260, 178)
	root.add_child(box)
	var border := ReferenceRect.new()
	border.border_color = color
	border.border_width = 2
	border.editor_only = false
	border.position = box.position
	border.size = box.size
	root.add_child(border)
	var t := _label(root, title, Vector2(110, 56), 16, color, 4)
	t.size.x = 260
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_pause_panel.queue_free()
		return
	get_tree().paused = true
	Audio.play("ui_back", -6.0)
	_pause_panel = _panel("PAUSED", Color("#3cf0dc"))
	var entries := [["resume", "RESUME"]]
	if not GameState.checkpoint.is_empty():
		entries.append(["retry", "RETRY CHECKPOINT"])
	entries.append_array([["restart", "RESTART LEVEL"], ["menu", "QUIT TO MENU"]])
	_pause_menu = MenuList.new().setup(entries, 8, 16)
	_pause_menu.position = Vector2(240, 110)
	_pause_panel.add_child(_pause_menu)
	_pause_menu.chosen.connect(_on_menu_choice)


func _show_retry(reason: String) -> void:
	_end_panel = _panel(reason, Color("#ff3b4e"))
	var line := _label(_end_panel, "GAPS CLEARED %d/%d" % [cleared, world.terrain.gaps.size()], Vector2(110, 86), 8, Color.WHITE, 2)
	line.size.x = 260
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var has_cp := not GameState.checkpoint.is_empty()
	var entries := [["retry", "RETRY FROM CHECKPOINT" if has_cp else "TRY AGAIN"]]
	if has_cp:
		entries.append(["restart", "RESTART LEVEL"])
	entries.append(["menu", "MENU"])
	var menu := MenuList.new().setup(entries, 8, 16)
	menu.position = Vector2(240, 140)
	_end_panel.add_child(menu)
	menu.chosen.connect(_on_menu_choice)


func _set_score(v: int, label: Label) -> void:
	label.text = "SCORE %d" % v
	if v % 7 == 0:
		Audio.play("score_tick", -14.0)


func _on_menu_choice(id: String) -> void:
	if id != "resume":
		for m in get_tree().get_nodes_in_group("menus"):
			m.active = false
	match id:
		"resume":
			_toggle_pause()
		"next":
			GameState.current_level = index + 1
			Transition.go("res://scenes/level.tscn")
		"retry":  # from the last checkpoint, if there is one
			Transition.go("res://scenes/level.tscn")
		"restart":
			GameState.checkpoint = {}
			Transition.go("res://scenes/level.tscn")
		"menu":
			GameState.checkpoint = {}
			Transition.go("res://scenes/main_menu.tscn")


func _label(parent: Node, text: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(size, color, outline)
	parent.add_child(l)
	return l
