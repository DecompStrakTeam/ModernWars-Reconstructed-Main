extends RefCounted




var allocations: Dictionary = {}
var sector_allocations: Dictionary = {}
var corridor_cache: Dictionary = {}
var corridor_revision: = -1

func clear() -> void :
	allocations.clear()
	sector_allocations.clear()
	corridor_cache.clear()
	corridor_revision = -1

func committed(country: int, city: int, sector: int) -> void :
	var key: = Vector2i(country, city)
	allocations[key] = int(allocations.get(key, 0)) + 1
	sector_allocations[sector] = int(sector_allocations.get(sector, 0)) + 1

func friendly(r: RefCounted, cell: int, side: int, probe: Dictionary) -> bool:
	return r._movement_land_legal(cell, probe) and (r.occupation[cell] > 0.0 if side == 0 else r.occupation[cell] < 0.0)

func build(r: RefCounted, country: int, side: int) -> Array[Dictionary]:
	if r.performance_profile_enabled: r.exclusive_profile.count(&"city_front_bfs_calls")
	var cities: Array[Dictionary] = r._eligible_reinforcement_cities(country, side)
	var records: Array[Dictionary] = []
	if cities.is_empty(): return records
	var by_cell: Dictionary = {}
	for city: Dictionary in cities:
		if not by_cell.has(int(city.cell)): by_cell[int(city.cell)] = []
		by_cell[int(city.cell)].append(city)
	var probe: = {"sovereign_id": country}
	var seeds: Array = r._active_front_cells.keys()
	seeds.sort()
	var queue: = PackedInt32Array()
	var depths: = PackedInt32Array()
	var parents: Dictionary = {}
	for cell: int in seeds:
		if friendly(r, cell, side, probe):
			queue.append(cell)
			depths.append(0)
			parents[cell] = -1


	if queue.is_empty():
		for cell: int in r.country_cells.get(country, PackedInt32Array()):
			if not friendly(r, cell, side, probe): continue
			for neighbor: int in r._cardinal_indices(cell):
				if r._effective_side_for_cell(neighbor) == 1 - side:
					queue.append(cell)
					depths.append(0)
					parents[cell] = -1
					break
	var cursor: = 0
	var last_depth: = -1
	while cursor < queue.size():
		var cell: = queue[cursor]
		var distance: = depths[cursor]
		cursor += 1
		if last_depth >= 0 and distance > last_depth: break
		if by_cell.has(cell):
			for city: Dictionary in by_cell[cell]:
				var result: = city.duplicate(true)
				var route: = PackedInt32Array()
				var step: = cell
				while int(parents[step]) >= 0:
					step = int(parents[step])
					route.append(step)
				result["front_cell"] = step
				result["route"] = route
				result["route_distance"] = distance
				records.append(result)
			if records.size() >= 3: last_depth = distance
		for next: int in r._cardinal_indices(cell):
			if parents.has(next) or not friendly(r, next, side, probe): continue
			parents[next] = cell
			queue.append(next)
			depths.append(distance + 1)
	if r.performance_profile_enabled: r.exclusive_profile.count(&"city_front_bfs_cells", cursor)
	records.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.id) < int(b.id) if int(a.route_distance) == int(b.route_distance) else int(a.route_distance) < int(b.route_distance))
	if records.size() > 3: records.resize(3)


	for record: Dictionary in records:
		record["destinations"] = _destinations(r, probe, side, int(record.front_cell))
	return records

