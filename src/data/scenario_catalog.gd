class_name ScenarioCatalog
extends RefCounted

const PRESENT_COLD_WAR: = "PRESENT & COLD WAR"
const WORLD_WARS: = "WORLD WARS"
const HISTORICAL_REGIONAL: = "HISTORICAL & REGIONAL"
const ALTERNATE_HISTORIES: = "ALTERNATE HISTORIES"
const COMMUNITY_MAPS: = "COMMUNITY MAPS"


static func entries() -> Array[ScenarioCatalogEntry]:
	var catalog: Array[ScenarioCatalogEntry] = []
	catalog.append(_entry("world_map_2022", PRESENT_COLD_WAR, "2022 MODERN DAY", "Current global geopolitics and real-world alliances.", "UnionOfBritain", "res://data/scenarios/populated_world_map_2022.json", "498c96cafcfae286c6f7622cb2b99af3c5e98264b901f0bb1ed1502e7318d091", "Modern Day", "2022.webp"))
	catalog.append(_entry("cold_war_1974", PRESENT_COLD_WAR, "1974 COLD WAR", "Bipolar world, proxy fronts, and superpower blocs.", "orange", "res://data/scenarios/populated_cold_war_1974.json", "6d142a45b72c11f8d251bd55913167735330618175094e9bebb0dfc1d92a320f", "1974 Scenario", "1974.webp"))
	catalog.append(_entry("ww2_1942", WORLD_WARS, "1942 TOTAL WAR", "The high tide of the Axis powers' global advance.", "orange", "res://data/scenarios/populated_ww2_1942.json", "eb4ad653bfa3c3dda79510d39352e9af044d1aa070976bfec9a95bc70c4fd37f", "1942 Scenario", "1942.webp"))
	catalog.append(_entry("ww2_peru_update", WORLD_WARS, "1936 INTERWAR", "The buildup to the most destructive war in history.", "filip", "res://data/scenarios/populated_ww2_peru_update.json", "8c8722fa8494bba820f497f28835e175183562bc61ca96afde9a78a30c3bef66", "WW2 Peru Update", "1936.webp"))
	catalog.append(_entry("ww1_1914", WORLD_WARS, "1914 GREAT WAR", "Empires collide on the trenches of Europe.", "orange", "res://data/scenarios/populated_ww1_1914.json", "3904d5a503d7ab23f11a87eda0dfb3321035d4926eb8ad78205cce2145c7c1ee", "1914 Scenario", "1914.webp"))
	catalog.append(_entry("napoleonic_1804", HISTORICAL_REGIONAL, "1804 NAPOLEONIC", "Revolutionary France clashing with global coalitions.", "orange", "res://data/scenarios/populated_napoleonic_1804.json", "42913c3cf3e3981065dbd4bb5ab9ecb84ddd24cf25ab0a7322fdac33cab34d21", "1804 Napoleonic Wars", "1804.webp"))
	catalog.append(_entry("renaissance_1492", HISTORICAL_REGIONAL, "1492 EXPLORATION", "The discovery of the New World and Old World rivalries.", "orange", "res://data/scenarios/populated_renaissance_1492.json", "2308a8334693e1287cda884d314a1e91cde36847db4d15472558ecdcf1317093", "1492 Scenario", "1492.webp"))
	catalog.append(_entry("1_ad", HISTORICAL_REGIONAL, "1 AD ANTIQUITY", "Classic empires and frontier legions of Rome and beyond.", "System", "res://data/scenarios/populated_1_ad.json", "16213c3855d7f9ef8f54d80c27614bc75c5077241ad4adfb8c7bf0515d715e52", "1 AD Scenario", "1.webp"))
	catalog.append(_entry("canada_states_scenario", HISTORICAL_REGIONAL, "CANADA PROVINCES", "Provincial conflicts across Canada.", "Gurt / man_82", "res://data/scenarios/populated_canada_states_scenario.json", "e16bbbe088601fd6c8ed95721711c78c7140447c7465e6cf7d6237346f6a69db", "Canada Provinces Scenario", "2022.webp"))
	catalog.append(_entry("germany_states_orange", HISTORICAL_REGIONAL, "GERMANY STATES", "Federal state level conflict in Germany.", "orange", "res://data/scenarios/populated_germany_states_orange.json", "ecd2b5249cbda3ce1f83985fefa9428950101d34f85a26fa78f22b3c4ff45282", "Germany States", "2022.webp"))
	catalog.append(_entry("england_states_scenario", HISTORICAL_REGIONAL, "ENGLAND STATES", "Counties and regional conflict in England.", "System", "res://data/scenarios/populated_england_states_scenario.json", "283b8ad631cc87c96d6941def1eb1bd3acf7ca6d4407db700aa728c07ad351c5", "England States", "2022.webp"))
	catalog.append(_entry("us_states_scenario", HISTORICAL_REGIONAL, "US STATES", "Internal subdivision conflict across North America.", "angel", "res://data/scenarios/populated_us_states_scenario.json", "04f9f0ceb7bce871fa9755eba4d6968b8bba2f6b1a9f52e5d9b120dd46695ac9", "US States Scenario", "2022.webp"))
	catalog.append(_entry("poland_states", HISTORICAL_REGIONAL, "POLAND STATES", "Detailed voivodeship and internal regional conflict in Poland.", "man_82", "res://data/scenarios/populated_poland_states.json", "cf6b281b965f283ae35d82711925505008ad9dc52ef082ed2c60c453204f1367", "Poland States", "2022.webp"))
	catalog.append(_entry("kaiserreich_alt", ALTERNATE_HISTORIES, "KAISERREICH", "Germany triumphant in the Great War; a fractured Entente world.", "angel", "res://data/scenarios/populated_kaiserreich_alt.json", "58b9a561c6ded942c18c518d1cdba0e350c4f8f7377a91e2ed5e06d281c3c682", "Kaiserreich", "1936.webp"))
	catalog.append(_entry("fire_rises_2acw", ALTERNATE_HISTORIES, "THE FIRE RISES", "A Second American Civil War erupts across a divided United States.", "angel", "res://data/scenarios/populated_fire_rises_2acw.json", "43eb9206689a601fc0c6525c16917aef238e3bbf48d8218112ec63f380b4ff70", "The Fire Rises – US Civil War", "2022.webp"))
	catalog.append(_entry("orwell_1984", ALTERNATE_HISTORIES, "1984", "Oceania, Eurasia, and Eastasia locked in perpetual global war.", "Randombanana", "res://data/scenarios/populated_orwell_1984.json", "b8476bc4dd0eee8baf6de475aedfad82ad36ef37c3d5f869b95962ba71e128e4", "1984 – Oceania vs Eurasia", "1974.webp"))
	catalog.append(_entry("tno_map", ALTERNATE_HISTORIES, "THE NEW ORDER", "An alternate Cold War where the Axis won — fractured superpowers vie for the world.", "Community", "res://data/scenarios/tno_final_preset.json", "9978ba94ebdadcb5a9f781e33522b7b557f37ff4bc7f55c929f63486318a94cd", "The New Order", "1936.webp"))
	catalog.append(_entry("roman_world", ALTERNATE_HISTORIES, "A ROMAN WORLD FINISHED", "An alternate history where Rome endures.", "Community", "res://data/scenarios/roman_world_finished_preset.json", "a08b279530f48598ae33ecbb6ce5748b7519932b1c6e0734456a994de8deab63", "A Roman World Finished", "1.webp"))
	catalog.append(_entry("continental_project", COMMUNITY_MAPS, "THE CONTINENTAL PROJECT", "A community-built world of custom nations and reimagined borders.", "Community", "res://data/scenarios/the_continental_project_preset.json", "3f36e668c1ffd9d875eafb7fcd4161b84cca863959003cdd81ede570bc51a336", "The Continental Project", "2022.webp"))
	return catalog


static func find_by_id(stable_id: String) -> ScenarioCatalogEntry:
	for entry: ScenarioCatalogEntry in entries():
		if entry.stable_id == stable_id:
			return entry
	return null


static func _entry(
	stable_id: String, 
	group_name: String, 
	card_title: String, 
	description: String, 
	map_credit: String, 
	file_name: String, 
	source_sha256: String, 
	loaded_context: String, 
	__preview_file_name: String
) -> ScenarioCatalogEntry:
	var entry: = ScenarioCatalogEntry.new()
	entry.stable_id = stable_id
	entry.group_name = group_name
	entry.card_title = card_title
	entry.description = description
	entry.map_credit = map_credit
	entry.source_path = file_name if file_name.begins_with("res://") else "res://source/data/%s" % file_name
	entry.source_sha256 = source_sha256
	entry.loaded_context = loaded_context
	entry.preview_texture_path = "res://assets/scenarios/previews/%s.png" % stable_id
	return entry
