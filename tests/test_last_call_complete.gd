extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const PATH := "res://data/cases/last_call.json"
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
func settle() -> void:
	await process_frame
	await process_frame
func touch(button: Control) -> void:
	if button == null:
		check(false, "Required touch target exists")
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await settle()
func action(prefix: String) -> Button:
	for button in game._modal_actions.get_children():
		if button is Button and button.text.begins_with(prefix):
			return button
	return null
func card(id: String) -> Button:
	for button in game._card_grid.get_children():
		if button.get_meta("item_id", "") == id:
			return button
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/last-call-complete-" + name + ".png")
func visible_labels() -> String:
	var labels: Array = game.modal_body.find_children("*", "Label", true, false)
	return "
".join(labels.map(func(label): return label.text))
func run() -> void:
	var loaded := Loader.load_case(PATH)
	check(loaded.errors.is_empty(), "Completed case satisfies generic contract")
	if not loaded.errors.is_empty():
		push_error(str(loaded.errors))
		quit(1)
		return
	var data: Dictionary = loaded.data
	check(data.evidence.size() == 15 and data.questions.size() == 30 and data.reports.size() == 8, "Full evidence and branching dialogue set present")
	check(data.truth.culprit_ids == ["nadine"], "Requested private culprit preserved")
	check(data.truth.timeline.map(func(event): return event.time) == ["22:48", "23:02", "23:09", "23:13", "23:18", "23:27", "23:34", "23:38", "23:47"], "Secret timeline matches every requested event")
	check(data.truth.phone_limits.contains("الجيب") and data.truth.phone_limits.contains("غير موثّقين"), "Phone departure and unknown later disposal are distinguished")
	var s := Session.new()
	check(s.load_case(PATH), "Complete case loads")
	check(s.request_analysis("weapon_analysis").status == "locked", "Analyses cannot run during intro")
	s.begin_investigation()
	for report in data.reports:
		if report.get("request_required", false):
			check(s.request_analysis(report.id).status == "locked", "Missing analysis inputs stay locked")
	for person in data.people:
		s.select_person(person.id)
		for question in s.questions_for(person.id):
			if question.available:
				var context := s.dialogue_context(person.id, question.id)
				check(not context.has("truth") and not context.has("conceals"), "Provider only sees authorized facts")
				check(not str(context.speaker).contains("خسارة شقيقها") and not str(context.speaker).contains("أوقف كاميرات"), "Personality cannot leak concealed facts")
	check(s.available_reports().size() == 2, "Initial report count excludes all forensic requests")
	s.select_person("layla")
	s.ask_question("layla_office_visit")
	check(s.ask_question("layla_search").status == "locked", "Layla secret gated by documents")
	s.select_person("samer")
	s.ask_question("samer_camera_cause")
	check(s.ask_question("samer_server_admission").status == "locked", "Samer secret gated by analysis")
	s.select_person("mazen")
	s.ask_question("mazen_threat_denial")
	check(s.ask_question("mazen_threat_admission").status == "locked", "Mazen admission gated by actual threat evidence")
	for clue in data.evidence:
		if clue.location_id == "adam_office" and s.meets(clue.get("requires", {})):
			check(s.collect_evidence(clue.id), "Office evidence reachable without fixed interview order")
	check(s.has_evidence("statue_photo") and s.has_evidence("server_logs") and s.has_evidence("fraud_ledger"), "Requested photo, server and financial evidence accessible")
	s.select_person("layla")
	check(s.confront("layla_office_visit", "door_events").status == "confirmed", "Layla's entry denial is confrontable")
	check(s.ask_question("layla_search").status == "answered", "Layla reveals file search after documentary challenge")
	s.select_person("mazen")
	check(s.confront("mazen_threat_denial", "mazen_threats").status == "confirmed", "Mazen threat denial can be challenged")
	check(s.ask_question("mazen_threat_admission").status == "answered", "Mazen admits threat without admitting murder")
	check(s.request_analysis("server_analysis").status == "completed", "Server analysis is immediate on explicit request")
	s.select_person("samer")
	check(s.confront("samer_camera_cause", "server_logs").status == "confirmed", "Camera story changes only after verified logs")
	check(s.ask_question("samer_server_admission").answer.contains("لم أكن مخولًا"), "Samer's unauthorized access is a separate revealed offense")
	check(s.available_reports().size() == 3, "Unrequested financial and weapon results remain hidden")
	s.travel_to("reception")
	for clue in data.evidence:
		if clue.location_id == "reception" and s.meets(clue.get("requires", {})):
			check(s.collect_evidence(clue.id), "Reception evidence reachable")
	check(not s.has_evidence("bag_fibers"), "Reference sample does not appear before bag ownership and sampling")
	s.select_person("nadine")
	s.ask_question("nadine_exit")
	s.ask_question("nadine_locker")
	check(s.confront("nadine_locker", "locker_access").status == "confirmed", "Locker timeline contradicts Nadine's denial")
	check(s.ask_question("nadine_locker_response").status == "answered", "Confrontation opens a follow-up branch")
	check(s.ask_question("nadine_bag").status == "answered", "Bag source and consent established")
	check(s.collect_evidence("bag_fibers"), "Fiber material can now be collected")
	for report in data.reports:
		if report.get("request_required", false) and report.id != "server_analysis":
			check(s.available_analyses().any(func(task): return task.id == report.id), "Prepared analysis is available but not auto published")
			check(s.request_analysis(report.id).status == "completed", "Each requested forensic result is immediate")
	check(s.available_reports().size() == 8, "All eight reports available after six explicit requests")
	check(s.available_analyses().is_empty(), "Completed requests do not duplicate")
	check(s.ask_question("nadine_fibers").status == "answered", "Fiber comparison unlocks a distinct response")
	s.ask_question("nadine_finance")
	check(s.ask_question("nadine_finance_result").status == "answered", "Financial sequence unlocks a later motive branch")
	check(s.ask_question("nadine_audio_access").status == "answered", "Verified archive access opens a late question")
	s.select_person("layla")
	s.ask_question("layla_call_question")
	check(s.confront("layla_call_question", "audio_archive").status == "confirmed", "Recorded call stops being evidence of a live victim")
	check(s.ask_question("layla_old_bell").status == "answered", "Old elevator chime is usable without revealing caller")
	s.select_person("samer")
	var replay := s.ask_question("samer_replay")
	check(replay.status == "answered" and replay.answer.contains("ممكن") and replay.answer.contains("لا تعين"), "Playback mechanism is coherent but not falsely presented as proven physical setup")
	check(s.ask_question("samer_clock_check").status == "answered", "Clock comparison does not turn medical estimate exact")
	s.select_person("mazen")
	check(s.ask_question("mazen_departure").status == "answered", "Mazen provides testable departure account")
	check(s.ask_question("mazen_departure_verified").status == "answered", "Independent result opens alibi follow-up")
	check(s.link_nodes(["e:desk_inventory", "e:statue_photo"], "compatible").status == "confirmed", "Missing object and old photo link")
	check(s.link_nodes(["e:call_recording", "e:audio_archive"], "same_source").status == "confirmed", "Old bell and recording link")
	check(s.link_nodes(["e:locker_find", "r:weapon_analysis"], "compatible").status == "confirmed", "Weapon link uses requested result")
	check(s.link_nodes(["e:locker_find", "r:fiber_analysis"], "contact").status == "confirmed", "Fibers can support a contact inference")
	check(s.link_nodes(["e:door_events", "e:locker_access"], "movement").status == "confirmed", "Five-minute concealment route is coherent")
	check(s.timeline().filter(func(event): return event.id == "death_window")[0].status == "uncertain", "Public death time remains approximate")
	check(not s.timeline().any(func(event): return event.time.contains("١١:٠٩")), "Exact strike time stays private")
	var full := ["e:door_events", "q:nadine_exit", "e:locker_find", "r:weapon_analysis", "i:weapon_link", "e:locker_access", "r:fiber_analysis", "q:nadine_bag", "e:finance_memo", "r:finance_analysis", "q:nadine_finance"]
	var saved := s.export_state()
	var restored := Session.new()
	restored.load_case(PATH)
	check(restored.restore_state(saved) and restored.export_state() == saved, "Branches, requests, clues and conclusions survive save restoration")
	var charge := s.submit_accusation("nadine", full)
	check(charge.status == "submitted" and not charge.has("outcome"), "Strong accusation is pending, never an automatic reveal")
	check(s.review_accusation(charge.id).decision == "charge_established", "Four connected evidence groups can establish the case")
	check(not s.accusations()[-1].has("outcome"), "Public judgment does not reveal truth")
	check(s.audit_accusation(charge.id).outcome == "proven", "Only optional audit reveals factual solution")
	var alternative := Session.new()
	alternative.load_case(PATH)
	alternative.restore_state(saved)
	var other_route := ["e:door_events", "q:nadine_exit", "e:locker_find", "r:weapon_analysis", "i:weapon_link", "e:locker_access", "r:fiber_analysis", "q:nadine_bag", "e:call_log", "r:audio_analysis", "r:server_analysis", "i:reused_audio"]
	var alternative_charge := alternative.submit_accusation("nadine", other_route)
	check(alternative.review_accusation(alternative_charge.id).decision == "charge_established", "An independent call-staging route can replace the financial motive route")
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	for page in game.case_intro._pages:
		check(not str(page).contains("احتيال") and not str(page).contains("نادين قتلت"), "Intro still does not disclose corruption or culprit")
	game.begin_investigation()
	await settle()
	var regions: Array = game.room._hotspots.get_children().filter(func(button): return button.has_meta("inspection_id"))
	check(regions.size() == 4, "Many office clues share four physical search zones")
	for first in range(regions.size()):
		for second in range(first + 1, regions.size()):
			check(not regions[first].get_global_rect().intersects(regions[second].get_global_rect()), "Search zones do not overlap")
	await touch(game.room.find_child("Inspection_area_office_terminal", true, false))
	check(game._card_grid.get_child_count() == 3, "Computer zone exposes its three inspectable records")
	check(game.session.collected_ids().is_empty(), "Opening a grouped search does not collect every document")
	await capture("terminal")
	await touch(card("server_logs"))
	check(not visible_labels().contains("سجلات الخوادم والكاميرات"), "Uncollected record name stays hidden in inspector")
	await touch(action("أضف إلى دفتر الأدلة"))
	check(game.session.has_evidence("server_logs") and game.session.collected_ids().size() == 1, "Only chosen record is collected")
	check(action("تحقق من سجلات الخوادم") != null, "Prepared analysis can be requested from inspection")
	check(not game.session.available_reports().any(func(report): return report.id == "server_analysis"), "UI has not auto requested analysis")
	await touch(action("تحقق من سجلات الخوادم"))
	check(game._window_title.text == "نتيجة التحليل" and game.session.available_reports().any(func(report): return report.id == "server_analysis"), "Touch request displays completed result immediately")
	check(not visible_labels().contains("نادين قتلت") and not visible_labels().contains("١١:٠٩"), "Scientific result avoids final culprit or exact death-time reveal")
	await capture("analysis")
	game.show_reports()
	check(action("طلب تحليل") == null, "No unprepared analysis is offered")
	game.close_modal()
	for id in ["desk_inventory", "finance_memo"]:
		game.session.collect_evidence(id)
	game.close_modal()
	await touch(game.room.find_child("Inspection_area_office_files", true, false))
	check(game._card_grid.get_child_count() == 3, "Newly available ledger appears in existing file area")
	await capture("files")
	game.queue_free()
	await process_frame
	print("LAST CALL COMPLETE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
