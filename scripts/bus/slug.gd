class_name Slug
extends Node2D
## Bumper-cannon round: flies straight, raycasting ahead each step. Damages the
## first obstacle it meets (smashable or blocker), or puffs dust off the ground.

const SPEED := 760.0
const LIFE := 1.1

var velocity := Vector2.ZERO
var _life := LIFE
var _trail: Array[Vector2] = []
var _from := Vector2.INF  # first raycast starts here (inside the bus) so point-blank shots land


func fire(at: Vector2, dir: Vector2, inherit: Vector2, from := Vector2.INF) -> Slug:
	position = at
	velocity = dir * SPEED + Vector2(inherit.x * 0.5, 0)  # forward speed only: shots fly flat
	_from = from
	return self


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var step := velocity * delta
	var start := global_position if _from == Vector2.INF else _from
	_from = Vector2.INF
	var q := PhysicsRayQueryParameters2D.create(start, global_position + step, 1 | Obstacle.LAYER_BLOCKER | Obstacle.LAYER_SMASH)
	q.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		var node: Node = hit.collider
		var obstacle := node.get_parent() as Obstacle
		if "--trace" in OS.get_cmdline_user_args():
			print("SLUG hit %s at %s (obstacle=%s)" % [node.name, hit.position, obstacle.kind if obstacle else "-"])
		if obstacle:
			obstacle.damage(1, velocity.normalized())
		else:
			_puff(hit.position)
		queue_free()
		return
	_trail.push_front(global_position)
	if _trail.size() > 4:
		_trail.pop_back()
	global_position += step
	velocity.y += 60.0 * delta  # a hint of drop
	queue_redraw()


func _puff(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.5
	p.direction = Vector2.UP
	p.spread = 60.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.color = Color(0.8, 0.75, 0.7, 0.8)
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)
	Audio.play_at("clank", at, -12.0, 0.3)


func _draw() -> void:
	for i in _trail.size():
		var p := _trail[i] - global_position
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.8, 0.4, 0.5 - i * 0.12))
	draw_rect(Rect2(-2, -1, 4, 2), Color(1, 0.95, 0.7))
