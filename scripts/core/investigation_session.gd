extends RefCounted
## The only authority for case progress. UI and dialogue providers never own the truth.
signal changed
signal location_changed(location_id: String)
const CaseLoader = preload("res://scripts/core/case_loader.gd")
const Campaign = preload("res://scripts/core/campaign_state.gd")
const LocalProvider = preload("res://scripts/dialogue/local_dialogue_provider.gd")
var campaign = Campaign.new()
var _provider: RefCounted = LocalProvider.new()
var _case: Dictionary = {}
var _collected: Array[String] = []
var _heard: Array[String] = []
var _contacted: Array[String] = []
var _asked_questions: Array[String] = []
var _confirmed_inferences: Array[String] = []
var _contradictions: Array[String] = []
var _reports: Array[String] = []
var _requested_analyses: Array[String] = []
var _hypotheses: Array = []
var _accusations: Array = []
var _dialogue_history: Array = []
var current_location := ""
var active_person := ""
var phase := "briefing"
var errors: Array = []
var content_hash := ""
var case_path := ""
var solved := false

func load_case(path: String) -> bool:
	var loaded := CaseLoader.load_case(path)
	errors = loaded.errors
	if not errors.is_empty():
		return false
	return _accept_case(loaded.data, loaded.content_hash, path)

func load_data(data: Dictionary) -> bool:
	var loaded := CaseLoader.prepare(data)
	errors = loaded.errors
	if not errors.is_empty():
		return false
	return _accept_case(loaded.data, JSON.stringify(data).sha256_text(), "")

func _accept_case(data: Dictionary, hash_value: String, path: String) -> bool:
	_case = data.duplicate(true)
	content_hash = hash_value
	case_path = path
	reset()
	return true

func case_id() -> String:
	return _case.get("id", "")

func _record(table: String, id: String) -> Dictionary:
	for record in _case.get(table, []):
		if record.id == id:
			return record.duplicate(true)
	return {}

func case_snapshot() -> Dictionary:
	var public := _case.duplicate(true)
	for key in ["truth", "facts", "assessment", "campaign_effects", "culprit", "solution", "proof_options", "accusation", "retry_hint", "objective", "witness", "suspects"]:
		public.erase(key)
	for person in public.get("people", []):
		person.erase("ai")
	for question in public.get("questions", []):
		question.erase("answer_facts")
	public["statements"] = heard_statements()
	public["reports"] = available_reports()
	public["timeline"] = timeline()
	public["inferences"] = []
	for id in _confirmed_inferences:
		public.inferences.append(_record("inferences", id))
	public["contradictions"] = []
	for id in _contradictions:
		public.contradictions.append(_record("contradictions", id))
	return public

func meets(requirements: Dictionary) -> bool:
	var progress := {"evidence": _collected, "statements": _heard, "questions": _asked_questions, "reports": _reports, "inferences": _confirmed_inferences, "contradictions": _contradictions, "people": _contacted_people()}
	for key in requirements:
		if key == "global":
			if not campaign.matches(requirements[key]):
				return false
		else:
			for id in requirements[key]:
				if id not in progress.get(key, []):
					return false
	return true

func _contacted_people() -> Array:
	var result: Array = _contacted.duplicate()
	for id in _heard:
		var person_id: String = _record("statements", id).get("person_id", "")
		if person_id not in result:
			result.append(person_id)
	if not active_person.is_empty() and active_person not in result:
		result.append(active_person)
	return result

func _touch() -> void:
	# Iterate to support a report update that depends on another newly available report.
	for iteration in range(_case.get("reports", []).size() + 1):
		var previous := _reports.size()
		for report in _case.get("reports", []):
			if report.id not in _reports and meets(report.get("requires", {})) and (not report.get("request_required", false) or report.id in _requested_analyses):
				_reports.append(report.id)
		if previous == _reports.size():
			break
	changed.emit()

