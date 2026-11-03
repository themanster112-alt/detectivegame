extends "res://scripts/dialogue/dialogue_provider.gd"
func respond(request: Dictionary) -> Dictionary:
	var segments := []
	for fact in request.get("allowed_facts", []):
		segments.append({"fact_id": fact.id, "variant": 0})
	return {"segments": segments, "reaction": "neutral"}
