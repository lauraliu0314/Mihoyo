shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 paper_color : source_color = vec4(0.83, 0.825, 0.805, 1.0);
uniform vec4 rule_color : source_color = vec4(0.38, 0.38, 0.37, 1.0);
uniform float rule_strength : hint_range(0.0, 0.2, 0.005) = 0.065;
uniform float rule_width : hint_range(0.001, 0.01, 0.001) = 0.002;

float segment(vec2 uv, float coordinate, float start, float end, bool vertical) {
	float line = vertical ? abs(uv.x - coordinate) : abs(uv.y - coordinate);
	float span = vertical ? uv.y : uv.x;
	return (1.0 - smoothstep(rule_width, rule_width * 1.8, line))
		* step(start, span) * step(span, end);
}

void fragment() {
	vec2 uv = UV;
	float rules = 0.0;
	rules = max(rules, segment(uv, 0.14, 0.02, 0.54, true));
	rules = max(rules, segment(uv, 0.86, 0.42, 0.98, true));
	rules = max(rules, segment(uv, 0.26, 0.0, 0.30, false));
	rules = max(rules, segment(uv, 0.73, 0.70, 1.0, false));
	ALBEDO = mix(paper_color.rgb, rule_color.rgb, rules * rule_strength);
}
