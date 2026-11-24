class_name BusShadow
extends Node2D
## A soft shadow on the road straight below the bus. It shrinks and fades as the
## bus climbs and sharpens as it comes down, so you can judge a landing.
## While airborne, a subtle colored rim signals alignment with the road slope
## below: green (perfect), amber (hard), red (wreck angle).

const MAX_H := 520.0

var terrain: Terrain
var bus: Bus


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(bus) or bus.chassis == null or bus.is_crashed:
		return
	var c := bus.chassis.global_position
	var ground := terrain.surface_y(c.x)
	if is_nan(ground):
		return
	var h := clampf(ground - c.y - 22.0, 0.0, MAX_H)
	var t := h / MAX_H
	var half := roundf(58.0 * (1.0 - t * 0.55))
	var a := 0.42 * (1.0 - t) + 0.08
	for row in 3:  # a flat pixel ellipse: three stacked bars, narrower at the edges
		var w: float = half - (0.0 if row == 1 else 10.0) - t * 6.0
		draw_rect(Rect2(roundf(c.x - w), roundf(ground) - 2 + row, w * 2.0, 1), Color(0, 0, 0, a))
	if bus.airborne and h > 14.0:
		var y_l := terrain.surface_y(c.x - 18.0)
		var y_r := terrain.surface_y(c.x + 18.0)
		var slope_angle := 0.0 if (is_nan(y_l) or is_nan(y_r)) else atan2(y_r - y_l, 36.0)
		var err := absf(rad_to_deg(angle_difference(slope_angle, bus.chassis.rotation)))
		var col := Color("#7dff6a") if err < bus.perfect_angle else (
				Color("#d8f8ff") if err < bus.hard_angle else (
				Color("#ff9a2e") if err < bus.crash_angle else Color("#ff3b4e")))
		col.a = clampf(0.85 * (1.0 - t * 0.55), 0.25, 0.85)
		var rw := maxf(10.0, half - 4.0)
		draw_rect(Rect2(roundf(c.x - rw), roundf(ground) - 3, rw * 2.0, 2), col)
