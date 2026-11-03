extends Control
signal return_to_title
@export var player_name := ""
@export var show_title_action := false
@export var simplified_ui := false
const PlayerProfile = preload("res://scripts/core/player_profile.gd")
const NoirTheme = preload("res://scripts/ui/noir_theme.gd")
const CaseIntro = preload("res://scripts/ui/case_intro.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const Manager = preload("res://scripts/core/case_manager.gd")
const LocationView = preload("res://scenes/investigation/location_view.tscn")
const VisualCatalog = preload("res://scripts/world/visual_catalog.gd")
const EvidenceCard = preload("res://scenes/ui/evidence_card.tscn")
@export_file("*.json") var case_path := "res://data/cases/midnight_training.json"
@export var save_path := "user://investigation_progress.json"
@export var persistence_enabled := true
var manager = Manager.new()
var session = Session.new()
var room: Control
var opening_history: Array = []
var _hero_portrait: TextureRect
const HeroPortrait = preload("res://scripts/ui/hero_portrait.gd")
var player_identity_label: Label
var location_title: Label
var location_description: Label
var travel_buttons: Dictionary = {}
var navigation: HBoxContainer
var case_data: Dictionary = {}
var collected: Array[String]:
	get: return session.collected_ids()
var witness_heard: bool:
	get: return session.witness_heard()
var dialogue_index := 0
var _dialogue_frame: PanelContainer
var _dialogue_portrait: TextureRect
var modal_panel: PanelContainer
var _modal_tween: Tween
var overlay: ColorRect
var modal_body: VBoxContainer
var status: Label
var _board_button: Button
var _exploration_hint: Label
var notebook_button: Button
var conclusion_button: Button
var board_selection: Array[String] = []
var board_feedback := ""
var proof_selection: Array[String] = []
var _modal_scroll: ScrollContainer
var _modal_title := ""
var _investigation_chrome: MarginContainer
var _close_button: Button
var _active_person_id := ""
var _title: Label
var _last_accusation_id := ""
var _board_tab := "evidence"
var case_intro: Control
var _window_title: Label
var _modal_tabs: HBoxContainer
var _modal_actions: HFlowContainer
var _accusation_shortcut: Button
var _pages: Dictionary = {}
var _menu_tab := "case"
var _notebook_tab := "evidence"
var _accusation_tab := "person"
var _selected_suspect := ""
var _report_page := 0
var _assistant_tab := "brief"
var _confronting_question := ""
var footer_buttons: Array[Button] = []
var _card_grid: GridContainer


func _ready() -> void:
	manager.story_mode = simplified_ui
	manager.save_path = save_path
	manager.persistence_enabled = persistence_enabled
	var progress_ok: bool = manager.load_progress()
	if not manager.open_case(case_path):
		add_child(_label(manager.last_error))
		return
	session = manager.session
	case_data = session.case_snapshot()
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	theme = NoirTheme.build()
	var bg := ColorRect.new()
	bg.color = NoirTheme.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	room = LocationView.instantiate()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	_hero_portrait = HeroPortrait.create("normal")
	add_child(_hero_portrait)
	_hero_portrait.hide()
	room.inspection_requested.connect(show_inspection)
	room.person_requested.connect(_start_dialogue)
	var margin := MarginContainer.new()
	_investigation_chrome = margin
	margin.set_script(preload("res://scripts/ui/mobile_safe_margin.gd"))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var column := VBoxContainer.new()
	column.layout_direction = Control.LAYOUT_DIRECTION_RTL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	var chrome_frame := Control.new()
	chrome_frame.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chrome_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(chrome_frame)
	chrome_frame.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_bottom = -112
	var header_panel := PanelContainer.new()
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_theme_stylebox_override("panel", NoirTheme.panel(Color(NoirTheme.BACKGROUND, 0.68), Color(NoirTheme.GOLD, 0.22), 16))
	column.add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header_panel.add_child(header)
	_title = _label(case_data.title, 26)
	_title.add_theme_color_override("font_color", NoirTheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	location_title = _label("", 20)
	location_title.custom_minimum_size.x = 200
	header.add_child(location_title)
	var file_button := _button("القضية", show_case_menu)
	file_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	file_button.custom_minimum_size.x = 145
	header.add_child(file_button)
	if not player_name.is_empty():
		player_identity_label = _label("المحقق: {player_name}", 19)
		player_identity_label.add_theme_color_override("font_color", NoirTheme.GOLD)
		column.add_child(player_identity_label)
	location_description = _label("", 17)
	location_description.hide()
	location_description.add_theme_color_override("font_color", NoirTheme.MUTED)
	column.add_child(location_description)
	var navigation_scroll := ScrollContainer.new()
	navigation_scroll.custom_minimum_size.y = 64
	navigation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(navigation_scroll)
	navigation = HBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_theme_constant_override("separation", 12)
	navigation_scroll.add_child(navigation)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	status = _label("", 16)
	status.add_theme_color_override("font_color", NoirTheme.MUTED)
	column.add_child(status)
	_exploration_hint = _label("المس الأشياء في المشهد لفحص الأدلة. افتح «الأشخاص» للتحدث والاستجواب.", 18)
	_exploration_hint.add_theme_color_override("font_color", NoirTheme.GOLD)
	_exploration_hint.add_theme_stylebox_override("normal", NoirTheme.panel(Color(NoirTheme.BACKGROUND, 0.9), Color(NoirTheme.GOLD, 0.2), 10))
	_exploration_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_exploration_hint)
	var footer_panel := PanelContainer.new()
	footer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_panel.add_theme_stylebox_override("panel", NoirTheme.panel(Color(NoirTheme.BACKGROUND, 0.66), Color(NoirTheme.GOLD, 0.2), 12))
	footer_panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	chrome_frame.add_child(footer_panel)
	footer_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_panel.anchor_top = 1.0
	footer_panel.offset_top = -100
	footer_panel.offset_bottom = 0
	var footer := GridContainer.new()
	footer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	footer.columns = 4
	footer.add_theme_constant_override("h_separation", 10)
	footer_panel.add_child(footer)
	notebook_button = _button("دفتر الأدلة", show_notebook)
	_apply_art_icon(notebook_button, "notebook")
	footer.add_child(notebook_button)
	footer.add_child(_button("الأشخاص", show_people))
	var board_button := _button("لوح التحقيق", show_board)
	_board_button = board_button
	_apply_art_icon(board_button, "board")
	footer.add_child(board_button)
	conclusion_button = _button("توجيه اتهام", show_conclusion)
	conclusion_button.custom_minimum_size.x = 230
	conclusion_button.add_theme_stylebox_override("normal", NoirTheme.selected())
	_apply_art_icon(conclusion_button, "accusation")
	footer.add_child(conclusion_button)
	for child in footer.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0, 64)
			child.autowrap_mode = TextServer.AUTOWRAP_OFF
			child.alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.add_theme_font_size_override("font_size", 20)
			footer_buttons.append(child)
	_build_modal()
	_accusation_shortcut = _button("توجيه اتهام", show_conclusion)
	_accusation_shortcut.name = "AccusationShortcut"
	_accusation_shortcut.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_accusation_shortcut.anchor_left = 0.02
	_accusation_shortcut.anchor_right = 0.20
	_accusation_shortcut.anchor_top = 0.025
	_accusation_shortcut.anchor_bottom = 0.115
	_accusation_shortcut.offset_left = 0
	_accusation_shortcut.offset_top = 0
	_accusation_shortcut.offset_right = 0
	_accusation_shortcut.offset_bottom = 0
	_accusation_shortcut.add_theme_font_size_override("font_size", 18)
	_accusation_shortcut.add_theme_stylebox_override("normal", NoirTheme.selected())
	add_child(_accusation_shortcut)
	_accusation_shortcut.hide()
	case_intro = CaseIntro.new()
	case_intro.player_name = player_name
	add_child(case_intro)
	case_intro.finished.connect(begin_investigation)
	_attach_session()
	if session.phase == "briefing":
		_show_case_intro()
	elif session.phase == "closed":
		if simplified_ui: show_story_result()
		else: show_case_menu()
	if not progress_ok:
		status.text = "تعذّر قراءة الحفظ السابق؛ لن يُستبدل تلقائيًا."

