class_name ScenarioJsonLoader
extends RefCounted

const DEFAULT_COUNTRY_COLOR: = Color(150.0 / 255.0, 150.0 / 255.0, 150.0 / 255.0, 0.5)

var last_error: String = ""


func load_scenario(source_path: String, display_context: String = "") -> ScenarioData:
	last_error = ""
	var file: = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		last_error = "Cannot open scenario file: %s (error %s)" % [source_path, FileAccess.get_open_error()]
		return null

	var json: = JSON.new()
	var parse_error: = json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		last_error = "Invalid JSON in %s at line %d: %s" % [source_path, json.get_error_line(), json.get_error_message()]
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		last_error = "Scenario root must be a JSON object: %s" % source_path
		return null

	return parse_scenario_dict(json.data as Dictionary, source_path, display_context)


func parse_scenario_dict(data: Dictionary, source_path: String = "", display_context: String = "") -> ScenarioData:
	last_error = ""
	var scenario: = ScenarioData.new()
	scenario.source_path = source_path
	scenario.raw_name = _string_or_default(data.get("name"), "Unnamed Scenario")
	scenario.display_name = display_context if not display_context.is_empty() else scenario.raw_name
	scenario.map_resolution = _string_or_default(data.get("mapRes"), "")
	scenario.grid_resolution = _float_or_default(data.get("gridRes"), 0.1)
	if scenario.grid_resolution <= 0.0:
		scenario.grid_resolution = 0.1
	scenario.map_encoding = _string_or_default(data.get("mapDataEnc"), "")

	var metadata_value: Variant = data.get("metadata", [])
	if typeof(metadata_value) == TYPE_ARRAY:
		for value: Variant in metadata_value as Array:
			if typeof(value) == TYPE_DICTIONARY:
				scenario.countries.append(parse_country(value as Dictionary))

	var cities_value: Variant = data.get("cities", [])
	if typeof(cities_value) == TYPE_ARRAY:
		for value: Variant in cities_value as Array:
			if typeof(value) == TYPE_DICTIONARY:
				scenario.cities.append(parse_city(value as Dictionary))

	var map_data_value: Variant = data.get("mapData", [])
	if typeof(map_data_value) != TYPE_ARRAY:
		last_error = "Scenario mapData must be an array: %s" % source_path
		return null
	_decode_map_entries(map_data_value as Array, scenario)
	return scenario


func parse_country(data: Dictionary) -> CountryData:
	var country: = CountryData.new()
	country.id = _int_or_default(data.get("id"), 0)
	country.country_name = _string_or_default(data.get("name"), "Country %d" % country.id)
	country.color_source = _string_or_default(data.get("color"), "rgba(150, 150, 150, 0.5)")
	country.color = parse_css_color(country.color_source, DEFAULT_COUNTRY_COLOR)
	country.is_custom = _bool_or_default(data.get("isCustom"), false)
	country.flag_url = _string_or_default(data.get("flagUrl"), "")
	country.role = _string_or_default(data.get("role"), "")
	country.overlord_id = _int_or_default(data.get("overlordId"), -1)
	country.releasable_by = _int_or_default(data.get("releasableBy"), -1)
	var allies_value: Variant = data.get("allies", [])
	if typeof(allies_value) == TYPE_ARRAY:
		for ally_value: Variant in allies_value as Array:
			var ally_id: = _int_or_default(ally_value, -1)
			if ally_id > 0 and not country.allies.has(ally_id):
				country.allies.append(ally_id)

	var saved_cells_value: Variant = data.get("savedCells", [])
	if typeof(saved_cells_value) == TYPE_ARRAY:
		for value: Variant in saved_cells_value as Array:
			if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
				var pair: = value as Array
				country.saved_cells.append(Vector2i(_int_or_default(pair[0], 0), _int_or_default(pair[1], 0)))
	return country


func parse_city(data: Dictionary) -> CityData:
	var city: = CityData.new()
	city.id = _int_or_default(data.get("id"), 0)
	city.city_name = _string_or_default(data.get("name"), "City")
	city.latitude = _float_or_default(data.get("lat"), 0.0)
	city.longitude = _float_or_default(data.get("lng"), 0.0)
	city.population = _int_or_default(data.get("pop"), 0)
	city.is_capital = _bool_or_default(data.get("isCapital"), false)
	city.owner_id = _int_or_default(data.get("ownerId"), -1)
	city.is_custom = _bool_or_default(data.get("isCustom"), false)
	return city


static func parse_css_color(value: Variant, fallback: Color = DEFAULT_COUNTRY_COLOR) -> Color:
	var parsed: Variant = _try_parse_css_color(value)
	if parsed is Color:
		return parsed
	return fallback


static func is_css_color_valid(value: Variant) -> bool:
	return _try_parse_css_color(value) is Color


static func _try_parse_css_color(value: Variant) -> Variant:
	if value == null:
		return null
	var text: = String(value).strip_edges()
	var lower: = text.to_lower()
	if lower.begins_with("rgba(") and lower.ends_with(")"):
		return _parse_rgb_color(lower.substr(5, lower.length() - 6).split(","), true)
	if lower.begins_with("rgb(") and lower.ends_with(")"):
		return _parse_rgb_color(lower.substr(4, lower.length() - 5).split(","), false)
	if lower.begins_with("hsla(") and lower.ends_with(")"):
		return _parse_hsl_color(lower.substr(5, lower.length() - 6).split(","), true)
	if lower.begins_with("hsl(") and lower.ends_with(")"):
		return _parse_hsl_color(lower.substr(4, lower.length() - 5).split(","), false)
	if Color.html_is_valid(text):
		return Color.from_string(text, DEFAULT_COUNTRY_COLOR)
	return null


