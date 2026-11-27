shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

// 一整块高饱和半透明软糖：颜色、内部深浅、边缘玻璃感都由物体空间决定。
// 保留旧参数名，调用方不用改 set_shader_parameter 的代码。
uniform vec4 base_color : source_color = vec4(0.98, 0.98, 0.97, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.0, 0.41, 1.0);
uniform vec4 ink : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform float pattern_seed = 0.0;
uniform float roughness = 0.12;
uniform float glow = 0.0;
uniform float socket = 0.0;
uniform float gummy_alpha = 0.82;
uniform float gummy_softness = 0.012;
uniform float rim_strength = 0.55;
uniform float saturation = 0.82;
uniform float color_value = 0.94;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	vec3 p = v_local;
	float seed = pattern_seed;

	// 主体就是 accent 色，不做白砖；先按角色压一点饱和度/亮度，
	// 保留色相，但不要霓虹感。
	vec3 c = accent_color.rgb;
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(luma), c, clamp(saturation, 0.0, 1.5)) * color_value;
	c = mix(c * 0.78, c * 1.06, smoothstep(-0.42, 0.46, p.y));

	// 内部三团柔和的色块，让每个角度看到的深浅不一样。
	float n = sin(p.x * 6.3 + seed) * sin(p.y * 5.1 + seed * 1.7) * sin(p.z * 7.4 + seed * 2.3);
	c = mix(c, c * 0.70, smoothstep(0.05, 0.90, -n) * 0.30);
	c = mix(c, mix(c, vec3(1.0), 0.50), smoothstep(0.15, 0.90, n) * 0.20);

	// 靠上表面的高光糖霜。
	float top = smoothstep(-0.05, 0.55, p.y);
	c = mix(c, mix(c, vec3(1.0), 0.65), top * 0.18);

	// 边缘更亮、更透明，形成软糖的玻璃壳。
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	c = mix(c, mix(c, vec3(1.0), 0.55), fres * 0.34);

	// socket 留作“目标点”强调，平时为 0。
	float socket_mask = 0.0;
	if (socket > 0.5) {
		float ring = abs(length(p.xz) - 0.135);
		socket_mask = smoothstep(0.030, 0.0, ring);
		c = mix(c, mix(accent_color.rgb, vec3(1.0), 0.45), socket_mask * 0.8);
	}

	ALBEDO = c;
	ALPHA = clamp(gummy_alpha + fres * 0.16 + socket_mask * 0.10, 0.0, 1.0);
	ROUGHNESS = clamp(roughness + (1.0 - fres) * 0.04, 0.03, 0.5);
	METALLIC = 0.0;
	SPECULAR = 0.72;
	RIM = rim_strength;
	RIM_TINT = 0.88;
	EMISSION = c * glow * (0.35 + 0.45 * top + 0.2 * socket_mask);
}
