class_name EncirclementTopology
extends RefCounted



const A_LAND: = 2
const B_LAND: = -2
const OPEN: = 0
const NEUTRAL: = 1
const EMPTY: = 3
const RING_FRACTION: = 0.6

var width: = 0
var height: = 0
var marks: = PackedInt32Array()
var classifications: = PackedInt32Array()
var reached: = PackedByteArray()
var visited: = PackedByteArray()
var stack: = PackedInt32Array()
var component: = PackedInt32Array()
var neighbors: = PackedInt32Array([0, 0, 0, 0])
var active_indices: = PackedInt32Array()
var active_count: = 0

var sealed_components: Array[Dictionary] = []
var release_causes: = PackedByteArray()
var _water_mask: = PackedByteArray()
var _outside_water: = PackedByteArray()
var _water_cache_width: = 0
var _water_cache_height: = 0

func compute(occupation: PackedFloat32Array, land_mask: PackedByteArray, grid: Vector2i, step: int) -> void :
	width = int(ceil(float(grid.x) / step))
	height = int(ceil(float(grid.y) / step))
	var count: = width * height
	var water_changed: = width != _water_cache_width or height != _water_cache_height
	if marks.size() != count:
		marks.resize(count)
		release_causes.resize(count)
		classifications.resize(count)
		reached.resize(count)
		visited.resize(count)
		stack.resize(count)
		component.resize(count)
		active_indices.resize(count)
		_water_mask.resize(count)
		_outside_water.resize(count)
		water_changed = true
	marks.fill(0)
	release_causes.fill(0)
	sealed_components.clear()
	active_count = 0
	var half: = step >> 1
	for cy: int in range(height):
		var row: = mini(grid.y - 1, cy * step + half) * grid.x
		for cx: int in range(width):
			var fine: = row + mini(grid.x - 1, cx * step + half)
			var mask: = land_mask[fine]
			var value: = occupation[fine]
			var coarse: = cy * width + cx
			classifications[coarse] = (A_LAND if value > 0.1 else B_LAND if value < -0.1 else EMPTY) if mask == 2 else NEUTRAL if mask == 1 else OPEN
			var water: = 1 if mask == 0 else 0
			water_changed = water_changed or _water_mask[coarse] != water
			_water_mask[coarse] = water
			if mask == 2:
				active_indices[active_count] = coarse
				active_count += 1
	if water_changed:
		_cache_outside_water()
		_water_cache_width = width
		_water_cache_height = height
	for friendly: int in [A_LAND, B_LAND, EMPTY]:
		_free_flood(friendly)
		_mark_components(friendly)

func fill_neighbors(index: int) -> void :
	var x: = index % width
	var y: = int(index / float(width))
	neighbors[0] = index - width if y > 0 else -1
	neighbors[1] = index + width if y + 1 < height else -1
	neighbors[2] = index - 1 if x > 0 else y * width + width - 1
	neighbors[3] = index + 1 if x + 1 < width else y * width

func _passable(index: int, friendly: int) -> bool:
	var value: = classifications[index]
	return value == OPEN or value == EMPTY or (friendly != EMPTY and value == friendly)

func _seed(index: int, friendly: int, size: int) -> int:
	if reached[index] == 0 and _outside_water[index] == 0 and _passable(index, friendly):
		reached[index] = 1
		stack[size] = index
		return size + 1
	return size

func _free_flood(friendly: int) -> void :
	reached.fill(0)
	var size: = 0




	for offset: int in range(active_count):
		var index: = active_indices[offset]
		var x: = index % width
		var y: = int(index / float(width))
		var outside: = x == 0 or x == width - 1 or y == 0 or y == height - 1
		if not outside:
			fill_neighbors(index)
			for direction: int in range(4):
				if _outside_water[neighbors[direction]] != 0:
					outside = true
					break
		if outside:
			size = _seed(index, friendly, size)
	while size > 0:
		size -= 1
		fill_neighbors(stack[size])
		for direction: int in range(4):
			var next: = neighbors[direction]
			if next >= 0:
				size = _seed(next, friendly, size)

func _mark_components(friendly: int) -> void :
	visited.fill(0)
	for active_offset: int in range(active_count):
		var start: = active_indices[active_offset]
		if visited[start] != 0 or classifications[start] != friendly:
			continue
		var size: = 1
		var count: = 0
		var a_edges: = 0
		var b_edges: = 0
		var other_edges: = 0
		var free: = false
		stack[0] = start
		visited[start] = 1
		while size > 0:
			size -= 1
			var index: = stack[size]
			component[count] = index
			count += 1
			free = free or reached[index] != 0
			fill_neighbors(index)
			for direction: int in range(4):
				var next: = neighbors[direction]
				if next < 0:
					other_edges += 1
					continue
				var value: = classifications[next]
				if value == friendly:
					if visited[next] == 0:
						visited[next] = 1
						stack[size] = next
						size += 1
				elif value == A_LAND:
					a_edges += 1
				elif value == B_LAND:
					b_edges += 1
				else:
					other_edges += 1
		var perimeter: = a_edges + b_edges + other_edges
		if free or perimeter == 0:
			for offset: int in range(count):
				release_causes[component[offset]] = 1
			continue
		var mark: = 0
		if friendly == A_LAND and float(b_edges) / perimeter >= RING_FRACTION:
			mark = 1
		elif friendly == B_LAND and float(a_edges) / perimeter >= RING_FRACTION:
			mark = -1
		elif friendly == EMPTY:
			mark = 2 if float(a_edges) / perimeter >= RING_FRACTION else -2 if float(b_edges) / perimeter >= RING_FRACTION else 0
		if mark != 0:
			var cells: = component.slice(0, count)
			var enemy_edges: = b_edges if mark == 1 or mark == -2 else a_edges
			sealed_components.append({"mark": mark, "cells": cells, "enemy_percent": 100.0 * enemy_edges / perimeter})
			for offset: int in range(count):
				marks[component[offset]] = mark
		else:
			for offset: int in range(count):
				release_causes[component[offset]] = 2

func _cache_outside_water() -> void :
	_outside_water.fill(0)
	var size: = 0
	for index: int in range(marks.size()):
		var x: = index % width
		var y: = int(index / float(width))
		if _water_mask[index] != 0 and (x == 0 or x == width - 1 or y == 0 or y == height - 1):
			_outside_water[index] = 1
			stack[size] = index
			size += 1
	while size > 0:
		size -= 1
		fill_neighbors(stack[size])
		for direction: int in range(4):
			var next: = neighbors[direction]
			if next >= 0 and _water_mask[next] != 0 and _outside_water[next] == 0:
				_outside_water[next] = 1
				stack[size] = next
				size += 1


func collect_mature_component(start: int, timers: PackedInt32Array, minimum: int) -> int:
	var component_mark: = marks[start]
	var size: = 1
	var count: = 0
	stack[0] = start
	visited[start] = 1
	while size > 0:
		size -= 1
		var index: = stack[size]
		component[count] = index
		count += 1
		fill_neighbors(index)
		for direction: int in range(4):
			var next: = neighbors[direction]
			if next >= 0 and visited[next] == 0 and timers[next] >= minimum and marks[next] == component_mark:
				visited[next] = 1
				stack[size] = next
				size += 1
	return count
