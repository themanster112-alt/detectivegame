extends RefCounted
const PATHS := {
	"normal": "res://assets/characters/hero/Brooding Noir Detective Portrait.png",
	"thinking": "res://assets/characters/hero/Contemplative Detective in Dark Formalwear.png",
	"accusing": "res://assets/characters/hero/Accusing Detective Noir Pose.png"
}
static func texture(state: String) -> Texture2D:
	var path: String = PATHS.get(state, PATHS.normal)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var bitmap := Image.load_from_file(path)
	return null if bitmap == null or bitmap.is_empty() else ImageTexture.create_from_image(bitmap)
static func create(state: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.name = "HeroPortrait"
	portrait.layout_direction = Control.LAYOUT_DIRECTION_LTR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = texture(state)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_left = 0.03
	portrait.anchor_right = 0.40
	portrait.anchor_top = 0.19
	portrait.anchor_bottom = 0.91
	return portrait