func _attach_session() -> void:
	case_data = session.case_snapshot()
	var catalog_path: String = case_data.get("visual_catalog_path", "")
	if not catalog_path.is_empty() and ResourceLoader.exists(catalog_path):
		var catalog: Resource = load(catalog_path)
		if catalog != null and catalog.has_method("background_texture"):
			room.visual_catalog = catalog
	else:
		room.visual_catalog = VisualCatalog.new()
	_title.text = case_data.title
	session.changed.connect(_update_status)
	session.location_changed.connect(_on_location_changed)
	for child in navigation.get_children():
		navigation.remove_child(child)
		child.queue_free()
	travel_buttons.clear()
	for location in case_data.locations:
		var button := _button(location.name, func(): travel_to(location.id))
		button.name = "Travel_" + location.id
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size.x = 190
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_apply_art_icon(button, "travel")
		navigation.add_child(button)
		travel_buttons[location.id] = button
	_on_location_changed(session.current_location)
	_update_status()

func _known_art(ref: String) -> Texture2D:
	var id := ref.trim_prefix("e:").trim_prefix("r:")
	var known: bool = session.has_evidence(id) or session.available_reports().any(func(report): return report.id == id)
	if not known or not session.meets(room.visual_catalog.art_requirements.get(id, {})):
		return null
	return room.visual_catalog.evidence_texture(id)

func _add_known_art(ref: String, inspection: bool = false) -> void:
	var texture := _known_art(ref)
	if inspection:
		var clue_id := ref.trim_prefix("e:")
		var clue: Dictionary = session.evidence_data(clue_id)
		if not clue.is_empty() and clue.location_id == session.current_location and session.meets(clue.get("requires", {})):
			var art_id: String = clue_id if session.meets(room.visual_catalog.art_requirements.get(clue_id, {})) else room.visual_catalog.inspection_fallbacks.get(clue_id, "")
			texture = room.visual_catalog.evidence_texture(art_id)
	if texture == null:
		if inspection:
			modal_body.add_child(_label("صورة الدليل غير متوفرة بعد.", 17))
		return
	var artwork := TextureRect.new()
	artwork.name = "KnownEvidenceArtwork"
	artwork.texture = texture
	artwork.custom_minimum_size.y = 220
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_body.add_child(artwork)
	var id := ref.trim_prefix("e:").trim_prefix("r:")
	if room.visual_catalog.art_notices.has(id):
		modal_body.add_child(_label(room.visual_catalog.art_notices[id], 16))

func _show_hero(state: String, dialogue: bool = false) -> void:
	if dialogue:
		_hero_portrait.hide()
		room._characters.hide()
		_dialogue_frame.show()
		_dialogue_portrait.texture = HeroPortrait.texture(state)
		return
	_hero_portrait.texture = HeroPortrait.texture(state)
	_hero_portrait.anchor_left = 0.04 if dialogue else 0.03
	_hero_portrait.anchor_right = 0.42 if dialogue else maxf(0.25, modal_panel.anchor_left - 0.02)
	_hero_portrait.anchor_top = 0.01 if dialogue else 0.10
	_hero_portrait.anchor_bottom = 0.86 if dialogue else 0.91
	room._characters.hide()
	_hero_portrait.show()

func _label(value: String, font_size: int = 22) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text = PlayerProfile.format_text(value, player_name)
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 6)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text = value
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.custom_minimum_size.y = 56
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _apply_art_icon(button: Button, key: String) -> void:
	button.icon = room.visual_catalog.ui_texture(key)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 28)
	button.add_theme_constant_override("h_separation", 12)

func _build_modal() -> void:
	overlay = ColorRect.new()
	overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	modal_panel = PanelContainer.new()
	modal_panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	modal_panel.add_theme_stylebox_override("panel", NoirTheme.modal())
	overlay.add_child(modal_panel)
	var column := VBoxContainer.new()
	column.layout_direction = Control.LAYOUT_DIRECTION_RTL
	column.add_theme_constant_override("separation", 10)
	var content_row := HBoxContainer.new()
	content_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content_row.add_theme_constant_override("separation", 22)
	modal_panel.add_child(content_row)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_child(column)
	_dialogue_frame = PanelContainer.new()
	_dialogue_frame.name = "DialoguePortraitFrame"
	_dialogue_frame.custom_minimum_size = Vector2(280, 280)
	_dialogue_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dialogue_frame.add_theme_stylebox_override("panel", NoirTheme.panel(Color("0D171F"), Color(NoirTheme.GOLD, 0.38), 10))
	content_row.add_child(_dialogue_frame)
	_dialogue_portrait = TextureRect.new()
	_dialogue_portrait.name = "DialoguePortrait"
	_dialogue_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialogue_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dialogue_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_frame.add_child(_dialogue_portrait)
	_dialogue_frame.hide()
	var titlebar := HBoxContainer.new()
	titlebar.add_theme_constant_override("separation", 16)
	column.add_child(titlebar)
	_window_title = _label("", 24)
	_window_title.add_theme_color_override("font_color", NoirTheme.GOLD)
	_window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titlebar.add_child(_window_title)
	_close_button = _button("عودة  ×", close_modal)
	_close_button.custom_minimum_size = Vector2(115, 48)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_close_button.add_theme_font_size_override("font_size", 16)
	titlebar.add_child(_close_button)
	_modal_tabs = HBoxContainer.new()
	_modal_tabs.add_theme_constant_override("separation", 6)
	column.add_child(_modal_tabs)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_modal_scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 12)
	_modal_scroll.add_child(modal_body)
	_modal_actions = HFlowContainer.new()
	_modal_actions.add_theme_constant_override("h_separation", 10)
	_modal_actions.add_theme_constant_override("v_separation", 8)
	column.add_child(_modal_actions)
	overlay.hide()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _open(title: String, dialogue: bool = false, layout: String = "side") -> void:
	_hero_portrait.hide()
	room._characters.show()
	var animate := not overlay.visible or _modal_title != title
	if is_instance_valid(case_intro):
		case_intro.hide()
	room.set_dialogue_mode(dialogue)
	room._characters.hide()
	_dialogue_frame.visible = dialogue
	_dialogue_portrait.texture = room._portrait.texture if dialogue and is_instance_valid(room._portrait) else null
	_investigation_chrome.hide()
	_close_button.visible = session.phase != "briefing"
	if not dialogue:
		room.set_character_expression(_active_person_id, "neutral")
	var bounds := Rect2(0.43, 0.13, 0.54, 0.75)
	if layout == "wide":
		bounds = Rect2(0.27, 0.10, 0.70, 0.78)
	elif layout == "compact":
		bounds = Rect2(0.47, 0.20, 0.50, 0.60)
	elif layout == "inspect":
		bounds = Rect2(0.51, 0.18, 0.46, 0.62)
	elif layout == "evidence":
		bounds = Rect2(0.43, 0.10, 0.54, 0.78)
	elif dialogue:
		bounds = Rect2(0.08, 0.20, 0.84, 0.60)
	modal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_panel.anchor_left = bounds.position.x
	modal_panel.anchor_right = bounds.end.x
	modal_panel.anchor_top = bounds.position.y
	modal_panel.anchor_bottom = bounds.end.y
	modal_panel.add_theme_stylebox_override("panel", NoirTheme.panel(Color(0.025, 0.045, 0.065, 0.95), Color(NoirTheme.GOLD, 0.32), 22) if dialogue else NoirTheme.modal())
	overlay.color = Color(NoirTheme.BACKGROUND, 0.18 if dialogue else 0.37)
	_clear(modal_body)
	_clear(_modal_tabs)
	_clear(_modal_actions)
	_modal_tabs.hide()
	_modal_actions.hide()
	_window_title.text = title
	_modal_scroll.scroll_vertical = 0
	_modal_title = title
	overlay.show()
	if is_instance_valid(_accusation_shortcut):
		_accusation_shortcut.visible = session.can_conclude()
	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()
	modal_panel.modulate.a = 1.0
	if not animate:
		return
	modal_panel.modulate.a = 0.35
	_modal_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_modal_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.16)

