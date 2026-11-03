extends RefCounted
## Keep original v1 case files intact. The adapter is only for legacy demonstration data.
static func convert(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	var people := []
	var statements := []
	var questions := []
	var facts := []
	var witness: Dictionary = source.get("witness", {})
	for suspect in source.get("suspects", []):
		if not suspect is Dictionary:
			continue
		people.append({"id": suspect.get("id", ""), "name": suspect.get("name", ""), "role": "suspect", "occupation": "", "location_id": "", "position": [0.5, 0.7], "statement_ids": [], "ai": {"personality": "", "speech_style": "", "knows": [], "conceals": [], "lies": [], "known_evidence": []}})
	if not witness.is_empty():
		var statement_ids := []
		for index in range(witness.get("lines", []).size()):
			var id: String = witness.get("id", "") + "_line_" + str(index)
			statement_ids.append(id)
			statements.append({"id": id, "person_id": witness.get("id", ""), "text": witness.lines[index], "status": "claimed", "requires": {}})
		var known := []
		for question in witness.get("questions", []):
			if not question is Dictionary:
				continue
			var fact_id: String = witness.get("id", "") + "_" + str(question.get("id", ""))
			known.append(fact_id)
			facts.append({"id": fact_id, "text": question.get("answer", ""), "variants": [], "requires": {"evidence": question.get("requires_evidence", [])}})
			questions.append({"id": str(witness.get("id", "")) + "_" + str(question.get("id", "")), "legacy_id": question.get("id", ""), "person_id": witness.get("id", ""), "label": question.get("label", ""), "answer_facts": [fact_id], "requires": {"evidence": question.get("requires_evidence", [])}})
		people.append({"id": witness.get("id", ""), "name": witness.get("name", ""), "role": "witness", "occupation": "", "location_id": witness.get("location_id", ""), "position": witness.get("position", [0.5, 0.7]), "statement_ids": statement_ids, "ai": {"personality": "", "speech_style": "", "knows": known, "conceals": [], "lies": [], "known_evidence": source.get("evidence", []).map(func(item): return item.get("id", ""))}})
	var inferences := []
	for rule in source.get("inferences", []):
		if not rule is Dictionary:
			continue
		var converted: Dictionary = rule.duplicate(true)
		converted["links"] = rule.get("evidence", []).map(func(id): return "e:" + str(id))
		converted["requires"] = {}
		inferences.append(converted)
	var contradictions := []
	for rule in source.get("contradictions", []):
		if not rule is Dictionary:
			continue
		var converted: Dictionary = rule.duplicate(true)
		converted["person_id"] = witness.get("id", "")
		converted["question_id"] = str(witness.get("id", "")) + "_" + str(rule.get("question_id", ""))
		converted["requires"] = {}
		contradictions.append(converted)
	var criteria := []
	for proof in source.get("proof_options", []):
		if not proof is Dictionary or proof.get("id") not in source.get("accusation", {}).get("required_proofs", []):
			continue
		var links := []
		for id in proof.get("evidence", []):
			links.append("e:" + str(id))
		for id in proof.get("inferences", []):
			links.append("i:" + str(id))
		for id in proof.get("contradictions", []):
			links.append("c:" + str(id))
		criteria.append({"id": proof.id, "all_of": links, "weight": 1, "group": proof.id, "reliability": "valid"})
	data["visual_catalog_path"] = "res://assets/ui/noir_visual_catalog.tres"
	data["target_duration_minutes"] = 15
	data["schema_version"] = 2
	data["revision"] = 1
	data["case_file"] = {"number": str(source.get("id", "")), "crime_type": "theft", "crime_label": "سرقة", "summary": source.get("intro", ""), "victim": {"name": "غير موثق في بيانات التدريب", "background": "غير موثق في بيانات التدريب"}, "crime_scene": str(source.get("start_location", ""))}
	data["assistant"] = {"name": "مساعد المحقق", "briefing": "المواقع والأشخاص المتاحون مدرجون في ملف القضية."}
	data["people"] = people
	data["statements"] = statements
	data["questions"] = questions
	data["facts"] = facts
	data["inferences"] = inferences
	data["contradictions"] = contradictions
	data["reports"] = [{"id": "initial", "title": "التقرير الفني الأولي", "kind": "technical", "summary": "لا يتضمن ملف التدريب تقريرًا فنيًا مستقلًا.", "status": "uncertain", "findings": [], "cause_of_death": "", "estimated_time": "", "requires": {}}]
	data["timeline"] = []
	var order := 0
	for clue in source.get("evidence", []):
		if not clue is Dictionary:
			continue
		data.timeline.append({"id": "time_" + str(clue.get("id", "")), "time": clue.get("time", ""), "text": clue.get("name", ""), "order": order, "status": "uncertain", "requires": {"evidence": [clue.get("id", "")]}})
		order += 1
	data["truth"] = {"culprit_ids": [source.get("culprit", "")], "summary": source.get("solution", "")}
	data["assessment"] = {"threshold": maxi(1, criteria.size()), "minimum_groups": maxi(1, criteria.size()), "profiles": [{"suspect_id": source.get("culprit", ""), "criteria": criteria}]}
	data["campaign_effects"] = {"proven": {"reputation": 1, "trust": {}}, "failed": {"reputation": -1, "trust": {}}, "wrongful_verdict": {"reputation": -2, "trust": {}}}
	data["allow_reopen"] = true
	data["requirements"] = {}
	return data
