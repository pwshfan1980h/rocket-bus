class_name Gore
extends Node2D
## Blood: spurting sprays that follow severed parts, bursts, and stains that stay
## on the ground. One per scene (found or created on demand). Does nothing when
## the player has gore switched off.

const BLOOD := Color("#c8121e")
const BLOOD_DARK := Color("#5e0610")
const MAX_STAINS := 400

var _stains: Array[Vector4] = []  # x, y, width, shade
var _sprays: Array[Dictionary] = []


static func enabled() -> bool:
	return GameState.gore_on


static func of(node: Node) -> Gore:
	var tree := node.get_tree()
	var existing := tree.get_first_node_in_group("gore")
	if existing:
		return existing
	var g := Gore.new()
	tree.current_scene.add_child(g)
	return g


func _ready() -> void:
	add_to_group("gore")
	z_index = 3


## A severed stump or limb end that spurts for a while, dripping onto the road.
func spray(body: Node2D, local_pos: Vector2, dir: Vector2, duration := 1.6) -> void:
	if not enabled() or not is_instance_valid(body):
		return
	var p := CPUParticles2D.new()
	p.position = local_pos
	p.amount = 56
	p.lifetime = 0.8
	p.local_coords = false
	p.direction = dir
	p.spread = 22.0
	p.gravity = Vector2(0, 650)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color_ramp = _ramp()
	body.add_child(p)
	p.emitting = true
	_sprays.append({"p": p, "t": duration, "drip": 0.0})


## A one-off burst of blood (a limb tearing, a head popping off).
func burst(at: Vector2, amount := 40, dir := Vector2.UP) -> void:
	if not enabled():
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.9
	p.direction = dir
	p.spread = 70.0
	p.gravity = Vector2(0, 650)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color_ramp = _ramp()
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)
	for i in 8:
		stain_below(at + Vector2(randf_range(-40, 40), 0), randf_range(4, 10))


## Leaves a stain on the ground under `at` (raycast down).
func stain_below(at: Vector2, width: float) -> void:
	if not enabled():
		return
	var q := PhysicsRayQueryParameters2D.create(at, at + Vector2(0, 400), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		_stains.append(Vector4(hit.position.x, hit.position.y, width, randf()))
		if _stains.size() > MAX_STAINS:
			_stains.pop_front()
		queue_redraw()


func _process(delta: float) -> void:
	for s in _sprays:
		s.t -= delta
		var p: CPUParticles2D = s.p
		if not is_instance_valid(p):
			s.t = 0.0
			continue
		p.initial_velocity_max = 170.0 * clampf(s.t / 1.6, 0.25, 1.0)  # spurts weaken
		s.drip -= delta
		if s.drip <= 0.0:
			s.drip = 0.09
			stain_below(p.global_position + Vector2(randf_range(-12, 12), 0), randf_range(1.5, 4.0))
		if s.t <= 0.0:
			p.emitting = false
			get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	_sprays = _sprays.filter(func(s): return s.t > 0.0)


func _draw() -> void:
	for s in _stains:
		var c := BLOOD.lerp(BLOOD_DARK, s.w)
		draw_rect(Rect2(s.x - s.z, s.y - 1, s.z * 2, 3), c)
		draw_rect(Rect2(s.x - s.z * 0.5, s.y - 2, s.z, 1), c)
		draw_rect(Rect2(s.x - s.z * 0.3, s.y + 2, 1, 2 + s.w * 3), BLOOD_DARK)


static func _ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color("#d8182a"), BLOOD, Color(BLOOD_DARK, 0.0)])
	return g
