class_name Life
extends Node2D
## Everything alive (or drifting) in a level. It reacts to the bus: perched
## birds burst into a flock, bugs scatter, lizards bolt, tumbleweeds get smacked,
## trees shed leaves, and the wheels kick up dust. Only things near the camera
## are simulated. Glowing particles are drawn on `glow` (outside the night tint).

signal birds_flushed(count: int)

const BIRD_COLORS := {
	"DESERT": ["#2a2030", "#3a2a3a"], "JUNGLE": ["#e03a3a", "#3ac04a", "#3a7ae0", "#f0c030"],
	"MOUNTAINS": ["#3a3040", "#5a4a50"], "SNOW": ["#e8eef8", "#2a2a34"], "VOLCANO": ["#1a1010"],
	"BAY CITY": ["#8a8a9a", "#6a6a7a"],
}
## Half-size of the area around the camera that's simulated/drawn (fits the widest zoom).
const VIEW := Vector2(470, 270)
const DUST_COLORS := {
	"DESERT": "#e0b888", "JUNGLE": "#6a4a2a", "MOUNTAINS": "#a0a0a8", "SNOW": "#ffffff",
	"VOLCANO": "#3a3030", "BAY CITY": "#8a8a8a",
}

var terrain: Terrain
var props: Props
var bus: Bus
var glow: Node2D

var _kinds: Array = []
var _title := ""
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _birds: Array[Dictionary] = []
var _flock_seq := 0
var _flock_timer := 3.0
var _swarms: Array[Dictionary] = []
var _butterflies: Array[Dictionary] = []
var _lizards: Array[Dictionary] = []
var _tumbles: Array[Dictionary] = []
var _tumble_timer := 1.0
var _leaves: Array[Dictionary] = []
var _tree_cd := {}
var _puffs: Array[Dictionary] = []
var _puff_timer := 0.0
var _flakes: Array[Dictionary] = []  # snow, ash, embers, motes, fireflies
var _flap_cd := 0.0
var _buzz: AudioStreamPlayer2D
var _cam := Vector2.ZERO
## Bigger animals: vultures, bats (flying) and snakes, goats, penguins, monkeys.
var _critters: Array[Dictionary] = []
var _critter_cd := 0.0


func setup(t: Terrain, p: Props, glow_node: Node2D) -> Life:
	terrain = t
	props = p
	glow = glow_node
	return self


func _ready() -> void:
	_rng.seed = 99
	_kinds = terrain.biome.life
	_title = terrain.biome.title
	glow.draw.connect(_draw_glow)
	if "perched" in _kinds:
		for perch in props.perches:
			if _rng.randf() < 0.6:
				_add_bird(perch + Vector2(_rng.randf_range(-3, 3), 0), true)
	var x := 200.0
	while x < terrain.end_x:
		var gy := terrain.ground_y(x)
		if not is_nan(gy):
			if ("bugs" in _kinds or "flies" in _kinds) and _rng.randf() < 0.5:
				_add_swarm(Vector2(x, gy - _rng.randf_range(16, 40)))
			if "lizards" in _kinds and _rng.randf() < 0.45:
				_lizards.append({"p": Vector2(x, gy), "state": "idle", "t": _rng.randf() * 3,
					"dir": 1.0 if _rng.randf() < 0.5 else -1.0, "alpha": 1.0})
		x += _rng.randf_range(220, 420)
	if "bugs" in _kinds or "flies" in _kinds:
		_buzz = AudioStreamPlayer2D.new()
		_buzz.stream = Audio.stream("bug_buzz_loop")
		_buzz.bus = "SFX"
		_buzz.volume_db = -14.0
		_buzz.max_distance = 260.0
		add_child(_buzz)
		_buzz.play()
	for kind in ["snow", "ash", "embers", "dust", "fireflies", "spores"]:
		if kind in _kinds:
			var n: int = {"snow": 140, "ash": 60, "embers": 50, "dust": 40, "fireflies": 24, "spores": 70}[kind]
			for i in n:
				_flakes.append({"kind": kind, "p": Vector2(_rng.randf_range(-VIEW.x, VIEW.x), _rng.randf_range(-VIEW.y, VIEW.y)),
					"s": _rng.randf_range(0.5, 1.0), "ph": _rng.randf() * TAU})
	_spawn_critters()
	if "butterflies" in _kinds:
		for i in 6:
			_butterflies.append({"p": Vector2(_rng.randf_range(0, 600), -40), "v": Vector2.ZERO,
				"c": Color.from_hsv(_rng.randf(), 0.7, 1.0), "ph": _rng.randf() * TAU})


