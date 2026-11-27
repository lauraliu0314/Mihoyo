shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha;

// 软糖材质：半透明、亮面、边缘带一点糖霜/果冻感。
uniform vec4 gummy_color : source_color = vec4(1.0, 0.62, 0.25, 0.92);
uniform float sugar : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec3 c = gummy_color.rgb;
	ALBEDO = c;
	ALPHA = gummy_color.a;
	ROUGHNESS = mix(0.16, 0.38, sugar);
	METALLIC = 0.0;
	SPECULAR = 0.7;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * glow;
	EMISSION += mix(c, vec3(1.0), sugar) * fres * (0.35 + sugar * 0.45);
}
