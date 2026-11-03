extends "res://scripts/ui/case_intro.gd"
const Hero = preload("res://scripts/ui/hero_portrait.gd")
signal page_changed(index: int)
var story: Dictionary = {}
var history: Array = []
var log_button: Button
var hero: TextureRect
var _queue: Array = []
var _queue_index := 0
var _active_line: Label
var _elapsed := 0.0
var _line_duration := 1.0
var _history_open := false
var _scroll_frames := 0
func _ready() -> void:
	super._ready()
	_scroll.remove_child(_content)
	var transcript_margin := MarginContainer.new()
	transcript_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript_margin.add_theme_constant_override("margin_right", 24)
	_scroll.add_child(transcript_margin)
	transcript_margin.add_child(_content)
	hero = Hero.create("normal")
	add_child(hero)
	move_child(hero, 1)
	log_button = _button("سجل الحوارات", show_history)
	log_button.custom_minimum_size.x = 200
	log_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var actions := skip_button.get_parent()
	actions.add_child(log_button)
	actions.move_child(log_button, 2)
func record(title: String, text: String) -> void:
	var entry := {"title": PlayerProfile.format_text(title, player_name), "text": PlayerProfile.format_text(text, player_name)}
	if entry not in history: history.append(entry)
func _render() -> void:
	_queue.clear()
	_queue_index = 0
	_active_line = null
	_history_open = false
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	back_button.hide()
	next_button.hide()
	_progress.hide()
	_eyebrow.text = "قبل القضية الأولى"
	log_button.text = "سجل الحوارات"
	hero.texture = Hero.texture("normal")
	var heading := _label(PlayerProfile.format_text("{player_name} · بداية الحكاية", player_name), 30, NoirTheme.GOLD)
	if page < 2: _content.add_child(heading)
	else: heading.free()
	var novel: Dictionary = story.get("novel", {})
	var biography: Array = novel.get("biography", [])
	if page == 0:
		_begin_queue(biography.map(func(text): return {"speaker":"", "text":str(text)}))
	else:
		for paragraph in (biography if page == 1 else []): _append_line({"speaker":"", "text":str(paragraph)}, false)
		if page == 1: _append_line({"speaker":"", "text":str(novel.get("ring", "اتصال وارد من يزن."))}, false)
		if page == 1:
			_offer_answer()
		elif page == 2:
			_eyebrow.text = "اتصال يزن"
			_begin_queue(novel.get("conversation", []))
		else:
			for line in novel.get("conversation", []): _append_line(line, false)
			_append_line({"speaker":"", "text":str(novel.get("arrival", ""))}, false)
			_offer_arrival()
	show()
	_scroll_frames = 3
func _begin_queue(lines: Array) -> void:
	_queue = lines.duplicate(true)
	_queue_index = 0
	next_button.hide()
	_append_next()
func _append_next() -> void:
	if _queue_index < _queue.size():
		_append_line(_queue[_queue_index], true)
		_queue_index += 1
		return
	_active_line = null
	if page == 0:
		page = 1
		page_changed.emit(page)
		_append_line({"speaker":"", "text":str(story.novel.get("ring", "اتصال وارد من يزن."))}, false)
		_offer_answer()
	elif page == 2:
		page = 3
		page_changed.emit(page)
		_begin_queue([{"speaker":"", "text":str(story.novel.get("arrival", ""))}])
	elif page == 3:
		_offer_arrival()
func _append_line(entry: Dictionary, animated: bool) -> void:
	var speaker := PlayerProfile.format_text(str(entry.get("speaker", "")), player_name)
	var text := PlayerProfile.format_text(str(entry.get("text", "")), player_name)
	if not speaker.is_empty():
		_content.add_child(_label(speaker, 17, NoirTheme.GOLD))
	var paragraph := _label(text, 21)
	_content.add_child(paragraph)
	record(speaker if not speaker.is_empty() else "السرد", text)
	if animated:
		_active_line = paragraph
		paragraph.visible_ratio = 0
		_elapsed = 0
		_line_duration = clampf(text.length() / float(story.get("novel", {}).get("characters_per_second", 38)), 0.7, 3.2)
	_scroll_frames = 3
func _process(delta: float) -> void:
	if not visible or _history_open: return
	if _scroll_frames > 0:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
		_scroll_frames -= 1
	if not is_instance_valid(_active_line): return
	_elapsed += delta
	_active_line.visible_ratio = minf(1.0, _elapsed / _line_duration)
	if _elapsed >= _line_duration + float(story.get("novel", {}).get("pause_between_lines", 0.8)):
		_active_line = null
		_append_next()
func _offer_answer() -> void:
	_eyebrow.text = "اتصال وارد من يزن"
	next_button.text = "الرد على الاتصال"
	next_button.show()
func _offer_arrival() -> void:
	_eyebrow.text = "المكالمة الأخيرة"
	next_button.text = "الانتقال إلى مسرح الجريمة"
	next_button.show()
func advance() -> void:
	if page == 1:
		page = 2
		page_changed.emit(page)
		_render()
	elif page == 3 and not is_instance_valid(_active_line):
		finished.emit()
func previous() -> void:
	pass
func show_history() -> void:
	_history_open = not _history_open
	log_button.text = "متابعة السرد" if _history_open else "سجل الحوارات"
	if _history_open: _scroll.scroll_vertical = 0
	else: _scroll_frames = 3
