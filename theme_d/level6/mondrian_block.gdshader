shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// De Stijl 积木：亮面搪瓷 + 粗黑边 + 单块主色矩形。
// 每个面按 pattern_seed 翻转构图，避免六个面完全一样。
uniform vec4 base_color : source_color = vec4(0.84, 0.06, 0.08, 1.0);
uniform vec4 accent_color : source_color = vec4(0.07, 0.07, 0.07, 1.0);
uniform vec4 ink : source_color = vec4(0.04, 0.04, 0.04, 1.0);
uniform float pattern_seed = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.14;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform float socket : hint_range(0.0, 1.0) = 0.0;

float rect_mask(vec2 uv, vec2 lo, vec2 hi) {
	vec2 a = smoothstep(lo - 0.004, lo + 0.004, uv);
	vec2 b = 1.0 - smoothstep(hi - 0.004, hi + 0.004, uv);
	return a.x * a.y * b.x * b.y;
}

float line_mask(float v, float at, float w) {
	return 1.0 - smoothstep(w, w + 0.006, abs(v - at));
}

void fragment() {
	vec2 uv = UV;
	float s = fract(pattern_seed * 0.6180339);
	if (s > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (fract(s * 3.7) > 0.5) {
		uv.y = 1.0 - uv.y;
	}

	vec3 col = base_color.rgb;

	// 主色右侧大块。
	float accent = rect_mask(uv, vec2(0.56, 0.10), vec2(0.90, 0.86));
	col = mix(col, accent_color.rgb, accent);

	// 左下小黑块，给每个面一个不对称的构图锚点。
	float black_block = rect_mask(uv, vec2(0.10, 0.10), vec2(0.27, 0.35));
	col = mix(col, ink.rgb, black_block);

	// 一条贯穿的细分隔线。
	float div = line_mask(uv.x, 0.52, 0.010) * step(0.06, uv.y) * step(uv.y, 0.94);
	col = mix(col, ink.rgb, div * 0.90);

	// 黑色外框。
	float border = 1.0 - rect_mask(uv, vec2(0.035, 0.035), vec2(0.965, 0.965));
	col = mix(col, ink.rgb, border);

	// 固定基座顶部的黑/黄 socket；其余块为 0。
	float socket_mask = 0.0;
	if (socket > 0.5) {
		float sq = rect_mask(uv, vec2(0.29, 0.29), vec2(0.71, 0.71));
		float sq_in = rect_mask(uv, vec2(0.37, 0.37), vec2(0.63, 0.63));
		col = mix(col, ink.rgb, sq);
		col = mix(col, accent_color.rgb, sq_in);
		socket_mask = sq_in;
	}

	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	EMISSION = accent_color.rgb * glow * (accent + socket_mask) * 0.85;
}
