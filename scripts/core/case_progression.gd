extends RefCounted
var path := "res://data/campaign_sequence.json"
var error := ""
func definition() -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		error = "تعذّر قراءة ترتيب القضايا."
		return {}
	var data: Dictionary = json.data
	if data.get("version") != 1 or not data.get("cases") is Array or not data.get("popularity_awards") is Dictionary:
		error = "بنية ترتيب القضايا غير صالحة."
		return {}
	var ids := []
	for entry in data.cases:
		if not entry is Dictionary or not entry.get("id") is String or entry.id.is_empty() or entry.id in ids or not entry.get("title") is String or not entry.get("path") is String:
			error = "تعريف قضية غير صالح."
			return {}
		if not entry.path.is_empty() and (not entry.path.begins_with("res://") or entry.path.get_extension() != "json"):
			error = "مسار قضية غير صالح."
			return {}
		ids.append(entry.id)
	for key in ["supported", "acquitted"]:
		if not (data.popularity_awards.get(key) is int or data.popularity_awards.get(key) is float) or not is_finite(float(data.popularity_awards[key])):
			error = "نقاط الشعبية غير صالحة."
			return {}
	error = ""
	return data
func completed(campaign: RefCounted, id: String) -> bool:
	return campaign.flags.get("story_case_results", {}).has(id) or campaign.judgments.any(func(item): return item.case_id == id)
func catalog(campaign: RefCounted) -> Array[Dictionary]:
	var data := definition()
	var result: Array[Dictionary] = []
	var previous := ""
	for entry in data.get("cases", []):
		var record: Dictionary = entry.duplicate(true)
		record.unlocked = previous.is_empty() or completed(campaign, previous)
		record.ready = not record.path.is_empty() and FileAccess.file_exists(record.path)
		record.completed = completed(campaign, record.id)
		result.append(record)
		previous = record.id
	return result
func score(campaign: RefCounted) -> int:
	return int(campaign.flags.get("detective_popularity", 0))
func score_text(campaign: RefCounted) -> String:
	var value := score(campaign)
	return "ناقص %d" % absi(value) if value < 0 else str(value)
func next_case(campaign: RefCounted, id: String) -> Dictionary:
	var entries := catalog(campaign)
	for index in range(entries.size() - 1):
		if entries[index].id == id: return entries[index + 1]
	return {}
