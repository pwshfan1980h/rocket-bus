class_name Trailer
extends Node2D
## A one-axle trailer towed on a long draw bar (clear of the rocket flame). Its
## hitch snaps on a hard landing; back the bus up to the tongue to hook it again.
##
##   body (RigidBody2D) --PinJoint2D--> wheel     body --PinJoint2D (hitch)--> bus chassis
##
## cargo: "water" | "canoe" | "cake" (just looks; they all tow the same).

signal hooked
signal unhooked

const BUS_HITCH := Vector2(-44, 17)  ## on the bus chassis, under the rear bumper
const TONGUE := Vector2(74, 1)  ## hitch eye, trailer-local (level with the bus hitch on flat road)
const JACK := Rect2(68, 1, 3, 14)  ## stand that drops when unhooked, holding the tongue at hitch height
const BOX := Rect2(-26, -16, 50, 22)
const AXLE := Vector2(-2, 8)
const WHEEL_R := 7.0
const REHOOK_DIST := 14.0

var bus: Bus
var cargo := "water"
var body: RigidBody2D
var wheel: RigidBody2D
var attached := false
var lost := false  ## fell into a gap
var _hitch: PinJoint2D
var _jack: CollisionShape2D
var _blink := 0.0
var _cooldown := 0.0  ## after a snap, a beat before it can re-hook (no instant re-attach)


func setup(b: Bus, kind: String) -> Trailer:
	bus = b
	cargo = kind
	return self


func _ready() -> void:
	var xf := bus.chassis.global_transform
	body = RigidBody2D.new()
	body.mass = 0.3
	body.collision_layer = Bus.LAYER_BUS
	body.collision_mask = Bus.LAYER_WORLD
	body.physics_material_override = Bus._material(0.4, 0.0)
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Placed so its tongue sits on the bus hitch.
	body.global_position = xf * BUS_HITCH - TONGUE
	body.linear_velocity = bus.chassis.linear_velocity
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BOX.size
	shape.shape = rect
	shape.position = BOX.get_center()
	body.add_child(shape)
	_jack = CollisionShape2D.new()
	var leg := RectangleShape2D.new()
	leg.size = JACK.size
	_jack.shape = leg
	_jack.position = JACK.get_center()
	_jack.disabled = true
	body.add_child(_jack)
	var art := Node2D.new()
	art.draw.connect(_draw_trailer.bind(art))
	body.add_child(art)
	add_child(body)

	wheel = RigidBody2D.new()
	wheel.mass = 0.08
	wheel.collision_layer = Bus.LAYER_BUS
	wheel.collision_mask = Bus.LAYER_WORLD
	wheel.physics_material_override = Bus._material(1.0, 0.05)
	wheel.global_position = body.global_position + AXLE
	wheel.linear_velocity = body.linear_velocity
	var ws := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = WHEEL_R
	ws.shape = circle
	wheel.add_child(ws)
	var tyre := Sprite2D.new()
	tyre.texture = Bus.TEX_WHEEL
	tyre.scale = Vector2(0.7, 0.7)
	wheel.add_child(tyre)
	add_child(wheel)
	var axle := PinJoint2D.new()
	body.add_child(axle)
	axle.position = AXLE
	axle.node_a = axle.get_path_to(body)
	axle.node_b = axle.get_path_to(wheel)
	hook(true)


func hitch_point() -> Vector2:
	return body.to_global(TONGUE)


## Joins the trailer to the bus (snapping the tongue onto the hitch first).
func hook(quiet := false) -> void:
	if attached or lost or not is_instance_valid(bus) or bus.is_crashed:
		return
	var delta := bus.chassis.to_global(BUS_HITCH) - hitch_point()
	body.global_position += delta
	wheel.global_position += delta
	_hitch = PinJoint2D.new()
	_hitch.softness = 0.0
	bus.chassis.add_child(_hitch)
	_hitch.position = BUS_HITCH
	_hitch.node_a = _hitch.get_path_to(bus.chassis)
	_hitch.node_b = _hitch.get_path_to(body)
	attached = true
	_jack.set_deferred("disabled", true)
	if not quiet:
		Audio.play("clank", -2.0)
		Fx.float_text(hitch_point() + Vector2(0, -24), "HOOKED!", Color("#7dff6a"), 16)
		hooked.emit()


