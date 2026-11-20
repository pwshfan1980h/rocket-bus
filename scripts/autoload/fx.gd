extends CanvasLayer
## Screen-space effects shared by every scene: floating arcade text and camera shake.

signal shake_requested(strength: float)

const SPEECH_ICON := preload("res://scripts/ui/speech_icon.gd")


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


## A little speech bubble with a symbol ("!", "?", "heart", "note", "dots", "star", "skull")
## over a speaker: the quiet stand-in for a spoken line.
func bubble(speaker: Node2D, symbol: String, color := Color("#1a1420")) -> void:
	add_child(SPEECH_ICON.new().setup(speaker, symbol, color))


func shake(strength: float) -> void:
	shake_requested.emit(strength)
