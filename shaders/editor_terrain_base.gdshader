shader_type canvas_item;
render_mode unshaded;
uniform bool mercator = false;
void fragment() {
	vec2 uv = UV;
	if (mercator) uv.y = (90.0 - degrees(atan(sinh(3.14159265359 * (1.0 - 2.0 * UV.y))))) / 180.0;
	int kind = int(floor(texture(TEXTURE, uv).r * 255.0 + 0.5));
	vec3 mountain = mod(floor(uv.x * 3600.0) + floor(uv.y * 1800.0), 4.0) < 2.0 ? vec3(0.384,0.420,0.447) : vec3(0.627,0.659,0.667);
	COLOR = kind == 1 ? vec4(0.824,0.718,0.490,0.65) : kind == 2 ? vec4(mountain,0.65) : kind == 4 ? vec4(0.459,0.506,0.420,1.0) : vec4(0.0);
}
