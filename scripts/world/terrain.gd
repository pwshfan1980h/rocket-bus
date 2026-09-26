class_name Terrain
extends Node2D
## Builds a level's road from a list of segments: drivable islands (with
## collision), wooden ramps, and the gaps between them.
##
## Segments (lengths in px, +y is down):
##   {"t": "flat", "len": 400}
##   {"t": "hill", "len": 300, "amp": 20, "waves": 1}   smooth bumps
##   {"t": "slope", "len": 300, "dy": -60}              ease up/down
##   {"t": "ramp", "len": 150, "rise": 50}              must be followed by a gap
##   {"t": "gap", "len": 240, "dy": 0, "kind": "chasm"} kind: chasm|water|swamp|ice|lava
##   {"t": "fuel"}                                      fuel can at this spot
##   {"t": "finish", "len": 300}                        bus stop + finish line

const SHADER := preload("res://assets/shaders/terrain.gdshader")
const RUNWAY := 400.0  # road behind the start line
const DEPTH := 700.0
const LIQUIDS := ["water", "swamp", "ice", "lava"]

var biome: Dictionary
var islands: Array[Dictionary] = []
var gaps: Array[Dictionary] = []
var ramps: Array[Dictionary] = []
var pickups: Array[Vector2] = []
var signs: Array[Vector2] = []
var finish_x := 0.0
var end_x := 0.0
var road_top := 0.0  # highest road point (smallest y)
var road_bottom := 0.0

var _x := 0.0
var _y := 0.0
var _road_y := 0.0  # road height ignoring ramps
var _cur: PackedVector2Array
var _cur_ramps: Array = []
var _time := 0.0
var _barriers: Array[Vector2] = []


func build(segments: Array, biome_name: String) -> Terrain:
	biome = Biomes.get_biome(biome_name)
	_x = -RUNWAY
	_cur = PackedVector2Array([Vector2(_x, 0)])
	_add_flat(RUNWAY)
	for seg in segments:
		match seg.t:
			"flat":
				_add_flat(seg.len)
			"hill":
				var y0 := _y
				_add_curve(seg.len, func(t): return y0 - seg.amp * (1.0 - cos(TAU * seg.get("waves", 1) * t)) / 2.0)
			"slope":
				var y0 := _y
				_add_curve(seg.len, func(t): return y0 + seg.dy * (1.0 - cos(PI * t)) / 2.0)
				_road_y = _y
			"ramp":
				var base := _y
				var x0 := _x
				# Ends at the peak: a flat lip would drop the front wheels and pitch the bus nose-down.
				_add_point(_x + seg.len, _y - seg.rise)
				var r := {"x0": x0, "x1": x0 + seg.len, "lip_x": _x, "top_y": _y, "base_y": base}
				ramps.append(r)
				_cur_ramps.append(r)
				signs.append(Vector2(x0 - 150, base))
			"gap":
				_close_island()
				var lip_y := _y
				var land_y: float = _road_y + seg.get("dy", 0.0)
				var kind: String = seg.get("kind", "chasm")
				var low := maxf(_road_y, land_y)
				var gap := {
					"x0": _x, "x1": _x + seg.len, "lip_y": lip_y, "road_y": _road_y,
					"land_y": land_y, "kind": kind, "index": gaps.size(),
					"liquid_y": low + 46.0,
				}
				gap.trigger_y = gap.liquid_y - 26.0 if kind in LIQUIDS else low + 170.0
				gaps.append(gap)
				_x += seg.len
				_y = land_y
				_road_y = land_y
				_cur = PackedVector2Array([Vector2(_x, _y)])
			"fuel":
				pickups.append(Vector2(_x, _y - 30))
			"finish":
				finish_x = _x + 90
				_add_flat(seg.len)
	_add_flat(500)
	end_x = _x
	_close_island()
	_add_barrier(-RUNWAY)
	_add_barrier(end_x - 20)
	for isl in islands:
		for p in isl.pts:
			road_top = minf(road_top, p.y)
			road_bottom = maxf(road_bottom, p.y)
	_build_nodes()
	return self


func _add_barrier(x: float) -> void:
	var y := surface_y(x + 10)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 400)
	cs.shape = rect
	cs.position = Vector2(x + 10, y - 200)
	wall.add_child(cs)
	add_child(wall)
	_barriers.append(Vector2(x, y))