func _destinations(r: RefCounted, probe: Dictionary, side: int, start: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parents: = {start: -1}
	var queue: Array[int] = [start]
	var depths: = {start: 0}
	var cursor: = 0
	while cursor < queue.size():
		var cell: = queue[cursor]
		cursor += 1
		if r._active_front_cells.has(cell):
			var path: Array[int] = []
			var step: = cell
			while step != start:
				path.push_front(step)
				step = parents[step]
			result.append({"cell": cell, "route": PackedInt32Array(path)})
		if int(depths[cell]) >= 6: continue
		for next: int in r._cardinal_indices(cell):
			if parents.has(next) or not friendly(r, next, side, probe): continue
			parents[next] = cell
			depths[next] = int(depths[cell]) + 1
			queue.append(next)
	if result.is_empty(): result.append({"cell": start, "route": PackedInt32Array()})
	if r.performance_profile_enabled: r.exclusive_profile.count(&"city_destination_bfs_cells", cursor)
	return result

func select(r: RefCounted, country: int, side: int, cities: Array[Dictionary]) -> Dictionary:
	if cities.is_empty(): return {}
	var best: Dictionary = {}
	var score: = INF
	for city: Dictionary in cities:


		var delivered: = int(allocations.get(Vector2i(country, int(city.id)), 0))
		var cost: = delivered * (1.0 + float(city.route_distance) / maxf(1.0, float(cities[0].route_distance)))
		if cost < score:
			score = cost
			best = city
	var result: = best.duplicate(true)
	var destination: Dictionary = best.destinations[0]
	var demand_score: = INF
	for candidate: Dictionary in best.destinations:
		var cell: = int(candidate.cell)
		var weight: float = r._front_weight(cell, side)
		var cost: float = weight + int(sector_allocations.get(cell, 0)) * 0.75 + (candidate.route as PackedInt32Array).size() * 0.1
		if cost < demand_score or (is_equal_approx(cost, demand_score) and cell < int(destination.cell)):
			demand_score = cost
			destination = candidate
	result.route.append_array(destination.route)
	result.front_cell = destination.cell



	if corridor_revision != r._control_revision:
		corridor_cache.clear()
		corridor_revision = r._control_revision
	var key: = Vector3i(country, int(best.cell), int(destination.cell))
	if not corridor_cache.has(key):
		corridor_cache[key] = _direct_corridor(r, country, side, int(best.cell), int(destination.cell))
	var corridor: PackedInt32Array = corridor_cache[key]
	if not corridor.is_empty(): result.route = corridor
	result.route_distance = (result.route as PackedInt32Array).size()
	result.erase("destinations")
	return result

func _direct_corridor(r: RefCounted, country: int, side: int, start: int, goal: int) -> PackedInt32Array:
	if r.performance_profile_enabled: r.exclusive_profile.count(&"city_corridor_calls")
	var probe: = {"sovereign_id": country}
	var origin: Vector2 = r.geo_for_grid_index(start)
	var destination: Vector2 = r.geo_for_grid_index(goal)
	var axis: Vector2 = r._wrapped_geo_delta(origin, destination)


	var clipped: = MovementCorridor.clipped_precise(origin.x, origin.y, destination.x, destination.y, r.grid_size, func(sample_cell: int) -> bool: return friendly(r, sample_cell, side, probe))
	if absf(clipped[0] - destination.x) > 1e-06 or absf(clipped[1] - destination.y) > 1e-06: return PackedInt32Array()
	var route: = PackedInt32Array()
	var cell: = start
	for step: int in range(512):
		if cell == goal: return route
		var best: = -1
		var error: = INF
		var delta: Vector2 = r._wrapped_geo_delta(r.geo_for_grid_index(cell), destination)
		var distance: = absf(delta.x) + absf(delta.y)
		for next: int in r._cardinal_indices(cell):
			if not friendly(r, next, side, probe): continue
			var point: Vector2 = r.geo_for_grid_index(next)
			var remaining: Vector2 = r._wrapped_geo_delta(point, destination)
			if absf(remaining.x) + absf(remaining.y) >= distance - 1e-05: continue
			var line_error: = absf(axis.cross(r._wrapped_geo_delta(origin, point)))
			if line_error < error:
				error = line_error
				best = next
		if best < 0: break
		cell = best
		route.append(cell)
	return PackedInt32Array()

func reroute(r: RefCounted, unit: Dictionary) -> PackedInt32Array:
	var start: int = r.grid_index_for_geo(unit.longitude, unit.latitude)
	var side: = int(unit.side_index)
	var parents: = {start: -1}
	var queue: Array[int] = [start]
	var cursor: = 0
	while cursor < queue.size() and cursor < 2048:
		var cell: = queue[cursor]
		cursor += 1
		if r._active_front_cells.has(cell) and friendly(r, cell, side, unit):
			var path: Array[int] = []
			var step: = cell
			while step != start:
				path.push_front(step)
				step = parents[step]
			unit["reinforcement_destination"] = cell
			unit["front_sector"] = cell
			return PackedInt32Array(path)
		for next: int in r._cardinal_indices(cell):
			if parents.has(next) or not friendly(r, next, side, unit): continue
			parents[next] = cell
			queue.append(next)
	return PackedInt32Array()
