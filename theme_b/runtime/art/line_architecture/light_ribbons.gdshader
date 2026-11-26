shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(0.32, 0.7, 0.9, 1.0);
varying vec3 local_position;
varying float phase;
void vertex() {
	local_position = VERTEX;
	phase = dot(MODEL_MATRIX[3].xyz, vec3(0.73, 1.37, 0.41));
}
void fragment() {
	float band = pow(0.5 + 0.5 * sin(local_position.y * 7.0 - TIME * 1.25 + phase), 14.0);
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = tint.rgb * 0.32;
	METALLIC = 0.45;
	ROUGHNESS = 0.36;
	EMISSION = tint.rgb * (0.35 + band * 2.3 + edge * 0.6);
}
