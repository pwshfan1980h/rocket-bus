class_name Obstacle
extends Node2D
## Stuff in the road. Smashables (crates, cones, fences, mailboxes, barrels) burst
## apart when the bus plows through; barrels explode. Blockers (boulders, logs,
## barricades) are solid: shoot them with the bumper cannon or hit them and wreck.

signal destroyed(obstacle: Obstacle)

const KINDS := {
	"crate": {"size": Vector2(12, 12), "hp": 1, "blocker": false, "color": "#a0703a", "sound": "wood_break"},
	"cone": {"size": Vector2(6, 10), "hp": 1, "blocker": false, "color": "#ff7a1a", "sound": "plastic_bonk"},
	"fence": {"size": Vector2(28, 12), "hp": 1, "blocker": false, "color": "#c8a070", "sound": "wood_break"},
	"mailbox": {"size": Vector2(6, 14), "hp": 1, "blocker": false, "color": "#3a6ad0", "sound": "clank"},
	"barrel": {"size": Vector2(10, 14), "hp": 1, "blocker": false, "color": "#d0302a", "sound": "explosion", "explosive": true},
	"boulder": {"size": Vector2(30, 26), "hp": 3, "blocker": true, "color": "#7a7280", "sound": "rock_break"},
	"log": {"size": Vector2(54, 12), "hp": 2, "blocker": true, "color": "#6a4428", "sound": "wood_break"},
	"barricade": {"size": Vector2(40, 22), "hp": 2, "blocker": true, "color": "#e8e0d0", "sound": "wood_break"},
}
const LAYER_BLOCKER := 16
const LAYER_SMASH := 32
const CRASH_SPEED := 220.0
const BLAST_RADIUS := 95.0

var kind := "crate"
var hp := 1
var spec: Dictionary
var _flash := 0.0
var _dead := false
var _area: Area2D
var _solid: StaticBody2D


func setup(k: String) -> Obstacle:
	kind = k
	spec = KINDS[k]
	hp = spec.hp
	return self


func is_blocker() -> bool:
	return spec.blocker


func _ready() -> void:
	add_to_group("obstacles")
	# Hitboxes are at least as tall as the bumper cannon's line of fire.
	var size := Vector2(spec.size.x, maxf(spec.size.y, 24.0))
	var rect := RectangleShape2D.new()
	rect.size = size
	if spec.blocker:
		_solid = StaticBody2D.new()
		_solid.collision_layer = LAYER_BLOCKER
		_solid.collision_mask = 0
		var cs := CollisionShape2D.new()
		cs.shape = rect
		cs.position = Vector2(0, -size.y / 2)
		_solid.add_child(cs)
		add_child(_solid)
	_area = Area2D.new()
	_area.collision_layer = LAYER_SMASH
	_area.collision_mask = 2  # the bus
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = size + (Vector2(8, 4) if spec.blocker else Vector2.ZERO)
	cs2.shape = r2
	cs2.position = Vector2(0, -size.y / 2)
	_area.add_child(cs2)
	add_child(_area)
	_area.body_entered.connect(_on_bus)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


func _on_bus(body: Node) -> void:
	var bus := body.get_parent() as Bus
	if _dead or bus == null or bus.is_crashed:
		return
	var speed := bus.chassis.linear_velocity.length()
	# Deferred: we're inside the physics callback, where bodies can't be added.
	if spec.blocker:
		if speed > CRASH_SPEED:
			bus.call_deferred("crash_into", "HIT A %s!" % kind.to_upper())
		return
	call_deferred("smash", bus.chassis.linear_velocity)


## Cannon hit (or blast). Blockers take a few hits.
func damage(amount: int, from_dir := Vector2.RIGHT) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.12
	queue_redraw()
	_chips(4 if hp > 0 else 0)
	if hp > 0:
		Audio.play_at("clank", global_position, -6.0, 0.3)
	else:
		smash(from_dir * 300.0 + Vector2(0, -120))


func smash(push: Vector2) -> void:
	if _dead:
		return
	_dead = true
	Audio.play_at(spec.sound, global_position, -2.0, 0.15)
	_pieces(push)
	if spec.get("explosive", false):
		_explode()
	destroyed.emit(self)
	queue_free()


func _explode() -> void:
	var at := global_position + Vector2(0, -8)
	Fx.shake(8.0)
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 70
	p.lifetime = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 0.8), Color(1, 0.6, 0.15), Color(0.4, 0.2, 0.15, 0.8), Color(0.2, 0.18, 0.2, 0)])
	p.color_ramp = g
	var light := PointLight2D.new()
	light.texture = preload("res://assets/sprites/light_radial.png")
	light.position = at
	light.color = Color(1, 0.6, 0.25)
	light.energy = 3.0
	light.texture_scale = 4.0
	var parent := get_parent()
	parent.add_child(p)
	parent.add_child(light)
	p.emitting = true
	var tw := parent.create_tween()
	tw.tween_property(light, "energy", 0.0, 0.5)
	tw.tween_callback(light.queue_free)
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	# Shove everything nearby (bus, debris, ragdolls) and set off other obstacles.
	var q := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BLAST_RADIUS
	q.shape = circle
	q.transform = Transform2D(0, at)
	q.collision_mask = 2 | 4 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 32):
		var b := hit.collider as RigidBody2D
		if b:
			var dir := (b.global_position - at).normalized()
			# The bus gets a hard jolt, not a guaranteed flip; loose bits go flying.
			var strength := 0.35 if b.get_parent() is Bus else 1.0
			b.apply_central_impulse((dir * 320.0 + Vector2(0, -160)) * b.mass * strength)
	for o in get_tree().get_nodes_in_group("obstacles"):
		if o != self and o.global_position.distance_to(at) < BLAST_RADIUS:
			o.call_deferred("damage", 99, (o.global_position - at).normalized())


