extends RefCounted
signal save_failed(message: String)
const Session = preload("res://scripts/core/investigation_session.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Campaign = preload("res://scripts/core/campaign_state.gd")
const Repository = preload("res://scripts/core/case_repository.gd")
const Progression = preload("res://scripts/core/case_progression.gd")
var progression = Progression.new()
var story_mode := false
var campaign = Campaign.new()
var session: RefCounted
var save_path := "user://investigation_progress.json"
var persistence_enabled := true
var _cases: Dictionary = {}
var last_error := ""
var restored := false
var _write_allowed := true
var _blocked_reason := ""

func load_progress() -> bool:
	if not persistence_enabled:
		return true
	var result := Store.load_save(save_path)
	if result.status == "missing":
		return true
	if result.status != "loaded" or not campaign.restore(result.data.campaign):
		last_error = "تعذّر قراءة الحفظ. لم يُستبدل الملف الموجود."
		_write_allowed = false
		_blocked_reason = last_error
		return false
	for id in result.data.cases:
		if not result.data.cases[id] is Dictionary or not result.data.cases[id].get("state") is Dictionary:
			last_error = "بنية حفظ القضايا غير صالحة."
			_write_allowed = false
			return false
	_cases = result.data.cases.duplicate(true)
	return true

func list_cases() -> Array[Dictionary]:
	return Repository.list_cases()

func open_case(path: String) -> bool:
	if story_mode:
		var allowed := progression.catalog(campaign).filter(func(item): return item.path == path and item.ready and item.unlocked)
		if allowed.is_empty():
			last_error = "هذه القضية غير متاحة بعد؛ أنهِ القضية السابقة أولًا."
			return false
	var candidate = Session.new()
	candidate.campaign = campaign
	if not candidate.load_case(path):
		last_error = "تعذّر تحميل القضية: " + str(candidate.errors)
		return false
	if story_mode and not progression.catalog(campaign).any(func(item): return item.path == path and item.id == candidate.case_id()):
		last_error = "معرف القضية لا يطابق ترتيب القضايا."
		return false
	if not story_mode and not candidate.meets(candidate._case.get("requirements", {})):
		last_error = "هذه القضية غير متاحة وفق سجل المحقق الحالي."
		return false
	restored = false
	if _cases.has(candidate.case_id()):
		var saved: Dictionary = _cases[candidate.case_id()]
		if not candidate.restore_state(saved.state):
			last_error = "الحفظ لا يطابق إصدار القضية أو يحتوي بيانات غير صالحة؛ لم يُستبدل."
			_write_allowed = false
			return false
		restored = true
	if session != null and session.changed.is_connected(_save_current):
		session.changed.disconnect(_save_current)
	if session != null:
		_save_current()
	session = candidate
	session.changed.connect(_save_current)
	if story_mode and session.phase == "closed":
		for item in session.export_state().accusations:
			if item.status == "reviewed":
				finish_story_case(item.id)
				break
	last_error = "" if _write_allowed else _blocked_reason
	return true

func _save_current() -> void:
	if session == null:
		return
	_cases[session.case_id()] = {"path": session.case_path, "state": session.export_state()}
	if not _write_allowed:
		last_error = _blocked_reason
		return
	if not persistence_enabled:
		return
	var error := Store.save(save_path, campaign.snapshot(), _cases)
	if error != OK:
		last_error = "تعذّر حفظ التقدم على الجهاز."
		save_failed.emit(last_error)
	else:
		last_error = ""

func save_now() -> bool:
	_save_current()
	return last_error.is_empty() and _write_allowed

func campaign_summary() -> Dictionary:
	return campaign.public_snapshot()

func finish_story_case(accusation_id: String) -> Dictionary:
	if not story_mode or session == null or not _write_allowed:
		return {"status": "error", "message": "تعذّر اعتماد نتيجة القضية أو حفظها."}
	var results: Dictionary = campaign.flags.get("story_case_results", {}).duplicate(true)
	if results.has(session.case_id()):
		return results[session.case_id()].duplicate(true)
	var records: Array = session.export_state().accusations
	var matches: Array = records.filter(func(item): return item.id == accusation_id)
	if matches.is_empty(): return {"status": "invalid"}
	if matches[0].status == "pending":
		if session.review_accusation(accusation_id).status != "reviewed": return {"status": "locked"}
	matches = session.export_state().accusations.filter(func(item): return item.id == accusation_id)
	if matches[0].status != "reviewed": return {"status": "invalid"}
	# Only a factually correct AND sufficiently supported charge earns popularity.
	var verdict: String = "supported" if matches[0].outcome == "proven" else "acquitted"
	var config := progression.definition()
	if config.is_empty(): return {"status": "error", "message": progression.error}
	var delta := int(config.popularity_awards[verdict])
	var result := {"status": "completed", "verdict": verdict, "delta": delta, "suspect_id": matches[0].suspect_id, "accusation_id": accusation_id}
	results[session.case_id()] = result
	campaign.flags["story_case_results"] = results
	campaign.flags["detective_popularity"] = progression.score(campaign) + delta
	_save_current()
	return result.duplicate(true)
func story_result() -> Dictionary:
	return campaign.flags.get("story_case_results", {}).get(session.case_id(), {}).duplicate(true) if session != null else {}
