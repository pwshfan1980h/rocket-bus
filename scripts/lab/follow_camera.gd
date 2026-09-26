extends Camera2D
## Follows a body with speed look-ahead and a dynamic zoom: pulls back as the bus
## speeds up or climbs, eases back in as it slows. Shakes on Fx.shake().

const ZOOM_NEAR := 1.08  ## parked / crawling
const ZOOM_FAR := 0.68  ## flat out, high in the air

var target: Node2D
var terrain: Terrain  ## optional: lets height above the road widen the view
var dynamic_zoom := true
## Cinematic override (e.g. the finish pull-back). NAN = automatic.
var zoom_override := NAN
var _shake := 0.0
var _zoom := 1.0


func _ready() -> void:
	Fx.shake_requested.connect(func(s: float): _shake = maxf(_shake, s))


func snap() -> void:
	if target:
		global_position = _goal()
	_zoom = _target_zoom()
	zoom = Vector2(_zoom, _zoom)


func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(_goal(), 1.0 - exp(-5.0 * delta))
	var want := _target_zoom()
	# Pull out briskly when things get fast, drift back in slowly so it never feels twitchy.
	var rate := 2.2 if want < _zoom else 0.9
	_zoom = lerpf(_zoom, want, 1.0 - exp(-rate * delta))
	zoom = Vector2(_zoom, _zoom)
	_shake = maxf(0.0, _shake - 30.0 * delta)
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()


func _target_zoom() -> float:
	if not is_nan(zoom_override):
		return zoom_override
	if not dynamic_zoom or not (target is RigidBody2D) or not is_instance_valid(target):
		return 1.0
	var body := target as RigidBody2D
	var speed_t := clampf((body.linear_velocity.length() - 60.0) / 560.0, 0.0, 1.0)
	var height_t := 0.0
	if terrain:
		var ground := terrain.surface_y(body.global_position.x)
		if is_nan(ground):  # over a gap: show the far side
			height_t = 0.6
		else:
			height_t = clampf((ground - body.global_position.y - 40.0) / 160.0, 0.0, 1.0)
	var t := clampf(speed_t * 0.75 + height_t * 0.5, 0.0, 1.0)
	return lerpf(ZOOM_NEAR, ZOOM_FAR, ease(t, 0.8))


func _goal() -> Vector2:
	var look := Vector2.ZERO
	if target is RigidBody2D:
		look = (target as RigidBody2D).linear_velocity * Vector2(0.3, 0.12)
	return target.global_position + Vector2(0, -30) + look.limit_length(130)
