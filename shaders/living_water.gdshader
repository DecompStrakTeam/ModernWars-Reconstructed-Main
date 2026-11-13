shader_type canvas_item;
render_mode unshaded;
#include "living_water.gdshaderinc"

uniform bool night_mode = false;
varying vec4 primitive_modulation;
void vertex() {
	primitive_modulation = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(living_water_color(source.rgb, UV, TIME, night_mode), source.a) * primitive_modulation;
}
