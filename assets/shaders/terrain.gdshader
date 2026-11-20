shader_type canvas_item;
// The ground under the road: strata that bend with the road above, falling into
// darkness with depth, with things buried in it (pebbles, bones, roots, ice,
// magma veins, craters, crystals, pipes) so the slab isn't one flat stripe.
//
// The road height at each x comes from `surf` (a 1px-tall strip baked by
// terrain.gd: road y * 16 in R+G, 1 in B over an island), so every look below is
// a function of (world x, depth below the road).
//
// soil: 0 rock, 1 desert, 2 jungle, 3 snow, 4 volcano, 5 moon, 6 border, 7 city

uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform float band = 11.0;
uniform float depth_start = 60.0;  // fallback when no surface strip is bound
uniform sampler2D surf : filter_nearest, repeat_disable;
uniform bool has_surf = false;
uniform float surf_x0 = 0.0;      // world x of texel 0
uniform float surf_step = 4.0;    // world px per texel
uniform float surf_base = 0.0;    // world y encoded as 0
uniform int soil = 0;
uniform vec4 rock : source_color = vec4(0.5, 0.45, 0.45, 1.0);
uniform vec4 accent : source_color = vec4(0.9, 0.85, 0.7, 1.0);  // bones / roots / ice / magma / crystal / brick
uniform float darkness = 1.0;     // how far the deep ground falls into shadow (0..1)

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash2(vec2 p) {
	return hash(p.x * 12.9898 + p.y * 78.233);
}

