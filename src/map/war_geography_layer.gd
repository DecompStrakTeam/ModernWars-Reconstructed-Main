extends Control

var front: = false
var _key: Array = []
var _chunks: Array[Control] = []
var _view_key: Array = []
var _descriptors: Array[Dictionary] = []

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void :
	sync_view()

func sync_view() -> void :
	var map_view: = get_parent() as CampaignMapView
	var runtime: = map_view.war_runtime
	var camera: = map_view.sync_camera_revision()
	var active: = runtime != null and runtime.has_active_war() and runtime.grid_size == map_view.raster_size
	var key: = [camera, runtime, runtime.visual_revisions.control_revision if active else -1, runtime.state if runtime != null else -1, map_view.texture, runtime.native_front_trace_revision if active else -1]
	if key == _key: return
	if not MWNativeConflictController.render_sync_due(runtime, _key.size() != 6 or \
	key[0] != _key[0] or key[1] != _key[1] or key[3] != _key[3] or key[4] != _key[4]): return
	_key = key
	if not active or (front and runtime.state != ConflictRuntimeState.WarState.RUNNING):
		for chunk: Control in _chunks: chunk.hide()
		return
	if front and runtime.native_front_trace_revision >= 0:
		for chunk: Control in _chunks: chunk.hide()

		return
	var pass_data: = map_view._war_geography_view()
	var view_key: = [camera, runtime, runtime.visual_revisions.generation, map_view.texture]
	if view_key != _view_key:
		_view_key = view_key
		_descriptors = row_strips(pass_data)

	var quad_rows: Dictionary = {}
	if front:
		for cell: int in runtime.render_front_quads:
			var row: = int(cell / float(runtime.grid_size.x))
			if not quad_rows.has(row): quad_rows[row] = PackedInt32Array()
			quad_rows[row].append(cell)
	var used: = 0
	for item: Dictionary in pass_data.items:
		var fill_sources: Dictionary = {}
		for pass_mode: String in (["front"] if front else ["fill", "border"]):
			for descriptor_index: int in _descriptors.size():
				var descriptor: Dictionary = _descriptors[descriptor_index]
				if descriptor.region != item.region: continue
				var region: Dictionary = descriptor.region
				var rows: Vector2i = descriptor.rows
				var bounds: = Rect2i(region.x_start, rows.x, region.x_end - region.x_start, rows.y - rows.x)
				var epoch: = runtime.visual_revisions.region_epoch(bounds, front)
				var draw_descriptor: = descriptor
				if front:
					draw_descriptor = descriptor.duplicate()
					var quads: = PackedInt32Array()
					for row: int in range(rows.x, rows.y):
						if quad_rows.has(row): quads.append_array(quad_rows[row])
					draw_descriptor["quads"] = quads
				if used == _chunks.size():
					var chunk: = MWWarGeographyChunk.new()
					add_child(chunk)
					_chunks.append(chunk)
				var fill_source: Variant = fill_sources.get(descriptor_index) if pass_mode == "border" else null
				_chunks[used].configure(draw_descriptor, pass_mode, epoch, _view_key, fill_source)
				if pass_mode == "fill": fill_sources[descriptor_index] = _chunks[used]
				used += 1
	for i: int in range(used, _chunks.size()): _chunks[i].hide()
	map_view.war_render_stats["visible_regions"] = pass_data.items.size()
	map_view.war_render_stats["visible_grid_area"] = pass_data.area
	map_view.war_render_stats["render_step"] = pass_data.step
	map_view.war_render_stats["front_chunks" if front else "occupation_chunks"] = used

static func row_strips(pass_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var step: = int(pass_data.step)
	for item: Dictionary in pass_data.items:
		var region: Dictionary = item.region
		var first: = int(region.y_start)
		while first < int(region.y_end):

			var boundary: = (int(first / 16.0) + 1) * 16
			var end: = mini(int(region.y_end), first + maxi(1, ceili((boundary - first) / float(step))) * step)
			result.append({"region": region, "cache": item.cache, "rows": Vector2i(first, end), "step": step})
			first = end
	return result

func refresh_statistics() -> void :
	if front and get_parent().war_runtime != null and get_parent().war_runtime.native_front_trace_revision >= 0: return
	var total: = 0
	for chunk: Control in _chunks:
		if chunk.visible and chunk.mode != "border": total += chunk.sampled
	get_parent().war_render_stats["frontline_cells" if front else "sampled_cells"] = total
