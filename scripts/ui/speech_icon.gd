extends Node2D
## A tiny pixel speech bubble with a symbol in it, popping up over a rider's head.
## Stands in for most spoken lines, so the voice and the mood still read without
## a wall of floating text. Lives on the Fx layer (screen space) and follows its
## speaker in the world.

## 5x5 glyphs, one string per row ("#" = ink).
const GLYPHS := {
	"!": ["..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "...#.", "..##.", ".....", "..#.."],
	"heart": [".#.#.", "#####", "#####", ".###.", "..#.."],
	"note": ["..##.", "..#.#", "..#..", "###..", "##..."],
	"dots": [".....", ".....", ".....", ".....", "#.#.#"],
	"star": ["..#..", ".###.", "#####", ".###.", "#...#"],
	"skull": [".###.", "#.#.#", "#####", ".###.", ".#.#."],
}

var target: Node2D
var glyph := "!"
var ink := Color.WHITE
var life := 0.9
var _age := 0.0
var _anchor := Vector2.ZERO


func setup(speaker: Node2D, symbol: String, color: Color) -> Node2D:
	target = speaker
	glyph = symbol if GLYPHS.has(symbol) else "!"
	ink = color
	_anchor = speaker.global_position
	return self


func _ready() -> void:
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	_place()


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	modulate.a = 1.0 - clampf((_age - life * 0.7) / (life * 0.3), 0.0, 1.0)
	_place()


func _place() -> void:
	if is_instance_valid(target) and target.is_visible_in_tree():
		_anchor = target.global_position
	var screen := get_viewport().get_canvas_transform() * _anchor
	position = (screen + Vector2(2, -14 - 4.0 * ease(minf(_age / 0.3, 1.0), 0.5))).round()


func _draw() -> void:
	# Bubble: 9x9 white box with a dark outline and a tail down-left.
	var o := Vector2(-4, -9)
	draw_rect(Rect2(o + Vector2(-1, 0), Vector2(11, 9)), Color("#1a1420"))
	draw_rect(Rect2(o + Vector2(0, -1), Vector2(9, 11)), Color("#1a1420"))
	draw_rect(Rect2(o + Vector2(0, 0), Vector2(9, 9)), Color.WHITE)
	draw_rect(Rect2(o + Vector2(0, 9), Vector2(3, 2)), Color("#1a1420"))
	draw_rect(Rect2(o + Vector2(1, 9), Vector2(1, 1)), Color.WHITE)
	var rows: Array = GLYPHS[glyph]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				draw_rect(Rect2(o + Vector2(2 + x, 2 + y), Vector2.ONE), ink)
