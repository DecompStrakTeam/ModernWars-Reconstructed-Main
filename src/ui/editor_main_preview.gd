@tool
extends TextureRect



const CAPTURE: = "res://docs/verification/latest-main-preview.png"
var _seen_digest: = ""
var _poll_elapsed: = 1.0

func _validate_property(property: Dictionary) -> void :
	if property["name"] == "texture":

		property["usage"] = int(property["usage"]) & ~ PROPERTY_USAGE_STORAGE

func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		hide()
		set_process(false)
		queue_free()
		return
	tooltip_text = "Latest actual Main runtime capture; editor-only snapshot. Refreshed whenever runtime verification captures are saved."
	_refresh_capture()

func _process(delta: float) -> void :
	if not Engine.is_editor_hint():
		return
	_poll_elapsed += delta
	if _poll_elapsed >= 1.0:
		_poll_elapsed = 0.0
		_refresh_capture()

func _refresh_capture() -> void :
	if not FileAccess.file_exists(CAPTURE):
		return

	var digest: = FileAccess.get_sha256(CAPTURE)
	if digest == _seen_digest:
		return


	var image: = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(CAPTURE)) == OK and not image.is_empty():
		texture = ImageTexture.create_from_image(image)
		_seen_digest = digest