static func _parse_rgb_color(components: PackedStringArray, has_alpha: bool) -> Variant:
	if components.size() != (4 if has_alpha else 3):
		return null
	var red: Variant = _parse_css_number(components[0])
	var green: Variant = _parse_css_number(components[1])
	var blue: Variant = _parse_css_number(components[2])
	if red == null or green == null or blue == null:
		return null
	var alpha: Variant = _parse_css_alpha(components[3]) if has_alpha else 1.0
	if alpha == null:
		return null
	return Color(
		clampf(float(red) / 255.0, 0.0, 1.0), 
		clampf(float(green) / 255.0, 0.0, 1.0), 
		clampf(float(blue) / 255.0, 0.0, 1.0), 
		float(alpha)
	)


static func _parse_hsl_color(components: PackedStringArray, has_alpha: bool) -> Variant:
	if components.size() != (4 if has_alpha else 3):
		return null
	var hue: Variant = _parse_css_hue(components[0])
	var saturation: Variant = _parse_css_percentage(components[1])
	var lightness: Variant = _parse_css_percentage(components[2])
	if hue == null or saturation == null or lightness == null:
		return null
	var alpha: Variant = _parse_css_alpha(components[3]) if has_alpha else 1.0
	if alpha == null:
		return null

	var normalized_hue: = fposmod(float(hue), 360.0) / 360.0
	var chroma: = (1.0 - absf(2.0 * float(lightness) - 1.0)) * float(saturation)
	var hue_sector: = normalized_hue * 6.0
	var secondary: = chroma * (1.0 - absf(fposmod(hue_sector, 2.0) - 1.0))
	var red: = 0.0
	var green: = 0.0
	var blue: = 0.0
	if hue_sector < 1.0:
		red = chroma
		green = secondary
	elif hue_sector < 2.0:
		red = secondary
		green = chroma
	elif hue_sector < 3.0:
		green = chroma
		blue = secondary
	elif hue_sector < 4.0:
		green = secondary
		blue = chroma
	elif hue_sector < 5.0:
		red = secondary
		blue = chroma
	else:
		red = chroma
		blue = secondary
	var match_lightness: = float(lightness) - chroma * 0.5
	return Color(red + match_lightness, green + match_lightness, blue + match_lightness, float(alpha))


static func _parse_css_number(component: String) -> Variant:
	var text: = component.strip_edges()
	if not text.is_valid_float():
		return null
	return text.to_float()


static func _parse_css_hue(component: String) -> Variant:
	var text: = component.strip_edges()
	if text.ends_with("deg"):
		text = text.substr(0, text.length() - 3).strip_edges()
	return _parse_css_number(text)


static func _parse_css_percentage(component: String) -> Variant:
	var text: = component.strip_edges()
	if not text.ends_with("%"):
		return null
	var value: Variant = _parse_css_number(text.substr(0, text.length() - 1).strip_edges())
	if value == null:
		return null
	return clampf(float(value) / 100.0, 0.0, 1.0)


static func _parse_css_alpha(component: String) -> Variant:
	var text: = component.strip_edges()
	if text.ends_with("%"):
		return _parse_css_percentage(text)
	var value: Variant = _parse_css_number(text)
	if value == null:
		return null
	return clampf(float(value), 0.0, 1.0)


func _decode_map_entries(entries: Array, scenario: ScenarioData) -> void :
	var capacity: = entries.size()



	var indices: = PackedInt32Array()
	var country_ids: = PackedInt32Array()
	var biomes: = PackedInt32Array()
	indices.resize(capacity)
	country_ids.resize(capacity)
	biomes.resize(capacity)
	var write_index: = 0
	var accumulated_index: = -1
	var uses_delta: = scenario.map_encoding == "delta"

	for value: Variant in entries:
		if typeof(value) != TYPE_ARRAY:
			continue
		var entry: = value as Array
		if entry.size() < 2:
			continue
		var encoded_index: = _int_or_default(entry[0], -1)
		var absolute_index: = encoded_index
		if uses_delta:
			accumulated_index += encoded_index
			absolute_index = accumulated_index
		if absolute_index < 0:
			continue
		indices[write_index] = absolute_index
		country_ids[write_index] = _int_or_default(entry[1], 0)
		biomes[write_index] = _int_or_default(entry[2], 0) if entry.size() >= 3 else 0
		write_index += 1

	indices.resize(write_index)
	country_ids.resize(write_index)
	biomes.resize(write_index)
	scenario.map_indices = indices
	scenario.map_country_ids = country_ids
	scenario.map_biomes = biomes


static func _string_or_default(value: Variant, fallback: String) -> String:
	return fallback if value == null else String(value)


static func _int_or_default(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_BOOL:
		return int(value)
	var text: = String(value)
	return text.to_int() if text.is_valid_int() else fallback


static func _float_or_default(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	var text: = String(value)
	return text.to_float() if text.is_valid_float() else fallback


static func _bool_or_default(value: Variant, fallback: bool) -> bool:
	if value == null:
		return fallback
	if typeof(value) == TYPE_BOOL:
		return value as bool
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return bool(value)
	var text: = String(value).to_lower()
	if text == "true" or text == "1":
		return true
	if text == "false" or text == "0":
		return false
	return fallback