func _physics_process(delta: float) -> void:
	_time += delta
	_flap_cd -= delta
	var cam := get_viewport().get_camera_2d()
	if cam:
		_cam = cam.get_screen_center_position()
	var bp := Vector2(INF, INF)
	var bv := Vector2.ZERO
	var grounded := false
	if is_instance_valid(bus) and bus.chassis and bus.in_hazard == "":
		bp = bus.chassis.global_position
		bv = bus.chassis.linear_velocity
		grounded = not bus.airborne and not bus.is_crashed
	_update_birds(delta, bp, bv)
	_update_swarms(delta, bp)
	_update_butterflies(delta, bp)
	_update_lizards(delta, bp)
	if "tumbleweeds" in _kinds:
		_update_tumbles(delta, bp, bv)
	if "leaves" in _kinds:
		_update_leaves(delta, bp)
	_update_puffs(delta, grounded, bv)
	_update_flakes(delta)
	_update_critters(delta, bp, bv)
	queue_redraw()
	glow.queue_redraw()


# --- Birds ----------------------------------------------------------------------

func _add_bird(at: Vector2, perched: bool, flock := -1, vel := Vector2.ZERO) -> void:
	var palette: Array = BIRD_COLORS.get(_title, BIRD_COLORS.DESERT)
	_birds.append({"p": at, "v": vel, "perched": perched, "flock": flock, "t": _rng.randf() * 10,
		"c": Color(palette[_rng.randi() % palette.size()]), "hop": 0.0})


func _update_birds(delta: float, bp: Vector2, bv: Vector2) -> void:
	if "birds" in _kinds:
		_flock_timer -= delta
		if _flock_timer <= 0.0:
			_flock_timer = _rng.randf_range(6, 12)
			_flock_seq += 1
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			var start := _cam + Vector2(-(VIEW.x + 40) * dir, _rng.randf_range(-120, -70))
			for i in _rng.randi_range(5, 10):
				_add_bird(start + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-15, 15)), false,
						_flock_seq, Vector2(dir * 90, 0))
	var flushed := 0
	for b in _birds:
		b.t += delta
		if b.perched:
			if b.p.distance_to(bp) < 170:
				b.perched = false
				b.flock = -1000 - int(b.p.x / 200)  # birds flushed together flock together
				b.v = Vector2(signf(b.p.x - bp.x + 0.1) * _rng.randf_range(40, 90) + bv.x * 0.3,
						_rng.randf_range(-190, -130))
				flushed += 1
			elif _rng.randf() < delta * 0.3:
				b.hop = 0.15
			b.hop = maxf(0.0, b.hop - delta)
			continue
		var sep := Vector2.ZERO
		var align := Vector2.ZERO
		var center := Vector2.ZERO
		var n := 0
		for o in _birds:
			if o == b or o.perched or o.flock != b.flock:
				continue
			var d: Vector2 = b.p - o.p
			var dist := d.length()
			if dist < 50:
				n += 1
				align += o.v
				center += o.p
				if dist < 10 and dist > 0.01:
					sep += d / dist * (10 - dist)
		var acc := Vector2(sin(b.t * 1.3 + b.p.x) * 20, cos(b.t * 1.7) * 12)
		if n > 0:
			acc += (align / n - b.v) * 1.2 + (center / n - b.p) * 0.8 + sep * 12.0
		if b.flock < 0:
			acc.y -= 60  # fleeing birds climb
		if b.p.distance_to(bp) < 90:
			acc += (b.p - bp).normalized() * 300
		b.v = (b.v + acc * delta).limit_length(150)
		if b.v.length() < 60:
			b.v = b.v.normalized() * 60
		b.p += b.v * delta
	if flushed > 0:
		if _flap_cd <= 0.0:
			_flap_cd = 0.2
			Audio.play_at("bird_flap", bp, -2.0)
			Audio.play_at("bird_chirp", bp + Vector2(0, -40), -6.0, 0.2)
		birds_flushed.emit(flushed)
	_birds = _birds.filter(func(b): return b.perched or b.p.distance_to(_cam) < 700)


