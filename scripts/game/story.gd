class_name Story
## STORY MODE: "ROUTE 99". The driver's last week before retirement, on the route
## nobody finishes. Seven hand-built legs across three worlds (city, desert,
## jungle) with two forks. Each leg has a job: pick people up on hills, tow a
## trailer, outrun a mudslide, keep the passengers happy.
##
## Leg fields: title, biome, blurb, radio (dispatch lines before the leg), riders
## (aboard at the start), fuel, segments (terrain.gd format), next (leg ids; two =
## a fork, none = the end), plus optional trailer (cargo), chase, weather, requests
## [{"who", "want": "front_flip" | "no_flips" | "big_air", "tip"}].
##
## Difficulty climbs along the route: FIRST SHIFT has short gaps and a flat first
## stop; the forks add one new job each (trailer / steep stops); the jungle legs
## combine jobs and lengthen gaps; THE LAST STOP asks for everything at once.
## The whole route is played on LIVES lives (see GameState.story).

const LIVES := 7

const FIRST := "depot"
const ENDINGS := {
	"perfect": {"title": "PERFECT SHIFT", "lines": [
		"EVERY RIDER HOME. EVERY CARGO DELIVERED.",
		"DISPATCH NAMES ROUTE 99 AFTER YOU.",
		"YOU RETIRE A LEGEND. THE BUS DOES NOT.",
	]},
	"party": {"title": "THE RETIREMENT PARTY", "lines": [
		"A FEW RIDERS WALKED. MOST MADE IT.",
		"THE DEPOT THROWS YOU A PARTY ANYWAY.",
		"THE CAKE IS ONLY A LITTLE SQUASHED.",
	]},
}

## Map layout: leg id -> position on the story map (screen px).
const MAP := {
	"depot": Vector2(52, 118), "water": Vector2(146, 74), "canyon": Vector2(146, 162),
	"river": Vector2(240, 118), "temple": Vector2(334, 74), "mudslide": Vector2(334, 162),
	"home": Vector2(428, 118),
}

static var _legs := {}


static func ids() -> Array:
	return MAP.keys()


static func leg(id: String) -> Dictionary:
	if _legs.is_empty():
		_legs = _all()
	return _legs.get(id, {})


