class_name AmmoCrate
extends Area2D
## Olive crate of cannon slugs. Drive through it to reload.

const AMOUNT := 4

var _time := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body(body: Node) -> void:
	var bus := body.get_parent() as Bus
	if _taken or bus == null or bus.is_crashed:
		return
	_taken = true
	bus.ammo += AMOUNT
	Audio.play("ammo_pickup", -2.0)
	Fx.float_text(global_position + Vector2(0, -16), "+%d AMMO" % AMOUNT, Color("#b8e060"))
	bus.passengers.driver_say(["LOCKED AND LOADED!", "MORE BOOM!", "RELOADED!"].pick_random())
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var y := sin(_time * 3.0) * 2.0
	var c := Color("#6a7a3a")
	draw_rect(Rect2(-7, -6 + y, 14, 11), c)
	draw_rect(Rect2(-7, -6 + y, 14, 1), c.lightened(0.3))
	draw_rect(Rect2(-7, -1 + y, 14, 1), c.darkened(0.3))
	for k in 3:  # slug tips poking out
		draw_rect(Rect2(-5 + k * 4, -9 + y, 2, 3), Color("#e8c060"))
	var ring := 0.5 + 0.5 * sin(_time * 4.0)
	draw_arc(Vector2(0, y), 12 + ring * 2, 0, TAU, 16, Color(0.7, 1, 0.4, 0.5 * ring), 1.0)
