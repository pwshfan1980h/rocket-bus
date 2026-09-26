class_name Levels
## The 20 levels: 5 worlds x 4. Segment format is documented in terrain.gd.
## Gap dy is relative to the road before the ramp (negative = land higher).

const WORLDS := ["DESERT", "JUNGLE", "MOUNTAINS", "SNOW", "VOLCANO"]
## The ramp alone carries the bus ~200px, so every gap gets this much extra to make the rocket matter.
const GAP_EXTRA := 100.0


static func count() -> int:
	return all().size()


static func get_level(i: int) -> Dictionary:
	return all()[clampi(i, 0, count() - 1)]


static func code(i: int) -> String:
	return "%d-%d" % [i / 4 + 1, i % 4 + 1]


static func all() -> Array:
	return [
		# --- World 1: Desert ----------------------------------------------------------
		_lvl("FIRST DAY", "desert", 100, "Hold the rocket off the ramp. Land flat.", [
			_f(700), _j(150, 50, 200, "chasm"), _f(600), _end()], false),
		_lvl("OASIS HOP", "desert", 100, "Don't feed the bus to the oasis.", [
			_f(500), _h(300, 16), _f(300), _j(150, 50, 240, "water"), _f(500), _end()], false),
		_lvl("DOUBLE TROUBLE", "desert", 100, "Two gaps. One tank. Save some fuel.", [
			_f(300), _o("boulder"), _f(420), _j(140, 45, 220, "chasm"), _f(450), _fuel(), _f(100),
			_j(150, 50, 260, "water"), _f(400), _end()]),
		_lvl("MESA LEAP", "desert", 100, "The far side is higher. Burn longer.", [
			_f(400), _s(300, -50), _f(300), _j(150, 55, 240, "chasm", -20), _f(400), _h(300, 20),
			_j(140, 50, 260, "chasm", 30), _f(400), _end()]),
		# --- World 2: Jungle -------------------------------------------------------------
		_lvl("RIVER RUN", "jungle", 100, "Rivers, bugs, and one very nervous driver.", [
			_f(500), _h(400, 14, 2), _j(150, 50, 260, "water"), _f(400),
			_j(140, 45, 240, "swamp"), _f(400), _end()]),
		_lvl("SWAMP THING", "jungle", 100, "Something lives in that swamp.", [
			_f(300), _o("log"), _f(400), _j(130, 45, 230, "swamp"), _f(350), _s(300, 40), _f(200),
			_j(150, 55, 280, "swamp", -20), _f(400), _end()]),
		_lvl("CANOPY CHASE", "jungle", 100, "Three gaps under the canopy.", [
			_f(400), _j(140, 50, 240, "chasm"), _f(300), _fuel(), _h(300, 20),
			_j(140, 50, 260, "water"), _f(300), _j(150, 55, 280, "swamp"), _f(400), _end()]),
		_lvl("TEMPLE DROP", "jungle", 100, "Nose down for the downhill landing.", [
			_f(400), _s(400, -80), _j(150, 55, 320, "chasm", 60), _s(300, 40), _f(300),
			_j(140, 50, 260, "water"), _f(250), _j(140, 50, 280, "swamp", -30), _f(400), _end()]),
		# --- World 3: Mountains ----------------------------------------------------------
		_lvl("SWITCHBACK", "mountain", 100, "Up, over, and down the mountain.", [
			_f(300), _o("boulder"), _f(300), _s(400, -90), _f(200), _j(150, 55, 280, "chasm"), _f(300), _s(300, 60), _f(140),
			_j(140, 50, 260, "water"), _f(300), _j(150, 50, 260, "chasm", -40), _f(400), _end()]),
		_lvl("GOAT PATH", "mountain", 100, "Bumpy road. Hold it steady.", [
			_f(300), _h(400, 16, 2), _f(120), _j(150, 55, 300, "chasm", -25), _f(250), _fuel(), _f(80),
			_j(140, 50, 280, "chasm", 50), _s(300, 50), _f(250), _j(150, 55, 300, "water"), _f(400), _end()]),
		_lvl("EAGLE'S NEST", "mountain", 110, "Big air. Bigger gaps.", [
			_f(400), _s(500, -140), _f(150), _j(160, 60, 360, "chasm"), _f(250),
			_j(150, 55, 320, "chasm", 60), _f(300), _j(150, 55, 300, "chasm"), _f(400), _end()]),
		_lvl("SUMMIT RUN", "mountain", 110, "Four gaps to the top of the world.", [
			_f(350), _j(150, 55, 280, "chasm", -40), _f(250), _j(150, 55, 300, "water"), _f(200), _fuel(),
			_s(300, -60), _j(160, 60, 340, "chasm", 40), _f(250), _j(150, 55, 300, "chasm"), _f(400), _end()]),
		# --- World 4: Snow ----------------------------------------------------------------
		_lvl("FIRST FROST", "snow", 100, "Icy roads. Brake early.", [
			_f(500), _j(150, 50, 240, "ice"), _f(400), _j(150, 50, 260, "chasm"), _f(400),
			_j(150, 50, 260, "ice"), _f(400), _end()]),
		_lvl("FROZEN LAKE", "snow", 110, "Don't test the ice.", [
			_f(300), _o("barricade"), _f(400), _s(300, 40), _j(150, 55, 320, "ice"), _f(300), _fuel(), _f(80),
			_j(140, 50, 280, "ice", -30), _f(300), _h(300, 16), _j(150, 55, 300, "chasm"), _f(250),
			_j(150, 50, 260, "ice"), _f(400), _end()]),
		_lvl("AVALANCHE ALLEY", "snow", 110, "Downhill run-ups. Fast and scary.", [
			_f(300), _s(400, 100), _j(150, 55, 340, "chasm"), _f(250), _j(150, 55, 300, "ice", -30),
			_f(250), _s(300, 60), _j(160, 60, 360, "chasm"), _f(250), _j(150, 55, 300, "ice"), _f(400), _end()]),
		_lvl("POLAR EXPRESS", "snow", 120, "Five gaps. The heater is broken.", [
			_f(300), _j(150, 55, 300, "ice"), _f(200), _j(150, 55, 320, "chasm", -40), _f(250), _fuel(),
			_f(80), _j(160, 60, 340, "ice"), _f(200), _j(150, 55, 320, "chasm", 40), _s(200, 30), _f(250),
			_j(160, 60, 360, "ice"), _f(400), _end()]),
		# --- World 5: Volcano ------------------------------------------------------------
		_lvl("HOT FOOT", "volcano", 110, "The floor is lava. Literally.", [
			_f(300), _o("boulder"), _f(400), _j(150, 50, 260, "lava"), _f(300), _j(150, 50, 280, "chasm"), _f(300),
			_j(150, 55, 300, "lava"), _f(250), _j(150, 55, 300, "lava"), _f(400), _end()]),
		_lvl("MAGMA MILE", "volcano", 110, "Don't touch the orange stuff.", [
			_f(350), _h(300, 20), _j(150, 55, 320, "lava"), _f(250), _fuel(), _f(80),
			_j(150, 55, 320, "lava", -40), _f(250), _j(160, 60, 340, "chasm"), _f(250),
			_j(150, 55, 320, "lava", 40), _f(400), _end()]),
		_lvl("ASH CLOUD", "volcano", 120, "Can't see. Can't stop.", [
			_f(300), _s(400, -100), _j(160, 60, 360, "lava"), _f(200), _j(150, 55, 340, "lava", 50),
			_f(200), _fuel(), _f(80), _j(150, 55, 320, "chasm"), _f(200), _j(160, 60, 360, "lava"), _f(200),
			_j(150, 55, 320, "lava"), _f(400), _end()]),
		_lvl("THE LAST STOP", "volcano", 120, "Six gaps. Everyone off at the last stop.", [
			_f(300), _j(150, 55, 320, "lava"), _f(200), _j(150, 55, 340, "chasm", -40), _f(200), _fuel(),
			_f(80), _j(160, 60, 360, "lava"), _f(200), _j(150, 55, 340, "lava", 40), _s(200, 30), _fuel(),
			_f(80), _j(160, 60, 380, "lava"), _f(200), _j(160, 60, 400, "lava"), _f(500), _end()]),
	]


