extends RefCounted



const INTERVAL: = 30
const COMMIT_TICKS: = 180
const FAILURE_TICKS: = 180
const SECURE_TICKS: = 90
var sectors: Dictionary = {}
var operations: Dictionary = {}
var history: Array[Dictionary] = []
var last_tick: = -1
var next_id: = 1
var operation_seed: = 0
var unit_lookup: Dictionary = {}

func clear(seed_value: int = 0) -> void :
	sectors.clear()
	operations.clear()
	history.clear()
	last_tick = -1
	next_id = 1
	operation_seed = seed_value
	unit_lookup.clear()

func friendly(r: RefCounted, cell: int, side: int) -> bool:
	return cell >= 0 and cell < r.land_mask.size() and r.land_mask[cell] == 2 and (r.occupation[cell] > 0.0 if side == 0 else r.occupation[cell] < 0.0)



func doctrine_weights(r: RefCounted, country: int, ratio: float, lost_home: bool) -> Dictionary:
	var label: = MWBattleDoctrines.short_label(r.country_doctrines.get(country, "Combined Arms"))
	var existing: = CountryBattlePlanner.candidate_weights({"doctrine": label, "ratio": ratio, "damaged": 0.0, "saturated": true, "encircled": 0, "lost_home": lost_home, "tick": r.sim_tick_count}, true)
	return {"advance": float(existing.get("offensive_line", 1.0)), "flank": float(existing.get("encircle", 1.0)), "exploit": float(existing.get("spearhead", 1.0)), "city": float(existing.get("urban_defense", 1.0)), "recover": float(existing.get("recover_homeland", 1.0))}

func _set_role(unit: Dictionary, role: String, target: Vector2, tick: int, operation: int = -1) -> void :
	if unit.get("sector_role", "") != role or int(unit.get("sector_operation", -1)) != operation:
		unit["sector_commit_until"] = tick + COMMIT_TICKS
	unit["sector_role"] = role
	unit["sector_destination"] = target
	unit["sector_operation"] = operation

