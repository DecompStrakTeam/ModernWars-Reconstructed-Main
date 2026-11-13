class_name CampaignMapView
extends Control

signal country_clicked(country_id: int)
signal map_clicked(control_position: Vector2)

enum ViewMode{
	POLITICAL, 
	ALLIANCE, 
	FLAG, 
	ALLIANCE_FLAG, 
}

const INITIAL_CENTER: = Vector2(18.0, 37.0)
const INITIAL_ZOOM: = 3.0
const MIN_ZOOM: = 2.0
const MAX_ZOOM: = 7.5



const TILE_SIZE: = 512.0
const OCEAN_TOP: = Color("#0a2534")
const OCEAN_BOTTOM: = Color("#04101a")
const LOCAL_NIGHT_STYLE: StringName = &"local_nasa_night"
const POLITICAL_OVERLAY_ALPHA: = 0.45
const OCCUPATION_OVERLAY_ALPHA: = 0.85
const OCCUPATION_WHITE_BLEND: = 0.3
const SOURCE_LABEL_FONT_BASE: FontFile = preload("res://assets/fonts/playfair-display/PlayfairDisplay-wght.ttf")
const LABEL_REGION_BIN_COUNT: = 4
const LABEL_PATH_SAMPLES: = 10
const LABEL_CHAR_FACTOR: = 0.65
const LABEL_SPACING_FACTOR: = 0.35
const WAR_RENDER_PADDING: = 12.0
const WAR_HASH_CELL_SIZE: = 2.5

var texture: Texture2D
var owner_ids: PackedInt32Array = PackedInt32Array()
var raster_size: = Vector2i.ZERO
var country_names: Dictionary = {}
var cities: Array[CityData] = []
var labels_visible: = true
var cities_visible: = true
var battle_visuals_visible: = false

var units_visual_visible: = true

enum UnitViewMode{SINGLE, GROUPS}
var unit_view_mode: = UnitViewMode.SINGLE
var planning_visible: = false

var formation_debug_visible: = false

func set_planning_visible(enabled: bool) -> void :
	planning_visible = enabled
	queue_redraw()

func set_unit_view_mode(mode: UnitViewMode) -> void :
	unit_view_mode = mode
	queue_redraw()
var center_longitude: = INITIAL_CENTER.x
var center_latitude: = INITIAL_CENTER.y
var zoom_level: = INITIAL_ZOOM
var target_zoom_level: = INITIAL_ZOOM
const ZOOM_DURATION: = 0.15
var _zoom_start: = INITIAL_ZOOM
var _zoom_elapsed: = ZOOM_DURATION
var _zoom_cursor: = Vector2.ZERO
var _zoom_anchor: = Vector2.ZERO
var view_mode: = ViewMode.POLITICAL
var visual_style_id: StringName = LOCAL_NIGHT_STYLE
var war_runtime: ConflictRuntimeState = null
var war_render_stats: Dictionary = {}
var camera_revision: = 0
var annotation_revision: = 0
var _camera_revision_key: Array = []
var _dynamic_revision_key: Array = []
var _strength_layout_key: Array = []
var _strength_layout: Array[Dictionary] = []
var _planning_overlay: WarAnnotationLayer
var strength_layout_build_count: = 0

var _political_texture: Texture2D
var _static_border_texture: Texture2D
var terrain_layer: Control
var _alliance_texture: Texture2D
var _country_colors: Dictionary = {}

var _country_flag_asset_paths: Dictionary = {}
var _unit_flag_renderer: MWUnitFlagRenderer
var _alliance_root_by_country: Dictionary = {}
var _alliance_colors: Dictionary = {}
var _country_sample_indices: Dictionary = {}
var _country_bounds: Dictionary = {}
var _label_geo_by_country: Dictionary = {}
var _label_regions: Array[Dictionary] = []
var _country_label_font: Font
var _city_label_font: Font
var _strength_label_font: SystemFont
var _encirclement_popup_font: SystemFont
var _war_view_cache_key: Array = []
var _war_view_cache: Dictionary = {}
var _occupation_render_stats: Dictionary = {}
var _left_pressed: = false
var _left_drag_distance: = 0.0
var _middle_dragging: = false


func _ready() -> void :
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _unit_flag_renderer == null:
		_unit_flag_renderer = MWUnitFlagRenderer.new()
	terrain_layer = ClassDB.instantiate("MWModernMapSurface") if bool(get_meta("mw_visual_only_map", false)) or MWMapProjection.view_profile(self) == MWMapProjection.EQUIRECTANGULAR else LocalNaturalEarthTerrain.new()
	terrain_layer.name = "LocalNaturalEarthTerrain"
	add_child(terrain_layer)
	for is_border_pass: bool in [false, true]:
		if is_border_pass:
			var occupation_layer: = MWWarGeographyLayer.new()
			occupation_layer.name = "WarOccupationLayer"
			add_child(occupation_layer)
		var overlay: = SourceGridOverlay.new()
		overlay.borders = is_border_pass
		overlay.name = "SourceGridBorders" if is_border_pass else "SourceGridPolitical"
		add_child(overlay)
	var front_layer: = MWWarGeographyLayer.new()
	front_layer.name = "WarFrontlineLayer"
	front_layer.front = true
	add_child(front_layer)
	var trace_layer: = MWFrontTraceLayer.new()
	trace_layer.name = "NativeFrontTraceLayer"
	add_child(trace_layer)
	for kind: String in ["cities", "planning", "countries"]:
		var labels: = WarAnnotationLayer.new()
		labels.kind = kind
		labels.name = "WarAnnotations_" + kind
		add_child(labels)
		if kind == "planning":
			_planning_overlay = labels
	_country_label_font = _build_country_label_font()
	_city_label_font = _build_city_label_font()
	resized.connect(_on_resized)
	set_process(false)


func configure(
	map_texture: Texture2D, 
	map_owner_ids: PackedInt32Array, 
	map_raster_size: Vector2i, 
	scenario_countries: Array[CountryData], 
	scenario_cities: Array[CityData]
) -> void :
	MWMapGridViewport.configure(self, map_texture, map_owner_ids, map_raster_size, scenario_countries, scenario_cities)


func configure_reference(
	map_texture: Texture2D, 
	map_owner_ids: PackedInt32Array, 
	map_raster_size: Vector2i, 
	scenario_countries: Array[CountryData], 
	scenario_cities: Array[CityData]
) -> void :
	annotation_revision += 1
	owner_ids = map_owner_ids
	raster_size = map_raster_size
	country_names.clear()
	_country_colors.clear()
	for country: CountryData in scenario_countries:
		country_names[country.id] = country.country_name
		_country_colors[country.id] = country.color
	if _unit_flag_renderer == null:
		_unit_flag_renderer = MWUnitFlagRenderer.new()
	_unit_flag_renderer.configure_flags(scenario_countries)
	_unit_flag_renderer.set_unit_multimesh_enabled(true)
	_country_flag_asset_paths = _unit_flag_renderer.get_asset_paths()
	cities = scenario_cities
	_build_country_anchors()
	_build_alliance_components(scenario_countries)
	_political_texture = _project_source_texture(map_texture)
	_build_static_border_texture()
	_alliance_texture = null
	view_mode = ViewMode.POLITICAL
	texture = _political_texture
	_sync_source_overlay_mode()
	war_runtime = null
	reset_view()


func reset_view() -> void :
	set_camera(INITIAL_CENTER.x, INITIAL_CENTER.y, INITIAL_ZOOM)


func set_camera(longitude: float, latitude: float, zoom: float) -> void :
	var native_camera: = get_node_or_null("NativeCameraController") as MWCameraController
	if native_camera != null:
		native_camera.set_camera(longitude, latitude, zoom)
		return
	center_longitude = MWWebMercator.wrap_longitude(longitude)
	center_latitude = clampf(latitude, - MWMapProjection.max_latitude(self), MWMapProjection.max_latitude(self))
	zoom_level = clampf(zoom, _minimum_zoom(), MAX_ZOOM)
	if terrain_layer != null:
		zoom_level = maxf(_minimum_zoom(), float(terrain_layer.call("practical_zoom", center_longitude, center_latitude, zoom_level, size)))
	_constrain_vertical_center()
	target_zoom_level = zoom_level
	_zoom_elapsed = ZOOM_DURATION
	set_process(false)
	queue_redraw()


func set_labels_visible(enabled: bool) -> void :
	labels_visible = enabled
	queue_redraw()


func set_cities_visible(enabled: bool) -> void :
	cities_visible = enabled
	queue_redraw()


func set_battle_visuals_visible(enabled: bool) -> void :


	battle_visuals_visible = enabled
	queue_redraw()


func set_units_visual_visible(enabled: bool) -> void :
	units_visual_visible = enabled
	queue_redraw()


func set_war_runtime(runtime: ConflictRuntimeState) -> void :
	war_runtime = runtime
	queue_redraw()


func clear_war_runtime() -> void :
	war_runtime = null
	queue_redraw()


func fit_grid_bounds(bounds: Rect2i, padding_ratio: float = 0.2) -> void :
	if bounds.size.x <= 0 or bounds.size.y <= 0 or raster_size.x <= 0 or raster_size.y <= 0:
		return
	var west: = float(bounds.position.x) / float(raster_size.x) * 360.0 - 180.0
	var east: = float(bounds.end.x) / float(raster_size.x) * 360.0 - 180.0
	var north: = 90.0 - float(bounds.position.y) / float(raster_size.y) * 180.0
	var south: = 90.0 - float(bounds.end.y) / float(raster_size.y) * 180.0
	var projected_north: = MWMapProjection.project(self, 0.0, north).y
	var projected_south: = MWMapProjection.project(self, 0.0, south).y
	var projected_width: = maxf(0.0001, absf(east - west) / 360.0)
	var projected_height: = maxf(0.0001, absf(projected_south - projected_north))
	var padded_width: = projected_width * (1.0 + padding_ratio * 2.0)
	var padded_height: = projected_height * (1.0 + padding_ratio * 2.0)
	var available: = Vector2(maxf(320.0, size.x - 120.0), maxf(240.0, size.y - 150.0))
	var fitted_world_width: = minf(available.x / padded_width, available.y / padded_height)
	var fitted_zoom: = log(fitted_world_width / TILE_SIZE) / log(2.0)
	var center_projected_y: = (projected_north + projected_south) * 0.5
	var center_geo: = MWMapProjection.unproject(self, Vector2(0.5, center_projected_y))
	set_camera((west + east) * 0.5, center_geo.y, fitted_zoom)


func replace_world_owners(updated_owner_ids: PackedInt32Array) -> bool:
	return SourceGridOverlay.replace_world_owners_native(self, updated_owner_ids)




func _replace_world_owners_reference_for_verification(updated_owner_ids: PackedInt32Array) -> bool:
	if not OS.is_debug_build():
		return false
	if updated_owner_ids.size() != owner_ids.size() or raster_size.x <= 0 or raster_size.y <= 0:
		return false
	annotation_revision += 1
	owner_ids = updated_owner_ids.duplicate()
	var source_image: = Image.create(raster_size.x, raster_size.y, false, Image.FORMAT_RGBA8)
	for y: int in range(raster_size.y):
		for x: int in range(raster_size.x):
			var owner_id: = owner_ids[y * raster_size.x + x]
			var color: Color = _country_colors.get(owner_id, Color.TRANSPARENT)
			if owner_id > 0:
				color.a = 1.0
			source_image.set_pixel(x, y, color)
	_political_texture = ImageTexture.create_from_image(_project_source_image(source_image))
	_build_static_border_texture()
	_alliance_texture = null
	texture = _political_texture
	view_mode = ViewMode.POLITICAL
	_sync_source_overlay_mode()
	_build_country_anchors()
	queue_redraw()
	return true


