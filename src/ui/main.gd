class_name ModernWarsMain
extends Control

const OCEAN_COLOR: = Color("#071521")
const PANEL_COLOR: = Color("#101014")
const PANEL_BORDER: = Color(1, 1, 1, 0.08)
const SETUP_PANEL_COLOR: = Color(8.0 / 255.0, 8.0 / 255.0, 10.0 / 255.0, 0.78)
const SETUP_PANEL_BORDER: = Color(1.0, 1.0, 1.0, 0.07)
const ACCENT: = Color("#ff4757")
const TEXT_MUTED: = Color("#777777")
const SIDE_A_COLOR: = Color("#ff4757")
const SIDE_B_COLOR: = Color("#2e86de")
const SOURCE_RED: = Color("#ff4757")
const SOURCE_SERIF_BASE: FontFile = preload("res://assets/fonts/playfair-display/PlayfairDisplay-wght.ttf")
const SETUP_PANEL_RECT: = Rect2(18.0, 78.0, 371.0, 320.0)

var current_screen: String = ""
var is_loading: bool = false
var selected_entry: ScenarioCatalogEntry = null
var loaded_scenario: ScenarioData = null
var last_load_msec: int = 0
var conflict_setup_state: MWConflictSetupState = null

var _screen_root: Control
var _backdrop: TextureRect
var _start_button: Button
var _card_buttons: Dictionary = {}
var _preview_owner_ids: PackedInt32Array = PackedInt32Array()
var _prewar_owner_snapshot: PackedInt32Array = PackedInt32Array()
var _map_preview_control: CampaignMapView
var _readonly_inspector: MWReadonlyInspectorUI
var _side_a_button: Button
var _side_b_button: Button
var _side_a_list: MWConflictCountryCards
var _side_b_list: MWConflictCountryCards
var _remove_country_button: Button
var _launch_conflict_button: Button
var _selection_feedback: Label
var _labels_button: Button
var _cities_button: Button
var _battle_visuals_button: Button
var _unit_view_button: Button
var _planning_button: Button
var _playing_status: Label
var _setup_shell: PanelContainer
var _setup_sheet_ui: MWSetupSheetUI
var _setup_blur: ColorRect
var _setup_backdrop_copy: BackBufferCopy
var _war_runtime: ConflictRuntimeState
var _war_hud: Control
var _war_report_ui: MWWarReportUI
var _mobilization_overlay: Control
var _war_result_panel: PanelContainer
var _pause_button: Button
var _speed_down_button: Button
var _speed_display_button: Button
var _speed_up_button: Button
var _war_hud_accumulator: = 0.0
var _result_return_started: = false
var _hud_scale: = 1.0
var _hud_layout_signature: = ""


func _ready() -> void :
	var steam_platform: = get_node_or_null("SteamPlatform")
	if steam_platform != null and steam_platform.has_method("may_enter_game") and not steam_platform.call("may_enter_game"):
		steam_platform.connect("startup_authorized", _initialize_main, CONNECT_ONE_SHOT)
		return
	_initialize_main()


func _initialize_main() -> void :
	_build_background()
	_show_main_menu()
	if not has_node("PlayerStateUI"):
		var player_state_controller: = MWPlayerStateUI.new()
		player_state_controller.name = "PlayerStateUI"
		add_child(player_state_controller)
	_readonly_inspector = MWReadonlyInspectorUI.new()
	_readonly_inspector.name = "ReadonlyInspectorUI"
	add_child(_readonly_inspector)


func _process(delta: float) -> void :
	var runtime: = _war_runtime
	if runtime == null:
		return
	if runtime.speed_index > ConflictRuntimeState.MAX_PLAYABLE_SPEED_INDEX:
		if runtime.native_authoritative_active() and runtime._native_conflict_core.has_method("native_war_control"):
			runtime._native_conflict_core.native_war_control(runtime, "speed_set", ConflictRuntimeState.MAX_PLAYABLE_SPEED_INDEX, ConflictRuntimeState.MAX_PLAYABLE_SPEED_INDEX)
		else:
			runtime.speed_index = ConflictRuntimeState.MAX_PLAYABLE_SPEED_INDEX
	var effective_delta: = minf(delta, 1.0 / 30.0)
	var ticks: = runtime.advance(effective_delta)
	if _war_runtime != runtime:
		return
	MWNativeConflictController.sync_main_render_revisions(self, ticks)
	_war_hud_accumulator += delta
	if _war_hud_accumulator >= 0.1:
		_war_hud_accumulator = 0.0
		_refresh_war_hud()
	if runtime.state == ConflictRuntimeState.WarState.RESULT and _war_result_panel == null:
		_show_war_result()
	if runtime.should_return_to_setup() and not _result_return_started:
		_result_return_started = true
		_return_to_setup_after_result()


func _build_background() -> void :
	_backdrop = TextureRect.new()
	_backdrop.name = "SourceMenuBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture = load("res://assets/scenarios/previews/world_map_2022.png") as Texture2D
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	var overlay: = MenuDiagonalOverlay.new()
	overlay.name = "MainMenuDiagonalOverlay"
	overlay.set_anchor(SIDE_LEFT, 0.5)
	overlay.set_anchor(SIDE_TOP, 0.0)
	overlay.set_anchor(SIDE_RIGHT, 1.0)
	overlay.set_anchor(SIDE_BOTTOM, 1.0)
	add_child(overlay)

	_screen_root = Control.new()
	_screen_root.name = "ScreenRoot"
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_root)


func _clear_screen() -> void :
	if is_instance_valid(_readonly_inspector):
		_readonly_inspector.reset_interaction_mode()
	for child: Node in _screen_root.get_children():
		_screen_root.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	_start_button = null


func _show_main_menu() -> void :
	var session_player: = get_node_or_null("PlayerStateUI")
	if session_player != null and session_player.has_method("cancel_campaign_load"):
		session_player.call("cancel_campaign_load")
	is_loading = false
	var session_controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
	if session_controller != null and session_controller.has_method("request_session_transition") and bool(session_controller.call("request_session_transition", "menu")):
		return


	if _war_runtime != null and has_node("PlayerStateUI"):
		get_node("PlayerStateUI").autosave_now()
	_stop_war_runtime()
	_clear_screen()
	_backdrop.visible = true
	current_screen = "main_menu"
	selected_entry = null
	loaded_scenario = null
	conflict_setup_state = null
	_preview_owner_ids = PackedInt32Array()
	_prewar_owner_snapshot = PackedInt32Array()
	_backdrop.texture = load("res://assets/scenarios/previews/world_map_2022.png") as Texture2D
	_add_source_header()

	var rail: = _right_rail("MainMenuRightRail")
	_screen_root.add_child(rail)
	var nav: = VBoxContainer.new()
	nav.name = "MainMenuNavigation"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	rail.add_child(nav)

	var play: = _menu_link("PLAY    ▶", 48, SOURCE_RED)
	play.name = "PlayButton"
	play.custom_minimum_size = Vector2(470, 76)
	play.pressed.connect(_show_scenario_selector)
	nav.add_child(play)

	var load_file: = _menu_link("LOAD FILE", 17, Color(1, 1, 1, 0.92), true)
	load_file.name = "LoadFileButton"
	load_file.custom_minimum_size = Vector2(340, 48)
	load_file.disabled = true
	nav.add_child(load_file)

	var tools: = HBoxContainer.new()
	tools.name = "MainMenuTools"
	tools.alignment = BoxContainer.ALIGNMENT_END
	tools.add_theme_constant_override("separation", 10)
	nav.add_child(tools)
	for definition: Array in [["EditorButton", "EDITOR"], ["TutorialButton", "TUTORIAL"], ["SettingsButton", "SETTINGS"]]:
		var tool: = _menu_link(definition[1], 15, Color(1, 1, 1, 0.7), true)
		tool.name = definition[0]
		tool.disabled = true
		tool.custom_minimum_size = Vector2(145, 46)
		tools.add_child(tool)

	var footer_spacer: = Control.new()
	footer_spacer.custom_minimum_size = Vector2(0, 38)
	nav.add_child(footer_spacer)
	var footer_links: = HBoxContainer.new()
	footer_links.name = "MainMenuFooterLinks"
	footer_links.alignment = BoxContainer.ALIGNMENT_END
	footer_links.add_theme_constant_override("separation", 14)
	nav.add_child(footer_links)
	for definition: Array in [["SupportDevButton", "Support Dev"], ["CreditsButton", "Credits"]]:
		var footer_button: = _menu_link(definition[1], 12, Color(1, 1, 1, 0.5))
		footer_button.name = definition[0]
		footer_button.disabled = true
		footer_links.add_child(footer_button)
	var copyright: = _label("Decoded and rekt'ed by DecompStrak Team © 2026 man_82. All rights reserved. Please don't reupload, rehost, or redistribute this game on other sites.", 10, Color(1, 1, 1, 0.38), HORIZONTAL_ALIGNMENT_RIGHT)
	copyright.name = "MainMenuCopyright"
	copyright.custom_minimum_size = Vector2(470, 0)
	nav.add_child(copyright)