func update(r: RefCounted) -> void :
	if last_tick >= 0 and r.sim_tick_count - last_tick < INTERVAL: return
	last_tick = r.sim_tick_count
	sectors.clear()
	var by_id: Dictionary = {}
	var country_counts: Dictionary = {}
	for u: Dictionary in r.units:
		if float(u.health) <= 0.0: continue
		by_id[int(u.id)] = u
		if r.city_muster.owns_assignment(u): continue
		country_counts[int(u.sovereign_id)] = int(country_counts.get(int(u.sovereign_id), 0)) + 1
		var cell: = int(u.get("front_sector", -1))
		if cell < 0 or not r._active_front_cells.has(cell) or not u.has("formation_target"): continue
		if not sectors.has(cell): sectors[cell] = {"units": [], "side": int(u.side_index), "front": [], "reserve": []}
		var record: Dictionary = sectors[cell]
		record.units.append(u)
		var forward: bool = u.get("formation_row", "forward") == "forward"
		record["front" if forward else "reserve"].append(u)
		var destination: Vector2 = u.formation_target
		var distant: bool = r._wrapped_geo_delta(Vector2(u.longitude, u.latitude), destination).length_squared() > 0.09
		if not operations.has(int(u.get("sector_operation", -1))):
			var desired_role: = "Reinforce" if distant else ("Hold" if forward else "Reserve")

			if r.sim_tick_count >= int(u.get("sector_commit_until", 0)) or int(u.get("sector_operation", -1)) >= 0 or u.get("sector_slot", "") != u.get("reserved_slot", ""):
				_set_role(u, desired_role, destination, r.sim_tick_count)
			else:
				u["sector_destination"] = destination
			u["sector_slot"] = u.get("reserved_slot", "")
	unit_lookup = by_id
	var busy: Dictionary = {}
	var active_by_country: Dictionary = {}
	for operation_id: int in operations.keys():
		var op: Dictionary = operations[operation_id]
		var attacker: Dictionary = by_id.get(int(op.unit), {})
		var cover: Dictionary = by_id.get(int(op.cover), {})
		var reason: = ""
		if attacker.is_empty(): reason = "assigned force destroyed"
		elif not r.unit_can_enter_cell(attacker, int(op.target_cell)): reason = "homeland restriction"
		elif cover.is_empty(): reason = "cover force destroyed"
		if not reason.is_empty():
			_end(operation_id, r.sim_tick_count, reason)
			continue
		var supported: bool = friendly(r, int(op.anchor), int(op.side)) and friendly(r, int(op.cover_cell), int(op.side)) and not r.unit_is_encircled(attacker)


		for route_cell: int in op.route:
			if not r.unit_can_enter_cell(attacker, route_cell) or (route_cell != int(op.target_cell) and not friendly(r, route_cell, int(op.side))):
				supported = false
				break
		if not supported:
			if int(op.failure_since) < 0: op.failure_since = r.sim_tick_count
			op.phase = "paused"
			_set_role(attacker, "Withdraw", Vector2(cover.longitude, cover.latitude), r.sim_tick_count, operation_id)
			if r.sim_tick_count - int(op.failure_since) >= FAILURE_TICKS:
				_end(operation_id, r.sim_tick_count, "sustained loss of anchor/support/route")
				continue
		else:
			op.failure_since = -1
			_set_role(cover, "Cover", op.cover_target, r.sim_tick_count, operation_id)
			var covered: bool = r._wrapped_geo_delta(Vector2(cover.longitude, cover.latitude), op.cover_target).length_squared() < 0.01
			if friendly(r, int(op.target_cell), int(op.side)):
				if int(op.secure_since) < 0: op.secure_since = r.sim_tick_count
				op.phase = "securing"
				_set_role(attacker, "Secure", op.target, r.sim_tick_count, operation_id)
				if r.sim_tick_count - int(op.secure_since) >= SECURE_TICKS:
					_end(operation_id, r.sim_tick_count, "limited objective secured")
					continue
			elif covered and float(attacker.health) >= 35.0:
				op.phase = "pushing"
				_set_role(attacker, "Exploit" if op.kind == "exploit" else "Advance", op.target, r.sim_tick_count, operation_id)
			else:
				op.phase = "preparing"
				_set_role(attacker, "Hold", op.start, r.sim_tick_count, operation_id)
		busy[int(attacker.id)] = true
		busy[int(cover.id)] = true
		active_by_country[int(op.country)] = int(active_by_country.get(int(op.country), 0)) + 1
	var ordered: Array = sectors.keys()
	ordered.sort_custom( func(a: int, b: int) -> bool:
		var ka: = posmod(a * 7919 + operation_seed, 104729)
		var kb: = posmod(b * 7919 + operation_seed, 104729)
		return a < b if ka == kb else ka < kb)
	for cell: int in ordered:
		var sector: Dictionary = sectors[cell]
		if sector.front.is_empty() or sector.reserve.is_empty(): continue
		var attacker: Dictionary = sector.front[0]
		var cover: Dictionary = sector.reserve[0]
		if busy.has(int(attacker.id)) or busy.has(int(cover.id)) or float(attacker.health) < 65 or float(cover.health) < 50: continue
		if r.sim_tick_count < int(attacker.get("sector_recover_until", 0)): continue
		if r.unit_is_encircled(attacker) or r.unit_is_encircled(cover): continue
		var country: = int(attacker.sovereign_id)


		if int(active_by_country.get(country, 0)) >= maxi(1, int(int(country_counts.get(country, 0)) / 8.0)): continue
		var start: Vector2 = attacker.formation_target
		if r._wrapped_geo_delta(Vector2(attacker.longitude, attacker.latitude), start).length_squared() > 0.0225: continue
		var candidate: = _candidate(r, cell, attacker, cover)
		if candidate.is_empty(): continue
		var id: = next_id
		next_id += 1
		operations[id] = {"id": id, "country": country, "side": int(sector.side), "anchor": cell, "cover_cell": cell, "cover_target": start, "start": start, "unit": int(attacker.id), "cover": int(cover.id), "target": candidate.geo, "target_cell": candidate.cell, "kind": candidate.kind, "created": r.sim_tick_count, "failure_since": -1, "secure_since": -1, "phase": "preparing", "route": candidate.route}
		attacker["sector_route"] = candidate.route
		attacker["sector_route_cursor"] = 0
		attacker["sector_recover_until"] = r.sim_tick_count + COMMIT_TICKS
		_set_role(attacker, "Hold", start, r.sim_tick_count, id)
		_set_role(cover, "Cover", start, r.sim_tick_count, id)
		busy[int(attacker.id)] = true
		busy[int(cover.id)] = true
		active_by_country[country] = int(active_by_country.get(country, 0)) + 1

