extends Node2D
## Plays GameState.current_level: title card, countdown, the run, and the
## results or retry screen.
## Story legs (GameState.story_mode) add jobs on top: see StoryRun.
## User args: --level=N (start at N)  --bot (autopilot)  --botall (bot plays every level, prints a report)
##            --story=ID (play a story leg)  --botstory (bot plays every story leg)
## (Always test at normal speed: raising time_scale enlarges physics steps and changes outcomes.)

enum State { INTRO, PLAY, WON, FAILED }

const FAIL_TEXT := {
	"chasm": "FELL IN!", "water": "SPLASHDOWN!", "swamp": "SWAMPED!", "ice": "ON THIN ICE!",
	"lava": "TOASTED!", "crash": "WRECKED!", "cargo": "LOST THE CARGO!", "mudslide": "BURIED IN MUD!",
	"missed": "MISSED A STOP!",
}
const POINTS := {"perfect": 1000, "good": 500, "hard": 150}
const FRONT_FLIP_POINTS := 2000  ## per front flip stuck (+half again for a perfect landing)
const BACKFLIP_POINTS := 750
const FULL_BUS_POINTS := 1500  ## nobody walked off
const OVERTIME_PER_FUEL := 25  ## leftover fuel turns into points at the finish
const BONKS_TO_LEAVE := 3

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
var _low_fuel := 1.0  ## lowest fuel share this run (the bot reports it, for tuning)
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
var _rush: Control  ## speed lines at the screen edges when the bus is flying along
var _rush_amount := 0.0
var _leaving: Array[Dictionary] = []  ## riders fed up with the bonks: off at the next stop
var _ghost_run := PackedFloat32Array()
var _recording := false
var _max_x := -INF
var _story: StoryRun  ## story-leg jobs (null in arcade levels)
var _story_id := ""
var _walked := 0  ## riders who quit during this run
var _finish_blocked := ""


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	for a in _args:
		if a.begins_with("--level=") and bot_report.is_empty():
			GameState.current_level = int(a.substr(8))
	_bot = "--bot" in _args or "--botall" in _args or "--botstory" in _args
	if _bot and bot_retries == 0:
		GameState.checkpoint = {}
	_skip_intro = "--botall" in _args or "--botstory" in _args
	for a in _args:
		if a.begins_with("--story="):
			GameState.story_mode = true
			if GameState.story.is_empty():
				GameState.new_story()
			GameState.story.at = a.substr(8)
	if "--botstory" in _args:
		GameState.story_mode = true
		if GameState.story.is_empty():
			GameState.new_story()
			GameState.story.at = Story.ids()[0]
	index = GameState.current_level
	if GameState.story_mode:
		_story_id = GameState.story.at
		def = Story.leg(_story_id)
	else:
		def = Levels.get_level(index)
	if str(GameState.checkpoint.get("level", "")) == _level_key():
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
	if _story_id != "":
		_story = StoryRun.new().setup(self, def)
		add_child(_story)
	_recording = _resume.is_empty() and not _bot
	if not _bot:
		_spawn_ghost()
	world.start_ambience()
	_build_hud()
	if _story:
		_story.build_hud(_hud.layer)
		_hud_lives()
	_update_riders()
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
	if _story and _resume.is_empty() and not _skip_intro:
		await _radio(def.radio)
		if not is_inside_tree(): return
	var card_text := "%s  %s" % [_code(), def.title]
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
	if _story:
		_story.start()
	if index == 0 and not _bot and not _story:
		_hint("HOLD  D / RIGHT  TO DRIVE")


