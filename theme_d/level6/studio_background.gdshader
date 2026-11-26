shader_type spatial;
render_mode unshaded, cull_disabled;

// 中灰工作室远景：让白色立方体从背景里跳出来，保留一点彩色空气。
uniform vec4 base_color : source_color = vec4(0.54, 0.55, 0.58, 1.0);
uniform vec4 warm_color : source_color = vec4(0.62, 0.62, 0.63, 1.0);
uniform vec4 magenta : source_color = vec4(1.0, 0.0, 0.41, 1.0);
uniform vec4 cyan : source_color = vec4(0.13, 0.83, 0.93, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.83, 0.0, 1.0);
uniform vec4 blue : source_color = vec4(0.11, 0.31, 0.85, 1.0);

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(base_color.rgb, warm_color.rgb, smoothstep(0.0, 1.0, uv.y));

	// 失焦的大色团：只提供一点色彩空气，不抢主体。
	float b0 = smoothstep(0.42, 0.0, length((uv - vec2(0.16, 0.70)) * vec2(1.0, 1.35)));
	col = mix(col, magenta.rgb, b0 * 0.080);

	float b1 = smoothstep(0.38, 0.0, length((uv - vec2(0.78, 0.62)) * vec2(1.0, 1.25)));
	col = mix(col, cyan.rgb, b1 * 0.080);

	float b2 = smoothstep(0.34, 0.0, length((uv - vec2(0.55, 0.18)) * vec2(1.25, 1.0)));
	col = mix(col, yellow.rgb, b2 * 0.060);

	float b3 = smoothstep(0.46, 0.0, length((uv - vec2(0.92, 0.22)) * vec2(1.0, 1.4)));
	col = mix(col, blue.rgb, b3 * 0.075);

	// 轻微暗角，让房间中心更亮。
	float vig = smoothstep(0.95, 0.30, length(uv - vec2(0.5)));
	col *= 0.965 + 0.035 * vig;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
