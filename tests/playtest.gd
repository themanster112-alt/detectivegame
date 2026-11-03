extends SceneTree
var game: Control
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func press(text: String) -> bool:
	for item in game.modal_panel.find_children("*", "Button", true, false):
		if item is Button and item.text.begins_with(text):
			item.pressed.emit()
			return true
	return false
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	game.case_path = "res://data/cases/midnight_training.json"
	root.add_child(game)
	await process_frame
	check(game.session.phase == "briefing" and game.case_intro.visible, "New case opens with cinematic intro")
	check(game.case_intro._pages[0].title == game.case_data.title, "Opening shows the case title")
	check(not game._investigation_chrome.visible, "Investigation HUD stays hidden during opening")
	await capture("res://.godot/ux-opening.png")
	game.case_intro.next_button.pressed.emit()
	check(game.case_intro._pages[game.case_intro.page].kind == "case", "Next opens case report")
	await capture("res://.godot/case-file-preview.png")
	game.case_intro.next_button.pressed.emit()
	check(game.case_intro._pages[game.case_intro.page].kind == "report", "Case report continues to technical or forensic report")
	await capture("res://.godot/ux-report.png")
	game.case_intro.next_button.pressed.emit()
	check(game.case_intro._pages[game.case_intro.page].kind == "assistant", "Report continues to assistant briefing")
	await capture("res://.godot/assistant-preview.png")
	game.case_intro.skip_button.pressed.emit()
	check(not game.case_intro.visible, "Crime-scene button closes the intro")
	check(not game.overlay.visible and not game.conclusion_button.disabled, "Accusation is available from investigation start")
	game.show_conclusion()
	check(game.proof_selection.is_empty(), "No proof is preselected")
	game.choose_suspect("nour")
	check(game._window_title.text == "تم تسجيل الاتهام" and game.session.phase == "investigation", "Any suspect accepted without immediate correction")
	var early: String = game._last_accusation_id
	game._review_accusation(early)
	check(game.session.phase == "closed", "Explicit review produces a decision")
	check(not game.session.accusations()[0].has("outcome"), "Public review does not expose ground truth")
	game._reopen_case()
	check(game.session.phase == "investigation", "Optional reopening returns to free investigation")
	var room: Control = game.room
	check(room._background.texture != null, "Existing background is retained")
	check(room._characters != room._evidence and room._evidence != room._hotspots, "Presentation layers remain independent")
	for clue in game.case_data.evidence:
		await process_frame
		var hotspot: Button = room.find_child("Evidence_" + clue.id, true, false)
		check(hotspot != null, "Data-driven hotspot exists")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = hotspot.get_global_rect().get_center()
		click.pressed = true
		root.push_input(click, true)
		var release := click.duplicate()
		release.pressed = false
		root.push_input(release, true)
		check(game.overlay.visible, "Hotspot receives real pointer input through empty UI")
		check(not game.modal_body.get_children().any(func(item): return item is Label and item.text == clue.name), "Undiscovered evidence name stays hidden")
		check(game.modal_body.get_children().any(func(item): return item is Label and item.text == clue.description), "Correct inspection description opens")
		check(press("أضف إلى دفتر الأدلة"), "Evidence can be collected")
		game.close_modal()
	check(game.collected.size() == 3, "All demonstration clues retained")
	game.collect_evidence("phone")
	check(game.collected.size() == 3, "Duplicates still prevented")
	game.close_modal()
	game.travel_buttons.reception.pressed.emit()
	check(game.session.current_location == "reception" and game.collected.size() == 3, "Travel retains progress")
	game.show_people()
	check(game._card_grid.get_child_count() == mini(4, game.session.available_people().size()), "People use compact paged cards")
	game._start_dialogue("layla")
	check(not game._investigation_chrome.visible, "Arabic dialogue leaves portrait space")
	await capture("res://tests/dialogue-preview.png")
	check(press("تابع الحديث") and press("تابع الحديث"), "Existing testimony remains accessible")
	check(game.witness_heard, "Testimony recorded per statement")
	game.show_questions()
	game._answer_question("cup")
	check(game.session.asked_questions().size() == 1, "Interrogation records the selected question")
	game._confront_question("cup", "coffee")
	check(game.session.discovered_contradictions().size() == 1, "Existing contradiction retained")
	game.show_board()
	game._select_board_evidence("phone")
	game._select_board_evidence("coffee")
	game._submit_board_inference("return")
	check(game.session.confirmed_inferences().size() == 1, "Existing relation retained")
	check(game.session.known_nodes().any(func(item): return item.kind == "report"), "Board includes reports")
	check(game.session.known_nodes().any(func(item): return item.kind == "statement"), "Board includes recorded statements")
	check(game.session.known_nodes().any(func(item): return item.kind == "timeline"), "Board includes timeline")
	await capture("res://.godot/board-preview.png")
	game.show_notebook()
	check(game._card_grid.get_child_count() == game.collected.size(), "Notebook uses visual evidence cards")
	game._show_notebook_entry("e:phone")
	check(game.modal_body.get_child(0) is PanelContainer, "Full evidence details remain accessible")
	game.show_notebook()
	await capture("res://.godot/notebook-preview.png")
	game.show_conclusion()
	game._select_charge_person("samer")
	game._charge_tab("materials")
	for ref in ["e:phone", "e:coffee", "e:letter", "i:samer_return", "c:receipt_time"]:
		game._toggle_proof(ref)
	await capture("res://.godot/accusation-preview.png")
	game.choose_suspect("samer")
	check(game._window_title.text == "تم تسجيل الاتهام", "Even a strong charge receives no immediate correct-name feedback")
	game._review_accusation(game._last_accusation_id)
	check(game._window_title.text == "قرار مراجعة الملف", "Decision follows explicit review")
	game._audit_accusation(game._last_accusation_id)
	check(game.modal_body.get_child(0).text == "إثبات الجريمة", "Optional later audit can reveal proven outcome")
	game._reopen_case()
	var previous: Array[String] = game.session.collected_ids()
	game._load_selected_case("res://tests/fixtures/engine_contract.json")
	check(game.case_data.people.size() == 6 and game.travel_buttons.size() == 3, "UI adapts to a different case shape")
	game.begin_investigation()
	game.show_reports()
	check(game.modal_body.get_children().any(func(item): return item is Label and item.text.contains("سبب الوفاة")), "Forensic fields render for murder cases")
	for person in game.session.available_people():
		game._start_dialogue(person.id)
		check(game.session.active_person == person.id, "All witnesses and suspects are callable")
		game.show_questions()
		check(game._window_title.text.contains(person.name), "Interrogation uses active person rather than a fixed witness")
		game.close_modal()
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, game.size).encloses(game.conclusion_button.get_global_rect()), "Fixed accusation button fits mobile viewport")
		for location in game.case_data.locations:
			game.travel_to(location.id)
			await process_frame
			check(is_equal_approx(room._stage.size.x / room._stage.size.y, 16.0 / 9.0), "Stage preserves 16:9")
			check(Rect2(Vector2.ZERO, room.size).encloses(room._stage.get_rect()), "Stage fits viewport")
			for hotspot in room._hotspots.get_children():
				check(Rect2(Vector2.ZERO, room._stage.size).encloses(hotspot.get_rect()), "Touch target fits stage")
				check(hotspot.size.y >= 56, "Touch target stays large enough")
		game.show_board()
		await process_frame
		var tabs: HBoxContainer = game._modal_tabs
		check(tabs.get_children().all(func(button): return button.size.y < 100), "Board tabs retain readable compact touch targets")
		check(game.modal_body.size.x <= game._modal_scroll.size.x + 1, "Board content wraps instead of overflowing horizontally")
		game.close_modal()
	root.size = Vector2i(1280, 720)
	game._load_selected_case("res://data/cases/midnight_training.json")
	check(game.session.collected_ids() == previous and game.session.phase == "investigation", "Switching back restores the independent case")
	game.travel_to("office")
	await process_frame
	await capture("res://tests/room-preview.png")
	game.show_evidence("phone")
	await capture("res://tests/evidence-preview.png")
	game.travel_to("reception")
	await capture("res://tests/reception-preview.png")
	check(game._accusation_shortcut.visible == game.overlay.visible, "Accusation stays reachable from investigation windows")
	check(not game.case_data.has("truth") and not game.case_data.has("assessment"), "UI receives no private solution")
	game.queue_free()
	await process_frame
	print("PLAYTEST: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
