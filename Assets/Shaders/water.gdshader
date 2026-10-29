shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Oasis pool water
uniform vec4 shallow : source_color = vec4(0.35, 0.85, 0.9, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.45, 0.75, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 1.5 + TIME * 2.0) * 0.03 + cos(world_pos.z * 1.7 + TIME * 1.6) * 0.03;
}

void fragment() {
	float w = sin(world_pos.x * 3.0 + TIME * 2.0) * sin(world_pos.z * 3.0 - TIME * 1.5) * 0.5 + 0.5;
	ALBEDO = mix(deep.rgb, shallow.rgb, w * 0.6 + 0.2);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	EMISSION = shallow.rgb * 0.12 * w;
}