# --- Bugs, butterflies ------------------------------------------------------------

func _add_swarm(anchor: Vector2) -> void:
	var flies := []
	var count := 12 if "flies" in _kinds else 7
	for i in count:
		flies.append({"p": anchor + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8)), "v": Vector2.ZERO})
	_swarms.append({"a": anchor, "flies": flies})


func _update_swarms(delta: float, bp: Vector2) -> void:
	var nearest := INF
	for s in _swarms:
		if absf(s.a.x - _cam.x) > VIEW.x + 60:
			continue
		for f in s.flies:
			var acc: Vector2 = (s.a - f.p) * 6.0 + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 500
			var to_bus: Vector2 = f.p - bp
			if to_bus.length() < 80:
				acc += to_bus.normalized() * 1500
			f.v = (f.v + acc * delta).limit_length(110)
			f.p += f.v * delta
		var d: float = s.a.distance_to(bp)
		if d < nearest and _buzz:
			nearest = d
			_buzz.global_position = s.a
	if _buzz:
		_buzz.volume_db = -14.0 if nearest < 300 else -60.0


func _update_butterflies(delta: float, bp: Vector2) -> void:
	for b in _butterflies:
		b.ph += delta
		if absf(b.p.x - _cam.x) > VIEW.x:  # keep a few near the camera
			b.p = _cam + Vector2(_rng.randf_range(-220, 220), _rng.randf_range(-60, 30))
		var acc := Vector2(sin(b.ph * 0.9) * 40, sin(b.ph * 2.3) * 60)
		if b.p.distance_to(bp) < 90:
			acc += (b.p - bp).normalized() * 400
		b.v = (b.v + acc * delta).limit_length(50)
		b.p += b.v * delta


# --- Lizards ------------------------------------------------------------------

func _update_lizards(delta: float, bp: Vector2) -> void:
	for l in _lizards:
		if l.state == "gone" or absf(l.p.x - _cam.x) > VIEW.x + 60:
			continue
		l.t += delta
		if l.state == "idle" and l.p.distance_to(bp) < 150:
			l.state = "run"
			l.t = 0.0
			l.dir = signf(l.p.x - bp.x + 0.1)
			Audio.play_at("lizard_scurry", l.p, -4.0)
		elif l.state == "run":
			l.p.x += l.dir * 170 * delta
			var gy := terrain.ground_y(l.p.x)
			if not is_nan(gy):
				l.p.y = gy
			if l.t > 0.7:
				l.alpha -= delta * 3.0
				if l.alpha <= 0.0:
					l.state = "gone"


# --- Tumbleweeds -------------------------------------------------------------------

func _update_tumbles(delta: float, bp: Vector2, bv: Vector2) -> void:
	_tumble_timer -= delta
	if _tumble_timer <= 0.0 and _tumbles.size() < 3:
		_tumble_timer = _rng.randf_range(2.5, 6.0)
		var x := _cam.x - VIEW.x - 20
		var gy := terrain.ground_y(x)
		if not is_nan(gy):
			var pat := []
			for k in 7:
				pat.append(Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)))
			_tumbles.append({"p": Vector2(x, gy - 8), "v": Vector2(70, 0), "rot": 0.0,
				"r": _rng.randf_range(5, 8), "pat": pat})
	for t in _tumbles:
		t.v.x = move_toward(t.v.x, 75.0, 40 * delta)
		t.v.y += 500 * delta
		t.p += t.v * delta
		t.rot += t.v.x * delta / t.r
		var gy := terrain.surface_y(t.p.x)
		if not is_nan(gy) and t.p.y + t.r > gy:
			t.p.y = gy - t.r
			t.v.y = -absf(t.v.y) * 0.5 - (_rng.randf_range(40, 140) if _rng.randf() < 0.2 else 0.0)
		if t.p.distance_to(bp) < 48 and bv.length() > 40:
			t.v = bv * 1.1 + Vector2(0, -220)
			Audio.play_at("rustle", t.p, -4.0)
	_tumbles = _tumbles.filter(func(t): return t.p.x < _cam.x + VIEW.x + 80 and t.p.y < terrain.road_bottom + 400)


