extends Control
var player_name := ""
const PlayerProfile = preload("res://scripts/core/player_profile.gd")
## Presentation only. Does not own progress, alter case data, or read campaign state.
signal finished
const NoirTheme = preload("res://scripts/ui/noir_theme.gd")
var page := 0
var _pages: Array = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _eyebrow: Label
var _progress: Label
var next_button: Button
var skip_button: Button
var back_button: Button
var _transition: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = NoirTheme.build()
	var veil := TextureRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.61, 1.0])
	gradient.colors = PackedColorArray([Color(NoirTheme.BACKGROUND, 0.08), Color(NoirTheme.BACKGROUND, 0.22), Color(NoirTheme.BACKGROUND, 0.94), Color(NoirTheme.BACKGROUND, 0.99)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1280
	texture.height = 720
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	veil.texture = texture
	add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.set_script(preload("res://scripts/ui/mobile_safe_margin.gd"))
	add_child(margin)
	var frame := Control.new()
	margin.add_child(frame)
	var column := VBoxContainer.new()
	column.anchor_left = 0.43
	column.anchor_right = 0.96
	column.anchor_top = 0.07
	column.anchor_bottom = 0.79
	column.add_theme_constant_override("separation", 16)
	frame.add_child(column)
	_eyebrow = _label("", 18, NoirTheme.GOLD)
	column.add_child(_eyebrow)
	var rule := HSeparator.new()
	column.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)
	_progress = _label("", 16, NoirTheme.MUTED)
	_progress.text_direction = Control.TEXT_DIRECTION_LTR
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_progress.anchor_left = 0.04
	_progress.anchor_right = 0.40
	_progress.anchor_top = 0.08
	frame.add_child(_progress)
	var actions := HBoxContainer.new()
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.anchor_left = 0.04
	actions.anchor_right = 0.96
	actions.anchor_top = 0.86
	actions.anchor_bottom = 0.97
	actions.add_theme_constant_override("separation", 14)
	frame.add_child(actions)
	next_button = _button("التالي", advance)
	next_button.name = "IntroNext"
	next_button.custom_minimum_size.x = 180
	next_button.add_theme_stylebox_override("normal", NoirTheme.selected())
	actions.add_child(next_button)
	back_button = _button("السابق", previous)
	back_button.custom_minimum_size.x = 130
	actions.add_child(back_button)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(space)
	skip_button = _button("الانتقال إلى موقع الجريمة", func(): finished.emit())
	skip_button.name = "IntroCrimeScene"
	skip_button.custom_minimum_size.x = 320
	actions.add_child(skip_button)
	hide()

func _label(text: String, size: int, color: Color = NoirTheme.TEXT) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = PlayerProfile.format_text(text, player_name)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 8)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.custom_minimum_size.y = 58
	button.pressed.connect(action)
	return button

func open_case(data: Dictionary, reports: Array, people: Array, locations: Array) -> void:
	_pages.clear()
	var info: Dictionary = data.case_file
	_pages.append({"kind": "opening", "eyebrow": info.crime_label + "  /  " + info.number, "title": data.title, "paragraphs": [info.summary]})
	var scene: String = info.crime_scene
	for location in locations:
		if location.id == scene:
			scene = location.name
	var case_paragraphs := ["الضحية / المتضرر", info.victim.name]
	if info.victim.background != info.victim.name:
		case_paragraphs.append(info.victim.background)
	case_paragraphs.append("مكان الحادث · " + scene)
	_pages.append({"kind": "case", "eyebrow": "ملف القضية", "title": data.title, "paragraphs": case_paragraphs})
	for report in reports:
		var paragraphs := [report.summary]
		if not report.get("cause_of_death", "").is_empty():
			paragraphs.append("سبب الوفاة: " + report.cause_of_death)
		if not report.get("estimated_time", "").is_empty():
			paragraphs.append("الوقت التقديري: " + report.estimated_time)
		for finding in report.get("findings", []):
			paragraphs.append("• " + finding)
		_pages.append({"kind": "report", "eyebrow": "الطب الشرعي" if report.kind == "forensic" else "التقرير الفني", "title": report.title, "status": report.status, "paragraphs": paragraphs})
	var names := []
	for person in people:
		names.append(person.name + (" · " + person.occupation if not person.get("occupation", "").is_empty() else ""))
	var location_names := []
	for location in locations:
		location_names.append(location.name)
	var chunks := maxi(1, ceili(float(names.size()) / 2))
	for index in range(chunks):
		var paragraphs := []
		if index == 0:
			paragraphs.append(data.assistant.briefing)
			paragraphs.append("المواقع المتاحة: " + "، ".join(location_names))
		if not names.is_empty():
			paragraphs.append("الأشخاص المعروفون")
			paragraphs.append("
".join(names.slice(index * 3, mini(names.size(), index * 3 + 3))))
		_pages.append({"kind": "assistant", "eyebrow": "إحاطة الموقع" if index == 0 else "متابعة الإحاطة", "title": data.assistant.name, "paragraphs": paragraphs})
	page = 0
	show()
	_render()

func advance() -> void:
	if page + 1 >= _pages.size():
		finished.emit()
		return
	page += 1
	_render()

func previous() -> void:
	page = maxi(0, page - 1)
	_render()

func _render() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var entry: Dictionary = _pages[page]
	_eyebrow.text = entry.eyebrow
	_progress.text = "%02d / %02d" % [page + 1, _pages.size()]
	_content.add_child(_label(entry.title, 42 if entry.kind == "opening" else 30))
	if entry.has("status"):
		_content.add_child(_label({"confirmed": "نتائج مؤكدة", "preliminary": "نتائج أولية", "uncertain": "معلومات غير مؤكدة"}.get(entry.status, entry.status), 17, NoirTheme.GOLD))
	for paragraph in entry.paragraphs:
		_content.add_child(_label(str(paragraph), 21))
	back_button.visible = page > 0
	next_button.text = "إلى موقع الجريمة" if page == _pages.size() - 1 else "التالي"
	_scroll.scroll_vertical = 0
	if _transition and _transition.is_valid():
		_transition.kill()
	_content.modulate.a = 0.0
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_content, "modulate:a", 1.0, 0.24)
