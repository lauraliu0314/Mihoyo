shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// 白色工作室墙面：近白底、极淡的 1 米接缝、每面一点点粉彩 tint。
uniform int face_id = 0;
uniform float grid_count = 6.0;
uniform vec4 wall_color : source_color = vec4(0.790, 0.785, 0.772, 1.0);
uniform vec4 seam_color : source_color = vec4(0.660, 0.655, 0.640, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 0.94, 0.95, 1.0);

void fragment() {
	vec2 uv = UV;

	// 白底 + 每面 10% 的粉彩 tint，白墙也不会失去方位感。
	vec3 base = mix(wall_color.rgb, tint.rgb, 0.03);
	base *= 0.955 + 0.045 * uv.y;

	// 1 米接缝：浅灰细线，不用黑线；白墙必须靠它读出格子。
	vec2 g = uv * grid_count;
	vec2 d = min(fract(g), 1.0 - fract(g));
	float line = 1.0 - smoothstep(0.008, 0.030, min(d.x, d.y));
	base = mix(base, seam_color.rgb, line * 0.72);

	// 墙脚和墙角压暗，纯白空间才有体积。
	float foot = smoothstep(0.20, 0.0, uv.y);
	base *= 1.0 - 0.16 * foot;
	float edge_x = smoothstep(0.0, 0.14, min(uv.x, 1.0 - uv.x));
	float edge_y = smoothstep(0.0, 0.14, min(uv.y, 1.0 - uv.y));
	base *= mix(0.84, 1.0, edge_x * edge_y);

	// 墙单独再压一点亮度：白色外壳不要抢物块，也不要过曝。
	base *= 0.88;

	ALBEDO = base;
	ROUGHNESS = 0.90;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
