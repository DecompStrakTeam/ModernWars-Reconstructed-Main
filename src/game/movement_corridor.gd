class_name MovementCorridor
extends RefCounted




const MAX_CELLS: = 4096

static func wrapped_delta(from: Vector2, to: Vector2) -> Vector2:
	return Vector2(fposmod(to.x - from.x + 180.0, 360.0) - 180.0, to.y - from.y)

static func trace(from: Vector2, to: Vector2, grid: Vector2i) -> Array[Dictionary]:
	return trace_precise(from.x, from.y, to.x, to.y, grid)

static func trace_precise(from_x: float, from_y: float, to_x: float, to_y: float, grid: Vector2i) -> Array[Dictionary]:
	var visits: Array[Dictionary] = []
	if grid.x <= 0 or grid.y <= 0 or not is_finite(from_x) or not is_finite(from_y) or not is_finite(to_x) or not is_finite(to_y):
		return [{"cell": -1, "entry": 0.0, "exit": 1.0}]
	var delta_x: = fposmod(to_x - from_x + 180.0, 360.0) - 180.0
	var delta_y: = to_y - from_y

	var start_x: = fposmod(from_x + 180.0, 360.0) / 360.0 * grid.x
	var start_y: = (90.0 - from_y) / 180.0 * grid.y
	var shift_x: = delta_x / 360.0 * grid.x
	var shift_y: = - delta_y / 180.0 * grid.y
	var cell: = Vector2i(floori(start_x), floori(start_y))
	var goal: = Vector2i(floori(start_x + shift_x), floori(start_y + shift_y))
	var steps: = Vector2i(int(signf(shift_x)), int(signf(shift_y)))
	var limit: = absi(goal.x - cell.x) + absi(goal.y - cell.y) + 3
	if limit > MAX_CELLS:
		return [{"cell": -1, "entry": 0.0, "exit": 1.0}]
	var increment_x: = absf(1.0 / shift_x) if shift_x != 0 else INF
	var increment_y: = absf(1.0 / shift_y) if shift_y != 0 else INF
	var crossing_x: = (cell.x + (1 if steps.x > 0 else 0) - start_x) / shift_x if shift_x != 0 else INF
	var crossing_y: = (cell.y + (1 if steps.y > 0 else 0) - start_y) / shift_y if shift_y != 0 else INF
	var entry: = 0.0
	var bridge_a: = -1
	var bridge_b: = -1
	for _unused: int in range(limit):
		var record: = {"cell": _index(cell, grid), "entry": entry, "exit": minf(1.0, minf(crossing_x, crossing_y))}
		if bridge_a >= 0 or bridge_b >= 0:
			record["bridge_a"] = bridge_a
			record["bridge_b"] = bridge_b
		visits.append(record)
		if cell == goal: return visits
		var next: = minf(crossing_x, crossing_y)
		if next > 1.0: return visits
		bridge_a = -1
		bridge_b = -1
		if absf(crossing_x - crossing_y) < 1e-08:
			bridge_a = _index(cell + Vector2i(steps.x, 0), grid)
			bridge_b = _index(cell + Vector2i(0, steps.y), grid)
			cell += steps
			crossing_x += increment_x
			crossing_y += increment_y
		elif crossing_x < crossing_y:
			cell.x += steps.x
			crossing_x += increment_x
		else:
			cell.y += steps.y
			crossing_y += increment_y
		entry = maxf(0, next)
	return visits

static func _index(cell: Vector2i, grid: Vector2i) -> int:
	return cell.y * grid.x + posmod(cell.x, grid.x) if cell.y >= 0 and cell.y < grid.y else -1

static func clipped(from: Vector2, to: Vector2, grid: Vector2i, legal: Callable) -> Vector2:
	var precise: = clipped_precise(from.x, from.y, to.x, to.y, grid, legal)
	return Vector2(precise[0], precise[1])

static func clipped_precise(from_x: float, from_y: float, to_x: float, to_y: float, grid: Vector2i, legal: Callable) -> PackedFloat64Array:
	if grid.x <= 0 or grid.y <= 0 or not is_finite(from_x) or not is_finite(from_y) or not is_finite(to_x) or not is_finite(to_y):
		return PackedFloat64Array([from_x, from_y])
	var delta_x: = fposmod(to_x - from_x + 180.0, 360.0) - 180.0
	var delta_y: = to_y - from_y
	var length: = sqrt(delta_x * delta_x + delta_y * delta_y)
	for visit: Dictionary in trace_precise(from_x, from_y, to_x, to_y, grid):
		var allowed: bool = legal.call(int(visit["cell"]))
		if visit.has("bridge_a"):
			allowed = allowed and (legal.call(int(visit["bridge_a"])) or legal.call(int(visit["bridge_b"])))


		var interval: = maxf(0, float(visit["exit"]) - float(visit["entry"]))
		var sample_step: = minf(360.0 / grid.x, 180.0 / grid.y) * 0.25
		var samples: = maxi(1, ceili(length * interval / sample_step)) if is_finite(length) else 1
		if allowed:
			for sample: int in range(samples):
				var t: = float(visit["entry"]) + interval * (sample + 0.5) / samples
				var index: = _geo_index(from_x + delta_x * t, from_y + delta_y * t, grid)
				if not legal.call(index):
					allowed = false
					break
		if not allowed:
			if not is_finite(length): return PackedFloat64Array([from_x, from_y])
			var epsilon: = 1e-07 / maxf(length, 1e-07)
			var t: = maxf(0, float(visit["entry"]) - epsilon)
			for attempt: int in range(4):
				var x: = fposmod(from_x + delta_x * t + 180.0, 360.0) - 180.0
				var y: = from_y + delta_y * t
				if legal.call(_geo_index(x, y, grid)): return PackedFloat64Array([x, y])
				t = maxf(0, t - epsilon)
			return PackedFloat64Array([from_x, from_y])
	return PackedFloat64Array([fposmod(to_x + 180.0, 360.0) - 180.0, to_y])

static func _geo_index(x: float, y: float, grid: Vector2i) -> int:
	return _index(Vector2i(floori(fposmod(x + 180.0, 360.0) / 360.0 * grid.x), floori((90.0 - y) / 180.0 * grid.y)), grid)