func _show_scenario_selector() -> void :
	var session_player: = get_node_or_null("PlayerStateUI")
	if session_player != null and session_player.has_method("cancel_campaign_load"):
		session_player.call("cancel_campaign_load")
	is_loading = false
	_clear_screen()
	_backdrop.visible = true
	current_screen = "scenario_selector"
	_backdrop.texture = load("res://assets/scenarios/previews/world_map_2022.png") as Texture2D
	_add_source_header()

	var rail: = _right_rail("ScenarioRightRail")
	_screen_root.add_child(rail)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail.add_child(center)
	var panel: = PanelContainer.new()
	panel.name = "ScenarioSelectorPanel"
	var viewport_size: = get_viewport_rect().size
	panel.custom_minimum_size = Vector2(viewport_size.x * 0.45 - 80.0, viewport_size.y * 0.8)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.05), 1, 2))
	center.add_child(panel)
	var panel_margin: = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 30)
	panel_margin.add_theme_constant_override("margin_right", 30)
	panel_margin.add_theme_constant_override("margin_top", 30)
	panel_margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(panel_margin)
	var content: = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel_margin.add_child(content)

	var header: = HBoxContainer.new()
	header.name = "ScenarioSelectorHeader"
	header.custom_minimum_size = Vector2(0, 55)
	header.add_theme_constant_override("separation", 15)
	content.add_child(header)
	var back: = _menu_link("‹  BACK", 12, Color("#666666"))
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(170, 48)
	back.pressed.connect(_show_main_menu)
	header.add_child(back)
	var title: = _source_label("CHOOSE ERA", 24, 700, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	title.name = "ScenarioSelectorTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(title)
	var separator: = HSeparator.new()
	separator.add_theme_color_override("separator", Color(1, 1, 1, 0.1))
	content.add_child(separator)

	var scroll: = ScrollContainer.new()
	scroll.name = "ScenarioSelector"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var sections: = VBoxContainer.new()
	sections.name = "ScenarioListColumn"
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 30)
	scroll.add_child(sections)

	var catalog: = MWScenarioCatalog.entries()
	var current_group: = ""
	var group_cards: VBoxContainer = null
	for entry: ScenarioCatalogEntry in catalog:
		if entry.group_name != current_group:
			current_group = entry.group_name
			var group: = VBoxContainer.new()
			group.name = "ScenarioGroup_%s" % current_group.validate_node_name()
			group.add_theme_constant_override("separation", 10)
			sections.add_child(group)
			var group_label: = _label(current_group, 10, Color("#555555"), HORIZONTAL_ALIGNMENT_LEFT)
			group_label.add_theme_font_override("font", _source_serif(900, 2))
			group.add_child(group_label)
			group_cards = VBoxContainer.new()
			group_cards.add_theme_constant_override("separation", 12)
			group.add_child(group_cards)
		var card: = _scenario_card(entry)
		group_cards.add_child(card)
		_card_buttons[entry.stable_id] = card

	_start_button = _button("START CAMPAIGN", 16)
	_start_button.name = "StartCampaignButton"
	_start_button.disabled = false
	_start_button.custom_minimum_size = Vector2(0, 54)
	_start_button.add_theme_stylebox_override("normal", _panel_style(Color("#b33939"), Color("#e55039"), 1, 0))
	_start_button.add_theme_stylebox_override("hover", _panel_style(Color("#d64541"), Color("#ff6b6b"), 1, 0))
	_start_button.pressed.connect(_on_start_campaign_pressed)
	content.add_child(_start_button)
	_select_scenario(catalog[0])


func _scenario_card(entry: ScenarioCatalogEntry) -> Button:
	var card: = _button("", 11)
	card.name = "ScenarioCard_%s" % entry.stable_id
	card.custom_minimum_size = Vector2(0, 106)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s — %s — MAP: %s" % [entry.card_title, entry.description, entry.map_credit]
	card.add_theme_stylebox_override("normal", _panel_style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05), 1, 1))
	card.add_theme_stylebox_override("hover", _panel_style(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.2), 1, 1))

	var margin: = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var copy: = VBoxContainer.new()
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(copy)
	var title: = _source_label(entry.card_title, 18, 700, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	title.name = "ScenarioCardTitle_%s" % entry.stable_id
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title)
	var description: = _label(entry.description, 11, Color("#888888"), HORIZONTAL_ALIGNMENT_LEFT)
	description.name = "ScenarioCardDescription_%s" % entry.stable_id
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(description)
	var credit: = _label("MAP: %s" % entry.map_credit, 9, Color("#444444"), HORIZONTAL_ALIGNMENT_LEFT)
	credit.name = "ScenarioCardCredit_%s" % entry.stable_id
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(credit)
	card.pressed.connect(_select_scenario.bind(entry))
	MWScenarioCatalog.apply_card_availability(card, entry)
	return card


func _select_scenario(entry: ScenarioCatalogEntry) -> void :
	if not MWScenarioCatalog.authorize_campaign(self, entry):
		return
	selected_entry = entry
	if _start_button:
		_start_button.disabled = false
		_start_button.text = "START CAMPAIGN"
	if _backdrop:
		_backdrop.texture = load(entry.preview_texture_path) as Texture2D
	for id: String in _card_buttons:
		var button: = _card_buttons[id] as Button
		if id == entry.stable_id:
			button.add_theme_stylebox_override("normal", _panel_style(Color(1.0, 0.278, 0.341, 0.15), SOURCE_RED, 1, 1))
		else:
			button.add_theme_stylebox_override("normal", _panel_style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.05), 1, 1))


func _on_start_campaign_pressed() -> void :
	if selected_entry == null or is_loading:
		return
	var session_controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
	if session_controller != null and session_controller.has_method("request_session_transition") and bool(session_controller.call("request_session_transition", "full_reload")):
		return
	if not MWScenarioCatalog.authorize_campaign(self, selected_entry):
		return
	var load_entry: = selected_entry
	var session_player: = get_node_or_null("PlayerStateUI")
	var load_ticket: = 0
	if session_player != null and session_player.has_method("begin_campaign_load"):
		load_ticket = int(session_player.call("begin_campaign_load"))
		if load_ticket == 0:
			return
	_stop_war_runtime()
	is_loading = true
	_show_loading(selected_entry)
	await get_tree().process_frame


	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if selected_entry != load_entry or current_screen != "loading" or not is_loading:
		return
	if load_ticket > 0 and ( not is_instance_valid(session_player) or not bool(session_player.call("campaign_load_current", load_ticket))):
		return
	var loader: = MWScenarioJsonLoader.new()
	var started: = Time.get_ticks_msec()
	var scenario: = loader.load_scenario(load_entry.source_path, load_entry.loaded_context)
	if selected_entry != load_entry or current_screen != "loading" or not is_loading:
		return
	if load_ticket > 0 and ( not is_instance_valid(session_player) or not bool(session_player.call("campaign_load_current", load_ticket))):
		return
	last_load_msec = Time.get_ticks_msec() - started
	if scenario == null:
		if load_ticket > 0 and is_instance_valid(session_player):
			session_player.call("finish_campaign_load", load_ticket)
		is_loading = false
		_show_load_error(loader.last_error)
		return
	loaded_scenario = scenario
	conflict_setup_state = MWConflictSetupState.new()
	_show_campaign(scenario, selected_entry)
	is_loading = false
	if load_ticket > 0 and is_instance_valid(session_player):
		session_player.call("finish_campaign_load", load_ticket)


