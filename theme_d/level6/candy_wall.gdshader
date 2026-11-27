shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// 糖果罐内壁：马卡龙玻璃 + 糖纸斜纹 + 糖粒/波点 + 1 米甜点格线。
uniform int face_id = 0;
uniform float grid_count = 6.0;
uniform vec4 mint : source_color = vec4(0.55, 0.90, 0.82, 1.0);
uniform vec4 cream : source_color = vec4(1.0, 0.90, 0.76, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.62, 0.74, 1.0);
uniform vec4 blue : source_color = vec4(0.62, 0.82, 1.0, 1.0);
uniform vec4 white : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cocoa : source_color = vec4(0.48, 0.28, 0.26, 1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec3 base = mix(mint.rgb, cream.rgb, smoothstep(0.0, 1.0, uv.y));
	base = mix(base, blue.rgb, smoothstep(0.55, 1.0, uv.x) * 0.22);

	// 糖纸斜纹。
	float stripe = sin((uv.x + uv.y) * 6.2831 * 1.5 + float(face_id) * 0.7);
	base = mix(base, pink.rgb, smoothstep(0.66, 1.0, stripe) * 0.30);

	// 玻璃罐高光。
	float glass = smoothstep(0.58, 0.98, 1.0 - abs(uv.x - 0.23));
	base += white.rgb * glass * 0.16;

	// 波点糖纸。
	vec2 dots = uv * vec2(9.0, 6.0);
	vec2 dot_cell = floor(dots);
	vec2 dot_f = fract(dots) - vec2(0.5);
	if (hash12(dot_cell + float(face_id) * 3.1) > 0.58) {
		float d = smoothstep(0.33, 0.28, length(dot_f));
		base = mix(base, white.rgb, d * 0.42);
	}

	// 糖粒：部分格子里的小斜条。
	vec2 cell_uv = UV * grid_count;
	vec2 cell = floor(cell_uv);
	vec2 f = fract(cell_uv);
	float h = hash12(cell + float(face_id) * 13.0);
	if (h > 0.80) {
		vec2 sp = vec2(hash12(cell + 1.3), hash12(cell + 4.7));
		vec2 dir = normalize(vec2(0.72, 0.7));
		vec2 rel = f - sp;
		float along = dot(rel, dir);
		float across = abs(dot(rel, vec2(-dir.y, dir.x)));
		if (abs(along) < 0.10 && across < 0.018) {
			if (h > 0.92) {
				base = pink.rgb;
			} else if (h > 0.86) {
				base = blue.rgb;
			} else {
				base = cream.rgb;
			}
		}
	}

	// 和玩法对齐的 1 米格线：淡巧克力色，既像糖果格又看得清。
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float line = 1.0 - smoothstep(0.012, 0.024, edge);
	base = mix(base, mix(pink.rgb, cocoa.rgb, 0.35), line * 0.50);

	// 罐口/罐底玻璃边。
	float rim = smoothstep(0.0, 0.06, min(uv.y, 1.0 - uv.y));
	base *= mix(0.86, 1.0, rim);

	ALBEDO = base;
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	RIM = 0.20;
	RIM_TINT = 0.80;
}
