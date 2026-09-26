extends Node
## Progress + settings, saved to user://save.cfg.

const PATH := "user://save.cfg"
## Global game pace. Slows physics, timers and effects together (1.0 = full speed).
const PACE := 0.93

var current_level := 0
var unlocked := 1
var stars := {}  # level index -> 0..3
var best := {}  # level index -> score
var music_on := true
var sfx_on := true
var seen_intro := false


func _ready() -> void:
	Engine.time_scale = PACE
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		unlocked = cfg.get_value("progress", "unlocked", 1)
		stars = cfg.get_value("progress", "stars", {})
		best = cfg.get_value("progress", "best", {})
		music_on = cfg.get_value("settings", "music", true)
		sfx_on = cfg.get_value("settings", "sfx", true)
	apply_audio()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "best", best)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.save(PATH)


func apply_audio() -> void:
	Audio.set_volumes(1.0 if music_on else 0.0, 1.0 if sfx_on else 0.0)


func record(level: int, score: int, star_count: int) -> void:
	stars[level] = maxi(stars.get(level, 0), star_count)
	best[level] = maxi(best.get(level, 0), score)
	unlocked = maxi(unlocked, mini(level + 2, Levels.count()))
	save()


func total_stars() -> int:
	var n := 0
	for k in stars:
		n += stars[k]
	return n