## Road height at x (the island's collision surface), or NAN over a gap.
func surface_y(x: float) -> float:
	for isl in islands:
		if x >= isl.x0 and x <= isl.x1:
			var pts: PackedVector2Array = isl.pts
			for i in pts.size() - 1:
				if x <= pts[i + 1].x:
					var t := (x - pts[i].x) / maxf(0.001, pts[i + 1].x - pts[i].x)
					return lerpf(pts[i].y, pts[i + 1].y, t)
	return NAN


## Road height ignoring ramps (where decorations may stand).
func ground_y(x: float) -> float:
	for r in ramps:
		if x >= r.x0 - 4 and x <= r.lip_x + 4:
			return NAN
	return surface_y(x)


func gap_at(x: float) -> Dictionary:
	for g in gaps:
		if x > g.x0 and x < g.x1:
			return g
	return {}


func start_position() -> Vector2:
	return Vector2(0, surface_y(0) - 31)


# --- Build helpers -------------------------------------------------------------

func _add_point(x: float, y: float) -> void:
	_x = x
	_y = y
	if x > _cur[-1].x:
		_cur.append(Vector2(x, y))


func _add_flat(length: float) -> void:
	_add_point(_x + length, _y)


func _add_curve(length: float, fn: Callable) -> void:
	var x0 := _x
	var steps := maxi(2, int(length / 8))
	for i in range(1, steps + 1):
		var t := float(i) / steps
		_add_point(x0 + length * t, fn.call(t))


func _close_island() -> void:
	islands.append({"pts": _cur, "x0": _cur[0].x, "x1": _cur[-1].x, "ramps": _cur_ramps})
	_cur_ramps = []


func _build_nodes() -> void:
	var g: Dictionary = biome.ground
	var gaps_node := Node2D.new()
	gaps_node.name = "Gaps"
	gaps_node.draw.connect(_draw_gap_walls.bind(gaps_node))
	add_child(gaps_node)
	for gap in gaps:
		if gap.kind in LIQUIDS:
			var liquid := GapLiquid.new()
			liquid.setup(gap)
			add_child(liquid)

	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for i in 4:
		mat.set_shader_parameter("c%d" % i, Color(g.body[i % g.body.size()]))
	mat.set_shader_parameter("depth_start", road_bottom + 40.0)
	var phys := PhysicsMaterial.new()
	phys.friction = biome.friction
	for isl in islands:
		var ground := _ground_line(isl)
		var bottom := road_bottom + DEPTH
		var body := Polygon2D.new()
		var poly := ground.duplicate()
		poly.append(Vector2(isl.x1, bottom))
		poly.append(Vector2(isl.x0, bottom))
		body.polygon = poly
		if Geometry2D.triangulate_polygon(poly).is_empty():
			push_warning("terrain body triangulation failed: island %d..%d, %d pts" % [isl.x0, isl.x1, poly.size()])
		body.material = mat
		add_child(body)
		add_child(_strip(ground, 8.0, 11.0, Color(g.shoulder)))
		add_child(_strip(ground, 0.0, 8.0, Color(g.road)))
		var edge := Line2D.new()
		edge.points = ground
		edge.width = 1.0
		edge.default_color = Color(g.edge)
		add_child(edge)
		add_child(_collision(isl, bottom, phys))
	var overlay := Node2D.new()
	overlay.name = "Overlay"
	overlay.draw.connect(_draw_overlay.bind(overlay))
	add_child(overlay)


