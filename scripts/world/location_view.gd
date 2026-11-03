extends Control
signal evidence_requested(id: String)
signal inspection_requested(id: String)
signal witness_requested
signal person_requested(id: String)

@export var visual_catalog: Resource = preload("res://assets/ui/noir_visual_catalog.tres")
var _stage: Control
var _background: TextureRect
var _characters: Control
var _evidence: Control
var _hotspots: Control
var _transition: Tween
var _expression_tween: Tween
var _background_notice: Label
var _previous_background: TextureRect
var _previous_expression: TextureRect
var _portrait: TextureRect
var _character_id := ""
var _character_art := ""
var _location_id := ""
var _dialogue_mode := false
var current_expression := "neutral"
var _inspections: Dictionary = {}

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = $Stage16x9
	_background = $Stage16x9/Background
	_characters = $Stage16x9/CharactersLayer
	_evidence = $Stage16x9/EvidenceLayer
	_hotspots = $Stage16x9/HotspotsLayer
	_previous_background = _background.duplicate()
	_previous_background.name = "BackgroundTransition"
	_previous_background.texture = null
	_previous_background.hide()
	_stage.add_child(_previous_background)
	_stage.move_child(_previous_background, 1)
	_background_notice = Label.new()
	_background_notice.name = "BackgroundPlaceholder"
	_background_notice.text = "خلفية مؤقتة · بانتظار الرسم الأصلي"
	_background_notice.text_direction = Control.TEXT_DIRECTION_RTL
	_background_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_background_notice.add_theme_font_size_override("font_size", 18)
	_background_notice.modulate = Color("C9A46B")
	_background_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_background_notice)
	_background_notice.anchor_left = 0.98
	_background_notice.anchor_right = 0.98
	_background_notice.offset_left = -500
	_background_notice.offset_right = 0
	_background_notice.offset_bottom = 50
	resized.connect(_fit_stage)
	_fit_stage()

func _fit_stage() -> void:
	var width: float = minf(size.x, size.y * 16.0 / 9.0)
	_stage.size = Vector2(width, width * 9.0 / 16.0)
	_stage.position = (size - _stage.size) * 0.5
	_place_inspection_regions()

func display_location(location: Dictionary, case_data: Dictionary, collected: Array[String]) -> void:
	var changed_location: bool = _location_id != location.id
	_location_id = location.id
	if _expression_tween and _expression_tween.is_valid():
		_expression_tween.kill()
	_previous_expression = null
	_portrait = null
	_character_id = ""
	if changed_location:
		current_expression = "neutral"
		_dialogue_mode = false
	for layer in [_characters, _evidence, _hotspots]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_set_background(visual_catalog.background_texture(location.get("art", location.id)))
	_inspections.clear()
	var authored: Array = []
	var presentation: Variant = case_data.get("presentation", {})
	if presentation is Dictionary and presentation.get("hotspots", []) is Array:
		authored = presentation.get("hotspots", [])
	for clue in case_data.evidence:
		if clue.location_id != location.id:
			continue
		var info := {"id": clue.id, "evidence_id": clue.id, "location_id": location.id, "rect": Rect2(float(clue.position[0]) - 0.04, float(clue.position[1]) - 0.05, 0.08, 0.10), "label": "منطقة فحص", "art_match": false, "collectible": true}
		var catalog_region: Variant = visual_catalog.inspection_regions.get(location.id + ":" + clue.id, {})
		if catalog_region is Dictionary:
			info.merge(catalog_region, true)
		var clue_region: Variant = clue.get("hotspot", {})
		if clue_region is Dictionary:
			info.merge(clue_region, true)
		for region in authored:
			if region is Dictionary and region.get("location_id") == location.id and region.get("evidence_id", "") == clue.id:
				info.merge(region, true)
		# These identities are authoritative; presentation cannot redirect another clue.
		info.id = clue.id
		info.evidence_id = clue.id
		info.location_id = location.id
		_register_inspection(info)
	for region in authored:
		if not region is Dictionary or region.get("location_id") != location.id or not region.get("evidence_id", "") is String or not region.get("evidence_id", "").is_empty():
			continue
		var info: Dictionary = region.duplicate(true)
		if not info.get("id") is String or info.id.is_empty() or _inspections.has(info.id):
			continue
		info["evidence_id"] = ""
		info["collectible"] = false
		info["art_match"] = info.get("art_match", true)
		info["label"] = info.get("label", "فحص المكان")
		_register_inspection(info)
	var local_people: Array = case_data.get("people", []).filter(func(person): return person.get("location_id", "") == location.id)
	if not local_people.is_empty():
		present_person(local_people[0])
	# People are reached through portrait cards, never through scene hotspots.
	_background_notice.visible = _background.texture is GradientTexture2D or _background.texture == null
	set_dialogue_mode(_dialogue_mode)

