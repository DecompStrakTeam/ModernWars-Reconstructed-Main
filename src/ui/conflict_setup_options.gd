class_name ConflictSetupOptions
extends VBoxContainer



signal options_changed

const UNAVAILABLE: = [
	["Random War", "Automatic conflict selection is excluded."], 
	["Extra sides / FFA", "This runtime supports two opposing poles only."], 
	["Country buffs", "Country buffs are not implemented."], 
	["Add Allies / Release country", "Diplomacy and puppet systems are excluded."], 
	["Time System / year / month / day", "The optional source calendar is not implemented."], 
	["Fight to the death (no peace)", "Diplomatic peace offers are not implemented."], 
	["City Focus Mode (target cities)", "Optional city-priority offensives are not implemented; default garrisons remain active."], 
	["Disable long-range missiles — ON", "Missile and bomb systems are excluded."], 
	["No naval attacks — ON", "Only legal land movement is implemented."], 
	["Disable mountains — ON", "Mountain terrain and specialist units are not implemented."], 
	["Disable provinces — ON", "Internal province borders are not implemented."], 
	["Disable puppets (no vassal call) — ON", "Puppet systems are excluded."], 
	["War goals (claim specific land)", "Territorial war goals and diplomacy are excluded."], 
	["Cinematic mode (record war)", "Automatic video recording is not implemented."], 
	["Start Rebellion", "Rebellion simulation is excluded."], 
]

func configure(setup: RefCounted) -> void :
	add_theme_constant_override("separation", 9)
	add_child(_label("Conflict Name (Optional)"))
	var name_input: = LineEdit.new()
	name_input.name = "ConflictNameInput"
	name_input.placeholder_text = "Leave blank to auto-name"
	name_input.max_length = 48
	name_input.text = setup.conflict_name
	name_input.text_changed.connect( func(value: String) -> void : setup.conflict_name = value;options_changed.emit())
	add_child(name_input)
	add_child(_label("FORCES & TIMELINE"))
	var density_label: = _label("Force Density   %.1fx" % setup.force_density)
	add_child(density_label)
	var density: = HSlider.new()
	density.name = "ForceDensitySlider"
	density.min_value = 0.5
	density.max_value = 2.0
	density.step = 0.1
	density.value = setup.force_density
	density.tooltip_text = "Player-approved formations: 1.5x source count, with front-coverage floor. 0.5–2.0x; default 1.0x. The same source-equivalent or entered manpower pool is divided across more formations; no free personnel. Recruitment retains source rules and the smaller soldiers-per-formation ratio. Higher density costs more CPU."
	density.value_changed.connect( func(value: float) -> void :
		setup.force_density = value
		density_label.text = "Force Density   %.1fx" % value
		options_changed.emit()
	)
	add_child(density)
	add_child(_label("Alliance Manpower (Optional)"))
	for side: int in range(2):
		var row: = HBoxContainer.new()
		var side_label: = _label("SIDE %s" % ("A" if side == 0 else "B"))
		side_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		side_label.custom_minimum_size.x = 56
		row.add_child(side_label)
		var manpower: = SpinBox.new()
		manpower.name = "ManpowerSideA" if side == 0 else "ManpowerSideB"
		manpower.min_value = 0
		manpower.max_value = 1000000000000
		manpower.step = 1
		manpower.value = setup.manual_manpower[side]
		manpower.get_line_edit().add_theme_font_size_override("font_size", 13)
		manpower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		manpower.tooltip_text = "0 = Auto. Changes soldiers per unit and health-derived casualty reporting, not unit count or health."
		manpower.value_changed.connect( func(value: float) -> void :
			var pool: PackedInt64Array = setup.manual_manpower
			pool[side] = int(value)
			setup.manual_manpower = pool
			options_changed.emit()
		)
		row.add_child(manpower)
		add_child(row)
	add_child(_label("0 = Auto; troop health and unit count stay unchanged."))
	add_child(_label("BATTLE RULES"))
	var surrender: = CheckButton.new()
	surrender.name = "SurrenderOnCapitalCapture"
	surrender.text = "Surrender on Capital Capture"
	surrender.button_pressed = setup.surrender_on_capital_capture
	surrender.tooltip_text = "A country whose pre-war capital is decisively captured surrenders once; remaining force becomes casualties."
	surrender.toggled.connect( func(value: bool) -> void : setup.surrender_on_capital_capture = value;options_changed.emit())
	add_child(surrender)
	var disclosure: = Button.new()
	disclosure.name = "UnavailableSetupOptionsButton"
	disclosure.text = "UNAVAILABLE SOURCE OPTIONS ▸"
	disclosure.toggle_mode = true
	add_child(disclosure)
	var unavailable: = VBoxContainer.new()
	unavailable.name = "UnavailableSetupOptions"
	unavailable.visible = false
	add_child(unavailable)
	for definition: Array in UNAVAILABLE:
		var control: = Button.new()
		control.text = definition[0]
		control.disabled = true
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.tooltip_text = definition[1]
		unavailable.add_child(control)
		var reason: = _label(definition[1])
		reason.modulate = Color(0.7, 0.7, 0.7)
		unavailable.add_child(reason)
	disclosure.toggled.connect( func(value: bool) -> void : unavailable.visible = value)

func _label(text: String) -> Label:
	var result: = Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", 12)
	return result
