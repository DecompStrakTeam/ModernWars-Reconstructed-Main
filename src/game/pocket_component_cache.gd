extends RefCounted




const BLOCK: = 16
var blocks: Dictionary = {}
var nodes: Dictionary = {}
var node_components: Dictionary = {}
var next_node: = 1
var native_core: Object = null
var native_graph_enabled: = true
var last_block_usec: = 0
var last_graph_usec: = 0
var last_dirty_blocks: = 0
var last_graph_nodes: = 0
var last_refresh_tick: = -1

func block_of(cell: int, width: int) -> Vector2i:

	return Vector2i(floori(float(cell % width) / float(BLOCK)), floori(float(cell) / float(width * BLOCK)))

func refresh(r: RefCounted, mask: PackedByteArray, now: float, tick: int) -> void :
	last_refresh_tick = tick
	var changed_blocks: Dictionary = {}
	for cell: int in r.dirty:
		changed_blocks[block_of(cell, r.grid.x)] = true
		for adjacent: int in r.neighbors(cell):
			if adjacent >= 0 and r.cell_to_local[adjacent] >= 0:
				changed_blocks[block_of(adjacent, r.grid.x)] = true
	r.dirty.clear()
	r.scanned_cells = 0
	var prior_components: Dictionary = r.components
	var prior_nodes: = node_components.duplicate()
	var prior_cells: Dictionary = {}
	var ordered_blocks: Array = changed_blocks.keys()
	last_dirty_blocks = ordered_blocks.size()
	ordered_blocks.sort_custom( func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for key: Vector2i in ordered_blocks:
		for node_id: int in blocks.get(key, []):
			var old: Dictionary = nodes[node_id]
			var base: int = int(old.side) * r.local_to_cell.size()
			for cell: int in old.members:
				var local: int = r.cell_to_local[cell]
				prior_cells[base + local] = int(prior_nodes.get(node_id, 0))
				r.labels[base + local] = 0
			nodes.erase(node_id)
		blocks[key] = []
	var block_started: = Time.get_ticks_usec()
	if native_core != null and is_instance_valid(native_core) and native_core.has_method("build_pocket_blocks"):
		var water_results: Dictionary = {}
		for key: Vector2i in ordered_blocks:
			var x0: = key.x * BLOCK
			var y0: = key.y * BLOCK
			var x1: = mini(x0 + BLOCK, r.grid.x)
			var y1: = mini(y0 + BLOCK, r.grid.y)
			for side: int in range(3):
				for y: int in range(y0, y1):
					for x: int in range(x0, x1):
						var cell: int = y * r.grid.x + x
						if r.cell_to_local[cell] < 0 or not r._passable(cell, side): continue
						for adjacent: int in r.neighbors(cell):
							if adjacent >= 0 and mask[adjacent] == 0 and not water_results.has(adjacent):
								water_results[adjacent] = r._water(adjacent, mask)
		var native_scanned: int = native_core.build_pocket_blocks(self, r, mask, water_results, ordered_blocks, BLOCK)
		if native_scanned < 0:
			push_error("Native pocket block builder rejected a precomputed water boundary")
			return
	else:
		for key: Vector2i in ordered_blocks:
			_build_block(r, mask, key)
	last_block_usec = Time.get_ticks_usec() - block_started
	var graph_started: = Time.get_ticks_usec()
	last_graph_nodes = nodes.size()
	if native_graph_enabled and native_core != null and is_instance_valid(native_core) and native_core.has_method("join_pocket_graph"):
		native_core.join_pocket_graph(self, r, changed_blocks, prior_nodes, prior_cells, prior_components, now, tick)
		last_graph_usec = Time.get_ticks_usec() - graph_started
		return


	node_components.clear()
	var records: Dictionary = {}
	var children: Dictionary = {}
	for start: int in nodes:
		if node_components.has(start): continue
		var id: int = r._next_id
		r._next_id += 1
		var side: int = nodes[start].side
		var group: = PackedInt32Array([start])
		node_components[start] = id
		var cursor: = 0
		var enemy: = 0
		var other: = 0
		var a: = 0
		var b: = 0
		var sea: = false
		var free: = false
		var empty_sea: = false
		var count: = 0
		var parents: Dictionary = {}
		while cursor < group.size():
			var n: int = group[cursor]
			cursor += 1
			var node: Dictionary = nodes[n]
			enemy += int(node.enemy)
			other += int(node.other)
			a += int(node.a)
			b += int(node.b)
			sea = sea or bool(node.sea)
			free = free or bool(node.free)
			empty_sea = empty_sea or bool(node.empty_sea)
			count += node.owned.size()
			var parent: = int(prior_nodes.get(n, 0))
			if parent != 0: parents[parent] = true
			if changed_blocks.has(node.block):
				for cell: int in node.owned:
					parent = int(prior_cells.get(side * r.local_to_cell.size() + r.cell_to_local[cell], 0))
					if parent != 0: parents[parent] = true
			for exit_cell: int in node.exits:
				var local: int = r.cell_to_local[exit_cell]
				if local < 0: continue
				var adjacent: int = r.labels[side * r.local_to_cell.size() + local]
				if adjacent != 0 and not node_components.has(adjacent):
					node_components[adjacent] = id
					group.append(adjacent)
		if side == 2:
			enemy = maxi(a, b)
			other += mini(a, b)
		var pressure: = float(enemy) / maxf(1.0, enemy + other)
		var outcome: = 0
		if count > 0 and not free and not empty_sea and pressure >= 0.6:
			outcome = 2 if sea else 1
			if side == 2 and sea: outcome = 0
		var owned: = PackedInt32Array()
		var members: = PackedInt32Array()


		if outcome != 0:
			for n: int in group:
				owned.append_array(nodes[n].owned)
				members.append_array(nodes[n].members)
		var valid_parents: Dictionary = {}
		for p: int in parents:
			if prior_components.has(p) and int(prior_components[p].outcome) == outcome and outcome != 0:
				valid_parents[p] = true
		var since: = now
		var since_tick: = tick
		if valid_parents.size() == 1:
			var p: int = valid_parents.keys()[0]
			since = prior_components[p].since
			since_tick = prior_components[p].since_tick
		for p: int in valid_parents: children[p] = int(children.get(p, 0)) + 1
		records[id] = {"id": id, "side": side, "members": members, "owned": owned, "outcome": outcome, "pressure": pressure, "since": since, "since_tick": since_tick, "captured_side": 0 if a >= b else 1, "cities": 0, "allowance": 0.0, "parents": valid_parents}
	for record: Dictionary in records.values():
		for p: int in record.parents:
			if int(children[p]) > 1:
				record.since = now
				record.since_tick = tick
		record.erase("parents")
	r.components = records
	r.revision += 1
	last_graph_usec = Time.get_ticks_usec() - graph_started

func _build_block(r: RefCounted, mask: PackedByteArray, key: Vector2i) -> void :
	var x0: = key.x * BLOCK
	var y0: = key.y * BLOCK
	var x1: = mini(x0 + BLOCK, r.grid.x)
	var y1: = mini(y0 + BLOCK, r.grid.y)
	for side: int in range(3):
		var base: int = side * r.local_to_cell.size()
		for y: int in range(y0, y1):
			for x: int in range(x0, x1):
				var seed_cell: int = y * r.grid.x + x
				var local: int = r.cell_to_local[seed_cell]
				if local < 0 or not r._passable(seed_cell, side) or r.labels[base + local] != 0: continue
				var id: = next_node
				next_node += 1
				var members: = PackedInt32Array([seed_cell])
				var owned: = PackedInt32Array()
				var exits: Dictionary = {}
				var node: = {"side": side, "block": key, "enemy": 0, "other": 0, "a": 0, "b": 0, "sea": false, "free": false, "empty_sea": false}
				r.labels[base + local] = id
				var cursor: = 0
				while cursor < members.size():
					var cell: = members[cursor]
					cursor += 1
					r.scanned_cells += 1
					var is_owned: bool = side == 2 or r.classes[cell] != 3
					if is_owned: owned.append(cell)
					for adjacent: int in r.neighbors(cell):
						if adjacent < 0:
							node.free = true
							node.other += 1 if is_owned else 0
						elif r._passable(adjacent, side):
							if is_owned and side != 2 and r.classes[adjacent] == 3: node.other += 1
							if block_of(adjacent, r.grid.x) != key:
								exits[adjacent] = true
							else:
								var adjacent_local: int = r.cell_to_local[adjacent]
								if adjacent_local >= 0 and r.labels[base + adjacent_local] == 0:
									r.labels[base + adjacent_local] = id
									members.append(adjacent)
						elif mask[adjacent] == 0:
							node.other += 1 if is_owned else 0
							var water: Dictionary = r._water(adjacent, mask)
							if water.outside:
								node.sea = true
								node.empty_sea = bool(node.empty_sea) or not is_owned
							else:
								for shore: int in water.shore:


									exits[shore] = true
						elif is_owned:
							if side == 2:
								if r.classes[adjacent] == 2: node.a += 1
								elif r.classes[adjacent] == -2: node.b += 1
								else: node.other += 1
							elif r.classes[adjacent] == (-2 if side == 0 else 2): node.enemy += 1
							else: node.other += 1
				node.members = members
				node.owned = owned
				node.exits = PackedInt32Array(exits.keys())
				nodes[id] = node
				blocks[key].append(id)
