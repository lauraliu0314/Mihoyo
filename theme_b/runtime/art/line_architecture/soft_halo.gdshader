shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.32, 0.7, 0.9, 1.0);
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
	VERTEX += NORMAL * 0.026;
}
void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float pulse = 0.8 + 0.2 * sin(TIME * 1.25 + local_position.y * 7.0);
	ALBEDO = tint.rgb;
	ALPHA = 0.1 * facing * pulse;
}