func begin_investigation() -> bool:
	if _case.is_empty() or phase == "closed" or not meets(_case.get("requirements", {})):
		return false
	phase = "investigation"
	_touch()
	return true

func location_data(id: String = "") -> Dictionary:
	return _record("locations", current_location if id.is_empty() else id)

func available_locations() -> Array:
	return _case.get("locations", []).filter(func(item): return meets(item.get("requires", {}))).duplicate(true)

func evidence_data(id: String) -> Dictionary:
	return _record("evidence", id)

func collected_ids() -> Array[String]:
	return _collected.duplicate()

func has_evidence(id: String) -> bool:
	return id in _collected

func travel_to(id: String) -> bool:
	var location := location_data(id)
	if phase != "investigation" or location.is_empty() or not meets(location.get("requires", {})):
		return false
	active_person = ""
	if current_location != id:
		current_location = id
		location_changed.emit(id)
	_touch()
	return true

func collect_evidence(id: String) -> bool:
	var clue := evidence_data(id)
	if phase != "investigation" or clue.is_empty() or clue.location_id != current_location or has_evidence(id) or not meets(clue.get("requires", {})):
		return false
	_collected.append(id)
	_touch()
	return true

func person_data(id: String) -> Dictionary:
	var person := _record("people", id)
	person.erase("ai")
	return person

func available_people() -> Array:
	var result := []
	for person in _case.get("people", []):
		if meets(person.get("requires", {})):
			var item: Dictionary = person.duplicate(true)
			item.erase("ai")
			result.append(item)
	return result

func select_person(id: String) -> bool:
	var person := person_data(id)
	if phase != "investigation" or person.is_empty() or not meets(person.get("requires", {})):
		return false
	active_person = id
	if id not in _contacted:
		_contacted.append(id)
	_touch()
	return true

func default_witness_id() -> String:
	for person in _case.get("people", []):
		if person.role in ["witness", "both"]:
			return person.id
	return _case.get("people", [{}])[0].get("id", "") if not _case.is_empty() else ""

func statement_data(id: String) -> Dictionary:
	var statement := _record("statements", id)
	if statement.is_empty() or not meets(statement.get("requires", {})):
		return {}
	var person := person_data(statement.person_id)
	return statement if not person.is_empty() and meets(person.get("requires", {})) else {}

func person_statements(id: String) -> Array:
	var result := []
	var person := person_data(id)
	for statement_id in person.get("statement_ids", []):
		var statement := statement_data(statement_id)
		if not statement.is_empty():
			result.append(statement)
	return result

func hear_statement(id: String) -> bool:
	var statement := statement_data(id)
	if phase != "investigation" or statement.is_empty() or statement.person_id != active_person or id in _heard:
		return false
	_heard.append(id)
	_touch()
	return true

func heard_statements() -> Array:
	var result := []
	for id in _heard:
		result.append(_record("statements", id))
	return result

func witness_heard() -> bool:
	var statements := person_statements(default_witness_id())
	return not statements.is_empty() and statements.all(func(item): return item.id in _heard)

func record_witness() -> bool:
	var id := default_witness_id()
	var person := person_data(id)
	if person.is_empty() or phase != "investigation" or (active_person != id and current_location != person.get("location_id")):
		return false
	active_person = id
	var recorded := false
	for statement in person_statements(id):
		if hear_statement(statement.id):
			recorded = true
	return recorded

func _question_id(id: String, person_id: String = "") -> String:
	if not _record("questions", id).is_empty():
		return id
	var target := person_id if not person_id.is_empty() else (active_person if not active_person.is_empty() else default_witness_id())
	for question in _case.get("questions", []):
		if question.person_id == target and question.get("legacy_id") == id:
			return question.id
	return ""

func questions_for(id: String) -> Array:
	var result := []
	for question in _case.get("questions", []):
		if question.person_id == id:
			result.append({"id": question.id, "label": question.label, "available": not dialogue_context(id, question.id).is_empty(), "asked": question.id in _asked_questions, "expression": question.get("expression", "neutral")})
	return result

