extends RefCounted


const DEPTH: = 0.22
var geometry: Dictionary = {}
var slots: Dictionary = {}
var reservations: Dictionary = {}
var last_tick: = -1

var geometry_cache_enabled: = true
var _cached_geometry_revision: = -1
var _cached_cells: Array = []
var _cached_by_side: Array = [[], []]
var _cached_side_front_count: Array = [0, 0]
var _cached_lanes: Array = [0, 0]

func clear() -> void :
	geometry.clear()
	slots.clear()
	reservations.clear()
	last_tick = -1
	_cached_geometry_revision = -1
	_cached_cells.clear()
	_cached_by_side = [[], []]
	_cached_side_front_count = [0, 0]
	_cached_lanes = [0, 0]

func friendly(r: RefCounted, cell: int, side: int) -> bool:
	return cell >= 0 and cell < r.land_mask.size() and r.land_mask[cell] == 2 and (r.occupation[cell] > 0.0 if side == 0 else r.occupation[cell] < 0.0)

func sector_geometry(r: RefCounted, cell: int, side: int) -> Dictionary:
	var signature: = PackedInt32Array()
	var origin: Vector2 = r.geo_for_grid_index(cell)
	var outward: = Vector2.ZERO
	for neighbor: int in r._cardinal_indices(cell):
		var hostile: bool = r.land_mask[neighbor] == 2 and r.occupation[cell] * r.occupation[neighbor] < 0.0
		signature.append(int(hostile))
		if hostile: outward += r._wrapped_geo_delta(origin, r.geo_for_grid_index(neighbor)).normalized()
	if geometry.has(cell) and geometry[cell].signature == signature: return geometry[cell]
	if outward == Vector2.ZERO: return {}
	var normal: = - outward.normalized()


	for adjacent: int in r._cardinal_indices(cell):
		if not r._active_front_cells.has(adjacent) or not friendly(r, adjacent, side): continue
		for neighbor: int in r._cardinal_indices(adjacent):
			if r.land_mask[neighbor] == 2 and r.occupation[adjacent] * r.occupation[neighbor] < 0.0:
				normal -= r._wrapped_geo_delta(r.geo_for_grid_index(adjacent), r.geo_for_grid_index(neighbor)).normalized() * 0.25
	normal = normal.normalized()
	var result: = {"signature": signature, "origin": origin, "normal": normal, "tangent": Vector2( - normal.y, normal.x)}
	geometry[cell] = result
	return result

