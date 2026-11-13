extends Control



var kind: = "countries"
var _key: Array = []
var redraw_count: = 0

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = kind == "cities"
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void :
	sync_view()

func sync_view() -> void :
	var map_view: = get_parent() as CampaignMapView
	var r: = map_view.war_runtime
	var active: = r != null and r.has_active_war()
	var key: = [map_view.sync_camera_revision(), map_view.annotation_revision, map_view.texture]
	if kind == "countries":
		key.append_array([map_view.labels_visible, map_view._country_label_font])
	elif kind == "cities":
		key.append_array([map_view.cities_visible, map_view._city_label_font, r, active, hash(r.bases) if active else 0])
	else:
		key.append_array([map_view.planning_visible, r, active, map_view._country_label_font])
		if active and map_view.planning_visible:


			for commander: Dictionary in r.battle_planner.commander_groups.values():
				var operation: Dictionary = r.battle_planner.operations[int(commander.operation)]
				key.append([operation.id, operation.side, operation.phase, operation.posture_kind, operation.doctrine, operation.progress, commander.objective.duplicate(), r.country_color(int(commander.country)), CampaignMapView.planning_front_attachment(commander.anchor_geo, r.battle_planner._sector_candidates.get(int(commander.country), []))])
	if key == _key: return
	_key = key
	queue_redraw()

func _draw() -> void :
	var map_view: = get_parent() as CampaignMapView
	if map_view.texture == null: return
	var started: = Time.get_ticks_usec()
	var r: = map_view.war_runtime
	var active: = r != null and r.has_active_war()
	var viewport_rect: = Rect2(Vector2.ZERO, map_view.size).grow(12.0)
	if kind == "cities":
		if active: map_view._draw_war_bases(r, viewport_rect, self)
		map_view._draw_city_annotations(viewport_rect, self)
	elif kind == "countries":
		if map_view.labels_visible: map_view._draw_country_labels(viewport_rect, self)
	elif active and map_view.planning_visible:
		map_view._draw_battle_plans(r, viewport_rect, self)
	redraw_count += 1
	if r != null: r.record_render_profile(&"dynamic_overlay_redraw", Time.get_ticks_usec() - started, true)
