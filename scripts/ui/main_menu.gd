extends Node2D
## Start screen: a parked bus idling in a random world, the logo, and the menu.

const WORLDS := ["desert", "moon", "jungle", "mountain", "snow", "volcano", "city"]

static var _visit := 0

var world: World
var bus: Bus
var menu: MenuList
var _logo: Label
var _time := 0.0
var _chatter := 4.0
var _anchor: Node2D


func _ready() -> void:
	var biome: String = WORLDS[_visit % WORLDS.size()]
	_visit += 1
	world = World.new().build(biome, [{"t": "flat", "len": 3000}])
	add_child(world)
	bus = world.spawn_bus(Vector2(-60, world.terrain.surface_y(-60) - 31))
	bus.controls_enabled = false
	_anchor = Node2D.new()
	_anchor.position = Vector2(60, world.terrain.surface_y(0) - 60)
	add_child(_anchor)
	world.camera.target = _anchor
	world.camera.snap()
	Audio.music("music_menu")
	Audio.ambience(Biomes.get_biome(biome).ambience)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_logo = _label(ui, "ROCKET BUS", Vector2(0, 26), 32, Color("#ffcc26"), 6)
	_logo.label_settings.shadow_size = 2
	_logo.label_settings.shadow_color = Color("#ff4aa8")
	_logo.label_settings.shadow_offset = Vector2(3, 3)
	_logo.pivot_offset = Vector2(240, 16)
	_label(ui, "TIME THE ROCKET.  LAND IT LEVEL.", Vector2(0, 66), 8, Color.WHITE, 2)
	var entries := [["start", "START" if GameState.unlocked <= 1 else "CONTINUE  %s" % Levels.code(GameState.unlocked - 1)],
		["select", "LEVEL SELECT"], ["lab", "BUS LAB"], ["music", _onoff("MUSIC", GameState.music_on)],
		["sfx", _onoff("SOUND", GameState.sfx_on)], ["gore", _onoff("GORE", GameState.gore_on)]]
	if OS.get_name() != "Web":
		entries.append(["quit", "QUIT"])
	menu = MenuList.new().setup(entries, 8, 14)
	menu.position = Vector2(340, 104)
	ui.add_child(menu)
	menu.chosen.connect(_on_choice)
	_label(ui, "STARS %d/%d" % [GameState.total_stars(), Levels.count() * 3], Vector2(0, 244), 8, Color("#ffcc26"), 2)
	_label(ui, "MUSIC BY KEVIN MACLEOD (INCOMPETECH.COM)  CC BY 4.0", Vector2(0, 258), 8, Color(1, 1, 1, 0.35), 0)
	var world_name := _label(ui, Biomes.get_biome(biome).title, Vector2(8, 254), 8, Color(1, 1, 1, 0.4), 0)
	world_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	world_name.size.x = 200


func _process(delta: float) -> void:
	_time += delta
	_logo.rotation = sin(_time * 1.5) * 0.03
	_logo.scale = Vector2.ONE * (1.0 + sin(_time * 3.0) * 0.02)
	_chatter -= delta
	if _chatter <= 0.0:
		_chatter = randf_range(6.0, 11.0)
		if randf() < 0.25:
			bus.honk()
		else:
			bus.passengers.chatter(["ARE WE THERE YET?", "PRESS START!", "WHERE ARE WE GOING?",
					"I LIKE THIS BUS", "IS THAT A ROCKET?"].pick_random())


func _on_choice(id: String) -> void:
	if id in ["start", "select", "lab"]:
		menu.active = false  # no double-triggering while the screen fades out
	match id:
		"start":
			GameState.checkpoint = {}
			GameState.current_level = GameState.unlocked - 1
			Transition.go("res://scenes/level.tscn")
		"select":
			Transition.go("res://scenes/level_select.tscn")
		"lab":
			Transition.go("res://scenes/bus_lab.tscn")
		"music":
			GameState.music_on = not GameState.music_on
			menu.set_text("music", _onoff("MUSIC", GameState.music_on))
			GameState.apply_audio()
			GameState.save()
		"sfx":
			GameState.sfx_on = not GameState.sfx_on
			menu.set_text("sfx", _onoff("SOUND", GameState.sfx_on))
			GameState.apply_audio()
			GameState.save()
		"gore":
			GameState.gore_on = not GameState.gore_on
			menu.set_text("gore", _onoff("GORE", GameState.gore_on))
			GameState.save()
		"quit":
			get_tree().quit()


func _onoff(what: String, on: bool) -> String:
	return "%s: %s" % [what, "ON" if on else "OFF"]


func _label(parent: Node, text: String, pos: Vector2, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(480, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = PixelFont.settings(size, color, outline)
	parent.add_child(l)
	return l
