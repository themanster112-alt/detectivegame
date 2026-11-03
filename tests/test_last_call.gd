extends SceneTree
const Loader = preload("res://scripts/core/case_loader.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const Repository = preload("res://scripts/core/case_repository.gd")
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
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/last-call-" + name + ".png")
func action(prefix: String) -> Button:
	for control in game._modal_actions.get_children():
		if control is Button and control.text.begins_with(prefix):
			return control
	return null
func run() -> void:
	var loaded := Loader.load_case(PATH)
	check(loaded.errors.is_empty(), "First case validates against unchanged schema")
	if not loaded.errors.is_empty():
		push_error(str(loaded.errors))
		quit(1)
		return
	var data: Dictionary = loaded.data
	check(data.title == "المكالمة الأخيرة" and data.case_file.number == "CASE-001", "First case identity")
	check(data.case_file.victim.name.contains("٤٣") and data.case_file.victim.background.contains("مجموعة الأفق"), "Victim age and occupation preserved")
	check(data.people.size() == 4 and data.people.all(func(person): return person.role in ["suspect", "both"]), "Exactly four suspects")
	check(data.people.map(func(person): return person.id) == ["nadine", "layla", "samer", "mazen"], "Requested cast preserved")
	check(data.assistant.name.contains("يزن"), "Yazan gives initial briefing")
	check(data.target_duration_minutes >= 15 and data.target_duration_minutes <= 20, "Target duration is metadata only")
	var session := Session.new()
	check(session.load_case(PATH), "General session loads new case")
	check(session.available_reports().size() == 2, "Only initial reports appear during opening")
	var medical: Dictionary = session.available_reports()[0]
	check(medical.kind == "forensic" and medical.status == "preliminary", "Initial medical report is preliminary")
	check(medical.estimated_time.contains("١١:٠٠") and medical.estimated_time.contains("١١:٢٠") and medical.estimated_time.contains("قابل للمراجعة"), "Death window remains an estimate")
	check(session.timeline().filter(func(event): return event.id == "death_window")[0].status == "uncertain", "Timeline never turns death estimate into an exact time")
	var snapshot := session.case_snapshot()
	check(not snapshot.has("truth") and not snapshot.has("assessment") and not snapshot.has("facts"), "Hidden truth does not enter UI snapshot")
	check(snapshot.people.all(func(person): return not person.has("ai")), "Private character boundaries hidden")
	check(session.begin_investigation() and session.can_conclude(), "Free investigation and early accusation remain available")
	check(session.select_person("nadine"), "Nadine can be questioned")
	check(session.ask_question("nadine_finance").status == "locked", "Financial material not disclosed before discovery")
	check(session.dialogue_context("nadine", "nadine_finance").is_empty(), "Provider does not receive concealed financial facts early")
	for person in data.people:
		check(session.select_person(person.id), "Requested suspect available")
		var statements := session.person_statements(person.id)
		check(statements.size() == 2, "Each suspect has concise initial statements")
		for statement in statements:
			check(session.hear_statement(statement.id), "Initial statement recorded by existing system")
		for question in session.questions_for(person.id):
			if question.available:
				var reply: Dictionary = session.ask_question(question.id)
				check(reply.status == "answered", "Initial local dialogue works offline")
	check(session.heard_statements().size() == 8, "All initial accounts retained")
	session.travel_to("reception")
	check(not session.collect_evidence("locker_find"), "Hidden weapon cannot appear before reason to search")
	session.travel_to("adam_office")
	for id in ["door_events", "desk_inventory", "call_log", "finance_memo"]:
		check(session.collect_evidence(id), "Office evidence uses current collection engine")
	session.travel_to("reception")
	for id in ["call_recording", "audio_archive", "security_log", "locker_find"]:
		check(session.collect_evidence(id), "Reception evidence is reachable")
	check(session.available_reports().size() == 2, "Analysis results wait for explicit request")
	check(session.request_analysis("audio_analysis").status == "completed", "Audio result delivered immediately on request")
	check(session.request_analysis("weapon_analysis").status == "completed", "Weapon result delivered immediately on request")
	check(session.select_person("nadine"), "Return to Nadine remains free")
	check(session.ask_question("nadine_finance").status == "answered", "Evidence unlocks follow-up without engine changes")
	check(session.ask_question("nadine_exit").status == "answered", "Exit claim remains available")
	check(session.confront("nadine_exit", "door_events").status == "confirmed", "Exit discrepancy can be discovered")
	session.select_person("layla")
	session.ask_question("layla_call_question")
	check(session.confront("layla_call_question", "audio_archive").status == "confirmed", "Live-call belief can be revisited without accusing Layla")
	check(session.link_nodes(["e:call_recording", "e:audio_archive"], "same_source").status == "confirmed", "Call comparison uses existing board rules")
	session.travel_to("adam_office")
	session.collect_evidence("server_logs")
	session.collect_evidence("fraud_ledger")
	check(session.request_analysis("server_analysis").status == "completed", "Server analysis requested")
	check(session.request_analysis("finance_analysis").status == "completed", "Financial analysis requested")
	check(session.link_nodes(["e:locker_find", "r:weapon_analysis"], "compatible").status == "confirmed", "Weapon relationship established")
	var strong_refs := ["e:door_events", "q:nadine_exit", "e:locker_find", "r:weapon_analysis", "i:weapon_link", "e:finance_memo", "r:finance_analysis", "q:nadine_finance", "e:call_log", "r:audio_analysis", "r:server_analysis", "i:reused_audio"]
	var charge := session.submit_accusation("nadine", strong_refs)
	check(charge.status == "submitted" and not charge.has("outcome"), "No immediate guilt reveal at accusation")
	check(session.review_accusation(charge.id).decision == "charge_established", "Evidence can support a complete playable resolution")
	check(not session.accusations()[-1].has("outcome"), "Public decision still seals actual truth")
	check(session.audit_accusation(charge.id).outcome == "proven", "Private case truth used only by explicit later audit")
	var early := Session.new()
	early.load_case(PATH)
	early.begin_investigation()
	var weak := early.submit_accusation("nadine", [])
	check(weak.status == "submitted", "Even correct name can be accused with a partial file")
	check(early.review_accusation(weak.id).decision == "insufficient", "Name alone cannot prove this case")
	check(Repository.list_cases().any(func(item): return item.id == "last_call") and Repository.list_cases().any(func(item): return item.id == "midnight_training"), "New and old cases coexist in archive")
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.session.case_id() == "last_call" and game.case_intro.visible, "F5 entry opens the new first case")
	for page in game.case_intro._pages:
		var text := str(page)
		check(not text.contains("احتيال") and not text.contains("القاتلة") and not text.contains("نادين مراد هي المسؤولة"), "No corruption or culprit disclosure in introduction")
	check(game.case_intro._pages.any(func(page): return page.kind == "report" and page.eyebrow == "الطب الشرعي"), "Forensic page appears in cinematic sequence")
	await capture("opening")
	while game.case_intro._pages[game.case_intro.page].kind != "assistant":
		game.case_intro.advance()
	check(game.case_intro._pages[game.case_intro.page].title.contains("يزن"), "Assistant introduction uses Yazan, not a generic placeholder name")
	await capture("briefing")
	game.case_intro.skip_button.pressed.emit()
	await process_frame
	check(game.session.current_location == "adam_office" and game.room._background.texture != null, "Existing office artwork is reused")
	check(game.room._hotspots.get_children().filter(func(node): return node.has_meta("inspection_id")).size() == 4, "Grouped office regions avoid overlapping evidence buttons")
	check(not game.conclusion_button.disabled, "Accusation remains available after intro")
	await capture("office")
	game.show_people()
	check(game._card_grid.get_child_count() == 4, "All four suspects appear on one page")
	await capture("people")
	for person in data.people:
		game._start_dialogue(person.id)
		check(game._window_title.text == person.name, "Dialogue uses the requested character")
		var next := action("تابع الحديث")
		check(next != null, "Initial account has a continuation")
		if next != null:
			next.pressed.emit()
		check(game.session.person_statements(person.id).all(func(statement): return game.session.heard_statements().any(func(heard): return heard.id == statement.id)), "UI records both opening statements")
		game.close_modal()
	game.travel_to("reception")
	game._start_dialogue("layla")
	check(game.room._portrait.texture != null, "Existing Layla portrait reused")
	await capture("layla")
	game.queue_free()
	await process_frame
	print("LAST CALL: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