func asked_questions() -> Array[String]:
	return _asked_questions.duplicate()

func set_dialogue_provider(provider: RefCounted) -> bool:
	if provider == null or not provider.has_method("respond"):
		return false
	_provider = provider
	return true

func dialogue_context(person_id: String, question_id: String) -> Dictionary:
	var person := _record("people", person_id)
	var question := _record("questions", _question_id(question_id, person_id))
	if person.is_empty() or question.is_empty() or question.person_id != person_id or not meets(person.get("requires", {})) or not meets(question.get("requires", {})):
		return {}
	var ai: Dictionary = person.ai
	var allowed := []
	for id in question.answer_facts:
		var fact := _record("facts", id)
		if id not in ai.knows and id not in ai.conceals and id not in ai.lies:
			continue
		if meets(fact.get("requires", {})):
			allowed.append({"id": fact.id, "text": fact.text, "variants": fact.get("variants", []).duplicate()})
	if allowed.is_empty():
		return {}
	var visible_evidence := []
	for id in ai.known_evidence:
		if has_evidence(id):
			visible_evidence.append(evidence_data(id))
	return {"speaker": {"id": person.id, "name": person.name, "personality": ai.personality, "speech_style": ai.speech_style}, "question": {"id": question.id, "label": question.label}, "allowed_facts": allowed, "known_evidence": visible_evidence}

func ask_question(id: String) -> Dictionary:
	var question_id := _question_id(id)
	var question := _record("questions", question_id)
	if phase != "investigation" or question.is_empty() or active_person != question.get("person_id"):
		return {"status": "invalid"}
	var request := dialogue_context(active_person, question_id)
	if request.is_empty():
		return {"status": "locked"}
	var reply: Variant = _provider.respond(request.duplicate(true))
	# Validate all output; do not accept arbitrary prose, hidden facts or provider actions.
	if not reply is Dictionary or not reply.get("segments") is Array or reply.segments.is_empty():
		return {"status": "provider_error"}
	var text := []
	var used := []
	for segment in reply.segments:
		if not segment is Dictionary or not segment.get("fact_id") is String or not segment.get("variant") is int or segment.fact_id in used:
			return {"status": "provider_error"}
		var matches: Array = request.allowed_facts.filter(func(fact): return fact.id == segment.fact_id)
		if matches.is_empty():
			return {"status": "provider_error"}
		var fact: Dictionary = matches[0]
		var variants: Array = [fact.text] + fact.variants
		if segment.variant < 0 or segment.variant >= variants.size():
			return {"status": "provider_error"}
		used.append(segment.fact_id)
		text.append(variants[segment.variant])
	if question_id not in _asked_questions:
		_asked_questions.append(question_id)
	var answer := "
".join(text)
	_dialogue_history.append({"question_id": question_id, "person_id": active_person, "text": answer, "fact_ids": used})
	_touch()
	var reaction: String = reply.get("reaction", "neutral") if reply.get("reaction", "neutral") in ["neutral", "concerned", "defensive"] else "neutral"
	return {"status": "answered", "answer": answer, "reaction": reaction}

func dialogue_history() -> Array:
	return _dialogue_history.duplicate(true)

func available_analyses() -> Array:
	var result := []
	if phase != "investigation":
		return result
	for report in _case.get("reports", []):
		if report.get("request_required", false) and report.id not in _reports and meets(report.get("requires", {})):
			# Never return result text before an explicit player request.
			result.append({"id": report.id, "title": report.get("analysis_label", report.title), "kind": report.kind, "evidence": report.get("requires", {}).get("evidence", []).duplicate()})
	return result

