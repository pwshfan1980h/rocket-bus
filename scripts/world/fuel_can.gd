class_name FuelCan
extends Area2D
## Bobbing jerry can. Driving (or flying) through it tops up the rocket.

signal collected

const AMOUNT := 35.0

var _time := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the bus
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	add_child(shape)
	var light := PointLight2D.new()
	light.texture = preload("res://assets/sprites/light_radial.png")
	light.color = Color(1, 0.3, 0.3)
	light.energy = 0.8
	light.texture_scale = 0.8
	add_child(light)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body(body: Node) -> void:
	if _taken:
		return
	var bus := body.get_parent() as Bus
	if bus == null or bus.is_crashed:
		return
	_taken = true
	bus.fuel = minf(bus.fuel_capacity, bus.fuel + AMOUNT)
	Audio.play("fuel_pickup", -2.0)
	Fx.float_text(global_position + Vector2(0, -16), "+FUEL", Color("#ff5a5a"))
	collected.emit()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var y := sin(_time * 3.0) * 2.0
	var body := Color("#e03030")
	draw_rect(Rect2(-5, -7 + y, 10, 13), body)
	draw_rect(Rect2(-5, -7 + y, 10, 1), body.lightened(0.3))
	draw_rect(Rect2(-3, -10 + y, 4, 3), Color("#c8c8d0"))  # spout
	draw_rect(Rect2(1, -9 + y, 3, 2), Color("#303038"))  # handle
	draw_line(Vector2(-4, -5 + y), Vector2(4, 4 + y), body.darkened(0.3), 1.0)  # embossed X
	draw_line(Vector2(4, -5 + y), Vector2(-4, 4 + y), body.darkened(0.3), 1.0)
	var ring := 0.5 + 0.5 * sin(_time * 4.0)
	draw_arc(Vector2(0, y), 11 + ring * 2, 0, TAU, 16, Color(1, 0.9, 0.4, 0.5 * ring), 1.0)
