extends RefCounted
## Replace through session.set_dialogue_provider(). No network or credentials here.
## Output selects authorized fact/variant IDs. Arbitrary generated prose is not trusted.
func respond(_request: Dictionary) -> Dictionary:
	return {"segments": [], "reaction": "neutral"}