func inspection_data(id: String) -> Dictionary:
	return _inspections.get(id, {}).duplicate(true)

func _normalized_rect(value: Variant) -> Rect2:
	var rect := Rect2()
	if value is Rect2:
		rect = value
	elif value is Array and value.size() == 4:
		for number in value:
			if not (number is int or number is float) or not is_finite(float(number)):
				return Rect2()
		rect = Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	if not is_finite(rect.position.x) or not is_finite(rect.position.y) or not is_finite(rect.size.x) or not is_finite(rect.size.y):
		return Rect2()
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 1 or rect.end.y > 1 or not rect.has_area():
		return Rect2()
	return rect

func _register_inspection(info: Dictionary) -> void:
	var rect := _normalized_rect(info.get("rect"))
	if not rect.has_area():
		return
	info.rect = rect
	info.label = info.get("label", "منطقة فحص") if info.get("label", "منطقة فحص") is String else "منطقة فحص"
	info.art_match = info.get("art_match", false) == true
	info.collectible = info.get("collectible", true) == true and not str(info.evidence_id).is_empty()
	_inspections[info.id] = info
	var target_info: Dictionary = info
	var area_id: Variant = info.get("area_id", "")
	if area_id is String and not area_id.is_empty():
		var group_id: String = "area_" + area_id
		if _inspections.has(group_id):
			_inspections[group_id].entries.append(info.id)
			return
		target_info = {"id": group_id, "evidence_id": "", "rect": rect, "label": str(info.get("area_label", "تفتيش المنطقة")), "entries": [info.id], "location_id": info.location_id}
		_inspections[group_id] = target_info
	var button := Button.new()
	button.name = ("Evidence_" if not target_info.evidence_id.is_empty() else "Inspection_") + str(target_info.id)
	button.text = ""
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(64, 64)
	button.set_meta("inspection_id", target_info.id)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for state in ["hover", "focus", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Color("C9A46B"), 0.06 if state != "pressed" else 0.12)
		style.border_color = Color(Color("C9A46B"), 0.5)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		inspection_requested.emit(target_info.id)
		if not target_info.evidence_id.is_empty():
			evidence_requested.emit(target_info.evidence_id))
	_hotspots.add_child(button)
	_place_inspection_regions()

func _background_image_rect() -> Rect2:
	if _background.texture == null:
		return Rect2(Vector2.ZERO, _stage.size)
	var image_size: Vector2 = _background.texture.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return Rect2(Vector2.ZERO, _stage.size)
	var scale_factor := minf(_stage.size.x / image_size.x, _stage.size.y / image_size.y)
	var displayed := image_size * scale_factor
	return Rect2((_stage.size - displayed) * 0.5, displayed)

