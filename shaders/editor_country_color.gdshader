shader_type canvas_item;
render_mode unshaded;
uniform int nation_id = -1;
uniform vec4 nation_color : source_color = vec4(1.0);
void fragment() {
	vec3 packed = floor(texture(TEXTURE, UV).rgb * 255.0 + 0.5);
	int owner = int(packed.r) + 256 * int(packed.g) + 65536 * int(packed.b);
	COLOR = owner == nation_id ? vec4(nation_color.rgb, 1.0) : vec4(0.0);
}
