shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

// Swirling glow shown inside the door once it is unlocked
uniform vec4 color_a : source_color = vec4(0.4, 1.0, 0.7, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.6, 1.0, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float swirl = sin(a * 5.0 + r * 10.0 - TIME * 4.0) * 0.5 + 0.5;
	vec3 c = mix(color_a.rgb, color_b.rgb, swirl);
	float mask = smoothstep(1.0, 0.55, r);
	ALBEDO = c * mask * (0.7 + swirl * 0.8);
	ALPHA = mask;
}
