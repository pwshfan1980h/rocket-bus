class_name Ragdoll
extends RefCounted
## A thrown passenger: head + torso + two arms + two legs held by pin joints.
## Hits the ground with a BONK. Bloodless slapstick.

const SHEET := preload("res://assets/sprites/passengers.png")
const SKIN := Color("#e8b890")

var torso: RigidBody2D
var head: RigidBody2D
var _bonk_cd := 0.0


func build(into: Node, at: Vector2, rot: float, vel: Vector2, row: int, shirt: Color) -> void:
	var xf := Transform2D(rot, at)
	torso = _part(into, xf * Vector2(0, 2), rot, Vector2(6, 6), shirt, 0.08)
	head = _part(into, xf * Vector2(0, -5), rot, Vector2(6, 7), Color.TRANSPARENT, 0.04)
	var face := Sprite2D.new()  # the passenger's own shocked face
	face.texture = SHEET
	face.hframes = 3
	face.vframes = 6
	face.frame = row * 3 + 2
	face.region_enabled = false
	face.position = Vector2(0, 1)
	head.add_child(face)
	var limbs := [
		[Vector2(-4, 1), Vector2(2, 5), shirt, Vector2(-4, -1)],  # arms
		[Vector2(4, 1), Vector2(2, 5), shirt, Vector2(4, -1)],
		[Vector2(-2, 8), Vector2(2, 6), Color("#3a3a5a"), Vector2(-2, 5)],  # legs
		[Vector2(2, 8), Vector2(2, 6), Color("#3a3a5a"), Vector2(2, 5)],
	]
	_pin(into, torso, head, xf * Vector2(0, -1), 50.0)
	for l in limbs:
		var part := _part(into, xf * l[0], rot, l[1], l[2], 0.02)
		_pin(into, torso, part, xf * l[3], 110.0)
		part.linear_velocity = vel + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		part.angular_velocity = randf_range(-20, 20)
	torso.linear_velocity = vel
	head.linear_velocity = vel
	torso.angular_velocity = randf_range(-12, 12)
	torso.set_meta("doll", self)  # keeps this RefCounted alive as long as the body exists
	torso.body_entered.connect(_on_hit)
	head.body_entered.connect(_on_hit)


func _part(into: Node, pos: Vector2, rot: float, size: Vector2, color: Color, mass: float) -> RigidBody2D:
	var b := RigidBody2D.new()
	b.collision_layer = 8
	b.collision_mask = 1
	b.mass = mass
	b.position = pos
	b.rotation = rot
	b.contact_monitor = true
	b.max_contacts_reported = 2
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3
	mat.friction = 0.8
	b.physics_material_override = mat
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	b.add_child(cs)
	if color.a > 0.0:
		var poly := Polygon2D.new()
		poly.color = color
		poly.polygon = PackedVector2Array([-size / 2, Vector2(size.x / 2, -size.y / 2), size / 2, Vector2(-size.x / 2, size.y / 2)])
		b.add_child(poly)
		if color != SKIN and size.y == 5:  # hands
			var hand := Polygon2D.new()
			hand.color = SKIN
			hand.polygon = PackedVector2Array([Vector2(-1, 2), Vector2(1, 2), Vector2(1, 3), Vector2(-1, 3)])
			b.add_child(hand)
	into.add_child(b)
	return b


func _pin(into: Node, a: RigidBody2D, b: RigidBody2D, at: Vector2, limit_deg: float) -> void:
	var j := PinJoint2D.new()
	j.position = at
	j.softness = 0.2
	j.angular_limit_enabled = true
	j.angular_limit_lower = deg_to_rad(-limit_deg)
	j.angular_limit_upper = deg_to_rad(limit_deg)
	into.add_child(j)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


func _on_hit(_body: Node) -> void:
	if not is_instance_valid(torso):
		return
	var t := Time.get_ticks_msec() / 1000.0
	var speed := torso.linear_velocity.length()
	if speed < 120.0 or t < _bonk_cd:
		return
	_bonk_cd = t + 0.5
	Audio.play_at("clank", torso.global_position, -10.0, 0.3)
	Audio.play_at("voice_hurt", torso.global_position, -12.0, 0.2)
	if randf() < 0.5:
		Fx.float_text(torso.global_position + Vector2(0, -8), BusPassengers.QUIPS.bonk.pick_random(), Color("#ffe14a"))