func update(r: RefCounted, initial: bool = false) -> void :
	if not initial and last_tick >= 0 and r.sim_tick_count - last_tick < 15: return
	last_tick = 0 if initial else r.sim_tick_count
	if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_geometry")
	var cells: Array = _cached_cells
	var by_side: Array = _cached_by_side
	var side_front_count: Array = _cached_side_front_count
	var geometry_revision: = int(r.frontline_geometry_revision)
	var front_geometry_dirty: = not geometry_cache_enabled or _cached_geometry_revision != geometry_revision
	var geometry_dirty: = front_geometry_dirty
	if front_geometry_dirty:
		cells = r._active_front_cells.keys()
		cells.sort()
		by_side = [[], []]
		side_front_count = [0, 0]
		for cell: int in cells:
			side_front_count[0 if r.occupation[cell] > 0.0 else 1] += 1
		if r.performance_profile_enabled: r.exclusive_profile.count(&"front_slot_seed_cells", cells.size())
	var lanes: Array = [
		maxi(1, int(ceil(r.unit_count_for_side(0) / float(maxi(1, side_front_count[0] * 2))))), 
		maxi(1, int(ceil(r.unit_count_for_side(1) / float(maxi(1, side_front_count[1] * 2))))), 
	]
	if lanes != _cached_lanes:
		geometry_dirty = true
	if geometry_dirty:
		var next_slots: Dictionary = {}
		for cell: int in cells:
			var side: = 0 if r.occupation[cell] > 0.0 else 1
			var g: = sector_geometry(r, cell, side)
			if g.is_empty(): continue
			if front_geometry_dirty: by_side[side].append(cell)
			for placement: int in range(2 * lanes[side]):
				var row: = placement % 2
				var lane: = int(placement / 2.0)
				var lateral: float = (float(lane) - (lanes[side] - 1) * 0.5) * 0.05
				var target: Vector2 = g.origin + g.normal * (0.015 if row == 0 else DEPTH * row) + g.tangent * lateral
				var target_cell: int = r.grid_index_for_geo(target.x, target.y)
				if not friendly(r, target_cell, side):
					if row > 0: continue
					target = g.origin
					target_cell = cell
				var id: = "%d:%d:%d:%d" % [side, cell, row, lane]
				next_slots[id] = {"id": id, "cell": cell, "target_cell": target_cell, "target": target, "row": row, "side": side, "normal": g.normal, "tangent": g.tangent}
		slots = next_slots
		_cached_geometry_revision = geometry_revision
		_cached_cells = cells
		_cached_by_side = by_side
		_cached_side_front_count = side_front_count
		_cached_lanes = lanes
		if r.performance_profile_enabled: r.exclusive_profile.count(&"front_slot_geometry_rebuilds")
	else:
		if r.performance_profile_enabled: r.exclusive_profile.count(&"front_slot_geometry_cache_hits")
	if r.performance_profile_enabled: r.exclusive_profile.leave()
	var free_units: Dictionary = {}
	var assigned: Dictionary = {}
	reservations.clear()
	if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_preserve_reservations")
	for i: int in range(r.units.size()):
		var unit: Dictionary = r.units[i]
		if float(unit.health) <= 0.0 or r.city_muster.owns_assignment(unit): continue
		var id: String = unit.get("reserved_slot", "")
		var local_reservation: bool = slots.has(id) and r._wrapped_geo_delta(Vector2(unit.longitude, unit.latitude), slots[id].target).length_squared() < 0.16
		if local_reservation and not reservations.has(id) and r.unit_can_enter_cell(unit, int(slots[id].target_cell)):
			reservations[id] = i
			assigned[i] = true
		else:
			free_units[i] = true
	if r.performance_profile_enabled: r.exclusive_profile.leave()



	var buckets: Dictionary = {}
	if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_unit_buckets")
	for i: int in range(r.units.size()):
		var u: Dictionary = r.units[i]
		if float(u.health) <= 0.0 or r.city_muster.owns_assignment(u): continue
		var key: Vector2i = r._coverage_key(Vector2(u.longitude, u.latitude))
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(i)
	if r.performance_profile_enabled: r.exclusive_profile.leave()
	if not initial:




		var forward_buckets: Dictionary = {}
		if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_forward_vacancies")
		for id: String in slots:
			var slot: Dictionary = slots[id]
			if int(slot.row) != 0 or id.get_slice(":", 3) != "0" or reservations.has(id): continue
			var key: Vector2i = r._coverage_key(slot.target)
			if not forward_buckets.has(key): forward_buckets[key] = []
			forward_buckets[key].append(id)
		for i: int in free_units.keys():
			var u: Dictionary = r.units[i]
			var origin: = Vector2(u.longitude, u.latitude)
			var key: Vector2i = r._coverage_key(origin)
			var best_id: = ""
			var best_score: = INF
			for radius: int in range(5):
				for dy: int in range( - radius, radius + 1):
					for dx: int in range( - radius, radius + 1):
						if radius > 0 and absi(dx) != radius and absi(dy) != radius: continue
						for id: String in forward_buckets.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
							var slot: Dictionary = slots[id]
							if reservations.has(id) or int(slot.side) != int(u.side_index): continue
							var distance: float = r._wrapped_geo_delta(origin, slot.target).length_squared()
							if distance >= best_score or not r.unit_can_enter_cell(u, int(slot.target_cell)): continue
							best_score = distance
							best_id = id


				if best_score < pow(maxf(0.0, float(radius - 1)) * 0.3, 2): break
			if best_id.is_empty(): continue
			reservations[best_id] = i
			assigned[i] = true
			free_units.erase(i)
			u["reserved_slot"] = best_id
			u["formation_assignment_tick"] = r.sim_tick_count
		if r.performance_profile_enabled: r.exclusive_profile.leave()


	if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_assign_layers")
	if r.native_conflict_enabled and r.native_front_slot_assignment_enabled and r._native_conflict_core != null and r._native_conflict_core.has_method("assign_front_slot_layers"):
		var assignment_result: Dictionary = r._native_conflict_core.assign_front_slot_layers(
			r, slots, by_side, PackedInt32Array([int(lanes[0]), int(lanes[1])]), buckets, reservations, assigned, free_units, initial)
		reservations = assignment_result["reservations"]
		assigned = assignment_result["assigned"]
		free_units = assignment_result["free_units"]
	else:
		for layer: int in range(maxi(lanes[0], lanes[1]) * 2):
			var row: = layer % 2
			var lane: = int(layer / 2.0)
			for side: int in range(2):
				if lane >= lanes[side]: continue
				for cell: int in by_side[side]:
					var id: = "%d:%d:%d:%d" % [side, cell, row, lane]
					if not slots.has(id) or reservations.has(id): continue
					var slot: Dictionary = slots[id]
					var best: = -1
					var key: Vector2i = r._coverage_key(slot.target)
					var best_score: = INF
					for radius: int in range(0, 5):
						for dy: int in range( - radius, radius + 1):
							for dx: int in range( - radius, radius + 1):
								if radius > 0 and absi(dx) != radius and absi(dy) != radius: continue
								for i: int in buckets.get(Vector2i(posmod(key.x + dx, 1200), key.y + dy), []):
									var u: Dictionary = r.units[i]
									if int(u.side_index) != side: continue
									var old_id: String = u.get("reserved_slot", "")
									var promotes: bool = row == 0 and slots.has(old_id) and int(slots[old_id].row) > 0
									if assigned.has(i) and not promotes: continue
									if promotes and (r.sim_frame_count - int(u.get("last_combat_tick", -1000)) < 2 or u.get("encircled", false)): continue
									var score: float = r._wrapped_geo_delta(Vector2(u.longitude, u.latitude), slot.target).length_squared()
									if score < best_score or (is_equal_approx(score, best_score) and (best < 0 or int(u.id) < int(r.units[best].id))):


										if not r.unit_can_enter_cell(u, int(slot.target_cell)): continue
										best = i
										best_score = score
						if best >= 0: break
					if best < 0: continue
					var selected: Dictionary = r.units[best]
					reservations.erase(selected.get("reserved_slot", ""))
					reservations[id] = best
					assigned[best] = true
					free_units.erase(best)
					selected["reserved_slot"] = id
					selected["formation_assignment_tick"] = 0 if initial else r.sim_tick_count
	if r.performance_profile_enabled: r.exclusive_profile.leave()


	if not initial:
		if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_rotation")
		for id: String in reservations.keys():
			var slot: Dictionary = slots[id]
			if int(slot.row) != 0: continue
			var front_index: int = reservations[id]
			var front: Dictionary = r.units[front_index]
			if float(front.health) >= 45.0 or front.get("row_rotation", false): continue
			var reserve_id: = "%d:%d:1:%s" % [slot.side, slot.cell, id.get_slice(":", 3)]
			if not reservations.has(reserve_id): continue
			var reserve_index: int = reservations[reserve_id]
			var reserve: Dictionary = r.units[reserve_index]
			if float(reserve.health) < float(front.health) + 30.0 or reserve.get("row_rotation", false): continue
			if not r.unit_can_enter_cell(front, int(slots[reserve_id].target_cell)) or not r.unit_can_enter_cell(reserve, int(slot.target_cell)): continue
			reservations[id] = reserve_index
			reservations[reserve_id] = front_index
			front["row_rotation"] = true
			reserve["row_rotation"] = true
		if r.performance_profile_enabled: r.exclusive_profile.leave()
	if r.performance_profile_enabled: r.exclusive_profile.enter(&"front_slot_commit")
	for id: String in reservations:
		var u: Dictionary = r.units[reservations[id]]
		var slot: Dictionary = slots[id]
		u["reserved_slot"] = id
		u["formation_slot_id"] = id
		u["front_sector"] = slot.cell
		u["formation_row"] = ["forward", "support", "operational"][slot.row]
		u["formation_target"] = slot.target
		u["formation_normal"] = slot.normal
		u["formation_tangent"] = slot.tangent
	for i: int in free_units:
		r.units[i].erase("reserved_slot")
		r.units[i].erase("formation_target")
	if r.performance_profile_enabled: r.exclusive_profile.leave()
