shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// De Stijl 六面墙：奶油底 + 红/蓝/黄矩形 + 粗黑分隔线。
// 粗线对齐 1 米格，细线保留走位网格；face_id 旋转构图，让六面可区分。
uniform int face_id = 0;
uniform float grid_count = 6.0;
uniform vec4 cream : source_color = vec4(0.95, 0.93, 0.87, 1.0);
uniform vec4 red : source_color = vec4(0.84, 0.16, 0.16, 1.0);
uniform vec4 blue : source_color = vec4(0.11, 0.31, 0.54, 1.0);
uniform vec4 yellow : source_color = vec4(0.95, 0.72, 0.02, 1.0);
uniform vec4 ink : source_color = vec4(0.04, 0.04, 0.04, 1.0);

float rect_mask(vec2 uv, vec2 lo, vec2 hi) {
	vec2 a = smoothstep(lo - 0.003, lo + 0.003, uv);
	vec2 b = 1.0 - smoothstep(hi - 0.003, hi + 0.003, uv);
	return a.x * a.y * b.x * b.y;
}

float band(float v, float at, float w) {
	return 1.0 - smoothstep(w, w + 0.006, abs(v - at));
}

float grid_line(vec2 uv, float count, float w) {
	vec2 g = fract(uv * count);
	vec2 d = min(g, 1.0 - g);
	float m = min(d.x, d.y);
	return 1.0 - smoothstep(w, w + 0.006, m);
}

void fragment() {
	vec2 uv = UV;
	// 六个面用旋转/镜像得到不同的构成，但都保持网格对齐。
	if (face_id == 1) {
		uv = vec2(uv.y, 1.0 - uv.x);
	} else if (face_id == 2) {
		uv = vec2(1.0 - uv.x, 1.0 - uv.y);
	} else if (face_id == 3) {
		uv = vec2(1.0 - uv.y, uv.x);
	} else if (face_id == 4) {
		uv = vec2(1.0 - uv.x, uv.y);
	} else if (face_id == 5) {
		uv = vec2(uv.x, 1.0 - uv.y);
	}

	vec3 col = cream.rgb;
	col = mix(col, red.rgb, rect_mask(uv, vec2(0.0, 0.66), vec2(0.33, 1.0)));
	col = mix(col, blue.rgb, rect_mask(uv, vec2(0.33, 0.0), vec2(1.0, 0.33)));
	col = mix(col, yellow.rgb, rect_mask(uv, vec2(0.66, 0.33), vec2(0.83, 0.66)));
	col = mix(col, ink.rgb, rect_mask(uv, vec2(0.0, 0.33), vec2(0.16, 0.50)));

	// 墙面退到 65% 饱和度：保留 Mondrian 构图，但让物块和玩家先读出来。
	col = mix(cream.rgb, col, 0.65);

	// 粗黑分隔线，落在 1/3 与 2/3 的 1 米格点上。
	float div = 0.0;
	div = max(div, band(uv.x, 0.3333, 0.010));
	div = max(div, band(uv.x, 0.6667, 0.010));
	div = max(div, band(uv.x, 0.8333, 0.008));
	div = max(div, band(uv.y, 0.3333, 0.010));
	div = max(div, band(uv.y, 0.6667, 0.010));
	col = mix(col, ink.rgb, div);

	// 1 米细格线，保证贴墙走位可读。
	float grid = grid_line(uv, grid_count, 0.0055);
	col = mix(col, ink.rgb, grid * 0.30);

	// 墙脚一条更深的踢脚线，给“室内”一点重量。
	float baseboard = 1.0 - smoothstep(0.006, 0.014, uv.y);
	col = mix(col, ink.rgb, baseboard * 0.55);

	ALBEDO = col;
	ROUGHNESS = 0.86;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
