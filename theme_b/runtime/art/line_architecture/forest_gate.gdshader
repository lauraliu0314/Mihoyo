shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float a = atan(p.y, p.x);
	float spiral = pow(0.5 + 0.5*sin(a*3.0 - r*22.0 + TIME*1.1), 18.0);
	float spiral2 = pow(0.5 + 0.5*sin(a*5.0 + r*16.0 - TIME*0.7), 28.0);
	float rim = exp(-pow((r-0.945)*85.0, 2.0));
	float ripples = pow(0.5+0.5*sin(r*65.0-TIME*1.4), 24.0);
	float fade = smoothstep(0.08,0.35,r)*(1.0-smoothstep(0.85,1.0,r));
	vec3 gold = vec3(1.0, 0.67, 0.20);
	vec3 jade = vec3(0.18, 0.55, 0.36);
	vec3 glow = (gold*spiral*0.55 + jade*spiral2*0.32 + gold*ripples*0.1)*fade + gold*rim*0.65;
	ALBEDO = mix(vec3(0.003,0.008,0.007),vec3(0.016,0.05,0.036),r) + glow;
	EMISSION = glow * 0.25;
}
