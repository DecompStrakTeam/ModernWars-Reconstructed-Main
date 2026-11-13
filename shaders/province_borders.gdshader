shader_type canvas_item;
render_mode unshaded;
uniform sampler2D province_ids : filter_nearest, repeat_disable;
uniform sampler2D country_ids : filter_nearest, repeat_disable;
uniform vec2 world_origin = vec2(0.0);
uniform float world_width = 4096.0;
uniform float zoom_level = 3.0;
uniform bool night_mode = true;
varying vec2 map_position;
float province_code(vec2 uv) {
	vec3 rgb = floor(texture(province_ids, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0))).rgb * 255.0 + 0.5);
	return dot(rgb, vec3(65536.0, 256.0, 1.0));
}
vec3 country_code(vec2 uv) {
	return floor(texture(country_ids, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0))).rgb * 255.0 + 0.5);
}
void vertex() {
	map_position = VERTEX;
}
void fragment() {
	vec2 uv = (map_position - world_origin) / max(world_width, 1.0) * vec2(1.0, 2.0);
	float id = province_code(uv);
	float edge = 0.0;
	if (uv.y >= 0.0 && uv.y <= 1.0 && id > 0.0 && id < 100000.0) {
		vec2 screen_pixel = vec2(1.0, 2.0) / max(world_width, 1.0);
		vec3 owner = country_code(uv);
		for (int a = 0; a < 2; a++) {
			vec2 next_uv = uv + (a == 0 ? vec2(screen_pixel.x, 0.0) : vec2(0.0, screen_pixel.y));
			float next_id = province_code(next_uv);
			if (next_id > 0.0 && next_id < 100000.0 && next_id != id && all(equal(country_code(next_uv), owner))) edge = 1.0;
		}
	}
	float fade = smoothstep(3.8, 5.2, zoom_level);
	COLOR = vec4(night_mode ? vec3(0.65) : vec3(0.08), edge * fade * (night_mode ? 0.18 : 0.25));
}
