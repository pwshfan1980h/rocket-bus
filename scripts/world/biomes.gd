class_name Biomes
## Look, sound and life of each world. Levels pick one by name.
##
## layers: far -> near backdrop silhouettes. kind = mesas | dunes | peaks | hills |
##         forest | canopy | volcanoes | city. parallax 0..1, h = max height px.
## life:   birds, perched, lizards, bugs, flies, tumbleweeds, leaves, dust,
##         snow, embers, ash, fireflies, butterflies

const ALL := {
	"city": {
		"title": "BAY CITY",
		"sky": ["#221246", "#3c1a64", "#682480", "#aa3484", "#e25676", "#fc8860", "#ffb868"],
		"sun": {"r": 30, "top": "#ffec8c", "bottom": "#ff5a78", "stripes": true, "x": 340},
		"stars": 0.6, "aurora": false,
		"modulate": Color(0.68, 0.6, 0.84),
		"layers": [
			{"kind": "hills", "parallax": 0.05, "color": "#762e6c", "h": 34},
			{"kind": "city", "parallax": 0.15, "color": "#3e1a54", "h": 76},
		],
		"ground": {"road": "#3a3448", "edge": "#686278", "line": "#ffd03c", "shoulder": "#968496",
			"body": ["#3e2238", "#46283e", "#3a1e34"]},
		"decor": ["streetlight", "palm", "hydrant"], "fg": "",
		"life": ["birds", "perched", "dust"],
		"music": "music_menu", "ambience": "amb_city_loop", "friction": 1.0,
		"chatter": ["NICE VIEW!", "IS THIS MY STOP?", "SMELLS LIKE TACOS"],
	},
	"desert": {
		"title": "DESERT",
		"sky": ["#2a1a52", "#5a2a74", "#9a3a78", "#d8586a", "#f4845a", "#ffae5c", "#ffd88a"],
		"sun": {"r": 34, "top": "#fff0a0", "bottom": "#ff7a50", "stripes": true, "x": 330},
		"stars": 0.3, "aurora": false,
		"modulate": Color(0.92, 0.78, 0.74),
		"layers": [
			{"kind": "mesas", "parallax": 0.04, "color": "#a2486a", "h": 60},
			{"kind": "dunes", "parallax": 0.12, "color": "#c05a5a", "h": 30},
			{"kind": "mesas", "parallax": 0.25, "color": "#7a2e4a", "h": 46, "stripes": "#6a2640"},
		],
		"ground": {"road": "#4a3a44", "edge": "#8a7478", "line": "#ffe070", "shoulder": "#e0a060",
			"body": ["#c8704a", "#b05a3e", "#d88a58", "#9a4a36"]},
		"decor": ["cactus", "cactus", "rock", "skull", "post"], "fg": "cactus",
		"life": ["birds", "perched", "lizards", "tumbleweeds", "dust", "bugs", "vultures", "snakes"],
		"music": "music_desert", "ambience": "amb_desert_loop", "friction": 1.0,
		"chatter": ["IT'S SO HOT!", "ARE WE THERE YET?", "I SEE A CACTUS", "NEED... WATER...",
			"WHO BUILT THIS ROAD?"],
	},
	"jungle": {
		"title": "JUNGLE",
		"sky": ["#123a3a", "#1a5048", "#2a6a50", "#4a8a5a", "#7aa866", "#b0c47a", "#d8dc98"],
		"sun": {"r": 22, "top": "#fffce0", "bottom": "#f0f0a0", "stripes": false, "x": 120},
		"stars": 0.0, "aurora": false,
		"modulate": Color(0.72, 0.86, 0.72),
		"layers": [
			{"kind": "hills", "parallax": 0.04, "color": "#3a7a5a", "h": 50},
			{"kind": "canopy", "parallax": 0.12, "color": "#2a6246", "h": 64},
			{"kind": "canopy", "parallax": 0.28, "color": "#1a4834", "h": 80},
		],
		"ground": {"road": "#4a3a2a", "edge": "#7a6444", "line": "", "shoulder": "#4a8a3a",
			"body": ["#5a3a26", "#6a4630", "#4a2e20", "#3e2a1c"]},
		"decor": ["fern", "fern", "bigtree", "rock", "post"], "fg": "jungle",
		"life": ["birds", "perched", "flies", "butterflies", "leaves", "dust", "lizards", "fireflies", "monkeys"],
		"music": "music_jungle", "ambience": "amb_jungle_loop", "friction": 0.95,
		"chatter": ["SO HUMID!", "SOMETHING BIT ME!", "WAS THAT A MONKEY?", "BUGS! BUGS!",
			"I LOVE NATURE"],
	},
	"mountain": {
		"title": "MOUNTAINS",
		"sky": ["#1a1e4a", "#28306a", "#3a4a8a", "#5a6aa8", "#8a90c0", "#c0aac8", "#f0c4b0"],
		"sun": {"r": 14, "top": "#ffffff", "bottom": "#d8e0ff", "stripes": false, "x": 90},
		"stars": 0.7, "aurora": false,
		"modulate": Color(0.66, 0.68, 0.86),
		"layers": [
			{"kind": "peaks", "parallax": 0.03, "color": "#4a5288", "h": 110, "cap": "#d8dcf0"},
			{"kind": "peaks", "parallax": 0.1, "color": "#363c6a", "h": 80, "cap": "#b8bce0"},
			{"kind": "forest", "parallax": 0.26, "color": "#1c2440", "h": 40},
		],
		"ground": {"road": "#3e3a44", "edge": "#6a6674", "line": "#e8e8f0", "shoulder": "#5a7a4a",
			"body": ["#5a5460", "#4a4652", "#666070", "#3e3a46"]},
		"decor": ["pine", "pine", "rock", "guardrail", "post"], "fg": "pine",
		"life": ["birds", "perched", "leaves", "dust", "goats"],
		"music": "music_mountain", "ambience": "amb_mountain_loop", "friction": 1.0,
		"chatter": ["MY EARS POPPED", "LOOK AT THAT VIEW!", "DON'T LOOK DOWN", "IS THAT A GOAT?"],
	},
	"snow": {
		"title": "SNOW",
		"sky": ["#060a22", "#0c1434", "#142048", "#1c2c5c", "#263c70", "#34507e", "#4a6488"],
		"sun": {"r": 16, "top": "#f4f6ff", "bottom": "#c8d0f0", "stripes": false, "x": 380, "moon": true},
		"stars": 1.0, "aurora": true,
		"modulate": Color(0.46, 0.5, 0.72),
		"layers": [
			{"kind": "peaks", "parallax": 0.03, "color": "#3a4a78", "h": 100, "cap": "#e8f0ff"},
			{"kind": "peaks", "parallax": 0.1, "color": "#2c3a64", "h": 70, "cap": "#c8d8f8"},
			{"kind": "forest", "parallax": 0.24, "color": "#16203c", "h": 42, "cap": "#8898c8"},
		],
		"ground": {"road": "#8a92a8", "edge": "#e8f0ff", "line": "", "shoulder": "#f4f8ff",
			"body": ["#c8d4ec", "#aab8d8", "#dce6f8", "#98a8cc"]},
		"decor": ["snowpine", "snowpine", "snowman", "rock", "post"], "fg": "snowpine",
		"life": ["birds", "perched", "snow", "dust", "penguins"],
		"music": "music_snow", "ambience": "amb_snow_loop", "friction": 0.75,
		"chatter": ["BRRR!", "I CAN'T FEEL MY TOES", "IS THE HEATER ON?", "SNOWBALL FIGHT!"],
	},
	"volcano": {
		"title": "VOLCANO",
		"sky": ["#1a0608", "#2e0a0c", "#4a1010", "#6a1a12", "#8a2a14", "#b04418", "#d86a20"],
		"sun": {"r": 0},
		"stars": 0.0, "aurora": false,
		"modulate": Color(0.7, 0.5, 0.48),
		"layers": [
			{"kind": "volcanoes", "parallax": 0.04, "color": "#3a1414", "h": 120},
			{"kind": "peaks", "parallax": 0.12, "color": "#2a0e10", "h": 60},
			{"kind": "mesas", "parallax": 0.26, "color": "#1c0a0c", "h": 40},
		],
		"ground": {"road": "#2a2226", "edge": "#5a4448", "line": "#ff8a2a", "shoulder": "#3a2a2a",
			"body": ["#3a2a2e", "#2a1e22", "#4a2a26", "#221a1e"]},
		"decor": ["rock", "rock", "deadtree", "skull", "post"], "fg": "",
		"life": ["birds", "perched", "lizards", "embers", "ash", "bats", "vultures"],
		"music": "music_volcano", "ambience": "amb_volcano_loop", "friction": 1.0,
		"chatter": ["IS THAT LAVA?!", "IT'S GETTING HOT IN HERE", "I SMELL SMOKE", "WHY IS THE SKY RED?",
			"THIS IS FINE"],
	},
	"moon": {
		"title": "MOON",
		"sky": ["#02020a", "#04040e", "#060614", "#08081a", "#0a0a20", "#0c0c26", "#10102c"],
		"sun": {"r": 0}, "earth": true,
		"stars": 1.6, "aurora": false,
		"modulate": Color(0.82, 0.84, 0.95),
		"layers": [
			{"kind": "craters", "parallax": 0.04, "color": "#3a3a48", "h": 70},
			{"kind": "craters", "parallax": 0.12, "color": "#2c2c38", "h": 48},
			{"kind": "craters", "parallax": 0.26, "color": "#1e1e28", "h": 30},
		],
		"ground": {"road": "#5a5a66", "edge": "#a8a8b4", "line": "#e8e8f0", "shoulder": "#b0b0ba",
			"body": ["#8a8a94", "#7a7a86", "#9a9aa4", "#6a6a76"]},
		"decor": ["moonrock", "moonrock", "flag", "lander", "dish"], "fg": "",
		"life": ["dust"], "gravity": 0.4,
		"music": "music_moon", "ambience": "amb_moon_loop", "friction": 0.85,
		"chatter": ["ONE SMALL STEP...", "I'M FLOATING!", "IS THAT EARTH?", "WHY IS THE BUS FLOATY?",
			"I CAN'T BREATHE! ...OH WAIT."],
	},
	# An alien border dimension (a nod to Half-Life's): floating islands in a green void.
	"border": {
		"title": "BORDERWORLD",
		"sky": ["#040c0a", "#071811", "#0b2418", "#10321f", "#164028", "#1d5032", "#26603c"],
		"sun": {"r": 0}, "nebula": true,
		"stars": 0.9, "aurora": false,
		"modulate": Color(0.72, 0.9, 0.84),
		"layers": [
			{"kind": "islands", "parallax": 0.03, "color": "#1a3a2e", "h": 60, "float": true},
			{"kind": "islands", "parallax": 0.1, "color": "#132c24", "h": 50, "float": true},
			{"kind": "islands", "parallax": 0.22, "color": "#0c1e18", "h": 40, "float": true},
		],
		"ground": {"road": "#2c2a3c", "edge": "#7ac8a0", "line": "", "shoulder": "#3a8a6a",
			"body": ["#3a3048", "#2e2640", "#46385a", "#261e34"]},
		"floating": true,
		"decor": ["alienplant", "alienplant", "crystal", "stalk"], "fg": "",
		"life": ["spores", "jellies"], "gravity": 0.75,
		"music": "music_border", "ambience": "amb_border_loop", "friction": 0.9,
		"chatter": ["WHERE ARE WE?!", "THE ROCKS ARE FLOATING!", "I DON'T LIKE THIS DIMENSION",
			"IS THAT A JELLYFISH?", "TAKE ME HOME!", "WHO BROUGHT US HERE?"],
	},
}


static func get_biome(name: String) -> Dictionary:
	return ALL.get(name, ALL.desert)


static func color(c) -> Color:
	return c if c is Color else Color(c)
