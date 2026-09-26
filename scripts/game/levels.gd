class_name Levels
## The 24 levels: 6 worlds x 4. Each level is a short recipe; `_build` turns it into
## a long course (see terrain.gd for the segment format). The same recipe always
## builds the same course (seeded by the title), so tuning = editing numbers here.

const WORLDS := ["DESERT", "JUNGLE", "MOUNTAINS", "SNOW", "VOLCANO", "MOON", "BORDER"]
## The ramp alone carries the bus ~200px, so every gap gets this much extra to make the rocket matter.
const GAP_EXTRA := 100.0

# title, biome, blurb, jumps, gap kinds, gap length range, landing-height range (+-px),
# fuel tank, options (blockers, zone "mud"/"ice", weather)
const RECIPES := [
	["FIRST DAY", "desert", "Hold the rocket off the ramp. Land flat.", 3, ["chasm"], [170, 210], 0, 100, {"blockers": false}],
	["OASIS HOP", "desert", "Don't feed the bus to the oasis.", 4, ["water", "chasm"], [190, 240], 0, 100, {"blockers": false}],
	["DOUBLE TROUBLE", "desert", "Crates, boulders, gaps. One tank.", 5, ["chasm", "water"], [210, 260], 20, 100, {}],
	["MESA LEAP", "desert", "Sandstorm. The far sides get higher.", 6, ["chasm"], [220, 280], 40, 100, {"weather": "sandstorm"}],
	["RIVER RUN", "jungle", "Rivers, bugs, and one very nervous driver.", 5, ["water", "swamp"], [220, 270], 20, 100, {"weather": "rain"}],
	["SWAMP THING", "jungle", "Something lives in that swamp.", 6, ["swamp", "water"], [230, 280], 30, 100, {"zone": "mud"}],
	["CANOPY CHASE", "jungle", "Mud, rain, monkeys.", 6, ["chasm", "water", "swamp"], [240, 290], 40, 100, {"zone": "mud", "weather": "rain"}],
	["TEMPLE DROP", "jungle", "Nose down for the downhill landings.", 7, ["chasm", "swamp"], [250, 300], 60, 100, {"zone": "mud"}],
	["SWITCHBACK", "mountain", "Up, over, and down the mountain.", 6, ["chasm", "water"], [240, 290], 40, 100, {}],
	["GOAT PATH", "mountain", "Bumpy road in the rain. Hold it steady.", 7, ["chasm"], [250, 300], 40, 100, {"weather": "rain"}],
	["EAGLE'S NEST", "mountain", "Big air. Bigger gaps.", 7, ["chasm", "water"], [250, 300], 50, 110, {}],
	["SUMMIT RUN", "mountain", "Eight gaps to the top of the world.", 8, ["chasm"], [260, 310], 50, 110, {"weather": "rain"}],
	["FIRST FROST", "snow", "Icy roads. Brake early.", 6, ["ice", "chasm"], [240, 290], 40, 100, {"zone": "ice"}],
	["FROZEN LAKE", "snow", "Don't test the ice.", 7, ["ice"], [250, 300], 50, 110, {"zone": "ice"}],
	["AVALANCHE ALLEY", "snow", "Blizzard. Can't see a thing.", 8, ["ice", "chasm"], [250, 300], 50, 120, {"zone": "ice", "weather": "blizzard"}],
	["POLAR EXPRESS", "snow", "The heater is broken.", 8, ["ice", "chasm"], [250, 300], 50, 140, {"zone": "ice", "weather": "blizzard"}],
	["HOT FOOT", "volcano", "The floor is lava. Literally.", 7, ["lava", "chasm"], [280, 340], 50, 110, {}],
	["MAGMA MILE", "volcano", "Don't touch the orange stuff.", 8, ["lava"], [290, 350], 60, 110, {}],
	["ASH CLOUD", "volcano", "Can't see. Can't stop.", 8, ["lava", "chasm"], [260, 320], 60, 130, {"weather": "ash"}],
	["THE LAST STOP", "volcano", "Nine gaps. Everyone off at the last stop.", 9, ["lava", "chasm"], [270, 320], 60, 120, {"weather": "ash"}],
	["ONE SMALL HOP", "moon", "Low gravity. Easy on the rocket.", 5, ["chasm"], [480, 620], 40, 70, {}],
	["CRATER HOPPER", "moon", "Craters everywhere. Float between them.", 6, ["chasm"], [520, 680], 50, 65, {}],
	["DARK SIDE", "moon", "Nobody's out here to see you crash.", 7, ["chasm"], [560, 740], 60, 60, {}],
	["EARTHRISE", "moon", "The last stop is 238,900 miles from home.", 8, ["chasm"], [600, 800], 70, 60, {}],
	["ANOMALOUS RIDE", "border", "Floating islands. Don't look down.", 8, ["chasm"], [260, 320], 50, 140,
		{"blockers": false}],
]
const SMASHABLES := {
	"desert": ["crate", "cone", "fence", "barrel", "mailbox"], "jungle": ["crate", "fence", "barrel"],
	"mountain": ["crate", "cone", "fence", "barrel"], "snow": ["crate", "cone", "fence"],
	"volcano": ["barrel", "barrel", "crate"], "moon": ["crate", "barrel"], "border": ["crate", "cone"],
}
const BLOCKERS := {
	"desert": ["boulder", "barricade"], "jungle": ["boulder", "barricade"], "mountain": ["boulder", "barricade"],
	"snow": ["barricade", "boulder"], "volcano": ["boulder", "barricade"], "moon": ["boulder"],
	"border": ["boulder"],
}
const CHECKPOINT_EVERY := 3  ## jumps between checkpoints
const FUEL_EVERY := 2  ## jumps between fuel cans

