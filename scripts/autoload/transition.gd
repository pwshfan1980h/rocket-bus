extends CanvasLayer
## Fade-to-black scene changes.

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.06, 0.03, 0.1, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func go(scene_path: String, time := 0.35) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, time)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = GameState.PACE
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, time)
	await tw2.finished
	_busy = false


func fade_in(time := 0.6) -> void:
	_rect.color.a = 1.0
	create_tween().tween_property(_rect, "color:a", 0.0, time)
