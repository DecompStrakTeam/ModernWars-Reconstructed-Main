class_name LocalNaturalEarthTerrain
extends Control


const ASSET_ROOT: = "res://assets/maps/night_map/"
const MANIFEST_PATH: = ASSET_ROOT + "manifest.json"
const CACHE_BUDGET_BYTES: = 192 * 1024 * 1024
const PENDING_LIMIT: = 2
const FADE_DURATION: = 0.15
const BASE_PIXELS: = 4096
var pack_digest: = ""
var _manifest: Dictionary = {}
var _cache: Dictionary = {}
var _costs: Dictionary = {}
var _pending: Dictionary = {}
var _last_used: Dictionary = {}
var _wanted: Dictionary = {}
var _base_keys: Dictionary = {}
var _visible_tiles: Array[Dictionary] = []
var _display_tiles: Array[Dictionary] = []
var _from_tiles: Array[Dictionary] = []
var _requests: Array[String] = []
var _origin: = Vector2.ZERO
var _world_width: = 0.0
var _view_size: = Vector2.ZERO
var _serial: = 0
var _selected_pixels: = BASE_PIXELS
var _displayed_pixels: = BASE_PIXELS
var _from_pixels: = BASE_PIXELS
var _tile_bytes: = 0
var _base_bytes: = 0
var _base_tile_bytes: = 0
var _last_pan: = Vector2.ZERO
var _fade_elapsed: = FADE_DURATION
var _transition_count: = 0

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert (_manifest.get("visual_only", false) and _manifest.get("projection") == "EPSG:3857")
	pack_digest = _manifest["pack_sha256"]
	_tile_bytes = MWLocalNightMapLOD.texture_bytes(int(_manifest["tile_size"]) + 2 * int(_manifest["gutter"]))
	_base_tile_bytes = MWLocalNightMapLOD.base_texture_bytes(int(_manifest["tile_size"]) + 2 * int(_manifest["gutter"]))
	for key: String in MWLocalNightMapLOD.level_for(_manifest, BASE_PIXELS)["tiles"].values():
		_base_keys[key] = true
	_base_bytes = _base_keys.size() * _base_tile_bytes
	_update_view()

func _process(delta: float) -> void :
	_update_view()
	if DisplayServer.get_name() != "headless":
		_consume_texture()
	_try_transition()
	if _fade_elapsed < FADE_DURATION:
		_fade_elapsed = minf(FADE_DURATION, _fade_elapsed + delta)
		queue_redraw()
		if _fade_elapsed >= FADE_DURATION:
			_from_pixels = _displayed_pixels
			_from_tiles.clear()
			_choose_target()
	if DisplayServer.get_name() != "headless":
		_request_textures()

func _consume_texture() -> void :
	for key: String in _pending.keys():
		var status: = ResourceLoader.load_threaded_get_status(ASSET_ROOT + key)
		if status == ResourceLoader.THREAD_LOAD_LOADED:

			var tile: = ResourceLoader.load_threaded_get(ASSET_ROOT + key) as Texture2D
			_pending.erase(key)
			if tile != null:
				if _base_keys.has(key):
					var format: = RenderingServer.texture_get_format(tile.get_rid())
					assert (format in [Image.FORMAT_BPTC_RGBA, Image.FORMAT_DXT1, Image.FORMAT_DXT3, Image.FORMAT_DXT5], "Resident base requires imported desktop GPU block compression")
				_cache[key] = tile
				_costs[key] = _key_cost(key)
				_last_used[key] = _serial
				queue_redraw()
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending.erase(key)
			push_error("Local night tile failed: " + key)

func _request_textures() -> void :
	for key: String in _requests:
		if _pending.size() >= PENDING_LIMIT:
			break
		if _cache.has(key) or _pending.has(key):
			continue
		if not _reserve(_key_cost(key)):
			break
		if ResourceLoader.load_threaded_request(ASSET_ROOT + key, "Texture2D", false, ResourceLoader.CACHE_MODE_IGNORE) == OK:
			_pending[key] = true

func _tiles(pixels: int, partial: bool = false) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	tiles.assign(MWLocalNightMapLOD.tiles_for_view(MWLocalNightMapLOD.level_for(_manifest, pixels), _origin, _world_width, size, int(_manifest["tile_size"]), partial))
	return tiles

func _update_view() -> void :
	var map_view: = get_parent() as Control
	if map_view == null or not map_view.has_method("_world_origin") or _manifest.is_empty():
		return
	var origin: Vector2 = map_view.call("_world_origin")
	var width: float = map_view.call("_world_width")
	if origin == _origin and width == _world_width and size == _view_size:
		return
	_last_pan = origin - _origin if is_equal_approx(width, _world_width) else Vector2.ZERO
	_origin = origin
	_world_width = width
	_view_size = size
	_serial += 1
	_display_tiles = _tiles(_displayed_pixels, true)
	_from_tiles.clear()
	if _fade_elapsed < FADE_DURATION:
		_from_tiles = _tiles(_from_pixels, true)
	if _fade_elapsed >= FADE_DURATION:
		_choose_target()
	else:
		_visible_tiles = _tiles(_selected_pixels)
		_rebuild_requests()
	queue_redraw()

func _choose_target() -> void :
	var selected: = MWLocalNightMapLOD.stable_selection(_manifest, _origin, _world_width, size, CACHE_BUDGET_BYTES - _base_bytes, _displayed_pixels)
	_selected_pixels = int(selected.get("pixels", BASE_PIXELS))
	_visible_tiles = _tiles(_selected_pixels)
	var union: = _base_keys.duplicate()
	for tile: Dictionary in _display_tiles:
		if _cache.has(tile["key"]) or _pending.has(tile["key"]):
			union[tile["key"]] = true
	for tile: Dictionary in _visible_tiles:
		union[tile["key"]] = true
	if _keys_cost(union) > CACHE_BUDGET_BYTES:


		_selected_pixels = BASE_PIXELS
		_visible_tiles = _tiles(BASE_PIXELS)
	_rebuild_requests()

