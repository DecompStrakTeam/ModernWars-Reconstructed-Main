shader_type canvas_item;
render_mode unshaded;

// HOI4-style matte political cartography with crisp sovereign fills.
varying vec4 primitive_modulation;
void vertex() {
	primitive_modulation = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a < 0.02) {
		discard;
	}
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 matte = mix(source.rgb, vec3(luminance), 0.06);
	COLOR = vec4(matte, source.a) * primitive_modulation;
}
