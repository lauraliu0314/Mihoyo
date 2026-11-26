shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float spin_speed : hint_range(-4.0, 4.0, 0.01) = 0.12;
uniform float pull_speed : hint_range(0.0, 2.0, 0.01) = 0.04;
uniform float vortex_speed : hint_range(-4.0, 4.0, 0.01) = 1.15;
uniform float star_glow : hint_range(0.0, 4.0, 0.01) = 1.15;
// Same values as the wall: decon_style.tres wall_blur, and the wall grid of 6 cells.
uniform float blur : hint_range(0.0, 1.0) = 0.2;
uniform float wall_cells : hint_range(1.0, 24.0) = 6.0;
uniform float grain : hint_range(0.0, 1.0) = 0.13;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float star_layer(float radius, float angle, float scale, float pull, float spin, float seed) {
	float radial = fract(radius * 2.4 - TIME * pull + seed);
	float theta = angle + TIME * spin - log(radius + 0.025) * 1.6;
	vec2 cell = vec2(theta * scale, radial * scale * 1.35);
	vec2 id = floor(cell);
	vec2 local = fract(cell) - vec2(0.5);
	float n = hash21(id + vec2(seed, seed * 3.1));
	float present = step(0.8, n);
	vec2 jitter = vec2(
		hash21(id + vec2(19.1, seed)),
		hash21(id + vec2(seed, 47.2))
	) - vec2(0.5);
	float point = 1.0 - smoothstep(0.0, 0.07, length(local - jitter * 0.5));
	float falloff = smoothstep(0.03, 0.12, radius);
	return present * point * falloff;
}

vec4 portal_sample(vec2 uv) {
	vec2 p = uv - vec2(0.5);
	float radius = length(p);
	float angle = atan(p.y, p.x);

	float stars = star_layer(radius, angle, 7.0, pull_speed, spin_speed, 0.17);
	stars += star_layer(radius, angle, 11.0, pull_speed * 1.12, spin_speed * 1.12, 2.4);
	stars = clamp(stars, 0.0, 1.0);

	float vortex = sin(angle * 3.0 + TIME * vortex_speed + log(radius + 0.03) * 7.0);
	float arms = smoothstep(0.2, 0.92, vortex);
	arms *= smoothstep(0.04, 0.12, radius);

	vec3 color = vec3(0.22, 0.22, 0.23);
	color = mix(color, vec3(0.72, 0.74, 0.78), arms * 0.65);
	color = mix(color, vec3(1.0), stars);
	float glow = arms * 0.35 + stars * star_glow;
	return vec4(color, glow);
}

void fragment() {
	vec4 sample = portal_sample(UV);
	// Wall shader: spread = blur * 0.02 across the whole face.
	// This square is one cell, so scale by the wall's cell count.
	float spread = blur * 0.02 * wall_cells;
	if (spread > 0.0001) {
		sample += portal_sample(UV + vec2(spread, 0.0));
		sample += portal_sample(UV + vec2(-spread, 0.0));
		sample += portal_sample(UV + vec2(0.0, spread));
		sample += portal_sample(UV + vec2(0.0, -spread));
		sample /= 5.0;
	}
	float grit = hash21(FRAGCOORD.xy);
	float fine = hash21(FRAGCOORD.xy * 0.45 + vec2(8.0, 3.0));
	sample.rgb += (grit * 0.65 + fine * 0.35 - 0.5) * grain * 0.127;

	ALBEDO = clamp(sample.rgb, vec3(0.0), vec3(1.0));
	EMISSION = vec3(0.85) * sample.a;
	ALPHA = 1.0;
}
