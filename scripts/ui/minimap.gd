class_name Minimap
extends Control
## "Road ahead" strip for the HUD: the terrain profile from a little behind the bus
## to far ahead, with gaps (coloured by kind), ramps, fuel cans,
## the finish flag and the bus itself. Gives foresight at high speed.

const W := 200.0
const H := 26.0
const BEHIND := 350.0
const AHEAD := 2650.0
const GAP_COLORS := {
	"chasm": Color("#1a0c20"), "water": Color("#3a7ae0"), "swamp": Color("#5a8a3a"),
	"ice": Color("#9ad0ff"), "lava": Color("#ff6a1a"),
}

var terrain: Terrain
var world: World
var bus: Bus


func setup(w: World, b: Bus) -> Minimap:
	world = w
	terrain = w.terrain
	bus = b
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _process(_delta: float) -> void:
	queue_redraw()


## Little red jerry can for fuel.
func _gas_can(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 2, p.y - 7, 5, 6), Color("#ff4040"))
	draw_rect(Rect2(p.x - 1, p.y - 8, 2, 1), Color("#d8d8e0"))
	draw_rect(Rect2(p.x + 1, p.y - 8, 2, 1), Color("#303038"))


func _draw() -> void:
	if not is_instance_valid(bus) or bus.chassis == null:
		return
	var bx := bus.chassis.global_position.x
	var by := bus.chassis.global_position.y + 31.0
	var x0 := bx - BEHIND
	var span := BEHIND + AHEAD
	var sx := W / span
	var sy := 0.08  # vertical exaggeration kept small so hills read but fit
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.03, 0.1, 0.72))

	var to_screen := func(x: float, y: float) -> Vector2:
		return Vector2((x - x0) * sx, clampf(H * 0.6 + (y - by) * sy, 2.0, H - 2.0))

	# Road profile (gaps stay open and get coloured by what's in them).
	var prev := Vector2.INF
	var x := x0
	while x <= x0 + span:
		var y := terrain.surface_y(x)
		if is_nan(y):
			var g := terrain.gap_at(x)
			if not g.is_empty():
				var p: Vector2 = to_screen.call(x, g.road_y + 40)
				draw_rect(Rect2(p.x, p.y, 2, H - p.y), GAP_COLORS.get(g.kind, Color.BLACK))
			prev = Vector2.INF
		else:
			var p: Vector2 = to_screen.call(x, y)
			if prev != Vector2.INF:
				draw_line(prev, p, Color("#d8cfc0"), 1.0)
			draw_rect(Rect2(p.x, p.y + 1, 2, H - p.y - 1), Color(0.5, 0.45, 0.5, 0.35))
			prev = p
		x += 10.0

	for r in terrain.ramps:  # ramp lips as bright ticks
		if r.lip_x > x0 and r.lip_x < x0 + span:
			var p: Vector2 = to_screen.call(r.lip_x, r.top_y)
			draw_rect(Rect2(p.x - 1, p.y - 1, 2, 3), Color("#ffc828"))
	for p0 in terrain.pickups:
		if p0.x > x0 and p0.x < x0 + span:
			_gas_can(to_screen.call(p0.x, p0.y + 30))
	if terrain.finish_x > x0 and terrain.finish_x < x0 + span:
		var p: Vector2 = to_screen.call(terrain.finish_x, terrain.surface_y(terrain.finish_x))
		draw_rect(Rect2(p.x, p.y - 8, 1, 8), Color.WHITE)
		for k in 2:
			draw_rect(Rect2(p.x + 1 + k * 2, p.y - 8, 2, 2), Color.WHITE if k == 0 else Color.BLACK)
			draw_rect(Rect2(p.x + 1 + k * 2, p.y - 6, 2, 2), Color.BLACK if k == 0 else Color.WHITE)
	# The bus.
	var bp: Vector2 = to_screen.call(bx, bus.chassis.global_position.y + 20)
	draw_rect(Rect2(bp.x - 2, bp.y - 3, 5, 3), Color("#ffcc26"))
	draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.25), false, 1.0)
