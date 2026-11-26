shader_type spatial;
render_mode unshaded;
uniform vec3 block_size = vec3(1.0);
uniform vec2 gray_range = vec2(0.12, 0.55);
uniform bool forest_palette = true;
uniform vec4 forest_dark : source_color = vec4(0.02, 0.08, 0.06, 1.0);
uniform vec4 forest_mid : source_color = vec4(0.063, 0.275, 0.196, 1.0);
uniform vec4 forest_teal : source_color = vec4(0.153, 0.463, 0.365, 1.0);
uniform float flow_strength = 0.0;
uniform bool burn_enabled = false;
uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;
uniform float layer_detail = 0.0;
uniform vec4 warm_color : source_color = vec4(1.0, 0.77, 0.38, 1.0);
uniform float surface_glow : hint_range(0.0, 1.0) = 0.38;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	vec3 p = local_position / max(block_size, vec3(0.001)) + vec3(0.5);
	// Broad diagonal gradient remains attached to the rotating structure.
	float ramp = smoothstep(0.12, 0.9, dot(p, vec3(0.23, 0.55, 0.22)));
	float detail = sin(p.x*13.0+p.y*7.0)*cos(p.z*11.0-p.y*5.0);
	ramp = clamp(ramp + detail * layer_detail, 0.0, 1.0);
	ALBEDO = vec3(mix(gray_range.x, gray_range.y, ramp));
	if (forest_palette) {
		vec3 lower = mix(forest_dark.rgb, forest_mid.rgb, smoothstep(0.0, 0.55, ramp));
		ALBEDO = mix(lower, forest_teal.rgb, smoothstep(0.45, 1.0, ramp));
	}
	// Constant warm coating: no pulse, sweep, point light or distance falloff.
	EMISSION = warm_color.rgb * surface_glow;
	float wave = pow(0.5 + 0.5 * sin(dot(p, vec3(1.0, 1.4, 0.7)) * 9.0 - TIME * 1.2), 10.0);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.8, 0.38), wave * flow_strength * 0.65);
	EMISSION += warm_color.rgb * wave * flow_strength;
	if (burn_enabled) {
		float fuel = 1.0 - burn_progress;
		float tongues = pow(0.5 + 0.5 * sin(p.y * 22.0 - TIME * 4.5 + sin(p.x * 19.0 + p.z * 13.0) * 3.0), 5.0);
		ALBEDO = mix(ALBEDO, vec3(0.035), smoothstep(0.0, 0.95, burn_progress));
		EMISSION = mix(vec3(1.0, 0.14, 0.015), vec3(1.0, 0.65, 0.1), tongues) * tongues * fuel * 0.95;
	}
}