func _place_inspection_regions() -> void:
	if not is_instance_valid(_hotspots) or not is_instance_valid(_background):
		return
	var image_rect := _background_image_rect()
	for button in _hotspots.get_children():
		if button.has_meta("person_id"):
			var rect: Rect2 = button.get_meta("person_rect")
			var area := Rect2(image_rect.position + rect.position * image_rect.size, rect.size * image_rect.size)
			var target := area.size.max(Vector2(64, 64))
			var center := area.get_center()
			center.x = clampf(center.x, target.x * 0.5, _stage.size.x - target.x * 0.5)
			center.y = clampf(center.y, 160 + target.y * 0.5, _stage.size.y - 124 - target.y * 0.5)
			button.position = center - target * 0.5
			button.size = target
			continue
		if not button.has_meta("inspection_id"):
			if button.has_meta("scene_point"):
				var point: Array = button.get_meta("scene_point")
				var target: Vector2 = button.get_combined_minimum_size().max(Vector2(154, 64))
				var center := Vector2(float(point[0]), float(point[1])) * _stage.size
				center.x = clampf(center.x, target.x * 0.5, _stage.size.x - target.x * 0.5)
				center.y = clampf(center.y, 112 + target.y * 0.5, _stage.size.y - 124 - target.y * 0.5)
				button.position = center - target * 0.5
				button.size = target
			continue
		var info: Dictionary = _inspections.get(button.get_meta("inspection_id"), {})
		if info.is_empty():
			continue
		var normalized: Rect2 = info.rect
		var area := Rect2(image_rect.position + normalized.position * image_rect.size, normalized.size * image_rect.size)
		var center := area.get_center()
		var target_size := Vector2(maxf(64, area.size.x), maxf(64, area.size.y))
		# Keep touch targets away from the fixed top HUD and the bottom navigation.
		var safe_top := minf(112, _stage.size.y * 0.20)
		var safe_bottom := maxf(safe_top + 64, _stage.size.y - 124)
		target_size = target_size.min(Vector2(_stage.size.x, safe_bottom - safe_top))
		center.x = clampf(center.x, target_size.x * 0.5, _stage.size.x - target_size.x * 0.5)
		center.y = clampf(center.y, safe_top + target_size.y * 0.5, safe_bottom - target_size.y * 0.5)
		button.position = center - target_size * 0.5
		button.size = target_size

func present_person(person: Dictionary) -> void:
	if _expression_tween and _expression_tween.is_valid():
		_expression_tween.kill()
	for child in _characters.get_children():
		_characters.remove_child(child)
		child.queue_free()
	_previous_expression = null
	_character_id = person.get("id", "")
	_character_art = person.get("art_id", _character_id)
	current_expression = "neutral"
	_portrait = _add_visual(_characters, visual_catalog.character_texture(_character_art, current_expression), [0.0, 0.0], Vector2.ZERO, "صورة شخصية مؤقتة", "Character_" + _character_id)
	_place_character()
	_update_expression_notice()

func _set_background(texture: Texture2D) -> void:
	if _background.texture == texture:
		return
	if _transition and _transition.is_valid():
		_transition.kill()
	_previous_background.texture = _background.texture
	_background.texture = texture
	if _previous_background.texture == null:
		_previous_background.hide()
		return
	_previous_background.modulate.a = 1.0
	_previous_background.show()
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_previous_background, "modulate:a", 0.0, 0.22)
	_transition.tween_callback(_previous_background.hide)

func set_dialogue_mode(enabled: bool) -> void:
	_dialogue_mode = enabled
	_place_character()
	_hotspots.visible = not enabled
	_evidence.visible = not enabled
	_background_notice.anchor_top = 0.04 if enabled else 0.34
	_background_notice.anchor_bottom = _background_notice.anchor_top
	if is_instance_valid(_portrait):
		_update_expression_notice()

