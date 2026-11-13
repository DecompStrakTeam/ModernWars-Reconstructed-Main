shader_type canvas_item;
render_mode unshaded;

// Only the already-committed scenario raster and sparse front mask are read.
uniform sampler2D country_ids : filter_nearest, repeat_disable;
uniform sampler2D front_mask : filter_nearest, repeat_disable;
uniform sampler2D past_territory : filter_nearest, repeat_disable;
uniform bool past_mode = false;
uniform bool sovereign_clip = true;
uniform bool mercator_view = false;
uniform float world_width = 1.0;
uniform vec2 sovereign_probe_uv = vec2(0.0001);
uniform vec4 line_color : source_color = vec4(0.0,0.0,0.0,0.18);
varying vec2 geographic_uv;
varying vec2 mask_uv;
varying vec2 stroke_point;
varying float segment_length;

vec3 owner_at(vec2 uv) {
	return floor(texture(country_ids,vec2(fract(uv.x),clamp(uv.y,0.0,1.0))).rgb*255.0+0.5);
}
void vertex() {
	vec4 encoded=floor(COLOR*255.0+0.5);
	segment_length=dot(encoded.rgb,vec3(1.0,256.0,65536.0))*2.0/16777215.0*world_width;
	// One-screen-pixel round capsule. Overlapping endpoint caps close bends
	// and bin seams without extending geographic boundaries or changing LOD.
	float extent=1.0;
	stroke_point=vec2(encoded.a<2.5 ? -extent : segment_length+extent,(encoded.a<1.5 || encoded.a>3.5 ? 1.0 : -1.0)*extent);
	VERTEX+=UV*(extent/max(world_width,1.0));
	geographic_uv=VERTEX*vec2(1.0,2.0);
	if (mercator_view) geographic_uv.y=0.5-atan(sinh(3.141592653589793*(1.0-2.0*VERTEX.y)))/3.141592653589793;
	mask_uv=mercator_view ? VERTEX : geographic_uv;
}
void fragment() {
	vec2 uv=vec2(fract(geographic_uv.x),geographic_uv.y);
	vec2 sovereign_uv=vec2(fract(mask_uv.x),mask_uv.y);
	vec3 owner=owner_at(sovereign_uv);
	float code=dot(owner,vec3(1.0,256.0,65536.0));
	// Probe half a SCREEN pixel, not half an ownership texel. At deep zoom a
	// half-texel inset cut real internal borders dozens of pixels short of the
	// country's stepped border. C++ supplies the unchanged projection's UV step.
	vec2 step_uv=sovereign_probe_uv;
	bool interior=code>0.0 && code<16777215.0 && uv.y>=0.0 && uv.y<=1.0;
	bool same_sovereign=all(equal(owner,owner_at(sovereign_uv+vec2(step_uv.x,0.0))))
		&& all(equal(owner,owner_at(sovereign_uv-vec2(step_uv.x,0.0))))
		&& all(equal(owner,owner_at(sovereign_uv+vec2(0.0,step_uv.y))))
		&& all(equal(owner,owner_at(sovereign_uv-vec2(0.0,step_uv.y))));
	interior = sovereign_clip ? interior && same_sovereign : uv.y>=0.0 && uv.y<=1.0;
	// A two-pixel quad has a one-pixel coverage integral. Analytic edge AA is
	// independent of zoom and avoids per-segment CanvasItem CPU expansion.
	float distance_to_line=length(vec2(stroke_point.x-clamp(stroke_point.x,0.0,segment_length),stroke_point.y));
	float coverage=1.0-smoothstep(0.0,1.0,distance_to_line);
	COLOR=vec4(line_color.rgb,line_color.a*coverage);
	COLOR.a *= interior && texture(front_mask,uv).r<0.5 ? 1.0 : 0.0;
	if (past_mode) COLOR.a *= texture(past_territory,uv).a>0.0 ? 1.0 : 0.0;
}
