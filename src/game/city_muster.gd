extends RefCounted



const MUSTER_SECONDS: = 2.0
var exits: Dictionary = {}
var relocation_cache: Dictionary = {}
var cache_revision: = -1

func clear() -> void :
	exits.clear()
	relocation_cache.clear()
	cache_revision = -1

func inactive(unit: Dictionary) -> bool:
	var phase: String = unit.get("deployment_phase", "")
	return phase == "MUSTERING" or phase == "RELOCATING" or phase == "STRANDED"

func owns_assignment(unit: Dictionary) -> bool:



	return inactive(unit) or unit.get("deployment_phase", "") == "TRANSIT"

func begin(r: RefCounted, unit: Dictionary, city: Dictionary) -> void :
	unit["deployment_phase"] = "MUSTERING"
	unit["deployment_transit"] = false
	unit["deploy_ticks"] = 0
	unit["muster_city"] = city.duplicate(true)
	unit["muster_anchor"] = Vector2(unit.longitude, unit.latitude)
	unit["muster_started"] = r.simulation_seconds
	unit["muster_until"] = r.simulation_seconds + MUSTER_SECONDS
	unit["muster_checked_revision"] = -1
	unit["muster_retry_time"] = 0.0
	unit["formation_row"] = "support"
	unit["departure_waypoint"] = r.geo_for_grid_index(unit.reinforcement_route[0]) if not unit.reinforcement_route.is_empty() else Vector2(unit.longitude, unit.latitude)
	unit["sector_role"] = "Reinforce"
	unit["deployment_assigned_sector"] = int(unit.reinforcement_destination)
	unit.erase("sector_destination")
	unit.erase("reserved_slot")
	unit.erase("formation_target")
	_reserve_exit(r, unit)

func release_exit(unit: Dictionary) -> void :
	var key: String = unit.get("city_exit_slot", "")
	if int(exits.get(key, -1)) == int(unit.id): exits.erase(key)
	unit.erase("city_exit_slot")

func _reserve_exit(r: RefCounted, unit: Dictionary) -> void :
	release_exit(unit)
	var anchor: Vector2 = unit.muster_anchor
	var route: PackedInt32Array = unit.get("reinforcement_route", PackedInt32Array())
	var destination: Vector2 = r.geo_for_grid_index(route[mini(2, route.size() - 1)]) if not route.is_empty() else anchor + Vector2.RIGHT * 0.1
	var outward: Vector2 = r._wrapped_geo_delta(anchor, destination).normalized()
	var tangent: = Vector2( - outward.y, outward.x)
	for lane: int in range(64):
		var key: = "%d:%d:%d" % [int(unit.sovereign_id), int(unit.reinforcement_city_id), lane]
		if exits.has(key): continue
		var column: = (lane % 5) - 2
		var target: = anchor + outward * (0.07 + 0.06 * floorf(lane / 5.0)) + tangent * column * 0.065
		target.x = fposmod(target.x + 180.0, 360.0) - 180.0
		var clipped: PackedFloat64Array = MovementCorridor.clipped_precise(anchor.x, anchor.y, target.x, target.y, r.grid_size, _legal.bind(r, unit))
		if absf(clipped[0] - target.x) > 1e-06 or absf(clipped[1] - target.y) > 1e-06: continue
		exits[key] = int(unit.id)
		unit["city_exit_slot"] = key
		unit["departure_exit_slot"] = key
		unit["city_exit_target"] = target
		return
	unit["city_exit_target"] = anchor

func _legal(cell: int, r: RefCounted, unit: Dictionary) -> bool:
	return r.city_deployment.friendly(r, cell, int(unit.side_index), unit)

