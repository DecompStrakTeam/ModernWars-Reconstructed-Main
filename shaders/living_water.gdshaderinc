// Visual-only procedural water with HOI4-style naval cartography.
// Coordinates are geographic world UV, not province/control state.
vec3 living_water_color(vec3 base, vec2 world_uv, float time, bool night) {
	// Integer longitude harmonics keep all wrapped copies and the dateline phase-continuous
	float longitude_phase = world_uv.x * 6.28318530718;
	float wave = sin(longitude_phase * 49.0 + world_uv.y * 189.0 + time * 0.18)
		* sin(world_uv.y * 234.0 - longitude_phase * 23.0 - time * 0.13);
	float bathy=dot(base,vec3(0.299,0.587,0.114));
	vec3 deep_navy=night?vec3(0.024,0.047,0.086):vec3(0.039,0.075,0.133);
	vec3 shelf_navy=night?vec3(0.047,0.090,0.157):vec3(0.071,0.133,0.220);
	vec3 result=mix(deep_navy,shelf_navy,clamp(bathy*1.15,0.0,1.0));
	float glint=pow(max(0.0,wave),8.0)*(night?0.008:0.016);
	result+=vec3(0.002,0.004,0.006)*wave+vec3(glint*0.65,glint*0.82,glint);
	// Crisp antialiased 15-degree and 30-degree geographic graticule coordinate lines
	vec2 grid = world_uv * vec2(24.0, 12.0);
	vec2 distance_to_line = min(fract(grid), 1.0 - fract(grid));
	vec2 width = max(fwidth(grid), vec2(0.00015));
	vec2 lines = 1.0 - smoothstep(width * 0.20, width * 0.80, distance_to_line);
	float graticule = max(lines.x, lines.y);
	return result + vec3(0.16, 0.22, 0.30) * graticule * (night ? 0.06 : 0.09);
}
