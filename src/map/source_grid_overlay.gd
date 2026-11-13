extends Control



const BORDER_SHADER: Shader = preload("res://src/map/source_grid_border.gdshader")
var borders: = false
var _source_texture: Texture2D
var _origin: = Vector2.ZERO
var _width: = 0.0
var _view_size: = Vector2.ZERO

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if borders:
		var border_material: = ShaderMaterial.new()
		border_material.shader = BORDER_SHADER
		material = border_material
	_sync_view()

func _process(_delta: float) -> void :
	_sync_view()

func _sync_view() -> void :
	var map_view: = get_parent() as CampaignMapView
	if map_view == null:
		return
	var next_texture: = map_view._static_border_texture if borders else map_view.texture
	var next_origin: = map_view._world_origin()
	var next_width: = map_view._world_width()
	if next_texture == _source_texture and next_origin == _origin and next_width == _width and map_view.size == _view_size:
		return
	_source_texture = next_texture
	_origin = next_origin
	_width = next_width
	_view_size = map_view.size
	queue_redraw()

func _draw() -> void :
	if _source_texture == null or _width <= 0.0:
		return
	var first_copy: = int(floor( - _origin.x / _width))
	var last_copy: = int(floor((size.x - _origin.x) / _width))
	var tint: = Color.WHITE if borders else Color(1, 1, 1, CampaignMapView.POLITICAL_OVERLAY_ALPHA)
	for copy_index: int in range(first_copy, last_copy + 1):
		draw_texture_rect(_source_texture, Rect2(_origin + Vector2(copy_index * _width, 0.0), Vector2.ONE * _width), false, tint)
