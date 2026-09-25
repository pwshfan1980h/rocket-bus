class_name PixelFont
## Crisp Press Start 2P (renders cleanly at multiples of 8px).

static var _font: FontFile


static func get_font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/PressStart2P-Regular.ttf").duplicate()
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


static func settings(size := 8, color := Color.WHITE, outline := 0) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = get_font()
	s.font_size = size
	s.font_color = color
	if outline > 0:
		s.outline_size = outline
		s.outline_color = Color(0.08, 0.04, 0.12)
		s.shadow_size = 0
		s.shadow_color = Color(0.08, 0.04, 0.12, 0.8)
		s.shadow_offset = Vector2(1, 1)
	return s
