class_name Grading
## Turns a finished run into Speed stars, Technique stars and an overall grade.
##   Speed      0-3: time vs. par
##   Technique  0-3: landing quality, style (flips - front flips count double -, big air, close calls), minus retries
##   Grade      SS S A B C D E F FF from speed + technique + bonuses.
## A comet exit (leaving the level soaring) adds a big bonus and never grades below C.

const GRADES := ["FF", "F", "E", "D", "C", "B", "A", "S", "SS"]
const COMET_BONUS := 1.5
const LANDING_VALUE := {"perfect": 1.0, "good": 0.65, "hard": 0.15}


## Par time (seconds) for a level: road length at a brisk average speed.
static func par_time(finish_x: float) -> float:
	return finish_x / 300.0


static func speed_stars(time: float, par: float) -> int:
	var r := par / maxf(time, 0.01)
	if r >= 1.0:
		return 3
	if r >= 0.85:
		return 2
	if r >= 0.7:
		return 1
	return 0


static func technique_stars(landings: Array, retries: int, style: Dictionary) -> int:
	var q := 0.0
	for l in landings:
		q += LANDING_VALUE.get(l, 0.0)
	q = q / maxf(1.0, landings.size())
	q += 0.08 * (style.get("flips", 0) + style.get("front", 0)) + 0.06 * style.get("close", 0) + (0.1 if style.get("air", 0.0) > 2.0 else 0.0)
	q -= 0.2 * retries
	if q >= 0.85:
		return 3
	if q >= 0.6:
		return 2
	if q >= 0.35:
		return 1
	return 0


static func style_bonus(style: Dictionary) -> float:
	return clampf(0.25 * (style.get("flips", 0) + style.get("front", 0)) + 0.2 * style.get("close", 0) + (0.3 if style.get("air", 0.0) > 2.0 else 0.0), 0.0, 1.0)


static func grade(speed: int, technique: int, bonus: float, comet: bool, retries: int) -> String:
	var pts := speed + technique + bonus + (COMET_BONUS if comet else 0.0) - 0.5 * retries
	var g := "FF"
	for pair in [[6.5, "SS"], [5.8, "S"], [5.0, "A"], [4.0, "B"], [3.0, "C"], [2.0, "D"], [1.2, "E"], [0.5, "F"]]:
		if pts >= pair[0]:
			g = pair[1]
			break
	if comet and rank(g) < rank("C"):
		g = "C"
	return g


static func rank(g: String) -> int:
	return GRADES.find(g)


static func is_good(g: String) -> bool:
	return rank(g) >= rank("C")


static func color(g: String) -> Color:
	return {
		"SS": Color.WHITE, "S": Color("#ffcc26"), "A": Color("#7dff6a"), "B": Color("#3cf0dc"),
		"C": Color("#e8e0f0"), "D": Color("#ff9a2e"), "E": Color("#ff5a4e"), "F": Color("#ff3b4e"),
		"FF": Color("#a01828"),
	}.get(g, Color.WHITE)
