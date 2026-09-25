class_name FloatingText
extends Label
## Arcade pop-up text pinned to a world position: pops in, rises, fades out.

var world_pos := Vector2.ZERO
var rise := 26.0
var life := 1.3
var rainbow := false
var _age := 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_size()
	pivot_offset = size / 2
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	_place()


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	if rainbow:
		label_settings.font_color = Color.from_hsv(fmod(_age * 2.5, 1.0), 0.75, 1.0)
	var fade_start := life * 0.65
	modulate.a = 1.0 - clampf((_age - fade_start) / (life - fade_start), 0.0, 1.0)
	_place()


func _place() -> void:
	var t := ease(clampf(_age / life, 0.0, 1.0), 0.4)
	var screen := get_viewport().get_canvas_transform() * (world_pos + Vector2(0, -rise * t))
	position = (screen - size / 2).round()
