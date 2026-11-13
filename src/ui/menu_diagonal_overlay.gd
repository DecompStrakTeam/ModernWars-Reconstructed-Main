
extends Control

const OVERLAY_COLOR: = Color(0.0, 0.0, 0.0, 0.58)
const EDGE_COLOR: = Color(1.0, 1.0, 1.0, 0.06)


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void :
	var points: = PackedVector2Array([
		Vector2(size.x * 0.25, 0.0), 
		Vector2(size.x, 0.0), 
		Vector2(size.x, size.y), 
		Vector2(0.0, size.y)
	])
	draw_colored_polygon(points, OVERLAY_COLOR)
	draw_line(points[3], points[0], EDGE_COLOR, 1.0)
