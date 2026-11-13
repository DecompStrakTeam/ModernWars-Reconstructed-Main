shader_type canvas_item;
render_mode unshaded;

// The texture encodes only immutable/current source-grid country IDs. Five
// nearest samples produce a constant screen-width outline of that exact grid.
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float half_width_pixels = 0.5;

void fragment() {
	vec2 pixel_step = fwidth(UV) * half_width_pixels;
	vec3 owner = texture(TEXTURE, UV).rgb;
	vec3 east = texture(TEXTURE, vec2(fract(UV.x + pixel_step.x), UV.y)).rgb;
	vec3 west = texture(TEXTURE, vec2(fract(UV.x - pixel_step.x), UV.y)).rgb;
	vec3 south = texture(TEXTURE, vec2(UV.x, clamp(UV.y + pixel_step.y, 0.0, 1.0))).rgb;
	vec3 north = texture(TEXTURE, vec2(UV.x, clamp(UV.y - pixel_step.y, 0.0, 1.0))).rgb;
	bool edge = any(notEqual(owner, east)) || any(notEqual(owner, west))
		|| any(notEqual(owner, south)) || any(notEqual(owner, north));
	COLOR = vec4(border_color.rgb, border_color.a * float(edge));
}
