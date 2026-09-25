extends StaticBody2D
## Test track: a long road, one wooden ramp, and end barriers. Draws itself.

const ROAD_TOP := 0.0
const LEFT := -1500.0
const RIGHT := 5000.0
const RAMP := [Vector2(900, 0), Vector2(1060, -58), Vector2(1076, -58), Vector2(1076, 0)]

const ASPHALT := Color8(58, 52, 72)
const ASPHALT_EDGE := Color8(104, 98, 122)
const LANE := Color8(255, 208, 60)
const CURB := Color8(150, 132, 150)
const CURB_D := Color8(96, 82, 104)
const DIRT := Color8(62, 34, 58)
const DIRT_D := Color8(44, 24, 44)
const PLANK := Color8(184, 118, 62)
const PLANK_D := Color8(116, 66, 38)
const HAZARD := Color8(255, 200, 40)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	physics_material_override = mat
	_add_poly([
		Vector2(LEFT - 20, -300), Vector2(LEFT, -300), Vector2(LEFT, ROAD_TOP),
		Vector2(RIGHT, ROAD_TOP), Vector2(RIGHT, -300), Vector2(RIGHT + 20, -300),
		Vector2(RIGHT + 20, 400), Vector2(LEFT - 20, 400),
	])
	_add_poly(RAMP)


func _add_poly(points: Array) -> void:
	var p := CollisionPolygon2D.new()
	p.polygon = PackedVector2Array(points)
	add_child(p)


func _draw() -> void:
	var w := RIGHT - LEFT
	draw_rect(Rect2(LEFT, 14, w, 400), DIRT)
	for x in range(int(LEFT), int(RIGHT), 16):  # brick seams in the retaining wall
		var row_off := 8 if (x / 16) % 2 else 0
		draw_rect(Rect2(x + row_off, 22, 1, 6), DIRT_D)
		draw_rect(Rect2(x, 28, 16, 1), DIRT_D)
		draw_rect(Rect2(x + 8 - row_off, 29, 1, 6), DIRT_D)
	draw_rect(Rect2(LEFT, 10, w, 4), CURB)
	draw_rect(Rect2(LEFT, 13, w, 1), CURB_D)
	draw_rect(Rect2(LEFT, 0, w, 10), ASPHALT)
	draw_rect(Rect2(LEFT, 0, w, 1), ASPHALT_EDGE)
	for x in range(int(LEFT), int(RIGHT), 22):
		draw_rect(Rect2(x, 4, 12, 2), LANE)
	for x in [LEFT - 20, RIGHT]:  # end barriers
		draw_rect(Rect2(x, -300, 20, 300), CURB_D)
		for y in range(-300, 0, 12):
			draw_rect(Rect2(x, y, 20, 6), HAZARD)

	# Ramp: plank deck on struts, hazard lip.
	draw_colored_polygon(PackedVector2Array(RAMP), PLANK_D)
	var a: Vector2 = RAMP[0]
	var b: Vector2 = RAMP[1]
	for i in range(0, 17):
		var t := i / 16.0
		var top := a.lerp(b, t)
		draw_line(top, Vector2(top.x, 0), PLANK_D.darkened(0.3), 1.0)
	draw_line(a, b, PLANK, 3.0)
	for i in range(0, 16, 2):
		var p0 := a.lerp(b, i / 16.0)
		draw_line(p0, p0 + Vector2(0, 3), PLANK_D, 1.0)
	draw_rect(Rect2(1060, -58, 16, 3), PLANK)
	for y in range(-58, 0, 6):
		draw_rect(Rect2(1072, y, 4, 3), HAZARD)
