extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const CASE_PATH := "res://data/cases/midnight_training.json"
var checks := 0
var failures := 0
var changes := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var loaded := Loader.load_case(CASE_PATH)
	check(loaded.errors.is_empty(), "Legacy data normalizes to generic case")
	check(loaded.data.schema_version == 2 and loaded.data.people.size() == 4, "Legacy people are not dropped")
	for malformed in [null, [], "text", 17, {}, {"schema_version": 1, "witness": false}]:
		check(not Loader.validate(malformed).is_empty(), "Malformed input rejected without runtime errors")
	var original: Dictionary = loaded.data
	var mutations := []
	var bad := original.duplicate(true)
	bad.evidence.append(bad.evidence[0].duplicate(true))
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.evidence[0].location_id = "missing"
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.evidence[0].position = ["x", 1]
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.start_location = "missing"
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.truth.culprit_ids = ["unknown"]
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.questions[0].answer_facts = ["unknown"]
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.inferences[0].links = ["e:phone", "e:phone"]
	mutations.append(bad)
	bad = original.duplicate(true)
	bad.assessment.profiles[0].criteria[0].all_of = ["e:missing"]
	mutations.append(bad)
	for item in mutations:
		check(not Loader.validate(item).is_empty(), "Invalid references rejected")
	var session := Session.new()
	session.changed.connect(func(): changes += 1)
	check(session.load_case(CASE_PATH), "Case loads")
	check(session.phase == "briefing" and not session.can_conclude(), "Starts with case briefing")
	check(session.begin_investigation() and session.can_conclude(), "Accusation available immediately after briefing")
	check(not session.record_witness(), "No remote testimony without summoning")
	check(session.collect_evidence("phone"), "Local clue collected")
	check(not session.collect_evidence("phone"), "Duplicate collection rejected")
	check(not session.collect_evidence("unknown"), "Unknown collection rejected")
	var snapshot := session.case_snapshot()
	check(not snapshot.has("truth") and not snapshot.has("facts") and not snapshot.has("assessment"), "Public case has no solution or private facts")
	snapshot.evidence.clear()
	check(session.case_snapshot().evidence.size() == 3, "Public snapshots isolated")
	var collected_copy := session.collected_ids()
	collected_copy.clear()
	check(session.has_evidence("phone"), "Collection snapshots isolated")
	check(not session.travel_to("unknown"), "Unknown location rejected")
	check(session.travel_to("reception"), "Travel works")
	check(not session.collect_evidence("coffee"), "Remote collection rejected")
	check(session.record_witness() and session.witness_heard(), "Legacy testimony API preserved")
	check(not session.record_witness(), "Duplicate testimony ignored")
	check(session.select_person("samer"), "Suspect can be summoned without assigned physical location")
	check(session.person_statements("samer").is_empty(), "No invented suspect dialogue")
	check(session.travel_to("office"), "Free return")
	session.collect_evidence("coffee")
	session.collect_evidence("letter")
	check(session.try_inference("phone", "coffee", "return").status == "confirmed", "Existing evidence relation preserved")
	check(session.select_person("layla"), "Witness summon works away from original location")
	check(session.ask_question("cup").status == "answered", "Question works without mandatory sequence")
	check(session.confront("cup", "coffee").status == "confirmed", "Contradiction preserved")
	var early := session.submit_accusation("nour", [])
	check(early.status == "submitted" and not early.has("outcome"), "Wrong suspect accepted without immediate verdict")
	check(session.submit_accusation("unknown", []).status == "invalid", "Unknown suspect rejected")
	check(session.submit_accusation("samer", ["e:phone", "e:phone"]).status == "invalid", "Duplicate accusation references rejected")
	var full_refs := ["e:phone", "e:coffee", "e:letter", "i:samer_return", "c:receipt_time"]
	var full := session.submit_accusation("samer", full_refs)
	check(full.status == "submitted" and not session.solved, "Complete charge remains pending")
	check(session.accusations().all(func(item): return not item.has("outcome")), "Public pending accusations have no hidden outcome")
	var state := session.export_state()
	check(not session.load_case("res://missing.json") and session.export_state() == state, "Failed case load preserves current state")
	check(session.review_accusation(full.id).decision == "charge_established", "Strong interlinked case accepted at review")
	check(not session.accusations()[-1].has("outcome"), "Review does not reveal true culprit")
	check(session.audit_accusation(full.id).outcome == "proven", "Optional audit reveals actual proof")
	check(session.reopen_case() and session.has_evidence("phone"), "Reopening retains evidence")
	check(changes > 0, "Progress emits state signals")
	session.reset()
	check(session.phase == "briefing" and session.collected_ids().is_empty() and session.accusations().is_empty(), "Reset restores fresh briefing")
	print("SESSION: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