func close_modal() -> void:
	_dialogue_frame.hide()
	_hero_portrait.hide()
	room._characters.show()
	if session.phase == "briefing":
		return
	room.set_dialogue_mode(false)
	room.set_character_expression(_active_person_id, "neutral")
	_investigation_chrome.show()
	_modal_title = ""
	overlay.hide()
	_accusation_shortcut.hide()
	room.display_location(session.location_data(), _world_data(), collected)

func _action(text: String, action: Callable, primary: bool = false) -> Button:
	var button := _button(text, action)
	button.custom_minimum_size = Vector2(clampf(text.length() * 11 + 48, 160, 420), 56)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 18)
	if primary:
		button.add_theme_stylebox_override("normal", NoirTheme.selected())
	if _dialogue_frame.visible:
		button.custom_minimum_size = Vector2(maxf(100, text.length() * 9 + 20), 48)
		NoirTheme.style_text_action(button)
		button.add_theme_color_override("font_color", NoirTheme.GOLD)
		button.add_theme_color_override("font_hover_color", NoirTheme.GOLD)
	_modal_actions.add_child(button)
	_modal_actions.show()
	return button

func _tabs(items: Array, selected: String, action: Callable) -> void:
	for item in items:
		var tab_label: String = item.label
		if item.id == "information" and session.known_nodes().any(func(node): return node.kind in ["statement", "question", "report", "timeline", "person"] and _is_unread(node)):
			tab_label += " ●"
		var button := _button(tab_label, func(): action.call(item.id))
		button.custom_minimum_size = Vector2(88, 48)
		button.add_theme_font_size_override("font_size", 17)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		var style := NoirTheme.panel(NoirTheme.BACKGROUND, Color(NoirTheme.GOLD, 0.18), 10)
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		if item.id == selected:
			style.bg_color = NoirTheme.SURFACE
			style.border_color = NoirTheme.GOLD
			style.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", style)
		_modal_tabs.add_child(button)
	_modal_tabs.show()

func _tile(item: Dictionary, action: Callable) -> Button:
	if item.get("dialogue_option", false):
		var option := _button("› " + str(item.label), action)
		option.name = "DialogueOption_" + str(item.id)
		option.set_meta("item_id", item.id)
		option.custom_minimum_size.y = 56
		option.add_theme_font_size_override("font_size", 18)
		NoirTheme.style_text_action(option)
		if item.get("asked", false):
			option.text = "✓ " + str(item.label) + " · سُئل سابقًا"
			option.add_theme_color_override("font_color", NoirTheme.MUTED)
		elif item.get("newly_available", false):
			option.text = "● " + str(item.label) + " · متاح الآن"
			option.add_theme_color_override("font_color", NoirTheme.GOLD)
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.disabled = item.get("disabled", false)
		return option
	if item.get("portrait_card", false) and item.get("texture") != null:
		return _portrait_tile(item, action)
	var button := _button("", action)
	button.name = "Card_" + str(item.id).replace(":", "_")
	button.set_meta("item_id", item.id)
	button.custom_minimum_size.y = 112
	button.disabled = item.get("disabled", false)
	if item.get("selected", false):
		button.add_theme_stylebox_override("normal", NoirTheme.selected())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 12)
	if item.get("texture") != null:
		var art := TextureRect.new()
		art.texture = item.texture
		art.custom_minimum_size.x = 62
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(art)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	for field in [{"value": ("✓ " if item.get("selected", false) else "") + item.label, "size": 19, "color": NoirTheme.TEXT}, {"value": item.get("meta", "") + (" · رسم توضيحي" if item.get("texture") != null and room.visual_catalog.art_notices.has(str(item.id).trim_prefix("e:").trim_prefix("r:")) else "") + " · " + item.get("text", ""), "size": 15, "color": NoirTheme.MUTED}]:
		var label := _label(str(field.value), field.size)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.max_lines_visible = 1
		label.custom_minimum_size.y = ceilf(theme.default_font.get_height(field.size))
		label.add_theme_constant_override("line_spacing", 0)
		label.add_theme_color_override("font_color", field.color)
		text.add_child(label)
	return button

func _portrait_tile(item: Dictionary, action: Callable) -> Button:
	var button := _button("", action)
	button.name = "PortraitCard_" + str(item.id)
	button.set_meta("item_id", item.id)
	button.custom_minimum_size.y = 194
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 10
	column.offset_right = -10
	column.offset_top = 8
	column.offset_bottom = -8
	var art := TextureRect.new()
	art.name = "PersonArtwork"
	art.texture = item.texture
	art.custom_minimum_size.y = 100
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	var name := _label(str(item.label), 19)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name)
	var occupation := _label(str(item.get("text", "")), 14)
	occupation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	occupation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(occupation)
	return button

func _cards(items: Array, key: String, action: Callable, page_size: int = 4) -> void:
	if simplified_ui:
		page_size = maxi(1, items.size())
	var total_pages := maxi(1, ceili(float(items.size()) / page_size))
	var page: int = clampi(int(_pages.get(key, 0)), 0, total_pages - 1)
	_pages[key] = page
	_card_grid = GridContainer.new()
	_card_grid.columns = 1 if not items.is_empty() and items[0].get("dialogue_option", false) else 2
	_card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_grid.add_theme_constant_override("h_separation", 10)
	_card_grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(_card_grid)
	for index in range(page * page_size, mini(items.size(), (page + 1) * page_size)):
		var item: Dictionary = items[index]
		_card_grid.add_child(_tile(item, func(): action.call(item.id)))
	if items.is_empty():
		modal_body.add_child(_label("لا توجد معلومات مسجلة في هذا القسم بعد.", 20))
	if total_pages > 1:
		var previous := _action("السابق", func():
			_pages[key] = page - 1
			_refresh_section(key))
		previous.disabled = page == 0
		var count := _label("%d / %d" % [page + 1, total_pages], 16)
		count.custom_minimum_size = Vector2(66, 56)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.text_direction = Control.TEXT_DIRECTION_LTR
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_modal_actions.add_child(count)
		var next := _action("التالي", func():
			_pages[key] = page + 1
			_refresh_section(key))
		next.disabled = page == total_pages - 1