func _rebuild_requests() -> void :
	_wanted = _base_keys.duplicate()
	_requests.clear()
	for key: String in _base_keys:
		_requests.append(key)
	for tiles: Array in [_visible_tiles]:
		for tile: Dictionary in tiles:
			var key: String = tile["key"]
			_wanted[key] = true
			_last_used[key] = _serial
			if not _requests.has(key):
				_requests.append(key)
	for tile: Dictionary in _display_tiles + _from_tiles:

		if _cache.has(tile["key"]) or _pending.has(tile["key"]):
			_wanted[tile["key"]] = true
	if _last_pan.length_squared() > 1.0:
		var level: = MWLocalNightMapLOD.level_for(_manifest, _selected_pixels)
		for tile: Dictionary in MWLocalNightMapLOD.tiles_for_view(level, _origin + _last_pan.limit_length(160), _world_width, size, int(_manifest["tile_size"])):
			var key: String = tile["key"]
			if not _requests.has(key) and _keys_cost(_wanted) + _tile_bytes <= CACHE_BUDGET_BYTES:
				_requests.append(key)
				_wanted[key] = true

func _ready_tiles(tiles: Array[Dictionary]) -> bool:
	if tiles.is_empty():
		return false
	for tile: Dictionary in tiles:
		if not _cache.has(tile["key"]):
			return false
	return true

func _base_ready() -> bool:
	for key: String in _base_keys:
		if not _cache.has(key):
			return false
	return not _base_keys.is_empty()

func _try_transition() -> void :
	if _fade_elapsed < FADE_DURATION or _selected_pixels == _displayed_pixels or not _base_ready() or not _ready_tiles(_visible_tiles):
		return
	_from_pixels = _displayed_pixels
	_from_tiles = _display_tiles.duplicate()
	_displayed_pixels = _selected_pixels
	_display_tiles = _visible_tiles.duplicate()
	_fade_elapsed = 0.0
	_transition_count += 1
	_rebuild_requests()

func _resident_bytes() -> int:
	var total: = _keys_cost(_pending)
	for cost: int in _costs.values():
		total += cost
	return total

func _key_cost(key: String) -> int:
	return _base_tile_bytes if _base_keys.has(key) else _tile_bytes

func _keys_cost(keys: Dictionary) -> int:
	var total: = 0
	for key: String in keys:
		total += _key_cost(key)
	return total

func _reserve(bytes: int) -> bool:
	while _resident_bytes() + bytes > CACHE_BUDGET_BYTES:
		var oldest: = ""
		var age: = 2147483647
		for key: String in _cache:
			if not _wanted.has(key) and int(_last_used.get(key, 0)) < age:
				oldest = key
				age = int(_last_used.get(key, 0))
		if oldest.is_empty():
			return false
		_cache.erase(oldest)
		_costs.erase(oldest)
		_last_used.erase(oldest)
	return true

func _draw_tiles(tiles: Array[Dictionary], opacity: float) -> void :
	if opacity <= 0:
		return
	var core: = Rect2(Vector2.ONE * int(_manifest["gutter"]), Vector2.ONE * int(_manifest["tile_size"]))
	for tile: Dictionary in tiles:
		var tile_texture: Texture2D = _cache.get(tile["key"])
		if tile_texture != null:
			draw_texture_rect_region(tile_texture, tile["rect"], core, Color(1, 1, 1, opacity))

func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("#040a12"))
	if _manifest.is_empty() or _world_width <= 0:
		return
	_draw_tiles(_tiles(BASE_PIXELS), 1.0)
	var blend: = clampf(_fade_elapsed / FADE_DURATION, 0, 1)
	if _from_pixels > BASE_PIXELS and blend < 1:
		_draw_tiles(_from_tiles, 1.0 - blend if _displayed_pixels == BASE_PIXELS else 1.0)
	if _displayed_pixels > BASE_PIXELS:
		_draw_tiles(_display_tiles, blend)


func practical_zoom(longitude: float, latitude: float, requested: float, view_size: Vector2) -> float:
	if _manifest.is_empty():
		return minf(requested, 7.5)
	return MWLocalNightMapLOD.practical_zoom(_manifest, longitude, latitude, requested, view_size, CACHE_BUDGET_BYTES - _base_bytes)

func cache_stats() -> Dictionary:
	var missing: = 0
	for tile: Dictionary in _visible_tiles:
		if not _cache.has(tile["key"]):
			missing += 1
	return {"cached": _cache.size(), "pending": _pending.size(), "visible": _visible_tiles.size(), "missing": missing, "settled": _base_ready() and missing == 0 and _fade_elapsed >= FADE_DURATION and _displayed_pixels == _selected_pixels, "lod_pixels": _selected_pixels, "displayed_pixels": _displayed_pixels, "base_pixels": BASE_PIXELS, "base_ready": _base_ready(), "base_bytes": _base_bytes, "fade": _fade_elapsed / FADE_DURATION, "transition_count": _transition_count, "screen_pixels_per_texel": _world_width / maxf(1, _selected_pixels), "resident_bytes": _resident_bytes(), "budget_bytes": CACHE_BUDGET_BYTES, "overview_in_close_view": false, "pack_sha256": pack_digest}

func _exit_tree() -> void :
	for key: String in _pending:
		ResourceLoader.load_threaded_get(ASSET_ROOT + key)
	_pending.clear()
	_cache.clear()
