class_name LandPocketResolver
extends RefCounted



enum Outcome{OPEN, INLAND_SEALED, COASTAL_CONTAINED}
const CITY_SECONDS: = 5.0
var grid: = Vector2i.ZERO
var classes: = PackedInt32Array()
var dirty: Dictionary = {}
var components: Dictionary = {}


var labels: = PackedInt32Array()
var cell_to_local: = PackedInt32Array()
var local_to_cell: = PackedInt32Array()
var _next_id: = 1
var _water_kind: = PackedByteArray()
var _lakes: Dictionary = {}
var _lake_ids: Dictionary = {}
var _next_lake: = 1
var revision: = 0
var scanned_cells: = 0
var block_cache: RefCounted
var block_cache_enabled: = true
var native_graph_enabled: = true
var native_core: Object = null

func initialize(mask: PackedByteArray, control: PackedFloat32Array, size: Vector2i, theater: PackedInt32Array) -> void :
	grid = size
	classes.resize(mask.size())
	classes.fill(0)
	cell_to_local.resize(mask.size())
	cell_to_local.fill(-1)
	local_to_cell.resize(0)
	dirty.clear()
	components.clear()
	_next_id = 1
	_water_kind.resize(mask.size())
	_water_kind.fill(0)
	_lakes.clear()
	_lake_ids.clear()
	_next_lake = 1
	for cell: int in theater:
		if cell_to_local[cell] < 0:
			cell_to_local[cell] = local_to_cell.size()
			local_to_cell.append(cell)
		classes[cell] = classification(control[cell])
		dirty[cell] = true
	labels.resize(local_to_cell.size() * 3)
	labels.fill(0)
	block_cache = null
	revision += 1

static func classification(control: float) -> int:
	return 2 if control > 0.1 else -2 if control < -0.1 else 3

func changed(cell: int, control: float) -> void :
	var next_class: = classification(control)
	if cell >= 0 and cell < classes.size() and classes[cell] != next_class:
		classes[cell] = next_class
		dirty[cell] = true

func neighbors(cell: int) -> PackedInt32Array:
	var x: = cell % grid.x
	return PackedInt32Array([cell - grid.x if cell >= grid.x else -1, cell + grid.x if cell < grid.x * (grid.y - 1) else -1, cell - 1 if x > 0 else cell + grid.x - 1, cell + 1 if x < grid.x - 1 else cell - grid.x + 1])




func _water(cell: int, mask: PackedByteArray) -> Dictionary:
	if _water_kind[cell] == 2:
		return {"outside": true}
	if _water_kind[cell] == 1:
		return _lakes[_lake_ids[cell]]



	if _prove_ocean_route(cell, mask):
		return {"outside": true}
	var stack: = PackedInt32Array([cell])
	var visited: = PackedInt32Array()
	var shore: Dictionary = {}
	_water_kind[cell] = 3
	var outside: = false
	while not stack.is_empty() and not outside:
		var current: = stack[-1]
		stack.resize(stack.size() - 1)
		visited.append(current)
		var water_neighbors: = neighbors(current)
		for neighbor_index: int in range(3, -1, -1):
			var adjacent: = water_neighbors[neighbor_index]
			if adjacent < 0:
				outside = true
			elif mask[adjacent] != 0:
				shore[adjacent] = true
			elif _water_kind[adjacent] == 2:
				outside = true
			elif _water_kind[adjacent] == 0:
				_water_kind[adjacent] = 3
				stack.append(adjacent)

	visited.append_array(stack)
	var info: = {"outside": outside, "shore": PackedInt32Array(shore.keys())}
	var lake_id: = _next_lake
	if not outside:
		_next_lake += 1
		_lakes[lake_id] = info
	for index: int in visited:
		_water_kind[index] = 2 if outside else 1
		if not outside:
			_lake_ids[index] = lake_id
	return info

func _water_ray(cell: int, mask: PackedByteArray, vertical_step: int) -> PackedInt32Array:
	var route: = PackedInt32Array()
	var current: = cell
	while current >= 0 and current < mask.size() and mask[current] == 0:
		route.append(current)
		if _water_kind[current] == 2 or current < grid.x or current >= grid.x * (grid.y - 1):
			return route
		current += vertical_step
	return PackedInt32Array()

func _prove_ocean_route(cell: int, mask: PackedByteArray) -> bool:
	for vertical_step: int in [ - grid.x, grid.x]:
		var route: = _water_ray(cell, mask, vertical_step)
		if not route.is_empty():
			for proven: int in route:
				_water_kind[proven] = 2
			return true
	for horizontal_step: int in [-1, 1]:
		var prefix: = PackedInt32Array([cell])
		var current: = cell
		for distance: int in range(1, mini(257, grid.x)):
			var row: = current - current % grid.x
			current = row + posmod(current % grid.x + horizontal_step, grid.x)
			if mask[current] != 0:
				break
			prefix.append(current)
			if _water_kind[current] == 2:
				for proven: int in prefix:
					_water_kind[proven] = 2
				return true
			if distance in [16, 64, 128, 256]:
				for vertical_step: int in [ - grid.x, grid.x]:
					var route: = _water_ray(current, mask, vertical_step)
					if not route.is_empty():
						prefix.append_array(route)
						for proven: int in prefix:
							_water_kind[proven] = 2
						return true
	return false

