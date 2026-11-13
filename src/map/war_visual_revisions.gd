extends RefCounted


const BLOCK_SIZE: = 16
var control_revision: = 0
var unit_revision: = 0
var battle_revision: = 0
var generation: = 0
var grid: = Vector2i.ZERO
var columns: = 0
var occupation_epochs: = PackedInt64Array()
var front_epochs: = PackedInt64Array()

func reset(size: Vector2i) -> void :
	grid = size
	columns = ceili(size.x / float(BLOCK_SIZE))
	var count: = columns * ceili(size.y / float(BLOCK_SIZE))
	occupation_epochs.resize(count)
	front_epochs.resize(count)
	generation += 1
	control_revision += 1
	occupation_epochs.fill(control_revision)
	front_epochs.fill(control_revision)
	publish_dynamic()

func publish_dynamic() -> void :
	unit_revision += 1
	battle_revision += 1

func changed(cell: int, magnitude_changed: bool, owner_changed: bool) -> void :
	if cell < 0 or grid.x <= 0 or cell >= grid.x * grid.y or not (magnitude_changed or owner_changed): return
	control_revision += 1
	var x: = cell % grid.x
	var y: = int(float(cell) / float(grid.x))


	if owner_changed: _mark(x, y, 4, false)
	if magnitude_changed: _mark(x, y, 1, true)

func _mark(x: int, y: int, halo: int, front: bool) -> void :
	var first_y: = int(float(maxi(0, y - halo)) / float(BLOCK_SIZE))
	var last_y: = int(float(mini(grid.y - 1, y + halo)) / float(BLOCK_SIZE))
	var first_x: = floori((x - halo) / float(BLOCK_SIZE))
	var last_x: = floori((x + halo) / float(BLOCK_SIZE))
	for by: int in range(first_y, last_y + 1):
		for bx: int in range(first_x, last_x + 1):
			var key: = by * columns + posmod(bx, columns)
			if front: front_epochs[key] = control_revision
			else: occupation_epochs[key] = control_revision

func region_epoch(region: Rect2i, front: bool) -> int:
	if region.size.x <= 0 or region.size.y <= 0 or columns <= 0: return -1
	var epoch: = 0
	for by: int in range(maxi(0, int(float(region.position.y) / float(BLOCK_SIZE))), mini(ceili(grid.y / float(BLOCK_SIZE)), ceili(region.end.y / float(BLOCK_SIZE)))):
		for bx: int in range(maxi(0, int(float(region.position.x) / float(BLOCK_SIZE))), mini(columns, ceili(region.end.x / float(BLOCK_SIZE)))):
			var key: = by * columns + bx
			epoch = maxi(epoch, front_epochs[key] if front else occupation_epochs[key])
	return epoch
