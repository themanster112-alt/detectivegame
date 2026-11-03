extends RefCounted
var reputation := 0.0
var trust: Dictionary = {}
var flags: Dictionary = {}
var judgments: Array = []

func snapshot() -> Dictionary:
	return {"reputation": reputation, "trust": trust.duplicate(true), "flags": flags.duplicate(true), "judgments": judgments.duplicate(true)}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not (data.get("reputation") is int or data.get("reputation") is float) or not is_finite(float(data.get("reputation"))):
		return false
	if not data.get("trust") is Dictionary or not data.get("flags") is Dictionary or not data.get("judgments") is Array:
		return false
	for id in data.trust:
		if not (data.trust[id] is int or data.trust[id] is float) or not is_finite(float(data.trust[id])):
			return false
	for record in data.judgments:
		if not record is Dictionary or not record.get("key") is String or not record.get("case_id") is String or record.get("outcome") not in ["proven", "failed", "wrongful_verdict"] or record.get("decision") not in ["charge_established", "insufficient"] or not record.get("audited") is bool:
			return false
	reputation = float(data.reputation)
	trust = data.trust.duplicate(true)
	flags = data.flags.duplicate(true)
	judgments = data.judgments.duplicate(true)
	return true

func matches(requirements: Dictionary) -> bool:
	if reputation < float(requirements.get("reputation_min", -INF)):
		return false
	for id in requirements.get("trust_min", {}):
		if float(trust.get(id, 0)) < float(requirements.trust_min[id]):
			return false
	for id in requirements.get("flags", {}):
		if flags.get(id) != requirements.flags[id]:
			return false
	for case_id in requirements.get("judgments", {}):
		if not judgments.any(func(record): return record.case_id == case_id and (record.decision == requirements.judgments[case_id] or (record.audited and record.outcome == requirements.judgments[case_id]))):
			return false
	return true

func record(key: String, case_id: String, outcome: String, effect: Dictionary) -> void:
	if judgments.any(func(item): return item.key == key):
		return
	judgments.append({"key": key, "case_id": case_id, "outcome": outcome, "decision": "insufficient" if outcome == "failed" else "charge_established", "audited": false})
	# Failed charges are public immediately. Other truth-dependent effects wait for audit.
	if outcome == "failed":
		_apply(effect)

func audit(key: String, effect: Dictionary) -> void:
	for item in judgments:
		if item.key == key and not item.audited:
			item.audited = true
			if item.outcome != "failed":
				_apply(effect)

func _apply(effect: Dictionary) -> void:
	reputation += float(effect.get("reputation", 0))
	for id in effect.get("trust", {}):
		trust[id] = float(trust.get(id, 0)) + float(effect.trust[id])
	for id in effect.get("flags", {}):
		flags[id] = effect.flags[id]

func public_snapshot() -> Dictionary:
	var result := snapshot()
	for item in result.judgments:
		if not item.audited:
			item.erase("outcome")
	return result
