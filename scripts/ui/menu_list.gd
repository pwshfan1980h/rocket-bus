class_name MenuList
extends Control
## Vertical pixel-font menu: arrows/W/S + Enter/Space, or mouse hover + click.

signal chosen(id: String)

var items: Array = []  # [[id, text], ...]
var index := 0
var active := true
var line_height := 14
var font_size := 8
var _labels: Array[Label] = []


func setup(entries: Array, size := 8, spacing := 14) -> MenuList:
	items = entries
	font_size = size
	line_height = spacing
	return self


func _ready() -> void:
	add_to_group("menus")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in items.size():
		var l := Label.new()
		l.label_settings = PixelFont.settings(font_size, Color.WHITE, 2)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(-120, i * line_height)
		l.size = Vector2(240, line_height)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(func(): if active and index != i: _move_to(i))
		l.gui_input.connect(func(e: InputEvent):
			if active and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_choose())
		add_child(l)
		_labels.append(l)
	_refresh()


func set_text(id: String, text: String) -> void:
	for i in items.size():
		if items[i][0] == id:
			items[i][1] = text
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_S):
		_move_to((index + 1) % items.size())
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_W):
		_move_to((index - 1 + items.size()) % items.size())
	elif event.is_action_pressed("ui_accept"):
		_choose()
	else:
		return
	get_viewport().set_input_as_handled()


func _move_to(i: int) -> void:
	index = i
	Audio.play("ui_move", -8.0)
	_refresh()


func _choose() -> void:
	Audio.play("ui_select", -4.0)
	chosen.emit(items[index][0])


func _refresh() -> void:
	for i in _labels.size():
		var sel := i == index
		_labels[i].text = ("> %s <" if sel else "%s") % items[i][1]
		_labels[i].label_settings.font_color = Color("#ffcc26") if sel else Color("#e8e0f0")