func request_analysis(id: String) -> Dictionary:
	if phase != "investigation":
		return {"status": "locked"}
	var report := _record("reports", id)
	if report.is_empty() or not report.get("request_required", false):
		return {"status": "invalid"}
	if not meets(report.get("requires", {})):
		return {"status": "locked"}
	if id in _reports:
		return {"status": "duplicate", "report": report}
	_requested_analyses.append(id)
	_touch()
	return {"status": "completed", "report": _record("reports", id)}

func available_reports() -> Array:
	var result := []
	for id in _reports:
		var report := _record("reports", id)
		for other_id in _reports:
			if _record("reports", other_id).get("supersedes", "") == id:
				report["updated_by"] = other_id
		result.append(report)
	return result

func timeline() -> Array:
	var result: Array = _case.get("timeline", []).filter(func(event): return meets(event.get("requires", {}))).duplicate(true)
	result.sort_custom(func(first, second): return first.get("order", 0) < second.get("order", 0))
	return result

func known_nodes() -> Array:
	var result := []
	for id in _collected:
		var clue := evidence_data(id)
		result.append({"ref": "e:" + id, "label": clue.name, "text": clue.description, "kind": "evidence", "certainty": "recorded"})
	for statement in heard_statements():
		result.append({"ref": "s:" + statement.id, "label": person_data(statement.person_id).name, "text": statement.text, "kind": "statement", "certainty": statement.status})
	for question_id in _asked_questions:
		var answers: Array = _dialogue_history.filter(func(answer): return answer.question_id == question_id)
		if not answers.is_empty():
			var answer: Dictionary = answers[-1]
			result.append({"ref": "q:" + question_id, "label": person_data(answer.person_id).name + " · " + _record("questions", question_id).label, "text": answer.text, "kind": "statement", "certainty": "claimed"})
	for person_id in _contacted_people():
		var person := person_data(person_id)
		result.append({"ref": "p:" + person_id, "label": person.name, "text": person.get("occupation", ""), "kind": "person", "certainty": "recorded"})
	for report in available_reports():
		result.append({"ref": "r:" + report.id, "label": report.title, "text": report.summary, "kind": "report", "certainty": report.status})
	for event in timeline():
		result.append({"ref": "t:" + event.id, "label": event.time, "text": event.text, "kind": "timeline", "certainty": event.status})
	for id in _confirmed_inferences:
		var inference := _record("inferences", id)
		result.append({"ref": "i:" + id, "label": "استنتاج مسنود", "text": inference.explanation, "kind": "inference", "certainty": "supported"})
	for id in _contradictions:
		result.append({"ref": "c:" + id, "label": "تناقض موثق", "text": _record("contradictions", id).explanation, "kind": "contradiction", "certainty": "recorded"})
	for hypothesis in _hypotheses:
		result.append({"ref": "h:" + hypothesis.id, "label": "فرضية المحقق", "text": hypothesis.label, "kind": "hypothesis", "certainty": "hypothesis"})
	return result

func _known_refs() -> Array:
	return known_nodes().map(func(node): return node.ref)

func confirmed_inferences() -> Array[String]:
	return _confirmed_inferences.duplicate()

func hypotheses() -> Array:
	return _hypotheses.duplicate(true)

func link_nodes(refs: Array, meaning: String) -> Dictionary:
	var known := _known_refs()
	var unique := []
	for ref in refs:
		if not ref is String or ref not in known or ref in unique:
			return {"status": "invalid"}
		unique.append(ref)
	if phase != "investigation" or refs.size() < 2 or _record("inference_options", meaning).is_empty():
		return {"status": "invalid"}
	for rule in _case.inferences:
		if rule.meaning == meaning and rule.links.size() == refs.size() and rule.links.all(func(ref): return ref in refs) and meets(rule.get("requires", {})):
			if rule.id in _confirmed_inferences:
				return {"status": "duplicate", "explanation": rule.explanation}
			_confirmed_inferences.append(rule.id)
			_touch()
			return {"status": "confirmed", "explanation": rule.explanation}
	for item in _hypotheses:
		if item.meaning == meaning and item.links.size() == refs.size() and item.links.all(func(ref): return ref in refs):
			return {"status": "hypothesis", "id": item.id}
	var id := "hypothesis_" + str(_hypotheses.size() + 1)
	_hypotheses.append({"id": id, "links": refs.duplicate(), "meaning": meaning, "label": _record("inference_options", meaning).label})
	_touch()
	return {"status": "hypothesis", "id": id}