func _refresh_section(key: String) -> void:
	if key == "link_meanings":
		_show_link_meanings()
	elif key in ["people_assistant", "locations_assistant"]:
		show_assistant()
	elif key.begins_with("board"):
		show_board()
	elif key.begins_with("people"):
		show_people()
	elif key.begins_with("notebook"):
		show_notebook()
	elif key.begins_with("charge"):
		show_conclusion()
	elif key.begins_with("archive"):
		show_case_menu()
	elif key.begins_with("locations"):
		show_locations()
	elif key.begins_with("questions"):
		show_questions()
	elif key.begins_with("confront"):
		_show_confront_evidence()
	elif key.begins_with("analyses"):
		_show_analysis_requests()
	elif key.begins_with("area_"):
		show_inspection(key)

func _show_case_intro() -> void:
	overlay.hide()
	_accusation_shortcut.hide()
	_investigation_chrome.hide()
	room.set_dialogue_mode(true)
	room._characters.hide()
	case_intro.open_case(case_data, session.available_reports(), session.available_people(), session.available_locations())

func travel_to(id: String) -> void:
	if session.travel_to(id):
		close_modal()


func _world_data() -> Dictionary:
	var data = session.case_snapshot()
	data.people = session.available_people()
	data.evidence = data.evidence.filter(func(clue): return session.meets(clue.get("requires", {})))
	return data

func _on_location_changed(_id: String) -> void:
	var location = session.location_data()
	if location.is_empty():
		return
	location_title.text = location.name
	location_description.text = location.description
	for id in travel_buttons:
		travel_buttons[id].disabled = id == session.current_location
		travel_buttons[id].visible = session.available_locations().any(func(item): return item.id == id)
		travel_buttons[id].add_theme_stylebox_override("disabled", NoirTheme.selected())
		travel_buttons[id].add_theme_color_override("font_disabled_color", NoirTheme.GOLD)
	room.display_location(location, _world_data(), collected)

func _update_status() -> void:
	_refresh_discovery_hints()
	notebook_button.text = "الأدلة (%d)" % collected.size() + (" ●" if session.known_nodes().any(func(node): return node.kind == "evidence" and _is_unread(node)) else "")
	conclusion_button.disabled = not session.can_conclude()
	conclusion_button.text = "توجيه اتهام"
	if is_instance_valid(_accusation_shortcut):
		_accusation_shortcut.visible = overlay.visible and session.can_conclude() and not case_intro.visible
	status.text = "الشعبية: " + manager.progression.score_text(manager.campaign) if simplified_ui else ""
	if not manager.last_error.is_empty(): status.text = manager.last_error
	status.visible = not status.text.is_empty()
	for id in travel_buttons:
		travel_buttons[id].visible = session.available_locations().any(func(item): return item.id == id)

func show_locations() -> void:
	_open("المواقع")
	var items := []
	for location in session.available_locations():
		items.append({"id": location.id, "label": location.name, "text": location.description, "meta": "أنت هنا" if location.id == session.current_location else "انتقال إلى الموقع", "texture": room.visual_catalog.background_texture(location.get("art", location.id)), "selected": location.id == session.current_location})
	_cards(items, "locations", travel_to)