func _show_loading(entry: ScenarioCatalogEntry) -> void :
	_clear_screen()
	current_screen = "loading"
	_backdrop.visible = true
	_add_source_header()
	var rail: = _right_rail("LoadingRightRail")
	_screen_root.add_child(rail)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail.add_child(center)
	var panel: = PanelContainer.new()
	panel.name = "LoadingPanel"
	panel.custom_minimum_size = Vector2(620, 430)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.52), Color(1, 1, 1, 0.06), 1, 1))
	center.add_child(panel)
	var margin: = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)
	var box: = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	box.add_child(_source_label("INITIALIZING", 18, 700, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 4))
	var separator: = HSeparator.new()
	separator.add_theme_color_override("separator", Color(1, 1, 1, 0.1))
	box.add_child(separator)
	var status_text: = "Loading Modern World Theater..." if entry.stable_id == "world_map_2022" else "Loading %s..." % entry.card_title
	var status: = _source_label(status_text, 32, 700, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	status.name = "LoadingStatus"
	box.add_child(status)
	var progress: = ProgressBar.new()
	progress.name = "LoadingProgress"
	progress.custom_minimum_size = Vector2(300, 4)
	progress.show_percentage = false
	progress.indeterminate = true
	progress.add_theme_stylebox_override("background", _panel_style(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 2))
	progress.add_theme_stylebox_override("fill", _panel_style(SOURCE_RED, Color.TRANSPARENT, 0, 2))
	box.add_child(progress)
	box.add_child(_label("Syncing satellite telemetry for global operations...", 11, Color("#666666"), HORIZONTAL_ALIGNMENT_RIGHT))


func _show_load_error(message: String) -> void :
	_clear_screen()
	current_screen = "load_error"
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_child(center)
	var box: = VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 0)
	center.add_child(box)
	box.add_child(_label("SCENARIO LOAD FAILED", 30, Color("#f06b6b"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label(message, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var back: = _button("BACK TO SCENARIOS", 18)
	back.pressed.connect(_show_scenario_selector)
	box.add_child(back)


func _show_campaign(scenario: ScenarioData, entry: ScenarioCatalogEntry) -> void :
	if not MWScenarioCatalog.authorize_scenario(self, entry, scenario):
		return
	_clear_screen()
	current_screen = "campaign_setup"
	_backdrop.visible = false
	_prewar_owner_snapshot = PackedInt32Array()

	var preview: = CampaignMapView.new()
	preview.name = "MapPreview"
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_STOP


	var native_presentation: = not (OS.is_debug_build() and has_meta(&"verification_native_war") and not bool(get_meta(&"verification_native_war")))
	if not MWMapProjection.prepare_playable_view(preview, native_presentation):
		preview.free()
		_show_load_error("Native map presentation could not be prepared.")
		return
	preview.configure(_build_map_preview(scenario), _preview_owner_ids, Vector2i(scenario.grid_width(), scenario.grid_height()), scenario.countries, scenario.cities)
	preview.map_clicked.connect(_on_map_clicked)
	preview.country_clicked.connect(_assign_country_id)
	_map_preview_control = preview
	_screen_root.add_child(preview)
	if is_instance_valid(_readonly_inspector):
		_readonly_inspector.set_country_names(preview.country_names)
	_add_setup_backdrop_blur()
	_setup_backdrop_copy = _screen_root.get_node_or_null("ConflictSetupBackdropCopy") as BackBufferCopy
	_setup_blur = _screen_root.get_node_or_null("ConflictSetupBackdropBlur") as ColorRect
	_build_campaign_status_bar(entry)

	var setup: = PanelContainer.new()
	setup.name = "ConflictSetupShell"
	setup.set_anchor(SIDE_LEFT, 0.0)
	setup.set_anchor(SIDE_TOP, 0.0)
	setup.offset_left = 18
	setup.offset_top = 78
	setup.offset_right = 389
	setup.offset_bottom = 398
	setup.add_theme_stylebox_override("panel", _setup_panel_style())
	_screen_root.add_child(setup)
	_setup_shell = setup
	var setup_margin: = MarginContainer.new()
	setup_margin.add_theme_constant_override("margin_left", 0)
	setup_margin.add_theme_constant_override("margin_right", 0)
	setup_margin.add_theme_constant_override("margin_top", 0)
	setup_margin.add_theme_constant_override("margin_bottom", 0)
	setup.add_child(setup_margin)
	var setup_scroll: = ScrollContainer.new()
	setup_scroll.name = "SetupScroll"
	setup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	setup_margin.add_child(setup_scroll)
	var setup_box: = VBoxContainer.new()
	setup_box.add_theme_constant_override("separation", 10)
	setup_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_scroll.add_child(setup_box)
	var setup_eyebrow: = _label("MODERN WARS", 11, Color("#b6b6b6"), HORIZONTAL_ALIGNMENT_LEFT)
	setup_eyebrow.name = "SetupEyebrow"
	setup_box.add_child(setup_eyebrow)
	var setup_header: = HBoxContainer.new()
	setup_header.add_theme_constant_override("separation", 8)
	setup_box.add_child(setup_header)
	var setup_title: = _label("CONFLICT\nSETUP", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	setup_title.name = "SetupTitle"
	setup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_header.add_child(setup_title)
	var random_war: = _hud_button("RANDOM WAR: OFF", Color("#9b59b6"), true)
	random_war.name = "RandomWarButton"
	random_war.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	random_war.tooltip_text = "Source control; AI-driven random wars are outside this parity pass."
	setup_header.add_child(random_war)
	var minimize: = _hud_button("−", Color("#555555"))
	minimize.name = "SetupMinimizeButton"
	minimize.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	setup_header.add_child(minimize)

	var sides: = HBoxContainer.new()
	sides.name = "SidesContainer"
	sides.add_theme_constant_override("separation", 8)
	setup_box.add_child(sides)
	sides.add_child(_build_side_shell("SIDE A", MWConflictSetupState.SIDE_A))
	var versus: = _source_label("VS", 17, 900, Color("#444444"), HORIZONTAL_ALIGNMENT_CENTER)
	versus.custom_minimum_size = Vector2(28, 0)
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sides.add_child(versus)
	sides.add_child(_build_side_shell("SIDE B", MWConflictSetupState.SIDE_B))

	_selection_feedback = _label("Select a side, then click countries on the map to recruit them.", 11, Color("#777777"), HORIZONTAL_ALIGNMENT_CENTER)
	_selection_feedback.name = "SelectionFeedback"
	_selection_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_box.add_child(_selection_feedback)

	_remove_country_button = _hud_button("REMOVE SELECTED", Color("#555555"))
	_remove_country_button.name = "RemoveCountryButton"
	_remove_country_button.pressed.connect(_remove_selected_country)
	setup_box.add_child(_remove_country_button)
	var reset_picks: = _hud_button("RESET PICKS", Color("#555555"))
	reset_picks.name = "ResetPicksButton"
	reset_picks.pressed.connect( func() -> void :
		conflict_setup_state.reset()
		_refresh_conflict_setup()
	)
	var setup_actions: = HBoxContainer.new()
	setup_actions.name = "SetupActions"
	setup_actions.add_theme_constant_override("separation", 8)
	setup_box.add_child(setup_actions)
	reset_picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_actions.add_child(reset_picks)
	var advanced: = _hud_button("ADVANCED SETTINGS ▸", Color("#555555"))
	advanced.name = "AdvancedSetupButton"
	advanced.toggle_mode = true
	advanced.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_actions.add_child(advanced)
	var options: = MWConflictSetupOptions.new()
	options.name = "ConflictSetupOptions"
	options.configure(conflict_setup_state)
	options.visible = false
	setup_box.add_child(options)
	advanced.toggled.connect( func(open: bool) -> void :
		options.visible = open
		advanced.text = "ADVANCED SETTINGS ▾" if open else "ADVANCED SETTINGS ▸"
		_sync_setup_blur()
		_resize_setup_to_content.call_deferred()
	)
	setup.resized.connect(_sync_setup_blur)

	_launch_conflict_button = _hud_button("INAUGURATE CONFLICT", Color("#286b49"))
	var launch_disabled_style: = _launch_conflict_button.get_theme_stylebox("disabled") as StyleBoxFlat
	launch_disabled_style.bg_color = Color("#296b47").darkened(0.45)
	_launch_conflict_button.add_theme_font_size_override("font_size", 13)
	_launch_conflict_button.name = "LaunchConflictButton"
	_launch_conflict_button.disabled = true
	_launch_conflict_button.custom_minimum_size = Vector2(0, 44)
	_launch_conflict_button.pressed.connect(_launch_conflict)
	setup_box.add_child(_launch_conflict_button)
	minimize.pressed.connect( func() -> void :
		sides.visible = not sides.visible
		_selection_feedback.visible = sides.visible
		_remove_country_button.visible = sides.visible and conflict_setup_state.side_count(conflict_setup_state.active_side) > 0
		_launch_conflict_button.visible = sides.visible
		minimize.text = "−" if sides.visible else "+"
	)
	_setup_sheet_ui = MWSetupSheetUI.new()
	_setup_sheet_ui.name = "SetupSheetUI"
	setup.add_child(_setup_sheet_ui)
	_setup_sheet_ui.attach(setup, setup_box, conflict_setup_state, advanced, options, reset_picks, _launch_conflict_button)
	_setup_sheet_ui.geometry_changed.connect(_sync_setup_blur)
	_setup_sheet_ui.scenario_requested.connect(_show_scenario_selector)
	_setup_sheet_ui.reset_requested.connect(_reset_campaign_setup)
	_setup_sheet_ui.launch_requested.connect(_launch_conflict)
	_setup_sheet_ui.side_auto_selected.connect(_refresh_conflict_setup.bind(false))
	_refresh_conflict_setup()
	setup.size.y = minf(570.0, get_viewport_rect().size.y - 180.0)
	_sync_setup_blur()


func _sync_setup_blur() -> void :
	if not is_instance_valid(_setup_shell) or not is_instance_valid(_setup_blur):
		return
	_setup_blur.position = _setup_shell.position
	_setup_blur.size = _setup_shell.size
	_setup_backdrop_copy.rect = _setup_shell.get_rect().grow(8.0)


func _build_campaign_status_bar(entry: ScenarioCatalogEntry) -> void :
	var bar: = PanelContainer.new()
	bar.name = "GameStatusBar"
	bar.set_anchor(SIDE_LEFT, 0.0)
	bar.set_anchor(SIDE_TOP, 0.0)
	bar.set_anchor(SIDE_RIGHT, 1.0)
	bar.offset_left = 16
	bar.offset_top = 0
	bar.offset_right = -16
	bar.offset_bottom = 64
	var toolbar_surface: = _panel_style(Color("#0c1511"), PANEL_BORDER, 1, 3)
	toolbar_surface.content_margin_top = 8
	toolbar_surface.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", toolbar_surface)
	_screen_root.add_child(bar)
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var status: = _label("PLAYING: %s" % entry.loaded_context, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	status.name = "PlayingStatus"
	status.custom_minimum_size = Vector2(205, 0)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status)
	_playing_status = status
	var minimize: = _hud_button("−", Color("#555555"))
	minimize.name = "StatusMinimizeButton"
	minimize.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(minimize)
	var controls: = HBoxContainer.new()
	controls.name = "GameStatusControls"
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls.add_theme_constant_override("separation", 6)
	var toolbar_scroll: = ScrollContainer.new()
	toolbar_scroll.name = "ToolbarScroll"
	toolbar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	toolbar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(toolbar_scroll)
	toolbar_scroll.add_child(controls)
	var political: = _hud_button("POLITICAL", Color("#3498db"))
	political.name = "PoliticalViewButton"
	political.tooltip_text = "Switch between political colors and locally cached flags. Missing images use country colors."
	controls.add_child(political)
	var alliance: = _toggle_hud_button("ALLIANCE", Color("#8e44ad"), false)
	alliance.name = "AllianceViewButton"
	alliance.disabled = not _map_preview_control.supports_alliance_view()
	alliance.tooltip_text = (
		"Group connected allies by their source-data alliance color."
		if not alliance.disabled
		else "This scenario has no explicit alliance relationships to render."
	)
	controls.add_child(alliance)
	political.pressed.connect( func() -> void :
		var next_flag: = _map_preview_control.view_mode != CampaignMapView.ViewMode.FLAG and _map_preview_control.view_mode != CampaignMapView.ViewMode.ALLIANCE_FLAG
		var next_mode: = CampaignMapView.ViewMode.ALLIANCE_FLAG if alliance.button_pressed else CampaignMapView.ViewMode.FLAG
		if not next_flag:
			next_mode = CampaignMapView.ViewMode.ALLIANCE if alliance.button_pressed else CampaignMapView.ViewMode.POLITICAL
		if _map_preview_control.set_view_mode(next_mode):
			political.text = "FLAG VIEW" if next_flag else "POLITICAL"
			_layout_compact_toolbar.call_deferred(bar, controls)
	)
	alliance.toggled.connect( func(enabled: bool) -> void :
		var flag_view: = _map_preview_control.view_mode == CampaignMapView.ViewMode.FLAG or _map_preview_control.view_mode == CampaignMapView.ViewMode.ALLIANCE_FLAG
		if enabled:
			if not _map_preview_control.set_view_mode(CampaignMapView.ViewMode.ALLIANCE_FLAG if flag_view else CampaignMapView.ViewMode.ALLIANCE):
				alliance.set_pressed_no_signal(false)
		else:
			_map_preview_control.set_view_mode(CampaignMapView.ViewMode.FLAG if flag_view else CampaignMapView.ViewMode.POLITICAL)
	)
	var battle: = _toggle_hud_button("BATTLE VISUALS", Color("#286b49"), false)
	battle.name = "BattleVisualsButton"
	battle.tooltip_text = "Show source battle indicators once a war exists; none are drawn during setup."
	battle.toggled.connect( func(enabled: bool) -> void : _map_preview_control.set_battle_visuals_visible(enabled))
	controls.add_child(battle)
	_battle_visuals_button = battle

	_unit_view_button = _hud_button("UNIT VIEW: SINGLE", Color("#222a27"))
	_unit_view_button.name = "UnitViewButton"
	_unit_view_button.visible = false
	_unit_view_button.tooltip_text = "Cycle FLAGS / NATO-style battalion symbols."

	controls.add_child(_unit_view_button)
	_planning_button = _toggle_hud_button("PLANNING", Color("#296b47"), false)
	_planning_button.name = "PlanningButton"
	_planning_button.visible = false
	_planning_button.tooltip_text = "Render current AI plans. Does not affect simulation or RNG."
	_planning_button.toggled.connect( func(enabled: bool) -> void : _map_preview_control.set_planning_visible(enabled))
	controls.add_child(_planning_button)
	_labels_button = _toggle_hud_button("LABELS", Color("#296b47"), true)
	_labels_button.name = "LabelsToggleButton"
	_labels_button.toggled.connect( func(enabled: bool) -> void : _map_preview_control.set_labels_visible(enabled))
	controls.add_child(_labels_button)
	_cities_button = _toggle_hud_button("CITIES", Color("#296b47"), true)
	_cities_button.name = "CitiesToggleButton"
	_cities_button.toggled.connect( func(enabled: bool) -> void : _map_preview_control.set_cities_visible(enabled))
	controls.add_child(_cities_button)
	var god: = _hud_button(_readonly_inspector.get_god_button_label(), Color("#d35400"))
	god.name = "GodModeButton"
	god.tooltip_text = "Select countries on the map in God Mode."
	god.pressed.connect(_toggle_god_mode.bind(god, bar, controls))
	controls.add_child(god)

	_pause_button = _hud_button("PAUSE", Color("#212926"))
	_pause_button.name = "PauseButton"
	_pause_button.tooltip_text = "Pause or resume the running source simulation."
	_pause_button.visible = false
	_pause_button.pressed.connect(_toggle_war_pause)
	controls.add_child(_pause_button)
	_speed_down_button = _hud_button("−", Color("#555555"))
	_speed_down_button.name = "SpeedDecreaseButton"
	_speed_down_button.visible = false
	_speed_down_button.pressed.connect(_decrease_war_speed)
	controls.add_child(_speed_down_button)
	_speed_display_button = _hud_button("0.5x", Color("#34495e"))
	_speed_display_button.name = "SpeedDisplayButton"
	_speed_display_button.visible = false
	_speed_display_button.tooltip_text = "Click to cycle source speed steps."
	_speed_display_button.pressed.connect(_cycle_war_speed)
	controls.add_child(_speed_display_button)
	_speed_up_button = _hud_button("+", Color("#555555"))
	_speed_up_button.name = "SpeedIncreaseButton"
	_speed_up_button.visible = false
	_speed_up_button.pressed.connect(_increase_war_speed)
	controls.add_child(_speed_up_button)
	var quick_restart: = _hud_button("QUICK RESTART", Color("#e67e22"))
	quick_restart.name = "QuickRestartButton"
	quick_restart.tooltip_text = "Clear the current picks without reloading the scenario."
	quick_restart.pressed.connect(_quick_restart_action)
	controls.add_child(quick_restart)
	var full_reload: = _hud_button("FULL RELOAD", Color("#c0392b"))
	full_reload.name = "FullReloadButton"
	full_reload.tooltip_text = "Reload the scenario from its immutable source JSON."
	full_reload.pressed.connect(_reload_current_scenario)
	controls.add_child(full_reload)
	var reset: = _hud_button("RESET", Color("#444444"))
	reset.name = "ResetButton"
	reset.disabled = true
	reset.tooltip_text = "Unavailable until its source full-reload semantics are exposed separately."
	controls.add_child(reset)
	var menu: = _hud_button("⌂ MENU", SOURCE_RED)
	menu.name = "MenuButton"
	menu.pressed.connect(_show_main_menu)
	controls.add_child(menu)
	for definition: Array in [["RankButton", "RANK"], ["LogButton", "LOG"], ["MuteButton", "🔊"], ["IngameSettingsButton", "⚙"]]:
		var unavailable: = _hud_button(definition[1], Color("#555555"), true)
		unavailable.name = definition[0]
		unavailable.tooltip_text = "Source control; its supporting system is outside this parity pass."
		controls.add_child(unavailable)
	_size_reference_toolbar_button(minimize)
	for toolbar_button: Button in controls.get_children():
		_size_reference_toolbar_button(toolbar_button)
	minimize.pressed.connect( func() -> void :
		controls.visible = not controls.visible
		minimize.text = "−" if controls.visible else "+"
		_layout_compact_toolbar.call_deferred(bar, controls)
	)
	bar.resized.connect( func() -> void : _layout_compact_toolbar(bar, controls))
	controls.minimum_size_changed.connect( func() -> void : _layout_compact_toolbar.call_deferred(bar, controls))
	get_viewport().size_changed.connect( func() -> void :
		if is_instance_valid(bar):
			_layout_compact_toolbar(bar, controls)
	)
	var compact_toolbar: = MWCompactToolbar.new()
	compact_toolbar.name = "CompactToolbar"
	bar.add_child(compact_toolbar)
	compact_toolbar.attach(bar, controls)
	_layout_compact_toolbar.call_deferred(bar, controls)


func _layout_compact_toolbar(bar_reference: Variant, controls_reference: Variant) -> void :
	if not is_instance_valid(bar_reference) or not is_instance_valid(controls_reference):
		return
	var bar: = bar_reference as PanelContainer
	var controls: = controls_reference as HBoxContainer
	var viewport_size: = get_viewport_rect().size
	var signature: = str(viewport_size)
	for button: Button in controls.get_children():
		signature += str(button.visible) + button.text
	signature += str(is_instance_valid(_setup_shell)) + str(is_instance_valid(_war_hud))
	if signature == _hud_layout_signature:
		return
	_hud_layout_signature = signature


	_hud_scale = clampf(minf(viewport_size.x / 1599.0, viewport_size.y / 877.0), 1.0, 1.6)
	var factor: = _hud_scale
	var side_padding: = 8.0 if is_instance_valid(_planning_button) and _planning_button.visible else 10.0
	var row: = controls.get_parent().get_parent() as HBoxContainer
	var minimize: = row.get_node("StatusMinimizeButton") as Button
	var visible_buttons: Array[Button] = [minimize]
	for button: Button in controls.get_children():
		if button.visible:
			visible_buttons.append(button)
	bar.offset_left = roundf(16.0 * _hud_scale)
	bar.offset_top = 0.0
	bar.set_anchor(SIDE_RIGHT, 1.0)
	bar.offset_right = - roundf(16.0 * _hud_scale)
	bar.offset_bottom = roundf(60 * _hud_scale) if _hud_scale > 1.0 else 64.0
	var surface: = bar.get_theme_stylebox("panel") as StyleBoxFlat
	surface.content_margin_left = roundf(10 * _hud_scale)
	surface.content_margin_right = roundf(10 * _hud_scale)
	surface.content_margin_top = roundf(5 * _hud_scale)
	surface.content_margin_bottom = roundf(5 * _hud_scale)
	row.add_theme_constant_override("separation", roundi(8 * factor))
	controls.add_theme_constant_override("separation", roundi(6 * factor))
	controls.size_flags_horizontal = Control.SIZE_FILL
	_playing_status.custom_minimum_size.x = roundf(175 * factor)
	_playing_status.add_theme_font_size_override("font_size", roundi(16 * factor))
	_playing_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Button in visible_buttons:
		button.custom_minimum_size = Vector2(0, roundf(49 * factor))
		button.add_theme_font_size_override("font_size", roundi(11 * factor))
		button.size_flags_horizontal = Control.SIZE_FILL
		for state_name: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			if button.has_theme_stylebox_override(state_name):
				var style: = button.get_theme_stylebox(state_name) as StyleBoxFlat
				style.content_margin_left = roundf(side_padding * factor)
				style.content_margin_right = roundf(side_padding * factor)
				style.content_margin_top = roundf(7 * factor)
				style.content_margin_bottom = roundf(7 * factor)


	var natural_width: float = controls.get_combined_minimum_size().x + _playing_status.custom_minimum_size.x + minimize.get_combined_minimum_size().x + surface.content_margin_left + surface.content_margin_right + 2.0 * row.get_theme_constant("separation")


	var available_width: = viewport_size.x - bar.offset_left - 16.0
	if viewport_size.x >= 2000.0 and natural_width > available_width:
		var reduction: = minf(5.0 * factor, (natural_width - available_width + 4.0) / (2.0 * visible_buttons.size()))
		for button: Button in visible_buttons:
			for state_name: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
				if button.has_theme_stylebox_override(state_name):
					var style: = button.get_theme_stylebox(state_name) as StyleBoxFlat
					style.content_margin_left = roundf(side_padding * factor - reduction)
					style.content_margin_right = roundf(side_padding * factor - reduction)
		natural_width -= 2.0 * reduction * visible_buttons.size()
	bar.set_anchor(SIDE_RIGHT, 0.0)
	bar.offset_right = minf(viewport_size.x - 16.0, bar.offset_left + natural_width)
	if is_instance_valid(_setup_shell):
		_scale_hud_subtree(_setup_shell, _hud_scale)
		_setup_shell.position = Vector2(roundf(18 * _hud_scale), bar.offset_bottom + roundf(14 * _hud_scale))
		_resize_setup_to_content.call_deferred()
		if is_instance_valid(_setup_sheet_ui):
			_setup_sheet_ui.refresh_layout()
		_sync_setup_blur()
	if is_instance_valid(_war_hud):
		_war_report_ui.set_toolbar_bottom(bar.offset_bottom)
	var compact_toolbar: = bar.get_node_or_null("CompactToolbar") as MWCompactToolbar
	if compact_toolbar != null:
		compact_toolbar.refresh()


func _scale_hud_subtree(node: Node, factor: float) -> void :
	MWSetupSheetUI.scale_hud_subtree(node, factor)


func _resize_setup_to_content() -> void :
	if not is_instance_valid(_setup_shell):
		return
	if is_instance_valid(_setup_sheet_ui):
		_setup_sheet_ui.refresh_layout()
		_sync_setup_blur()


func _build_side_shell(title: String, side: int) -> PanelContainer:
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(147, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side_surface: = _panel_style(Color("#231516") if side == MWConflictSetupState.SIDE_A else Color("#15202b"), Color(1, 1, 1, 0.1), 1, 3)
	side_surface.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", side_surface)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var selector: = _button(title, 11)
	selector.name = "SideAButton" if side == MWConflictSetupState.SIDE_A else "SideBButton"
	selector.custom_minimum_size = Vector2(0, 32)
	selector.pressed.connect(_select_side.bind(side))
	box.add_child(selector)
	var list: = MWConflictCountryCards.new()
	list.name = "SideAList" if side == MWConflictSetupState.SIDE_A else "SideBList"
	list.custom_minimum_size = Vector2.ZERO
	list.country_removed.connect( func(country_id: int) -> void :
		conflict_setup_state.remove_country(country_id)
		_refresh_conflict_setup()
	)
	box.add_child(list)
	if side == MWConflictSetupState.SIDE_A:
		_side_a_button = selector
		_side_a_list = list
	else:
		_side_b_button = selector
		_side_b_list = list
	return panel


func _select_side(side: int) -> void :
	conflict_setup_state.set_active_side(side)
	_refresh_conflict_setup()


func _assign_country_id(country_id: int) -> void :
	if not is_instance_valid(_readonly_inspector) or not _readonly_inspector.should_assign_country(country_id, _war_runtime):
		return
	var country: = _country_by_id(country_id)
	if country == null:
		_selection_feedback.text = "No selectable country at that map position."
		return
	conflict_setup_state.assign_country(country_id)
	_selection_feedback.text = "%s ADDED TO SIDE %s" % [country.country_name.to_upper(), "A" if conflict_setup_state.active_side == MWConflictSetupState.SIDE_A else "B"]
	_refresh_conflict_setup(false)


func _on_map_clicked(control_position: Vector2) -> void :
	if not is_instance_valid(_readonly_inspector) or loaded_scenario == null or _map_preview_control == null:
		return
	_readonly_inspector.route_map_click(_map_preview_control, loaded_scenario.cities, loaded_scenario.countries, control_position, _war_runtime, conflict_setup_state)
	if _readonly_inspector.is_god_mode_active():
		_restore_setup_status()


func _toggle_god_mode(button: Button, bar: PanelContainer, controls: HBoxContainer) -> void :
	var active: = _readonly_inspector.toggle_god_mode()
	button.text = _readonly_inspector.get_god_button_label()
	var color: = Color("#27ae60") if active else Color("#d35400")
	(button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = color
	(button.get_theme_stylebox("hover") as StyleBoxFlat).bg_color = color.lightened(0.1)
	(button.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color = color.darkened(0.12)
	_set_setup_visible(_readonly_inspector.should_show_setup(current_screen == "campaign_setup"))
	_restore_setup_status()
	_layout_compact_toolbar.call_deferred(bar, controls)


func _remove_selected_country() -> void :
	var list: = _side_a_list if conflict_setup_state.active_side == MWConflictSetupState.SIDE_A else _side_b_list
	if list.selected_country_id < 0:
		_selection_feedback.text = "Select a country in the active side to remove it."
		return
	var country_id: = list.selected_country_id
	var country: = _country_by_id(country_id)
	conflict_setup_state.remove_country(country_id)
	_selection_feedback.text = "%s REMOVED" % (country.country_name.to_upper() if country != null else "COUNTRY")
	_refresh_conflict_setup(false)


func _quick_restart_setup() -> void :
	if not MWScenarioCatalog.authorize_campaign(self, selected_entry):
		return
	if conflict_setup_state == null:
		return
	_restore_setup_status()
	if not _prewar_owner_snapshot.is_empty() and _map_preview_control != null:
		_preview_owner_ids = _prewar_owner_snapshot.duplicate()
		_map_preview_control.replace_world_owners(_preview_owner_ids)
		_prewar_owner_snapshot = PackedInt32Array()
	conflict_setup_state.reset()
	_selection_feedback.text = "Conflict picks cleared without reloading the scenario."
	_refresh_conflict_setup(false)


func _quick_restart_action() -> void :
	var session_controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
	if session_controller != null and session_controller.has_method("request_session_transition") and bool(session_controller.call("request_session_transition", "quick_restart")):
		return
	if not MWScenarioCatalog.authorize_campaign(self, selected_entry):
		return
	if _war_runtime == null or not _war_runtime.has_active_war():
		_quick_restart_setup()
		return
	var runtime_to_restart: = _war_runtime
	_war_runtime = null
	_preview_owner_ids = runtime_to_restart.quick_restart()
	_prewar_owner_snapshot = PackedInt32Array()
	_map_preview_control.clear_war_runtime()
	_clear_war_hud()
	_set_war_controls_visible(false)
	current_screen = "campaign_setup"
	_set_setup_visible(_readonly_inspector.should_show_setup(true))
	_restore_setup_status()
	conflict_setup_state.reset()
	_selection_feedback.text = "Pre-war geography restored without reloading the scenario."
	_refresh_conflict_setup(false)


func _reset_campaign_setup() -> void :
	if conflict_setup_state == null:
		return
	conflict_setup_state.reset()
	if _map_preview_control != null:
		_map_preview_control.reset_view()
	_selection_feedback.text = "Conflict setup and map view reset."
	_refresh_conflict_setup(false)


func _reload_current_scenario() -> void :
	var session_controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
	if session_controller != null and session_controller.has_method("request_session_transition") and bool(session_controller.call("request_session_transition", "full_reload")):
		return
	if selected_entry == null or is_loading:
		return
	if not MWScenarioCatalog.authorize_campaign(self, selected_entry):
		return
	_stop_war_runtime()
	_on_start_campaign_pressed()


func _refresh_conflict_setup(reset_feedback: bool = true) -> void :


	if is_instance_valid(_setup_sheet_ui):
		_setup_sheet_ui.refresh_main(reset_feedback)


func _country_by_id(country_id: int) -> CountryData:
	if loaded_scenario == null:
		return null
	for country: CountryData in loaded_scenario.countries:
		if country.id == country_id:
			return country
	return null


func preview_click_position_for_country(country_id: int) -> Vector2:
	if _map_preview_control == null:
		return Vector2(-1, -1)
	return _map_preview_control.control_position_for_country(country_id)


func _launch_conflict() -> void :


	var frozen_reference: = OS.is_debug_build() and has_meta(&"verification_native_war") and not bool(get_meta(&"verification_native_war"))
	if not frozen_reference and conflict_setup_state != null and (conflict_setup_state.get_prompt05_rules() or conflict_setup_state.get_side_total() > 2):
		var controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
		if controller == null:
			push_error("Native conflict initializer unavailable")
			return
		controller.request_launch()
		return
	if not MWScenarioCatalog.authorize_campaign(self, selected_entry):
		return
	if conflict_setup_state == null or not conflict_setup_state.can_launch():
		return
	current_screen = "war_mobilizing"
	if is_instance_valid(_playing_status):
		_playing_status.text = "PLAYING: %s" % selected_entry.loaded_context
	_prewar_owner_snapshot = _preview_owner_ids.duplicate()
	_set_setup_visible(false)
	_show_mobilization_overlay()
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	_war_runtime = ConflictRuntimeState.new()


	var verification_seed: = int(get_meta(&"verification_launch_seed", 0)) if OS.is_debug_build() else 0



	_war_runtime.native_authoritative_enabled = true
	if OS.is_debug_build() and has_meta(&"verification_native_war"):
		_war_runtime.native_authoritative_enabled = bool(get_meta(&"verification_native_war"))
	_war_runtime.performance_profile_enabled = OS.is_debug_build() and bool(get_meta(&"verification_profile", false))
	_war_runtime.verification_input_trace_enabled = _war_runtime.performance_profile_enabled
	if not _war_runtime.launch(loaded_scenario, conflict_setup_state, _preview_owner_ids, verification_seed):
		_war_runtime = null
		_hide_mobilization_overlay()
		current_screen = "campaign_setup"
		_set_setup_visible(_readonly_inspector.should_show_setup(true))
		_selection_feedback.text = "Unable to initialize the selected land theater."
		return
	_map_preview_control.set_view_mode(CampaignMapView.ViewMode.POLITICAL)
	var view_button: = _screen_root.find_child("PoliticalViewButton", true, false) as Button
	if view_button != null:
		view_button.text = "POLITICAL"
	var alliance_button: = _screen_root.find_child("AllianceViewButton", true, false) as BaseButton
	if alliance_button != null:
		alliance_button.set_pressed_no_signal(false)
	_map_preview_control.set_war_runtime(_war_runtime)
	_create_war_hud()
	_set_war_controls_visible(true)
	_hide_mobilization_overlay()
	current_screen = "conflict_active"
	_result_return_started = false
	_refresh_war_hud()


func _show_mobilization_overlay() -> void :
	_hide_mobilization_overlay()
	var overlay: = ColorRect.new()
	overlay.name = "WarMobilizationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_root.add_child(overlay)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 260.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.025, 0.96), SOURCE_RED, 1, 8))
	center.add_child(panel)
	var margin: = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var content: = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	content.add_child(_source_label("MOBILIZING", 28, 900, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 2))
	var status: = _label("Establishing theater control and deploying front units...", 13, Color("#aaaaaa"), HORIZONTAL_ALIGNMENT_CENTER)
	status.name = "WarMobilizationStatus"
	content.add_child(status)
	var progress: = ProgressBar.new()
	progress.name = "WarMobilizationProgress"
	progress.custom_minimum_size = Vector2(420.0, 6.0)
	progress.show_percentage = false
	progress.indeterminate = true
	progress.add_theme_stylebox_override("background", _panel_style(Color(1, 1, 1, 0.07), Color.TRANSPARENT, 0, 3))
	progress.add_theme_stylebox_override("fill", _panel_style(SOURCE_RED, Color.TRANSPARENT, 0, 3))
	content.add_child(progress)
	_mobilization_overlay = overlay


func _hide_mobilization_overlay() -> void :
	if is_instance_valid(_mobilization_overlay):
		if _mobilization_overlay.get_parent() != null:
			_mobilization_overlay.get_parent().remove_child(_mobilization_overlay)
		_mobilization_overlay.queue_free()
	_mobilization_overlay = null


func _create_war_hud() -> void :
	_clear_war_hud()
	var hud: = Control.new()
	hud.name = "WarHud"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_root.add_child(hud)
	_war_report_ui = MWWarReportUI.new()
	_war_report_ui.name = "WarReportUI"
	hud.add_child(_war_report_ui)
	_war_hud = hud
	_hud_layout_signature = ""
	_layout_compact_toolbar.call_deferred(_screen_root.get_node("GameStatusBar"), _screen_root.find_child("GameStatusControls", true, false))


func _clear_war_hud() -> void :
	if is_instance_valid(_war_hud):
		if _war_hud.get_parent() != null:
			_war_hud.get_parent().remove_child(_war_hud)
		_war_hud.queue_free()
	_war_hud = null
	_war_result_panel = null
	_war_report_ui = null


func _refresh_war_hud() -> void :
	if _war_runtime == null:
		return
	var profile_started: = Time.get_ticks_usec() if _war_runtime.performance_profile_enabled else 0
	if is_instance_valid(_playing_status):
		_playing_status.text = "PLAYING: %s" % selected_entry.loaded_context
	if is_instance_valid(_pause_button):
		_pause_button.text = "RESUME" if _war_runtime.is_paused else "PAUSE"
		_pause_button.tooltip_text = "Resume simulation" if _war_runtime.is_paused else "Pause simulation"
	if is_instance_valid(_speed_display_button):
		_speed_display_button.text = "%sx" % _format_speed(_war_runtime.current_speed())
	if is_instance_valid(_war_report_ui):
		_war_report_ui.refresh(_war_runtime)
	if profile_started > 0 and _war_runtime != null:
		_war_runtime.record_render_profile(&"hud", Time.get_ticks_usec() - profile_started)


func _set_war_controls_visible(visible_state: bool) -> void :


	for control in [_unit_view_button, _planning_button, _pause_button, _speed_down_button, _speed_display_button, _speed_up_button]:
		if is_instance_valid(control):
			control.visible = visible_state


func _toggle_war_pause() -> void :
	if _war_runtime == null:
		return
	_war_runtime.toggle_pause()
	_refresh_war_hud()


func _decrease_war_speed() -> void :
	if _war_runtime != null:
		_war_runtime.decrease_speed()
		_refresh_war_hud()


func _increase_war_speed() -> void :
	if _war_runtime != null:
		_war_runtime.increase_speed()
		_refresh_war_hud()


func _cycle_war_speed() -> void :
	if _war_runtime != null:
		_war_runtime.cycle_speed()
		_refresh_war_hud()


func _show_war_result() -> void :
	if _war_runtime == null or not is_instance_valid(_war_hud):
		return
	var panel: = PanelContainer.new()
	panel.name = "WarResultPanel"
	panel.set_anchor(SIDE_LEFT, 0.5)
	panel.set_anchor(SIDE_TOP, 0.5)
	panel.set_anchor(SIDE_RIGHT, 0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.offset_left = -370.0
	panel.offset_right = 370.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.02, 0.025, 0.96), SOURCE_RED, 2, 8))
	_war_hud.add_child(panel)
	var box: = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_source_label(_war_runtime.result_title(), 32, 900, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 2))
	box.add_child(_label("Treaty applied to permanent control once.", 14, Color("#b6b6b6"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("Side A casualties: %s     •     Side B casualties: %s" % [
		_format_integer(_war_runtime.side_casualties[0]), 
		_format_integer(_war_runtime.side_casualties[1]), 
	], 13, Color("#dddddd"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("Returning to Conflict Setup...", 11, Color("#777777"), HORIZONTAL_ALIGNMENT_CENTER))
	_war_result_panel = panel
	_set_war_controls_visible(false)
	if _map_preview_control != null:
		_map_preview_control.queue_redraw()


func _return_to_setup_after_result() -> void :
	var session_controller: = find_child("NativeConflictController", true, false) as MWNativeConflictController
	if session_controller != null and session_controller.has_method("request_session_transition") and bool(session_controller.call("request_session_transition", "result_return")):
		return
	if _war_runtime == null:
		return
	var treaty_owners: = _war_runtime.world_owners.duplicate()
	_war_runtime.stop()
	_war_runtime = null
	_preview_owner_ids = treaty_owners
	if _map_preview_control != null:
		_map_preview_control.clear_war_runtime()
		_map_preview_control.replace_world_owners(treaty_owners)
	_clear_war_hud()
	_set_war_controls_visible(false)
	current_screen = "campaign_setup"
	_set_setup_visible(_readonly_inspector.should_show_setup(true))
	conflict_setup_state.reset()
	_restore_setup_status()
	_result_return_started = false
	_selection_feedback.text = "Conflict concluded. Treaty borders remain until Quick Restart or Full Reload."
	_refresh_conflict_setup(false)


func _restore_setup_status() -> void :
	if is_instance_valid(_playing_status) and selected_entry != null and is_instance_valid(_readonly_inspector):
		_playing_status.text = _readonly_inspector.get_mode_status_text(selected_entry.loaded_context)


func _set_setup_visible(visible_state: bool) -> void :
	if is_instance_valid(_setup_shell):
		_setup_shell.visible = visible_state
	var actual_visible: = _setup_shell.visible if is_instance_valid(_setup_shell) else visible_state
	if is_instance_valid(_setup_blur):
		_setup_blur.visible = actual_visible
	if is_instance_valid(_setup_backdrop_copy):
		_setup_backdrop_copy.visible = actual_visible


func _stop_war_runtime() -> void :
	_hide_mobilization_overlay()
	if _war_runtime != null:
		_war_runtime.stop()
		_war_runtime = null
	if is_instance_valid(_map_preview_control):
		_map_preview_control.clear_war_runtime()
	_clear_war_hud()
	_set_war_controls_visible(false)
	_result_return_started = false


func _format_speed(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).trim_suffix("0")


func _format_integer(value: int) -> String:
	var digits: = str(abs(value))
	var formatted: = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return ("-" if value < 0 else "") + formatted


func _build_map_preview(scenario: ScenarioData) -> ImageTexture:
	var result: Dictionary = MWMapProjection.build_campaign_preview(scenario)
	if result.is_empty():
		return _build_map_preview_reference(scenario)
	_preview_owner_ids = result.owners
	return ImageTexture.create_from_image(result.image)


func _build_map_preview_reference(scenario: ScenarioData) -> ImageTexture:
	var preview_size: = Vector2i(scenario.grid_width(), scenario.grid_height())
	var image: = Image.create(preview_size.x, preview_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_preview_owner_ids.resize(preview_size.x * preview_size.y)
	_preview_owner_ids.fill(0)
	var colors: Dictionary = {}
	for country: CountryData in scenario.countries:
		var opaque: = country.color
		opaque.a = 1.0
		colors[country.id] = opaque
	var source_width: = scenario.grid_width()
	var source_height: = scenario.grid_height()
	for index: int in scenario.map_entry_count():
		var source_index: = scenario.map_indices[index]
		var source_x: = source_index % source_width

		var source_y: = int(float(source_index) / float(source_width))
		if source_y < 0 or source_y >= source_height:
			continue
		var preview_x: = mini(preview_size.x - 1, int(float(source_x) * preview_size.x / source_width))
		var preview_y: = preview_size.y - 1 - mini(preview_size.y - 1, int(float(source_y) * preview_size.y / source_height))
		var owner_id: = scenario.map_country_ids[index]
		image.set_pixel(preview_x, preview_y, colors.get(owner_id, Color("#5d6770")))
		_preview_owner_ids[preview_y * preview_size.x + preview_x] = owner_id
	return ImageTexture.create_from_image(image)


func _add_setup_backdrop_blur() -> void :



	var copy: = BackBufferCopy.new()
	copy.name = "ConflictSetupBackdropCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	copy.rect = SETUP_PANEL_RECT.grow(8.0)
	_screen_root.add_child(copy)

	var shader: = Shader.new()
	shader.code = "\r\nshader_type canvas_item;\r\nuniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;\r\n\r\nvoid fragment() {\r\n\tvec2 px = SCREEN_PIXEL_SIZE * 6.0;\r\n\tvec2 uv = SCREEN_UV;\r\n\tvec4 colour = texture(screen_texture, uv) * 0.20;\r\n\tcolour += texture(screen_texture, uv + vec2(px.x, 0.0)) * 0.12;\r\n\tcolour += texture(screen_texture, uv - vec2(px.x, 0.0)) * 0.12;\r\n\tcolour += texture(screen_texture, uv + vec2(0.0, px.y)) * 0.12;\r\n\tcolour += texture(screen_texture, uv - vec2(0.0, px.y)) * 0.12;\r\n\tcolour += texture(screen_texture, uv + px) * 0.08;\r\n\tcolour += texture(screen_texture, uv - px) * 0.08;\r\n\tcolour += texture(screen_texture, uv + vec2(px.x, -px.y)) * 0.08;\r\n\tcolour += texture(screen_texture, uv + vec2(-px.x, px.y)) * 0.08;\r\n\tCOLOR = colour;\r\n}\r\n"


















	var shader_material: = ShaderMaterial.new()
	shader_material.shader = shader
	var blur: = ColorRect.new()
	blur.name = "ConflictSetupBackdropBlur"
	blur.position = SETUP_PANEL_RECT.position
	blur.size = SETUP_PANEL_RECT.size
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.material = shader_material
	_screen_root.add_child(blur)


func _add_source_header() -> void :
	var margin: = MarginContainer.new()
	margin.name = "MainMenuHeader"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	_screen_root.add_child(margin)
	var header: = VBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_theme_constant_override("separation", 3)
	margin.add_child(header)
	var steam_platform: = get_node_or_null("SteamPlatform")
	if steam_platform != null and steam_platform.has_method("is_demo_build") and steam_platform.call("is_demo_build"):
		var eyebrow: = _source_label("DEMO", 14, 700, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 4)
		eyebrow.name = "DemoEyebrow"
		header.add_child(eyebrow)
	var title: = _source_label("MODERN WARS", 92, 900, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -3)
	title.name = "MainMenuTitle"
	title.custom_minimum_size = Vector2(620, 90)
	header.add_child(title)
	var author: = _source_label("Decoded and rebuilt by DecompStrak Team, original project made by man_82", 28, 700, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 1)
	author.name = "MainMenuAuthor"
	header.add_child(author)


func _right_rail(node_name: String) -> MarginContainer:
	var rail: = MarginContainer.new()
	rail.name = node_name
	rail.set_anchor(SIDE_LEFT, 0.55)
	rail.set_anchor(SIDE_TOP, 0.0)
	rail.set_anchor(SIDE_RIGHT, 1.0)
	rail.set_anchor(SIDE_BOTTOM, 1.0)
	rail.add_theme_constant_override("margin_left", 40)
	rail.add_theme_constant_override("margin_right", 40)
	rail.add_theme_constant_override("margin_top", 60)
	rail.add_theme_constant_override("margin_bottom", 60)
	return rail


func _source_label(text: String, font_size: int, weight: int, color: Color, alignment: HorizontalAlignment, spacing: int = 0) -> Label:
	var label: = _label(text, font_size, color, alignment)
	label.add_theme_font_override("font", _source_serif(weight, spacing))
	return label


func _source_serif(weight: int, spacing: int = 0) -> Font:
	var variation: = FontVariation.new()
	variation.base_font = SOURCE_SERIF_BASE
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): weight
	}
	variation.spacing_glyph = spacing
	return variation


func _menu_link(text: String, font_size: int, color: Color, outlined: bool = false) -> Button:
	var button: = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_override("font", _source_serif(700))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", SOURCE_RED)
	button.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, maxf(0.42, color.a * 0.7)))
	var border: = Color(1, 1, 1, 0.25) if outlined else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, border, 1 if outlined else 0, 0))
	button.add_theme_stylebox_override("hover", _panel_style(Color(1, 1, 1, 0.03), SOURCE_RED, 1, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(1, 1, 1, 0.06), SOURCE_RED, 1, 0))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0, 0, 0, 0.12), border, 1 if outlined else 0, 0))
	return button


func _label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, font_size: int) -> Button:
	var button: = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(PANEL_COLOR, PANEL_BORDER, 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#1a2a39"), ACCENT, 2, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#243749"), ACCENT, 2, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#0b1118"), Color("#27333d"), 1, 8))
	return button


func _hud_button(text: String, color: Color, disabled: bool = false) -> Button:
	if color in [Color("#555555"), Color("#444444"), Color("#222a27"), Color("#34495e")]:
		color = Color("#212926")
	var button: = Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(0, 32)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.72))
	button.add_theme_stylebox_override("normal", _panel_style(color, Color(1, 1, 1, 0.12), 1, 2))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.1), Color.WHITE, 1, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), Color.WHITE, 1, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#212926"), Color(1, 1, 1, 0.08), 1, 2))
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style: = button.get_theme_stylebox(state_name) as StyleBoxFlat
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 7
		style.content_margin_bottom = 7
	return button


