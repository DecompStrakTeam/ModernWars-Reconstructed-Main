class_name ConflictSetupState
extends RefCounted

const SIDE_A: = 0
const SIDE_B: = 1

var active_side: int = SIDE_A
var side_total: int = 2
var _assignments: Dictionary = {}
var conflict_name: = ""
var force_density: = 1.0
var manual_manpower: = PackedInt64Array([0, 0])
var surrender_on_capital_capture: = false
var country_doctrines: Dictionary = {}
var country_roles: Dictionary = {}


func launch_options() -> Dictionary:
	return {
		"conflict_name": conflict_name.strip_edges().left(48), 
		"force_density": clampf(force_density, 0.5, 2.0), 
		"manual_manpower": PackedInt64Array([maxi(0, manual_manpower[0]), maxi(0, manual_manpower[1])]), 
		"surrender_on_capital_capture": surrender_on_capital_capture, 
		"country_doctrines": country_doctrines.duplicate(), 
		"country_roles": country_roles.duplicate(), 
	}


func set_active_side(side: int) -> void :
	if side >= 0 and side < side_total:
		active_side = side


func add_side() -> int:
	var new_side: = side_total
	side_total += 1
	return new_side


func remove_side(side: int) -> bool:
	if side < 2 or side >= side_total:
		return false
	for country_id: Variant in _assignments.keys():
		var assigned_side: = int(_assignments[country_id])
		if assigned_side == side:
			_assignments.erase(country_id)
		elif assigned_side > side:
			_assignments[country_id] = assigned_side - 1
	side_total -= 1
	active_side = mini(active_side, side_total - 1)
	return true


func assign_country(country_id: int) -> void :
	if country_id > 0:
		_assignments[country_id] = active_side
		if not country_doctrines.has(country_id): country_doctrines[country_id] = "Combined Arms"
		if not country_roles.has(country_id): country_roles[country_id] = "OFFENSE"


func remove_country(country_id: int) -> void :
	_assignments.erase(country_id)
	country_doctrines.erase(country_id)
	country_roles.erase(country_id)


func assignment_for(country_id: int) -> int:
	return int(_assignments.get(country_id, -1))


func countries_for_side(side: int) -> Array[int]:
	var result: Array[int] = []
	for key: Variant in _assignments:
		if int(_assignments[key]) == side:
			result.append(int(key))
	result.sort()
	return result


func side_count(side: int) -> int:
	var count: = 0
	for side_value: Variant in _assignments.values():
		if int(side_value) == side:
			count += 1
	return count


func can_launch() -> bool:
	return active_side_count() >= 2


func active_side_count() -> int:
	var result: = 0
	for side: int in side_total:
		if side_count(side) > 0:
			result += 1
	return result


func reset() -> void :
	_assignments.clear()
	country_doctrines.clear()
	country_roles.clear()
	active_side = SIDE_A