static var _cache: Array = []


static func count() -> int:
	return RECIPES.size()


static func get_level(i: int) -> Dictionary:
	if _cache.is_empty():
		for k in RECIPES.size():
			_cache.append(_build(k, RECIPES[k]))
	return _cache[clampi(i, 0, count() - 1)]


static func code(i: int) -> String:
	return "%d-%d" % [i / 4 + 1, i % 4 + 1]


## Turns a recipe into segments: an opening straight, then for each jump a varied run
## (hills, climbs/descents, mud/ice, clutter, a blocker to shoot), a flat run-up, the
## ramp and gap, and a landing strip; checkpoints every few jumps; a finish straight.
static func _build(index: int, r: Array) -> Dictionary:
	var title: String = r[0]
	var biome: String = r[1]
	var jumps: int = r[3]
	var kinds: Array = r[4]
	var gap_range: Array = r[5]
	var dy_range: float = r[6]
	var opts: Dictionary = r[8]
	var blockers: bool = opts.get("blockers", true)
	var zone: String = opts.get("zone", "")
	var difficulty := clampf(index / 23.0, 0.0, 1.0)
	var downhill_chance: float = 0.25 + 0.25 * difficulty  # more downhill landings in later worlds
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)

	var segs: Array = [_f(700 if index == 0 else 500)]
	var height := 0.0  # rough road height, kept within bounds
	var blocker_count := 0
	for j in jumps:
		# The run between jumps: 2-4 varied pieces.
		for k in rng.randi_range(2, 4):
			var roll := rng.randf()
			if roll < 0.3:
				segs.append(_f(rng.randf_range(220, 480)))
			elif roll < 0.55:
				# Bumps must be long and gentle enough for a 100px bus: >= 300px per wave.
				var hill_len := rng.randf_range(300, 620)
				var waves := 2 if hill_len >= 600 else 1
				var amp := minf(8 + 22 * difficulty * rng.randf(), hill_len / waves / 16.0)
				segs.append(_h(hill_len, amp, waves))
			elif roll < 0.8:
				var dy := rng.randf_range(30, 40 + 70 * difficulty)
				if height < -200 or (height < 150 and rng.randf() < 0.5):
					dy = absf(dy)  # downhill
				else:
					dy = -absf(dy)
				height += dy
				segs.append(_s(rng.randf_range(300, 420), dy))
			elif zone != "":
				segs.append(_f(80))
				segs.append({"t": zone, "len": rng.randf_range(160, 280)})
			else:
				segs.append(_f(rng.randf_range(260, 420)))
		if blockers and j % 3 == 1:  # blockers are occasional, not constant speed bumps
			var kind: String = BLOCKERS[biome][rng.randi() % BLOCKERS[biome].size()]
			segs.append(_f(500))  # a long flat approach so there's time to aim and shoot
			segs.append(_o(kind))
			segs.append(_f(260))
			blocker_count += Obstacle.KINDS[kind].hp
			if blocker_count >= 3:
				segs.append({"t": "ammo"})
				blocker_count = 0
		# Long, hard levels get a can before every jump; early ones every other jump.
		if j > 0 and (index >= 8 or j % FUEL_EVERY == 0):
			segs.append(_f(120))
			segs.append(_fuel())
		# Flat run-up, then the jump. Never straight off mud/ice: the bus needs to get up to speed.
		if segs[-1].t in ["mud", "ice"]:
			segs.append(_f(300))
		segs.append(_f(rng.randf_range(380, 520)))
		var gap_len := rng.randf_range(gap_range[0], gap_range[1])
		var kind: String = kinds[rng.randi() % kinds.size()]
		# Far sides can drop a lot but only rise a little (rising landings are brutal).
		var land_dy := 0.0 if dy_range <= 0 else rng.randf_range(-minf(dy_range, 30.0), dy_range)
		height += land_dy
		segs.append_array(_j(rng.randf_range(140, 170), rng.randf_range(45, 60), gap_len, kind, land_dy))
		if index >= 2 and rng.randf() < downhill_chance:
			# Downhill landing: tip the nose down to match the slope, then it levels out.
			var fall := rng.randf_range(80, 150)
			height += fall
			segs.append({"t": "landing", "len": rng.randf_range(320, 440), "dy": fall})
			segs.append(_f(rng.randf_range(260, 380)))
		else:
			segs.append(_f(rng.randf_range(420, 560)))  # landing strip
		if (j + 1) % CHECKPOINT_EVERY == 0 and j < jumps - 1:
			segs.append({"t": "checkpoint"})
			segs.append(_f(200))
	segs.append(_f(400))
	segs.append(_end())

	segs = _sprinkle(segs, biome, title)
	# Enough slugs for every blocker, plus spares for shooting barrels.
	var ammo := 3
	var barrels := 0
	for s in segs:
		if s.t == "obj" and Obstacle.KINDS[s.kind].blocker:
			ammo += Obstacle.KINDS[s.kind].hp
		elif s.t == "obj" and s.kind == "barrel":
			barrels += 1
	ammo += barrels / 2
	return {"title": title, "biome": biome, "fuel": float(r[7]), "blurb": r[2], "segments": segs,
		"ammo": mini(ammo, 14), "weather": opts.get("weather", "")}