static func _all() -> Dictionary:
	return {
		"depot": {
			"title": "FIRST SHIFT", "biome": "city@dawn", "fuel": 100.0, "riders": 1,
			"blurb": "Stop in the yellow box. Hold BRAKE while they board.",
			"radio": ["DISPATCH TO BUS 99. MORNING.", "PICK UP AT THE DEPOT, THEN HILL STREET.",
				"STOP IN THE BOX AND HOLD THE BRAKE. NO ROLLING."],
			"next": ["water", "canyon"],
			"segments": [_f(500), _stop(240, 0, 1, 0, "DEPOT"), _f(460), _ramp(150, 50), _gap(250, "chasm"),
				_f(460), _slope(320, -40), _f(120), _stop(260, -34, 2, 0, "HILL ST"), _slope(220, -16), _f(400),
				_ramp(150, 50), _gap(270, "water", 10), _f(520), _finish()],
		},
		"water": {
			"title": "WATER RUN", "biome": "desert@noon", "fuel": 110.0, "riders": 2, "trailer": "water",
			"blurb": "Tow the tank. Rough landing? Back up and re-hook.",
			"radio": ["THE DESERT TOWN'S WELL IS DRY.", "TOW THEM A TANK OF WATER.",
				"IF THE HITCH SNAPS, BACK UP TO IT. IT'LL HOOK ITSELF."],
			"next": ["river"],
			"segments": [_f(600), _hill(420, 12), _f(380), _ramp(160, 52), _gap(280, "chasm"), _f(520),
				_kicker(), _f(400), _fuel(), _f(300), _ramp(160, 55), _gap(300, "water", 30),
				_landing(380, 90), _f(320), {"t": "checkpoint"}, _f(360), _slope(340, -50), _f(380),
				_ramp(160, 55), _gap(290, "chasm"), _f(560), _finish()],
		},
		"canyon": {
			"title": "CANYON STOPS", "biome": "desert", "fuel": 100.0, "riders": 3,
			"blurb": "Steep stops on the switchbacks. Don't roll back.",
			"radio": ["THE CANYON LINE. THREE STOPS, ALL ON HILLS.", "MESA VIEW: ONE GETS OFF.",
				"CLIFF TOP: TWO GET ON. THEN THE ROCK GARDEN."],
			"next": ["river"],
			"segments": [_f(600), _slope(300, 60), _stop(260, 70, 0, 1, "MESA VIEW"), _slope(200, 20), _f(380),
				_ramp(150, 50), _gap(290, "chasm"), _f(420), _slope(300, -60), _stop(240, -64, 2, 0, "CLIFF TOP"),
				_slope(200, -20), _f(340), _fuel(), _f(260), _ramp(160, 55), _gap(300, "chasm", 40),
				_landing(360, 80), _f(300), _stop(220, 30, 1, 1, "ROCK GARDEN"), _f(400), _ramp(150, 50),
				_gap(280, "water"), _f(520), _finish()],
		},
		"river": {
			"title": "RIVER CROSSING", "biome": "jungle", "weather": "rain", "fuel": 110.0, "riders": 3,
			"trailer": "canoe", "requests": [{"who": "KID", "want": "front_flip", "tip": 1500}],
			"blurb": "Tow the canoe across. The kid wants a front flip.",
			"radio": ["RIVER'S UP. THE FERRY'S SUNK.", "TOW THE RANGER'S CANOE TO THE FAR BANK.",
				"AND THE KID IN ROW 3 WON'T STOP ASKING FOR A FRONT FLIP."],
			"next": ["temple", "mudslide"],
			"segments": [_f(600), _ramp(160, 52), _gap(290, "water"), _f(360), _kicker(24), _f(420),
				_hill(480, 14), _fuel(), _f(320), _ramp(160, 55), _gap(300, "swamp", 30), _landing(360, 90),
				_f(300), {"t": "checkpoint"}, _f(300), _kicker(26), _f(420), _ramp(160, 55),
				_gap(300, "water"), _f(560), _finish()],
		},
		"temple": {
			"title": "TEMPLE SHORTCUT", "biome": "jungle@night", "fuel": 100.0, "riders": 4,
			"requests": [{"who": "GRANDMA", "want": "no_flips", "tip": 1200}],
			"blurb": "Dark, steep, and Grandma says NO FLIPS.",
			"radio": ["SHORTCUT THROUGH THE OLD TEMPLE ROAD.", "IT'S DARK. HEADLIGHTS ON.",
				"GRANDMA'S ABOARD. SHE SAYS NO FLIPS. SHE MEANS IT."],
			"next": ["home"],
			"segments": [_f(600), _slope(300, 70), _stop(260, 80, 0, 2, "TEMPLE GATE"), _slope(200, 20), _f(380),
				_ramp(150, 50), _gap(290, "chasm"), _f(420), _kicker(20), _f(380), _fuel(), _f(260),
				_slope(320, -60), _stop(220, -56, 1, 0, "STATUE"), _slope(200, -20), _f(360),
				_ramp(160, 55), _gap(300, "swamp", 30), _landing(360, 90), _f(520), _finish()],
		},
		"mudslide": {
			"title": "MUDSLIDE", "biome": "jungle", "weather": "rain", "fuel": 110.0, "riders": 4,
			"chase": {"start": -950.0, "speed": 175.0, "accel": 5.0},
			"blurb": "The hill is coming down behind you. DRIVE.",
			"radio": ["DISPATCH TO 99, THE HILLSIDE IS MOVING!", "MUDSLIDE RIGHT BEHIND YOU.",
				"DON'T STOP FOR ANYTHING."],
			"next": ["home"],
			"segments": [_f(500), _slope(400, 60), _f(300), _ramp(150, 50), _gap(270, "chasm"), _f(420),
				{"t": "mud", "len": 200}, _f(300), _ramp(160, 52), _gap(290, "swamp"), _f(360), _fuel(),
				_f(200), _slope(360, 70), _f(260), _ramp(160, 55), _gap(300, "water", 20), _f(380),
				{"t": "mud", "len": 220}, _f(320), _ramp(160, 55), _gap(290, "chasm"), _f(600), _finish()],
		},
		"home": {
			"title": "THE LAST STOP", "biome": "city@night", "fuel": 110.0, "riders": 2, "trailer": "cake",
			"blurb": "Tow the cake. Pick up the guests. Land soft.",
			"radio": ["LAST RUN, 99. THEY'RE THROWING YOU A PARTY.", "TOW THE CAKE. GRAB TWO GUESTS ON HILL ROAD.",
				"LAND SOFT. IT'S A VERY TALL CAKE."],
			"next": [],
			"segments": [_f(600), _ramp(150, 50), _gap(280, "water"), _f(420), _slope(300, -55),
				_stop(240, -50, 2, 0, "HILL ROAD"), _slope(200, -20), _f(360), _fuel(), _f(260),
				_ramp(160, 55), _gap(300, "chasm", 30), _landing(360, 80), _f(340), {"t": "checkpoint"},
				_f(300), _kicker(20), _f(400), _ramp(160, 55), _gap(290, "water"), _f(600), _finish()],
		},
	}


## Which ending a finished route earns.
static func ending(state: Dictionary) -> Dictionary:
	return ENDINGS.perfect if state.get("walked", 0) == 0 and state.get("lost_cargo", 0) == 0 else ENDINGS.party


static func _f(length: float) -> Dictionary:
	return {"t": "flat", "len": length}


static func _hill(length: float, amp: float) -> Dictionary:
	return {"t": "hill", "len": length, "amp": amp}


static func _slope(length: float, dy: float) -> Dictionary:
	return {"t": "slope", "len": length, "dy": dy}


static func _landing(length: float, dy: float) -> Dictionary:
	return {"t": "landing", "len": length, "dy": dy}


static func _ramp(length: float, rise: float) -> Dictionary:
	return {"t": "ramp", "len": length, "rise": rise}


static func _gap(length: float, kind: String, dy := 0.0) -> Dictionary:
	return {"t": "gap", "len": length, "kind": kind, "dy": dy}


static func _kicker(rise := 20.0) -> Dictionary:
	return {"t": "kicker", "len": 90.0, "rise": rise}


static func _stop(length: float, dy: float, board: int, drop: int, stop_name: String) -> Dictionary:
	return {"t": "stop", "len": length, "dy": dy, "board": board, "drop": drop, "name": stop_name}


static func _fuel() -> Dictionary:
	return {"t": "fuel"}


static func _finish() -> Dictionary:
	return {"t": "finish", "len": 300}
