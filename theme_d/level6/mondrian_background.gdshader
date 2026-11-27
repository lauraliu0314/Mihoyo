shader_type spatial;
render_mode unshaded, cull_disabled;

// 奶油画廊：低对比风格派墙面 + 两幅小画 + 齐腰踢脚线。
// 背景只做衬托，色块压到 10%～14%，不再出现横跨房间的巨型黑框。
uniform vec4 cream : source_color = vec4(0.94, 0.92, 0.86, 1.0);
uniform vec4 red : source_color = vec4(0.80, 0.16, 0.16, 1.0);
uniform vec4 blue : source_color = vec4(0.12, 0.32, 0.54, 1.0);
uniform vec4 yellow : source_color = vec4(0.94, 0.72, 0.04, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.05, 1.0);

float rect_mask(vec2 uv, vec2 lo, vec2 hi) {
	vec2 a = smoothstep(lo - 0.003, lo + 0.003, uv);
	vec2 b = 1.0 - smoothstep(hi - 0.003, hi + 0.003, uv);
	return a.x * a.y * b.x * b.y;
}

float band(float v, float at, float w) {
	return 1.0 - smoothstep(w, w + 0.004, abs(v - at));
}

vec3 draw_small_painting(vec3 col, vec2 uv, vec2 lo, vec2 hi, vec4 accent) {
	float outer = rect_mask(uv, lo, hi);
	float inner = rect_mask(uv, lo + vec2(0.004), hi - vec2(0.004));
	col = mix(col, ink.rgb, clamp(outer - inner, 0.0, 1.0) * 0.85);
	col = mix(col, vec3(0.975, 0.965, 0.93), inner);

	vec2 a_lo = lo + vec2(0.012, 0.012);
	vec2 a_hi = vec2(hi.x - 0.012, lo.y + (hi.y - lo.y) * 0.42);
	float field = rect_mask(uv, a_lo, a_hi) * inner;
	col = mix(col, accent.rgb, field * 0.85);
	return col;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(cream.rgb, cream.rgb * 0.93, smoothstep(0.0, 1.0, uv.y));

	// 墙面大色块：只留极低对比度的色温变化。
	col = mix(col, red.rgb, rect_mask(uv, vec2(0.0, 0.48), vec2(0.18, 1.0)) * 0.10);
	col = mix(col, blue.rgb, rect_mask(uv, vec2(0.18, 0.0), vec2(0.42, 0.16)) * 0.12);
	col = mix(col, yellow.rgb, rect_mask(uv, vec2(0.62, 0.20), vec2(0.72, 0.32)) * 0.14);

	// 细黑挂画线。
	float rails = clamp(
		band(uv.x, 0.18, 0.0015) + band(uv.x, 0.42, 0.0015) + band(uv.y, 0.16, 0.0015),
		0.0, 1.0
	);
	col = mix(col, ink.rgb, rails * 0.22);

	// 画廊墙脚。
	float base = 1.0 - smoothstep(0.004, 0.010, abs(uv.y - 0.185));
	col = mix(col, ink.rgb, base * 0.55);
	col = mix(col, vec3(0.86, 0.83, 0.77), smoothstep(0.185, 0.0, uv.y) * 0.45);

	// 两幅小尺幅画作，避免整面墙被一张画占满。
	col = draw_small_painting(col, uv, vec2(0.07, 0.52), vec2(0.20, 0.70), red);
	col = draw_small_painting(col, uv, vec2(0.78, 0.58), vec2(0.91, 0.76), blue);

	// 挂画横杆。
	float picture_rail = 1.0 - smoothstep(0.002, 0.006, abs(uv.y - 0.74));
	col = mix(col, ink.rgb, picture_rail * 0.25);

	// 顶部聚光灯的柔光，给展厅一点纵深。
	float spot = smoothstep(0.55, 0.0, abs(uv.x - 0.5)) * smoothstep(0.30, 0.85, uv.y);
	col += vec3(0.030, 0.028, 0.022) * spot;

	ALBEDO = col;
}
