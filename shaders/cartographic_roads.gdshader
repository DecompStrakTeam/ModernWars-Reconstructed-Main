shader_type canvas_item;
render_mode unshaded;
uniform sampler2D country_ids : filter_nearest, repeat_disable;
uniform bool mercator_view=false;
uniform float world_width=4096.0;
uniform float stroke_width=1.2;
uniform vec4 line_color=vec4(0.86,0.83,0.68,1.0);
uniform float edge_width=0.35;
uniform bool outline_pass=false;
uniform float primary_detail=0.0;
uniform float primary_width=0.9;
uniform bool river_pass=false;
uniform bool clip_to_owner=true;
// False preserves the installed legacy binary's three river categories.
uniform bool ranked_rivers=false;
varying vec2 mask_uv;
varying vec2 stroke_point;
varying float segment_length;
varying float display_alpha;
varying float display_width;
varying float lake_connector;
void vertex() {
	// Native UV stores cap/normal extrusion. COLOR encodes length in RGB24
	// and the corner tag in alpha (not presentation tint).
	// The capsule's signed-distance coordinates are in screen pixels. Both
	// its readable core and very narrow dark edge keep their size while zooming.
	vec4 code=floor(COLOR*255.0+0.5);
	float category=floor(code.a/16.0);
	bool primary=!river_pass && category>=1.0;
	lake_connector=river_pass && category==(ranked_rivers ? 11.0 : 3.0) ? 1.0 : 0.0;
	float corner=mod(code.a,16.0);
	display_alpha=primary ? primary_detail : 1.0;
	display_width=primary ? primary_width : stroke_width;
	if (river_pass && ranked_rivers) { display_width=category<=2.0 ? 2.4 : category<=5.0 ? 1.6 : category<=8.0 ? 1.1 : category<=10.0 ? 0.8 : 1.1; }
	else if (river_pass) { display_width*=category==1.0 ? 1.8 : category==2.0 ? 1.35 : category==3.0 ? 1.2 : 1.0; }
	float extent=0.5*display_width+edge_width+0.5;
	segment_length=dot(code.rgb,vec3(1.0,256.0,65536.0))*2.0/16777215.0*world_width;
	stroke_point=vec2(corner<2.5 ? -extent : segment_length+extent,(corner<1.5 || corner>3.5 ? 1.0 : -1.0)*extent);
	VERTEX+=UV*(extent/max(world_width,1.0));
	mask_uv=mercator_view ? VERTEX : VERTEX*vec2(1.0,2.0);
}
void fragment() {
	if (display_alpha<=0.0) { discard; }
	vec3 owner=floor(texture(country_ids,vec2(fract(mask_uv.x),clamp(mask_uv.y,0.0,1.0))).rgb*255.0+0.5);
	float code=dot(owner,vec3(1.0,256.0,65536.0));
	float distance_to_line=length(vec2(stroke_point.x-clamp(stroke_point.x,0.0,segment_length),stroke_point.y));
	float radius=0.5*display_width;
	float core=1.0-smoothstep(max(0.0,radius-0.5),radius+0.5,distance_to_line);
	float edge=1.0-smoothstep(radius+edge_width-0.5,radius+edge_width+0.5,distance_to_line);
	// Separate cached passes keep another segment's dark edge from cutting
	// through an already-painted centre at bends and dense river vertices.
	COLOR=outline_pass ? vec4(0.025,0.04,0.055,edge*0.65) : vec4(line_color.rgb,core*line_color.a);
	if (river_pass && outline_pass) { COLOR=ranked_rivers ? vec4(vec3(44.0,82.0,130.0)/255.0,edge*0.40) : vec4(line_color.rgb,edge*0.20); }
	COLOR.a*=(!clip_to_owner || (code>0.0 && code<16777215.0) || lake_connector>0.5) && mask_uv.y>=0.0 && mask_uv.y<=1.0 ? 1.0 : 0.0;
	COLOR.a*=display_alpha;
}
