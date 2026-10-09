class_name Levels
## The 24 levels: 6 worlds x 4. Each level is a short recipe; `_build` turns it into
## a long course (see terrain.gd for the segment format). The same recipe always
## builds the same course (seeded by the title), so tuning = editing numbers here.

const WORLDS := ["DESERT", "JUNGLE", "MOUNTAINS", "SNOW", "VOLCANO", "MOON", "BORDER"]
## The ramp alone carries the bus ~200px, so every gap gets this much extra to make the rocket matter.
const GAP_EXTRA := 100.0

# title, biome, blurb, jumps, gap kinds, gap length range, landing-height range (+-px),
# fuel tank, options (zone "mud"/"ice", weather)
const RECIPES := [
	["FIRST DAY", "desert", "Hold the rocket off the ramp. Land flat.", 3, ["chasm"], [170, 210], 0, 60, {}],
	["OASIS HOP", "desert@noon", "Don't feed the bus to the oasis.", 4, ["water", "chasm"], [190, 240], 0, 85, {}],
	["DOUBLE TROUBLE", "desert@dawn", "Crates, boulders, gaps. One tank.", 5, ["chasm", "water"], [210, 260], 20, 135, {}],
	["MESA LEAP", "desert", "Sandstorm. The far sides get higher.", 6, ["chasm"], [220, 280], 40, 140, {"weather": "sandstorm"}],
	["RIVER RUN", "jungle", "Rivers, bugs, and one very nervous driver.", 5, ["water", "swamp"], [220, 270], 20, 85, {"weather": "rain"}],
	["SWAMP THING", "jungle@noon", "Something lives in that swamp.", 6, ["swamp", "water"], [230, 280], 30, 125, {"zone": "mud"}],
	["CANOPY CHASE", "jungle", "Mud, rain, monkeys.", 6, ["chasm", "water", "swamp"], [240, 290], 40, 155, {"zone": "mud", "weather": "rain"}],
	["TEMPLE DROP", "jungle@night", "Nose down for the downhill landings.", 7, ["chasm", "swamp"], [250, 300], 60, 135, {"zone": "mud"}],
	["SWITCHBACK", "mountain@dawn", "Up, over, and down the mountain.", 6, ["chasm", "water"], [240, 290], 40, 50, {}],
	["GOAT PATH", "mountain", "Bumpy road in the rain. Hold it steady.", 7, ["chasm"], [250, 300], 40, 70, {"weather": "rain"}],
	["EAGLE'S NEST", "mountain@noon", "Big air. Bigger gaps.", 7, ["chasm", "water"], [250, 300], 50, 80, {}],
	["SUMMIT RUN", "mountain", "Eight gaps to the top of the world.", 8, ["chasm"], [260, 310], 50, 70, {"weather": "rain"}],
	["FIRST FROST", "snow@noon", "Icy roads. Brake early.", 6, ["ice", "chasm"], [240, 290], 40, 65, {"zone": "ice"}],
	["FROZEN LAKE", "snow@dawn", "Don't test the ice.", 7, ["ice"], [250, 300], 50, 85, {"zone": "ice"}],
	["AVALANCHE ALLEY", "snow", "Blizzard. Can't see a thing.", 8, ["ice", "chasm"], [250, 300], 50, 70, {"zone": "ice", "weather": "blizzard"}],
	["POLAR EXPRESS", "snow", "The heater is broken.", 8, ["ice", "chasm"], [250, 300], 50, 100, {"zone": "ice", "weather": "blizzard"}],
	["HOT FOOT", "volcano", "The floor is lava. Literally.", 7, ["lava", "chasm"], [280, 340], 50, 60, {}],
	["MAGMA MILE", "volcano@night", "Don't touch the orange stuff.", 8, ["lava"], [290, 350], 60, 110, {}],
	["ASH CLOUD", "volcano", "Can't see. Can't stop.", 8, ["lava", "chasm"], [260, 320], 60, 80, {"weather": "ash"}],
	["THE LAST STOP", "volcano", "Nine gaps. Everyone off at the last stop.", 9, ["lava", "chasm"], [270, 320], 60, 85, {"weather": "ash"}],
	["ONE SMALL HOP", "moon", "Low gravity. Easy on the rocket.", 5, ["chasm"], [480, 620], 40, 40, {}],
	["CRATER HOPPER", "moon", "Craters everywhere. Float between them.", 6, ["chasm"], [520, 680], 50, 40, {}],
	["DARK SIDE", "moon", "Nobody's out here to see you crash.", 7, ["chasm"], [560, 740], 60, 40, {}],
	["EARTHRISE", "moon", "The last stop is 238,900 miles from home.", 8, ["chasm"], [600, 800], 70, 40, {}],
	["ANOMALOUS RIDE", "border", "Floating islands. Don't look down.", 8, ["chasm"], [260, 320], 50, 40,
		{}],
]
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
## (hills, climbs/descents, mud/ice), a flat run-up, the
## ramp and gap, and a landing strip; checkpoints every few jumps; a finish straight.
static func _build(index: int, r: Array) -> Dictionary:
	var title: String = r[0]
	var biome: String = r[1]
	var jumps: int = r[3]
	var kinds: Array = r[4]
	var gap_range: Array = r[5]
	var dy_range: float = r[6]
	var opts: Dictionary = r[8]
	var zone: String = opts.get("zone", "")
	var difficulty := clampf(index / 23.0, 0.0, 1.0)
	var downhill_chance: float = 0.25 + 0.25 * difficulty  # more downhill landings in later worlds
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)

	var segs: Array = [_f(700 if index == 0 else 500)]
	var height := 0.0  # rough road height, kept within bounds
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
		# Setpieces break up the run-up / ramp / gap rhythm once the player knows the basics.
		var setpiece := ""
		if index >= 2 and index < 20 and j > 0:  # (the moon's long gaps stay plain)
			var roll := rng.randf()
			if roll < 0.12 + 0.12 * difficulty:
				setpiece = "double"
			elif roll < 0.3 + 0.1 * difficulty:
				setpiece = "downhill"
		if setpiece == "downhill":  # come down a hill straight onto the ramp, land lower still
			segs.pop_back()
			segs.append(_s(rng.randf_range(320, 400), rng.randf_range(60, 90)))
			segs.append(_f(rng.randf_range(260, 320)))
			land_dy = absf(land_dy) * 0.5 + 30.0
			height += 120.0
		segs.append_array(_j(rng.randf_range(140, 170), rng.randf_range(45, 60), gap_len, kind, land_dy))
		if setpiece == "double":  # a tiny island: land and launch again straight away
			segs.append(_f(rng.randf_range(250, 290)))
			segs.append_array(_j(rng.randf_range(130, 150), rng.randf_range(42, 52), gap_len * 0.7, kind, 0.0))
		if index >= 2 and rng.randf() < downhill_chance:
			# Downhill landing: tip the nose down to match the slope, then it levels out.
			var fall := rng.randf_range(80, 150)
			height += fall
			segs.append({"t": "landing", "len": rng.randf_range(320, 440), "dy": fall})
			segs.append(_f(rng.randf_range(260, 380)))
		elif index >= 1 and rng.randf() < 0.25 + 0.2 * difficulty:
			# A kicker on the landing strip: free air for a flip, if you dare.
			segs.append(_f(rng.randf_range(300, 360)))
			segs.append({"t": "kicker", "len": rng.randf_range(80, 100), "rise": rng.randf_range(16, 24)})
			segs.append(_f(rng.randf_range(320, 400)))
		else:
			segs.append(_f(rng.randf_range(420, 560)))  # landing strip
		if (j + 1) % CHECKPOINT_EVERY == 0 and j < jumps - 1:
			segs.append({"t": "checkpoint"})
			segs.append(_f(200))
	segs.append(_f(400))
	segs.append(_end())

	return {"title": title, "biome": biome, "fuel": float(r[7]), "blurb": r[2], "segments": segs,
		"weather": opts.get("weather", "")}


static func _f(length: float) -> Dictionary:
	return {"t": "flat", "len": length}


static func _h(length: float, amp: float, waves := 1) -> Dictionary:
	return {"t": "hill", "len": length, "amp": amp, "waves": waves}


static func _s(length: float, dy: float) -> Dictionary:
	return {"t": "slope", "len": length, "dy": dy}


static func _j(ramp_len: float, rise: float, gap_len: float, kind: String, dy := 0.0) -> Array:
	return [{"t": "ramp", "len": ramp_len, "rise": rise},
		{"t": "gap", "len": gap_len + GAP_EXTRA, "kind": kind, "dy": dy}]


static func _fuel() -> Dictionary:
	return {"t": "fuel"}


static func _end() -> Dictionary:
	return {"t": "finish", "len": 300}