func show_case_file() -> void:
	if session.phase == "briefing":
		_show_case_intro()
		return
	_open("ملف القضية")
	var info: Dictionary = case_data.case_file
	modal_body.add_child(_label(info.crime_label + " · " + info.number, 17))
	modal_body.add_child(_label(case_data.title, 27))
	modal_body.add_child(_label(info.summary, 20))
	var scene: Dictionary = session.location_data(info.crime_scene)
	modal_body.add_child(_label("الضحية / المتضرر: " + info.victim.name + "
" + info.victim.background + "
مكان الحادث: " + scene.get("name", info.crime_scene), 18))
	_action("التقارير", show_reports)
	_action("إحاطة المساعد", show_assistant)

func _report_card(report: Dictionary) -> void:
	_mark_read("r:" + str(report.id))
	modal_body.add_child(_label(_certainty(report.status), 16))
	modal_body.add_child(_label(report.title, 24))
	_add_known_art("r:" + str(report.id))
	modal_body.add_child(_label(report.summary, 20))
	if not report.get("cause_of_death", "").is_empty():
		modal_body.add_child(_label("سبب الوفاة: " + report.cause_of_death, 19))
	if not report.get("estimated_time", "").is_empty():
		modal_body.add_child(_label("الوقت التقديري: " + report.estimated_time, 19))
	for finding in report.get("findings", []):
		modal_body.add_child(_label("• " + finding, 19))
	if report.has("updated_by"):
		modal_body.add_child(_label("توجد نتائج أحدث لهذا التقرير.", 17))

func show_reports() -> void:
	_open("التقارير")
	var reports: Array = session.available_reports()
	if not session.available_analyses().is_empty():
		_action("طلب تحليل جنائي", _show_analysis_requests, true)
	if reports.is_empty():
		modal_body.add_child(_label("لا توجد تقارير متاحة بعد.", 20))
		return
	_report_page = clampi(_report_page, 0, reports.size() - 1)
	_report_card(reports[_report_page])
	if reports.size() > 1:
		var previous := _action("التقرير السابق", func():
			_report_page -= 1
			show_reports())
		previous.disabled = _report_page == 0
		var count := _label("%d / %d" % [_report_page + 1, reports.size()], 16)
		count.custom_minimum_size = Vector2(66, 56)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.text_direction = Control.TEXT_DIRECTION_LTR
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_modal_actions.add_child(count)
		var next := _action("التقرير التالي", func():
			_report_page += 1
			show_reports())
		next.disabled = _report_page == reports.size() - 1

func _show_analysis_requests() -> void:
	_open("طلبات التحليل")
	var items := []
	for task in session.available_analyses():
		var inputs := []
		for id in task.evidence:
			inputs.append(session.evidence_data(id).get("name", "مادة مسجلة"))
		items.append({"id": task.id, "label": task.title, "text": "، ".join(inputs), "meta": "نتيجة فورية عند الطلب"})
	_cards(items, "analyses", _request_analysis)
	_action("التقارير المنجزة", show_reports)

func _request_analysis(id: String) -> void:
	var result: Dictionary = session.request_analysis(id)
	if result.status not in ["completed", "duplicate"]:
		_open("طلب التحليل")
		modal_body.add_child(_label("اجمع مواد الفحص المطلوبة قبل إرسال هذا الطلب.", 20))
		_action("العودة", _show_analysis_requests)
		return
	_open("نتيجة التحليل")
	_report_card(result.report)
	_action("التقارير", show_reports)
	_action("متابعة التحقيق", close_modal, true)

func _analysis_actions_for_evidence(id: String) -> void:
	for task in session.available_analyses():
		if id in task.evidence:
			_action(task.title, func(): _request_analysis(task.id), true)

func show_assistant() -> void:
	if simplified_ui:
		_open(case_data.assistant.name)
		modal_body.add_child(_label(case_data.assistant.briefing))
		_action("متابعة التحقيق", close_modal)
		return
	_open(case_data.assistant.name)
	_tabs([{"id": "brief", "label": "الإحاطة"}, {"id": "people", "label": "الأشخاص"}, {"id": "locations", "label": "المواقع"}], _assistant_tab, func(tab):
		_assistant_tab = tab
		show_assistant())
	if _assistant_tab == "brief":
		modal_body.add_child(_label(case_data.assistant.briefing))
		_action("إلى الأشخاص", func():
			_assistant_tab = "people"
			show_assistant())
	elif _assistant_tab == "people":
		var items := []
		for person in session.available_people():
			items.append({"id": person.id, "label": person.name, "text": person.get("occupation", ""), "meta": _role(person.role), "texture": room.visual_catalog.character_texture(person.get("art_id", person.id))})
		_cards(items, "people_assistant", _start_dialogue)
	else:
		var items := []
		for location in session.available_locations():
			items.append({"id": location.id, "label": location.name, "text": location.description, "meta": "موقع متاح"})
		_cards(items, "locations_assistant", travel_to)

func begin_investigation() -> void:
	if session.begin_investigation():
		case_intro.hide()
		room._characters.show()
		_on_location_changed(session.current_location)
		close_modal()

func _menu_select(tab: String) -> void:
	_menu_tab = tab
	show_case_menu()

func show_case_menu() -> void:
	if simplified_ui:
		if session.phase == "closed":
			show_story_result()
			return
		_open("القضية")
		modal_body.add_child(_label(case_data.title, 27))
		modal_body.add_child(_label("افحص الموقع وتحدث إلى الأشخاص، ثم اربط المعلومات التي تراها مهمة. يمكنك توجيه الاتهام عندما تكون مستعدًا.", 20))
		_action("التقارير", show_reports)
		_action("إحاطة يزن", show_assistant)
		_action("سجل الحوار", show_dialogue_log)
		if show_title_action: _action("القائمة الرئيسية", func(): return_to_title.emit())
		return
	if session.phase == "briefing":
		_show_case_intro()
		return
	_open("ملف التحقيق")
	if show_title_action:
		_action("القائمة الرئيسية", func(): return_to_title.emit())
	_tabs([{"id": "case", "label": "القضية"}, {"id": "archive", "label": "الأرشيف"}, {"id": "career", "label": "المحقق"}], _menu_tab, _menu_select)
	if _menu_tab == "case":
		modal_body.add_child(_label(case_data.title, 27))
		modal_body.add_child(_label(case_data.case_file.summary, 20))
		_action("ملف الحادث", show_case_file, true)
		_action("التقارير", show_reports)
		_action("المساعد", show_assistant)
		_action("سجل الحوارات السابقة", show_dialogue_log)
	elif _menu_tab == "archive":
		var items := []
		for item in manager.list_cases():
			items.append({"id": item.path, "label": item.title, "text": item.crime_label, "meta": "قضية مفتوحة" if item.id == session.case_id() else "فتح ملف"})
		_cards(items, "archive", _load_selected_case)
		_action("الاتهامات والقرارات", show_accusations)
		_action("حفظ التقدم", _save_progress)
	else:
		var campaign: Dictionary = manager.campaign_summary()
		modal_body.add_child(_label("سجل المحقق", 26))
		modal_body.add_child(_label("السمعة: %s · القرارات المسجلة: %d" % [str(campaign.reputation), campaign.judgments.size()], 20))
		for person_id in campaign.trust:
			modal_body.add_child(_label("الثقة · " + person_id + ": " + str(campaign.trust[person_id]), 18))
		_action("سجل القرارات", show_accusations)

func _save_progress() -> void:
	var saved: bool = manager.save_now()
	_open("حفظ التقدم", false, "compact")
	modal_body.add_child(_label("حُفظ التقدم." if saved else manager.last_error))

func _load_selected_case(path: String) -> void:
	if not manager.open_case(path):
		_open("تعذّر فتح القضية")
		modal_body.add_child(_label(manager.last_error))
		return
	if session.changed.is_connected(_update_status):
		session.changed.disconnect(_update_status)
	if session.location_changed.is_connected(_on_location_changed):
		session.location_changed.disconnect(_on_location_changed)
	session = manager.session
	board_selection.clear()
	proof_selection.clear()
	_active_person_id = ""
	_selected_suspect = ""
	_accusation_tab = "person"
	_menu_tab = "case"
	_report_page = 0
	_pages.clear()
	_attach_session()
	if simplified_ui and session.phase == "briefing":
		begin_investigation()
	elif simplified_ui and session.phase == "closed":
		show_story_result()
	elif session.phase == "briefing":
		show_case_file()
	else:
		close_modal()

func show_inspection(id: String) -> void:
	_dismiss_exploration_hint()
	var info: Dictionary = room.inspection_data(id)
	if info.is_empty():
		return
	if info.has("entries"):
		_open(str(info.label))
		var items := []
		for entry_id in info.entries:
			var entry: Dictionary = room.inspection_data(entry_id)
			var discovered: bool = session.has_evidence(entry_id)
			items.append({"id": entry_id, "label": session.evidence_data(entry_id).get("name", entry.label) if discovered else entry.label, "text": "محفوظ في الدفتر" if discovered else "افحص المحتوى قبل اختيار جمعه", "meta": "مادة مسجلة" if discovered else "فحص المنطقة"})
		_cards(items, str(info.id), show_evidence)
		return
	if not str(info.get("evidence_id", "")).is_empty():
		show_evidence(info.evidence_id)
		return
	_open("فحص المكان", false, "inspect")
	modal_body.add_child(_label(str(info.get("label", "فحص المكان")), 23))
	var description: Variant = info.get("description", "لا توجد مادة قابلة للجمع في هذا العنصر.")
	modal_body.add_child(_label(description if description is String else "لا توجد مادة قابلة للجمع في هذا العنصر.", 20))

func show_evidence(id: String) -> void:
	_dismiss_exploration_hint()
	var clue = session.evidence_data(id)
	if clue.is_empty() or clue.location_id != session.current_location or not session.meets(clue.get("requires", {})):
		return
	var info: Dictionary = room.inspection_data(id)
	_open(clue.name, false, "evidence")
	_add_known_art("e:" + id, true)
	if session.has_evidence(id):
		modal_body.add_child(_label(clue.description, 20))
		modal_body.add_child(_label("محفوظ في دفتر الأدلة.", 17))
		_action("دفتر الأدلة", show_notebook)
		_analysis_actions_for_evidence(id)
	else:
		modal_body.add_child(_label(clue.description, 20))
		if not info.get("art_match", false):
			var context := _label("موضع تفتيش تقريبي؛ قطعة الدليل غير ظاهرة في الخلفية.", 16)
			context.add_theme_color_override("font_color", NoirTheme.MUTED)
			modal_body.add_child(context)
		if info.get("collectible", true):
			_action("أضف إلى دفتر الأدلة", func(): collect_evidence(id), true)
		else:
			modal_body.add_child(_label("هذا العنصر للفحص فقط.", 17))

	if not str(info.get("area_id", "")).is_empty():
		var group_id: String = "area_" + str(info.area_id)
		_action("متابعة تفتيش المنطقة", func(): show_inspection(group_id))

func collect_evidence(id: String) -> void:
	var info: Dictionary = room.inspection_data(id)
	if not info.get("collectible", true):
		return
	if session.collect_evidence(id):
		room.display_location(session.location_data(), _world_data(), collected)
	show_evidence(id)

func show_notebook() -> void:
	_open("دفتر التحقيق", false, "wide")
	if simplified_ui: _notebook_tab = "evidence"
	_tabs([{"id": "evidence", "label": "الأدلة"}, {"id": "statement", "label": "الأقوال"}], _notebook_tab, func(tab):
		_notebook_tab = tab
		show_notebook())
	if simplified_ui: _modal_tabs.hide()
	var items := []
	for node in session.known_nodes():
		if node.kind == _notebook_tab:
			items.append({"id": node.ref, "label": node.label, "text": node.text, "meta": ("● جديد · " if _is_unread(node) else "") + _certainty(node.certainty), "texture": _known_art(node.ref)})
	_cards(items, "notebook_" + _notebook_tab, _show_notebook_entry)

func _show_notebook_entry(ref: String) -> void:
	_mark_read(ref)
	if ref.begins_with("e:"):
		_open("دليل مسجل")
		var card := EvidenceCard.instantiate()
		modal_body.add_child(card)
		card.display(session.evidence_data(ref.trim_prefix("e:")), room.visual_catalog, _known_art(ref) != null, room.visual_catalog.art_notices.get(ref.trim_prefix("e:"), ""))
	else:
		_open("قول مسجل")
		for node in session.known_nodes():
			if node.ref == ref:
				modal_body.add_child(_label(node.label, 24))
				modal_body.add_child(_label(_certainty(node.certainty), 17))
				modal_body.add_child(_label(node.text))
	_action("العودة إلى الدفتر", show_notebook)

func _certainty(value: String) -> String:
	return {"confirmed": "مؤكد", "recorded": "مسجل", "preliminary": "أولي", "uncertain": "غير مؤكد", "claimed": "قول يحتاج تحققًا", "supported": "مسنود بالمعلومات المسجلة", "hypothesis": "فرضية"}.get(value, value)

func _role(value: String) -> String:
	return {"witness": "شاهد", "suspect": "مشتبه به", "both": "شاهد ومشتبه به"}.get(value, value)

func show_dialogue_log() -> void:
	_open("سجل الحوارات السابقة")
	var entries: Array = opening_history.duplicate(true)
	for entry in session.export_state().get("dialogue_history", []):
		entries.append({"title": session.person_data(entry.person_id).get("name", ""), "text": entry.text})
	if entries.is_empty():
		modal_body.add_child(_label("لا توجد حوارات سابقة مسجلة بعد.", 20))
	for entry in entries:
		modal_body.add_child(_label(str(entry.title), 22))
		modal_body.add_child(_label(str(entry.text), 19))
	_action("عودة إلى التحقيق", close_modal)

func show_people() -> void:
	var minimum: int = int(case_data.get("presentation", {}).get("interrogation_min_evidence", 0)) if simplified_ui else 0
	if collected.size() < minimum:
		_open("المحقق: {player_name}", true)
		_show_hero("thinking", true)
		modal_body.add_child(_label("علينا جمع أدلة أكثر أولًا، حتى تكون لدينا أسئلة نستند إليها عند التحدث مع الأشخاص."))
		modal_body.add_child(_label("جمعت %d من %d أدلة مطلوبة لفتح قائمة الأشخاص." % [collected.size(), minimum], 18))
		_action("العودة إلى موقع الجريمة", close_modal)
		return
	_open("الشهود والمشتبه بهم", false, "wide")
	var items := []
	for person in session.available_people():
		items.append({"id": person.id, "label": person.name, "text": person.get("occupation", ""), "meta": _role(person.role), "portrait_card": true, "texture": room.visual_catalog.character_texture(person.get("art_id", person.id))})
	_cards(items, "people", _start_dialogue)

func _start_dialogue(person_id: String = "") -> void:
	_dismiss_exploration_hint()
	var target: String = person_id if not person_id.is_empty() else session.default_witness_id()
	if not session.select_person(target):
		return
	_active_person_id = target
	dialogue_index = 0
	room.present_person(session.person_data(target))
	_show_dialogue()

func _show_dialogue() -> void:
	var person = session.person_data(_active_person_id)
	if person.is_empty():
		return
	_open(person.name, true)
	var lines = session.person_statements(person.id)
	var cue := "%s:%d" % [person.get("art_id", person.id), dialogue_index]
	room.set_character_expression(person.id, room.visual_catalog.dialogue_expressions.get(cue, "neutral"))
	_dialogue_portrait.texture = room._portrait.texture
	if lines.is_empty():
		modal_body.add_child(_label("لا تتوافر أقوال مسجلة لهذه الشخصية في البيانات الحالية."))
	else:
		dialogue_index = mini(dialogue_index, lines.size() - 1)
		session.hear_statement(lines[dialogue_index].id)
		modal_body.add_child(_label(lines[dialogue_index].text))
	if dialogue_index < lines.size() - 1:
		_action("تابع الحديث", func():
			dialogue_index += 1
			_show_dialogue(), true)
	_action("الاستجواب", show_questions)
	_action("العودة إلى التحقيق", close_modal)

func _dialogue_action(actions: HFlowContainer, text: String, action: Callable) -> void:
	var button := _button(text, action)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.custom_minimum_size.x = 240
	actions.add_child(button)

func show_questions() -> void:
	var person = session.person_data(_active_person_id)
	if person.is_empty():
		return
	_open("استجواب · " + person.name, true)
	var items := []
	for question in session.questions_for(person.id):
		items.append({"id": question.id, "label": question.label if question.available else "سؤال غير متاح بعد", "text": "اطرح السؤال" if question.available else "يتطلب معلومات إضافية", "meta": "سُئل" if question.asked else "موضوع استجواب", "disabled": not question.available, "dialogue_option": true, "asked": question.asked, "newly_available": _new_question(question)})
	_cards(items, "questions_" + person.id, _answer_question, 2)

func _answer_question(id: String) -> void:
	var result: Dictionary = session.ask_question(id)
	if result.status != "answered":
		_open("الاستجواب")
		modal_body.add_child(_label("الإجابة غير متاحة حاليًا." if result.status != "provider_error" else "تعذّر اعتماد إجابة مزوّد الحوار."))
		_action("العودة إلى الأسئلة", show_questions)
		return
	var person = session.person_data(_active_person_id)
	_open(person.name, true)
	var legacy_key: String = id.trim_prefix(person.id + "_")
	var cue: String = person.get("art_id", person.id) + ":" + legacy_key
	room.set_character_expression(person.id, room.visual_catalog.question_expressions.get(cue, result.reaction))
	_dialogue_portrait.texture = room._portrait.texture
	modal_body.add_child(_label(result.answer))
	_confronting_question = id
	if not collected.is_empty():
		_action("مناقشة دليل", _show_confront_evidence)
	_action("الأسئلة", show_questions)
	_action("العودة إلى التحقيق", close_modal)

func _show_confront_evidence() -> void:
	_open("ناقش القول بدليل")
	var items := []
	for evidence_id in collected:
		var clue: Dictionary = session.evidence_data(evidence_id)
		items.append({"id": evidence_id, "label": clue.name, "text": clue.description, "meta": "دليل مسجل", "texture": _known_art("e:" + evidence_id)})
	_cards(items, "confront", func(evidence_id): _confront_question(_confronting_question, evidence_id))
	_action("العودة إلى الإجابة", func(): _answer_question(_confronting_question))

func _confront_question(question_id: String, evidence_id: String) -> void:
	var result: Dictionary = session.confront(question_id, evidence_id)
	_open("المحقق: " + (player_name if not player_name.is_empty() else "مناقشة الدليل"), true)
	_show_hero("accusing", true)
	room.set_character_expression(_active_person_id, "concerned" if result.status in ["confirmed", "duplicate"] else "neutral")
	modal_body.add_child(_label(result.get("explanation", "لم تسفر هذه المناقشة عن معلومات إضافية موثقة.")))
	_action("العودة إلى الإجابة", func(): _answer_question(question_id))
	modal_body.add_child(_button("العودة إلى الأسئلة", show_questions))

func _board_filter(tab: String) -> void:
	_board_tab = tab
	show_board()

func show_board() -> void:
	_open("لوح التحقيق", false, "wide")
	_show_hero("thinking")
	if simplified_ui and _board_tab not in ["evidence", "information", "inference"]: _board_tab = "information"
	_tabs([{"id": "evidence", "label": "الأدلة"}, {"id": "statement", "label": "الأقوال"}, {"id": "report", "label": "التقارير"}, {"id": "timeline", "label": "الزمن"}, {"id": "inference", "label": "الاستنتاجات"}, {"id": "person", "label": "الأشخاص"}], _board_tab, _board_filter)
	if simplified_ui:
		_clear(_modal_tabs)
		_tabs([{ "id": "evidence", "label": "الأدلة" }, { "id": "information", "label": "المعلومات" }, { "id": "inference", "label": "الاستنتاجات" }], _board_tab, _board_filter)
	var items := []
	for node in session.known_nodes():
		var information_match: bool = simplified_ui and _board_tab == "information" and node.kind in ["statement", "question", "report", "timeline", "person"]
		if not information_match and node.kind != _board_tab and not (_board_tab == "inference" and node.kind in ["hypothesis", "contradiction"]):
			continue
		items.append({"id": node.ref, "label": node.label, "text": node.text, "meta": _certainty(node.certainty), "texture": _known_art(node.ref), "selected": node.ref in board_selection})
	_cards(items, "board_" + _board_tab, _select_board_evidence)
	var link := _action("ربط المحدد (%d)" % board_selection.size(), _show_link_meanings, true)
	link.disabled = board_selection.size() < 2
	link.tooltip_text = "اختر عنصرين أو أكثر ثم فسّر العلاقة بينهما."
	var details := _action("قراءة العنصر", _show_board_details)
	details.disabled = board_selection.size() != 1
	details.tooltip_text = "حدد عنصرًا واحدًا لقراءة تفاصيله."
	if not board_selection.is_empty():
		_action("مسح", func():
			board_selection.clear()
			show_board())
	if not board_feedback.is_empty():
		_action("نتيجة الربط", _show_board_feedback)

func _show_link_meanings() -> void:
	_open("تفسير الربط")
	modal_body.add_child(_label("ما العلاقة التي تراها بين هذه المعلومات؟", 20))
	for node in session.known_nodes():
		if node.ref in board_selection:
			modal_body.add_child(_label("• " + node.label, 18))
	if case_data.inference_options.size() <= 4:
		for option in case_data.inference_options:
			_action(option.label, func(): _submit_board_inference(option.id))
	else:
		var meanings := []
		for option in case_data.inference_options:
			meanings.append({"id": option.id, "label": option.label, "text": "اختر تفسير العلاقة بين المواد المحددة."})
		_cards(meanings, "link_meanings", _submit_board_inference)
	_action("العودة إلى اللوح", show_board)

func _show_board_details() -> void:
	if board_selection.size() == 1: _mark_read(board_selection[0])
	if board_selection.size() != 1:
		return
	_open("معلومة مسجلة")
	for node in session.known_nodes():
		if node.ref == board_selection[0]:
			if node.kind == "report":
				for report in session.available_reports():
					if node.ref == "r:" + report.id:
						_report_card(report)
			else:
				_add_known_art(node.ref)
				modal_body.add_child(_label(node.label, 25))
				modal_body.add_child(_label(_certainty(node.certainty), 17))
				modal_body.add_child(_label(node.text))
	_action("العودة إلى اللوح", show_board)

func _show_board_feedback() -> void:
	_open("نتيجة الربط")
	modal_body.add_child(_label(board_feedback))
	_action("العودة إلى اللوح", show_board)

func _select_board_evidence(ref: String) -> void:
	if ":" not in ref:
		ref = "e:" + ref
	if ref in board_selection:
		board_selection.erase(ref)
	else:
		board_selection.append(ref)
	board_feedback = ""
	show_board()

func _submit_board_inference(meaning: String) -> void:
	var result: Dictionary = session.link_nodes(board_selection, meaning)
	board_feedback = result.get("explanation", "حُفظ الربط كفرضية تحتاج إلى تحقق." if result.status == "hypothesis" else "تعذّر تسجيل الربط.")
	show_board()

func _charge_tab(tab: String) -> void:
	_accusation_tab = tab
	show_conclusion()

func show_conclusion() -> void:
	if not session.can_conclude():
		return
	_open("توجيه اتهام", false, "wide")
	_show_hero("accusing")
	_tabs([{"id": "person", "label": "الشخص"}, {"id": "materials", "label": "المواد المختارة"}, {"id": "review", "label": "مراجعة الاتهام"}], _accusation_tab, _charge_tab)
	var known: Array = session.known_nodes()
	proof_selection = proof_selection.filter(func(ref): return known.any(func(node): return node.ref == ref))
	if _accusation_tab == "person":
		var items := []
		for person in session.available_people():
			if person.role in ["suspect", "both"]:
				items.append({"id": person.id, "label": person.name, "text": person.get("occupation", ""), "meta": _role(person.role), "texture": room.visual_catalog.character_texture(person.get("art_id", person.id)), "selected": person.id == _selected_suspect})
		_cards(items, "charge_people", _select_charge_person)
		_action("اختيار المواد", func(): _charge_tab("materials"), true).disabled = _selected_suspect.is_empty()
	elif _accusation_tab == "materials":
		var items := []
		for node in known:
			items.append({"id": node.ref, "label": node.label, "text": node.text, "meta": _certainty(node.certainty), "texture": _known_art(node.ref), "selected": node.ref in proof_selection})
		_cards(items, "charge_materials", _toggle_proof)
		_action("مراجعة (%d)" % proof_selection.size(), func(): _charge_tab("review"), true).disabled = _selected_suspect.is_empty()
	else:
		var person: Dictionary = session.person_data(_selected_suspect)
		modal_body.add_child(_label(person.get("name", "لم تختر شخصًا بعد"), 27))
		modal_body.add_child(_label("المواد المرفقة: %d" % proof_selection.size(), 19))
		for node in known:
			if node.ref in proof_selection:
				modal_body.add_child(_label("• " + node.label, 18))
		modal_body.add_child(_label("الحكم يعتمد فقط على المواد التي ترفقها بهذا الاتهام، وليس كل ما اكتشفته. لن تُضاف الاكتشافات اللاحقة إليه تلقائيًا. سيسجَّل الاتهام دون إصدار حكم فوري، ويمكنك متابعة التحقيق.", 18))
		_action("تسجيل الاتهام", func(): choose_suspect(_selected_suspect), true).disabled = _selected_suspect.is_empty()
		_action("تعديل المواد", func(): _charge_tab("materials"))

func _select_charge_person(id: String) -> void:
	_selected_suspect = id
	show_conclusion()

func _toggle_proof(id: String) -> void:
	if id in proof_selection:
		proof_selection.erase(id)
	else:
		proof_selection.append(id)
	show_conclusion()

func choose_suspect(id: String) -> void:
	var result: Dictionary = session.submit_accusation(id, proof_selection)
	if result.status != "submitted":
		return
	_last_accusation_id = result.id
	if simplified_ui:
		var final_result: Dictionary = manager.finish_story_case(result.id)
		if final_result.get("status") == "completed": show_story_result()
		else:
			_open("تعذّر اعتماد النتيجة")
			modal_body.add_child(_label(final_result.get("message", "أعد فتح القضية للمحاولة.")))
		return
	_open("تم تسجيل الاتهام", false, "compact")
	modal_body.add_child(_label("حُفظ الشخص والمواد التي استندت إليها. لم يصدر قرار بعد."))
	_action("متابعة التحقيق", close_modal, true)
	_action("طلب مراجعة الملف", func(): _review_accusation(result.id))

func _review_accusation(id: String) -> void:
	var result: Dictionary = session.review_accusation(id)
	if result.status != "reviewed":
		return
	_open("قرار مراجعة الملف", false, "compact")
	modal_body.add_child(_label("أُقر الاتهام بناءً على الملف المقدم. لا يكشف هذا القرار وحده الحقيقة الفعلية." if result.decision == "charge_established" else "لم تكفِ المواد المقدمة لإثبات الاتهام؛ هذا لا يحدد من ارتكب الجريمة."))
	_show_closing_hint()
	_action("سجل القرارات", show_accusations)

func _show_closing_hint() -> void:
	if session.phase != "closed":
		return
	var hint: Dictionary = case_data.get("presentation", {}).get("closing_hint", {})
	if not hint.is_empty():
		modal_body.add_child(_label(str(hint.get("title", "")), 22))
		modal_body.add_child(_label(str(hint.get("text", "")), 20))

func show_accusations() -> void:
	if simplified_ui:
		show_story_result()
		return
	_open("سجل الاتهامات")
	var records: Array = session.accusations()
	if records.is_empty():
		modal_body.add_child(_label("لا توجد اتهامات مسجلة.", 20))
	else:
		var page: int = clampi(int(_pages.get("judgments", 0)), 0, records.size() - 1)
		_pages["judgments"] = page
		var item: Dictionary = records[page]
		modal_body.add_child(_label(session.person_data(item.suspect_id).name, 25))
		modal_body.add_child(_label("اتهام " + item.id + " · " + ("قيد المراجعة" if item.status == "pending" else ("أُقر الاتهام" if item.decision == "charge_established" else "الأدلة غير كافية")), 20))
		modal_body.add_child(_label("المواد المرفقة: %d" % item.refs.size(), 18))
		if records.size() > 1:
			_action("السابق", func():
				_pages["judgments"] = page - 1
				show_accusations()).disabled = page == 0
			_action("التالي", func():
				_pages["judgments"] = page + 1
				show_accusations()).disabled = page == records.size() - 1
		if item.status == "pending" and session.phase == "investigation":
			_action("طلب القرار", func(): _review_accusation(item.id))
		if item.status == "reviewed":
			_action("تدقيق لاحق — اختياري", func(): _audit_accusation(item.id))
	_show_closing_hint()
	if session.phase == "closed" and case_data.get("allow_reopen", true):
		_action("إعادة فتح القضية", _reopen_case, true)
	_action("العودة إلى الأرشيف", func(): _menu_select("archive"))

func _audit_accusation(id: String) -> void:
	var result: Dictionary = session.audit_accusation(id)
	if result.status != "audited":
		return
	_open("نتيجة التدقيق اللاحق")
	var labels := {"proven": "إثبات الجريمة", "failed": "فشل الاتهام", "wrongful_verdict": "حكم خاطئ اعتمد على أدلة مضللة"}
	modal_body.add_child(_label(labels[result.outcome], 26))
	modal_body.add_child(_label(result.explanation))
	_action("العودة إلى سجل القرارات", show_accusations)

func _reopen_case() -> void:
	if session.reopen_case():
		close_modal()

func restart_case() -> void:
	session.reset()
	board_selection.clear()
	proof_selection.clear()
	board_feedback = ""
	dialogue_index = 0
	_selected_suspect = ""
	_pages.clear()
	_show_case_intro()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and manager.session != null:
		manager.save_now()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay) and overlay.visible and session.phase != "briefing":
		close_modal()
		get_viewport().set_input_as_handled()

func show_story_result() -> void:
	var result: Dictionary = manager.story_result()
	if result.is_empty():
		show_case_menu()
		return
	_open("نتيجة القضية", false, "evidence")
	_close_button.hide()
	var person: Dictionary = session.person_data(result.suspect_id)
	if result.verdict == "supported":
		modal_body.add_child(_label("ثبت الاتهام بالأدلة", 26))
		modal_body.add_child(_label("أثبت الملف المقدم مسؤولية " + str(person.get("name", "المتهم")) + "."))
	else:
		modal_body.add_child(_label("تبرئة المتهم", 26))
		modal_body.add_child(_label("تمت تبرئة " + str(person.get("name", "المتهم")) + " لعدم وجود دليل قطعي."))
	modal_body.add_child(_label(("اكتسبت %d نقاط شعبية." if result.delta > 0 else "خسرت %d نقاط شعبية.") % absi(int(result.delta)), 20))
	modal_body.add_child(_label("شعبية المحقق: " + manager.progression.score_text(manager.campaign), 22))
	var next: Dictionary = manager.progression.next_case(manager.campaign, session.case_id())
	if not next.is_empty() and next.unlocked:
		if next.ready:
			_action("القضية التالية", func(): _load_selected_case(next.path), true)
		else:
			modal_body.add_child(_label("فُتحت " + str(next.title) + "؛ محتواها قيد التجهيز.", 18))
	else:
		modal_body.add_child(_label("أنهيت القضايا المتاحة حاليًا.", 18))
	_show_closing_hint()
	if show_title_action: _action("القائمة الرئيسية", func(): return_to_title.emit(), true)

# Presentation-only reading state; stored with the existing campaign, never used by case rules.
func _ux_state() -> Dictionary:
	if not manager.campaign.flags.get("ui_reading", {}) is Dictionary: manager.campaign.flags["ui_reading"] = {}
	if not manager.campaign.flags.has("ui_reading"): manager.campaign.flags["ui_reading"] = {}
	var all_cases: Dictionary = manager.campaign.flags.ui_reading
	if not all_cases.has(session.case_id()): all_cases[session.case_id()] = {"read": {}, "exploration_seen": false}
	return all_cases[session.case_id()]
func _is_unread(node: Dictionary) -> bool:
	return _ux_state().read.get(node.ref, "") != str(node.text).sha256_text()
func _mark_read(ref: String) -> void:
	for node in session.known_nodes():
		if node.ref == ref:
			_ux_state().read[ref] = str(node.text).sha256_text()
			manager.save_now()
			_refresh_discovery_hints()
			return
func _dismiss_exploration_hint() -> void:
	if not _ux_state().exploration_seen:
		_ux_state().exploration_seen = true
		manager.save_now()
	if is_instance_valid(_exploration_hint): _exploration_hint.hide()
func _refresh_discovery_hints() -> void:
	if not is_instance_valid(notebook_button): return
	var evidence_new := false
	var information_new := false
	for node in session.known_nodes():
		if not _is_unread(node): continue
		if node.kind == "evidence": evidence_new = true
		elif node.kind in ["statement", "question", "report", "timeline", "person"]: information_new = true
	notebook_button.text = "الأدلة (%d)" % collected.size() + (" ●" if evidence_new else "")
	notebook_button.add_theme_color_override("font_color", NoirTheme.GOLD if evidence_new else NoirTheme.TEXT)
	_board_button.text = "لوح التحقيق" + (" ●" if information_new else "")
	_board_button.add_theme_color_override("font_color", NoirTheme.GOLD if information_new else NoirTheme.TEXT)
	_exploration_hint.visible = session.phase == "investigation" and not _ux_state().exploration_seen
func _new_question(question: Dictionary) -> bool:
	if not question.available or question.asked: return false
	for source in case_data.get("questions", []):
		if source.id == question.id: return not source.get("requires", {}).is_empty()
	return false