func set_visual_style(style_id: StringName) -> bool:

	if style_id != LOCAL_NIGHT_STYLE:
		return false
	visual_style_id = style_id
	queue_redraw()
	return true


func supports_alliance_view() -> bool:
	return not _alliance_root_by_country.is_empty()


func set_view_mode(mode: ViewMode) -> bool:
	if mode != ViewMode.POLITICAL and mode != ViewMode.ALLIANCE and mode != ViewMode.FLAG and mode != ViewMode.ALLIANCE_FLAG:
		return false
	if mode == ViewMode.ALLIANCE or mode == ViewMode.ALLIANCE_FLAG:
		if not supports_alliance_view():
			return false
		if _alliance_texture == null:
			_alliance_texture = _build_alliance_texture()
		if _alliance_texture == null:
			return false
		texture = _alliance_texture
	else:
		texture = _political_texture
	view_mode = mode
	_sync_source_overlay_mode()
	queue_redraw()
	return true


func _sync_source_overlay_mode() -> void :
	var overlay: = get_node_or_null("SourceGridPolitical") as SourceGridOverlay
	if overlay != null:
		overlay.set_render_mode(1 if view_mode == ViewMode.FLAG or view_mode == ViewMode.ALLIANCE_FLAG else 0)


func country_id_at(control_position: Vector2) -> int:
	return country_id_at_geographic(control_to_geographic(control_position))


func country_id_at_geographic(geographic: Vector2) -> int:
	if raster_size.x <= 0 or raster_size.y <= 0 or owner_ids.is_empty():
		return 0
	if geographic.y < -90.0 or geographic.y > 90.0:
		return 0
	var longitude: = MWWebMercator.wrap_longitude(geographic.x)
	var normalized_x: = (longitude + 180.0) / 360.0
	var normalized_y: = (90.0 - geographic.y) / 180.0
	var pixel_x: = clampi(int(floor(normalized_x * raster_size.x)), 0, raster_size.x - 1)
	var pixel_y: = clampi(int(floor(normalized_y * raster_size.y)), 0, raster_size.y - 1)
	var index: = pixel_y * raster_size.x + pixel_x
	if war_runtime != null and war_runtime.has_active_war():
		return war_runtime.effective_owner_at(index)
	return owner_ids[index]


func control_to_geographic(control_position: Vector2) -> Vector2:
	var world_width: = _world_width()
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	var projected: = center_projected + (control_position - size * 0.5) / world_width
	return MWMapProjection.unproject(self, projected)


func control_position_for_geo(longitude: float, latitude: float) -> Vector2:
	var world_width: = _world_width()
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	var projected: = MWMapProjection.project(self, longitude, latitude)
	var delta_x: = MWWebMercator.shortest_wrapped_x_delta(projected.x, center_projected.x)
	return size * 0.5 + Vector2(delta_x, projected.y - center_projected.y) * world_width


func control_position_for_city(city: CityData) -> Vector2:
	return control_position_for_geo(city.longitude, city.latitude)


func geographic_position_for_country(country_id: int) -> Vector2:
	if not _country_sample_indices.has(country_id) or raster_size.x <= 0:
		return Vector2(INF, INF)
	var flat_index: int = _country_sample_indices[country_id]
	var pixel_y: = floori(float(flat_index) / float(raster_size.x))
	var pixel_x: = flat_index % raster_size.x
	return Vector2(
		(float(pixel_x) + 0.5) / float(raster_size.x) * 360.0 - 180.0, 
		90.0 - (float(pixel_y) + 0.5) / float(raster_size.y) * 180.0
	)


func control_position_for_country(country_id: int) -> Vector2:
	var geographic: = geographic_position_for_country(country_id)
	if not is_finite(geographic.x):
		return Vector2(-1.0, -1.0)
	return control_position_for_geo(geographic.x, geographic.y)


func _gui_input(event: InputEvent) -> void :
	var controller: = get_node_or_null("NativeCameraController") as MWCameraController
	if controller != null:
		if controller.handle_map_input(event):
			accept_event()
	elif not bool(get_meta("mw_visual_only_map", false)):
		_gui_input_reference(event)
	else:
		push_error("Playable map requires its native input controller.")


func _gui_input_reference(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		var button: = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 0.5)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, -0.5)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_left_pressed = true
				_left_drag_distance = 0.0
			else:
				_left_pressed = false
				if _left_drag_distance < 6.0:
					map_clicked.emit(button.position)
					var country_id: = country_id_at(button.position)
					if country_id > 0:
						country_clicked.emit(country_id)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			if button.pressed and _point_is_covered_by_hud_reference(button.position):
				_middle_dragging = false
				return
			_middle_dragging = button.pressed
			if button.pressed and _left_pressed:
				_left_drag_distance = 6.0
			accept_event()
	elif event is InputEventMouseMotion:
		var motion: = event as InputEventMouseMotion
		if _left_pressed:
			_left_drag_distance += motion.relative.length()
		if _middle_dragging:
			_pan_by_screen_delta(motion.relative)
			accept_event()


func _input(event: InputEvent) -> void :
	var controller: = get_node_or_null("NativeCameraController") as MWCameraController
	if controller != null:
		controller.handle_global_input(event)
	elif not bool(get_meta("mw_visual_only_map", false)):
		_input_reference(event)


func _input_reference(event: InputEvent) -> void :



	if event is InputEventMouseButton:
		var button: = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_MIDDLE and not button.pressed:
			_middle_dragging = false


func _point_is_covered_by_hud(local_point: Vector2) -> bool:
	var controller: = get_node_or_null("NativeCameraController") as MWCameraController
	if controller != null:
		return controller.point_is_covered_by_hud(local_point)
	return _point_is_covered_by_hud_reference(local_point)


func _point_is_covered_by_hud_reference(local_point: Vector2) -> bool:
	var parent_control: = get_parent() as Control
	if parent_control == null:
		return false
	var global_point: Vector2 = get_global_transform() * local_point
	for child_index: int in range(get_index() + 1, parent_control.get_child_count()):
		var sibling: = parent_control.get_child(child_index) as Control
		if sibling == null or not sibling.visible or sibling.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if sibling.get_global_rect().has_point(global_point):
			return true
	return false


func _draw() -> void :
	var profile_started: = Time.get_ticks_usec() if war_runtime != null and war_runtime.performance_profile_enabled else 0

	if texture == null:
		return

	if OS.is_debug_build() and bool(get_meta(&"verification_uncached_render", false)) and war_runtime != null and war_runtime.has_active_war():
		_draw_war_geography()
	var annotations_started: = Time.get_ticks_usec()
	_draw_annotations()
	if profile_started > 0 and war_runtime != null:
		war_runtime.record_render_profile(&"dynamic_overlay_redraw", Time.get_ticks_usec() - annotations_started, true)
		war_runtime.record_render_profile(&"canvas_draw", Time.get_ticks_usec() - profile_started)


func _build_static_border_texture() -> void :
	var borders: Image = MWMapProjection.encode_country_ids(owner_ids, raster_size)
	if borders == null:
		_build_static_border_texture_reference()
		return
	_static_border_texture = ImageTexture.create_from_image(_project_source_image(borders))


func _build_static_border_texture_reference() -> void :


	var borders: = Image.create(raster_size.x, raster_size.y, false, Image.FORMAT_RGBA8)
	borders.fill(Color.TRANSPARENT)
	for y: int in range(raster_size.y):
		for x: int in range(raster_size.x):
			var index: = y * raster_size.x + x
			var owner_id: = owner_ids[index]
			borders.set_pixel(x, y, Color(float(owner_id & 255) / 255.0, float((owner_id >> 8) & 255) / 255.0, float((owner_id >> 16) & 255) / 255.0, 1.0))
	_static_border_texture = ImageTexture.create_from_image(_project_source_image(borders))


func _draw_annotations() -> void :
	var viewport_rect: = Rect2(Vector2.ZERO, size).grow(12.0)
	var runtime: = war_runtime
	var oracle: = OS.is_debug_build() and bool(get_meta(&"verification_uncached_render", false))
	if oracle:
		if runtime != null and runtime.has_active_war(): _draw_war_bases(runtime, viewport_rect)
		_draw_city_annotations(viewport_rect)
	if runtime != null and runtime.has_active_war():
		_draw_war_units_and_battles(runtime, viewport_rect)
		if oracle and planning_visible: _draw_battle_plans(runtime, viewport_rect)
	if oracle and labels_visible: _draw_country_labels(viewport_rect)