func _physics_process(delta: float) -> void:
	if _arrival != "" and is_instance_valid(bus):
		_drive_in()
	if _comet and is_instance_valid(bus):
		_comet_step(delta)
	if state != State.PLAY or not is_instance_valid(bus) or bus.chassis == null:
		return
	_low_fuel = minf(_low_fuel, bus.fuel / bus.fuel_capacity)
	clock += delta
	var c := bus.chassis
	var x := c.global_position.x
	_max_x = maxf(_max_x, x)
	while _recording and _ghost_run.size() / Ghost.STRIDE <= int(clock * Ghost.RATE):
		Ghost.sample(bus, _ghost_run)
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
	if _story:
		var why := _story.step(delta)
		if why != "":
			_fail(why)
			return
	if x > world.terrain.finish_x and _story:
		var block := _story.finish_block()
		if block == "missed":
			_fail("missed")
			return
		if block != "":
			if _finish_blocked != block:
				_finish_blocked = block
				_hint(block)
			x = world.terrain.finish_x - 1.0  # not over the line until the job's done
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
		if _story:
			var take := _story.bot_input()
			if not take.is_empty():
				bus.ai_input = take
		if clock > 240.0:
			_bot_done("FAILED", "timeout: stuck at x=%d speed=%d" % [x, bus.get_speed()])
			state = State.FAILED
			return
	_tutorial(x)
	_chatter(delta, x)
	_rush_amount = lerpf(_rush_amount, clampf((c.linear_velocity.length() - 380.0) / 220.0, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	_rush.queue_redraw()
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
		if _story and GameState.story.lives <= 0:
			return  # out of lives: the only way is back to the depot
		if _story and state == State.PLAY:
			_spend_life_and_restart()
			return
		Transition.go("res://scenes/level.tscn")
	elif event.is_action_pressed("pause") and state == State.PLAY:
		_toggle_pause()
	elif event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		var z := GameState.step_zoom(1 if event.is_action_pressed("zoom_in") else -1)
		_hint("VIEW %d%%   ( - / = )" % roundi(100.0 / z))


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
	GameState.checkpoint = {"level": _level_key(), "x": cx, "fuel": bus.fuel, "clock": clock,
		"landings": landings.duplicate(), "cleared": cleared, "retries": _retries, "style": _style.duplicate(),
		"flip_points": _flip_points}
	Audio.play("star", -4.0)
	_let_off_leavers()
	Fx.float_text(bus.chassis.global_position + Vector2(0, -60), "CHECKPOINT!", Color("#3cf0dc"), 16)
	bus.passengers.driver_say(["HALFWAY THERE!", "KEEP IT TOGETHER!", "STILL IN ONE PIECE!"].pick_random())


func _on_landed(grade: String, _impact: float, _angle: float) -> void:
	if state != State.PLAY:
		return
	landings.append(grade)
	_cash_flips(grade)
	if _story:
		_story.on_landed(grade)
	if grade == "hard":
		var r := bus.passengers.bonk_someone()
		if not r.is_empty() and r.bonks >= BONKS_TO_LEAVE and not r in _leaving:
			_leaving.append(r)
			_hint("A RIDER IS GETTING OFF AT THE NEXT STOP!")
		_update_riders()
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
		if index == 0 and _hint_step < 4 and not _story:
			_hint_step = 4
			_hint("NICE!  NOW GET TO THE BUS STOP")


## Landed in one piece after flipping: front flips get the full fanfare.
func _cash_flips(grade: String) -> void:
	var front: int = _jump_flips.front
	var back: int = _jump_flips.back
	_jump_flips = {"front": 0, "back": 0}
	if _story:
		_story.on_jump(front, back, _air_now)
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
	if _recording:
		Ghost.offer(_level_key(), _ghost_run, 1e6 - clock if state == State.WON else _max_x)


## Which field-guide page F1 opens on, from what's happening right now.
func help_topic() -> String:
	if not is_instance_valid(bus) or bus.chassis == null:
		return "basics"
	if _story:
		if _story.trailer and not _story.trailer.attached:
			return "towing"
		var x := bus.chassis.global_position.x
		for st in world.terrain.stops:
			if not st.done and x > st.x0 - 900.0 and x < st.x1 + 200.0:
				return "stops"
		if state == State.INTRO:
			return "story"
	if bus.airborne:
		return "air" if bus.fuel > 0.0 else "landing"
	var next := world.terrain.gap_at(bus.chassis.global_position.x + 500.0)
	if not next.is_empty():
		return "rocket"
	return "story" if _story else "basics"


## Retrying: race a see-through replay of your best attempt this session.
func _spawn_ghost() -> void:
	if not Ghost.best.has(_level_key()):
		return
	var ghost := Ghost.new()
	ghost.frames = Ghost.best[_level_key()].frames
	ghost.clock_ref = func(): return clock
	world.add_child(ghost)
	world.move_child(ghost, bus.get_index())


## Identifies this level (ghosts, checkpoints).
func _level_key() -> String:
	return "story:" + _story_id if _story_id != "" else str(index)


func _code() -> String:
	return "STORY" if _story_id != "" else Levels.code(index)


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
		if r.get("kicker", false):
			continue
		if not _warned_gaps.has(r.x0) and x > r.x0 - 260 and x < r.x0:
			_warned_gaps[r.x0] = true
			if randf() < 0.6:
				bus.passengers.exchange(["IS THAT A GAP?!", "UH... DRIVER?", "WE'RE NOT STOPPING?!",
						"THE ROAD ENDS!"].pick_random(), bus.passengers.DRIVER_LINES.gap.pick_random())


func _tutorial(x: float) -> void:
	if index != 0 or _bot or _story:
		return
	var ramp: Dictionary = world.terrain.ramps[0]
	if _hint_step == 0 and x > ramp.x0 - 320:
		_hint_step = 1
		_hint("RAMP AHEAD!  HOLD SHIFT FOR ROCKET")
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
	_let_off_leavers()
	var report := _finish_report(comet)
	if _story:
		_story.unload_all()
	_overtime(report.overtime)
	GameState.checkpoint = {}
	if _story and not _bot:
		_story_cleared(report)
	var showcase := "--showcase" in _args  # bot plays the real ending, nothing is saved
	if _bot and not showcase:  # the tester bot must never touch the player's save
		_bot_done("WON", "grade=%s spd=%d tech=%d fuel=%d low=%d%% landings=%s time=%.1f par=%.0f%s" % [report.grade,
				report.speed, report.technique, bus.fuel, _low_fuel * 100.0, landings, clock, report.par, " COMET" if comet else ""])
		return
	if not _bot and not _story:
		GameState.record(index, report.score, report.stars, report.grade)
	if comet:
		_start_comet()
	else:
		# The computer takes the wheel and drives off-screen while the camera pulls back.
		bus.ai_input = {"right": 0.9, "fire": false}
		world.camera.target = null
		world.camera.zoom_override = 0.72 * GameState.view_zoom
		Audio.music("music_results")
		_big_center("BUS STOP!", Color("#ffcc26"))
	await get_tree().create_timer(3.4 if comet else 2.6).timeout
	if not is_inside_tree(): return
	_freeze_and_report(report)


func _finish_report(comet: bool) -> Dictionary:
	var par := Grading.par_time(world.terrain.finish_x)
	if _story:  # stopping for people and towing take time
		par += 4.0 * world.terrain.stops.size() + (6.0 if _story.trailer else 0.0)
	var speed := Grading.speed_stars(clock, par)
	var tech := Grading.technique_stars(landings, _retries, _style)
	var bonus := Grading.style_bonus(_style)
	var grade := Grading.grade(speed, tech, bonus, comet, _retries)
	var score := 0
	for g in landings:
		score += POINTS.get(g, 0)
	var overtime := int(bus.fuel * OVERTIME_PER_FUEL)
	if _story:
		score += _story.tips()
	var full := bus.passengers.aboard_count() >= bus.passengers.seat_count()
	score += overtime + maxi(0, int((par - clock) * 50)) + (FULL_BUS_POINTS if full else 0)
	score += _flip_points + _style.close * 400 + int(_style.air * 100) + (2500 if comet else 0)
	return {
		"code": _code(), "title": def.title, "time": clock, "par": par, "landings": landings.duplicate(),
		"style": _style.duplicate(), "fuel_pct": int(bus.fuel / bus.fuel_capacity * 100), "retries": _retries,
		"speed": speed, "technique": tech, "grade": grade, "score": score, "comet": comet,
		"stars": int(round((speed + tech) / 2.0)), "last": index + 1 >= Levels.count(), "story": _story != null,
		"overtime": overtime, "full_bus": full,
		"riders": "%d/%d" % [bus.passengers.aboard_count(), bus.passengers.seat_count()],
	}


## The bus keeps sailing like a comet: no gravity, climbing, heating up red-hot.
func _start_comet() -> void:
	_comet = true
	if _story and _story.trailer:  # the trailer rides the comet too
		for b in [_story.trailer.body, _story.trailer.wheel]:
			b.gravity_scale = 0.0
			b.collision_mask = 0
	for b in [bus.chassis] + Array(bus.wheels):
		b.gravity_scale = 0.0
		b.collision_mask = 0
	bus.ai_input = {"right": 0.0, "fire": false}
	bus._set_flames(true)
	world.camera.zoom_override = 0.6 * GameState.view_zoom
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


## Streaks in the top and bottom of the screen; denser and brighter the faster you go.
func _draw_rush() -> void:
	if _rush_amount < 0.02:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for i in int(6 + 14 * _rush_amount):
		var band := fmod(i * 53.0, 70.0)
		var y := band + 40.0 if i % 2 == 0 else 270.0 - band - 20.0
		var x := fposmod(480.0 - (t * 1100.0 + i * 167.0), 600.0) - 60
		_rush.draw_line(Vector2(x, y), Vector2(x + 24 + (i % 4) * 12, y), Color(1, 1, 1, 0.22 * _rush_amount), 1.0)


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
	if _story and not _bot:
		GameState.story.lives -= 1
		_hud_lives()
	if _bot:
		_bot_done("FAILED", "%s %s at x=%d fuel=%d low=%d%% landings=%s" % [kind, reason, bus.chassis.global_position.x, bus.fuel,
				_low_fuel * 100.0, landings])
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
	if result == "FAILED" and not GameState.checkpoint.is_empty() and bot_retries < 2 and not _story:
		bot_retries += 1
		print("BOT   %s retry %d from checkpoint (%s)" % [_code(), bot_retries, detail.get_slice(" ", 0)])
		await get_tree().create_timer(0.3).timeout
		get_tree().change_scene_to_file("res://scenes/level.tscn")
		return
	if bot_retries > 0:
		detail += " (checkpoint retries: %d)" % bot_retries
	bot_retries = 0
	GameState.checkpoint = {}
	if not _skip_intro:  # single showcase run: let the finish play out
		await get_tree().create_timer(3.5).timeout
	var line := "%s %-16s %s  %s" % [_code(), def.title, result, detail]
	print("BOT ", line)
	bot_report.append(line)
	var bot_end := Levels.count()
	for a in _args:  # --botend=N stops a --botall batch before level N
		if a.begins_with("--botend="):
			bot_end = int(a.substr(9))
	var legs := Story.ids()
	if "--botstory" in _args and legs.find(_story_id) + 1 < legs.size():
		GameState.story.at = legs[legs.find(_story_id) + 1]
		await get_tree().create_timer(0.3).timeout
		if not is_inside_tree(): return
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	elif "--botall" in _args and index + 1 < bot_end:
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
	_label(layer, def.title if _story_id != "" else "%s %s" % [_code(), def.title], Vector2(8, 8), 8, Color("#ffcc26"), 2)
	_hud.gaps = _label(layer, "GAPS 0/%d" % world.terrain.gaps.size(), Vector2(8, 20), 8, Color("#3cf0dc"), 2)
	_rush = Control.new()
	_rush.size = Vector2(480, 270)
	_rush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush.draw.connect(_draw_rush)
	layer.add_child(_rush)
	var minimap := Minimap.new().setup(world, bus)
	minimap.story = _story
	minimap.position = Vector2(156, 5)
	layer.add_child(minimap)
	_hud.riders = _label(layer, "", Vector2(8, 32), 8, Color("#ff9ad2"), 2)
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
	_label(layer, "R RETRY   ESC PAUSE   H HORN   F1 HELP", Vector2(0, 256), 8, Color(1, 1, 1, 0.45), 0).size.x = 480
	layer.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _update_riders() -> void:
	var p := bus.passengers
	_hud.riders.text = "RIDERS %d/%d" % [p.aboard_count(), p.seat_count()]
	if not _leaving.is_empty():
		_hud.riders.text += "  (%d LEAVING)" % _leaving.size()


## Riders who've had enough bonks get off here and stomp away.
func _let_off_leavers() -> void:
	for r in _leaving:
		if r.aboard:
			_walked += 1
			_walk_off(r, ["I'M WALKING!", "HMPH!", "NEVER AGAIN!", "MY NECK!"].pick_random())
	_leaving.clear()
	_update_riders()


## A rider leaves the bus through the door and walks off (back the way we came).
func _walk_off(r: Dictionary, line: String) -> void:
	var src: Sprite2D = r.sprite
	var walker := Sprite2D.new()
	walker.texture = src.texture
	walker.hframes = src.hframes
	walker.vframes = src.vframes
	walker.frame = src.frame
	walker.flip_h = true
	walker.global_position = bus.chassis.to_global(Vector2(6, 4))
	world.add_child(walker)
	bus.passengers.set_aboard(r, false)
	Fx.float_text(walker.global_position + Vector2(0, -12), line, BusPassengers.SHIRTS[r.row].lightened(0.25))
	var ground := world.terrain.surface_y(walker.global_position.x - 40)
	if is_nan(ground):
		ground = walker.global_position.y + 20
	var tw := walker.create_tween()
	tw.tween_property(walker, "global_position", Vector2(walker.global_position.x - 20, ground - 6), 0.35)
	for k in 6:  # stomp, stomp
		tw.tween_property(walker, "global_position:x", walker.global_position.x - 34 - k * 10, 0.18)
		tw.parallel().tween_property(walker, "rotation", 0.15 if k % 2 == 0 else -0.15, 0.18)
	tw.tween_property(walker, "modulate:a", 0.0, 0.4)
	tw.tween_callback(walker.queue_free)


## Leftover fuel drains out of the gauge into the score.
func _overtime(points: int) -> void:
	if points <= 0 or _bot:
		return
	var l := _label(_hud.layer, "OVERTIME +0", Vector2(330, 22), 8, Color("#7dff6a"), 2)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_hud.fuel, "size:x", 0.0, 1.2)
	tw.parallel().tween_method(func(v: int):
		l.text = "OVERTIME +%d" % v
		if v % 9 == 0:
			Audio.play("score_tick", -14.0), 0, points, 1.2)
	tw.tween_callback(Audio.play.bind("cha_ching", -6.0))


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
	if Help.is_open():
		return
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
	if _story:
		entries.append_array([["restart", "RESTART LEG (-1 LIFE)"], ["quit_run", "QUIT RUN"]])
	else:
		entries.append_array([["restart", "RESTART LEVEL"], ["menu", "QUIT TO MENU"]])
	_pause_menu = MenuList.new().setup(entries, 8, 16)
	_pause_menu.position = Vector2(240, 110)
	_pause_panel.add_child(_pause_menu)
	_pause_menu.chosen.connect(_on_menu_choice)


func _show_retry(reason: String) -> void:
	if _story:
		_show_story_retry(reason)
		return
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
		"quit_run":  # leaving a story run ends it (no saves)
			GameState.story = {}
			GameState.story_mode = false
			GameState.checkpoint = {}
			Transition.go("res://scenes/main_menu.tscn")
		"next":
			GameState.current_level = index + 1
			Transition.go("res://scenes/level.tscn")
		"retry":  # from the last checkpoint, if there is one
			if _story and state == State.PLAY:
				_spend_life_and_restart()
				return
			Transition.go("res://scenes/level.tscn")
		"restart":
			GameState.checkpoint = {}
			if _story and state == State.PLAY:
				_spend_life_and_restart()
				return
			Transition.go("res://scenes/level.tscn")
		"menu":
			GameState.checkpoint = {}
			Transition.go("res://scenes/story_map.tscn" if _story else "res://scenes/main_menu.tscn")
		"story_next":
			GameState.checkpoint = {}
			Transition.go("res://scenes/story_map.tscn")
		"give_up":
			GameState.story.over = "dead"
			GameState.checkpoint = {}
			Transition.go("res://scenes/story_map.tscn")


func _label(parent: Node, text: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(size, color, outline)
	parent.add_child(l)
	return l


# --- Story ------------------------------------------------------------------------

## Dispatch radio card: the leg's briefing typed out line by line. Any key skips.
func _radio(lines: Array) -> void:
	var box := ColorRect.new()
	box.color = Color(0.05, 0.03, 0.09, 0.9)
	box.position = Vector2(60, 70)
	box.size = Vector2(360, 96)
	_hud.layer.add_child(box)
	var head := _label(box, "DISPATCH  -  %s" % def.title, Vector2(8, 8), 8, Color("#ff4aa8"), 0)
	head.size.x = 344
	var body := _label(box, "", Vector2(8, 26), 8, Color("#d8f8ff"), 0)
	body.size = Vector2(344, 64)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.label_settings.line_spacing = 4
	var text := "\n".join(lines)
	for i in text.length():
		body.text = text.substr(0, i + 1)
		if i % 3 == 0:
			Audio.play("typewriter", -14.0, randf_range(0.95, 1.05))
		await get_tree().create_timer(0.025).timeout
		if not is_inside_tree(): return
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		box.queue_free()


## Bailing out of a leg mid-run costs a life, like crashing would.
func _spend_life_and_restart() -> void:
	get_tree().paused = false
	GameState.story.lives -= 1
	if GameState.story.lives <= 0:
		GameState.story.over = "dead"
		Transition.go("res://scenes/story_map.tscn")
	else:
		Transition.go("res://scenes/level.tscn")


func _hud_lives() -> void:
	if not _hud.has("lives"):
		_hud.lives = _label(_hud.layer, "", Vector2(364, 22), 8, Color("#ff5a78"), 2)
	_hud.lives.text = "LIVES %d/%d" % [maxi(0, GameState.story.lives), Story.LIVES]
	if GameState.story.lives <= 0:
		_hud.lives.text = "NO LIVES LEFT"


## Bank a cleared leg into the run: score, riders who walked, a life for S grades.
func _story_cleared(report: Dictionary) -> void:
	var run: Dictionary = GameState.story
	run.path.append(_story_id)
	run.score += report.score
	run.walked += _walked
	run.lost_cargo += _story.lost_cargo
	if report.grade in ["S", "SS"] and run.lives < Story.LIVES:
		run.lives += 1
		Fx.float_text(bus.chassis.global_position + Vector2(0, -90), "+1 LIFE", Color("#ff5a78"), 16)
	var next: Array = def.next
	if next.is_empty():
		run.over = "won"
	elif next.size() == 1:
		run.at = next[0]
	else:
		run.at = ""  # a fork: the story map asks which way


func _show_story_retry(reason: String) -> void:
	var lives: int = GameState.story.lives
	_end_panel = _panel(reason, Color("#ff3b4e"))
	var line := _label(_end_panel, "LIVES LEFT: %d" % lives if lives > 0 else "OUT OF LIVES. THE RUN IS OVER.",
			Vector2(110, 86), 8, Color("#ff5a78"), 2)
	line.size.x = 260
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var entries := []
	if lives > 0:
		var has_cp := not GameState.checkpoint.is_empty()
		entries.append(["retry", "RETRY FROM CHECKPOINT" if has_cp else "TRY AGAIN"])
		if has_cp:
			entries.append(["restart", "RESTART LEG"])
		entries.append(["give_up", "GIVE UP THE ROUTE"])
	else:
		entries.append(["give_up", "BACK TO THE DEPOT"])
	var menu := MenuList.new().setup(entries, 8, 16)
	menu.position = Vector2(240, 130)
	_end_panel.add_child(menu)
	menu.chosen.connect(_on_menu_choice)
