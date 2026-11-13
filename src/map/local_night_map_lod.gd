extends RefCounted


static func tiles_for_view(level: Dictionary, origin: Vector2, width: float, view_size: Vector2, core: int, allow_partial: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var side: = int(level["tiles_per_side"])
	var span: = width / side
	var top: = maxi(0, int(floor( - origin.y / span)))
	var bottom: = mini(side - 1, int(ceil((view_size.y - origin.y) / span)) - 1)
	var left: = int(floor( - origin.x / span))
	var right: = int(ceil((view_size.x - origin.x) / span)) - 1
	for row: int in range(top, bottom + 1):
		for unwrapped_column: int in range(left, right + 1):
			var column: = posmod(unwrapped_column, side)
			var slot: = "%d:%d" % [column, row]
			if not level["tiles"].has(slot):
				if allow_partial:
					continue
				return []
			result.append({"key": level["tiles"][slot], "column": column, "row": row, "pixels": int(level["pixels"]), "rect": Rect2(origin + Vector2(unwrapped_column * span, row * span), Vector2.ONE * span), "core": core})
	return result


static func select(manifest: Dictionary, origin: Vector2, width: float, view_size: Vector2, budget_bytes: int) -> Dictionary:
	var best: = {}
	var core: = int(manifest["tile_size"])
	var tile_bytes: = texture_bytes(core + 2 * int(manifest["gutter"]))
	for level: Dictionary in manifest["levels"]:
		var pixels: = int(level["pixels"])
		if pixels < 4096 or not level.get("runtime", true):
			continue
		if pixels > 4096 and pixels > width * 2.0:
			continue
		var visible_tiles: = tiles_for_view(level, origin, width, view_size, core)
		if visible_tiles.is_empty():
			continue
		var unique_keys: = {}
		for tile: Dictionary in visible_tiles:
			unique_keys[tile["key"]] = true
		if unique_keys.size() * tile_bytes > budget_bytes:
			continue
		best = {"pixels": pixels, "level": level, "tiles": visible_tiles, "bytes": unique_keys.size() * tile_bytes, "screen_pixels_per_texel": width / pixels}
	return best


static func level_for(manifest: Dictionary, pixels: int) -> Dictionary:
	for level: Dictionary in manifest["levels"]:
		if int(level["pixels"]) == pixels and pixels >= 4096:
			return level
	return {}


static func stable_selection(manifest: Dictionary, origin: Vector2, width: float, view_size: Vector2, budget: int, displayed: int) -> Dictionary:
	var chosen: = select(manifest, origin, width, view_size, budget)
	if chosen.is_empty():
		return chosen
	var current: = level_for(manifest, displayed)
	if current.is_empty():
		return chosen
	var tiles: = tiles_for_view(current, origin, width, view_size, int(manifest["tile_size"]))
	var keys: = {}
	for tile: Dictionary in tiles:
		keys[tile["key"]] = true
	var cost: = keys.size() * texture_bytes(int(manifest["tile_size"]) + 2 * int(manifest["gutter"]))
	if tiles.is_empty() or cost > budget:
		return chosen
	var next_pixels: = int(chosen["pixels"])
	var threshold: = pow(2.0, 0.12)
	if (next_pixels > displayed and width * 2.0 < next_pixels * threshold) or (next_pixels < displayed and width * 2.0 >= displayed / threshold):
		return {"pixels": displayed, "level": current, "tiles": tiles, "bytes": cost, "screen_pixels_per_texel": width / displayed}
	return chosen


static func texture_bytes(side: int) -> int:

	var total: = 0
	while side > 0:
		total += side * side * 4
		side = int(side / 2.0)
	return total


static func base_texture_bytes(side: int) -> int:

	var total: = 0
	while side > 0:
		total += int(ceil(side / 4.0)) * int(ceil(side / 4.0)) * 16
		side = int(side / 2.0)
	return total


static func practical_zoom(manifest: Dictionary, longitude: float, latitude: float, requested: float, view_size: Vector2, budget_bytes: int) -> float:
	var candidate: = minf(requested, float(manifest["maximum_practical_zoom"]))
	for iteration: int in range(80):
		var width: = 512.0 * pow(2.0, candidate)
		var center: = MWWebMercator.project(longitude, latitude)
		var origin: = view_size * 0.5 - center * width
		var selected: = select(manifest, origin, width, view_size, budget_bytes)
		var north: = MWWebMercator.unproject(Vector2(0.5, clampf(center.y - view_size.y * 0.5 / width, 0, 1))).y
		var south: = MWWebMercator.unproject(Vector2(0.5, clampf(center.y + view_size.y * 0.5 / width, 0, 1))).y
		var poleward: = maxf(absf(north), absf(south))
		var native_scale: = width / (float(manifest["native_high_width"]) * cos(deg_to_rad(poleward)))
		if not selected.is_empty() and float(selected["screen_pixels_per_texel"]) <= 2.0 and native_scale <= 2.0:
			return candidate
		candidate -= 0.05
	return maxf(candidate, 2.0)