# --- Leaves ---------------------------------------------------------------------

func _update_leaves(delta: float, bp: Vector2) -> void:
	var rate := 5.0 if _title == "JUNGLE" else 2.5
	if _rng.randf() < rate * delta:
		_spawn_leaf(_cam + Vector2(_rng.randf_range(-VIEW.x, VIEW.x), -VIEW.y))
	for tree in props.trees:
		if absf(tree.x - bp.x) < 60 and _time - _tree_cd.get(tree, -99.0) > 3.0:
			_tree_cd[tree] = _time
			for i in 8:
				_spawn_leaf(tree + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-10, 10)))
	for l in _leaves:
		l.t += delta
		if l.landed:
			l.life -= delta
			continue
		l.p += Vector2(20 + sin(l.t * 2.0 + l.ph) * 30, 28) * delta
		l.rot += l.spin * delta
		var gy := terrain.surface_y(l.p.x)
		if not is_nan(gy) and l.p.y > gy - 1:
			l.p.y = gy - 1
			l.landed = true
	_leaves = _leaves.filter(func(l): return l.life > 0.0 and absf(l.p.x - _cam.x) < VIEW.x + 80)


func _spawn_leaf(at: Vector2) -> void:
	var cols := ["#3a9a3a", "#5ab040", "#2a7a3a"] if _title == "JUNGLE" else ["#e07a2a", "#d04a2a", "#f0b030"]
	_leaves.append({"p": at, "rot": _rng.randf() * TAU, "spin": _rng.randf_range(-3, 3), "t": 0.0,
		"ph": _rng.randf() * TAU, "c": Color(cols[_rng.randi() % cols.size()]), "landed": false, "life": 3.0})


# --- Wheel dust & drifting particles ------------------------------------------------

func _update_puffs(delta: float, grounded: bool, bv: Vector2) -> void:
	_puff_timer -= delta
	if grounded and absf(bv.x) > 70 and _puff_timer <= 0.0:
		_puff_timer = 0.04
		for w in bus.wheels:
			_puffs.append({"p": w.global_position + Vector2(-6 * signf(bv.x), 7),
				"v": Vector2(-bv.x * 0.15 + _rng.randf_range(-15, 15), _rng.randf_range(-35, -10)),
				"life": 0.7, "s": _rng.randf_range(2, 4)})
	for p in _puffs:
		p.p += p.v * delta
		p.v *= 0.94
		p.life -= delta
		p.s += delta * 6
	_puffs = _puffs.filter(func(p): return p.life > 0.0)


func _update_flakes(delta: float) -> void:
	for f in _flakes:
		f.ph += delta
		match f.kind:
			"snow":
				f.p += Vector2(sin(f.ph * 1.3) * 12 - 10, 40 * f.s) * delta
			"ash":
				f.p += Vector2(sin(f.ph) * 8, 16 * f.s) * delta
			"embers":
				f.p += Vector2(sin(f.ph * 2.0) * 10, -30 * f.s) * delta
			"dust":
				f.p += Vector2(sin(f.ph * 0.4) * 4 + 3, sin(f.ph * 0.7) * 3) * delta
			"fireflies":
				f.p += Vector2(sin(f.ph * 0.8) * 14, cos(f.ph * 1.1) * 10) * delta
			"spores":
				f.p += Vector2(sin(f.ph * 0.6) * 8, -14 * f.s) * delta
		# Particles live in a box around the camera and wrap.
		f.p.x = fposmod(f.p.x + VIEW.x, VIEW.x * 2) - VIEW.x
		f.p.y = fposmod(f.p.y + VIEW.y, VIEW.y * 2) - VIEW.y


# --- Critters -------------------------------------------------------------------