func _toggle_hud_button(text: String, color: Color, enabled: bool) -> Button:
	var button: = _hud_button(text, Color("#222a27"))
	button.toggle_mode = true
	button.button_pressed = enabled
	button.add_theme_stylebox_override("pressed", _panel_style(color, Color(1, 1, 1, 0.25), 1, 2))
	button.add_theme_stylebox_override("hover_pressed", _panel_style(color.lightened(0.08), Color.WHITE, 1, 2))
	for state_name: String in ["pressed", "hover_pressed"]:
		var style: = button.get_theme_stylebox(state_name) as StyleBoxFlat
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 7
		style.content_margin_bottom = 7
	return button


func _size_reference_toolbar_button(button: Button) -> void :

	button.custom_minimum_size = Vector2(0, 49)
	button.add_theme_font_size_override("font_size", 11)
	for state_name: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		if not button.has_theme_stylebox_override(state_name):
			continue
		var style: = button.get_theme_stylebox(state_name) as StyleBoxFlat
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10


func _panel_style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _setup_panel_style() -> StyleBoxFlat:
	var style: = _panel_style(SETUP_PANEL_COLOR, SETUP_PANEL_BORDER, 1, 6)
	style.set_content_margin_all(12)

	style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	style.shadow_offset = Vector2(0.0, 24.0)
	style.shadow_size = 56
	return style


func _format_count(value: int) -> String:
	var text: = str(value)
	var result: = ""
	while text.length() > 3:
		result = ",%s%s" % [text.right(3), result]
		text = text.left(text.length() - 3)
	return text + result
