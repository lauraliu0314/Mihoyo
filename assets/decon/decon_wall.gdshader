shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float cells : hint_range(1.0, 24.0) = 6.0;
uniform float blur : hint_range(0.0, 1.0) = 0.0;
uniform float sharpness : hint_range(0.0, 1.0) = 0.85;
uniform float grain : hint_range(0.0, 1.0) = 0.55;
uniform float wall_brightness : hint_range(0.0, 1.0) = 0.8;
uniform float seam_width : hint_range(0.0, 0.2) = 0.012;
uniform float seam_keep : hint_range(0.0, 1.0) = 0.78;
uniform float hue : hint_range(-1.0, 1.0) = 0.45;
uniform float light_yaw : hint_range(-1.0, 1.0) = 0.16;
uniform float light_pitch : hint_range(-1.0, 1.0) = 0.21;
uniform float light_strength : hint_range(0.0, 1.0) = 0.7;
uniform float light_fill : hint_range(0.0, 1.0) = 0.32;
uniform float light_hue : hint_range(-1.0, 1.0) = 0.6;
uniform vec3 room_center = vec3(0.0, 3.0, 0.0);

varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 cell_color(vec2 uv) {
	vec2 cell = fract(uv * cells);
	vec2 from_center = abs(cell - vec2(0.5));
	float edge = max(from_center.x, from_center.y);
	float pane = 0.5 - seam_width;
	float soft = mix(0.2, 0.02, clamp(sharpness, 0.0, 1.0));
	float seam = smoothstep(pane - soft, pane + soft, edge);
	float sweep = smoothstep(0.05, 0.95, cell.y * 0.7 + cell.x * 0.3);
	vec3 body = vec3(clamp(wall_brightness, 0.0, 1.0));
	body = mix(body * 0.92, body, 0.72 + sweep * 0.2);
	float core = smoothstep(pane, 0.14, edge);
	body = mix(body, min(body + vec3(0.06), vec3(0.94)), core * 0.3);
	return mix(body, body * seam_keep, seam);
}

void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (dot(n, room_center - world_pos) < 0.0) {
		n = -n;
	}
	world_normal = n;
}

void fragment() {
	vec3 color = cell_color(UV);
	float spread = blur * 0.02;
	if (spread > 0.0001) {
		color += cell_color(UV + vec2(spread, 0.0));
		color += cell_color(UV + vec2(-spread, 0.0));
		color += cell_color(UV + vec2(0.0, spread));
		color += cell_color(UV + vec2(0.0, -spread));
		color /= 5.0;
	}
	float grit = hash(FRAGCOORD.xy);
	float fine = hash(FRAGCOORD.xy * 0.45 + vec2(8.0, 3.0));
	color += (grit * 0.65 + fine * 0.35 - 0.5) * grain * 0.127;
	float warm = hue * 0.11;
	color.r += warm;
	color.b -= warm * 0.65;
	float yaw = light_yaw * 3.14159265;
	float pitch = light_pitch * 1.57079635;
	vec3 sun = normalize(vec3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)));
	float lit = smoothstep(-0.15, 0.95, dot(normalize(world_normal), sun));
	float strength = clamp(light_strength, 0.0, 1.0);
	color *= mix(1.0, mix(clamp(light_fill, 0.0, 1.0), 1.45, lit), strength);
	float tint = clamp(light_hue, -1.0, 1.0) * strength;
	color.r += tint * (0.1 * lit - 0.045 * (1.0 - lit));
	color.b += tint * (-0.065 * lit + 0.07 * (1.0 - lit));
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
}
