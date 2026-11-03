extends RefCounted
## Data contract only. No transport, merge, authority changes or state mutation.
const PROTOCOL_VERSION := 1
static func snapshot(session: RefCounted, actor_id: String, revision: int, role: String = "lead_detective") -> Dictionary:
	if actor_id.is_empty() or revision < 0 or role not in ["lead_detective", "assistant_detective"]:
		return {}
	var local: Dictionary = session.export_state()
	var shared := {}
	for field in ["phase", "current_location", "active_person", "collected", "heard", "contacted", "asked_questions", "inferences", "contradictions", "reports", "requested_analyses", "hypotheses"]:
		shared[field] = local.get(field, []).duplicate(true) if local.get(field) is Array or local.get(field) is Dictionary else local.get(field)
	shared.accusations = session.accusations()
	shared.campaign = session.campaign.public_snapshot()
	return {"protocol_version": PROTOCOL_VERSION, "case_id": session.case_id(), "content_hash": session.content_hash, "actor_id": actor_id, "role": role, "revision": revision, "state": shared}