func _draw_city_annotations(viewport_rect: Rect2, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	for city: CityData in cities:
		if not _city_is_visible(city):
			continue
		var base_point: = control_position_for_city(city)
		for point: Vector2 in _wrapped_visible_points(base_point, viewport_rect):
			var radius: = maxf(2.0, zoom_level - 2.0) * (2.0 if city.is_capital else 1.0)
			canvas.draw_circle(point, radius, Color.WHITE)
			canvas.draw_circle(point, radius, Color(0.0, 0.0, 0.0, 0.6), false, 1.0)
			if zoom_level >= 6.0:
				var baseline: = point + Vector2(maxf(2.0, zoom_level - 2.0) + 2.0, 4.0)
				canvas.draw_string_outline(_get_city_label_font(), baseline, city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color.BLACK)
				canvas.draw_string(_get_city_label_font(), baseline, city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func _city_is_visible(city: CityData) -> bool:
	if city.is_capital:
		return true
	if not cities_visible:
		return false
	if war_runtime != null and war_runtime.has_active_war() and war_runtime.active_theater_city_ids.has(city.id):
		return true
	if zoom_level >= 5.0:
		return true
	if zoom_level >= 4.0:
		return city.population > 50000
	if zoom_level >= 3.0:
		return city.population > 150000
	if zoom_level >= 2.0:
		return city.population > 400000
	return city.population > 1000000


func _draw_war_geography() -> void :
	var runtime: = war_runtime
	if runtime == null or runtime.grid_size != raster_size:
		return
	var pass_data: = _war_geography_view()
	var occupied_cells: = 0
	for item: Dictionary in pass_data["items"]:
		if runtime.state == ConflictRuntimeState.WarState.RUNNING:
			occupied_cells += _draw_war_frontline_region(item["region"], item["cache"], int(pass_data["step"]), runtime)
	war_render_stats = {"visible_regions": pass_data["items"].size(), "visible_grid_area": pass_data["area"], "render_step": pass_data["step"], "sampled_cells": int(_occupation_render_stats.get("sampled", 0)), "frontline_cells": occupied_cells}


func _draw_war_occupation_layer(target: CanvasItem) -> void :
	var runtime: = war_runtime
	_occupation_render_stats = {}
	if runtime == null or not runtime.has_active_war() or runtime.grid_size != raster_size:
		return
	var pass_data: = _war_geography_view()
	var rendered_cells: = 0
	var step: = int(pass_data["step"])
	for item: Dictionary in pass_data["items"]:
		var occupation_pass: = _draw_war_occupation_region(item["region"], item["cache"], step, runtime, target)
		rendered_cells += int(occupation_pass["sampled"])
		_draw_war_changed_borders_region(item["region"], item["cache"], occupation_pass["occupied_cells"], maxi(step, 2 if zoom_level < 5.0 else 1), runtime, target)
	_occupation_render_stats = {"sampled": rendered_cells}


func _war_geography_view() -> Dictionary:
	var runtime: = war_runtime
	var key: = [runtime.get_instance_id(), runtime.theater_bounds, raster_size, _world_origin(), _world_width(), size]
	if key == _war_view_cache_key:
		return _war_view_cache
	_war_view_cache_key = key
	var regions: Array[Dictionary] = []
	for camera_region: Dictionary in visible_war_grid_regions(WAR_RENDER_PADDING):
		var clipped_region: = _clip_war_region_to_theater(camera_region, runtime)
		if not clipped_region.is_empty():
			regions.append(clipped_region)
	var visible_area: = 0
	for region: Dictionary in regions:
		visible_area += int(region["x_end"] - region["x_start"]) * int(region["y_end"] - region["y_start"])
	var step: = adaptive_war_render_step(zoom_level, visible_area)
	var items: Array[Dictionary] = []
	for region: Dictionary in regions:
		items.append({"region": region, "cache": _build_war_projection_cache(region)})
	_war_view_cache = {"items": items, "area": visible_area, "step": step}
	return _war_view_cache


func _clip_war_region_to_theater(region: Dictionary, runtime: ConflictRuntimeState) -> Dictionary:
	var bounds: = runtime.theater_bounds
	var x_start: = maxi(int(region["x_start"]), bounds.position.x)
	var x_end: = mini(int(region["x_end"]), bounds.end.x)
	var y_start: = maxi(int(region["y_start"]), bounds.position.y)
	var y_end: = mini(int(region["y_end"]), bounds.end.y)
	if x_end <= x_start or y_end <= y_start:
		return {}
	return {
		"x_start": x_start, 
		"x_end": x_end, 
		"y_start": y_start, 
		"y_end": y_end, 
		"world_copy": int(region["world_copy"]), 
	}


static func adaptive_war_render_step(zoom: float, visible_area: int) -> int:
	if zoom <= 3.0:
		return 4
	if zoom <= 4.0:
		return 2
	if visible_area > 600000:
		return 3
	if visible_area > 150000:
		return 2
	return 1


func visible_war_grid_regions(padding_pixels: float = 0.0) -> Array[Dictionary]:
	return MWMapGridViewport.visible_regions(self, padding_pixels)


func _visible_war_grid_regions_reference(padding_pixels: float = 0.0) -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	if raster_size.x <= 0 or raster_size.y <= 0 or size.x <= 0.0 or size.y <= 0.0:
		return regions
	var world_width: = _world_width()
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	var left_world: = center_projected.x + ( - padding_pixels - size.x * 0.5) / world_width
	var right_world: = center_projected.x + (size.x + padding_pixels - size.x * 0.5) / world_width
	var top_projected: = clampf(center_projected.y + ( - padding_pixels - size.y * 0.5) / world_width, 0.0, MWMapProjection.normalized_height(self))
	var bottom_projected: = clampf(center_projected.y + (size.y + padding_pixels - size.y * 0.5) / world_width, 0.0, MWMapProjection.normalized_height(self))
	var north: = MWMapProjection.unproject(self, Vector2(0.5, top_projected)).y
	var south: = MWMapProjection.unproject(self, Vector2(0.5, bottom_projected)).y
	var y_start: = clampi(int(floor((90.0 - north) / 180.0 * raster_size.y)) - 1, 0, raster_size.y - 1)
	var y_end: = clampi(int(ceil((90.0 - south) / 180.0 * raster_size.y)) + 1, y_start + 1, raster_size.y)



	if right_world - left_world >= 1.0:
		regions.append({
			"x_start": 0, 
			"x_end": raster_size.x, 
			"y_start": y_start, 
			"y_end": y_end, 
			"world_copy": 0, 
		})
		return regions
	var first_copy: = int(floor(left_world))
	var last_copy: = int(floor(right_world - 1e-07))
	for world_copy: int in range(first_copy, last_copy + 1):
		var local_left: = clampf(left_world - float(world_copy), 0.0, 1.0)
		var local_right: = clampf(right_world - float(world_copy), 0.0, 1.0)
		if local_right <= local_left:
			continue
		var x_start: = clampi(int(floor(local_left * raster_size.x)) - 1, 0, raster_size.x - 1)
		var x_end: = clampi(int(ceil(local_right * raster_size.x)) + 1, x_start + 1, raster_size.x)
		regions.append({
			"x_start": x_start, 
			"x_end": x_end, 
			"y_start": y_start, 
			"y_end": y_end, 
			"world_copy": world_copy, 
		})
	return regions


func _build_war_projection_cache(region: Dictionary) -> Dictionary:
	return MWMapGridViewport.projection_cache(self, region)


func _build_war_projection_cache_reference(region: Dictionary) -> Dictionary:
	var x_start: int = region["x_start"]
	var x_end: int = region["x_end"]
	var y_start: int = region["y_start"]
	var y_end: int = region["y_end"]
	var world_copy: int = region["world_copy"]
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	var world_width: = _world_width()
	var x_positions: = PackedFloat32Array()
	var y_positions: = PackedFloat32Array()
	x_positions.resize(x_end - x_start + 1)
	y_positions.resize(y_end - y_start + 1)
	for x: int in range(x_start, x_end + 1):
		x_positions[x - x_start] = (float(x) / raster_size.x + world_copy - center_projected.x) * world_width + size.x * 0.5
	for y: int in range(y_start, y_end + 1):
		var latitude: = 90.0 - float(y) / raster_size.y * 180.0
		var projected_y: = MWMapProjection.project(self, 0.0, latitude).y
		y_positions[y - y_start] = (projected_y - center_projected.y) * world_width + size.y * 0.5
	return {
		"x_start": x_start, 
		"y_start": y_start, 
		"x_positions": x_positions, 
		"y_positions": y_positions, 
	}


func _war_cached_point(cache: Dictionary, x: int, y: int) -> Vector2:
	var xs: PackedFloat32Array = cache["x_positions"]
	var ys: PackedFloat32Array = cache["y_positions"]
	return Vector2(xs[x - int(cache["x_start"])], ys[y - int(cache["y_start"])])


func _draw_war_occupation_region(region: Dictionary, cache: Dictionary, step: int, runtime: ConflictRuntimeState, target: CanvasItem, rows: Vector2i = Vector2i(-1, -1), draw_fill: bool = true) -> Dictionary:
	if runtime.native_authoritative_active():
		if runtime._native_conflict_core == null or not runtime._native_conflict_core.has_method("native_visible_occupation_runs"):
			push_error("Native occupation render buffer is unavailable; rebuild the C++ extension")
			assert (false, "Native Main cannot silently use a stale DLL")
			return {"sampled": 0, "occupied_cells": PackedInt32Array()}
		var native_rows: Dictionary = runtime._native_conflict_core.native_visible_occupation_runs(
			int(region.x_start), int(region.x_end), int(region.y_start) if rows.x < 0 else rows.x, 
			int(region.y_end) if rows.y < 0 else rows.y, step)
		if not bool(native_rows.get("valid", false)):
			push_error("Native occupation render buffer rejected a visible source-grid region")
			assert (false, "Native occupation geometry must remain authoritative")
			return {"sampled": 0, "occupied_cells": PackedInt32Array()}
		var packed_runs: PackedInt32Array = native_rows.runs
		if packed_runs.size() % 4 != 0:
			push_error("Native occupation run columns are misaligned")
			assert (false, "Native occupation run buffer is invalid")
			return {"sampled": 0, "occupied_cells": PackedInt32Array()}
		if draw_fill:
			for offset: int in range(0, packed_runs.size(), 4):
				_draw_war_cached_block(cache, packed_runs[offset], packed_runs[offset + 2], packed_runs[offset + 1], 
					mini(packed_runs[offset + 2] + step, int(region.y_end)), packed_runs[offset + 3], runtime, target)
		return {"sampled": int(native_rows.sampled), "occupied_cells": native_rows.occupied_cells}
	var sampled: = 0
	var occupied_cells: = PackedInt32Array()
	var map_width: = raster_size.x
	var x_start: int = region["x_start"]
	var x_end: int = region["x_end"]
	var y_start: int = region["y_start"]
	var y_end: int = region["y_end"]
	for y: int in range(y_start if rows.x < 0 else rows.x, y_end if rows.y < 0 else rows.y, step):
		var run_owner: = -1
		var run_start: = x_start
		for x: int in range(x_start, x_end + step, step):
			var occupying_owner: = -1
			if x < x_end and y < raster_size.y:
				sampled += 1
				var index: = y * map_width + x
				var original_owner: int = runtime.prewar_world_owners[index]
				if runtime.country_to_side.has(original_owner):
					var effective_owner: = runtime.effective_owner_at(index)
					if effective_owner > 0 and effective_owner != original_owner:
						occupying_owner = effective_owner
						occupied_cells.append(index)
			if occupying_owner == run_owner:
				continue
			if run_owner > 0 and draw_fill:
				_draw_war_cached_block(cache, run_start, y, mini(x, x_end), mini(y + step, y_end), run_owner, runtime, target)
			run_owner = occupying_owner
			run_start = x
	return {"sampled": sampled, "occupied_cells": occupied_cells}


func _draw_war_cached_block(cache: Dictionary, x0: int, y0: int, x1: int, y1: int, country_id: int, runtime: ConflictRuntimeState, target: CanvasItem) -> void :
	if x1 <= x0 or y1 <= y0:
		return
	var north_west: = _war_cached_point(cache, x0, y0)
	var south_east: = _war_cached_point(cache, x1, y1)
	var fill: = runtime.country_color(country_id).lerp(Color.WHITE, OCCUPATION_WHITE_BLEND)
	fill.a = OCCUPATION_OVERLAY_ALPHA
	target.draw_rect(Rect2(north_west, south_east - north_west).abs().grow(0.5), fill)


func _draw_war_frontline_region(region: Dictionary, cache: Dictionary, step: int, runtime: ConflictRuntimeState, canvas: CanvasItem = null, rows: Vector2i = Vector2i(-1, -1), candidates: Variant = null) -> int:
	if canvas == null: canvas = self
	var mixed_cells: = 0
	var x_start: int = region["x_start"]
	var y_start: int = region["y_start"]
	var x_end: int = region["x_end"]
	var y_end: int = region["y_end"]
	for i00: int in (runtime.render_front_quads if candidates == null else candidates):
		var x: = i00 % raster_size.x
		var y: = floori(float(i00) / float(raster_size.x))
		if x < x_start or x >= x_end - 1 or y < y_start or y >= y_end - 1: continue
		if rows.x >= 0 and (y < rows.x or y >= rows.y): continue
		if (x - x_start) % step != 0 or (y - y_start) % step != 0: continue
		var i10: = i00 + 1
		var i01: = i00 + raster_size.x
		var i11: = i01 + 1
		var v00: float = runtime.occupation[i00]
		var v10: float = runtime.occupation[i10]
		var v01: float = runtime.occupation[i01]
		var v11: float = runtime.occupation[i11]
		mixed_cells += 1
		var p00: = _war_cached_point(cache, x, y)
		var p10: = _war_cached_point(cache, x + 1, y)
		var p01: = _war_cached_point(cache, x, y + 1)
		var p11: = _war_cached_point(cache, x + 1, y + 1)
		_draw_marching_triangle(p00, v00, p10, v10, p11, v11, canvas)
		_draw_marching_triangle(p00, v00, p11, v11, p01, v01, canvas)
	return mixed_cells


func _draw_war_changed_borders_region(region: Dictionary, cache: Dictionary, occupied_cells: PackedInt32Array, step: int, runtime: ConflictRuntimeState, target: CanvasItem) -> void :
	var border_color: = Color(1.0, 1.0, 1.0, 0.68)
	var x_start: int = region["x_start"]
	var x_end: int = region["x_end"]
	var y_start: int = region["y_start"]
	var y_end: int = region["y_end"]
	var line_width: = maxf(0.8, zoom_level * 0.18)
	for index: int in occupied_cells:
		var x: = index % raster_size.x
		var y: = floori(float(index) / float(raster_size.x))
		var effective_owner: = runtime.effective_owner_at(index)
		var east_x: = mini(x_end, x + step)
		var south_y: = mini(y_end, y + step)
		var west_x: = maxi(x_start, x - step)
		var north_y: = maxi(y_start, y - step)
		if east_x < raster_size.x and runtime.effective_owner_at(y * raster_size.x + east_x) != effective_owner:
			target.draw_line(_war_cached_point(cache, east_x, y), _war_cached_point(cache, east_x, south_y), border_color, line_width, true)
		if south_y < raster_size.y and runtime.effective_owner_at(south_y * raster_size.x + x) != effective_owner:
			target.draw_line(_war_cached_point(cache, x, south_y), _war_cached_point(cache, east_x, south_y), border_color, line_width, true)
		if west_x >= 0 and runtime.effective_owner_at(y * raster_size.x + west_x) != effective_owner:
			target.draw_line(_war_cached_point(cache, x, y), _war_cached_point(cache, x, south_y), border_color, line_width, true)
		if north_y >= 0 and runtime.effective_owner_at(north_y * raster_size.x + x) != effective_owner:
			target.draw_line(_war_cached_point(cache, x, y), _war_cached_point(cache, east_x, y), border_color, line_width, true)


func _draw_marching_triangle(a: Vector2, av: float, b: Vector2, bv: float, c: Vector2, cv: float, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var crossings: Array[Vector2] = []
	_append_zero_crossing(crossings, a, av, b, bv)
	_append_zero_crossing(crossings, b, bv, c, cv)
	_append_zero_crossing(crossings, c, cv, a, av)
	if crossings.size() >= 2:
		_draw_wrapped_line(crossings[0], crossings[1], Color(1.0, 1.0, 1.0, 0.9), maxf(0.8, 1.6 * (zoom_level / 5.0)), canvas)


func _append_zero_crossing(points: Array[Vector2], a: Vector2, av: float, b: Vector2, bv: float) -> void :
	if (av < 0.0 and bv < 0.0) or (av > 0.0 and bv > 0.0) or is_equal_approx(av, bv):
		return
	var amount: = absf(av) / maxf(1e-06, absf(av) + absf(bv))
	points.append(a.lerp(b, amount))


func _draw_war_bases(runtime: ConflictRuntimeState, viewport_rect: Rect2, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	for base: Dictionary in runtime.bases:
		var base_point: = control_position_for_geo(float(base["longitude"]), float(base["latitude"]))
		for point: Vector2 in _wrapped_visible_points(base_point, viewport_rect):
			var base_color: = Color("#ff4757") if int(base["side_index"]) == 0 else Color("#2e86de")
			var base_size: = maxf(4.0, zoom_level * 1.5)
			canvas.draw_circle(point, base_size * 1.5, Color(base_color, 0.22))
			canvas.draw_rect(Rect2(point - Vector2.ONE * base_size * 0.5, Vector2.ONE * base_size), Color.WHITE)
			canvas.draw_rect(Rect2(point - Vector2.ONE * base_size * 0.5, Vector2.ONE * base_size), base_color, false, maxf(1.0, zoom_level * 0.18))
			canvas.draw_line(point + Vector2( - base_size * 0.28, 0.0), point + Vector2(base_size * 0.28, 0.0), base_color, 1.25, true)
			canvas.draw_line(point + Vector2(0.0, - base_size * 0.28), point + Vector2(0.0, base_size * 0.28), base_color, 1.25, true)


func _draw_war_units_and_battles(runtime: ConflictRuntimeState, viewport_rect: Rect2) -> void :
	if runtime.native_authoritative_active():
		_draw_native_war_units_and_battles(runtime, viewport_rect)
		return
	var visible_unit_indices: = _visible_war_unit_indices(runtime) if units_visual_visible else PackedInt32Array()
	war_render_stats["visible_units"] = visible_unit_indices.size()
	var actual_markers: = 0
	var unit_scale: = pow(1.3, zoom_level - 3.0)
	var unit_size: = unit_marker_size(zoom_level)
	for unit_index: int in visible_unit_indices:
		if unit_index < 0 or unit_index >= runtime.units.size():
			continue
		var unit: Dictionary = runtime.units[unit_index]
		var point_base: = control_position_for_geo(float(unit["longitude"]), float(unit["latitude"]))
		for point: Vector2 in _wrapped_visible_points(point_base, viewport_rect):
			var country_color: = runtime.country_color(int(unit["sovereign_id"]))
			if unit_view_mode == UnitViewMode.GROUPS:
				var marker_size: = unit_size * 0.27
				for representative: Vector3 in formation_marker_layout(unit, zoom_level):
					actual_markers += 1
					var marker_rect: = Rect2(point + Vector2(representative.x, representative.y) * unit_size.x / 48.0 - marker_size * 0.5, marker_size)
					draw_rect(marker_rect.grow(1.0), Color(0.0, 0.0, 0.0, representative.z * 0.9))
					draw_rect(marker_rect, Color(country_color, representative.z))
				continue
			var unit_rect: = Rect2(point - unit_size * 0.5, unit_size)
			actual_markers += 1
			draw_rect(unit_rect.grow(maxf(1.0, unit_scale * 0.55)), Color(0.0, 0.0, 0.0, 0.82))
			draw_rect(unit_rect, country_color)
	war_render_stats["drawn_unit_markers"] = actual_markers
	if formation_debug_visible:
		_draw_formation_debug(runtime, visible_unit_indices)
	if battle_visuals_visible:
		for battle: Dictionary in runtime.active_battles:
			var battle_base: = control_position_for_geo(float(battle["longitude"]), float(battle["latitude"]))
			for point: Vector2 in _wrapped_visible_points(battle_base, viewport_rect):
				var pulse: = battle_clash_pulse(runtime.sim_tick_count, int(battle.get("damage_tick", runtime.sim_tick_count)))
				var marker_size: = clampf(6.0 + float(battle.get("participants", 2)) * 0.35 + zoom_level * 0.5, 8.0, 18.0) * (1.0 + pulse * 0.12)
				draw_circle(point, marker_size, Color(0.0, 0.0, 0.0, 0.68 + pulse * 0.12))
				draw_line(point + Vector2( - marker_size * 0.48, - marker_size * 0.48), point + Vector2(marker_size * 0.48, marker_size * 0.48), Color("#f1c40f"), maxf(1.5, zoom_level * 0.25), true)
				draw_line(point + Vector2(marker_size * 0.48, - marker_size * 0.48), point + Vector2( - marker_size * 0.48, marker_size * 0.48), Color("#f1c40f"), maxf(1.5, zoom_level * 0.25), true)
	_draw_soldier_strength_labels(runtime, viewport_rect)
	_draw_encirclement_popups(runtime, viewport_rect)


func _draw_native_war_units_and_battles(runtime: ConflictRuntimeState, viewport_rect: Rect2) -> void :


	var draw_result: Dictionary = _unit_flag_renderer.draw_snapshot(
		self, runtime.native_render_snapshot, runtime.country_colors, 
		Vector2(center_longitude, center_latitude), zoom_level, size, viewport_rect, 
		unit_view_mode == UnitViewMode.GROUPS, units_visual_visible)
	if not bool(draw_result.get("ok", false)):
		push_error("Native formation render columns are misaligned")
		return
	war_render_stats["visible_units"] = int(draw_result["visible_units"])
	war_render_stats["drawn_unit_markers"] = int(draw_result["drawn_unit_markers"])
	war_render_stats["flag_markers"] = int(draw_result["flag_markers"])
	war_render_stats["fallback_markers"] = int(draw_result["fallback_markers"])
	if battle_visuals_visible:
		war_render_stats["visible_battles"] = _unit_flag_renderer.draw_battles(
			self, runtime.active_battles, runtime.sim_tick_count, 
			Vector2(center_longitude, center_latitude), zoom_level, size, viewport_rect)
	if planning_visible and is_instance_valid(_planning_overlay):


		RenderingServer.canvas_item_set_draw_index(_planning_overlay.get_canvas_item(), 10001)
	_draw_soldier_strength_labels(runtime, viewport_rect)


const UNIT_MARKER_RENDER_FACTOR: = 0.7


static func unit_marker_size(display_zoom: float) -> Vector2:


	var width: = lerpf(12.0, 20.0, clampf((display_zoom - 4.0) / 2.0, 0.0, 1.0))
	if display_zoom > 6.0: width = lerpf(20.0, 32.0, clampf((display_zoom - 6.0) / 1.5, 0.0, 1.0))
	var nominal: = Vector2(width, width * 0.6) / UNIT_MARKER_RENDER_FACTOR
	return nominal * UNIT_MARKER_RENDER_FACTOR


func _draw_formation_debug(runtime: ConflictRuntimeState, visible_indices: PackedInt32Array) -> void :
	var font: = ThemeDB.fallback_font
	var route_budget: = 16
	for i: int in visible_indices:
		if i >= runtime.units.size(): continue
		var unit: Dictionary = runtime.units[i]
		var origin: = control_position_for_geo(unit.longitude, unit.latitude)
		var geo: = Vector2(unit.longitude, unit.latitude)
		var target: Vector2 = unit.get("sector_destination", unit.get("formation_target", geo))
		var point: = control_position_for_geo(target.x, target.y)
		_draw_wrapped_line(origin, point, Color(1.0, 0.8, 0.2, 0.65), 1.0)
		for axis: String in ["formation_tangent", "formation_normal"]:
			var end: Vector2 = target + unit.get(axis, Vector2.ZERO) * 0.08
			_draw_wrapped_line(point, control_position_for_geo(end.x, end.y), Color.CYAN if axis == "formation_tangent" else Color.YELLOW, 1.0)
		var personnel: = roundi(runtime.unit_personnel(unit))
		var label: = "%d %dp %s %s sector:%d city:%d op:%d" % [unit.id, personnel, unit.get("formation_row", "waiting"), unit.get("sector_role", "WAITING"), int(unit.get("front_sector", -1)), int(unit.get("reinforcement_city_id", -1)), int(unit.get("sector_operation", -1))]
		if unit.has("deployment_phase"):
			label += " %s %.2fs exit:%s route:%d boost:%s" % [unit.deployment_phase, maxf(0.0, float(unit.get("muster_until", 0.0)) - runtime.simulation_seconds), unit.get("city_exit_slot", unit.get("departure_exit_slot", "released")), (unit.get("reinforcement_route", PackedInt32Array()) as PackedInt32Array).size(), str(unit.get("deployment_transit", false))]
			if route_budget > 0 and unit.deployment_phase != "ACTIVE":
				route_budget -= 1
				var route: PackedInt32Array = unit.get("reinforcement_route", PackedInt32Array())
				var cursor: = int(unit.get("reinforcement_route_cursor", 0))
				var previous: = origin
				for step: int in range(cursor, mini(route.size(), cursor + 64)):
					var waypoint: = runtime.geo_for_grid_index(route[step])
					var route_point: = control_position_for_geo(waypoint.x, waypoint.y)
					_draw_wrapped_line(previous, route_point, Color(0.4, 0.9, 1.0, 0.6), 1.0)
					previous = route_point
				var exit_geo: Vector2 = unit.get("city_exit_target", geo)
				_draw_wrapped_line(origin, control_position_for_geo(exit_geo.x, exit_geo.y), Color(1.0, 0.7, 0.2, 0.8), 1.5)
		draw_string_outline(font, origin + Vector2(8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, origin + Vector2(8, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


static func battle_clash_pulse(current_tick: int, damage_tick: int) -> float:
	return clampf(1.0 - float(maxi(0, current_tick - damage_tick)) / 8.0, 0.0, 1.0)


const PLANNING_LINE_WIDTH: = 22.0
const PLANNING_SPEAR_WIDTH: = 10.0
const PLANNING_LINE_ALPHA: = 1.0
const PLANNING_SPEAR_ALPHA: = 0.9

func _draw_battle_plans(runtime: ConflictRuntimeState, viewport_rect: Rect2, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var planner_visual: = runtime.planning_visual_state()
	var operations: Dictionary = planner_visual.get("operations", {})
	var commanders: Dictionary = planner_visual.get("commander_groups", {})
	var sectors: Dictionary = planner_visual.get("sector_candidates", {})
	var labels: Array[Dictionary] = []


	for commander: Dictionary in commanders.values():
		var operation: Dictionary = operations.get(int(commander["operation"]), {})
		if operation.is_empty(): continue
		if not planning_operation_is_pushing(operation): continue



		var start_geo: = planning_front_attachment(commander["anchor_geo"], sectors.get(int(commander["country"]), []))
		var target_geo: Vector2 = commander["objective"]["geo"]
		var start: = control_position_for_geo(start_geo.x, start_geo.y)
		var target: = control_position_for_geo(target_geo.x, target_geo.y)
		var color: = runtime.country_color(int(commander["country"]))


		var bend: = (0.16 if int(operation["side"]) == 0 else -0.16) + (int(operation["id"]) % 3 - 1) * 0.07
		var caption: = "%s OFFENSIVE" % String(commander["objective"]["name"]).to_upper()
		_draw_plan_ribbon(start, target, color, true, bend, "", viewport_rect, canvas)
		var unwrapped_target: = target
		unwrapped_target.x = start.x + fposmod(target.x - start.x + _world_width() * 0.5, _world_width()) - _world_width() * 0.5
		var spine: = planning_arrow_spine(start, unwrapped_target, bend)
		var bounds: = Rect2(start, Vector2.ZERO)
		for point: Vector2 in spine: bounds = bounds.expand(point)
		if bounds.grow(80).intersects(viewport_rect):
			var importance: = (100.0 if bool(commander["objective"].get("capital", false)) else 0.0) + float(operation["progress"]) * 40.0 + (20.0 if operation["phase"] == "pushing" else 0.0)
			labels.append({"point": spine[8 + (int(operation["id"]) % 3) * 4], "caption": caption, "color": color, "side": int(operation["side"]), "importance": importance, "operation": int(operation["id"])})


	var caption_rects: Array[Rect2] = []
	var font: = _get_country_label_font()
	labels = planning_operation_captions(labels)
	for label: Dictionary in labels:
		var point: Vector2 = label["point"]
		var text_size: = font.get_string_size(label["caption"], HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
		for attempt: int in range(12):
			var candidate: = Rect2(point + Vector2( - text_size.x * 0.5, - PLANNING_LINE_WIDTH - 28), Vector2(text_size.x, 24)).grow(3)
			var overlaps: = false
			for occupied: Rect2 in caption_rects:
				if candidate.intersects(occupied): overlaps = true;break
			if not overlaps:
				caption_rects.append(candidate)
				break
			point.y -= 27
		_draw_operation_caption(point, label["caption"], viewport_rect, label["color"], canvas)
	war_render_stats["planning_groups"] = 0
	war_render_stats["planning_ai_groups"] = int(planner_visual.get("officer_group_count", 0))
	war_render_stats["planning_captions"] = labels.size()
	war_render_stats["planning_operations"] = operations.size()
	war_render_stats["planning_visible_operations"] = _visible_offensive_operations(operations)

static func planning_operation_is_pushing(operation: Dictionary) -> bool:





	return operation.get("phase", "") == "pushing" and not MWBattleDoctrines.homeland_only(String(operation.get("doctrine", "COMB"))) and operation.get("posture_kind", "") in ["offensive_line", "spearhead", "encircle", "raid", "reinforce"]

static func _visible_offensive_operations(operations: Dictionary) -> int:
	var count: = 0
	for operation: Dictionary in operations.values():
		count += int(planning_operation_is_pushing(operation))
	return count

static func planning_operation_captions(candidates: Array[Dictionary]) -> Array[Dictionary]:


	candidates.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return a["importance"] > b["importance"] if a["importance"] != b["importance"] else a["operation"] < b["operation"])
	return candidates

static func planning_arrow_spine(start: Vector2, target: Vector2, bend: float) -> PackedVector2Array:
	var delta: = target - start
	var normal: = Vector2( - delta.y, delta.x).normalized()
	var offset: = normal * clampf(delta.length() * bend, -100.0, 100.0)
	var first: = start + delta * 0.3 + offset
	var second: = start + delta * 0.72 + offset
	var points: = PackedVector2Array()
	points.resize(25)
	for sample: int in points.size():
		points[sample] = bezier_point(sample / 24.0, start, first, second, target)
	return points

static func planning_front_attachment(anchor: Vector2, sectors: Array) -> Vector2:
	if sectors.is_empty(): return anchor
	var closest: = anchor
	var best_distance: = INF
	for sector: Dictionary in sectors:
		var geo: Vector2 = sector["geo"]
		geo.x = anchor.x + fposmod(geo.x - anchor.x + 180.0, 360.0) - 180.0
		var distance: = anchor.distance_squared_to(geo)
		if distance < best_distance:
			best_distance = distance
			closest = geo
	var attached: = closest


	for sector: Dictionary in sectors:
		var geo: Vector2 = sector["geo"]
		geo.x = anchor.x + fposmod(geo.x - anchor.x + 180.0, 360.0) - 180.0
		var leg: = geo - closest
		if leg.length_squared() < 1e-06 or leg.length_squared() > 0.1225: continue
		var candidate: = closest + leg * clampf((anchor - closest).dot(leg) / leg.length_squared(), 0.0, 1.0)
		if anchor.distance_squared_to(candidate) < best_distance:
			best_distance = anchor.distance_squared_to(candidate)
			attached = candidate
	attached.x = fposmod(attached.x + 180.0, 360.0) - 180.0
	return attached

static func planning_arrow_vertex_colors(polygon: PackedVector2Array, spine: PackedVector2Array, color: Color) -> PackedColorArray:
	var colors: = PackedColorArray()
	for vertex: Vector2 in polygon:
		var best_distance: = INF
		var progress: = 0.0
		for sample: int in range(spine.size() - 1):
			var leg: = spine[sample + 1] - spine[sample]
			var fraction: = clampf((vertex - spine[sample]).dot(leg) / maxf(leg.length_squared(), 1e-06), 0.0, 1.0)
			var distance: = vertex.distance_squared_to(spine[sample] + leg * fraction)
			if distance < best_distance:
				best_distance = distance
				progress = (sample + fraction) / float(spine.size() - 1)
		var vertex_color: = color
		vertex_color.a = color.a * lerpf(0.08, 1.0, smoothstep(0.0, 0.55, progress))
		colors.append(vertex_color)
	return colors

static func planning_arrow_polygon(points: PackedVector2Array, width: float) -> PackedVector2Array:
	if points.size() < 3 or points[0].distance_to(points[-1]) < 20.0: return PackedVector2Array()
	var neck: = points.size() - 2
	var head_length: = minf(width * 1.8, points[0].distance_to(points[-1]) * 0.3)
	while neck > 1 and points[neck].distance_to(points[-1]) < head_length: neck -= 1
	var left: = PackedVector2Array()
	var right: = PackedVector2Array()
	for sample: int in range(neck + 1):
		var tangent: = points[mini(sample + 1, points.size() - 1)] - points[maxi(0, sample - 1)]
		var normal: = Vector2( - tangent.y, tangent.x).normalized()


		var half_width: = width * 0.5
		left.append(points[sample] + normal * half_width)
		right.append(points[sample] - normal * half_width)
	var heading: = (points[-1] - points[neck]).normalized()
	var head_normal: = Vector2( - heading.y, heading.x)
	left.append(points[neck] + head_normal * width)
	left.append(points[-1])
	left.append(points[neck] - head_normal * width)
	right.reverse()
	left.append_array(right)
	return left

func _draw_plan_ribbon(start: Vector2, target: Vector2, color: Color, broad: bool, bend: float, caption: String, viewport_rect: Rect2, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var world_width: = _world_width()
	target.x = start.x + fposmod(target.x - start.x + world_width * 0.5, world_width) - world_width * 0.5
	var width: = PLANNING_LINE_WIDTH if broad else PLANNING_SPEAR_WIDTH
	var spine: = planning_arrow_spine(start, target, bend)
	var bounds: = Rect2(start, Vector2.ZERO)
	for point: Vector2 in spine: bounds = bounds.expand(point)
	if not bounds.grow(80).intersects(viewport_rect): return
	var polygon: = planning_arrow_polygon(spine, width)
	color.a = PLANNING_LINE_ALPHA if broad else PLANNING_SPEAR_ALPHA
	if polygon.is_empty():
		if not broad: return


		if viewport_rect.grow(24).has_point(start):
			canvas.draw_circle(start, 12.0, Color(0.02, 0.025, 0.03, 0.95))
			canvas.draw_circle(start, 8.0, color)
	else:
		var vertex_colors: = planning_arrow_vertex_colors(polygon, spine, color)
		canvas.draw_polygon(polygon, vertex_colors)
		polygon.append(polygon[0])
		vertex_colors.append(vertex_colors[0])
		for edge: int in range(polygon.size() - 1):
			var outline_alpha: = (vertex_colors[edge].a + vertex_colors[edge + 1].a) * 0.475
			canvas.draw_line(polygon[edge], polygon[edge + 1], Color(0.025, 0.03, 0.035, outline_alpha), 3.5 if broad else 2.2, true)


	if not broad:
		var heading: = (spine[-1] - spine[-4]).normalized()
		var normal: = Vector2( - heading.y, heading.x)
		var inner_tip: = spine[-1] - heading * width * 0.65
		var inner_neck: = inner_tip - heading * width * 0.9
		var chevron: = PackedVector2Array([inner_neck + normal * width * 0.58, inner_tip, inner_neck - normal * width * 0.58])
		canvas.draw_polyline(chevron, Color(0.035, 0.045, 0.055, 0.95), 2.4, true)
	if not caption.is_empty():
		_draw_operation_caption(spine[12], caption, viewport_rect, color, canvas)

func _draw_operation_caption(point: Vector2, caption: String, viewport_rect: Rect2, color: Color = Color.WHITE, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var font: = _get_country_label_font()
	var label_point: = point + Vector2(0, - PLANNING_LINE_WIDTH - 8)
	label_point.x -= font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x * 0.5
	label_point.x = clampf(label_point.x, viewport_rect.position.x + 8, maxf(viewport_rect.position.x + 8, viewport_rect.end.x - font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x - 8))
	label_point.y = clampf(label_point.y, viewport_rect.position.y + 26, viewport_rect.end.y - 16)
	canvas.draw_string_outline(font, label_point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 3, Color(0, 0, 0, 0.95))
	color.a = 1.0
	canvas.draw_string(font, label_point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)

static func formation_marker_layout(unit: Dictionary, display_zoom: float) -> PackedVector3Array:
	var layout: = PackedVector3Array()
	var formation_weight: = clampf(float(unit.get("health", 0.0)) / ConflictRuntimeState.UNIT_HEALTH, 0.0, 5.0)
	var health_fraction: = minf(formation_weight, 1.0)
	if health_fraction <= 0.0:
		return layout

	var count: = clampi(int(ceil(9.0 * (formation_weight if formation_weight <= 1.0 else sqrt(formation_weight)))), 1, 18)
	var movement: Vector2 = unit.get("direction", Vector2.ZERO)
	var facing: = Vector2(movement.x, - movement.y).angle() if movement.length_squared() > 1e-06 else float(unit.get("tactical_phase", 0.0)) * TAU
	var spacing: = clampf(5.0 + (display_zoom - 3.0), 5.0, 12.0)

	var identity: = int(unit.get("id", 0))
	var offsets: = [Vector2.ZERO, Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]
	layout.resize(count)
	for marker: int in range(count):
		var jitter: = Vector2(sin(identity * 17.0 + marker * 31.0), cos(identity * 13.0 + marker * 23.0)) * 0.7
		var base_offset: Vector2 = offsets[marker] if marker < offsets.size() else Vector2(-3 + (marker - 9) % 3, -1 + int(floor(float(marker - 9) / 3.0)))
		var offset: Vector2 = (base_offset * spacing + jitter).rotated(facing)
		layout[marker] = Vector3(offset.x, offset.y, 0.4 + health_fraction * 0.6)
	return layout


func _visible_war_unit_indices(runtime: ConflictRuntimeState) -> PackedInt32Array:
	var result: = PackedInt32Array()
	if runtime == null or runtime.units.is_empty():
		return result
	var regions: = visible_war_grid_regions(24.0)
	var seen: Dictionary = {}
	var hash_columns: = int(ceil(360.0 / WAR_HASH_CELL_SIZE))
	var estimated_bucket_count: = 0
	for region: Dictionary in regions:
		var west: = float(region["x_start"]) / raster_size.x * 360.0 - 180.0
		var east: = float(region["x_end"]) / raster_size.x * 360.0 - 180.0
		var north: = 90.0 - float(region["y_start"]) / raster_size.y * 180.0
		var south: = 90.0 - float(region["y_end"]) / raster_size.y * 180.0
		var min_key_x: = clampi(int(floor((west + 180.0) / WAR_HASH_CELL_SIZE)), 0, hash_columns - 1)
		var max_key_x: = clampi(int(floor((east + 180.0) / WAR_HASH_CELL_SIZE)), min_key_x, hash_columns - 1)
		var min_key_y: = int(floor((south + 90.0) / WAR_HASH_CELL_SIZE))
		var max_key_y: = int(floor((north + 90.0) / WAR_HASH_CELL_SIZE))
		estimated_bucket_count += (max_key_x - min_key_x + 1) * (max_key_y - min_key_y + 1)
		if estimated_bucket_count > runtime.units.size() * 3:
			result.resize(runtime.units.size())
			for index: int in range(runtime.units.size()):
				result[index] = index
			return result
		for key_y: int in range(min_key_y, max_key_y + 1):
			for key_x: int in range(min_key_x, max_key_x + 1):
				var bucket: Array = runtime.unit_spatial_hash.get(Vector2i(key_x, key_y), [])
				for unit_index: int in bucket:
					if unit_index >= 0 and unit_index < runtime.units.size() and not seen.has(unit_index):
						seen[unit_index] = true
						result.append(unit_index)
	return result


func _draw_soldier_strength_labels(runtime: ConflictRuntimeState, viewport_rect: Rect2) -> void :
	var font: = _get_strength_label_font()
	if runtime.native_authoritative_active():
		_unit_flag_renderer.draw_strength_layout(self, _cached_strength_layout(runtime), font, viewport_rect)
		return
	for label: Dictionary in _cached_strength_layout(runtime):
		var font_size: = int(label.font_size)
		var text: String = label["text"]
		var point: Vector2 = label["point"]
		if not viewport_rect.grow(font_size).has_point(point):
			continue
		var baseline: Vector2 = label.baseline
		draw_set_transform(point, float(label["angle"]))
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#ff4757") if int(label["side"]) == 0 else Color("#2e86de"))
		draw_set_transform(Vector2.ZERO)


func _cached_strength_layout(runtime: ConflictRuntimeState) -> Array[Dictionary]:
	var font: = _get_strength_label_font()
	var strength_revision: = int(runtime.get_meta("rust_strength_bucket", runtime.visual_revisions.unit_revision))
	var key: = [runtime, runtime.visual_revisions.generation, strength_revision, sync_camera_revision(), font]
	if key == _strength_layout_key: return _strength_layout
	_strength_layout_key = key
	_strength_layout = visible_soldier_strength_labels(runtime)
	var font_size: = int(maxf(12.0, zoom_level * 4.0))
	for label: Dictionary in _strength_layout:
		if not label.get("positioned", false):
			label.point += Vector2(0, - maxf(30.0, zoom_level * 5.0))
		label.font_size = font_size
		label.baseline = Vector2( - font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0, font.get_ascent(font_size) - font.get_height(font_size) / 2.0)
	strength_layout_build_count += 1
	return _strength_layout


func visible_soldier_strength_labels(runtime: ConflictRuntimeState) -> Array[Dictionary]:
	if runtime.native_authoritative_active():
		return _native_visible_soldier_strength_labels(runtime)



	var groups: Array = [[], []]
	var sums: = [Vector2.ZERO, Vector2.ZERO]
	var health: = [0.0, 0.0]
	var visible_rect: = Rect2(Vector2.ZERO, size)
	for index: int in _visible_war_unit_indices(runtime):
		var unit: Dictionary = runtime.units[index]
		var side: = int(unit["side_index"])
		if side < 0 or side > 1 or float(unit["health"]) <= 0.0:
			continue
		var longitude: = center_longitude + fposmod(float(unit["longitude"]) - center_longitude + 180.0, 360.0) - 180.0
		var geographic: = Vector2(longitude, float(unit["latitude"]))
		var point: = control_position_for_geo(geographic.x, geographic.y)
		if not visible_rect.has_point(point):
			continue
		groups[side].append(geographic)
		sums[side] += geographic
		health[side] += runtime.unit_personnel(unit)
	var labels: Array[Dictionary] = []
	for side: int in range(2):
		var count: int = groups[side].size()
		if count == 0:
			continue
		var geographic: Vector2 = sums[side] / float(count)
		var point: = control_position_for_geo(geographic.x, geographic.y)
		var angle: = 0.0
		if count > 5:
			var furthest: Vector2 = groups[side][0]
			var greatest: = -1.0
			for candidate: Vector2 in groups[side]:
				var distance: = candidate.distance_squared_to(geographic)
				if distance > greatest:
					greatest = distance
					furthest = candidate
			angle = (control_position_for_geo(furthest.x, furthest.y) - point).angle()
			if angle > PI / 2.0:
				angle -= PI
			elif angle < - PI / 2.0:
				angle += PI
			angle *= 0.3
		var soldiers: float = health[side]
		labels.append({"side": side, "units": count, "soldiers": soldiers, "geographic": geographic, "point": point, "angle": angle, "text": ConflictRuntimeState.format_source_soldiers(1.0 if soldiers > 0.0 and soldiers < 1.0 else soldiers)})
	return labels


func _native_visible_soldier_strength_labels(runtime: ConflictRuntimeState) -> Array[Dictionary]:
	return _unit_flag_renderer.strength_labels(self, runtime.native_render_snapshot, 
		Vector2(center_longitude, center_latitude), zoom_level, size)


func _get_strength_label_font() -> SystemFont:
	if _strength_label_font == null:
		_strength_label_font = SystemFont.new()
		_strength_label_font.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica", "Arial"])
		_strength_label_font.font_weight = 900
	return _strength_label_font


func _draw_encirclement_popups(runtime: ConflictRuntimeState, viewport_rect: Rect2) -> void :
	if _encirclement_popup_font == null:
		_encirclement_popup_font = SystemFont.new()
		_encirclement_popup_font.font_names = PackedStringArray(["Arial", "Helvetica"])
		_encirclement_popup_font.font_weight = 700
	var font: = _encirclement_popup_font
	for popup: Dictionary in runtime.encirclement_popups:
		var fraction: = float(popup["life"]) / float(popup["max_life"])
		var alpha: = minf(1.0, fraction * 1.6)
		var base: = control_position_for_geo(float(popup["longitude"]), float(popup["latitude"]))
		var text: String = popup["text"]
		for point: Vector2 in _wrapped_visible_points(base, viewport_rect):
			var baseline: = point + Vector2( - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2.0, - (1.0 - fraction) * 34.0)
			draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color(0, 0, 0, 0.85 * alpha))
			draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 225.0 / 255.0, 77.0 / 255.0, alpha))


func _format_compact_number(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


func _control_position_for_grid_corner(x: int, y: int) -> Vector2:
	var longitude: = float(x) / float(raster_size.x) * 360.0 - 180.0
	var latitude: = 90.0 - float(y) / float(raster_size.y) * 180.0
	return control_position_for_geo(longitude, latitude)


func _visible_wrap_offsets(point_x: float) -> Array[float]:
	var world_width: = _world_width()
	var offsets: Array[float] = [0.0]
	if point_x < size.x + world_width:
		offsets.append(world_width)
	if point_x > - world_width:
		offsets.append( - world_width)
	return offsets


func _draw_wrapped_line(from: Vector2, to: Vector2, color: Color, width: float, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var world_width: = _world_width()
	var adjusted_to: = to
	if adjusted_to.x - from.x > world_width * 0.5:
		adjusted_to.x -= world_width
	elif adjusted_to.x - from.x < - world_width * 0.5:
		adjusted_to.x += world_width
	for offset_x: float in _visible_wrap_offsets(from.x):
		canvas.draw_line(from + Vector2(offset_x, 0.0), adjusted_to + Vector2(offset_x, 0.0), color, width, true)


func _country_label_font_size(bounds: Rect2i, label: String, path_length: float) -> float:
	if bounds.size.x <= 0 or bounds.size.y <= 0 or label.is_empty() or path_length <= 0.0:
		return 0.0
	var world_width: = _world_width()
	var longitude_span: = float(bounds.size.x) / float(raster_size.x)
	var north_latitude: = 90.0 - float(bounds.position.y) / float(raster_size.y) * 180.0
	var south_latitude: = 90.0 - float(bounds.end.y) / float(raster_size.y) * 180.0
	var projected_north: = MWMapProjection.project(self, 0.0, north_latitude).y
	var projected_south: = MWMapProjection.project(self, 0.0, south_latitude).y
	var screen_width: = longitude_span * world_width
	var screen_height: = absf(projected_south - projected_north) * world_width
	var area_scale: = sqrt(maxf(0.0, screen_width * screen_height))
	if area_scale < 24.0:
		return 0.0
	var source_size: = clampf(area_scale / 4.5, 8.0, 36.0)
	var fit_size: = path_length / (float(label.length()) * (0.6 + LABEL_SPACING_FACTOR))
	var final_size: = minf(source_size, fit_size)
	return final_size if final_size >= 8.0 else 0.0


func label_region_count_for_country(country_id: int) -> int:
	var count: = 0
	for region: Dictionary in _label_regions:
		if int(region.get("country_id", 0)) == country_id:
			count += 1
	return count


func label_regions_have_source_bins(country_id: int) -> bool:
	var found: = false
	for region: Dictionary in _label_regions:
		if int(region.get("country_id", 0)) != country_id:
			continue
		found = true
		var bins: Array = region.get("bins", [])
		if bins.size() != LABEL_REGION_BIN_COUNT:
			return false
	return found


static func bezier_point(t: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var inverse: = 1.0 - t
	return inverse * inverse * inverse * p0 + 3.0 * inverse * inverse * t * p1 + 3.0 * inverse * t * t * p2 + t * t * t * p3


static func bezier_tangent_angle(t: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	var inverse: = 1.0 - t
	var tangent: = 3.0 * inverse * inverse * (p1 - p0) + 6.0 * inverse * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)
	return tangent.angle()


func _wrapped_visible_points(base_point: Vector2, viewport_rect: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var world_width: = _world_width()
	var first_copy: = int(floor((viewport_rect.position.x - base_point.x) / world_width))
	var last_copy: = int(ceil((viewport_rect.end.x - base_point.x) / world_width))
	for copy_index: int in range(first_copy, last_copy + 1):
		var point: = base_point + Vector2(copy_index * world_width, 0.0)
		if viewport_rect.has_point(point):
			points.append(point)
	return points


func _draw_country_labels(viewport_rect: Rect2, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var padded_viewport: = viewport_rect.grow(400.0)
	for region: Dictionary in _label_regions:
		var country_id: = int(region.get("country_id", 0))
		var label: = str(country_names.get(country_id, "")).to_upper()
		if label.is_empty():
			continue
		var center_geo: Vector2 = region.get("center_geo", Vector2(INF, INF))
		if not is_finite(center_geo.x):
			continue
		var base_center: = control_position_for_geo(center_geo.x, center_geo.y)
		for wrapped_center: Vector2 in _wrapped_visible_points(base_center, padded_viewport):
			var points: = _curve_points_for_region(region, wrapped_center - base_center)
			if points.size() != LABEL_REGION_BIN_COUNT:
				continue
			var path_length: = _bezier_path_length(points)
			var bounds: Rect2i = region.get("bounds", Rect2i())
			var font_size: = _country_label_font_size(bounds, label, path_length)
			if font_size < 7.0:
				continue
			_draw_text_on_curve(label, points, font_size, canvas)


func _curve_points_for_region(region: Dictionary, world_copy_offset: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var bins: Array = region.get("bins", [])
	if bins.size() != LABEL_REGION_BIN_COUNT:
		return result
	var center_geo: Vector2 = region.get("center_geo", Vector2.ZERO)
	var center_point: = control_position_for_geo(center_geo.x, center_geo.y)
	var world_width: = _world_width()
	for geographic_variant: Variant in bins:
		var geographic: Vector2 = geographic_variant
		var point: = control_position_for_geo(geographic.x, geographic.y)
		while point.x - center_point.x > world_width * 0.5:
			point.x -= world_width
		while point.x - center_point.x < - world_width * 0.5:
			point.x += world_width
		result.append(point + world_copy_offset)
	return result


func _bezier_path_length(points: Array[Vector2]) -> float:
	var length: = 0.0
	var previous: = points[0]
	for sample_index: int in range(1, LABEL_PATH_SAMPLES + 1):
		var current: = bezier_point(float(sample_index) / float(LABEL_PATH_SAMPLES), points[0], points[1], points[2], points[3])
		length += previous.distance_to(current)
		previous = current
	return length


func _draw_text_on_curve(text: String, points: Array[Vector2], font_size: float, canvas: CanvasItem = null) -> void :
	if canvas == null: canvas = self
	var path_length: = _bezier_path_length(points)
	if text.is_empty() or path_length <= 0.0:
		return
	var letter_spacing: = font_size * LABEL_SPACING_FACTOR
	var character_width: = font_size * 0.6
	var total_text_width: = float(text.length()) * (character_width + letter_spacing)
	var start_t: = 0.5 - (total_text_width / path_length) * 0.5
	var step_t: = (total_text_width / path_length) / float(text.length())
	var draw_font_size: = maxi(7, int(round(font_size)))
	var font: = _get_country_label_font()
	var outline_size: = maxi(2, int(round(font_size / 5.0)))
	for character_index: int in text.length():
		var t: = start_t + float(character_index) * step_t + step_t * 0.5
		if t < 0.0 or t > 1.0:
			continue
		var character: = text.substr(character_index, 1)
		var point: = bezier_point(t, points[0], points[1], points[2], points[3])
		var angle: = bezier_tangent_angle(t, points[0], points[1], points[2], points[3])
		var character_size: = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_font_size)
		var baseline: = Vector2( - character_size.x * 0.5, (font.get_ascent(draw_font_size) - font.get_descent(draw_font_size)) * 0.5)
		canvas.draw_set_transform(point, angle, Vector2.ONE)
		canvas.draw_string_outline(font, baseline, character, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_font_size, outline_size, Color(0.0, 0.0, 0.0, 0.8))
		canvas.draw_string(font, baseline, character, HORIZONTAL_ALIGNMENT_LEFT, -1, draw_font_size, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pan_by_screen_delta(delta: Vector2) -> void :
	var native_camera: = get_node_or_null("NativeCameraController") as MWCameraController
	if native_camera != null:
		native_camera.pan(delta)
		return
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	center_projected -= delta / _world_width()
	var geographic: = MWMapProjection.unproject(self, center_projected)
	center_longitude = MWWebMercator.wrap_longitude(geographic.x)
	center_latitude = geographic.y
	_constrain_vertical_center()
	if _zoom_elapsed < ZOOM_DURATION:

		_zoom_anchor = (_zoom_cursor - _world_origin()) / _world_width()
	queue_redraw()


func _build_country_label_font() -> Font:
	var variation: = FontVariation.new()
	variation.base_font = SOURCE_LABEL_FONT_BASE
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): 700
	}
	return variation


func _build_city_label_font() -> Font:
	var system_font: = SystemFont.new()
	system_font.font_names = PackedStringArray(["Consolas", "Courier New", "Liberation Mono", "monospace"])
	system_font.font_weight = 700
	return system_font


func _get_country_label_font() -> Font:
	if _country_label_font == null:
		_country_label_font = _build_country_label_font()
	return _country_label_font


func _get_city_label_font() -> Font:
	if _city_label_font == null:
		_city_label_font = _build_city_label_font()
	return _city_label_font


func _world_width() -> float:
	return TILE_SIZE * pow(2.0, zoom_level)


func _minimum_zoom() -> float:


	return MWModernMapSurface.minimum_cover_zoom(size) if MWMapProjection.view_profile(self) == MWMapProjection.EQUIRECTANGULAR else MIN_ZOOM


func _world_origin() -> Vector2:
	var center_projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	return size * 0.5 - center_projected * _world_width()


func _zoom_at(control_position: Vector2, amount: float) -> void :
	var native_camera: = get_node_or_null("NativeCameraController") as MWCameraController
	if native_camera != null:
		native_camera.zoom_at(control_position, amount)
		return
	var new_zoom: = clampf(target_zoom_level + amount, _minimum_zoom(), MAX_ZOOM)
	if terrain_layer != null:
		new_zoom = maxf(_minimum_zoom(), float(terrain_layer.call("practical_zoom", center_longitude, center_latitude, new_zoom, size)))
	if is_equal_approx(new_zoom, target_zoom_level):
		return
	_zoom_cursor = control_position
	_zoom_anchor = (control_position - _world_origin()) / _world_width()


	if terrain_layer != null:
		for iteration: int in range(3):
			var target_width: = TILE_SIZE * pow(2.0, new_zoom)
			var target_geo: = MWMapProjection.unproject(self, _zoom_anchor - (control_position - size * 0.5) / target_width)
			new_zoom = maxf(_minimum_zoom(), float(terrain_layer.call("practical_zoom", target_geo.x, target_geo.y, new_zoom, size)))
	_zoom_start = zoom_level
	target_zoom_level = new_zoom
	_zoom_elapsed = 0.0
	set_process(true)


func _process(delta: float) -> void :
	_advance_zoom(delta)


func _advance_zoom(delta: float) -> void :
	if _zoom_elapsed >= ZOOM_DURATION:
		return
	_zoom_elapsed = minf(ZOOM_DURATION, _zoom_elapsed + delta)
	var t: = _zoom_elapsed / ZOOM_DURATION

	zoom_level = lerpf(_zoom_start, target_zoom_level, 1.0 - pow(1.0 - t, 3.0))
	var projected_center: = _zoom_anchor - (_zoom_cursor - size * 0.5) / _world_width()
	var geo: = MWMapProjection.unproject(self, projected_center)
	center_longitude = MWWebMercator.wrap_longitude(geo.x)
	center_latitude = geo.y
	_constrain_vertical_center(false)
	if _zoom_elapsed >= ZOOM_DURATION:
		target_zoom_level = zoom_level
		set_process(false)
	queue_redraw()


func _constrain_vertical_center(enforce_quality: bool = true) -> void :
	zoom_level = maxf(_minimum_zoom(), zoom_level)
	if enforce_quality and terrain_layer != null:
		zoom_level = maxf(_minimum_zoom(), float(terrain_layer.call("practical_zoom", center_longitude, center_latitude, zoom_level, size)))
	var world_width: = _world_width()
	if world_width <= 0.0:
		return
	var extent: = MWMapProjection.normalized_height(self)
	var half_view: = minf(extent * 0.5, size.y * 0.5 / world_width)
	var projected: = MWMapProjection.project(self, center_longitude, center_latitude)
	projected.y = clampf(projected.y, half_view, extent - half_view)
	center_latitude = MWMapProjection.unproject(self, projected).y


func _on_resized() -> void :
	var native_camera: = get_node_or_null("NativeCameraController") as MWCameraController
	if native_camera != null:
		native_camera.resize()
		return
	_constrain_vertical_center()
	if _zoom_elapsed < ZOOM_DURATION:
		_zoom_anchor = (_zoom_cursor - _world_origin()) / _world_width()
	queue_redraw()


func _project_source_texture(source_texture: Texture2D) -> Texture2D:
	if source_texture == null or raster_size.x <= 0 or raster_size.y <= 0:
		return null
	var source_image: = source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	return ImageTexture.create_from_image(_project_source_image(source_image))


func _project_source_image(source_image: Image) -> Image:
	return MWMapProjection.project_source_image(self, source_image, raster_size)


func _build_alliance_texture() -> Texture2D:
	if not supports_alliance_view() or raster_size.x <= 0 or raster_size.y <= 0:
		return null
	var source_image: = Image.create(raster_size.x, raster_size.y, false, Image.FORMAT_RGBA8)
	source_image.fill(Color.TRANSPARENT)
	for flat_index: int in range(owner_ids.size()):
		var country_id: = owner_ids[flat_index]
		if country_id <= 0:
			continue
		var root_id: int = _alliance_root_by_country.get(country_id, country_id)
		var color: Color = _alliance_colors.get(root_id, _country_colors.get(root_id, _country_colors.get(country_id, Color("#969696"))))
		var pixel_y: = floori(float(flat_index) / float(raster_size.x))
		var pixel_x: = flat_index % raster_size.x
		source_image.set_pixel(pixel_x, pixel_y, color)
	return ImageTexture.create_from_image(_project_source_image(source_image))


func _build_alliance_components(countries: Array[CountryData]) -> void :
	_alliance_root_by_country.clear()
	var graph: Dictionary = {}
	var has_alliance_data: = false
	for country: CountryData in countries:
		graph[country.id] = []
	for country: CountryData in countries:
		for ally_id: int in country.allies:
			if not graph.has(ally_id) or ally_id == country.id:
				continue
			has_alliance_data = true
			(graph[country.id] as Array).append(ally_id)
			(graph[ally_id] as Array).append(country.id)
	if not has_alliance_data:
		return
	var visited: Dictionary = {}
	for country_id: Variant in graph:
		if visited.has(country_id):
			continue
		var component: Array[int] = []
		var stack: Array[int] = [int(country_id)]
		while not stack.is_empty():
			var current: int = stack.pop_back()
			if visited.has(current):
				continue
			visited[current] = true
			component.append(current)
			for neighbor: int in graph[current]:
				if not visited.has(neighbor):
					stack.append(neighbor)
		if component.size() <= 1:
			continue
		var root_id: int = component.min()
		for member_id: int in component:
			_alliance_root_by_country[member_id] = root_id


func _build_country_anchors() -> void :
	var computed: Dictionary = MWMapProjection.country_presentation(owner_ids, raster_size)
	if computed.is_empty():
		_build_country_anchors_reference()
		return
	_country_sample_indices = computed.samples
	_country_bounds = computed.bounds
	_label_geo_by_country = computed.centers
	_label_regions.assign(computed.regions)


func _build_country_anchors_reference() -> void :
	_country_sample_indices.clear()
	_country_bounds.clear()
	_label_geo_by_country.clear()
	_label_regions.clear()
	for flat_index: int in range(owner_ids.size()):
		var country_id: = owner_ids[flat_index]
		if country_id > 0 and not _country_sample_indices.has(country_id):
			_country_sample_indices[country_id] = flat_index



	_build_label_regions(1)
	for country_id: Variant in _country_sample_indices:
		var numeric_id: = int(country_id)
		if _country_bounds.has(numeric_id):
			continue
		var flat_index: int = _country_sample_indices[numeric_id]
		var pixel_y: = floori(float(flat_index) / float(raster_size.x))
		var pixel_x: = flat_index % raster_size.x
		_country_bounds[numeric_id] = Rect2i(pixel_x, pixel_y, 1, 1)
		_label_geo_by_country[numeric_id] = geographic_position_for_country(numeric_id)


func _build_label_regions(sampling_step: int) -> void :
	var sampled_width: = int(ceil(float(raster_size.x) / float(sampling_step)))
	var sampled_height: = int(ceil(float(raster_size.y) / float(sampling_step)))
	var visited: = PackedByteArray()
	visited.resize(sampled_width * sampled_height)
	var best_counts: Dictionary = {}
	for sampled_index: int in range(visited.size()):
		if visited[sampled_index] != 0:
			continue
		visited[sampled_index] = 1
		var sampled_y: = floori(float(sampled_index) / float(sampled_width))
		var sampled_x: = sampled_index % sampled_width
		var source_x: = mini(sampled_x * sampling_step, raster_size.x - 1)
		var source_y: = mini(sampled_y * sampling_step, raster_size.y - 1)
		var country_id: = owner_ids[source_y * raster_size.x + source_x]
		if country_id <= 0:
			continue
		var stack: Array[int] = [sampled_index]
		var component: = PackedInt32Array()
		var count: = 0
		var sum_x: = 0.0
		var sum_y: = 0.0
		var minimum_x: = sampled_x
		var maximum_x: = sampled_x
		var minimum_y: = sampled_y
		var maximum_y: = sampled_y
		while not stack.is_empty():
			var current: int = stack.pop_back()
			var current_y: = floori(float(current) / float(sampled_width))
			var current_x: = current % sampled_width
			component.append(current)
			count += 1
			sum_x += float(current_x * sampling_step) + float(sampling_step) * 0.5
			sum_y += float(current_y * sampling_step) + float(sampling_step) * 0.5
			minimum_x = mini(minimum_x, current_x)
			maximum_x = maxi(maximum_x, current_x)
			minimum_y = mini(minimum_y, current_y)
			maximum_y = maxi(maximum_y, current_y)
			var neighbors: = PackedInt32Array()
			if current_x > 0:
				neighbors.append(current - 1)
			if current_x + 1 < sampled_width:
				neighbors.append(current + 1)
			if current_y > 0:
				neighbors.append(current - sampled_width)
			if current_y + 1 < sampled_height:
				neighbors.append(current + sampled_width)
			for neighbor: int in neighbors:
				if visited[neighbor] != 0:
					continue
				var neighbor_y: = floori(float(neighbor) / float(sampled_width))
				var neighbor_x: = neighbor % sampled_width
				var neighbor_source_x: = mini(neighbor_x * sampling_step, raster_size.x - 1)
				var neighbor_source_y: = mini(neighbor_y * sampling_step, raster_size.y - 1)
				if owner_ids[neighbor_source_y * raster_size.x + neighbor_source_x] != country_id:
					continue
				visited[neighbor] = 1
				stack.append(neighbor)
		var pixel_minimum_x: = minimum_x * sampling_step
		var pixel_minimum_y: = minimum_y * sampling_step
		var pixel_maximum_x: = mini(raster_size.x, (maximum_x + 1) * sampling_step)
		var pixel_maximum_y: = mini(raster_size.y, (maximum_y + 1) * sampling_step)
		var bounds: = Rect2i(
			pixel_minimum_x, 
			pixel_minimum_y, 
			pixel_maximum_x - pixel_minimum_x, 
			pixel_maximum_y - pixel_minimum_y
		)
		var center_pixel: = Vector2(sum_x / float(count), sum_y / float(count))
		var center_geo: = Vector2(
			center_pixel.x / float(raster_size.x) * 360.0 - 180.0, 
			90.0 - center_pixel.y / float(raster_size.y) * 180.0
		)
		var bin_sum_x: = PackedFloat64Array()
		var bin_sum_y: = PackedFloat64Array()
		var bin_counts: = PackedInt32Array()
		bin_sum_x.resize(LABEL_REGION_BIN_COUNT)
		bin_sum_y.resize(LABEL_REGION_BIN_COUNT)
		bin_counts.resize(LABEL_REGION_BIN_COUNT)
		var component_width: = maxi(1, maximum_x - minimum_x + 1)
		for current: int in component:
			var current_y: = floori(float(current) / float(sampled_width))
			var current_x: = current % sampled_width
			var relative_x: = float(current_x - minimum_x) / float(component_width)
			var bin_index: = clampi(int(floor(relative_x * LABEL_REGION_BIN_COUNT)), 0, LABEL_REGION_BIN_COUNT - 1)
			bin_sum_x[bin_index] += float(current_x * sampling_step) + float(sampling_step) * 0.5
			bin_sum_y[bin_index] += float(current_y * sampling_step) + float(sampling_step) * 0.5
			bin_counts[bin_index] += 1
		var bin_pixels: Array[Vector2] = []
		for bin_index: int in LABEL_REGION_BIN_COUNT:
			if bin_counts[bin_index] > 0:
				bin_pixels.append(Vector2(bin_sum_x[bin_index] / float(bin_counts[bin_index]), bin_sum_y[bin_index] / float(bin_counts[bin_index])))
			else:
				bin_pixels.append(Vector2(INF, INF))
		for bin_index: int in LABEL_REGION_BIN_COUNT:
			if is_finite(bin_pixels[bin_index].x):
				continue
			var left: = bin_index - 1
			while left >= 0 and not is_finite(bin_pixels[left].x):
				left -= 1
			var right: = bin_index + 1
			while right < LABEL_REGION_BIN_COUNT and not is_finite(bin_pixels[right].x):
				right += 1
			if left >= 0 and right < LABEL_REGION_BIN_COUNT:
				bin_pixels[bin_index] = (bin_pixels[left] + bin_pixels[right]) * 0.5
			elif left >= 0:
				bin_pixels[bin_index] = bin_pixels[left]
			elif right < LABEL_REGION_BIN_COUNT:
				bin_pixels[bin_index] = bin_pixels[right]
			else:
				bin_pixels[bin_index] = center_pixel
		var bins: Array[Vector2] = []
		for bin_pixel: Vector2 in bin_pixels:
			bins.append(Vector2(
				bin_pixel.x / float(raster_size.x) * 360.0 - 180.0, 
				90.0 - bin_pixel.y / float(raster_size.y) * 180.0
			))
		_label_regions.append({
			"country_id": country_id, 
			"count": count, 
			"bounds": bounds, 
			"center_geo": center_geo, 
			"bins": bins, 
		})
		if count > int(best_counts.get(country_id, 0)):
			best_counts[country_id] = count
			_country_bounds[country_id] = bounds
			_label_geo_by_country[country_id] = center_geo

func sync_camera_revision() -> int:
	var key: = [_world_origin(), _world_width(), size]
	if key != _camera_revision_key:
		_camera_revision_key = key
		camera_revision += 1
	return camera_revision

func sync_render_revisions() -> void :
	var runtime: = war_runtime
	var key: = [sync_camera_revision(), texture, runtime, unit_view_mode, battle_visuals_visible, formation_debug_visible]
	if runtime != null:
		key.append_array([runtime.visual_revisions.unit_revision, runtime.visual_revisions.battle_revision, runtime.render_revision])
	if key != _dynamic_revision_key:
		_dynamic_revision_key = key
		queue_redraw()


func set_provinces_visible(enabled: bool) -> void :
	if terrain_layer != null and terrain_layer.has_method("set_provinces_enabled"):
		terrain_layer.call("set_provinces_enabled", enabled)
	queue_redraw()


func set_terrain_only_mode(enabled: bool) -> void :
	var political_node: = get_node_or_null("SourceGridPolitical") as SourceGridOverlay
	var borders_node: = get_node_or_null("SourceGridBorders") as SourceGridOverlay
	if political_node != null:
		political_node.visible = not enabled
		political_node.sync_view()
		political_node.queue_redraw()
	if borders_node != null:
		borders_node.visible = not enabled
		borders_node.sync_view()
		borders_node.queue_redraw()
	if terrain_layer != null and terrain_layer.has_method("set_political_overlay_enabled"):
		terrain_layer.call("set_political_overlay_enabled", not enabled)
	queue_redraw()
