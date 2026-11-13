extends RefCounted



var usec: Dictionary = {}
var counts: Dictionary = {}
var dirty_blocks: Dictionary = {}
var dirty_sectors: Dictionary = {}
var changed_cells: Dictionary = {}
var _stack: Array[StringName] = []
var _last: = 0

func begin(now: int = -1) -> void :
	usec.clear()
	counts.clear()
	dirty_blocks.clear()
	dirty_sectors.clear()
	changed_cells.clear()
	_stack.clear()
	_stack.append(&"other_simulation")
	_last = Time.get_ticks_usec() if now < 0 else now

func enter(label: StringName, now: int = -1) -> void :
	if _stack.is_empty(): return
	_charge(Time.get_ticks_usec() if now < 0 else now)
	_stack.append(label)

func leave(now: int = -1) -> void :
	if _stack.size() < 2: return
	_charge(Time.get_ticks_usec() if now < 0 else now)
	_stack.pop_back()

func finish(now: int = -1) -> void :
	if _stack.is_empty(): return
	_charge(Time.get_ticks_usec() if now < 0 else now)
	assert (_stack.size() == 1, "Unbalanced performance trace scopes")
	_stack.clear()
	counts[&"dirty_control_blocks"] = dirty_blocks.size()
	counts[&"dirty_front_sectors"] = dirty_sectors.size()
	counts[&"control_sign_changed_cells"] = dirty_sectors.size()
	counts[&"occupation_changed_cells"] = changed_cells.size()


func occupation_written(cell: int, width: int) -> void :
	changed_cells[cell] = true
	control_changed(cell, width, false)

func count(label: StringName, amount: int = 1) -> void :
	counts[label] = int(counts.get(label, 0)) + amount

func control_changed(cell: int, width: int, front_changed: bool) -> void :
	var x: = cell % width
	var y: = int(float(cell) / float(width))
	dirty_blocks[Vector2i(int(float(x) / 16.0), int(float(y) / 16.0))] = true
	if front_changed: dirty_sectors[cell] = true

func _charge(now: int) -> void :
	var label: StringName = _stack[-1]
	usec[label] = int(usec.get(label, 0)) + now - _last
	_last = now
