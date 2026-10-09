class_name HighwayWall
extends Node2D
## A segmented concrete sound wall along the back edge of a city road: light
## panels with a capped top, dark joints and rain stains, some tagged with
## graffiti. It sits behind the road so the bus reads clearly against it instead
## of against the busy skyline. Gaps, ramps and bus stops leave it open.

const PANEL := 46.0
const HEIGHT := 26.0
const CONCRETE := Color("#9a96a0")
const CAP := Color("#b4b0ba")
const JOINT := Color("#4a4652")
const STAIN := Color("#7e7a86")
const PAINT: Array[Color] = [Color("#ff4aa8"), Color("#3cf0dc"), Color("#ffd23a"), Color("#8aff5a"),
	Color("#f4f4f4"), Color("#ff8a2a"), Color("#a46aff"), Color("#ff3b4e")]
const WORDS := ["RKT", "B99", "ZOOM", "BUSX", "KRWN", "VAN", "DUB", "ZAP", "YO", "MAX", "OKE", "NITE",
	"KAOS", "SK8", "RAD", "VYBE", "99X", "BLAM", "WOOF", "LUX"]

var terrain: Terrain
var _panels: Array[Dictionary] = []  # {x, tag}


func setup(t: Terrain) -> HighwayWall:
	terrain = t
	return self


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(terrain.end_x) + 7
	var x := -Terrain.RUNWAY
	while x < terrain.end_x:
		if _open(x) and _open(x + PANEL):
			var tag := {}
			if rng.randf() < 0.38:
				tag = {"word": WORDS[rng.randi() % WORDS.size()], "fill": PAINT[rng.randi() % PAINT.size()],
					"edge": PAINT[rng.randi() % PAINT.size()], "tilt": rng.randf_range(-0.18, 0.12),
					"dx": rng.randf_range(4, 14), "drips": rng.randi_range(0, 3), "seed": rng.randi(),
					"scribble": rng.randf() < 0.35}
			_panels.append({"x": x, "tag": tag, "stain": rng.randf_range(0.2, 0.8)})
		x += PANEL


## True where a wall panel may stand: solid flat road, not a ramp, gap or stop.
func _open(x: float) -> bool:
	if is_nan(terrain.ground_y(x)):
		return false
	for s in terrain.stops:
		if x > s.x0 - 40 and x < s.x1 + 40:
			return false
	return absf(x - terrain.finish_x) > 80 or terrain.finish_x <= 0.0


func _draw() -> void:
	for p in _panels:
		var x0: float = p.x
		var x1 := x0 + PANEL - 2
		var y0 := terrain.ground_y(x0)
		var y1 := terrain.ground_y(x1)
		var face := PackedVector2Array([Vector2(x0, y0 + 2), Vector2(x0, y0 - HEIGHT), Vector2(x1, y1 - HEIGHT),
			Vector2(x1, y1 + 2)])
		draw_colored_polygon(face, CONCRETE)
		# Rain stains running down from the cap, and a darker foot where the road spray hits.
		var sx := lerpf(x0 + 4, x1 - 8, p.stain)
		var sy := lerpf(y0, y1, (sx - x0) / PANEL)
		draw_rect(Rect2(sx, sy - HEIGHT + 3, 3, 12), STAIN)
		draw_rect(Rect2(sx + 1, sy - HEIGHT + 15, 1, 5), STAIN)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, y0 - 4), Vector2(x1, y1 - 4), Vector2(x1, y1 + 2),
			Vector2(x0, y0 + 2)]), STAIN)
		# The cap along the top, and the joint to the next panel.
		draw_colored_polygon(PackedVector2Array([Vector2(x0 - 1, y0 - HEIGHT - 3), Vector2(x1 + 1, y1 - HEIGHT - 3),
			Vector2(x1 + 1, y1 - HEIGHT), Vector2(x0 - 1, y0 - HEIGHT)]), CAP)
		draw_rect(Rect2(x1, y1 - HEIGHT - 3, 2, HEIGHT + 5), JOINT)
		if not p.tag.is_empty():
			_draw_tag(p.tag, Vector2(x0 + p.tag.dx, lerpf(y0, y1, 0.3) - 9))


## A tag: an outlined word, sometimes with a looping scribble under it, and drips.
func _draw_tag(t: Dictionary, at: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed
	var font := PixelFont.get_font()
	var fill: Color = t.fill
	draw_set_transform(at, t.tilt)
	if t.scribble:
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(Vector2(k * 3.5, 3 + sin(k * 1.9) * 2.5 + rng.randf_range(-1, 1)))
		draw_polyline(pts, t.edge, 1.0)
	draw_string_outline(font, Vector2(0, 0), t.word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color("#1a1020"))
	draw_string_outline(font, Vector2(0, 0), t.word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 1, t.edge)
	draw_string(font, Vector2(0, 0), t.word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, fill)
	for k in t.drips:
		var dx := rng.randf_range(1, t.word.length() * 8 - 2)
		draw_rect(Rect2(roundf(dx), 1, 1, rng.randf_range(3, 8)), fill)
	draw_set_transform(Vector2.ZERO)
