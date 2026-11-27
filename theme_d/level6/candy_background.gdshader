shader_type spatial;
render_mode unshaded, cull_disabled;

// 糖果罐背景：奶油/草莓渐变、波点糖纸、两侧棒棒糖、糖粒。
uniform vec4 cream : source_color = vec4(1.0, 0.94, 0.85, 1.0);
uniform vec4 peach : source_color = vec4(1.0, 0.78, 0.72, 1.0);
uniform vec4 mint : source_color = vec4(0.76, 0.95, 0.88, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.62, 0.72, 1.0);
uniform vec4 blue : source_color = vec4(0.64, 0.82, 1.0, 1.0);
uniform vec4 yellow : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform vec4 white : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	float aspect = 1.71;
	vec3 col = mix(cream.rgb, peach.rgb, smoothstep(0.0, 0.65, 1.0 - uv.y));
	col = mix(col, mint.rgb, smoothstep(0.55, 1.0, uv.y) * 0.30);

	// 底部糖果罐玻璃边。
	col = mix(col, white.rgb, smoothstep(0.08, 0.0, uv.y) * 0.45);

	// 大波点。
	vec2 dots = uv * vec2(8.0, 5.0);
	vec2 dc = floor(dots);
	vec2 df = fract(dots) - vec2(0.5);
	if (hash12(dc) > 0.52) {
		float d = smoothstep(0.34, 0.29, length(df));
		col = mix(col, white.rgb, d * 0.30);
	}

	// 两侧棒棒糖：圆盘 + 螺旋。
	for (int i = 0; i < 2; i++) {
		vec2 center = i == 0 ? vec2(0.10, 0.38) : vec2(0.90, 0.62);
		vec2 q = (uv - center) * vec2(aspect, 1.0);
		float r = length(q);
		float radius = 0.13;
		if (r < radius) {
			float a = atan(q.y, q.x);
			float spiral = sin(a * 5.0 + r * 70.0);
			vec3 candy_col = i == 0 ? pink.rgb : blue.rgb;
			col = mix(candy_col, white.rgb, smoothstep(0.15, 0.55, spiral) * 0.65);
			col = mix(col, white.rgb, smoothstep(radius, radius - 0.012, r) * 0.8);
		}
		// 棒子
		vec2 stick_q = uv - (center + vec2(0.0, -0.21));
		if (abs(stick_q.x) < 0.012 && stick_q.y > -0.16 && stick_q.y < 0.0) {
			col = white.rgb * 0.96;
		}
	}

	// 顶部糖纸斜条纹。
	float stripes = sin((uv.x * 0.8 + uv.y) * 6.2831 * 3.0);
	if (uv.y > 0.88) {
		col = mix(col, pink.rgb, smoothstep(0.55, 1.0, stripes) * 0.45);
		col = mix(col, white.rgb, 0.25);
	}

	// 散落糖粒。
	vec2 cell = floor(uv * vec2(14.0, 8.0));
	vec2 f = fract(uv * vec2(14.0, 8.0));
	float h = hash12(cell);
	if (h > 0.73) {
		vec2 sp = vec2(hash12(cell + 1.3), hash12(cell + 4.7));
		vec2 rel = f - sp;
		vec2 dir = normalize(vec2(0.7, 0.7));
		float along = dot(rel, dir);
		float across = abs(dot(rel, vec2(-dir.y, dir.x)));
		if (abs(along) < 0.12 && across < 0.03) {
			col = h > 0.9 ? yellow.rgb : (h > 0.82 ? pink.rgb : blue.rgb);
		}
	}

	// 柔和暗角。
	float vig = smoothstep(0.0, 0.35, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	col *= mix(0.90, 1.0, vig);

	ALBEDO = col;
}