## Road clutter on long flat stretches (deterministic per level title).
static func _sprinkle(segs: Array, biome: String, title: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title) + 1
	var out := []
	for i in segs.size():
		var s: Dictionary = segs[i]
		var before_ramp: bool = i + 1 < segs.size() and segs[i + 1].t == "ramp"
		var before_blocker: bool = i + 1 < segs.size() and segs[i + 1].t == "obj"  # keep the line of fire clear
		if s.t != "flat" or s.len < 260 or i == 0 or before_ramp or before_blocker or rng.randf() < 0.35:
			out.append(s)
			continue
		var a: float = s.len * 0.45
		out.append({"t": "flat", "len": a})
		var pool: Array = SMASHABLES[biome]
		for k in rng.randi_range(1, 3):
			out.append({"t": "obj", "kind": pool[rng.randi() % pool.size()]})
			out.append({"t": "flat", "len": 14})
		out.append({"t": "flat", "len": s.len - a})
	return out


static func _f(length: float) -> Dictionary:
	return {"t": "flat", "len": length}


static func _h(length: float, amp: float, waves := 1) -> Dictionary:
	return {"t": "hill", "len": length, "amp": amp, "waves": waves}


static func _s(length: float, dy: float) -> Dictionary:
	return {"t": "slope", "len": length, "dy": dy}


static func _j(ramp_len: float, rise: float, gap_len: float, kind: String, dy := 0.0) -> Array:
	return [{"t": "ramp", "len": ramp_len, "rise": rise},
		{"t": "gap", "len": gap_len + GAP_EXTRA, "kind": kind, "dy": dy}]


static func _o(kind: String) -> Dictionary:
	return {"t": "obj", "kind": kind}


static func _fuel() -> Dictionary:
	return {"t": "fuel"}


static func _end() -> Dictionary:
	return {"t": "finish", "len": 300}