func update(r: RefCounted, index: int) -> bool:
	var unit: Dictionary = r.units[index]
	if not inactive(unit): return false

	if r.unit_is_encircled(unit):
		r._apply_encircled_unit_effects(index)
		if float(unit.health) <= 0.0: return true
	var phase: String = unit.deployment_phase
	if phase == "RELOCATING":
		var relocation_city: Dictionary = unit.muster_city
		if r.effective_owner_at(int(relocation_city.cell)) != int(unit.sovereign_id):
			unit["deployment_phase"] = "STRANDED"
			return true
		var relocation_anchor: Vector2 = relocation_city.geo
		if int(unit.reinforcement_route_cursor) < (unit.reinforcement_route as PackedInt32Array).size():
			r._move_unit_toward(index, Vector2.RIGHT)
		else:
			r._apply_deployment_step(index, relocation_anchor, r.UNIT_SPEED)
		if r._wrapped_geo_delta(Vector2(unit.longitude, unit.latitude), relocation_anchor).length_squared() < 1e-06:
			unit.reinforcement_route = relocation_city.route
			unit.reinforcement_route_cursor = 0
			unit.reinforcement_destination = relocation_city.front_cell
			unit.front_sector = relocation_city.front_cell
			unit.reinforcement_checked_revision = -1
			begin(r, unit, relocation_city)
		return true
	var city: Dictionary = unit.muster_city
	var safe: bool = r.effective_owner_at(int(city.cell)) == int(unit.sovereign_id) and _legal(int(city.cell), r, unit) and not r.unit_is_encircled(unit)
	if r.sim_tick_count - int(unit.get("damage_tick", -1000)) < 30: safe = false
	if safe and int(unit.get("muster_checked_revision", -1)) != r._control_revision:
		for cell: int in unit.get("reinforcement_route", PackedInt32Array()):
			if not _legal(cell, r, unit): safe = false;break
		if safe: unit.muster_checked_revision = r._control_revision
	if phase == "STRANDED" and safe:


		if r._wrapped_geo_delta(Vector2(unit.longitude, unit.latitude), city.geo).length_squared() < 1e-06:
			begin(r, unit, city)
			return true
	if not safe or phase == "STRANDED":
		unit["deployment_transit"] = false
		if r.simulation_seconds >= float(unit.muster_retry_time):
			unit.muster_retry_time = r.simulation_seconds + 1.0
			_reassign(r, unit)
		return true
	if phase == "MUSTERING":
		unit["velocity"] = Vector2.ZERO
		if r.simulation_seconds + 1e-07 < float(unit.muster_until): return true
		unit["deployment_phase"] = "TRANSIT"
		unit["deployment_transit"] = true
		unit["deployment_released"] = r.simulation_seconds
		unit["departure_exit_pending"] = true
		unit["reinforcement_lookahead_tick"] = -1


		return false
	return true

func _reassign(r: RefCounted, unit: Dictionary) -> void :
	release_exit(unit)
	unit["deployment_phase"] = "STRANDED"
	r._select_reinforcement_city(int(unit.sovereign_id), int(unit.side_index))
	var cities: Array[Dictionary] = r._city_front_route_cache.get(int(unit.sovereign_id), {}).get("cities", [] as Array[Dictionary])
	if cities.is_empty(): return
	if cache_revision != r._control_revision:
		relocation_cache.clear()
		cache_revision = r._control_revision
	var origin: int = r.grid_index_for_geo(unit.longitude, unit.latitude)
	var key: = "%d:%d:%d" % [int(unit.sovereign_id), origin, int(unit.reinforcement_city_id)]
	if not relocation_cache.has(key): relocation_cache[key] = _relocation(r, unit, cities, origin)
	var result: Dictionary = relocation_cache[key]
	if result.is_empty(): return
	unit["muster_city"] = result.city.duplicate(true)
	unit["reinforcement_city_id"] = int(result.city.id)
	unit["reinforcement_route"] = result.route
	unit["reinforcement_route_cursor"] = 0
	unit["reinforcement_checked_revision"] = -1
	unit["reinforcement_destination"] = int(result.city.cell)
	unit["deployment_phase"] = "RELOCATING"

func _relocation(r: RefCounted, unit: Dictionary, cities: Array[Dictionary], origin: int) -> Dictionary:
	var targets: = {}
	for city: Dictionary in cities:
		if int(city.id) != int(unit.reinforcement_city_id): targets[int(city.cell)] = city
	var queue: Array[int] = [origin]
	var parents: = {origin: -1}
	var cursor: = 0
	while cursor < queue.size() and cursor < 4096:
		var cell: = queue[cursor]
		cursor += 1
		if targets.has(cell):
			var path: Array[int] = []
			var step: = cell
			while step != origin:
				path.push_front(step)
				step = parents[step]
			return {"city": targets[cell], "route": PackedInt32Array(path)}
		for next: int in r._cardinal_indices(cell):
			if parents.has(next) or not _legal(next, r, unit): continue
			parents[next] = cell
			queue.append(next)
	return {}

func prune(units: Array[Dictionary]) -> void :
	var living: = {}
	for unit: Dictionary in units:
		if float(unit.health) > 0.0: living[int(unit.id)] = true
	for key: String in exits.keys():
		if not living.has(exits[key]): exits.erase(key)
