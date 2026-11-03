extends RefCounted

const BACKGROUND := Color("14212D")
const GOLD := Color("C9A46B")
const WARNING := Color("612D3C")
const TEXT := Color("E8DFCC")
const SURFACE := Color("1C2C3A")
const MUTED := Color("B6B5AD")

static func panel(fill: Color = BACKGROUND, border: Color = GOLD, margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func modal() -> StyleBoxFlat:
	var style := panel(Color(BACKGROUND, 0.96), Color(GOLD, 0.35), 22)
	style.border_width_top = 2
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style

static func selected() -> StyleBoxFlat:
	var style := panel(Color("34403F"), GOLD, 20)
	style.border_width_right = 4
	return style

static func build() -> Theme:
	var result := Theme.new()
	result.default_font = preload("res://assets/fonts/NotoSansArabic.ttf")
	result.default_font_size = 21
	result.set_color("font_color", "Label", TEXT)
	result.set_constant("line_spacing", "Label", 5)
	result.set_constant("outline_size", "Label", 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := SURFACE
		var border := Color(GOLD, 0.4)
		if state == "hover":
			fill = Color("293C49")
			border = GOLD
		elif state == "pressed":
			fill = Color("3B433E")
			border = GOLD
		elif state == "disabled":
			fill = Color(BACKGROUND, 0.65)
			border = Color(GOLD, 0.15)
		var style := panel(fill, border, 20)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = GOLD
			style.set_border_width_all(2)
		result.set_stylebox(state, "Button", style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.set_color(color_name, "Button", TEXT)
	result.set_color("font_disabled_color", "Button", Color(TEXT, 0.42))
	result.set_constant("outline_size", "Button", 0)
	result.set_stylebox("panel", "PanelContainer", panel(SURFACE, Color(GOLD, 0.28), 22))
	var track := panel(Color(BACKGROUND, 0.6), Color.TRANSPARENT, 0)
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	track.content_margin_left = 5
	track.content_margin_right = 5
	result.set_stylebox("scroll", "VScrollBar", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := track.duplicate()
		grabber.bg_color = GOLD if state == "grabber" else TEXT
		result.set_stylebox(state, "VScrollBar", grabber)
	return result

# Text actions reserve identical space in every pointer/focus state.
static func style_text_action(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(GOLD, 0.08 if state in ["hover", "focus"] else (0.14 if state == "pressed" else 0.0))
		style.set_content_margin_all(0)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
