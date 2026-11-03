extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const Manager = preload("res://scripts/core/case_manager.gd")
const PATH := "res://data/cases/last_call.json"
const SAVE := "res://.godot/last-call-outcomes-test.json"
var checks := 0
var failures := 0
var game: Control
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func fresh():
	var s = Session.new()
	check(s.load_case(PATH), "Case loads")
	s.begin_investigation()
	return s
func complete(s) -> void:
	for iteration in range(6):
		for clue in s._case.evidence:
			if s.meets(clue.get("requires", {})):
				s.travel_to(clue.location_id)
				s.collect_evidence(clue.id)
		for task in s.available_analyses():
			s.request_analysis(task.id)
		for person in s._case.people:
			s.select_person(person.id)
			for statement in s.person_statements(person.id):
				s.hear_statement(statement.id)
			for question in s.questions_for(person.id):
				if question.available:
					s.ask_question(question.id)
			for conflict in s._case.contradictions:
				if conflict.person_id == person.id:
					s.confront(conflict.question_id, conflict.evidence_id)
func labels() -> String:
	var text := ""
	for label in game.modal_body.find_children("*", "Label", true, false):
		text += label.text + "\n"
	return text
func fit() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for control in game._modal_actions.get_children():
		if control is Button and control.is_visible_in_tree():
			check(screen.encloses(control.get_global_rect()), "Visible action fits 1280x720: " + control.text)
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/last-call-outcomes-" + name + ".png")
func run() -> void:
	for suspect in ["nadine", "layla", "samer", "mazen"]:
		var early = fresh()
		check(early.can_conclude(), "Accusation available immediately")
		var charge: Dictionary = early.submit_accusation(suspect, [])
		check(charge.status == "submitted" and not charge.has("outcome"), "Any suspect accepts an early empty dossier")
		check(early.review_accusation(charge.id).decision == "insufficient", "Early charge lacks supporting evidence")
		check(not early.accusations()[0].has("outcome"), "Insufficient decision does not disclose culprit")
	var full = fresh()
	complete(full)
	check(full.collected_ids().size() == 15, "Full free-order investigation reaches every clue")
	for spec in [ [["e:locker_find", "r:weapon_analysis"], "compatible", "weapon_link"], [["e:call_log", "r:audio_analysis"], "not_alive_proof", "call_not_life"], [["e:locker_access", "e:locker_find"], "storage_access", "nadine_storage"], [["r:finance_analysis", "q:nadine_finance"], "motive_limit", "motive_not_proof"] ]:
		check(full.link_nodes(spec[0], spec[1]).status == "confirmed", "Required board inference: " + spec[2])
	var state: Dictionary = full.export_state()
	var motive = fresh()
	motive.restore_state(state)
	var motive_charge: Dictionary = motive.submit_accusation("nadine", ["e:finance_memo", "r:finance_analysis", "q:nadine_finance", "i:motive_not_proof"])
	check(motive.review_accusation(motive_charge.id).decision == "insufficient", "Financial motive alone never proves murder")
	var supported := ["e:door_events", "q:nadine_exit", "e:locker_find", "r:weapon_analysis", "i:weapon_link", "e:locker_access", "r:fiber_analysis", "q:nadine_bag", "e:finance_memo", "r:finance_analysis", "q:nadine_finance"]
	var misleading := ["e:mazen_threats", "q:mazen_threat_admission", "s:mazen_dispute", "q:mazen_business", "q:mazen_threat_denial", "c:mazen_threat_conflict", "e:call_log", "q:mazen_missed"]
	var rebutted = fresh()
	rebutted.restore_state(state)
	var rebutted_charge: Dictionary = rebutted.submit_accusation("mazen", misleading + ["r:movement_analysis"])
	check(rebutted.review_accusation(rebutted_charge.id).decision == "insufficient", "Attached independent departure report defeats misleading dossier")
	var later = fresh()
	later.restore_state(state)
	var frozen: Dictionary = later.submit_accusation("mazen", misleading)
	check(later.has_evidence("security_log") and later.review_accusation(frozen.id).decision == "charge_established", "Only attached rebuttals count; omitted discoveries do not rewrite dossier")
	var invalid: Dictionary = full._case.duplicate(true)
	invalid.assessment.profiles[3].criteria[0].none_of = ["r:missing_report"]
	check(not Loader.validate(invalid).is_empty(), "Unknown rebuttal references rejected")
	for spec in [["nadine", supported, "proven"], ["mazen", misleading, "wrongful_verdict"], ["layla", [], "failed"]]:
		var s = fresh()
		check(s.restore_state(state), "Pre-accusation progress restores")
		var charge: Dictionary = s.submit_accusation(spec[0], spec[1])
		check(charge.status == "submitted" and not charge.has("outcome"), "Submission is sealed")
		check(s.review_accusation(charge.id).decision == ("insufficient" if spec[2] == "failed" else "charge_established"), "Decision reflects dossier strength without revealing factual guilt")
		check(not s.accusations()[0].has("outcome") and not s.campaign.public_snapshot().judgments[0].has("outcome"), "Neither judgment nor campaign leaks correctness")
		check(s.campaign.reputation == (-1 if spec[2] == "failed" else 0), "Only public insufficiency affects reputation before audit")
		var manager = Manager.new()
		manager.save_path = SAVE
		manager.campaign = s.campaign
		check(manager.open_case(PATH), "Manager opens case for isolated disk test")
		check(manager.session.restore_state(s.export_state()) and manager.save_now(), "Actual disk save writes sealed outcome")
		var reload = Manager.new()
		reload.save_path = SAVE
		check(reload.load_progress() and reload.open_case(PATH) and reload.restored, "Actual disk reload restores closed case")
		check(reload.session.export_state() == s.export_state(), "Evidence, links and judgments round-trip exactly")
		check(reload.campaign.snapshot() == s.campaign.snapshot(), "Private outcome survives for following cases")
		check(not reload.campaign_summary().judgments[0].has("outcome"), "Reload does not expose verdict truth")
		check(reload.session.audit_accusation(charge.id).outcome == spec[2], "Optional later audit distinguishes required outcome")
		check(reload.campaign.reputation == (2 if spec[2] == "proven" else (-1 if spec[2] == "failed" else -3)), "Configured consequences apply only after optional audit")
		reload.save_now()
		var audited_reload = Manager.new()
		audited_reload.save_path = SAVE
		check(audited_reload.load_progress() and audited_reload.open_case(PATH), "Audited history reloads")
		check(audited_reload.campaign.public_snapshot().judgments[0].outcome == spec[2], "Later case history retains audited outcome")
		DirAccess.remove_absolute(SAVE)
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame
	game.begin_investigation()
	check(game.session.restore_state(state), "UI resumes full investigation")
	game.board_selection.assign(["e:call_log", "r:audio_analysis"])
	game._show_link_meanings()
	await capture("relations")
	fit()
	check(game._card_grid.get_child_count() == 4, "Many interpretations are paged rather than oversized buttons")
	game._pages["link_meanings"] = 2
	game._refresh_section("link_meanings")
	await process_frame
	await process_frame
	check(game._card_grid.get_children().any(func(button): return button.get_meta("item_id", "") == "not_alive_proof"), "Last page of interpretations is reachable")
	game._submit_board_inference("not_alive_proof")
	game._board_tab = "inference"
	game.show_board()
	await capture("board")
	fit()
	check(not labels().contains("S-04"), "Closing hint does not appear during investigation")
	game.show_conclusion()
	await capture("accusation")
	fit()
	game.proof_selection.assign(misleading)
	game.choose_suspect("mazen")
	check(not labels().contains("S-04") and not labels().contains("حكم خاطئ"), "Submission reveals neither hint nor correctness")
	game._review_accusation(game._last_accusation_id)
	await capture("closing")
	fit()
	check(labels().contains("مشروع الصمت") and labels().contains("S-04"), "Closing review displays ambiguous sequel hook")
	check(not labels().contains("يزن") and not labels().contains("حكم خاطئ"), "Hook reveals neither Yazan's secret nor wrong verdict")
	game.show_accusations()
	check(labels().contains("S-04"), "Closing hint remains accessible from saved closed phase")
	game.queue_free()
	await process_frame
	print("LAST CALL OUTCOMES: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
