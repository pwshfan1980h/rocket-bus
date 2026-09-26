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
var _blocker_hinted := false
var _arrival := ""  # "", "drive", "brake": scripted roll-in before the countdown

static var bot_report: Array = []


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	for a in _args:
		if a.begins_with("--level=") and bot_report.is_empty():
			GameState.current_level = int(a.substr(8))
	_bot = "--bot" in _args or "--botall" in _args
	_skip_intro = "--botall" in _args
	index = GameState.current_level
	def = Levels.get_level(index)
	world = World.new().build(def.biome, def.segments)
	add_child(world)
	world.fuel_collected.connect(func(_c): if bus: bus.passengers.chatter(["YUM, GAS!", "REFUEL!", "GLUG GLUG"].pick_random(), "voice_happy"))
	world.life.birds_flushed.connect(_on_birds)
	var start := world.terrain.start_position()
	if _skip_intro:
		bus = world.spawn_bus(start, def.fuel)
	else:  # roll in from off-screen, then stop at the line
		bus = world.spawn_bus(start + Vector2(-560, 0), def.fuel, Vector2(260, 0))
		_anchor = Node2D.new()
		_anchor.position = start + Vector2(40, -10)
		add_child(_anchor)
		world.camera.target = _anchor
		world.camera.snap()
	bus.ammo = def.get("ammo", 3)
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
	if not _skip_intro:
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
	var card := _label(_hud.layer, "%s  %s" % [Levels.code(index), def.title], Vector2(0, 90), 16, Color("#ffcc26"), 4)
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
	if not _skip_intro:
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
	if state != State.PLAY or not is_instance_valid(bus) or bus.chassis == null:
		return
	clock += delta
	var c := bus.chassis
	var x := c.global_position.x
	_hud.time.text = "%d.%d" % [int(clock), int(fmod(clock, 1.0) * 10)]
	_hud.fuel.size.x = roundf(60 * bus.fuel_ratio())
	_hud.ammo.text = "AMMO %d" % bus.ammo
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
	if x > world.terrain.finish_x:
		_win()
		return
	if _bot:
		_bot_drive()
		if clock > 60.0:
			_bot_done("FAILED", "timeout: stuck at x=%d speed=%d" % [x, bus.get_speed()])
			state = State.FAILED
			return
	_tutorial(x)
	if not _bot:
		_blocker_hint(x)
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
		var back := bus.chassis.global_transform.x * -1.0
		bus.chassis.apply_central_impulse((back * 90.0 + Vector2(0, 60)) * bus.chassis.mass)
		bus.chassis.apply_torque_impulse(-2500.0)
		_teeter_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and state != State.INTRO:
		Transition.go("res://scenes/level.tscn")
	elif event.is_action_pressed("pause") and state == State.PLAY:
		_toggle_pause()


# --- Events -------------------------------------------------------------------

func _on_landed(grade: String, _impact: float, _angle: float) -> void:
	if state != State.PLAY:
		return
	landings.append(grade)
	var x := bus.chassis.global_position.x
	var now_cleared := 0
	for g in world.terrain.gaps:
		if x > g.x1:
			now_cleared += 1
	if now_cleared > cleared:
		cleared = now_cleared
		_hud.gaps.text = "GAPS %d/%d" % [cleared, world.terrain.gaps.size()]
		Audio.play("gap_cleared", -6.0)
		if index == 0 and _hint_step < 4:
			_hint_step = 4
			_hint("NICE!  NOW GET TO THE BUS STOP")


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


func _blocker_hint(x: float) -> void:
	for o in world.obstacles:
		if is_instance_valid(o) and o.is_blocker() and o.global_position.x > x and o.global_position.x - x < 420:
			if not _warned_gaps.has(o):
				_warned_gaps[o] = true
				if not _blocker_hinted:
					_blocker_hinted = true
					_hint("%s AHEAD!  PRESS F TO FIRE THE CANNON" % o.kind.to_upper())
				if randf() < 0.6:
					bus.passengers.exchange(["IS THAT A %s?!" % o.kind.to_upper(), "WATCH OUT!", "STOP THE BUS!"].pick_random(),
							["I SEE IT.", "HOLD MY COFFEE.", "CANNON TIME!"].pick_random())
			return


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


func _win() -> void:
	state = State.WON
	# The computer takes the wheel and drives off-screen while the camera pulls back.
	bus.ai_input = {"right": 0.9, "fire": false}
	world.camera.target = null
	world.camera.zoom_override = 0.72
	bus.passengers.react("perfect")
	bus.passengers.event("finish")
	Audio.play("level_clear", -2.0)
	Audio.play("cheer", -6.0)
	Audio.music("music_results")
	_big_center("BUS STOP!", Color("#ffcc26"))
	var fuel_left := bus.fuel
	var score := 0
	for g in landings:
		score += POINTS.get(g, 0)
	var par: float = world.terrain.finish_x / 230.0
	var time_bonus := maxi(0, int((par - clock) * 50))
	score += int(fuel_left * 10) + time_bonus
	var hard := landings.count("hard")
	var perfect := landings.count("perfect")
	var stars := 1 + int(hard == 0) + int(perfect * 2 >= maxi(1, landings.size()))
	if _bot:  # the tester bot must never touch the player's save
		_bot_done("WON", "fuel=%d landings=%s time=%.1f" % [fuel_left, landings, clock])
		return
	GameState.record(index, score, stars)
	await get_tree().create_timer(2.6).timeout
	if not is_inside_tree(): return
	_show_results(score, stars, fuel_left, time_bonus)