## Surface with ramps flattened back to road level (what the dirt body follows).
func _ground_line(isl: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in isl.pts:
		var y: float = p.y
		for r in isl.ramps:
			if p.x > r.x0 and p.x <= r.lip_x:
				y = r.base_y
		out.append(Vector2(p.x, y))
	return out


func _strip(line: PackedVector2Array, top: float, bottom: float, color: Color) -> Polygon2D:
	var poly := PackedVector2Array()
	for p in line:
		poly.append(p + Vector2(0, top))
	for i in range(line.size() - 1, -1, -1):
		poly.append(line[i] + Vector2(0, bottom))
	var p2 := Polygon2D.new()
	p2.polygon = poly
	p2.color = color
	return p2


func _collision(isl: Dictionary, bottom: float, phys: PhysicsMaterial) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = phys
	var pts: PackedVector2Array = isl.pts
	var i := 0
	while i < pts.size() - 1:
		# Merge runs of equal slope into one convex strip.
		var j := i + 1
		var slope := (pts[j].y - pts[i].y) / maxf(0.001, pts[j].x - pts[i].x)
		while j + 1 < pts.size():
			var s2 := (pts[j + 1].y - pts[j].y) / maxf(0.001, pts[j + 1].x - pts[j].x)
			if absf(s2 - slope) > 0.002:
				break
			j += 1
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([pts[i], pts[j], Vector2(pts[j].x, bottom), Vector2(pts[i].x, bottom)])
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
		i = j
	return body


func _draw_overlay(n: Node2D) -> void:
	var g: Dictionary = biome.ground
	var line_col := Color(g.line) if g.line != "" else Color.TRANSPARENT
	for isl in islands:
		var ground := _ground_line(isl)
		# Dashed center line on the road.
		if line_col.a > 0.0:
			var x: float = isl.x0 + 10.0
			while x < isl.x1 - 16:
				var y := _line_y(ground, x)
				var y2 := _line_y(ground, x + 12)
				n.draw_line(Vector2(x, y + 4), Vector2(x + 12, y2 + 4), line_col, 2.0)
				x += 24
		# Cliff faces at the island ends.
		var dark := Color(g.body[0]).darkened(0.45)
		for end in [isl.x0, isl.x1]:
			var top := _line_y(ground, end)
			var dir := 1.0 if end == isl.x0 else -1.0
			for k in 60:
				var y := top + 11 + k * 6
				var w := 3.0 + float((k * 7) % 4)
				n.draw_rect(Rect2(end if dir > 0 else end - w, y, w, 6), dark)
	for r in ramps:
		_draw_ramp(n, r)
	for b in _barriers:
		n.draw_rect(Rect2(b.x, b.y - 40, 20, 40), Color("#2a2430"))
		for k in 5:
			n.draw_rect(Rect2(b.x, b.y - 40 + k * 8, 20, 4), Color("#ffc828"))


func _draw_ramp(n: Node2D, r: Dictionary) -> void:
	var plank := Color("#b87a3e")
	var plank_d := Color("#744626")
	var poly := PackedVector2Array([
		Vector2(r.x0, r.base_y), Vector2(r.x1, r.top_y), Vector2(r.lip_x, r.top_y), Vector2(r.lip_x, r.base_y),
	])
	n.draw_colored_polygon(poly, plank_d)
	for i in 12:  # support struts
		var t := (i + 0.5) / 12.0
		var x := lerpf(r.x0, r.x1, t)
		var y := lerpf(r.base_y, r.top_y, t)
		n.draw_line(Vector2(x, y + 2), Vector2(x, r.base_y), plank_d.darkened(0.35), 1.0)
		if i % 3 == 1:
			n.draw_line(Vector2(x, y + 2), Vector2(x + 12, r.base_y), plank_d.darkened(0.2), 1.0)
	n.draw_line(Vector2(r.x0, r.base_y), Vector2(r.x1, r.top_y), plank, 3.0)
	for y in range(int(r.top_y), int(r.base_y), 6):  # hazard stripes on the lip
		n.draw_rect(Rect2(r.lip_x - 4, y, 4, 3), Color("#ffc828"))
		n.draw_rect(Rect2(r.lip_x - 4, y + 3, 4, 3), Color("#1a1420"))


func _draw_gap_walls(node: Node2D) -> void:
	var g: Dictionary = biome.ground
	for gap in gaps:
		var top := minf(gap.road_y, gap.land_y) + 14.0
		var far := Color(g.body[1]).darkened(0.6)
		node.draw_rect(Rect2(gap.x0, top, gap.x1 - gap.x0, road_bottom + DEPTH - top), far)
		for k in 8:  # fade into the abyss
			var y := top + 30 + k * 24
			node.draw_rect(Rect2(gap.x0, y, gap.x1 - gap.x0, 24), Color(0, 0, 0, 0.12 * (k + 1)))
		for k in int((gap.x1 - gap.x0) / 10):  # jagged far-wall highlights
			var x: float = gap.x0 + k * 10 + 3
			node.draw_rect(Rect2(x, top + (k * 13) % 30, 2, 18), far.lightened(0.12))


func _line_y(line: PackedVector2Array, x: float) -> float:
	for i in line.size() - 1:
		if x <= line[i + 1].x:
			var t := (x - line[i].x) / maxf(0.001, line[i + 1].x - line[i].x)
			return lerpf(line[i].y, line[i + 1].y, t)
	return line[-1].y
