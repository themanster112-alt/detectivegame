extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const Manager = preload("res://scripts/core/case_manager.gd")
const Store = preload("res://scripts/core/save_store.gd")
const Campaign = preload("res://scripts/core/campaign_state.gd")
const FIXTURE := "res://tests/fixtures/engine_contract.json"
const DIRECTORY := "res://.godot/engine-save-tests/"
var checks := 0
var failures := 0

class MaliciousProvider extends RefCounted:
	func respond(_request: Dictionary) -> Dictionary:
		return {"segments": [{"fact_id": "secret_a", "variant": 0}], "reaction": "neutral", "truth": "invented"}
class VariantProvider extends RefCounted:
	var received: Dictionary = {}
	func respond(request: Dictionary) -> Dictionary:
		received = request.duplicate(true)
		return {"segments": [{"fact_id": "fact_a", "variant": 1}], "reaction": "defensive", "text": "Invented facts must never render."}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func new_session() -> RefCounted:
	var session := Session.new()
	if not session.load_case(FIXTURE):
		push_error(str(session.errors))
		quit(1)
	session.begin_investigation()
	return session

func _initialize() -> void:
	var loaded := Loader.load_case(FIXTURE)
	check(loaded.errors.is_empty(), "Native v2 JSON loads with numeric fields")
	if not loaded.errors.is_empty():
		push_error(str(loaded.errors))
		quit(1)
		return
	check(loaded.data.people.size() == 6 and loaded.data.locations.size() == 3, "Counts vary independently")
	check(Loader.load_case("res://data/templates/case_template.json").errors.is_empty(), "Author template is a valid independent case")
	var original: Dictionary = loaded.data
	for field in ["people", "locations", "facts", "questions", "reports", "timeline", "inferences", "contradictions", "assessment", "truth"]:
		var bad := original.duplicate(true)
		bad[field] = null
		check(not Loader.validate(bad).is_empty(), "Malformed field rejected: " + field)
	var bad := original.duplicate(true)
	bad.people[4].ai = null
	check(not Loader.validate(bad).is_empty(), "Missing character boundaries rejected")
	bad = original.duplicate(true)
	bad.reports[0].requires = null
	check(not Loader.validate(bad).is_empty(), "Malformed report requirements rejected safely")
	bad = original.duplicate(true)
	bad.reports[0].kind = "technical"
	check(not Loader.validate(bad).is_empty(), "Murder needs forensic briefing")
	bad = original.duplicate(true)
	bad.assessment.profiles[1].criteria[0].all_of = ["e:missing"]
	check(not Loader.validate(bad).is_empty(), "Unknown judgment evidence rejected")
	bad = original.duplicate(true)
	bad.people = [bad.people[0]]
	bad.statements = []
	bad.questions = []
	bad.facts = []
	bad.contradictions = []
	bad.inferences = []
	bad.timeline = []
	bad.assessment.profiles = []
	bad.campaign_effects = {}
	check(Loader.validate(bad).is_empty(), "Case can have one suspect and no witnesses or dialogue")
	var s = new_session()
	check(s.available_reports().size() == 1, "Only initial report available at start")
	check(s.timeline().is_empty(), "Unknown timeline events hidden")
	check(s.can_conclude() and s.collected_ids().is_empty(), "No collection gate on accusation")
	var early: Dictionary = s.submit_accusation("suspect_beta", [])
	check(early.status == "submitted" and not early.has("decision") and not early.has("outcome"), "Submission does not evaluate truth")
	check(s.review_accusation(early.id).decision == "insufficient", "Empty accusation fails on evidence strength")
	check(s.audit_accusation(early.id).outcome == "failed", "Optional failure audit")
	check(s.reopen_case(), "Failed case can be reopened")
	check(s.select_person("witness_a"), "Witness can be summoned")
	check(s.dialogue_context("witness_a", "question_hidden").is_empty(), "Hidden facts gated before evidence")
	var before: Dictionary = s.export_state()
	s.set_dialogue_provider(MaliciousProvider.new())
	check(s.ask_question("question_a").status == "provider_error", "Unauthorized provider fact rejected")
	check(s.export_state() == before, "Invalid provider response cannot advance progress")
	var provider := VariantProvider.new()
	check(s.set_dialogue_provider(provider), "Provider is replaceable")
	var reply: Dictionary = s.ask_question("question_a")
	check(reply.status == "answered" and reply.answer == "صياغة اختبار معتمدة.", "Only approved phrasing is rendered")
	check(not str(provider.received).contains("secret_a") and not provider.received.has("truth") and not provider.received.speaker.has("conceals"), "Provider context has no hidden truth or concealed facts")
	check(s.collect_evidence("sample"), "Evidence collection remains independent")
	check(s.available_reports().size() == 2 and s.available_reports()[0].updated_by == "updated", "Evidence unlocks a later report update")
	check(s.timeline().size() == 1, "Evidence unlocks timeline event")
	check(s.ask_question("question_hidden").status == "locked", "Fact-level conditions apply beyond question conditions")
	s.set_dialogue_provider(preload("res://scripts/dialogue/local_dialogue_provider.gd").new())
	check(s.confront("question_a", "sample").status == "confirmed", "Confrontation records supported contradiction")
	check(s.ask_question("question_hidden").status == "answered", "Protected fact becomes available only after required contradiction")
	check(s.known_nodes().any(func(node): return node.ref == "q:question_a" and node.text == "صياغة اختبار معتمدة."), "Interrogation answers are linkable recorded claims")
	check(s.link_nodes(["e:sample", "q:question_a"], "alternative").status == "hypothesis", "Evidence can link directly to interrogation answers")
	check(s.hear_statement("statement_a"), "Statement can be recorded after questioning")
	check(s.timeline().size() == 2 and s.timeline()[0].id == "event_b", "Timeline is data ordered and preserves uncertainty")
	check(s.link_nodes(["e:sample", "s:statement_a"], "supports").status == "confirmed", "Evidence-to-statement link works")
	var refs := ["e:sample", "s:statement_a", "i:relation_a"]
	var charge: Dictionary = s.submit_accusation("suspect_alpha", refs)
	check(s.review_accusation(charge.id).decision == "charge_established", "Strong interlinked charge succeeds without all evidence")
	check(not s.accusations()[-1].has("outcome"), "Public verdict does not reveal actual guilt")
	check(s.audit_accusation(charge.id).outcome == "proven", "Optional audit identifies proven case")
	var reputation: float = s.campaign.reputation
	s.audit_accusation(charge.id)
	check(s.campaign.reputation == reputation, "Auditing is idempotent")
	check(s.campaign.trust.get("witness_a") == 1, "Case-defined character trust persists")
	var alternative = new_session()
	alternative.collect_evidence("sample")
	alternative.select_person("witness_b")
	alternative.select_person("suspect_alpha")
	var alternative_charge: Dictionary = alternative.submit_accusation("suspect_alpha", ["e:sample", "r:updated", "p:witness_b"])
	check(alternative.review_accusation(alternative_charge.id).decision == "charge_established", "Alternative proof route needs no forced linking or interrogation sequence")
	check(alternative.audit_accusation(alternative_charge.id).outcome == "proven", "Alternative case-defined proof route succeeds")
	var wrongful = new_session()
	wrongful.travel_to("annex")
	wrongful.collect_evidence("misleading")
	var wrongful_charge: Dictionary = wrongful.submit_accusation("suspect_beta", ["e:misleading", "r:initial"])
	check(wrongful.review_accusation(wrongful_charge.id).decision == "charge_established", "Misleading evidence can produce an accepted judgment")
	check(not wrongful.accusations()[0].has("outcome"), "Wrongful judgment is not labeled wrong immediately")
	check(not wrongful.campaign.public_snapshot().judgments[0].has("outcome") and wrongful.campaign.reputation == 0, "Campaign UI cannot leak sealed guilt through reputation or history")
	check(wrongful.audit_accusation(wrongful_charge.id).outcome == "wrongful_verdict", "Later optional audit reveals wrongful judgment")
	check(wrongful.campaign.reputation == -3 and wrongful.campaign.flags.previous_error, "Audit applies configured campaign consequences")
	check(wrongful.reopen_case() and wrongful.has_evidence("misleading"), "Reopening preserves observations and prior verdicts")
	var saved_state: Dictionary = s.export_state()
	var restored = new_session()
	check(restored.restore_state(saved_state), "Complete state restores")
	check(restored.export_state() == saved_state, "Restoration keeps evidence, statements, inferences, dialogue, accusations and outcomes")
	var invalid: Dictionary = saved_state.duplicate(true)
	invalid.collected.append("missing")
	var unchanged: Dictionary = restored.export_state()
	check(not restored.restore_state(invalid) and restored.export_state() == unchanged, "Corrupted state rejected atomically")
	invalid = saved_state.duplicate(true)
	invalid.content_hash = "different"
	check(not restored.restore_state(invalid), "Case revision changes cannot silently reuse stale state")
	invalid = saved_state.duplicate(true)
	invalid.accusations[0].refs = ["e:missing"]
	check(not restored.restore_state(invalid), "Unknown saved accusation references rejected")
	invalid = saved_state.duplicate(true)
	invalid.accusations[0].id = "duplicate"
	check(not restored.restore_state(invalid), "Invalid saved accusation identity rejected")
	invalid = saved_state.duplicate(true)
	invalid.hypotheses = [{"id": "one", "links": ["e:sample", "h:future"], "meaning": "supports", "label": "test"}]
	check(not restored.restore_state(invalid), "Dangling saved hypothesis references rejected")
	restored.reopen_case()
	var reopened_state: Dictionary = restored.export_state()
	check(restored.restore_state(reopened_state) and not restored.solved, "Reopened case restores without stale success flag")
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var path := DIRECTORY + "progress.json"
	DirAccess.remove_absolute(path)
	var manager := Manager.new()
	manager.save_path = path
	check(manager.load_progress() and manager.open_case(FIXTURE), "Manager opens independent case")
	manager.session.begin_investigation()
	manager.session.collect_evidence("sample")
	check(manager.save_now(), "Progress writes to JSON")
	manager.session.select_person("witness_a")
	check(manager.save_now(), "Atomic save replaces an existing file")
	var second := Manager.new()
	second.save_path = path
	check(second.load_progress() and second.open_case(FIXTURE) and second.restored, "Manager restores saved case")
	check(second.session.has_evidence("sample") and second.session.active_person == "witness_a", "Restored UI can resume investigation")
	var next_case: Dictionary = original.duplicate(true)
	next_case.id = "followup_test"
	next_case.requirements = {"global": {"reputation_min": 1, "judgments": {"engine_contract": "charge_established"}}}
	var next_path := DIRECTORY + "followup.json"
	var file := FileAccess.open(next_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(next_case))
	file.close()
	manager.campaign.restore(s.campaign.snapshot())
	check(manager.open_case(next_path), "Campaign consequences unlock independent next case")
	manager.session.begin_investigation()
	check(manager.save_now(), "Multiple case progress saved")
	var third := Manager.new()
	third.save_path = path
	check(third.load_progress() and third.open_case(FIXTURE), "Earlier case remains independently restorable")
	check(third.session.has_evidence("sample") and third.campaign.reputation == s.campaign.reputation, "Campaign and cases restored together")
	var blocked := Manager.new()
	blocked.persistence_enabled = false
	check(not blocked.open_case(next_path), "Campaign requirements can keep later case unavailable")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var corrupt := Manager.new()
	corrupt.save_path = path
	check(not corrupt.load_progress(), "Corrupted disk save detected")
	corrupt.open_case(FIXTURE)
	corrupt.session.begin_investigation()
	check(FileAccess.get_file_as_string(path) == "{ broken", "Corrupted save never silently overwritten")
	check(not corrupt.save_now() and not corrupt.last_error.is_empty(), "Blocked saving retains a visible explanation")
	var frozen: Dictionary = original.duplicate(true)
	frozen.allow_reopen = false
	var locked := Session.new()
	check(locked.load_data(frozen), "Per-case reopen policy loads")
	locked.begin_investigation()
	var submitted: Dictionary = locked.submit_accusation("suspect_alpha", [])
	locked.review_accusation(submitted.id)
	check(not locked.reopen_case(), "Optional reopen can be disabled by case")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(next_path)
	DirAccess.remove_absolute(DIRECTORY)
	print("GENERAL ENGINE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
