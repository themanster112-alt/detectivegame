extends "res://tests/test_last_call_outcomes.gd"
func settle() -> void:
	await process_frame
	await process_frame
func press(button: Button) -> void:
	await settle()
	check(button != null, "Expected UI button exists")
	if button == null:
		return
	var event := InputEventScreenTouch.new()
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func action(prefix: String) -> Button:
	for button in game._modal_actions.get_children():
		if button is Button and button.text.begins_with(prefix):
			return button
	return null
func inspect_window() -> void:
	await settle()
	fit()
	var viewport := Rect2(Vector2.ZERO, Vector2(1280,720))
	check(viewport.encloses(game.modal_panel.get_global_rect()), "Window fits viewport")
	check(game.modal_body.size.x <= game._modal_scroll.size.x + 1, "Arabic body wraps within window")
	for button in game._modal_tabs.get_children():
		if button is Button:
			check(viewport.encloses(button.get_global_rect()), "Tab fits: " + button.text)
	for label in game.modal_body.find_children("*", "Label", true, false):
		check(label.size.x <= game.modal_body.size.x + 1, "Arabic label stays within content width")
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	check(game.case_intro.visible, "New player starts at opening")
	while game.case_intro.visible:
		check(not str(game.case_intro._pages[game.case_intro.page]).contains("احتيال"), "Intro does not reveal secret financial motive")
		await press(game.case_intro.next_button)
	check(game.session.current_location == "adam_office", "Final intro button opens crime scene")
	game.show_notebook()
	await inspect_window()
	check(game._card_grid.get_child_count() == 0, "Notebook contains no undiscovered evidence")
	game.close_modal()
	game.show_locations()
	await inspect_window()
	var reception: Button
	for card in game._card_grid.get_children():
		if card.get_meta("item_id", "") == "reception": reception = card
	await press(reception)
	check(game.session.current_location == "reception", "Location card travels by touch")
	game.travel_to("adam_office")
	game.show_inspection("server_logs")
	await inspect_window()
	game.show_evidence("server_logs")
	await press(action("أضف إلى دفتر الأدلة"))
	check(game.session.collected_ids() == ["server_logs"], "Only inspected evidence is discovered")
	await press(action("تحقق من سجلات الخوادم"))
	await inspect_window()
	check(game._window_title.text == "نتيجة التحليل", "Player can request immediate forensic analysis")
	game.show_notebook()
	check(game._card_grid.get_child_count() == 1, "Notebook shows exactly one collected clue")
	game.close_modal()
	complete(game.session)
	check(game.session.collected_ids().size() == 15, "Full investigation remains reachable")
	for person in game.session.available_people():
		game._start_dialogue(person.id)
		await inspect_window()
		await press(action("تابع الحديث"))
		await press(action("الاستجواب"))
		await inspect_window()
		for question in game.session.questions_for(person.id):
			if question.available:
				game._answer_question(question.id)
				await inspect_window()
		game.close_modal()
	for section in ["case", "archive", "career"]:
		game._menu_select(section)
		await inspect_window()
	for method in ["show_locations", "show_people", "show_case_file", "show_reports", "show_assistant", "show_notebook"]:
		game.call(method)
		await inspect_window()
	for section in ["evidence", "statement", "report", "timeline", "inference", "person"]:
		game._board_filter(section)
		await inspect_window()
	for section in ["evidence", "statement"]:
		game._notebook_tab = section
		game.show_notebook()
		await inspect_window()
	game.show_conclusion()
	game._select_charge_person("nadine")
	game._charge_tab("materials")
	await inspect_window()
	game._charge_tab("review")
	await inspect_window()
	check(labels().contains("الحكم يعتمد فقط على المواد") and labels().contains("لن تُضاف الاكتشافات اللاحقة"), "Review explains attached-only judgment before confirmation")
	check(not labels().contains("القاتلة") and not labels().contains("S-04"), "Confirmation does not disclose truth or closing hint")
	await capture("new-player-confirmation")
	await press(action("تسجيل الاتهام"))
	check(game.session.accusations()[-1].status == "pending", "Confirmation records a pending accusation")
	await press(action("طلب مراجعة الملف"))
	check(game.session.phase == "closed", "Player can finish case")
	await inspect_window()
	await capture("new-player-ending")
	game.queue_free()
	await process_frame
	print("LAST CALL NEW PLAYER: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