func _spawn_critters() -> void:
	if "vultures" in _kinds:
		for i in 3:
			_critters.append({"kind": "vulture", "p": Vector2.ZERO, "ph": i * TAU / 3, "r": _rng.randf_range(70, 110)})
	if "jellies" in _kinds:
		for i in 6:
			_critters.append({"kind": "jelly", "p": Vector2(_rng.randf_range(0, 900), -80), "v": Vector2.ZERO,
				"ph": _rng.randf() * TAU})
	if "bats" in _kinds:
		for i in 10:
			_critters.append({"kind": "bat", "p": Vector2(_rng.randf_range(0, 800), -120), "v": Vector2(60, 0),
				"ph": _rng.randf() * TAU})
	if "monkeys" in _kinds:
		for t in props.trees:
			if _rng.randf() < 0.5:
				_critters.append({"kind": "monkey", "p": t + Vector2(_rng.randf_range(-10, 10), -8), "state": "idle",
					"v": Vector2.ZERO, "t": 0.0, "dir": 1.0})
	var ground := {"snakes": "snake", "goats": "goat", "penguins": "penguin"}
	for key in ground:
		if not key in _kinds:
			continue
		var x := 250.0
		while x < terrain.end_x - 200:
			x += _rng.randf_range(260, 520)
			var gy := terrain.ground_y(x)
			if is_nan(gy):
				continue
			var n: int = _rng.randi_range(2, 4) if key == "penguins" else 1
			for k in n:
				_critters.append({"kind": ground[key], "p": Vector2(x + k * 9, gy), "state": "idle", "v": Vector2.ZERO,
					"t": _rng.randf() * 3, "dir": -1.0 if _rng.randf() < 0.5 else 1.0, "alpha": 1.0})


func _update_critters(delta: float, bp: Vector2, bv: Vector2) -> void:
	_critter_cd -= delta
	for c in _critters:
		match c.kind:
			"vulture":  # lazy circles above the bus
				c.ph += delta * 0.6
				c.p = _cam + Vector2(cos(c.ph) * c.r * 1.8, -150 + sin(c.ph) * c.r * 0.35)
				if _critter_cd <= 0.0 and _rng.randf() < delta * 0.1:
					_critter_cd = 4.0
					Audio.play_at("vulture_caw", c.p, -10.0)
			"bat":  # jittery swarm that scatters from the bus
				c.ph += delta
				var home: Vector2 = _cam + Vector2(sin(c.ph * 0.3) * 200, -130 + sin(c.ph * 0.7) * 30)
				var acc: Vector2 = (home - c.p) * 1.5 + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 600
				if c.p.distance_to(bp) < 120:
					acc += (c.p - bp).normalized() * 900
					if _critter_cd <= 0.0:
						_critter_cd = 1.5
						Audio.play_at("bat_squeak", c.p, -6.0)
				c.v = (c.v + acc * delta).limit_length(170)
				c.p += c.v * delta
			"monkey":
				_update_monkey(c, delta, bp)
			"jelly":  # drifting, pulsing, shying away from the bus
				c.ph += delta
				if absf(c.p.x - _cam.x) > VIEW.x + 80:
					c.p = _cam + Vector2(_rng.randf_range(-VIEW.x, VIEW.x), _rng.randf_range(-180, -60))
				var acc := Vector2(sin(c.ph * 0.3) * 10, sin(c.ph * 1.2) * 18)
				if c.p.distance_to(bp) < 140:
					acc += (c.p - bp).normalized() * 160
				c.v = (c.v + acc * delta).limit_length(40)
				c.p += c.v * delta
			_:
				_update_ground_critter(c, delta, bp, bv)
	_critters = _critters.filter(func(c): return c.get("alpha", 1.0) > 0.0)


