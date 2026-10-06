class_name Ghost
extends Node2D
## Your best attempt at this level (this session only), replayed as a see-through
## bus when you retry. Level records every run with record(); the best one is kept.

const RATE := 30.0  ## samples per second of run clock
const STRIDE := 7  ## floats per sample: chassis x, y, rotation, wheel0 x, y, wheel1 x, y
const PIECES := ["bus_lower_r", "bus_lower_f", "bus_upper_r", "bus_upper_f", "bus_door", "bus_hood",
	"bus_roof_r", "bus_roof_f", "bus_rack", "bus_bumper_f"]

## level key -> {"frames": PackedFloat32Array, "rank": float}
static var best := {}

var frames: PackedFloat32Array
var clock_ref: Callable  ## returns the current run clock
var _body: Node2D
var _wheels: Array[Sprite2D] = []


## rank: higher is better (finished runs beat unfinished; then faster / further).
static func offer(key: String, run: PackedFloat32Array, rank: float) -> void:
	if run.size() < STRIDE * 10:
		return
	if not best.has(key) or rank > best[key].rank:
		best[key] = {"frames": run, "rank": rank}


static func sample(bus: Bus, into: PackedFloat32Array) -> void:
	var c := bus.chassis
	into.append_array([c.global_position.x, c.global_position.y, c.rotation,
		bus.wheels[0].global_position.x, bus.wheels[0].global_position.y,
		bus.wheels[1].global_position.x, bus.wheels[1].global_position.y])


func _ready() -> void:
	modulate = Color(0.7, 0.95, 1.0, 0.38)
	_body = Node2D.new()
	add_child(_body)
	var rocket := Sprite2D.new()
	rocket.texture = Bus.TEX_ROCKET
	rocket.centered = false
	rocket.position = Bus.ROCKET_POS
	_body.add_child(rocket)
	for piece in PIECES:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/%s.png" % piece)
		s.centered = false
		s.position = Bus.CANVAS_ORIGIN
		_body.add_child(s)
	for i in 2:
		var w := Sprite2D.new()
		w.texture = Bus.TEX_WHEEL
		add_child(w)
		_wheels.append(w)
	var tag := Label.new()
	tag.text = "BEST"
	tag.label_settings = PixelFont.settings(8, Color.WHITE, 0)
	tag.position = Vector2(-14, -40)
	_body.add_child(tag)


func _process(_delta: float) -> void:
	var n := frames.size() / STRIDE
	var i := clampi(int(clock_ref.call() * RATE), 0, n - 1)
	visible = n > 0 and int(clock_ref.call() * RATE) < n
	var k := i * STRIDE
	_body.position = Vector2(frames[k], frames[k + 1])
	_body.rotation = frames[k + 2]
	for w in 2:
		var prev := _wheels[w].position
		_wheels[w].position = Vector2(frames[k + 3 + w * 2], frames[k + 4 + w * 2])
		_wheels[w].rotation += (_wheels[w].position.x - prev.x) / Bus.WHEEL_RADIUS