func _passable(cell: int, side: int) -> bool:
	var value: = classes[cell] if cell >= 0 and cell < classes.size() else 0
	return value == 3 if side == 2 else value == (2 if side == 0 else -2) or value == 3

func label_at(cell: int, side: int) -> int:
	if cell < 0 or cell >= classes.size() or side < 0 or side > 2:
		return 0
	var local: = cell_to_local[cell]
	var label: = 0 if local < 0 else labels[side * local_to_cell.size() + local]
	return int(block_cache.node_components.get(label, 0)) if block_cache != null else label

func _set_label(cell: int, side: int, identity: int) -> void :
	var local: = cell_to_local[cell]
	if local >= 0:
		labels[side * local_to_cell.size() + local] = identity

func refresh(mask: PackedByteArray, now_seconds: float, current_tick: int = 0) -> void :
	if dirty.is_empty():
		return
	if block_cache_enabled and local_to_cell.size() > 4096:
		if block_cache == null:
			block_cache = load("res://src/game/pocket_component_cache.gd").new()
		block_cache.native_core = native_core
		block_cache.native_graph_enabled = native_graph_enabled
		block_cache.refresh(self, mask, now_seconds, current_tick)
		return
	scanned_cells = 0
	var seeds: Dictionary = dirty.duplicate()
	dirty.clear()
	var previous: Dictionary = {}



	var previous_labels: = labels.duplicate()
	for changed_cell: int in seeds.keys():
		for adjacent: int in neighbors(changed_cell):
			if adjacent >= 0:
				seeds[adjacent] = true


				if mask[adjacent] == 0 and _water_kind[adjacent] == 1:
					for shore_cell: int in _lakes[_lake_ids[adjacent]]["shore"]:
						seeds[shore_cell] = true
	for side: int in range(3):
		var label_base: = side * local_to_cell.size()
		var invalid: Dictionary = {}
		for cell: int in seeds:
			var local: = cell_to_local[cell]
			var identity: = labels[label_base + local] if local >= 0 else 0
			if identity != 0:
				invalid[identity] = true
		for identity: int in invalid:
			var old: Dictionary = components[identity]
			previous[identity] = old
			for cell: int in old["members"]:
				labels[label_base + cell_to_local[cell]] = 0
				seeds[cell] = true
			components.erase(identity)
		var rebuilt: Array[Dictionary] = []
		for seed_cell: int in seeds:
			var seed_class: = classes[seed_cell] if seed_cell >= 0 and seed_cell < classes.size() else 0
			var seed_passable: = seed_class == 3 if side == 2 else seed_class == (2 if side == 0 else -2) or seed_class == 3
			var seed_local: = cell_to_local[seed_cell] if seed_cell >= 0 and seed_cell < cell_to_local.size() else -1
			if not seed_passable or seed_local < 0 or labels[label_base + seed_local] != 0:
				continue
			var identity: = _next_id
			_next_id += 1
			var members: = PackedInt32Array()
			var owned: = PackedInt32Array()
			var stack: = PackedInt32Array([seed_cell])
			var lakes_seen: Dictionary = {}
			var sea: = false
			var free_land: = false
			var empty_sea_route: = false
			var enemy_edges: = 0
			var a_edges: = 0
			var b_edges: = 0
			var other_edges: = 0
			labels[label_base + seed_local] = identity
			while not stack.is_empty():
				var cell: = stack[-1]
				stack.resize(stack.size() - 1)
				members.append(cell)
				scanned_cells += 1
				var is_owned: = side == 2 or int(classes[cell]) != 3
				if is_owned:
					owned.append(cell)



				var x: = cell % grid.x
				for neighbor_index: int in range(4):
					var adjacent: = -1
					match neighbor_index:
						0: adjacent = cell - grid.x if cell >= grid.x else -1
						1: adjacent = cell + grid.x if cell < grid.x * (grid.y - 1) else -1
						2: adjacent = cell - 1 if x > 0 else cell + grid.x - 1
						_: adjacent = cell + 1 if x < grid.x - 1 else cell - grid.x + 1
					if adjacent < 0:
						free_land = true
						other_edges += 1 if is_owned else 0
					else:
						var adjacent_class: = classes[adjacent]
						var adjacent_passable: = adjacent_class == 3 if side == 2 else adjacent_class == (2 if side == 0 else -2) or adjacent_class == 3
						if adjacent_passable:
							if is_owned and side != 2 and adjacent_class == 3:
								other_edges += 1
							var adjacent_local: = cell_to_local[adjacent]
							if adjacent_local >= 0 and labels[label_base + adjacent_local] == 0:
								labels[label_base + adjacent_local] = identity
								stack.append(adjacent)
						elif mask[adjacent] == 0:
							other_edges += 1 if is_owned else 0
							var water: = _water(adjacent, mask)
							if water["outside"]:
								sea = true
								empty_sea_route = empty_sea_route or not is_owned
							elif not lakes_seen.has(_lake_ids[adjacent]):
								lakes_seen[_lake_ids[adjacent]] = true
								for shore_cell: int in water["shore"]:
									var shore_class: = classes[shore_cell]
									var shore_passable: = shore_class == 3 if side == 2 else shore_class == (2 if side == 0 else -2) or shore_class == 3
									var shore_local: = cell_to_local[shore_cell]
									if shore_passable and shore_local >= 0 and labels[label_base + shore_local] == 0:
										labels[label_base + shore_local] = identity
										stack.append(shore_cell)
						else:
							if is_owned:
								if side == 2:
									if adjacent_class == 2:
										a_edges += 1
									elif adjacent_class == -2:
										b_edges += 1
									else:
										other_edges += 1
								elif adjacent_class == (-2 if side == 0 else 2):
									enemy_edges += 1
								else:
									other_edges += 1
			if side == 2:
				enemy_edges = maxi(a_edges, b_edges)
				other_edges += mini(a_edges, b_edges)
			var pressure: = float(enemy_edges) / maxf(1, enemy_edges + other_edges)
			var outcome: = Outcome.OPEN
			if not owned.is_empty() and not free_land and not empty_sea_route and pressure >= 0.6:
				outcome = Outcome.COASTAL_CONTAINED if sea else Outcome.INLAND_SEALED
				if side == 2 and sea:
					outcome = Outcome.OPEN
			var record: = {"id": identity, "side": side, "members": members, "owned": owned, "outcome": outcome, "pressure": pressure, "since": now_seconds, "since_tick": current_tick, "captured_side": 0 if a_edges >= b_edges else 1, "cities": 0, "allowance": 0.0}
			var parents: Dictionary = {}
			if outcome != Outcome.OPEN:
				for overlap_cell: int in owned:
					var overlap_local: = cell_to_local[overlap_cell]
					var parent_id: = previous_labels[label_base + overlap_local] if overlap_local >= 0 else 0
					if parent_id == 0 or parents.has(parent_id) or not previous.has(parent_id):
						continue
					var parent: Dictionary = previous[parent_id]
					if parent["side"] == side and parent["outcome"] == outcome:
						parents[parent_id] = true
			if parents.size() == 1:
				record["since"] = previous[parents.keys()[0]]["since"]
				record["since_tick"] = previous[parents.keys()[0]]["since_tick"]
			record["parents"] = parents
			components[identity] = record
			rebuilt.append(record)

		var children: Dictionary = {}
		for record: Dictionary in rebuilt:
			for parent_id: int in record["parents"]:
				children[parent_id] = int(children.get(parent_id, 0)) + 1
		for record: Dictionary in rebuilt:
			for parent_id: int in record["parents"]:
				if int(children[parent_id]) > 1:
					record["since"] = now_seconds
					record["since_tick"] = current_tick
			record.erase("parents")
	revision += 1

