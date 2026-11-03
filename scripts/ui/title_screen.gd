extends Control
const Noir = preload("res://scripts/ui/noir_theme.gd")
const Intro = preload("res://scripts/ui/story_opening.gd")
const Profile = preload("res://scripts/core/player_profile.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Manager = preload("res://scripts/core/case_manager.gd")
const Repository = preload("res://scripts/core/case_repository.gd")
const FIRST_CASE := "res://data/cases/last_call.json"
@export var profile_path := "user://player_progress.json"
@export var save_path := "user://investigation_progress.json"
@export var persistence_enabled := true
var profile = Profile.new()
var body: VBoxContainer
var panel: PanelContainer
var name_input: LineEdit
var message: Label
var intro: Control
var game: Control
var menu_buttons: Dictionary = {}
var _story: Dictionary = {}
var _story_log: Array = []
var _intro_target := FIRST_CASE
var _opening_background: TextureRect
const STUDY_BACKGROUND = preload("res://assets/backgrounds/Moody Detective’s Nighttime Study.png")
const CALL_BACKGROUND = preload("res://assets/backgrounds/Noir Detective Office_ Incoming Call.png")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = Noir.build()
	profile.path = profile_path
	profile.persistence_enabled = persistence_enabled
	profile.load_progress()
	AudioServer.set_bus_volume_db(0, linear_to_db(float(profile.data.volume)))
	var background := TextureRect.new()
	background.texture = STUDY_BACKGROUND
	_opening_background = background
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(Noir.BACKGROUND, 0.48)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.52
	panel.anchor_right = 0.96
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	panel.add_theme_stylebox_override("panel", Noir.modal())
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	body = VBoxContainer.new()
	body.layout_direction = Control.LAYOUT_DIRECTION_RTL
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	show_menu()
func _clear(title: String) -> void:
	_opening_background.texture = STUDY_BACKGROUND
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	menu_buttons.clear()
	panel.show()
	var heading := _label(title, 32)
	heading.add_theme_color_override("font_color", Noir.GOLD)
	body.add_child(heading)
func _label(value: String, size: int = 21) -> Label:
	var label := Label.new()
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text = Profile.format_text(value, profile.data.player_name)
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label
func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.custom_minimum_size.y = 62
	button.pressed.connect(callback)
	body.add_child(button)
	menu_buttons[text] = button
	return button
func _has_case_save() -> bool:
	if not persistence_enabled:
		return false
	var saved := Store.load_save(save_path)
	return saved.status == "loaded" and not saved.data.cases.is_empty()
func show_menu() -> void:
	_clear("الدقيقة المفقودة")
	body.add_child(_label("كل حقيقة تبدأ بسؤال.", 20))
	var progress = _progress_manager()
	body.add_child(_label("شعبية المحقق: " + progress.progression.score_text(progress.campaign), 20))
	if not profile.data.player_name.is_empty():
		body.add_child(_label("المحقق: {player_name}", 21))
	_button("لعبة جديدة", show_modes).disabled = not profile.write_allowed
	_button("متابعة", continue_game).disabled = profile.data.player_name.is_empty() and not _has_case_save()
	_button("القضايا", show_cases)
	_button("الإعدادات", show_settings)
	if not profile.error.is_empty():
		body.add_child(_label(profile.error, 18))
func show_modes() -> void:
	_clear("اختيار نمط اللعب")
	_button("لعب فردي", show_identity)
	body.add_child(_label("أنت المحقق الرئيسي، ويزن مساعدك القصصي.", 19))
	_button("لعب تعاوني", show_cooperative)
	body.add_child(_label("طور قيد التطوير؛ الاتصال الشبكي غير متاح حاليًا.", 19))
	_button("عودة", show_menu)
func show_cooperative() -> void:
	_clear("لعب تعاوني · قيد التطوير")
	body.add_child(_label("شاشة تحضيرية فقط؛ لا تُنشأ غرف ولا يجري اتصال شبكي.", 19))
	for role_id in Profile.ROLES:
		var role: Dictionary = Profile.ROLE_DEFINITIONS[role_id]
		body.add_child(_label(role.label + ": " + role.description, 18))
	_button("إنشاء غرفة", func(): _room_notice("إنشاء غرفة"))
	_button("الانضمام لغرفة", func(): _room_notice("الانضمام لغرفة"))
	_button("عودة", show_modes)
func _room_notice(action: String) -> void:
	_clear(action + " · قيد التطوير")
	body.add_child(_label("هذا الخيار غير متاح بعد. لا يوجد اتصال شبكي، ولم يُغيّر تقدمك المحفوظ."))
	_button("عودة", show_cooperative)
func show_identity() -> void:
	_clear("من يقود التحقيق؟")
	body.add_child(_label("أدخل اسم المحقق الذي سيظهر في المقدمة والحوارات."))
	name_input = LineEdit.new()
	name_input.placeholder_text = "اسم اللاعب"
	name_input.layout_direction = Control.LAYOUT_DIRECTION_LTR
	name_input.text_direction = Control.TEXT_DIRECTION_RTL
	name_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_input.max_length = 28
	name_input.custom_minimum_size.y = 64
	body.add_child(name_input)
	name_input.text_submitted.connect(func(_text): submit_identity())
	if _has_case_save():
		body.add_child(_label("بدء لعبة جديدة سيستبدل تقدم التحقيق السابق. المتابعة تحافظ عليه.", 18))
	message = _label("", 18)
	body.add_child(message)
	name_input.text_changed.connect(func(_value): message.text = "")
	_button("بدء جديد واستبدال التقدم" if _has_case_save() else "ابدأ الحكاية", submit_identity)
	_button("عودة", show_modes)
	name_input.grab_focus()
func submit_identity() -> void:
	if not profile.new_player(name_input.text):
		message.text = profile.error
		return
	if persistence_enabled:
		var result := Store.save(save_path, {"reputation": 0, "trust": {}, "flags": {}, "judgments": []}, {})
		if result != OK:
			message.text = "تعذّر بدء تقدم جديد؛ لم تبدأ المقدمة."
			return
	_story_log.clear()
	start_intro(FIRST_CASE)
func continue_game() -> void:
	var target: String = profile.data.last_case
	var progress = _progress_manager()
	if not progress.progression.catalog(progress.campaign).any(func(item): return item.path == target and item.ready and item.unlocked):
		target = FIRST_CASE
	if not profile.data.intro_seen and not profile.data.player_name.is_empty():
		start_intro(target)
	else:
		open_case(target)
func start_intro(target: String) -> void:
	_intro_target = target
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_intro.json"))
	if not source is Dictionary or not source.get("scenes") is Array or source.scenes.size() != 4:
		_clear("تعذّر عرض المقدمة")
		body.add_child(_label("بيانات المقدمة غير صالحة."))
		_button("عودة", show_menu)
		return
	_story = {"scenes": source.scenes.duplicate(true), "office_items": source.get("office_items", []).duplicate(true), "call_questions": source.get("call_questions", []).duplicate(true), "novel": source.get("novel", {}).duplicate(true)} # Author-only lore is not retained by the UI.
	panel.hide()
	intro = Intro.new()
	intro.player_name = profile.data.player_name
	intro.story = _story
	intro.history = _story_log
	add_child(intro)
	intro._pages = _story.scenes.duplicate(true)
	intro.page = clampi(int(profile.data.intro_page), 0, 3)
	intro.finished.connect(finish_intro)
	intro.page_changed.connect(func(current_page):
		_set_opening_background(current_page)
		remember_intro_page())
	intro.skip_button.text = "تخطي المقدمة"
	intro.show()
	intro._render()
	_set_opening_background(intro.page)

func _set_opening_background(current_page: int) -> void:
	_opening_background.texture = CALL_BACKGROUND if current_page >= 2 else STUDY_BACKGROUND

func remember_intro_page() -> void:
	if is_instance_valid(intro) and intro.visible:
		profile.data.intro_page = intro.page
		profile.save()

func finish_intro() -> void:
	profile.data.intro_seen = true
	profile.data.intro_page = 3
	if not profile.save():
		intro.hide()
		_clear("تعذّر حفظ تقدم اللاعب")
		body.add_child(_label(profile.error))
		_button("إعادة المحاولة", finish_intro)
		return
	if is_instance_valid(intro):
		remove_child(intro)
		intro.queue_free()
	open_case(_intro_target)
var arrival_intro: Control
func open_case(path: String) -> void:
	panel.hide()
	game = preload("res://main.tscn").instantiate()
	game.case_path = path
	game.save_path = save_path
	game.persistence_enabled = persistence_enabled
	game.player_name = profile.data.player_name
	game.opening_history = _story_log
	game.show_title_action = true
	game.simplified_ui = true
	game.return_to_title.connect(return_to_menu)
	add_child(game)
	if game.manager.session != null and path == FIRST_CASE and game.session.phase == "briefing":
		game.begin_investigation()
		_show_arrival_summary()
	if game.manager.session != null:
		profile.data.last_case = path
		profile.save()
func _show_arrival_summary() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/last_call_arrival.json"))
	if not source is Dictionary: return
	game._investigation_chrome.hide()
	game._accusation_shortcut.hide()
	arrival_intro = preload("res://scripts/ui/arrival_summary.gd").new()
	arrival_intro.player_name = profile.data.player_name
	arrival_intro.story = {"novel": source}
	arrival_intro.history = _story_log
	add_child(arrival_intro)
	arrival_intro.finished.connect(_close_arrival_summary)
	arrival_intro._render()
func _close_arrival_summary() -> void:
	if is_instance_valid(arrival_intro):
		remove_child(arrival_intro)
		arrival_intro.queue_free()
		if is_instance_valid(game): game.close_modal()
func return_to_menu() -> void:
	_close_arrival_summary()
	if is_instance_valid(game):
		if game.manager.session != null:
			profile.data.last_case = game.session.case_path
			game.manager.save_now()
		profile.save()
		remove_child(game)
		game.queue_free()
	show_menu()
func _progress_manager():
	var progress = Manager.new()
	progress.story_mode = true
	progress.save_path = save_path
	progress.persistence_enabled = persistence_enabled
	progress.load_progress()
	return progress
func show_cases() -> void:
	_clear("القضايا")
	var progress = _progress_manager()
	body.add_child(_label("شعبية المحقق: %d" % progress.progression.score(progress.campaign), 20))
	for record in progress.progression.catalog(progress.campaign):
		var button := _button(record.title, func(): open_case(record.path))
		button.disabled = not record.unlocked or not record.ready
		if not record.unlocked: body.add_child(_label("أكمل القضية السابقة لفتحها.", 17))
		elif not record.ready: body.add_child(_label("مفتوحة — المحتوى قيد التجهيز.", 17))
		elif record.completed: body.add_child(_label("منتهية", 17))
	_button("عودة", show_menu)
func show_settings() -> void:
	_clear("الإعدادات")
	body.add_child(_label("مستوى الصوت"))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = profile.data.volume
	volume.custom_minimum_size.y = 60
	volume.value_changed.connect(func(value):
		profile.data.volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(value)))
	body.add_child(volume)
	_button("حفظ وعودة", func():
		if profile.save(): show_menu()
		else: body.add_child(_label(profile.error)))
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		remember_intro_page()
		if is_instance_valid(game) and game.manager.session != null:
			profile.data.last_case = game.session.case_path
		profile.save()