func _update_monkey(c: Dictionary, delta: float, bp: Vector2) -> void:
	c.t += delta
	if c.state == "idle" and absf(c.p.x - bp.x) < 140:
		c.state = "leap"
		c.dir = 1.0 if c.p.x >= bp.x else -1.0
		c.v = Vector2(c.dir * _rng.randf_range(110, 170), _rng.randf_range(-220, -160))
		Audio.play_at("monkey_screech", c.p, -4.0)
		if _rng.randf() < 0.4 and is_instance_valid(bus):
			bus.passengers.chatter(["MONKEY!", "IT TOOK MY BANANA!", "OOK OOK!"].pick_random(), "voice_happy")
	elif c.state == "leap":
		c.v.y += 420 * delta
		c.p += c.v * delta
		var gy := terrain.surface_y(c.p.x)
		if c.v.y > 0 and not is_nan(gy) and c.p.y > gy:
			c.p.y = gy
			c.state = "run"
	elif c.state == "run":
		c.p.x += c.dir * 150 * delta
		c.alpha = c.get("alpha", 1.0) - delta * 0.8
		var gy := terrain.surface_y(c.p.x)
		if not is_nan(gy):
			c.p.y = gy


func _update_ground_critter(c: Dictionary, delta: float, bp: Vector2, bv: Vector2) -> void:
	if absf(c.p.x - _cam.x) > VIEW.x + 60 and c.state == "idle":
		return
	c.t += delta
	var near := absf(c.p.x - bp.x) < (170 if c.kind == "goat" else 130) and absf(c.p.y - bp.y) < 90
	if c.state == "idle" and near:
		c.state = "flee"
		c.t = 0.0
		c.dir = 1.0 if c.p.x >= bp.x else -1.0
		var sound: String = {"snake": "snake_hiss", "goat": "goat_bleat", "penguin": "penguin_squawk"}[c.kind]
		Audio.play_at(sound, c.p, -6.0, 0.15)
		if c.kind == "penguin" and _rng.randf() < 0.3 and is_instance_valid(bus):
			bus.passengers.chatter(["PENGUINS!", "SO CUTE!", "LOOK AT 'EM GO!"].pick_random(), "voice_happy")
	if c.state == "flee":
		var speed: float = {"snake": 90.0, "goat": 170.0, "penguin": 190.0}[c.kind]
		c.p.x += c.dir * speed * delta
		var gy := terrain.surface_y(c.p.x)
		if is_nan(gy):
			c.alpha = 0.0
			return
		c.p.y = gy
		if c.kind == "goat":  # bounding hops
			c.p.y -= absf(sin(c.t * 9.0)) * 10.0
		if c.t > 1.4:
			c.alpha = c.get("alpha", 1.0) - delta * 1.5