func _fail(kind: String, reason := "") -> void:
	if state != State.PLAY:
		return
	state = State.FAILED
	if _bot:
		_bot_done("FAILED", "%s %s at x=%d fuel=%d ammo=%d landings=%s" % [kind, reason, bus.chassis.global_position.x, bus.fuel, bus.ammo, landings])
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
			var t := (-v.y + sqrt(maxf(0.0, v.y * v.y + 2 * 700 * dy))) / 700.0  # time to fall to the landing height
			# Keep burning until the ballistic arc lands past the gap AND clears the far lip.
			var t_lip: float = maxf(0.0, (next.x1 + 20 - p.x) / maxf(v.x, 1.0))
			var y_at_lip: float = p.y + v.y * t_lip + 350.0 * t_lip * t_lip
			var clears: bool = y_at_lip < next.land_y - 42 or p.x > next.x1
			fire = p.x + v.x * t < next.x1 + 130 or not clears or not bus.airborne
	if bus.airborne:
		var err := wrapf(c.rotation - target_angle, -PI, PI)
		right = -clampf(err * 2.0 + c.angular_velocity * 2.5, -1.0, 1.0)  # + = nose down
	var shoot := false
	for o in world.obstacles:  # blast blockers in the way
		if is_instance_valid(o) and (o.is_blocker() or o.kind == "barrel"):
			var ahead: float = o.global_position.x - p.x
			if ahead > 0 and ahead < 420 and not bus.airborne:
				shoot = true
	bus.ai_input = {"right": right, "fire": fire and not "--norocket" in _args, "shoot": shoot}
	if "--trace" in _args and Engine.get_physics_frames() % 6 == 0:
		print("TRACE x=%d y=%d rot=%.1f tgt=%.1f spin=%.2f air=%s fire=%s right=%.2f v=(%d,%d)" % [p.x, p.y,
				rad_to_deg(c.rotation), rad_to_deg(target_angle), c.angular_velocity, bus.airborne, fire, right, v.x, v.y])


func _bot_done(result: String, detail: String) -> void:
	if not _skip_intro:  # single showcase run: let the finish play out
		await get_tree().create_timer(3.5).timeout
	var line := "%s %-16s %s  %s" % [Levels.code(index), def.title, result, detail]
	print("BOT ", line)
	bot_report.append(line)
	if "--botall" in _args and index + 1 < Levels.count():
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
	minimap.position = Vector2(138, 5)
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
	_hud.ammo = _label(layer, "AMMO %d" % bus.ammo, Vector2(364, 22), 8, Color("#b8e060"), 2)
	_hud.hint = _label(layer, "", Vector2(0, 238), 8, Color("#ffffff"), 2)
	_hud.hint.size.x = 480
	_hud.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(layer, "F CANNON   R RETRY   ESC PAUSE   H HORN", Vector2(0, 256), 8, Color(1, 1, 1, 0.45), 0).size.x = 480
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
	_pause_menu = MenuList.new().setup([["resume", "RESUME"], ["retry", "RESTART"], ["menu", "QUIT TO MENU"]], 8, 18)
	_pause_menu.position = Vector2(240, 110)
	_pause_panel.add_child(_pause_menu)
	_pause_menu.chosen.connect(_on_menu_choice)


func _show_retry(reason: String) -> void:
	_end_panel = _panel(reason, Color("#ff3b4e"))
	var line := _label(_end_panel, "GAPS CLEARED %d/%d" % [cleared, world.terrain.gaps.size()], Vector2(110, 86), 8, Color.WHITE, 2)
	line.size.x = 260
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menu := MenuList.new().setup([["retry", "TRY AGAIN"], ["menu", "MENU"]], 8, 18)
	menu.position = Vector2(240, 140)
	_end_panel.add_child(menu)
	menu.chosen.connect(_on_menu_choice)


func _show_results(score: int, stars: int, fuel_left: float, time_bonus: int) -> void:
	_end_panel = _panel("BUS STOP!", Color("#ffcc26"))
	var rows := [
		["TIME", "%.1fs" % clock],
		["LANDINGS", "%dP %dG %dH" % [landings.count("perfect"), landings.count("good"), landings.count("hard")]],
		["FUEL LEFT", "%d%%" % int(fuel_left / bus.fuel_capacity * 100)],
		["TIME BONUS", str(time_bonus)],
	]
	for i in rows.size():
		_label(_end_panel, rows[i][0], Vector2(126, 84 + i * 12), 8, Color("#d8f8ff"), 2)
		var v := _label(_end_panel, rows[i][1], Vector2(250, 84 + i * 12), 8, Color.WHITE, 2)
		v.size.x = 104
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var score_l := _label(_end_panel, "SCORE 0", Vector2(110, 136), 16, Color("#7dff6a"), 4)
	score_l.size.x = 260
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_method(_set_score.bind(score_l), 0, score, 1.0)
	for i in 3:
		var star := _label(_end_panel, "*", Vector2(196 + i * 32, 158), 16, Color("#ffcc26") if i < stars else Color(1, 1, 1, 0.2), 4)
		star.pivot_offset = Vector2(8, 8)
		star.scale = Vector2.ZERO
		tw.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		if i < stars:
			tw.tween_callback(Audio.play.bind("star", -4.0, 1.0 + i * 0.12))
	var last := index + 1 >= Levels.count()
	var entries := [["next", "NEXT LEVEL"], ["retry", "RETRY"], ["menu", "MENU"]]
	if last:
		entries = [["menu", "YOU BEAT THE GAME!"], ["retry", "RETRY"]]
	var menu := MenuList.new().setup(entries, 8, 13)
	menu.position = Vector2(240, 180)
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
		"retry":
			Transition.go("res://scenes/level.tscn")
		"menu":
			Transition.go("res://scenes/main_menu.tscn")


func _label(parent: Node, text: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.label_settings = PixelFont.settings(size, color, outline)
	parent.add_child(l)
	return l
