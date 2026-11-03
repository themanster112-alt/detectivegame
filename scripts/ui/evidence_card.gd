extends PanelContainer

const NoirTheme = preload("res://scripts/ui/noir_theme.gd")
## Shared presentation for evidence details and notebook entries.

func display(clue: Dictionary, catalog: Resource = preload("res://assets/ui/noir_visual_catalog.tres"), artwork_allowed: bool = true, artwork_notice: String = "") -> void:
	add_theme_stylebox_override("panel", NoirTheme.panel(NoirTheme.SURFACE, Color(NoirTheme.GOLD, 0.35), 24))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_add_text(column, clue.name, 24)
	var texture: Texture2D = catalog.evidence_texture(clue.id) if artwork_allowed else null
	if texture != null:
		var artwork := TextureRect.new()
		artwork.name = "EvidenceArtwork"
		artwork.texture = texture
		artwork.custom_minimum_size.y = 220
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(artwork)
		if not artwork_notice.is_empty():
			_add_text(column, artwork_notice, 16)
	_add_text(column, "المصدر: %s\nالتوقيت: %s\nالتصنيف: %s" % [clue.source, clue.time, clue.category], 18)
	_add_text(column, clue.description, 21)

func _add_text(parent: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 6)
	label.add_theme_color_override("font_color", NoirTheme.GOLD if font_size == 24 else (NoirTheme.MUTED if font_size == 18 else NoirTheme.TEXT))
	parent.add_child(label)
