class_name Ragdoll
extends RefCounted
## A thrown passenger: head + torso + two arms + two legs held by pin joints.
## Happy Wheels rules: hard hits tear joints apart - heads roll, limbs fly off,
## and every stump and severed part spurts blood (see Gore). With gore off the
## joints never tear and nothing bleeds.

const SHEET := preload("res://assets/sprites/passengers.png")
const SKIN := Color("#e8b890")
const PANTS := Color("#3a3a5a")
const TEAR_SPEED := 230.0  ## part speed on impact that rips it off
const BONK_SPEED := 120.0

var torso: RigidBody2D
var head: RigidBody2D
var _row := 0
var _joints := {}  # part body -> [joint, attach point in torso space]
var _bonk_cd := 0.0
var _screaming := true


func build(into: Node, at: Vector2, rot: float, vel: Vector2, row: int, shirt: Color) -> void:
	_row = row
	var xf := Transform2D(rot, at)
	torso = _part(into, xf * Vector2(0, 2), rot, Vector2(6, 6), shirt, 0.08)
	head = _part(into, xf * Vector2(0, -5), rot, Vector2(7, 7), Color.TRANSPARENT, 0.04, true)
	var face := Sprite2D.new()  # the passenger's own shocked face
	face.texture = SHEET
	face.hframes = 3
	face.vframes = 6
	face.frame = row * 3 + 2
	face.position = Vector2(0, 1)
	head.add_child(face)
	_pin(into, head, xf, Vector2(0, -1), 50.0)
	var limbs := [
		[Vector2(-4, 1), Vector2(2, 5), shirt, Vector2(-4, -1)],  # arms
		[Vector2(4, 1), Vector2(2, 5), shirt, Vector2(4, -1)],
		[Vector2(-2, 8), Vector2(2, 6), PANTS, Vector2(-2, 5)],  # legs
		[Vector2(2, 8), Vector2(2, 6), PANTS, Vector2(2, 5)],
	]
	for l in limbs:
		var part := _part(into, xf * l[0], rot, l[1], l[2], 0.02)
		_pin(into, part, xf, l[3], 110.0)
		part.linear_velocity = vel + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		part.angular_velocity = randf_range(-20, 20)
	torso.linear_velocity = vel
	head.linear_velocity = vel
	torso.angular_velocity = randf_range(-12, 12)
	torso.set_meta("doll", self)  # keeps this RefCounted alive as long as the body exists
	for b in [torso] + _joints.keys():
		b.body_entered.connect(_on_hit.bind(b))
	# A violent enough ejection can rip something off before it even lands.
	if Gore.enabled() and vel.length() > 380.0 and randf() < 0.45:
		torso.get_tree().create_timer(randf_range(0.05, 0.25)).timeout.connect(
				func(): if is_instance_valid(torso): _tear(_joints.keys().pick_random()))


func _part(into: Node, pos: Vector2, rot: float, size: Vector2, color: Color, mass: float,
		round := false) -> RigidBody2D:
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
	mat.friction = 0.5 if round else 0.8
	b.physics_material_override = mat
	var cs := CollisionShape2D.new()
	if round:  # heads roll
		var c := CircleShape2D.new()
		c.radius = size.x / 2
		cs.shape = c
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
	b.add_child(cs)
	if color.a > 0.0:
		var poly := Polygon2D.new()
		poly.color = color
		poly.polygon = PackedVector2Array([-size / 2, Vector2(size.x / 2, -size.y / 2), size / 2, Vector2(-size.x / 2, size.y / 2)])
		b.add_child(poly)
		if color != PANTS and size.y == 5:  # hands
			var hand := Polygon2D.new()
			hand.color = SKIN
			hand.polygon = PackedVector2Array([Vector2(-1, 2), Vector2(1, 2), Vector2(1, 3), Vector2(-1, 3)])
			b.add_child(hand)
	into.add_child(b)
	return b


func _pin(into: Node, part: RigidBody2D, xf: Transform2D, at: Vector2, limit_deg: float) -> void:
	var j := PinJoint2D.new()
	j.position = xf * at
	j.softness = 0.2
	j.angular_limit_enabled = true
	j.angular_limit_lower = deg_to_rad(-limit_deg)
	j.angular_limit_upper = deg_to_rad(limit_deg)
	into.add_child(j)
	j.node_a = j.get_path_to(torso)
	j.node_b = j.get_path_to(part)
	_joints[part] = [j, at + Vector2(0, -2)]


func _on_hit(_other: Node, part: RigidBody2D) -> void:
	if not is_instance_valid(part) or not is_instance_valid(torso):
		return
	var speed := part.linear_velocity.length()
	if Gore.enabled() and speed > TEAR_SPEED:
		if _joints.has(part):
			_tear(part)
		elif part == torso and not _joints.is_empty() and randf() < 0.6:
			_tear(_joints.keys().pick_random())
	var t := Time.get_ticks_msec() / 1000.0
	if speed < BONK_SPEED or t < _bonk_cd:
		return
	_bonk_cd = t + 0.5
	Audio.play_at("splat" if Gore.enabled() else "clank", part.global_position, -8.0, 0.3)
	if _screaming:
		Audio.play_at("voice_hurt", part.global_position, -12.0, 0.2)
	if Gore.enabled():
		Gore.of(torso).stain_below(part.global_position, randf_range(3, 7))
	if randf() < 0.45:
		Fx.float_text(part.global_position + Vector2(0, -8), BusPassengers.QUIPS.bonk.pick_random(), Color("#ffe14a"))


## Rip a part off the torso: both ends spurt, and a lost head ends the screaming.
func _tear(part: RigidBody2D) -> void:
	if not _joints.has(part) or not is_instance_valid(part):
		return
	var info: Array = _joints[part]
	_joints.erase(part)
	var joint: PinJoint2D = info[0]
	var at := joint.global_position
	joint.queue_free()
	part.apply_central_impulse(Vector2(randf_range(-40, 40), randf_range(-90, -40)) * part.mass)
	part.angular_velocity += randf_range(-25, 25)
	var gore := Gore.of(torso)
	gore.burst(at, 50, (part.global_position - torso.global_position).normalized())
	gore.spray(torso, torso.to_local(at), (at - torso.global_position).normalized(), 2.0)
	gore.spray(part, part.to_local(at), (at - part.global_position).normalized(), 1.2)
	for body in [torso, part]:  # red stump caps
		var cap := Polygon2D.new()
		cap.color = Gore.BLOOD
		var c: Vector2 = body.to_local(at)
		cap.polygon = PackedVector2Array([c + Vector2(-1.5, -1), c + Vector2(1.5, -1), c + Vector2(1.5, 1), c + Vector2(-1.5, 1)])
		body.add_child(cap)
	Audio.play_at("squelch", at, -4.0, 0.2)
	if part == head:
		_screaming = false
		head.angular_velocity = randf_range(-30, 30)  # heads roll
		Fx.float_text(at + Vector2(0, -10), ["OFF WITH HIS HEAD!", "HEADS UP!", "NOGGIN!"].pick_random(), Color("#ff3b4e"))
