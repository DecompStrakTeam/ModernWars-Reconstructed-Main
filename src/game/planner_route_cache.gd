extends RefCounted






const BLOCK: = 32
const MAX_ENTRIES: = 128
const MAX_ROUTE_CELLS: = 262144
const MAX_DEPENDENCIES: = 65536
var entries: Dictionary = {}
var epochs: = PackedInt64Array()
var grid: = Vector2i.ZERO
var _columns: = 0
var _sequence: = 0
var _route_cells: = 0
var _dependencies: = 0
var hits: = 0
var misses: = 0
var _profile_roots: Dictionary = {}

func clear() -> void :
	entries.clear()
	epochs.clear()
	grid = Vector2i.ZERO
	_sequence = 0
	_route_cells = 0
	_dependencies = 0
	hits = 0
	misses = 0
	_profile_roots.clear()

func begin_profile_pass() -> void :
	_profile_roots.clear()

func _prepare(size: Vector2i) -> void :
	if size == grid: return
	clear()
	grid = size
	_columns = int(ceil(float(size.x) / BLOCK))
	epochs.resize(_columns * int(ceil(float(size.y) / BLOCK)))
	epochs.fill(0)

func _block(cell: int) -> int:

	var row: = int(float(cell) / float(grid.x))
	var column: = cell % grid.x
	return int(float(row) / float(BLOCK)) * _columns + int(float(column) / float(BLOCK))

func invalidate_cells(cells: PackedInt32Array, size: Vector2i) -> void :
	_prepare(size)
	var changed: Dictionary = {}
	for cell: int in cells:
		if cell >= 0 and cell < grid.x * grid.y: changed[_block(cell)] = true
	for block: int in changed: epochs[block] += 1

func find(r: RefCounted, start: int, goal: int, country: int, defensive: bool, visit_limit: int) -> PackedInt32Array:
	_prepare(r.grid_size)
	var key: = Vector3i(start, goal, country if defensive else -1)
	_sequence += 1
	if entries.has(key):
		var entry: Dictionary = entries[key]
		var valid: bool = entry.limit == visit_limit
		for i: int in range(entry.blocks.size()):
			if epochs[entry.blocks[i]] != entry.epochs[i]:
				valid = false
				break
		if valid:
			hits += 1
			entry.used = _sequence

			return (entry.route as PackedInt32Array).duplicate()
		_erase(key)
	misses += 1
	if r.performance_profile_enabled: r.exclusive_profile.count(&"planner_bfs_calls")
	if start < 0 or goal < 0: return PackedInt32Array()
	return _dictionary_search(r, key, start, goal, country, defensive, visit_limit)


func _dictionary_search(r: RefCounted, key: Vector3i, start: int, goal: int, country: int, defensive: bool, visit_limit: int) -> PackedInt32Array:
	if r.native_conflict_enabled and r.native_planner_route_enabled and r._native_conflict_core != null and r._native_conflict_core.has_method("planner_route_search"):
		if r.performance_profile_enabled: r.exclusive_profile.enter(&"planner_route_native_search")
		var native_result: Dictionary = r._native_conflict_core.planner_route_search(r, start, goal, country, defensive, visit_limit)
		if r.performance_profile_enabled: r.exclusive_profile.leave()
		var native_dependencies: Dictionary = {}
		for block: int in native_result.get("dependencies", PackedInt32Array()):
			native_dependencies[block] = true
		var native_route: PackedInt32Array = native_result.get("route", PackedInt32Array())
		_store(key, native_route, native_dependencies, visit_limit)
		_record_search(r, start, country, defensive, visit_limit, int(native_result.get("expanded", 0)))
		return native_route
	var queue: = PackedInt32Array([start])
	var parent: Dictionary = {start: -1}
	var dependencies: Dictionary = {}
	var cursor: = 0
	while cursor < queue.size() and cursor < visit_limit:
		var cell: = queue[cursor]
		cursor += 1
		dependencies[_block(cell)] = true
		if cell == goal: break
		for next: int in r._cardinal_indices(cell):
			dependencies[_block(next)] = true
			if parent.has(next) or r.land_mask[next] != 2: continue
			if defensive and r.prewar_de_jure_owners[next] != country: continue
			parent[next] = cell
			queue.append(next)
	var route: = PackedInt32Array()
	if parent.has(goal):
		var cell: = goal
		while cell >= 0:
			route.append(cell)
			cell = int(parent[cell])
		route.reverse()
	_store(key, route, dependencies, visit_limit)
	var expanded: = cursor
	if cursor > 0 and queue[cursor - 1] == goal: expanded -= 1
	_record_search(r, start, country, defensive, visit_limit, expanded)
	return route

func _record_search(r: RefCounted, start: int, country: int, defensive: bool, visit_limit: int, expanded: int) -> void :
	if not r.performance_profile_enabled: return

	var root_key: = Vector3i(start, country if defensive else -1, visit_limit)
	var previous_max: = int(_profile_roots.get(root_key, 0))
	r.exclusive_profile.count(&"planner_bfs_same_root_misses", 1 if _profile_roots.has(root_key) else 0)
	r.exclusive_profile.count(&"planner_bfs_expanded", expanded)
	r.exclusive_profile.count(&"planner_bfs_duplicate_prefix", mini(expanded, previous_max))
	_profile_roots[root_key] = maxi(expanded, previous_max)

func _store(key: Vector3i, route: PackedInt32Array, dependencies: Dictionary, visit_limit: int) -> void :
	if route.size() > MAX_ROUTE_CELLS or dependencies.size() > MAX_DEPENDENCIES: return
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or _route_cells + route.size() > MAX_ROUTE_CELLS or _dependencies + dependencies.size() > MAX_DEPENDENCIES):
		var oldest: Vector3i = entries.keys()[0]
		for candidate: Vector3i in entries:
			if int(entries[candidate].used) < int(entries[oldest].used): oldest = candidate
		_erase(oldest)
	var blocks: = PackedInt32Array(dependencies.keys())
	var stamps: = PackedInt64Array()
	stamps.resize(blocks.size())
	for i: int in range(blocks.size()): stamps[i] = epochs[blocks[i]]
	entries[key] = {"route": route.duplicate(), "blocks": blocks, "epochs": stamps, "used": _sequence, "limit": visit_limit}
	_route_cells += route.size()
	_dependencies += blocks.size()

func _erase(key: Vector3i) -> void :
	_route_cells -= entries[key].route.size()
	_dependencies -= entries[key].blocks.size()
	entries.erase(key)

func stats() -> Dictionary:
	return {"entries": entries.size(), "route_cells": _route_cells, "dependencies": _dependencies, 
		"packed_bytes": _route_cells * 4 + _dependencies * 12 + epochs.size() * 8, 
		"hits": hits, "misses": misses}