func _pieces(push: Vector2) -> void:
	var size: Vector2 = spec.size
	var col := Color(spec.color)
	var n := 6 if spec.blocker else 4
	var parent := get_parent()
	for i in n:
		var b := RigidBody2D.new()
		b.collision_layer = 4
		b.collision_mask = 1
		b.mass = 0.05
		var w := randf_range(2, maxf(3, size.x / 3))
		var h := randf_range(2, maxf(3, size.y / 3))
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(w, h)
		cs.shape = r
		b.add_child(cs)
		var poly := Polygon2D.new()
		poly.color = col.darkened(randf() * 0.3)
		poly.polygon = PackedVector2Array([Vector2(-w, -h) / 2, Vector2(w, -h) / 2, Vector2(w, h) / 2, Vector2(-w, h) / 2])
		b.add_child(poly)
		b.position = global_position + Vector2(randf_range(-size.x, size.x) / 2, -randf_range(0, size.y))
		b.linear_velocity = push * randf_range(0.4, 0.9) + Vector2(randf_range(-80, 80), randf_range(-220, -60))
		b.angular_velocity = randf_range(-15, 15)
		parent.add_child(b)
		parent.get_tree().create_timer(6.0).timeout.connect(b.queue_free)


func _chips(count: int) -> void:
	if count <= 0:
		return
	var p := CPUParticles2D.new()
	p.position = global_position + Vector2(-spec.size.x / 2, -spec.size.y / 2)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count * 4
	p.lifetime = 0.5
	p.direction = Vector2(-1, -1)
	p.spread = 50.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(spec.color).lightened(0.2)
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func _draw() -> void:
	var s: Vector2 = spec.size
	var c := Color(spec.color)
	if _flash > 0.0:
		c = Color.WHITE
	var top := -s.y
	match kind:
		"crate":
			draw_rect(Rect2(-s.x / 2, top, s.x, s.y), c)
			draw_rect(Rect2(-s.x / 2, top, s.x, s.y), c.darkened(0.4), false, 1.0)
			draw_line(Vector2(-s.x / 2, top), Vector2(s.x / 2, 0), c.darkened(0.35), 1.0)
			draw_line(Vector2(s.x / 2, top), Vector2(-s.x / 2, 0), c.darkened(0.35), 1.0)
		"cone":
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, top)]), c)
			draw_rect(Rect2(-2, top * 0.55, 4, 2), Color.WHITE)
			draw_rect(Rect2(-4, -1, 8, 1), c.darkened(0.3))
		"fence":
			for k in 5:
				draw_rect(Rect2(-s.x / 2 + k * 6, top, 3, s.y), c)
			draw_rect(Rect2(-s.x / 2, top + 3, s.x, 2), c.darkened(0.25))
			draw_rect(Rect2(-s.x / 2, top + 8, s.x, 2), c.darkened(0.25))
		"mailbox":
			draw_rect(Rect2(-1, -8, 2, 8), Color("#6a6a74"))
			draw_rect(Rect2(-3, top, 7, 6), c)
			draw_rect(Rect2(3, top - 3, 1, 4), Color("#e03030"))
		"barrel":
			draw_rect(Rect2(-s.x / 2, top, s.x, s.y), c)
			draw_rect(Rect2(-s.x / 2, top + 3, s.x, 1), c.darkened(0.4))
			draw_rect(Rect2(-s.x / 2, top + 10, s.x, 1), c.darkened(0.4))
			draw_rect(Rect2(-2, top + 5, 4, 4), Color("#ffd23a"))  # hazard label
			draw_rect(Rect2(-1, top + 6, 2, 2), Color("#1a1420"))
		"boulder":
			draw_colored_polygon(PackedVector2Array([Vector2(-15, 0), Vector2(-14, -14), Vector2(-6, -26),
					Vector2(8, -24), Vector2(15, -12), Vector2(15, 0)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -14), Vector2(-5, -22), Vector2(4, -21), Vector2(-2, -12)]), c.lightened(0.15))
			draw_line(Vector2(2, -8), Vector2(8, -16), c.darkened(0.3), 1.0)
			_cracks()
		"log":
			draw_rect(Rect2(-s.x / 2, top, s.x, s.y), c)
			draw_rect(Rect2(-s.x / 2, top, s.x, 2), c.lightened(0.2))
			draw_circle(Vector2(s.x / 2 - 1, top + s.y / 2), s.y / 2, Color("#c89060"))
			draw_circle(Vector2(s.x / 2 - 1, top + s.y / 2), s.y / 4, Color("#a07040"))
			draw_line(Vector2(-10, top), Vector2(-16, top - 8), c, 2.0)  # branch stub
			_cracks()
		"barricade":
			draw_rect(Rect2(-s.x / 2 + 2, top + 8, 3, s.y - 8), Color("#6a6a74"))
			draw_rect(Rect2(s.x / 2 - 5, top + 8, 3, s.y - 8), Color("#6a6a74"))
			for k in 2:
				var y := top + 2 + k * 8
				draw_rect(Rect2(-s.x / 2, y, s.x, 5), c)
				for j in 5:
					draw_rect(Rect2(-s.x / 2 + j * 8, y, 4, 5), Color("#e04030"))
			_cracks()


func _cracks() -> void:
	var dmg: int = spec.hp - hp
	for k in dmg:
		var x := -6 + k * 7
		draw_line(Vector2(x, -spec.size.y + 3), Vector2(x + 4, -spec.size.y / 2), Color(0, 0, 0, 0.6), 1.0)
		draw_line(Vector2(x + 4, -spec.size.y / 2), Vector2(x + 1, -3), Color(0, 0, 0, 0.6), 1.0)
