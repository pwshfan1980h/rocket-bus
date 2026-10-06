shader_type canvas_item;
// The band the bus drives on: a cross-section of road, roadbed, then soil.
// Drawn as a mesh hugging the ground line with UV = (world x, depth below the
// surface in px), so every look is a function of (x, depth).
//
// style: 0 asphalt, 1 dirt track, 2 packed snow, 3 regolith, 4 basalt, 5 alien rock

uniform int style = 0;
uniform vec4 top : source_color;      // 1px lit lip
uniform vec4 road : source_color;
uniform vec4 road_d : source_color;   // ruts, cracks, shading
uniform vec4 fleck : source_color;    // pebbles, sparkles, aggregate
uniform vec4 bed : source_color;      // roadbed under the surface
uniform vec4 bed_d : source_color;
uniform vec4 glow : source_color;     // embers (basalt) / crystals (alien); alpha 0 = none
uniform float road_depth = 7.0;
uniform float bed_depth = 4.0;
uniform bool curb = false;            // concrete curb blocks in the roadbed
uniform bool wet = false;             // rain: darker, glossy, shimmering puddles

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash2(vec2 p) {
	return hash(p.x * 12.9898 + p.y * 78.233);
}

void fragment() {
	float x = floor(UV.x);
	float d = floor(UV.y);
	// Ragged bottom edges, chunky (3-4px columns) so they read as pixel art.
	float col = floor(x / 3.0);
	float road_end = road_depth + floor(hash(col) * 2.0);
	float bed_end = road_end + bed_depth + floor(hash(col + 91.0) * 3.0) - 1.0;
	float n = hash2(vec2(x, d));
	vec4 c;
	if (d < 1.0) {
		c = top;
		if (style == 2 && n > 0.9) c = vec4(1.0);  // snow glints
	} else if (d < road_end) {
		c = road;
		float block = hash(floor(x / 11.0));
		if (style == 0) {  // asphalt: worn aggregate, the odd crack
			if (n > 0.93) c = fleck;
			else if (n < 0.05) c = road_d;
			if (d == 1.0) c = mix(road, top, 0.35);
			if (hash(floor(x / 37.0)) > 0.86 && abs(x - floor(x / 37.0) * 37.0 - 18.0 + d * 0.6) < 0.6) c = road_d;
		} else if (style == 1) {  // dirt: tyre ruts, pebbles, clods
			if (d == 2.0 || d == 3.0) c = mix(road, road_d, 0.55);
			if (block > 0.7) c = mix(c, road_d, 0.2);
			if (n > 0.92) c = fleck;
			else if (n < 0.06) c = road_d;
		} else if (style == 2) {  // packed snow: blue in the ruts, deepening shade
			c = mix(road, road_d, clamp((d - 1.0) / road_depth, 0.0, 1.0) * 0.6);
			if (d == 2.0) c = mix(c, road_d, 0.5);
			if (n > 0.96) c = vec4(1.0);
		} else if (style == 3) {  // regolith: fine grey dust + boot/tyre prints
			if (n > 0.9) c = fleck;
			else if (n < 0.08) c = road_d;
			if (d == 2.0 && mod(x, 6.0) < 3.0) c = road_d;  // tread prints
		} else if (style == 4) {  // basalt: dark slabs with hot seams
			if (mod(x + floor(d / 3.0) * 5.0, 17.0) < 1.0) c = road_d;
			if (n > 0.95) c = fleck;
		} else {  // alien rock: mottled, faintly glowing
			if (block > 0.6) c = mix(road, road_d, 0.4);
			if (n > 0.95) c = fleck;
		}
	} else if (d < bed_end) {
		// Roadbed: gravel / roots / packed ice, mottled in 2px chunks.
		float g = hash2(floor(vec2(x, d) / 2.0));
		c = g > 0.55 ? bed : bed_d;
		if (curb) {
			c = bed;
			if (mod(x, 24.0) < 1.0 || d == road_end) c = bed_d;  // block joints + shadow line
		}
		if (d == road_end && !curb) c = mix(c, vec4(0.0, 0.0, 0.0, 1.0), 0.35);  // shadow under the surface
	} else {
		// Below the roadbed the strata body shows through; scatter a few loose pebbles into it.
		if (d < bed_end + 3.0 && hash2(vec2(x, d) + 3.0) > 0.93) {
			c = bed_d;
		} else {
			discard;
		}
	}
	// Embers / crystals glinting in the roadbed and cracks.
	if (glow.a > 0.0 && d >= 2.0 && d < bed_end) {
		float g = hash2(vec2(floor(x / 2.0), floor(d / 2.0)) + 17.0);
		float pulse = 0.5 + 0.5 * sin(TIME * 2.0 + x * 0.37);
		if (g > 0.975) c = mix(c, glow, 0.6 + 0.4 * pulse);
	}
	if (wet && d < road_end) {
		c.rgb *= 0.82;
		// Puddles: stretches of the lip that mirror the sky, with glints sliding along them.
		float puddle = hash(floor(x / 23.0) + 5.0);
		if (puddle > 0.55 && d < 2.0) {
			float glint = sin(x * 0.9 - TIME * 6.0 + puddle * 40.0);
			c = mix(c, vec4(0.72, 0.84, 1.0, 1.0), glint > 0.75 ? 0.85 : 0.4);
		} else if (d < 1.0) {
			c = mix(c, vec4(0.8, 0.88, 1.0, 1.0), 0.3);
		}
	}
	COLOR = c;
}
