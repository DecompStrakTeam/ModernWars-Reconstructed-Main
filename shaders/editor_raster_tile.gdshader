shader_type canvas_item;
render_mode unshaded;
uniform sampler2D owner_mask : filter_nearest, repeat_disable;
uniform vec2 tile_size = vec2(32.0);
uniform vec2 halo_size = vec2(34.0);
uniform bool show_borders = true;
uniform bool tile_mercator = false;
uniform vec2 projected_y = vec2(0.0, 1.0);
uniform vec2 latitude_span = vec2(90.0, 1.0);
void fragment() {
	vec2 source_uv = UV;
	if (tile_mercator) {
		float y = mix(projected_y.x, projected_y.y, UV.y);
		float latitude = degrees(2.0 * atan(exp(3.141592653589793 * (1.0 - 2.0 * y))) - 1.570796326794897);
		source_uv.y = clamp((latitude_span.x - latitude) / max(latitude_span.y, 0.00001), 0.0, 1.0);
	}
	vec4 base = texture(TEXTURE, source_uv);
	vec2 at = (source_uv * tile_size + vec2(1.0)) / halo_size;
	vec2 step_uv = fwidth(source_uv) * tile_size / halo_size * 0.5;
	vec3 owner = texture(owner_mask, at).rgb;
	bool edge = any(notEqual(owner, texture(owner_mask, at + vec2(step_uv.x, 0.0)).rgb))
		|| any(notEqual(owner, texture(owner_mask, at - vec2(step_uv.x, 0.0)).rgb))
		|| any(notEqual(owner, texture(owner_mask, at + vec2(0.0, step_uv.y)).rgb))
		|| any(notEqual(owner, texture(owner_mask, at - vec2(0.0, step_uv.y)).rgb));
	COLOR = show_borders && edge && base.a > 0.0 ? vec4(vec3(0.8), base.a) : base;
}
