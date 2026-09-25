extends CanvasLayer
## Screen-space effects shared by every scene: floating arcade text and camera shake.

signal shake_requested(strength: float)


func _ready() -> void:
	layer = 20


func float_text(world_pos: Vector2, text: String, color := Color.WHITE, size := 8,
		rainbow := false, life := 1.3) -> void:
	var t := FloatingText.new()
	t.text = text
	t.world_pos = world_pos
	t.rainbow = rainbow
	t.life = life
	t.rise = 18.0 + size
	t.label_settings = PixelFont.settings(size, color, 4 if size >= 16 else 2)
	add_child(t)


func shake(strength: float) -> void:
	shake_requested.emit(strength)
