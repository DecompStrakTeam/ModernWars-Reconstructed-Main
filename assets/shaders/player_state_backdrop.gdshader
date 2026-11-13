shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, 3.0).rgb;
	COLOR = vec4(scene * vec3(0.23, 0.24, 0.27), 1.0);
}
