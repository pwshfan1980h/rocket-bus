shader_type canvas_item;
// Rock/soil strata banded by world height, with wobble and speckles.

uniform vec4 c0 : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 c3 : source_color;
uniform float band = 11.0;
uniform float depth_start = 60.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = floor(world);
	float wob = hash(floor(p.x / 7.0)) * 3.0 + sin(p.x * 0.045) * 4.0;
	float b = floor((p.y + wob) / band);
	int idx = int(mod(b, 4.0));
	vec4 col = idx == 0 ? c0 : idx == 1 ? c1 : idx == 2 ? c2 : c3;
	float s = hash(p.x * 12.9898 + p.y * 78.233);
	if (s > 0.965) {
		col.rgb *= 0.78;
	} else if (s < 0.015) {
		col.rgb *= 1.15;
	}
	col.rgb *= clamp(1.0 - (world.y - depth_start) / 420.0, 0.3, 1.0);
	COLOR = col;
}
