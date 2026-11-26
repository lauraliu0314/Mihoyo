shader_type sky;
uniform vec4 zenith_color : source_color = vec4(0.012, 0.009, 0.025, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.13, 0.075, 0.20, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.21, 0.135, 0.29, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float cloud_noise(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise2(p) * amplitude;
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(13.7, 7.9);
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec2 uv = SCREEN_UV;
	float t = TIME * 0.003;
	// Low-frequency layers deliberately look soft rather than grainy or sharp.
	float fog = cloud_noise(uv * vec2(3.5, 2.4) + vec2(t, -t * 0.3));
	float veil = cloud_noise(uv * vec2(5.0, 3.0) + vec2(-t * 0.65, 8.0));
	vec3 midnight = vec3(0.003, 0.004, 0.012);
	vec3 blue = vec3(0.018, 0.029, 0.065);
	vec3 violet = vec3(0.041, 0.018, 0.062);
	vec3 base = mix(blue, violet, smoothstep(0.15, 0.85, uv.x + veil * 0.16));
	base = mix(midnight, base, 0.4 + fog * 0.65);
	float mist_band = exp(-pow((uv.y - 0.55 + sin(uv.x * 4.0) * 0.05) * 4.0, 2.0));
	base += vec3(0.013, 0.021, 0.033) * mist_band * smoothstep(0.25, 0.75, fog);
	// Diffuse moonlight behind haze, with no hard white disc.
	vec2 moon_delta = (uv - vec2(0.32, 0.16)) * vec2(1.55, 1.0);
	float moon = exp(-dot(moon_delta, moon_delta) * 45.0);
	base += vec3(0.029, 0.038, 0.062) * moon * (0.7 + veil * 0.3);
	// Indistinct distant trunks and canopy frame the scene at the edges.
	float forest = 0.0;
	for (int i = 0; i < 9; i++) {
		float f = float(i);
		float x = hash21(vec2(f, 12.0));
		float bend = sin(uv.y * 3.0 + f) * 0.025;
		float width = 0.007 + hash21(vec2(f, 31.0)) * 0.014;
		float trunk = 1.0 - smoothstep(width, width + 0.018, abs(uv.x - x - bend));
		float edge_weight = smoothstep(0.1, 0.43, abs(x - 0.5));
		forest = max(forest, trunk * edge_weight * smoothstep(0.05, 0.4, uv.y));
	}
	float canopy = smoothstep(0.4, 0.72, veil) * (1.0 - smoothstep(0.0, 0.3, uv.y));
	base *= 1.0 - forest * 0.3 - canopy * 0.25;
	// Dim, slowly breathing starlight. Large-scale fog moves much slower than fireflies.
	vec2 grid = uv * vec2(135.0, 90.0);
	vec2 cell = floor(grid);
	vec2 point = vec2(hash21(cell + 8.1), hash21(cell + 29.4)) * 0.6 + 0.2;
	float star = exp(-dot(fract(grid)-point, fract(grid)-point) * 190.0) * step(0.997, hash21(cell));
	star *= 0.55 + 0.15 * sin(TIME * 0.22 + hash21(cell) * 60.0);
	base += vec3(0.07, 0.08, 0.12) * star * (1.0 - fog * 0.6);
	float edge = smoothstep(0.2, 0.7, length((uv-0.5)*vec2(1.0, 1.15)));
	COLOR = base * (1.0 - edge * 0.58);
}
