shader_type spatial;
// Simple checker floor so movement is easy to see.
uniform vec3 color_a : source_color = vec3(0.42, 0.55, 0.40);
uniform vec3 color_b : source_color = vec3(0.36, 0.49, 0.35);
uniform float tile = 2.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = floor(world_pos.xz / tile);
	float k = mod(c.x + c.y, 2.0);
	ALBEDO = mix(color_a, color_b, k);
	ROUGHNESS = 0.9;
}
