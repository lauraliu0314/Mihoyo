shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(1.0, 0.76, 0.08, 1.0);
uniform float brightness : hint_range(0.0, 5.0, 0.05) = 3.0;
uniform float pulse_speed : hint_range(0.0, 5.0, 0.05) = 1.8;

void fragment() {
	vec2 p = abs(UV - vec2(0.5));
	float d = max(p.x, p.y);
	float border = smoothstep(0.405, 0.445, d)
		* (1.0 - smoothstep(0.458, 0.49, d));
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed);
	ALBEDO = glow_color.rgb * 0.18;
	EMISSION = glow_color.rgb * brightness * pulse * border;
	ALPHA = border * pulse;
}
