extends Control



var descriptor: Dictionary = {}
var mode: = "fill"
var epoch: = -1
var view_key: Array = []
var redraw_count: = 0
var sampled: = 0
var occupied_cells: = PackedInt32Array()
var occupied_valid: = false
var _fill_source: Variant

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(item: Dictionary, next_mode: String, next_epoch: int, key: Array, fill_source: Variant = null) -> void :
	visible = true
	_fill_source = fill_source
	if descriptor.get("rows") == item.rows and descriptor.get("region") == item.region and mode == next_mode and epoch == next_epoch and view_key == key: return
	occupied_valid = false
	descriptor = item
	mode = next_mode
	epoch = next_epoch
	view_key = key.duplicate()
	queue_redraw()

func _draw() -> void :
	var layer: = get_parent()
	var map_view: CampaignMapView = layer.get_parent()
	var runtime: = map_view.war_runtime
	if runtime == null or not runtime.has_active_war() or descriptor.is_empty(): return
	var started: = Time.get_ticks_usec()
	var region: Dictionary = descriptor.region
	var cache: Dictionary = descriptor.cache
	var step: int = descriptor.step
	var rows: Vector2i = descriptor.rows
	if mode == "front":
		sampled = map_view._draw_war_frontline_region(region, cache, step, runtime, self, rows, descriptor.quads)
	elif mode == "border" and is_instance_valid(_fill_source) and _fill_source.occupied_valid and \
	_fill_source.epoch == epoch and _fill_source.view_key == view_key and \
	_fill_source.descriptor.get("rows") == rows and _fill_source.descriptor.get("region") == region:


		sampled = 0
		map_view._draw_war_changed_borders_region(region, cache, _fill_source.occupied_cells, maxi(step, 2 if map_view.zoom_level < 5.0 else 1), runtime, self)
	else:
		var result: = map_view._draw_war_occupation_region(region, cache, step, runtime, self, rows, mode == "fill")
		sampled = int(result.sampled)
		if mode == "fill":
			occupied_cells = result.occupied_cells
			occupied_valid = true
		else: map_view._draw_war_changed_borders_region(region, cache, result.occupied_cells, maxi(step, 2 if map_view.zoom_level < 5.0 else 1), runtime, self)
	redraw_count += 1
	runtime.record_render_profile(&"frontline_redraw" if mode == "front" else &"occupation_redraw", Time.get_ticks_usec() - started, true)
	if mode != "front":
		runtime.record_render_profile(&"occupation_fill_redraw" if mode == "fill" else &"occupation_border_redraw", Time.get_ticks_usec() - started, true)
	layer.refresh_statistics()
