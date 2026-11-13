extends RefCounted




const CELL: = 0.5
const COLUMNS: = 720
const RADIUS: = 0.7
var buckets: Dictionary = {}
var fine_keys: = PackedVector2Array()
var source_keys: = PackedVector2Array()
var source_fine_buckets: Dictionary = {}
var count: = 0
var candidate_windows: Dictionary = {}
var window_dependents: Dictionary = {}

func key_for(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(fposmod(point.x + 180.0, 360.0) / CELL)), int(floor((point.y + 90.0) / CELL)))

func rebuild(positions: PackedVector2Array, coarse_keys: PackedVector2Array, living: PackedByteArray) -> void :
	buckets.clear()
	source_fine_buckets.clear()
	candidate_windows.clear()
	window_dependents.clear()
	count = positions.size()
	fine_keys.resize(count)
	source_keys = coarse_keys
	for index: int in range(count):
		var key: = key_for(positions[index])
		fine_keys[index] = Vector2(key)
		if living[index] == 0: continue
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(index)
		var source_key: = Vector2i(source_keys[index])
		if not source_fine_buckets.has(source_key): source_fine_buckets[source_key] = {}
		var source_bucket: Dictionary = source_fine_buckets[source_key]
		if not source_bucket.has(key): source_bucket[key] = []
		source_bucket[key].append(index)

func moved(index: int, point: Vector2) -> void :
	if index < 0 or index >= count: return
	var prior: = Vector2i(fine_keys[index])
	var next: = key_for(point)
	if prior == next: return
	if not source_fine_buckets.has(Vector2i(source_keys[index])): return





	for changed: Vector2i in [prior, next]:
		for window: Vector3i in window_dependents.get(changed, {}):
			candidate_windows.erase(window)
	if buckets.has(prior): buckets[prior].erase(index)
	if not buckets.has(next): buckets[next] = []
	buckets[next].append(index)
	var source_bucket: Dictionary = source_fine_buckets[Vector2i(source_keys[index])]
	source_bucket[prior].erase(index)
	if source_bucket[prior].is_empty(): source_bucket.erase(prior)
	if not source_bucket.has(next): source_bucket[next] = []
	source_bucket[next].append(index)
	fine_keys[index] = Vector2(next)




func nearest_enemy(origin: Vector2, noise: Vector2, coarse_origin: Vector2i, coarse_columns: int, side: int, positions: PackedVector2Array, units: Array[Dictionary], legal: Callable = Callable()) -> int:
	var best: = -1
	var best_distance: = INF
	var best_rank: = 2147483647
	var query: = origin - noise
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var coarse: = Vector2i(posmod(coarse_origin.x + dx, coarse_columns), coarse_origin.y + dy)
			var source_bucket: Dictionary = source_fine_buckets.get(coarse, {})
			for fine: Vector2i in source_bucket:
				var center: = Vector2((fine.x + 0.5) * CELL - 180.0, (fine.y + 0.5) * CELL - 90.0)
				var offset: = center - query
				offset.x = fposmod(offset.x + 180.0, 360.0) - 180.0

				var lower: = Vector2(maxf(0.0, absf(offset.x) - CELL * 0.5 - 0.0001), maxf(0.0, absf(offset.y) - CELL * 0.5 - 0.0001))
				if lower.length_squared() > best_distance: continue
				for index: int in source_bucket[fine]:
					var unit: Dictionary = units[index]
					if int(unit.side_index) == side or float(unit.health) <= 0.0: continue
					var delta: = positions[index] - origin
					delta.x = fposmod(delta.x + 180.0, 360.0) - 180.0
					var distance: = (delta + noise).length_squared()
					var rank: = ((dy + 1) * 3 + dx + 1) * count + index
					if distance > best_distance or (distance == best_distance and rank >= best_rank): continue
					if legal.is_valid() and not legal.call(index): continue
					best = index
					best_distance = distance
					best_rank = rank
	return best

func candidates(origin: Vector2, coarse_origin: Vector2i, coarse_columns: int, positions: PackedVector2Array) -> Array[int]:
	var ordered: Array[int] = []
	for index: int in ordered_window(origin, coarse_origin, coarse_columns):
		var delta: = positions[index] - origin
		if delta.x > 180.0: delta.x -= 360.0
		elif delta.x < -180.0: delta.x += 360.0
		if delta.length_squared() <= RADIUS * RADIUS: ordered.append(index)
	return ordered




func ordered_window(origin: Vector2, coarse_origin: Vector2i, coarse_columns: int) -> Array[int]:
	var center: = key_for(origin)
	var cache_key: = Vector3i(center.x, center.y, coarse_origin.y * coarse_columns + coarse_origin.x)
	if not candidate_windows.has(cache_key):
		var window: Array[int] = []


		for y: int in range(center.y - 2, center.y + 3):
			for x: int in range(center.x - 2, center.x + 3):
				var fine: = Vector2i(posmod(x, COLUMNS), y)
				if not window_dependents.has(fine): window_dependents[fine] = {}
				window_dependents[fine][cache_key] = true
				for index: int in buckets.get(fine, []):
					var source_key: = Vector2i(source_keys[index])
					var dx: = posmod(source_key.x - coarse_origin.x + 1, coarse_columns) - 1
					var dy: = source_key.y - coarse_origin.y
					if dx < -1 or dx > 1 or dy < -1 or dy > 1: continue
					window.append(((dy + 1) * 3 + dx + 1) * count + index)
		window.sort()
		for i: int in range(window.size()): window[i] %= count
		candidate_windows[cache_key] = window
	return candidate_windows[cache_key]
