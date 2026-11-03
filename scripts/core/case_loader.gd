extends RefCounted
const Legacy = preload("res://scripts/core/legacy_case_adapter.gd")

static func load_case(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "errors": ["Case file does not exist: " + path]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"data": {}, "errors": ["JSON line %d: %s" % [json.get_error_line(), json.get_error_message()]]}
	var result := prepare(json.data)
	if result.errors.is_empty():
		result["content_hash"] = FileAccess.get_file_as_string(path).sha256_text()
	return result

static func prepare(source: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not source is Dictionary:
		return {"data": {}, "errors": ["Case root must be an object"]}
	var data: Dictionary = source.duplicate(true)
	if data.get("schema_version") == 1:
		errors = _legacy_shape(data)
		if errors.is_empty():
			data = Legacy.convert(data)
	else:
		if data.get("schema_version") != 2:
			errors.append("Unsupported schema_version")
	if errors.is_empty():
		errors = _validate_v2(data)
	return {"data": data if errors.is_empty() else {}, "errors": errors}

static func validate(source: Variant) -> Array[String]:
	var errors: Array[String] = []
	errors.assign(prepare(source).errors)
	return errors

static func _legacy_shape(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["locations", "evidence", "suspects", "inferences", "inference_options", "proof_options", "contradictions"]:
		_records(data.get(key), key, errors)
	var witness: Variant = data.get("witness")
	if not witness is Dictionary:
		errors.append("Legacy witness must be an object")
	else:
		if not witness.get("lines") is Array:
			errors.append("Legacy lines must be an array")
		else:
			for line in witness.lines:
				if not line is String or line.is_empty():
					errors.append("Invalid legacy line")
		_records(witness.get("questions"), "questions", errors)
		for question in witness.get("questions", []) if witness.get("questions") is Array else []:
			if question is Dictionary and not question.get("requires_evidence") is Array:
				errors.append("Invalid legacy question requirements")
	for rule in data.get("inferences", []) if data.get("inferences") is Array else []:
		if rule is Dictionary and not rule.get("evidence") is Array:
			errors.append("Invalid legacy inference")
	if not data.get("accusation") is Dictionary:
		errors.append("Legacy accusation must be an object")
	for proof in data.get("proof_options", []) if data.get("proof_options") is Array else []:
		if proof is Dictionary:
			for key in ["evidence", "inferences", "contradictions"]:
				if not proof.get(key) is Array:
					errors.append("Invalid legacy proof references")
	return errors

static func _strings(record: Dictionary, keys: Array, context: String, errors: Array[String]) -> void:
	for key in keys:
		if not record.get(key) is String or record[key].strip_edges().is_empty():
			errors.append(context + "." + key + " must be a nonempty string")

static func _records(value: Variant, context: String, errors: Array[String], nonempty: bool = false) -> Dictionary:
	var result := {}
	if not value is Array:
		errors.append(context + " must be an array")
		return result
	if nonempty and value.is_empty():
		errors.append(context + " must not be empty")
	for record in value:
		if not record is Dictionary:
			errors.append(context + " entries must be objects")
			continue
		var id: Variant = record.get("id")
		if not id is String or id.is_empty() or ":" in id or result.has(id):
			errors.append(context + " contains invalid or duplicate id")
		else:
			result[id] = record
	return result

static func _refs(value: Variant, records: Dictionary, context: String, errors: Array[String], nonempty: bool = false) -> Array:
	if not value is Array:
		errors.append(context + " must be an array")
		return []
	if nonempty and value.is_empty():
		errors.append(context + " must not be empty")
	var seen := []
	for id in value:
		if not id is String or not records.has(id) or id in seen:
			errors.append(context + " contains unknown or duplicate reference")
		seen.append(id)
	return value

static func _position(value: Variant, errors: Array[String]) -> void:
	if not value is Array or value.size() != 2:
		errors.append("Position needs two coordinates")
		return
	for coordinate in value:
		if not (coordinate is int or coordinate is float):
			errors.append("Position must be numeric")
		elif not is_finite(float(coordinate)) or coordinate < 0.08 or coordinate > 0.85:
			errors.append("Position outside touch-safe range")

static func _number(value: Variant, minimum: float = 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum

static func _condition(value: Variant, tables: Dictionary, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("Requirements must be an object")
		return
	for key in value:
		if key == "global":
			var global: Variant = value[key]
			if not global is Dictionary:
				errors.append("Global condition must be an object")
				continue
			for field in global:
				if field == "reputation_min":
					if not _number(global[field], -1000000):
						errors.append("Invalid reputation condition")
				elif field == "trust_min":
					if not global[field] is Dictionary:
						errors.append("Invalid trust condition")
					else:
						for id in global[field]:
							if not _number(global[field][id], -1000000):
								errors.append("Invalid trust threshold")
				elif field in ["flags", "judgments"]:
					if not global[field] is Dictionary:
						errors.append("Invalid campaign condition")
					elif field == "judgments":
						for id in global[field]:
							if global[field][id] not in ["charge_established", "insufficient", "proven", "failed", "wrongful_verdict"]:
								errors.append("Invalid prior judgment condition")
				else:
					errors.append("Unknown global condition")
		elif key in ["evidence", "statements", "questions", "reports", "inferences", "contradictions", "people"]:
			_refs(value[key], tables[key], "requirements." + key, errors)
		else:
			errors.append("Unknown requirement " + str(key))

static func _validate_v2(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_strings(data, ["id", "title", "start_location"], "case", errors)
	if not _number(data.get("revision"), 1) or float(data.get("revision", 0)) != floorf(float(data.get("revision", 0))):
		errors.append("Case revision must be a positive integer")
	if not _number(data.get("target_duration_minutes", 15), 1):
		errors.append("Target duration must be positive")
	if not data.get("visual_catalog_path", "") is String:
		errors.append("Visual catalog path must be a string")
	elif not data.get("visual_catalog_path", "").is_empty() and (not data.visual_catalog_path.begins_with("res://") or data.visual_catalog_path.get_extension() != "tres"):
		errors.append("Visual catalog must be a local resource")
	if data.has("accusation_label"):
		_strings(data, ["accusation_label"], "case", errors)
	var case_file: Variant = data.get("case_file")
	if not case_file is Dictionary:
		errors.append("case_file must be an object")
	else:
		_strings(case_file, ["number", "crime_type", "crime_label", "summary", "crime_scene"], "case_file", errors)
		if not case_file.get("victim") is Dictionary:
			errors.append("Victim metadata is required")
		else:
			_strings(case_file.victim, ["name", "background"], "victim", errors)
	var assistant: Variant = data.get("assistant")
	if not assistant is Dictionary:
		errors.append("Assistant metadata is required")
	else:
		_strings(assistant, ["name", "briefing"], "assistant", errors)
	var tables := {}
	for key in ["locations", "people", "evidence", "statements", "questions", "facts", "reports", "timeline", "inferences", "contradictions", "inference_options"]:
		tables[key] = _records(data.get(key), key, errors, key in ["locations", "people", "reports"])
	var registry := {}
	var prefixes := {"evidence": "e", "people": "p", "statements": "s", "questions": "q", "reports": "r", "timeline": "t", "inferences": "i", "contradictions": "c"}
	for table in prefixes:
		for id in tables[table]:
			registry[prefixes[table] + ":" + id] = true
	if not tables.locations.has(data.get("start_location", "")):
		errors.append("Unknown start location")
	for location in tables.locations.values():
		_strings(location, ["name", "description"], "location", errors)
		if not location.get("art", "") is String:
			errors.append("Location art must be a string")
		_condition(location.get("requires", {}), tables, errors)
	for clue in tables.evidence.values():
		_strings(clue, ["name", "description", "source", "time", "category", "location_id"], "evidence", errors)
		if not tables.locations.has(clue.get("location_id", "")):
			errors.append("Unknown evidence location")
		_position(clue.get("position"), errors)
		_condition(clue.get("requires", {}), tables, errors)
	var suspects := {}
	for person in tables.people.values():
		_strings(person, ["name", "role"], "person", errors)
		for field in ["occupation", "art_id"]:
			if not person.get(field, "") is String:
				errors.append("Character display fields must be strings")
		if person.get("role") not in ["witness", "suspect", "both"]:
			errors.append("Unknown character role")
		if person.get("role") in ["suspect", "both"]:
			suspects[person.id] = true
		if not person.get("location_id", "") is String or (not person.get("location_id", "").is_empty() and not tables.locations.has(person.location_id)):
			errors.append("Unknown character location")
		_position(person.get("position"), errors)
		_refs(person.get("statement_ids"), tables.statements, "person statements", errors)
		for id in person.get("statement_ids", []) if person.get("statement_ids") is Array else []:
			if tables.statements.has(id) and tables.statements[id].get("person_id") != person.id:
				errors.append("Statement owner mismatch")
		_condition(person.get("requires", {}), tables, errors)
		var ai: Variant = person.get("ai")
		if not ai is Dictionary:
			errors.append("AI character boundaries are required")
		else:
			for key in ["knows", "conceals", "lies"]:
				_refs(ai.get(key), tables.facts, "ai." + key, errors)
			_refs(ai.get("known_evidence"), tables.evidence, "ai evidence", errors)
			for field in ["personality", "speech_style"]:
				if not ai.get(field) is String:
					errors.append("AI style must be a string")
	if suspects.is_empty():
		errors.append("At least one suspect is required")
	for statement in tables.statements.values():
		_strings(statement, ["text", "person_id", "status"], "statement", errors)
		if statement.get("status") not in ["claimed", "confirmed", "uncertain"]:
			errors.append("Invalid statement certainty")
		if not tables.people.has(statement.get("person_id", "")):
			errors.append("Unknown statement person")
		_condition(statement.get("requires", {}), tables, errors)
	for fact in tables.facts.values():
		_strings(fact, ["text"], "fact", errors)
		if not fact.get("variants", []) is Array:
			errors.append("Fact variants must be an array")
		else:
			for variant in fact.get("variants", []):
				if not variant is String or variant.is_empty():
					errors.append("Invalid fact wording")
		_condition(fact.get("requires", {}), tables, errors)
	for question in tables.questions.values():
		_strings(question, ["person_id", "label"], "question", errors)
		if not tables.people.has(question.get("person_id", "")):
			errors.append("Unknown question person")
		_refs(question.get("answer_facts"), tables.facts, "question facts", errors, true)
		if tables.people.has(question.get("person_id", "")):
			var ai: Variant = tables.people[question.person_id].get("ai")
			if ai is Dictionary and ai.get("knows") is Array and ai.get("conceals") is Array and ai.get("lies") is Array:
				for id in question.get("answer_facts", []) if question.get("answer_facts") is Array else []:
					if id not in ai.knows and id not in ai.conceals and id not in ai.lies:
						errors.append("Question fact is outside character knowledge")
		_condition(question.get("requires", {}), tables, errors)
	for report in tables.reports.values():
		_strings(report, ["title", "kind", "summary", "status"], "report", errors)
		if not report.get("request_required", false) is bool:
			errors.append("request_required must be boolean")
		if report.has("analysis_label"):
			_strings(report, ["analysis_label"], "report", errors)
		if report.get("status") not in ["preliminary", "confirmed", "uncertain"]:
			errors.append("Invalid report certainty")
		if not report.get("findings", []) is Array:
			errors.append("Report findings must be an array")
		else:
			for finding in report.get("findings", []):
				if not finding is String:
					errors.append("Report findings must be strings")
		for key in ["cause_of_death", "estimated_time"]:
			if not report.get(key, "") is String:
				errors.append("Report medical fields must be strings")
		_condition(report.get("requires", {}), tables, errors)
		if not report.get("supersedes", "") is String or (not report.get("supersedes", "").is_empty() and (not tables.reports.has(report.supersedes) or report.supersedes == report.id)):
			errors.append("Invalid report update reference")
	if not tables.reports.values().any(func(report): return not report.get("request_required", false) and report.get("requires", {}) is Dictionary and report.get("requires", {}).is_empty()):
		errors.append("An initial report must be available during briefing")
	if case_file is Dictionary and case_file.get("crime_type") == "murder":
		if not tables.reports.values().any(func(report): return report.get("kind") == "forensic" and not report.get("request_required", false) and report.get("requires", {}) is Dictionary and report.get("requires", {}).is_empty()):
			errors.append("Murder cases need an initial forensic report")
	for event in tables.timeline.values():
		_strings(event, ["time", "text", "status"], "timeline", errors)
		if event.get("status") not in ["confirmed", "uncertain", "claimed", "preliminary"]:
			errors.append("Invalid timeline certainty")
		if not _number(event.get("order", 0), -1000000):
			errors.append("Timeline order must be numeric")
		_condition(event.get("requires", {}), tables, errors)
	for option in tables.inference_options.values():
		_strings(option, ["label"], "inference option", errors)
	for inference in tables.inferences.values():
		_strings(inference, ["meaning", "explanation"], "inference", errors)
		if not tables.inference_options.has(inference.get("meaning", "")):
			errors.append("Unknown inference meaning")
		var links := _refs(inference.get("links"), registry, "inference links", errors, true)
		if links.size() < 2:
			errors.append("Inference needs at least two distinct references")
		_condition(inference.get("requires", {}), tables, errors)
	for rule in tables.contradictions.values():
		_strings(rule, ["person_id", "question_id", "evidence_id", "explanation"], "contradiction", errors)
		if not tables.questions.has(rule.get("question_id", "")) or not tables.evidence.has(rule.get("evidence_id", "")) or not tables.people.has(rule.get("person_id", "")):
			errors.append("Unknown contradiction reference")
		elif tables.questions[rule.question_id].get("person_id") != rule.person_id:
			errors.append("Contradiction person mismatch")
		_condition(rule.get("requires", {}), tables, errors)
	var truth: Variant = data.get("truth")
	if not truth is Dictionary:
		errors.append("Fixed truth is required")
	else:
		_refs(truth.get("culprit_ids"), suspects, "truth culprits", errors, true)
		_strings(truth, ["summary"], "truth", errors)
	var assessment: Variant = data.get("assessment")
	if not assessment is Dictionary:
		errors.append("Assessment rules are required")
	else:
		if not _number(assessment.get("threshold"), 0.01) or not _number(assessment.get("minimum_groups"), 1) or float(assessment.get("minimum_groups", 0)) != floorf(float(assessment.get("minimum_groups", 0))):
			errors.append("Invalid assessment thresholds")
		if not assessment.get("profiles") is Array:
			errors.append("Assessment profiles must be an array")
		else:
			var seen := []
			for profile in assessment.profiles:
				if not profile is Dictionary:
					errors.append("Invalid assessment profile")
					continue
				if not suspects.has(profile.get("suspect_id", "")) or profile.get("suspect_id") in seen:
					errors.append("Unknown or repeated assessment suspect")
				seen.append(profile.get("suspect_id"))
				var criteria := _records(profile.get("criteria"), "assessment criteria", errors)
				for criterion in criteria.values():
					_strings(criterion, ["group", "reliability"], "criterion", errors)
					_refs(criterion.get("all_of"), registry, "criterion references", errors, true)
					_refs(criterion.get("none_of", []), registry, "criterion rebuttals", errors)
					if not _number(criterion.get("weight"), 0.01) or criterion.get("reliability") not in ["valid", "misleading"]:
						errors.append("Invalid criterion weight or reliability")
	_condition(data.get("requirements", {}), tables, errors)
	if not data.get("allow_reopen", true) is bool:
		errors.append("allow_reopen must be boolean")
	var effects: Variant = data.get("campaign_effects", {})
	if not effects is Dictionary:
		errors.append("Campaign effects must be an object")
	else:
		for outcome in effects:
			var effect: Variant = effects[outcome]
			if outcome not in ["proven", "failed", "wrongful_verdict"] or not effect is Dictionary:
				errors.append("Invalid outcome effect")
				continue
			if not _number(effect.get("reputation", 0), -1000000) or not effect.get("trust", {}) is Dictionary or not effect.get("flags", {}) is Dictionary:
				errors.append("Invalid campaign effect")
			elif effect.get("trust", {}) is Dictionary:
				for id in effect.get("trust", {}):
					if not _number(effect.trust[id], -1000000):
						errors.append("Invalid trust effect")
	return errors
