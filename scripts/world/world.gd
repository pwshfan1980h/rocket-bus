class_name World
extends Node2D
## One playable scene's worth of world, assembled in draw order:
##   night tint, parallax backdrop, terrain + gaps, props, weeds, fuel cans,
##   [bus goes here], wildlife, glow layer, foreground silhouettes, camera.

signal fuel_collected(can: FuelCan)

const BusScene := preload("res://scenes/bus.tscn")

var biome_name := "desert"
var terrain: Terrain
var props: Props
var weeds: Weeds
var life: Life
var camera: Camera2D
var bus: Bus
var backdrop: Backdrop
var obstacles: Array[Obstacle] = []


func build(biome: String, segments: Array) -> World:
	biome_name = biome
	var b := Biomes.get_biome(biome)
	var tint := CanvasModulate.new()
	tint.color = b.modulate
	add_child(tint)

	terrain = Terrain.new().build(segments, biome)
	var sky := CanvasLayer.new()
	sky.layer = -10
	backdrop = Backdrop.new().setup(biome, terrain.surface_y(0))
	sky.add_child(backdrop)
	add_child(sky)
	add_child(terrain)
	props = Props.new().setup(terrain)
	add_child(props)
	weeds = Weeds.new().setup(terrain)
	add_child(weeds)
	for o in terrain.objects:
		var ob := Obstacle.new().setup(o.kind)
		ob.position = Vector2(o.x, terrain.surface_y(o.x) + 1)
		add_child(ob)
		obstacles.append(ob)
	for p in terrain.ammo_spots:
		var crate := AmmoCrate.new()
		crate.position = p
		add_child(crate)
	for p in terrain.pickups:
		var can := FuelCan.new()
		can.position = p
		can.collected.connect(func(): fuel_collected.emit(can))
		add_child(can)

	var glow_layer := CanvasLayer.new()
	glow_layer.layer = 1
	glow_layer.follow_viewport_enabled = true
	var glow := Node2D.new()
	glow_layer.add_child(glow)
	add_child(glow_layer)
	life = Life.new().setup(terrain, props, glow)
	life.z_index = 5
	add_child(life)
	var fg_layer := CanvasLayer.new()
	fg_layer.layer = 2
	fg_layer.add_child(Foreground.new().setup(terrain))
	add_child(fg_layer)

	camera = preload("res://scripts/lab/follow_camera.gd").new()
	camera.terrain = terrain
	add_child(camera)
	return self


func spawn_bus(at := Vector2.INF, fuel := 100.0, vel := Vector2.ZERO) -> Bus:
	if bus:
		bus.queue_free()
	if at == Vector2.INF:
		at = terrain.start_position()
	bus = BusScene.instantiate()
	bus.fuel_capacity = fuel
	bus.setup(at, 0.0, vel)
	add_child(bus)
	move_child(bus, life.get_index())
	weeds.bus = bus
	life.bus = bus
	camera.target = bus.chassis
	camera.snap()
	return bus


func start_ambience() -> void:
	var b := Biomes.get_biome(biome_name)
	Audio.music(b.music)
	Audio.ambience(b.ambience)
