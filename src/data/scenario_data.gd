extends Resource

@export var raw_name: String = "Unnamed Scenario"
@export var display_name: String = "Unnamed Scenario"
@export var source_path: String = ""
@export var map_resolution: String = ""
@export var grid_resolution: float = 0.1
@export var map_encoding: String = ""
@export var countries: Array[CountryData] = []
@export var cities: Array[CityData] = []

var map_indices: PackedInt32Array = PackedInt32Array()
var map_country_ids: PackedInt32Array = PackedInt32Array()
var map_biomes: PackedInt32Array = PackedInt32Array()


func grid_width() -> int:
	return maxi(1, int(ceil(360.0 / grid_resolution)))


func grid_height() -> int:
	return maxi(1, int(ceil(180.0 / grid_resolution)))


func map_entry_count() -> int:
	return map_indices.size()