func try_inference(first: String, second: String, meaning: String) -> Dictionary:
	return link_nodes(["e:" + first, "e:" + second], meaning)

func discovered_contradictions() -> Array[String]:
	return _contradictions.duplicate()

func confront(question_id: String, evidence_id: String) -> Dictionary:
	var question := _question_id(question_id)
	if phase != "investigation" or question not in _asked_questions or not has_evidence(evidence_id):
		return {"status": "invalid"}
	for rule in _case.contradictions:
		if rule.person_id == active_person and rule.question_id == question and rule.evidence_id == evidence_id and meets(rule.get("requires", {})):
			if rule.id in _contradictions:
				return {"status": "duplicate", "explanation": rule.explanation}
			_contradictions.append(rule.id)
			_touch()
			return {"status": "confirmed", "explanation": rule.explanation}
	return {"status": "unresolved"}

func can_conclude() -> bool:
	return phase == "investigation" and not _case.is_empty()

func submit_accusation(suspect_id: String, refs: Array) -> Dictionary:
	if not can_conclude():
		return {"status": "locked"}
	var suspect := person_data(suspect_id)
	if suspect.is_empty() or suspect.role not in ["suspect", "both"] or not meets(suspect.get("requires", {})):
		return {"status": "invalid"}
	var unique := []
	var known := _known_refs()
	for ref in refs:
		if not ref is String or ref not in known or ref in unique:
			return {"status": "invalid"}
		unique.append(ref)
	var id := str(_accusations.size() + 1)
	_accusations.append({"id": id, "suspect_id": suspect_id, "refs": unique, "status": "pending", "audited": false})
	_touch()
	# Do not evaluate or reveal correctness at submission.
	return {"status": "submitted", "id": id}

func _evaluate(accusation: Dictionary) -> Dictionary:
	var score := 0.0
	var valid_score := 0.0
	var valid_groups := []
	var groups := []
	for profile in _case.assessment.profiles:
		if profile.suspect_id != accusation.suspect_id:
			continue
		for criterion in profile.criteria:
			# Attached rebuttals defeat this criterion; later discoveries do not rewrite a submitted dossier.
			if criterion.get("none_of", []).any(func(ref): return ref in accusation.refs):
				continue
			if criterion.all_of.all(func(ref): return ref in accusation.refs):
				score += float(criterion.weight)
				if criterion.reliability == "valid":
					valid_score += float(criterion.weight)
					if criterion.group not in valid_groups:
						valid_groups.append(criterion.group)
				if criterion.group not in groups:
					groups.append(criterion.group)
	var enough: bool = score >= float(_case.assessment.threshold) and groups.size() >= int(_case.assessment.minimum_groups)
	var guilty: bool = accusation.suspect_id in _case.truth.culprit_ids
	var outcome := "failed"
	if enough:
		outcome = "proven" if guilty and valid_score >= float(_case.assessment.threshold) and valid_groups.size() >= int(_case.assessment.minimum_groups) else "wrongful_verdict"
	return {"outcome": outcome, "score": score, "decision": "insufficient" if not enough else "charge_established"}

func review_accusation(id: String) -> Dictionary:
	if phase != "investigation":
		return {"status": "locked"}
	for item in _accusations:
		if item.id != id:
			continue
		if item.status != "pending":
			return {"status": "invalid"}
		var evaluation := _evaluate(item)
		item.merge(evaluation, true)
		item.status = "reviewed"
		phase = "closed"
		solved = evaluation.outcome == "proven"
		var key := case_id() + ":" + content_hash + ":" + id
		campaign.record(key, case_id(), item.outcome, _case.get("campaign_effects", {}).get(item.outcome, {}))
		_touch()
		return {"status": "reviewed", "decision": item.decision}
	return {"status": "invalid"}