func _candidate(r: RefCounted, cell: int, unit: Dictionary, cover: Dictionary) -> Dictionary:
	var side: = int(unit.side_index)
	var best: Dictionary = {}
	var best_score: = - INF


	var parents: = {cell: -1}
	var queue: Array[int] = [cell]
	var depth: = {cell: 0}
	var approaches: Dictionary = {}
	var cursor: = 0
	while cursor < queue.size():
		var current: = queue[cursor]
		cursor += 1
		for neighbor: int in r._cardinal_indices(current):
			if not r.unit_can_enter_cell(unit, neighbor) or r.land_mask[neighbor] != 2: continue
			if friendly(r, neighbor, side):
				if int(depth[current]) < 3 and not parents.has(neighbor):
					parents[neighbor] = current
					depth[neighbor] = int(depth[current]) + 1
					queue.append(neighbor)
			elif r._effective_side_for_cell(neighbor) == 1 - side and not approaches.has(neighbor): approaches[neighbor] = current
	for next: int in approaches:
		if r.land_mask[next] != 2 or friendly(r, next, side) or not r.unit_can_enter_cell(unit, next): continue
		if r._effective_side_for_cell(next) != 1 - side: continue
		var geo: Vector2 = r.geo_for_grid_index(next)
		var key: Vector2i = r._coverage_key(geo)
		var friendly_force: = 0.0
		var enemy_force: = 0.0
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				for i: int in r._coverage_hash.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
					if i >= r.units.size(): continue
					var nearby: Dictionary = r.units[i]
					if r.city_muster.inactive(nearby): continue
					if r._wrapped_geo_delta(geo, Vector2(nearby.longitude, nearby.latitude)).length_squared() > 0.09: continue
					var force: float = r.unit_personnel(nearby)
					if int(nearby.side_index) == side: friendly_force += force
					else: enemy_force += force
		if friendly_force < enemy_force * 1.25 or friendly_force < r.unit_personnel(unit) + r.unit_personnel(cover) * 0.5: continue
		var support: = 0
		for neighbor: int in r._cardinal_indices(next):
			if friendly(r, neighbor, side): support += 1
		if support == 0: continue
		var weights: = doctrine_weights(r, int(unit.sovereign_id), friendly_force / maxf(500.0, enemy_force), int(r.prewar_de_jure_owners[next]) == int(unit.sovereign_id))
		var kind: = "exploit" if enemy_force < friendly_force * 0.25 else ("flank" if int(approaches[next]) != cell else "advance")
		var city: bool = r.city_cell_set.has(next)
		var score: float = float(weights[kind]) + support + float(city) * float(weights.city) + minf(4.0, friendly_force / maxf(500.0, enemy_force)) - float(depth[approaches[next]]) * 0.5

		score += float(posmod(next ^ operation_seed ^ int(unit.id), 997)) / 997.0
		if score > best_score:
			best_score = score
			var route: Array[int] = [next]
			var previous: int = approaches[next]
			while previous != cell:
				route.push_front(previous)
				previous = parents[previous]
			best = {"cell": next, "geo": geo, "kind": kind, "route": PackedInt32Array(route)}
	return best

func _end(id: int, tick: int, reason: String) -> void :
	var op: Dictionary = operations[id]
	for key: String in ["unit", "cover"]:
		var unit: Dictionary = unit_lookup.get(int(op[key]), {})
		if not unit.is_empty():
			unit["sector_recover_until"] = tick + COMMIT_TICKS
			unit["sector_operation"] = -1
			unit["sector_commit_until"] = 0
			unit.erase("sector_route")
			unit.erase("sector_destination")
	history.append({"id": id, "tick": tick, "reason": reason})
	if history.size() > 128: history.pop_front()
	operations.erase(id)
