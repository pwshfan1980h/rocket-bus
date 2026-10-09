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
var weather: Weather
var tint: CanvasModulate
var shadow: BusShadow


func build(biome: String, segments: Array) -> World:
	biome_name = biome
	var b := Biomes.get_biome(biome)
	tint = CanvasModulate.new()
	tint.color = b.modulate
	add_child(tint)

	terrain = Terrain.new().build(segments, biome)
	var sky := CanvasLayer.new()
	sky.layer = -10
	backdrop = Backdrop.new().setup(biome, terrain.surface_y(0))
	sky.add_child(backdrop)
	add_child(sky)
	if b.get("wall", false):  # behind the road: drawn before the terrain
		add_child(HighwayWall.new().setup(terrain))
	add_child(terrain)
	props = Props.new().setup(terrain)
	add_child(props)
	weeds = Weeds.new().setup(terrain)
	add_child(weeds)
	shadow = BusShadow.new()
	shadow.terrain = terrain
	add_child(shadow)
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


func _ready() -> void:
	set_space_gravity(get_world_2d(), Biomes.get_biome(biome_name).get("gravity", 1.0))


static func set_space_gravity(w: World2D, scale: float) -> void:
	PhysicsServer2D.area_set_param(w.space, PhysicsServer2D.AREA_PARAM_GRAVITY,
			ProjectSettings.get_setting("physics/2d/default_gravity") * scale)


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
	shadow.bus = bus
	bus.impact_style = {"jungle": "mud", "mountain": "gravel", "snow": "snow", "volcano": "sparks",
			"moon": "moondust", "border": "spores"}.get(Biomes.base_name(biome_name), "dust")
	if weather:
		weather.bus = bus
	camera.target = bus.chassis
	camera.snap()
	return bus


func set_weather(kind: String) -> void:
	if kind == "":
		return
	var layer := CanvasLayer.new()
	layer.layer = 3
	backdrop.set_weather(kind)
	weather = Weather.new().setup(kind, terrain, tint)
	weather.bus = bus
	layer.add_child(weather)
	add_child(layer)


func start_ambience() -> void:
	var b := Biomes.get_biome(biome_name)
	Audio.music(b.music)
	Audio.ambience(b.ambience)
