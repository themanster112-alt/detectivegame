extends Resource
## All art, paths, poses and expression cues belong to presentation, never case data.
## Files named here can be PNG or WebP; explicit Inspector textures take priority.
@export var backgrounds: Dictionary[String, Texture2D] = {}
@export var characters: Dictionary[String, Texture2D] = {}
@export var evidence: Dictionary[String, Texture2D] = {}
@export var character_expressions: Dictionary[String, Texture2D] = {}
@export var ui: Dictionary[String, Texture2D] = {}
@export var background_files: Dictionary[String, String] = {}
@export var character_files: Dictionary[String, String] = {}
@export var evidence_files: Dictionary[String, String] = {}
@export var ui_files: Dictionary[String, String] = {
	"notebook": "res://assets/ui/ui_notebook",
	"board": "res://assets/ui/ui_board",
	"accusation": "res://assets/ui/ui_accusation",
	"close": "res://assets/ui/ui_close",
	"travel": "res://assets/ui/ui_travel",
}
# Normalized 16:9 stage rectangles, independent of investigation hotspots.
@export var character_placements: Dictionary[String, Rect2] = {}
@export var dialogue_placements: Dictionary[String, Rect2] = {}
@export var dialogue_expressions: Dictionary[String, String] = {}
@export var question_expressions: Dictionary[String, String] = {}
# Per-case presentation data. Optional JSON presentation.hotspots overrides these.
# Rectangles are normalized against the displayed background image, not screen pixels.
@export var inspection_regions: Dictionary = {}
# Character approach points, independent from evidence and case logic.
@export var person_regions: Dictionary = {}
@export var art_requirements: Dictionary = {}
@export var inspection_fallbacks: Dictionary[String, String] = {}
@export var art_notices: Dictionary[String, String] = {}
var _image_cache: Dictionary = {}

func _image(stem: String) -> Texture2D:
	if stem.is_empty():
		return null
	var paths: Array = [stem] if stem.get_extension().to_lower() in ["png", "webp"] else [stem + ".png", stem + ".webp"]
	for path in paths:
		if _image_cache.has(path):
			return _image_cache[path]
		var texture: Texture2D
		if ResourceLoader.exists(path, "Texture2D"):
			texture = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			# Also support fresh source images before the editor has imported them.
			var bitmap := Image.new()
			if bitmap.load(path) == OK:
				texture = ImageTexture.create_from_image(bitmap)
		if texture != null:
			_image_cache[path] = texture
			return texture
	return null

func background_texture(id: String) -> Texture2D:
	var assigned: Texture2D = backgrounds.get(id)
	if assigned != null and not assigned is GradientTexture2D:
		return assigned
	var file := _image(background_files.get(id, ""))
	return file if file != null else assigned

func expression_texture(id: String, expression: String) -> Texture2D:
	var key := id + ":" + expression
	var assigned: Texture2D = character_expressions.get(key)
	if assigned != null:
		return assigned
	var file := _image(character_files.get(key, ""))
	if file != null:
		return file
	return characters.get(id) if expression == "neutral" else null

func character_texture(id: String, expression: String = "neutral") -> Texture2D:
	var texture := expression_texture(id, expression)
	return expression_texture(id, "neutral") if texture == null else texture

func evidence_texture(id: String) -> Texture2D:
	var assigned: Texture2D = evidence.get(id)
	return assigned if assigned != null else _image(evidence_files.get(id, ""))

func ui_texture(id: String) -> Texture2D:
	var assigned: Texture2D = ui.get(id)
	return assigned if assigned != null else _image(ui_files.get(id, ""))

func clear_image_cache() -> void:
	_image_cache.clear()