func accusations() -> Array:
	var result := _accusations.duplicate(true)
	for item in result:
		item.erase("score")
		if not item.audited:
			item.erase("outcome")
	return result

func audit_accusation(id: String) -> Dictionary:
	for item in _accusations:
		if item.id == id and item.status == "reviewed":
			item.audited = true
			campaign.audit(case_id() + ":" + content_hash + ":" + id, _case.get("campaign_effects", {}).get(item.outcome, {}))
			_touch()
			return {"status": "audited", "outcome": item.outcome, "explanation": _case.truth.summary}
	return {"status": "invalid"}

func reopen_case() -> bool:
	if phase != "closed" or not _case.get("allow_reopen", true):
		return false
	phase = "investigation"
	solved = false
	_touch()
	return true

func reset() -> void:
	_collected.clear()
	_heard.clear()
	_contacted.clear()
	_asked_questions.clear()
	_confirmed_inferences.clear()
	_contradictions.clear()
	_reports.clear()
	_requested_analyses.clear()
	_hypotheses.clear()
	_accusations.clear()
	_dialogue_history.clear()
	active_person = ""
	solved = false
	phase = "briefing"
	current_location = _case.get("start_location", "")
	location_changed.emit(current_location)
	_touch()

func export_state() -> Dictionary:
	return {"case_id": case_id(), "content_hash": content_hash, "phase": phase, "current_location": current_location, "active_person": active_person, "collected": _collected.duplicate(), "heard": _heard.duplicate(), "contacted": _contacted.duplicate(), "asked_questions": _asked_questions.duplicate(), "inferences": _confirmed_inferences.duplicate(), "contradictions": _contradictions.duplicate(), "reports": _reports.duplicate(), "requested_analyses": _requested_analyses.duplicate(), "hypotheses": _hypotheses.duplicate(true), "accusations": _accusations.duplicate(true), "dialogue_history": _dialogue_history.duplicate(true)}

