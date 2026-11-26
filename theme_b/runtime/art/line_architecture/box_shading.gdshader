shader_type spatial;
render_mode unshaded;
uniform sampler2D base_texture : source_color, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
varying vec3 local_normal;
void vertex(){ local_normal = NORMAL; }
void fragment(){
	vec4 tex = texture(base_texture, UV) * base_color;
	float shade = 0.30 + 0.56 * max(dot(normalize(local_normal), normalize(vec3(-0.4, 0.85, 0.3))), 0.0);
	ALBEDO = tex.rgb * shade;
}
