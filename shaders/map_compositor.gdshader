shader_type canvas_item;
render_mode unshaded;
#include "living_water.gdshaderinc"

// Scenario sovereign IDs are a visual mask, not province administration.
uniform sampler2D country_ids : filter_nearest, repeat_disable;
uniform sampler2D city_lights : filter_linear_mipmap, repeat_disable;
uniform vec2 world_origin = vec2(0.0);
uniform float world_width = 4096.0;
uniform float zoom_level = 3.0;
uniform bool night_mode = true;
uniform bool wargames_mode = false;
uniform bool mercator_view = false;
varying vec2 map_position;
varying float linear_source_y;
varying vec4 primitive_modulation;

float source_y(float display_y) {
	return mercator_view ? 0.5 - atan(sinh(3.141592653589793 * (1.0 - 2.0 * display_y))) / 3.141592653589793 : display_y * 2.0;
}

vec3 country_code(vec2 uv) {
	return floor(texture(country_ids, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0))).rgb * 255.0 + 0.5);
}
void vertex() {
	map_position = VERTEX;
	linear_source_y = source_y((VERTEX.y - world_origin.y) / max(world_width, 1.0));
	primitive_modulation = COLOR;
}
void fragment() {
	vec2 display_uv = (map_position - world_origin) / max(world_width, 1.0);
	vec2 world_uv = vec2(display_uv.x, source_y(display_uv.y));
	vec2 atlas_uv = UV;
	if (mercator_view) {
		// Correct the quad's linear UV interpolation to the exact geographic
		// latitude. No source-image resampling or additional tile draw calls.
		// Equirectangular sources are 2:1: a full latitude UV spans half
		// the longitude texel count. Preserve that aspect inside the quad.
		float source_to_atlas_y = 0.5 * dFdx(UV.x) / max(dFdx(display_uv.x), 0.00000001);
		atlas_uv.y += (world_uv.y - linear_source_y) * source_to_atlas_y;
	}
	vec4 source = texture(TEXTURE, atlas_uv, -0.35);
	vec2 mask_uv = mercator_view ? display_uv : world_uv;
	float id = dot(country_code(mask_uv),vec3(1.0,256.0,65536.0));
	bool land = id > 0.0 && id < 16777215.0;
	vec3 terrain = source.rgb;
	if (wargames_mode) {
		terrain = land ? vec3(0.22,0.27,0.24) : vec3(0.078431,0.125490,0.172549);
	} else if (!land) {
		terrain = living_water_color(terrain, world_uv, TIME, night_mode);
		// A local categorical coastal sample darkens shallow edge water subtly.
		vec2 step_uv = 1.0 / vec2(textureSize(country_ids,0));
		float coast = 0.0;
		for (int a = 0; a < 4; a++) {
			vec2 offset=a==0?vec2(-1.0,0.0):a==1?vec2(1.0,0.0):a==2?vec2(0.0,-1.0):vec2(0.0,1.0);
			float n = dot(country_code(mask_uv + step_uv * offset),vec3(1.0,256.0,65536.0));
			coast += (n > 0.0 && n < 16777215.0) ? 0.25 : 0.0;
		}
		terrain *= 1.0 - coast*0.35;
	} else {
		if (night_mode) {
			// Mask derives from observed NASA2016 composite, never CityData dots.
			float observed = texture(city_lights, vec2(fract(world_uv.x), clamp(world_uv.y, 0.0, 1.0))).r;
			terrain += vec3(1.0, 0.68, 0.30) * observed * 0.025;
		}
	}
	COLOR = vec4(terrain, source.a) * primitive_modulation;
}
