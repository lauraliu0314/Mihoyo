shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
varying float brightness;
void vertex() {
	brightness = INSTANCE_CUSTOM.r;
	vec4 center = MODEL_MATRIX[3];
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], center);
}
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float halo = exp(-radius * radius * 5.0) * (1.0 - smoothstep(0.65, 1.0, radius));
	float core = 1.0 - smoothstep(0.03, 0.18, radius);
	ALBEDO = mix(vec3(1.0, 0.48, 0.045), vec3(1.0, 0.9, 0.45), core);
	ALPHA = (halo * 0.65 + core * 0.8) * brightness;
}