## The hitch pin shears: the trailer is on its own.
func unhook() -> void:
	if not attached:
		return
	attached = false
	_cooldown = 1.2
	_jack.set_deferred("disabled", false)
	if is_instance_valid(_hitch):
		_hitch.queue_free()
	Audio.play("clank", 0.0, 0.7)
	Audio.play("creak_c", -4.0)
	Fx.float_text(hitch_point() + Vector2(0, -24), "HITCH SNAPPED!", Color("#ff9a2e"), 16)
	body.apply_central_impulse(Vector2(randf_range(-20, 20), -60) * body.mass)
	unhooked.emit()


func _physics_process(delta: float) -> void:
	_blink += delta
	if attached or lost or not is_instance_valid(bus) or bus.is_crashed:
		return
	# Backed up close enough, slowly enough: the hitch drops onto the ball.
	_cooldown -= delta
	var gap := bus.chassis.to_global(BUS_HITCH).distance_to(hitch_point())
	if _cooldown <= 0.0 and gap < REHOOK_DIST and absf(bus.get_speed()) < 90.0 and not bus.airborne:
		hook()


func _process(_delta: float) -> void:
	body.get_child(-1).queue_redraw()


func _draw_trailer(n: Node2D) -> void:
	var steel := Color("#5a5e70")
	var dark := Color("#2a2832")
	n.draw_rect(Rect2(BOX.position.x, BOX.end.y - 5, BOX.size.x, 5), steel)  # deck
	n.draw_rect(Rect2(BOX.position.x, BOX.end.y - 5, BOX.size.x, 1), Color("#8a8ea0"))
	n.draw_line(Vector2(BOX.end.x, BOX.end.y - 3), TONGUE, dark, 2.0)  # draw bar
	n.draw_rect(Rect2(TONGUE - Vector2(2, 2), Vector2(4, 4)), Color("#ffc828"))  # hitch eye
	n.draw_rect(Rect2(BOX.position.x + 2, BOX.end.y, 3, 4), dark)  # mud flap
	if not attached:  # the jack stand, wound down
		n.draw_rect(JACK, dark)
		n.draw_rect(Rect2(JACK.position.x - 2, JACK.end.y - 1, 7, 1), dark)
	match cargo:
		"water":  # a fat blue tank with straps
			n.draw_rect(Rect2(-24, -15, 46, 15), Color("#3a7ad8"))
			n.draw_rect(Rect2(-24, -15, 46, 2), Color("#7ab0f0"))
			n.draw_rect(Rect2(-23, -2, 44, 2), Color("#24508a"))
			for x in [-14, 6]:
				n.draw_rect(Rect2(x, -15, 2, 15), dark)
			n.draw_rect(Rect2(-6, -13, 12, 5), Color("#e8f0ff"))
		"canoe":  # a red canoe on a rack
			for x in [-20, 14]:
				n.draw_rect(Rect2(x, -8, 2, 8), dark)
			var hull := PackedVector2Array([Vector2(-30, -12), Vector2(26, -12), Vector2(20, -6), Vector2(-24, -6)])
			n.draw_colored_polygon(hull, Color("#d83a2a"))
			n.draw_line(Vector2(-30, -12), Vector2(26, -12), Color("#ff7a5a"), 1.0)
			n.draw_line(Vector2(-10, -14), Vector2(4, -18), Color("#c89a5a"), 1.0)  # paddle
		"cake":  # a three-tier wedding cake, very nervous
			n.draw_rect(Rect2(-16, -8, 32, 8), Color("#fff4f0"))
			n.draw_rect(Rect2(-11, -14, 22, 6), Color("#fff4f0"))
			n.draw_rect(Rect2(-6, -19, 12, 5), Color("#fff4f0"))
			for tier in [[-16, -8, 32], [-11, -14, 22], [-6, -19, 12]]:  # pink icing lines
				n.draw_rect(Rect2(tier[0], tier[1], tier[2], 1), Color("#ff9ad2"))
			n.draw_rect(Rect2(-1, -23, 2, 4), Color("#ffe14a"))
	if not attached and not lost and fmod(_blink, 0.6) < 0.35:  # "come back for me"
		n.draw_colored_polygon(PackedVector2Array([TONGUE + Vector2(-4, -14), TONGUE + Vector2(4, -14),
				TONGUE + Vector2(0, -8)]), Color("#ffc828"))
