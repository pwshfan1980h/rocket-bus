extends Node
## Registers the game's input actions so every scene can use them by name.

const BINDINGS := {
	"move_right": [KEY_D, KEY_RIGHT],  # throttle on the ground, nose-down in the air
	"move_left": [KEY_A, KEY_LEFT],  # brake/reverse on the ground, nose-up in the air
	"rocket": [KEY_SHIFT, KEY_W, KEY_UP],  # either Shift; W/Up spare Windows players Sticky Keys
	"brake": [KEY_SPACE],  # hard brake, never reverses; holds the bus still on hills
	"reset": [KEY_R],
	"horn": [KEY_H],
	"pause": [KEY_ESCAPE, KEY_P],
}


func _enter_tree() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
