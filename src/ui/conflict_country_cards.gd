class_name ConflictCountryCards
extends VBoxContainer

signal country_removed(country_id: int)
var countries: Array[CountryData] = []
var selected_country_id: = -1
var setup_state: RefCounted

func show_countries(values: Array[CountryData]) -> void :
	countries = values
	selected_country_id = -1
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if countries.is_empty():
		var empty: = Label.new()
		empty.text = "— no nations —"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color("#929792"))
		add_child(empty)
	for country: CountryData in countries:
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		add_child(row)
		var pick: = Button.new()
		pick.text = country.country_name
		pick.tooltip_text = country.country_name
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.custom_minimum_size.y = 64
		pick.add_theme_font_size_override("font_size", 11)
		pick.pressed.connect( func() -> void : selected_country_id = country.id)
		row.add_child(pick)
		var remove: = Button.new()
		remove.name = "RemoveCountry%d" % country.id
		remove.text = "×"
		remove.tooltip_text = "Remove " + country.country_name
		remove.pressed.connect( func() -> void : country_removed.emit(country.id))
		row.add_child(remove)
		if setup_state != null:
			var selectors: = HBoxContainer.new()
			add_child(selectors)
			var role: = OptionButton.new()
			role.name = "CountryRole%d" % country.id
			role.add_item("OFF")
			role.add_item("SUP")
			role.select(1 if setup_state.country_roles.get(country.id, "OFFENSE") == "SUPPORT" else 0)
			role.tooltip_text = "OFF: Offensive participant. SUP: Reserved for future support-unit behavior; currently uses the same land runtime."
			role.get_popup().set_item_tooltip(0, "OFF: Offensive participant.")
			role.get_popup().set_item_tooltip(1, "SUP: Reserved for future support-unit behavior; no expeditionary support system yet.")
			role.item_selected.connect( func(index: int) -> void :
				var roles: Dictionary = setup_state.country_roles
				roles[country.id] = "SUPPORT" if index == 1 else "OFFENSE"
				setup_state.country_roles = roles
			)
			selectors.add_child(role)
			var label: = Label.new()
			label.text = "DOCTRINES"
			label.add_theme_font_size_override("font_size", 10)
			selectors.add_child(label)
			var doctrine: = OptionButton.new()
			doctrine.name = "CountryDoctrine%d" % country.id
			doctrine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for entry: Array in MWBattleDoctrines.definitions():
				doctrine.add_item(entry[0])
				doctrine.set_item_metadata(doctrine.item_count - 1, entry[1])
				doctrine.get_popup().set_item_tooltip(doctrine.item_count - 1, MWBattleDoctrines.tooltip(entry[0]))
			var selected: = MWBattleDoctrines.short_label(setup_state.country_doctrines.get(country.id, "Combined Arms"))
			for index: int in doctrine.item_count:
				if doctrine.get_item_text(index) == selected: doctrine.select(index)
			doctrine.tooltip_text = MWBattleDoctrines.tooltip(selected)
			doctrine.item_selected.connect( func(index: int) -> void :
				var doctrines: Dictionary = setup_state.country_doctrines
				doctrines[country.id] = doctrine.get_item_metadata(index)
				setup_state.country_doctrines = doctrines
				doctrine.tooltip_text = MWBattleDoctrines.tooltip(doctrine.get_item_text(index))
			)
			selectors.add_child(doctrine)

func has_country(country_id: int) -> bool:
	for country: CountryData in countries:
		if country.id == country_id:
			return true
	return false
