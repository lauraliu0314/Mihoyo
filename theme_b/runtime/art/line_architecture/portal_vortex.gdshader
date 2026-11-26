shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment(){
	vec2 p = (UV-0.5)*2.0;
	float r = length(p);
	float a = atan(p.y,p.x);
	float spiral = pow(0.5+0.5*sin(a*4.0-r*18.0+TIME*1.8), 7.0);
	float rim = exp(-pow((max(abs(p.x), abs(p.y))-0.98)*48.0,2.0));
	float rings = pow(0.5+0.5*sin(r*45.0-TIME*2.5),12.0)*0.15;
	float mask = 1.0-smoothstep(0.82,0.98,r);
	vec3 c = mix(vec3(0.29,0.06,0.7),vec3(0.15,0.85,1.0),0.5+0.5*sin(a+TIME*0.4));
	ALBEDO = vec3(0.005,0.003,0.018);
	EMISSION = c*(spiral*0.65+rings)*mask*smoothstep(0.08,0.35,r)+vec3(0.45,0.8,1.0)*rim;
}
