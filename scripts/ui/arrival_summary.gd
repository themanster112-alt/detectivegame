extends "res://scripts/ui/story_opening.gd"
## Separate short monologue panels; never changes investigation state.
var section := 0
func _render() -> void:
	var sections: Array = story.novel.get("sections", [])
	if sections.is_empty(): return
	story.novel.biography = sections[section].paragraphs
	super._render()
	_eyebrow.text = "موقع الجريمة · حديث داخلي"
	_content.get_child(0).text = sections[section].title
	hero.texture = Hero.texture("thinking")
	skip_button.text = "تجاوز الملخص وابدأ التحقيق"
func _append_next() -> void:
	if _queue_index < _queue.size():
		_append_line(_queue[_queue_index], true)
		_queue_index += 1
		return
	_active_line = null
	next_button.text = "التالي" if section + 1 < story.novel.sections.size() else "ابدأ التحقيق"
	next_button.show()
func advance() -> void:
	if is_instance_valid(_active_line): return
	if section + 1 < story.novel.sections.size():
		section += 1
		_render()
	else: finished.emit()