func outcome_at(cell: int, side: int) -> int:
	var identity: = label_at(cell, side)
	if identity == 0 or classes[cell] != (2 if side == 0 else -2):
		return Outcome.OPEN
	return int(components[identity]["outcome"])

func ready(city_cells: PackedInt32Array, controller: Callable, now_seconds: float, current_tick: int = 0) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for identity: int in components:
		var pocket: Dictionary = components[identity]
		if int(pocket["outcome"]) != Outcome.INLAND_SEALED:
			continue
		if int(pocket["side"]) == 2:
			if current_tick - int(pocket["since_tick"]) >= 120:
				resolved.append(pocket)
			continue
		var city_count: = 0
		for cell: int in city_cells:
			if label_at(cell, int(pocket["side"])) == identity and int(controller.call(cell)) == int(pocket["side"]):
				city_count += 1
		pocket["cities"] = city_count
		pocket["allowance"] = CITY_SECONDS * city_count
		if now_seconds - float(pocket["since"]) + 1e-07 >= float(pocket["allowance"]):
			resolved.append(pocket)
	return resolved

func diagnostic_state() -> Array:
	var state: = []
	for identity: int in components:
		var pocket: Dictionary = components[identity]
		if int(pocket["outcome"]) != Outcome.OPEN:
			state.append([pocket["side"], pocket["outcome"], pocket["owned"], pocket["since"], pocket["cities"], pocket["allowance"]])
	return state
