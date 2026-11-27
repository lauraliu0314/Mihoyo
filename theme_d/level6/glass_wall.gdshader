shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

// 立方体外壳：一层很薄的透明软膜，靠 1 米接缝和菲涅耳读出体积。
uniform int face_id = 0;
uniform float grid_count = 6.0;
uniform vec4 glass_color : source_color = vec4(0.96, 0.985, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 seam_color : source_color = vec4(0.20, 0.22, 0.26, 1.0);
uniform float glass_alpha = 0.075;
uniform float seam_alpha = 0.28;

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(glass_color.rgb, tint.rgb, 0.16);
	base *= 0.985 + 0.015 * uv.y;

	// 1 米接缝：细、浅，负责让透明外壳仍有格子可读。
	vec2 g = uv * grid_count;
	vec2 d = min(fract(g), 1.0 - fract(g));
	float line = 1.0 - smoothstep(0.006, 0.026, min(d.x, d.y));

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	vec3 col = mix(base, seam_color.rgb, line * 0.55);
	col = mix(col, vec3(1.0), fres * 0.45);

	ALBEDO = col;
	ALPHA = clamp(glass_alpha + fres * 0.16 + line * seam_alpha, 0.0, 0.58);
	ROUGHNESS = 0.075;
	METALLIC = 0.0;
	SPECULAR = 0.70;
	RIM = 0.20;
	RIM_TINT = 0.9;
	EMISSION = base * 0.025;
}
