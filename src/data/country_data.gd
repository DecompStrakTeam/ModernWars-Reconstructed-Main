extends Resource

@export var id: int = 0
@export var country_name: String = ""
@export var color: Color = Color(0.59, 0.59, 0.59, 1.0)
@export var color_source: String = "rgba(150, 150, 150, 0.5)"
@export var is_custom: bool = false
@export var flag_url: String = ""
@export var role: String = ""
@export var overlord_id: int = -1
@export var releasable_by: int = -1
@export var allies: Array[int] = []
@export var saved_cells: Array[Vector2i] = []
