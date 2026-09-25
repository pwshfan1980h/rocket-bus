extends Camera2D
## Smoothly follows a body with speed look-ahead, and shakes on Fx.shake().

var target: Node2D
var _shake := 0.0


func _ready() -> void:
	Fx.shake_requested.connect(func(s: float): _shake = maxf(_shake, s))


func snap() -> void:
	if target:
		global_position = _goal()


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(_goal(), 1.0 - exp(-6.0 * delta))
	_shake = maxf(0.0, _shake - 30.0 * delta)
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()


func _goal() -> Vector2:
	var look := Vector2.ZERO
	if target is RigidBody2D:
		look = (target as RigidBody2D).linear_velocity * Vector2(0.25, 0.1)
	return target.global_position + Vector2(0, -30) + look.limit_length(90)