const SMASHABLES := {
	"desert": ["crate", "cone", "fence", "barrel", "mailbox"], "jungle": ["crate", "fence", "barrel"],
	"mountain": ["crate", "cone", "fence", "barrel"], "snow": ["crate", "cone", "fence"],
	"volcano": ["barrel", "barrel", "crate"], "moon": ["crate", "barrel"],
}
const BLOCKERS := {
	"desert": ["boulder", "barricade"], "jungle": ["log", "boulder"], "mountain": ["boulder", "log"],
	"snow": ["log", "barricade"], "volcano": ["boulder", "barricade"], "moon": ["boulder"],
}


static func _lvl(title: String, biome: String, fuel: float, blurb: String, segs: Array,
		blockers := true) -> Dictionary:
	var flat := []
	for s in segs:
		if s is Array:
			flat.append_array(s)
		else:
			flat.append(s)
	flat = _sprinkle(flat, biome, title, blockers)
	var ammo := 3
	for s in flat:
		if s.t == "obj" and s.kind in BLOCKERS.get(biome, []):
			ammo += Obstacle.KINDS[s.kind].hp
	return {"title": title, "biome": biome, "fuel": fuel, "blurb": blurb, "segments": flat, "ammo": ammo}


## Puts road clutter on long flat stretches: smashables everywhere, and (after the
## first levels) a blocker you must shoot. Deterministic per level title.
static func _sprinkle(segs: Array, biome: String, title: String, blockers: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)
	var out := []
	var eligible := 0
	for i in segs.size():
		var s: Dictionary = segs[i]
		var next_is_ramp: bool = i + 1 < segs.size() and segs[i + 1].t == "ramp"
		if s.t != "flat" or s.len < 260 or i == 0 or (i + 1 < segs.size() and segs[i + 1].t == "finish"):
			out.append(s)
			continue
		eligible += 1
		var after_jump: bool = segs[i - 1].t == "gap"
		var blocker: bool = blockers and eligible % 2 == 0 and not next_is_ramp and not after_jump and s.len >= 380
		# Blockers sit deep into the stretch so there's time to see and shoot them.
		var a: float = s.len * (0.7 if blocker else 0.45)
		out.append({"t": "flat", "len": a})
		if blocker:
			out.append({"t": "obj", "kind": BLOCKERS[biome][rng.randi() % BLOCKERS[biome].size()]})
		else:
			var pool: Array = SMASHABLES[biome]
			for k in rng.randi_range(1, 3):
				out.append({"t": "obj", "kind": pool[rng.randi() % pool.size()]})
				out.append({"t": "flat", "len": 14})
		if eligible % 3 == 0:
			out.append({"t": "flat", "len": 40})
			out.append({"t": "ammo"})
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