func _draw_critters() -> void:
	for c in _critters:
		if absf(c.p.x - _cam.x) > VIEW.x + 20:
			continue
		var p: Vector2 = c.p
		var a: float = c.get("alpha", 1.0)
		match c.kind:
			"vulture":
				var flap := sin(_time * 3.0 + c.ph) * 2.0
				var col := Color("#2a1e24")
				draw_line(p, p + Vector2(-8, -3 - flap), col, 2.0)
				draw_line(p, p + Vector2(8, -3 - flap), col, 2.0)
				draw_rect(Rect2(p.x - 2, p.y - 1, 4, 3), col)
				draw_rect(Rect2(p.x + 2, p.y - 2, 2, 1), Color("#d8a0a0"))
			"jelly":
				var pulse := 1.0 + 0.2 * sin(c.ph * 3.0)
				var col := Color(0.55, 1.0, 0.85, 0.75)
				draw_arc(p, 5.0 * pulse, PI, TAU, 10, col, 2.0)
				draw_line(p + Vector2(-5 * pulse, 0), p + Vector2(5 * pulse, 0), col, 1.0)
				for k in 4:
					var tx := p.x - 3 + k * 2
					draw_line(Vector2(tx, p.y), Vector2(tx + sin(c.ph * 2.0 + k) * 2, p.y + 8), Color(col, 0.5), 1.0)
			"bat":
				var flap := sin(_time * 30.0 + c.ph) * 2.0
				draw_line(p, p + Vector2(-3, -flap), Color("#140a0e"), 1.0)
				draw_line(p, p + Vector2(3, -flap), Color("#140a0e"), 1.0)
				draw_rect(Rect2(p.x - 1, p.y - 1, 2, 2), Color("#140a0e"))
			"monkey":
				var col := Color(0.45, 0.28, 0.16, a)
				draw_rect(Rect2(p.x - 2, p.y - 5, 4, 4), col)
				draw_rect(Rect2(p.x - 2 + c.dir * 2, p.y - 8, 3, 3), col)
				draw_rect(Rect2(p.x - 1 + c.dir * 2, p.y - 7, 2, 1), Color(0.9, 0.75, 0.6, a))
				draw_arc(p + Vector2(-c.dir * 3, -3), 2.5, 0, PI * 1.5, 6, col, 1.0)
			"snake":
				var col := Color(0.55, 0.6, 0.2, a)
				for k in 6:
					var wave := sin(_time * 12.0 + k) * (1.5 if c.state == "flee" else 0.5)
					draw_rect(Rect2(p.x - c.dir * k * 2, p.y - 2 + wave, 2, 2), col)
				draw_rect(Rect2(p.x + c.dir * 2, p.y - 3, 2, 2), col.darkened(0.2))
			"goat":
				var col := Color(0.92, 0.9, 0.86, a)
				draw_rect(Rect2(p.x - 4, p.y - 7, 8, 4), col)
				draw_rect(Rect2(p.x + c.dir * 4 - 1, p.y - 10, 3, 3), col)
				draw_line(Vector2(p.x + c.dir * 4, p.y - 10), Vector2(p.x + c.dir * 2, p.y - 12), Color(0.5, 0.45, 0.4, a), 1.0)
				for lx in [-3, 2]:
					draw_rect(Rect2(p.x + lx, p.y - 3, 1, 3), col.darkened(0.3))
			"penguin":
				if c.state == "flee":  # belly slide
					draw_rect(Rect2(p.x - 4, p.y - 3, 8, 3), Color(0.1, 0.1, 0.14, a))
					draw_rect(Rect2(p.x - 3, p.y - 1, 6, 1), Color(0.95, 0.95, 1, a))
					draw_rect(Rect2(p.x + c.dir * 4, p.y - 2, 1, 1), Color(1, 0.6, 0.1, a))
				else:
					var waddle := sin(c.t * 6.0) * 0.5
					draw_rect(Rect2(p.x - 2 + waddle, p.y - 8, 4, 8), Color(0.1, 0.1, 0.14, a))
					draw_rect(Rect2(p.x - 1 + waddle, p.y - 6, 2, 5), Color(0.95, 0.95, 1, a))
					draw_rect(Rect2(p.x + c.dir * 2 + waddle, p.y - 7, 1, 1), Color(1, 0.6, 0.1, a))


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	_draw_critters()
	var dust := Color(DUST_COLORS.get(_title, "#a0a0a0"))
	for p in _puffs:
		draw_circle(p.p, p.s, Color(dust, clampf(p.life, 0.0, 0.5)))
	for b in _birds:
		if absf(b.p.x - _cam.x) > VIEW.x + 20:
			continue
		if b.perched:
			var y: float = b.p.y - (1 if b.hop > 0 else 0)
			draw_rect(Rect2(b.p.x - 2, y - 3, 4, 3), b.c)
			draw_rect(Rect2(b.p.x + 1, y - 5, 2, 2), b.c)
			draw_rect(Rect2(b.p.x + 3, y - 4, 1, 1), Color("#ffb030"))
		else:
			var flap := sin(b.t * 18.0) * 3.0
			draw_line(b.p, b.p + Vector2(-4, -flap), b.c, 1.0)
			draw_line(b.p, b.p + Vector2(4, -flap), b.c, 1.0)
			draw_rect(Rect2(b.p.x - 1, b.p.y - 1, 2, 2), b.c)
	for s in _swarms:
		if absf(s.a.x - _cam.x) > VIEW.x + 20:
			continue
		for f in s.flies:
			draw_rect(Rect2(f.p.x, f.p.y, 1, 1), Color("#141010"))
			if int(_time * 30 + f.p.x) % 2 == 0:
				draw_rect(Rect2(f.p.x, f.p.y - 1, 1, 1), Color(0.8, 0.9, 1.0, 0.6))
	for b in _butterflies:
		var w := absf(sin(b.ph * 14.0)) * 2.0 + 0.5
		draw_rect(Rect2(b.p.x - w, b.p.y - 1, w, 2), b.c)
		draw_rect(Rect2(b.p.x + 1, b.p.y - 1, w, 2), b.c)
		draw_rect(Rect2(b.p.x, b.p.y - 1, 1, 3), Color("#1a1a1a"))
	var liz_col: Color = {"DESERT": Color("#b89a50"), "JUNGLE": Color("#50c040"), "VOLCANO": Color("#e0602a")}.get(_title, Color("#8a9a50"))
	for l in _lizards:
		if l.state == "gone" or absf(l.p.x - _cam.x) > VIEW.x + 20:
			continue
		var c := Color(liz_col, l.alpha)
		var d: float = l.dir
		var leg := 1.0 if l.state == "run" and int(l.t * 20) % 2 == 0 else 0.0
		draw_rect(Rect2(l.p.x - 3, l.p.y - 2, 6, 2), c)
		draw_rect(Rect2(l.p.x + 3 * d - (0 if d > 0 else 2), l.p.y - 3, 2, 2), c)  # head
		draw_line(Vector2(l.p.x - 3 * d, l.p.y - 1), Vector2(l.p.x - 8 * d, l.p.y - 1 - leg), c, 1.0)  # tail
		draw_rect(Rect2(l.p.x - 2, l.p.y, 1, 1 + leg), c)
		draw_rect(Rect2(l.p.x + 2, l.p.y, 1, 2 - leg), c)
		if l.state == "idle" and fmod(l.t, 3.0) < 0.15:
			draw_rect(Rect2(l.p.x + 5 * d, l.p.y - 2, 2 * d, 1), Color("#ff4060"))  # tongue flick
	for t in _tumbles:
		var c := Color("#a07a44")
		var pts := []
		for v in t.pat:
			pts.append(t.p + (v as Vector2).rotated(t.rot) * t.r)
		draw_arc(t.p, t.r, 0, TAU, 12, c, 1.0)
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], c.darkened(0.2), 1.0)
	for l in _leaves:
		var flip := cos(l.t * 5.0 + l.ph)  # twisting: the leaf's width flips as it turns
		var fwd := Vector2(3, 0).rotated(l.rot)
		var side := Vector2(0, 1.5 * flip).rotated(l.rot)
		var c: Color = l.c if flip > 0 else l.c.darkened(0.3)
		c.a = clampf(l.life, 0.0, 1.0)
		if absf(flip) < 0.2:  # edge-on: just a sliver
			draw_line(l.p - fwd, l.p + fwd, c, 1.0)
		else:
			draw_colored_polygon(PackedVector2Array([l.p - fwd, l.p + side, l.p + fwd, l.p - side]), c)
	for f in _flakes:
		if f.kind == "ash":
			draw_rect(Rect2(_cam + f.p, Vector2(1, 1)), Color(0.55, 0.5, 0.5, 0.8))


func _draw_glow() -> void:
	for f in _flakes:
		var p: Vector2 = _cam + f.p
		match f.kind:
			"snow":
				var sz := 1.0 if f.s < 0.8 else 2.0
				glow.draw_rect(Rect2(p, Vector2(sz, sz)), Color(1, 1, 1, 0.55 + f.s * 0.4))
			"embers":
				var a := 0.5 + 0.5 * sin(f.ph * 6.0)
				glow.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 0.6 + 0.3 * a, 0.2, a))
			"dust":
				var a := 0.15 + 0.2 * sin(f.ph * 1.5)
				glow.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 0.95, 0.8, a))
			"fireflies":
				var a := maxf(0.0, sin(f.ph * 2.5))
				glow.draw_circle(p, 1.2, Color(0.85, 1.0, 0.4, a))
				glow.draw_circle(p, 3.0, Color(0.85, 1.0, 0.4, a * 0.2))
			"spores":
				var a := 0.4 + 0.4 * sin(f.ph * 2.0)
				glow.draw_circle(p, 1.0 + f.s, Color(0.5, 1.0, 0.75, a))