func _place_character() -> void:
	if not is_instance_valid(_portrait):
		return
	var placements: Dictionary = visual_catalog.dialogue_placements if _dialogue_mode else visual_catalog.character_placements
	var bounds: Rect2 = placements.get(_character_art, Rect2(0.04, 0.34, 0.22, 0.46))
	_portrait.visible = _dialogue_mode
	_portrait.anchor_left = bounds.position.x
	_portrait.anchor_top = bounds.position.y
	_portrait.anchor_right = bounds.end.x
	_portrait.anchor_bottom = bounds.end.y
	_portrait.offset_left = 0
	_portrait.offset_top = 0
	_portrait.offset_right = 0
	_portrait.offset_bottom = 0
	# Shared normalized framing prevents jumps when expressions are switched.
	if is_instance_valid(_previous_expression):
		_previous_expression.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_character_expression(id: String, expression: String) -> bool:
	if id != _character_id or not is_instance_valid(_portrait):
		return false
	current_expression = expression
	var texture: Texture2D = visual_catalog.character_texture(_character_art, expression)
	if _expression_tween and _expression_tween.is_valid():
		_expression_tween.kill()
	if is_instance_valid(_previous_expression):
		_portrait.remove_child(_previous_expression)
		_previous_expression.queue_free()
	_previous_expression = null
	if texture != _portrait.texture and _portrait.texture != null:
		_previous_expression = TextureRect.new()
		_previous_expression.name = "ExpressionTransition"
		_previous_expression.texture = _portrait.texture
		_previous_expression.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_previous_expression.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_previous_expression.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.add_child(_previous_expression)
		_previous_expression.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_expression_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_expression_tween.tween_property(_previous_expression, "modulate:a", 0.0, 0.16)
		_expression_tween.tween_callback(_previous_expression.queue_free)
	_portrait.texture = texture
	_update_expression_notice()
	return true

func _update_expression_notice() -> void:
	var notice := _portrait.get_node_or_null("PlaceholderLabel") as Label
	var missing_pose: bool = visual_catalog.expression_texture(_character_art, current_expression) == null
	if notice == null and (_portrait.texture == null or missing_pose):
		notice = Label.new()
		notice.name = "PlaceholderLabel"
		notice.text_direction = Control.TEXT_DIRECTION_RTL
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.add_theme_font_size_override("font_size", 18)
		notice.modulate = Color("C9A46B")
		notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.add_child(notice)
		notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if notice != null:
		notice.visible = _portrait.texture == null or missing_pose
		notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP if _dialogue_mode else VERTICAL_ALIGNMENT_CENTER
		notice.text = "صورة شخصية مؤقتة\nبانتظار الرسم الأصلي" if _portrait.texture == null else "تعبير مؤقت · عرض الصورة المحايدة"

func _add_visual(parent: Control, texture: Texture2D, point: Array, dimensions: Vector2, placeholder: String, node_name: String) -> TextureRect:
	var slot := TextureRect.new()
	slot.name = node_name
	slot.texture = texture
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.anchor_left = point[0]
	slot.anchor_right = point[0]
	slot.anchor_top = point[1]
	slot.anchor_bottom = point[1]
	slot.offset_left = -dimensions.x / 2
	slot.offset_right = dimensions.x / 2
	slot.offset_top = -dimensions.y - 42
	slot.offset_bottom = -42
	parent.add_child(slot)
	if texture == null:
		var label := Label.new()
		label.name = "PlaceholderLabel"
		label.text = placeholder
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color("C9A46B")
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(label)

	return slot

func _add_person_hotspot(person: Dictionary) -> void:
	var point: Array = person.get("position", [0.5, 0.5])
	var fallback := Rect2(clampf(float(point[0]) - 0.04, 0, 0.92), clampf(float(point[1]) - 0.06, 0.23, 0.68), 0.08, 0.12)
	var rect := _normalized_rect(visual_catalog.person_regions.get(_location_id + ":" + person.id, fallback))
	if not rect.has_area(): rect = fallback
	var button := Button.new()
	button.name = "Person_" + person.id
	button.text = ""
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(64,64)
	button.set_meta("person_id", person.id)
	button.set_meta("person_rect", rect)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for state in ["hover", "focus", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Color("C9A46B"), 0.08)
		style.border_color = Color(Color("C9A46B"), 0.55)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		person_requested.emit(person.id)
		witness_requested.emit())
	_hotspots.add_child(button)
	_place_inspection_regions()

