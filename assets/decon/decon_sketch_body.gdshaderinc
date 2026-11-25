uniform float shade : hint_range(0.0, 1.0) = 0.55;
uniform vec3 face_axis = vec3(0.0, 1.0, 0.0);
uniform vec3 side_axis = vec3(1.0, 0.0, 0.0);
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float transmit : hint_range(0.0, 1.0) = 0.0;
uniform float roundness : hint_range(0.0, 1.0) = 0.45;
uniform float sharpness : hint_range(0.0, 1.0) = 0.85;
uniform float grain : hint_range(0.0, 1.0) = 0.55;
uniform float face_contrast : hint_range(0.0, 1.0) = 1.0;
uniform float hue : hint_range(-1.0, 1.0) = -0.45;
uniform float light_yaw : hint_range(-1.0, 1.0) = 0.16;
uniform float light_pitch : hint_range(-1.0, 1.0) = 0.21;
uniform float light_strength : hint_range(0.0, 1.0) = 0.7;
uniform float light_fill : hint_range(0.0, 1.0) = 0.32;
uniform float light_hue : hint_range(-1.0, 1.0) = 0.6;

varying vec3 world_normal;
varying vec3 world_face;
varying vec3 world_side;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 shade_at(vec2 uv) {
	vec3 n = normalize(world_normal);
	float onto = clamp(dot(n, normalize(world_face)), 0.0, 1.0);
	float along = clamp(abs(dot(n, normalize(world_side))), 0.0, 1.0);
	float other = clamp(1.0 - onto - along, 0.0, 1.0);
	float amount = clamp(face_contrast, 0.0, 1.0);
	float bright = mix(0.7, 1.0, amount);
	float mid = mix(0.7, 0.48, amount);
	float dark = mix(0.7, 0.14, amount);
	float lift = onto * bright + along * mid + other * dark;
	float sweep = smoothstep(0.0, 1.0, uv.x * 0.35 + uv.y * 0.65);
	vec3 body = mix(vec3(0.1), vec3(0.96), lift);
	body = mix(body * 0.9, body, 0.82 + sweep * 0.1 + shade * 0.04);
	return body;
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_face = normalize((MODEL_MATRIX * vec4(face_axis, 0.0)).xyz);
	world_side = normalize((MODEL_MATRIX * vec4(side_axis, 0.0)).xyz);
}

void fragment() {
	vec3 body = shade_at(UV);
	float spread = blur * 0.14;
	if (spread > 0.0001) {
		body += shade_at(UV + vec2(spread, 0.0));
		body += shade_at(UV + vec2(-spread, 0.0));
		body += shade_at(UV + vec2(0.0, spread));
		body += shade_at(UV + vec2(0.0, -spread));
		body /= 5.0;
	}
	float grit = hash(FRAGCOORD.xy);
	float fine = hash(FRAGCOORD.xy * 0.45 + vec2(4.0, 9.0));
	body += (grit * 0.65 + fine * 0.35 - 0.5) * grain * 0.1;
	float edge = max(abs(UV.x - 0.5), abs(UV.y - 0.5));
	float softness = (1.0 - clamp(sharpness, 0.0, 1.0)) * 0.36 + blur * 0.24;
	float edge_amt = smoothstep(max(0.5 - softness, 0.0), 0.5, edge);
	body = mix(body, body * 0.6, edge_amt * (1.0 - clamp(roundness, 0.0, 1.0)));
	float tint = hue * 0.11;
	body.r += tint;
	body.b -= tint * 0.65;
	float yaw = light_yaw * 3.14159265;
	float pitch = light_pitch * 1.57079635;
	vec3 sun = normalize(vec3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)));
	float lit = smoothstep(-0.15, 0.95, dot(normalize(world_normal), sun));
	float strength = clamp(light_strength, 0.0, 1.0);
	body *= mix(1.0, mix(clamp(light_fill, 0.0, 1.0), 1.45, lit), strength);
	float sun_tint = clamp(light_hue, -1.0, 1.0) * strength;
	body.r += sun_tint * (0.1 * lit - 0.045 * (1.0 - lit));
	body.b += sun_tint * (-0.065 * lit + 0.07 * (1.0 - lit));
	float face_ndl = dot(normalize(world_normal), sun);
	float through = pow(clamp(-face_ndl, 0.0, 1.0), 1.5);
	float scatter = pow(1.0 - abs(face_ndl), 2.0);
	float pass = clamp(transmit, 0.0, 1.0) * strength;
	vec3 glow = vec3(0.9);
	float hue_amt = clamp(light_hue, -1.0, 1.0);
	glow.r += hue_amt * 0.18;
	glow.b -= hue_amt * 0.1;
	body += glow * (through * 0.62 + scatter * 0.22) * pass;
	ALBEDO = clamp(body, vec3(0.0), vec3(1.0));
}