func restore_state(value: Variant) -> bool:
	if value is Dictionary:
		value = value.duplicate(true)
		if not value.has("requested_analyses"):
			value["requested_analyses"] = []
	if not value is Dictionary or value.get("case_id") != case_id() or value.get("content_hash") != content_hash or value.get("phase") not in ["briefing", "investigation", "closed"]:
		return false
	if location_data(str(value.get("current_location", ""))).is_empty() or not value.get("active_person") is String or (not value.active_person.is_empty() and person_data(value.active_person).is_empty()):
		return false
	var fields := {"collected": "evidence", "heard": "statements", "contacted": "people", "asked_questions": "questions", "inferences": "inferences", "contradictions": "contradictions", "reports": "reports", "requested_analyses": "reports"}
	for key in fields:
		if not value.get(key) is Array:
			return false
		var seen := []
		for id in value[key]:
			if not id is String or id in seen or _record(fields[key], id).is_empty():
				return false
			seen.append(id)
	for key in ["hypotheses", "accusations", "dialogue_history"]:
		if not value.get(key) is Array:
			return false
	var hypothesis_ids := []
	for item in value.hypotheses:
		if not item is Dictionary or not item.get("id") is String or not item.get("links") is Array or not item.get("meaning") is String or not item.get("label") is String:
			return false
		if item.id.is_empty() or ":" in item.id or item.id in hypothesis_ids:
			return false
		hypothesis_ids.append(item.id)
	var accusation_index := 0
	for item in value.accusations:
		accusation_index += 1
		if not item is Dictionary or not item.get("id") is String or not item.get("refs") is Array or person_data(str(item.get("suspect_id", ""))).get("role") not in ["suspect", "both"] or item.get("status") not in ["pending", "reviewed"] or not item.get("audited") is bool:
			return false
		if item.id != str(accusation_index):
			return false
		if item.status == "pending" and (item.audited or item.has("outcome") or item.has("decision") or item.has("score")):
			return false
		if item.status == "reviewed" and (item.get("outcome") not in ["proven", "failed", "wrongful_verdict"] or item.get("decision") not in ["charge_established", "insufficient"]):
			return false
	for item in value.dialogue_history:
		if not item is Dictionary or _record("questions", str(item.get("question_id", ""))).is_empty() or person_data(str(item.get("person_id", ""))).is_empty() or not item.get("text") is String or not item.get("fact_ids") is Array:
			return false
	var candidate = get_script().new()
	candidate._case = _case.duplicate(true)
	candidate.campaign = campaign
	candidate._assign_state(value)
	var known: Array = candidate._known_refs()
	var prior_hypotheses: Array = known.filter(func(ref): return not ref.begins_with("h:"))
	for item in candidate._hypotheses:
		var seen := []
		if item.links.size() < 2 or candidate._record("inference_options", item.meaning).is_empty():
			return false
		for ref in item.links:
			if not ref is String or ref not in prior_hypotheses or ref in seen or ref == "h:" + item.id:
				return false
			seen.append(ref)
		prior_hypotheses.append("h:" + item.id)
	var reviewed_count := 0
	for item in candidate._accusations:
		var seen := []
		for ref in item.refs:
			if not ref is String or ref not in known or ref in seen:
				return false
			seen.append(ref)
		if item.status == "reviewed":
			reviewed_count += 1
			var evaluated: Dictionary = candidate._evaluate(item)
			if item.outcome != evaluated.outcome or item.decision != evaluated.decision:
				return false
	if value.phase == "closed" and reviewed_count == 0:
		return false
	if value.phase == "investigation" and reviewed_count > 0 and not _case.get("allow_reopen", true):
		return false
	for id in candidate._requested_analyses:
		if not candidate._record("reports", id).get("request_required", false) or id not in candidate._reports:
			return false
	for id in candidate._reports:
		if candidate._record("reports", id).get("request_required", false) and id not in candidate._requested_analyses:
			return false
		if not candidate.meets(candidate._record("reports", id).get("requires", {})):
			return false
	for id in candidate._contradictions:
		var rule: Dictionary = candidate._record("contradictions", id)
		if rule.question_id not in candidate._asked_questions or rule.evidence_id not in candidate._collected:
			return false
	for id in candidate._asked_questions:
		var question: Dictionary = candidate._record("questions", id)
		if not candidate.meets(question.get("requires", {})):
			return false
	for item in candidate._dialogue_history:
		var question: Dictionary = candidate._record("questions", item.question_id)
		if item.person_id != question.person_id or item.question_id not in candidate._asked_questions:
			return false
		for id in item.fact_ids:
			if not id is String or id not in question.answer_facts:
				return false
	_assign_state(value)
	location_changed.emit(current_location)
	_touch()
	return true

func _assign_state(value: Dictionary) -> void:
	_collected.assign(value.collected)
	_heard.assign(value.heard)
	_contacted.assign(value.contacted)
	_asked_questions.assign(value.asked_questions)
	_confirmed_inferences.assign(value.inferences)
	_contradictions.assign(value.contradictions)
	_reports.assign(value.reports)
	_requested_analyses.assign(value.get("requested_analyses", []))
	_hypotheses = value.hypotheses.duplicate(true)
	_accusations = value.accusations.duplicate(true)
	_dialogue_history = value.dialogue_history.duplicate(true)
	phase = value.phase
	current_location = value.current_location
	active_person = value.active_person
	var reviewed: Array = _accusations.filter(func(item): return item.status == "reviewed")
	solved = phase == "closed" and not reviewed.is_empty() and reviewed[-1].get("outcome") == "proven"