// 4x4 ordered-dither threshold in 0..1.
float bayer4(vec2 p) {
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

vec2 texel(float i) {
	int w = textureSize(surf, 0).x;
	vec4 t = texelFetch(surf, ivec2(clamp(int(i), 0, w - 1), 0), 0);
	float y = (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 16.0 + surf_base;
	return vec2(y, t.b);
}

float road_y(float x) {
	float f = (x - surf_x0) / surf_step;
	float i = floor(f);
	vec2 a = texel(i);
	vec2 b = texel(i + 1.0);
	if (b.y < 0.5) return a.x;  // next texel is over a gap: hold the edge height
	if (a.y < 0.5) return b.x;
	return mix(a.x, b.x, f - i);
}

// Rounded stone: lit upper-left rim, shaded lower-right, dark lower outline. .w = coverage.
vec4 stone(vec2 q, vec2 r, vec3 base) {
	vec2 n = q / r;
	float d = dot(n, n);
	if (d > 1.0) return vec4(0.0);
	vec3 c = base;
	float lit = -n.x * 0.4 - n.y * 0.9;
	if (d > 0.45) c = lit > 0.25 ? base * 1.28 : (lit < -0.25 ? base * 0.66 : base);
	if (d > 0.8 && lit < -0.1) c = base * 0.45;
	return vec4(c, 1.0);
}

void fragment() {
	vec2 p = floor(world);
	float depth = has_surf ? p.y - floor(road_y(p.x + 0.5)) : p.y - depth_start + 60.0;
	// Strata: mostly parallel to the road, a little level with the world, wobbling.
	float wob = hash(floor(p.x / 7.0)) * 3.0 + sin(p.x * 0.045) * 4.0;
	float sy = depth * 0.7 + p.y * 0.3;
	float b = floor((sy + wob) / band);
	int idx = int(mod(b, 4.0));
	vec4 col = idx == 0 ? c0 : idx == 1 ? c1 : idx == 2 ? c2 : c3;
	if (mod(sy + wob, band) < 1.0) col.rgb *= 0.88;  // a darker seam on each layer
	float s = hash2(p);
	if (s > 0.965) {
		col.rgb *= 0.78;
	} else if (s < 0.015) {
		col.rgb *= 1.15;
	}

	// --- buried things, in cells laid along the road (x, depth) ---------------
	vec2 cellsz = vec2(22.0, 18.0);
	vec2 cp = floor(vec2(p.x, depth) / 2.0);  // art pixels: 2 world px
	float ad = cp.y;
	vec2 cell = floor(cp / cellsz);
	vec2 local = cp - cell * cellsz;
	float h = hash2(cell + 7.3);
	float h2 = hash2(cell + 19.1);
	float h3 = hash2(cell + 41.7);
	vec2 q = local - vec2(6.0 + floor(h2 * (cellsz.x - 12.0)), 6.0 + floor(h3 * (cellsz.y - 12.0)));
	if (ad > 11.0 && h < 0.3) {
		float kind = hash2(cell + 3.9);
		vec2 r = vec2(2.0 + floor(h2 * 3.0), 1.5 + floor(h3 * 2.0));
		vec3 rc = rock.rgb * (0.85 + 0.3 * hash(cell.x + cell.y * 3.1));
		bool special = kind > 0.6;
		if (soil == 1 && special) {
			if (kind > 0.86) {  // ammonite fossil: ring with a core and an inner curl
				float rr = length(q);
				if (rr < 3.6 && (rr > 2.5 || rr < 1.1)) col.rgb = accent.rgb * (q.y < 0.0 ? 1.0 : 0.8);
				else if (rr < 2.5 && q.x > 0.5 && q.y < 0.5) col.rgb = accent.rgb * 0.72;
			} else {  // bone: shaft with knobbly ends
				vec2 a = abs(q);
				if ((a.x < 4.0 && a.y < 1.0) || (a.x >= 3.0 && a.x < 6.0 && a.y < 2.0 && (a.x - 3.0) + a.y < 3.0))
					col.rgb = accent.rgb * (q.y < 0.0 ? 1.0 : 0.8);
			}
		} else if (soil == 3 && special) {  // ice crystal: blue diamond with a white glint
			float m = abs(q.x) * 0.7 + abs(q.y);
			if (m < 3.6) col.rgb = accent.rgb * (q.x - q.y > 0.0 ? 0.82 : 1.0);
			if (m < 1.3 && q.x <= 0.0 && q.y <= 0.0) col.rgb = vec3(1.0);
		} else if (soil == 5) {  // moon: craters with a lit far rim and a shaded near rim
			float rr = length(q / vec2(1.0, 0.6));
			float cr = 3.0 + floor(h2 * 3.0);
			if (rr < cr) col.rgb *= rr > cr - 1.5 ? (q.y > 0.0 ? 1.22 : 0.68) : 0.86;
		} else if (soil == 6 && special) {  // glowing crystal shard
			float m = abs(q.x) * 1.4 + abs(q.y) * 0.6;
			if (m < 3.4) {
				float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + cell.x * 1.7 + cell.y);
				col.rgb = accent.rgb * pulse * (q.x < 0.0 ? 1.3 : 0.9);
			}
		} else if (soil == 7 && special) {  // broken brick
			vec2 a = abs(q);
			if (a.x < 4.0 && a.y < 2.0) col.rgb = mod(q.x + 4.0, 4.0) < 1.0 ? accent.rgb * 0.6 : accent.rgb;
		} else {
			vec4 st = stone(q, r, rc);
			if (st.a > 0.0) col.rgb = st.rgb;
		}
	}
	// Jungle: roots reaching down from the road into the soil.
	if (soil == 2 && ad > 6.0 && ad < 44.0) {
		float rx = floor(cp.x / 7.0);
		float len = 12.0 + hash(rx + 2.0) * 30.0;
		if (hash(rx) > 0.55 && ad < len) {
			float off = floor(2.5 + sin(ad * 0.35 + rx) * 1.6 + hash(rx + 5.0) * 1.5);
			float w = ad < len * 0.4 ? 2.0 : 1.0;
			float m = mod(cp.x, 7.0);
			if (m >= off && m < off + w) col.rgb = accent.rgb * (ad < 16.0 ? 1.0 : 0.78);
		}
	}
	// Volcano: glowing magma cracks (a cell-edge network) deeper down, breathing.
	if (soil == 4 && depth > 64.0) {
		vec2 sc = vec2(19.0, 14.0);
		vec2 g = cp / sc;
		vec2 gi = floor(g);
		float d1 = 99.0;
		float d2 = 99.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 o = gi + vec2(float(i), float(j));
				vec2 pt = o + vec2(hash2(o), hash2(o + 5.1));
				float dd = length((g - pt) * sc);
				if (dd < d1) { d2 = d1; d1 = dd; } else if (dd < d2) { d2 = dd; }
			}
		}
		float edge = d2 - d1;
		// Only some seams run hot; which ones changes every few cells.
		bool hot = hash2(floor(g / 3.0) + 2.0) > 0.5 && hash2(floor(cp / 4.0) + 9.0) > 0.3;
		float pulse = 0.6 + 0.4 * sin(TIME * 1.6 + hash2(gi) * 6.0 + p.x * 0.01);
		float heat = clamp((depth - 64.0) / 160.0, 0.0, 1.0);
		if (hot && edge < 0.9 && heat > 0.15) {
			col.rgb = mix(col.rgb, accent.rgb * (1.0 + 0.5 * pulse), 0.35 + 0.65 * heat);
		} else if (hot && edge < 2.2 && bayer4(cp) < 0.4 * heat * pulse) {
			col.rgb = mix(col.rgb, accent.rgb * 0.7, 0.45);
		}
	}
	// City: a sewer main and a cable duct running under the street.
	if (soil == 7) {
		float pd = ad - 22.0;
		if (pd >= 0.0 && pd < 5.0) {
			vec3 pipe = vec3(0.34, 0.32, 0.4);
			col.rgb = pd < 1.0 ? pipe * 1.4 : (pd >= 4.0 ? pipe * 0.6 : pipe);
			if (mod(cp.x, 36.0) < 2.0) col.rgb = pipe * (pd < 1.0 ? 1.6 : 1.15);  // flanged joints
		}
		float cd = ad - 15.0;
		if (cd >= 0.0 && cd < 1.0 && mod(cp.x, 6.0) < 4.0) col.rgb = vec3(0.14, 0.12, 0.18);
	}
	// Fall into darkness with depth: flat steps with dithered edges (crisp pixels).
	float dk = clamp((depth - 30.0) / 240.0, 0.0, 1.0) * darkness;
	float lv = clamp(floor(dk * 4.0 + (bayer4(floor(p / 2.0)) - 0.5) * 0.9), 0.0, 4.0) / 4.0;
	if (!(soil == 4 && col.r > col.b * 2.5 && col.r > 0.7)) col.rgb *= 1.0 - lv * 0.66;  // magma stays lit
	// Contact shadow right under the road band.
	if (depth < 30.0 && bayer4(floor(p / 2.0)) < (30.0 - depth) / 22.0 * 0.55) col.rgb *= 0.8;
	COLOR = col;
}
