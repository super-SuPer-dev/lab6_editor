shader_type spatial;
render_mode unshaded, cull_disabled;

// Bubbling low-poly lava made only from sine waves (no textures, web friendly)
uniform vec4 hot_color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform vec4 dark_color : source_color = vec4(0.32, 0.04, 0.02, 1.0);
uniform float scale = 0.32;
uniform float glow = 1.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.35 + TIME) * 0.18 + cos(world_pos.z * 0.3 + TIME * 0.8) * 0.18;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float n = sin(p.x * 1.3 + TIME * 0.5) * sin(p.y * 1.1 - TIME * 0.35);
	n += 0.5 * sin((p.x + p.y) * 2.3 + TIME * 1.1);
	n += 0.35 * sin(length(p * 1.7) * 2.5 - TIME * 1.6);
	n = n * 0.3 + 0.5;
	vec3 c = mix(dark_color.rgb, mid_color.rgb, smoothstep(0.42, 0.68, n));
	c = mix(c, hot_color.rgb, smoothstep(0.76, 0.95, n));
	ALBEDO = c * glow;
}
