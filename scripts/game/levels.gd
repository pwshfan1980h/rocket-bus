class_name Levels
## The 20 levels: 5 worlds x 4. Segment format is documented in terrain.gd.
## Gap dy is relative to the road before the ramp (negative = land higher).

const WORLDS := ["DESERT", "JUNGLE", "MOUNTAINS", "SNOW", "VOLCANO"]


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
			_f(700), _j(150, 50, 200, "chasm"), _f(600), _end()]),
		_lvl("OASIS HOP", "desert", 100, "Don't feed the bus to the oasis.", [
			_f(500), _h(300, 16), _f(300), _j(150, 50, 240, "water"), _f(500), _end()]),
		_lvl("DOUBLE TROUBLE", "desert", 100, "Two gaps. One tank. Save some fuel.", [
			_f(500), _j(140, 45, 220, "chasm"), _f(450), _fuel(), _f(100),
			_j(150, 50, 260, "water"), _f(400), _end()]),
		_lvl("MESA LEAP", "desert", 100, "The far side is higher. Burn longer.", [
			_f(400), _s(300, -50), _f(300), _j(150, 55, 300, "chasm", -30), _f(400), _h(300, 20),
			_j(140, 50, 260, "chasm", 30), _f(400), _end()]),
		# --- World 2: Jungle -------------------------------------------------------------
		_lvl("RIVER RUN", "jungle", 100, "Rivers, bugs, and one very nervous driver.", [
			_f(500), _h(400, 14, 2), _j(150, 50, 260, "water"), _f(400),
			_j(140, 45, 240, "swamp"), _f(400), _end()]),
		_lvl("SWAMP THING", "jungle", 100, "Something lives in that swamp.", [
			_f(400), _j(130, 45, 230, "swamp"), _f(350), _s(300, 40), _f(200),
			_j(150, 55, 280, "swamp", -20), _f(400), _end()]),
		_lvl("CANOPY CHASE", "jungle", 100, "Three gaps under the canopy.", [
			_f(400), _j(140, 50, 240, "chasm"), _f(300), _fuel(), _h(300, 20),
			_j(140, 50, 260, "water"), _f(300), _j(150, 55, 280, "swamp"), _f(400), _end()]),
		_lvl("TEMPLE DROP", "jungle", 100, "Nose down for the downhill landing.", [
			_f(400), _s(400, -80), _j(150, 55, 320, "chasm", 60), _s(300, 40), _f(300),
			_j(140, 50, 260, "water"), _f(250), _j(140, 50, 280, "swamp", -30), _f(400), _end()]),
		# --- World 3: Mountains ----------------------------------------------------------
		_lvl("SWITCHBACK", "mountain", 100, "Up, over, and down the mountain.", [
			_f(400), _s(400, -90), _f(200), _j(150, 55, 280, "chasm"), _f(300), _s(300, 60),
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
			_f(400), _s(300, 40), _j(150, 55, 320, "ice"), _f(300), _fuel(), _f(80),
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
			_f(400), _j(150, 50, 260, "lava"), _f(300), _j(150, 50, 280, "chasm"), _f(300),
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


static func _lvl(title: String, biome: String, fuel: float, blurb: String, segs: Array) -> Dictionary:
	var flat := []
	for s in segs:
		if s is Array:
			flat.append_array(s)
		else:
			flat.append(s)
	return {"title": title, "biome": biome, "fuel": fuel, "blurb": blurb, "segments": flat}


static func _f(length: float) -> Dictionary:
	return {"t": "flat", "len": length}


static func _h(length: float, amp: float, waves := 1) -> Dictionary:
	return {"t": "hill", "len": length, "amp": amp, "waves": waves}


static func _s(length: float, dy: float) -> Dictionary:
	return {"t": "slope", "len": length, "dy": dy}


static func _j(ramp_len: float, rise: float, gap_len: float, kind: String, dy := 0.0) -> Array:
	return [{"t": "ramp", "len": ramp_len, "rise": rise}, {"t": "gap", "len": gap_len, "kind": kind, "dy": dy}]


static func _fuel() -> Dictionary:
	return {"t": "fuel"}


static func _end() -> Dictionary:
	return {"t": "finish", "len": 300}
