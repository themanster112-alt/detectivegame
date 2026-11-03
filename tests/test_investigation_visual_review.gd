extends "res://tests/test_last_call_outcomes.gd"
var displayed: Array = []
func settle() -> void:
	await process_frame
	await process_frame
func touch(button: Control) -> void:
	await settle()
	check(button != null, "Required visual interaction target exists")
	if button == null: return
	var event := InputEventScreenTouch.new()
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func named_button(text: String) -> Button:
	for control in game.find_children("*", "Button", true, false):
		if control.text == text and control.is_visible_in_tree(): return control
	return null
func card(id: String) -> Button:
	for control in game._card_grid.get_children():
		if control.get_meta("item_id", "") == id: return control
	return null
func art() -> Array:
	return game.modal_body.find_children("*", "TextureRect", true, false).filter(func(node): return node.texture != null)
func shot(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/visual-fix-" + name + ".png")
func check_art(id: String, filename: String) -> void:
	check(art().size() == 1, "One clear evidence image on inspection: " + id)
	if art().size() == 1:
		check(art()[0].texture == game.room.visual_catalog.evidence_texture(id), "Actual assigned PNG rendered: " + filename)
		check(art()[0].size.y >= 220 and art()[0].stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Evidence image is readable and proportional")
		check(art()[0].is_visible_in_tree() and game._modal_scroll.get_global_rect().grow(1).encloses(art()[0].get_global_rect()), "Whole evidence image is really visible inside inspection viewport")
		if filename not in displayed: displayed.append(filename)
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	game.begin_investigation()
	await touch(game.travel_buttons["reception"])
	check(game.session.current_location == "reception", "Opened reception using real navigation controls")
	check(game.room._portrait == null or not game.room._portrait.is_visible_in_tree(), "Exploration never shows floating half-body portrait")
	for target in game.room._hotspots.get_children():
		if target.has_meta("person_id"):
			check(target.find_children("*", "Label", true, false).is_empty(), "Talk target has no permanent caption")
		if target.has_meta("inspection_id"):
			check(target.find_children("*", "Label", true, false).is_empty(), "Inspection target rests invisible")
	await shot("reception")
	game.show_people()
	await settle()
	await touch(card("layla"))
	check(game.session.active_person == "layla" and game._window_title.text == "ليلى", "Reception interaction opens Layla dialogue")
	check(not game.room._hotspots.visible and not game._investigation_chrome.visible, "Dialogue hides exploration controls")
	check(game._dialogue_portrait.is_visible_in_tree() and not game._hero_portrait.is_visible_in_tree(), "Layla alone is the speaking portrait")
	check(absf(game.modal_panel.get_global_rect().get_center().y - 360) < 2, "Dialogue box stays centered")
	check(game.modal_panel.get_global_rect().encloses(game._dialogue_frame.get_global_rect()), "Portrait fits inside dialogue box")
	await shot("layla-dialogue")
	await touch(named_button("الاستجواب"))
	check(game._dialogue_frame.is_visible_in_tree() and not game._hero_portrait.visible, "Question selection stays inside dialogue and does not show hero continuously")
	check(not game.room._characters.visible, "Only current speaker portrait is presented")
	await shot("hero-speaking")
	await touch(game._close_button)
	check(not game._hero_portrait.visible and not game.room._portrait.is_visible_in_tree(), "Returning to exploration clears both portraits")
	await touch(game.room._hotspots.find_child("Evidence_security_log", false, false))
	check(art().size() == 1 and not game.session.has_evidence("security_log"), "Image is visible on inspection before collection")
	await touch(named_button("أضف إلى دفتر الأدلة"))
	check_art("security_log", "evidence_7_bag_inspection.png")
	await shot("evidence_7_bag_inspection")
	await touch(named_button("دفتر الأدلة"))
	check(art().size() == 1, "Notebook visually contains the newly discovered image")
	await shot("notebook")
	await touch(card("e:security_log"))
	check_art("security_log", "evidence_7_bag_inspection.png")
	await shot("notebook-detail")
	game.close_modal()
	complete(game.session)
	# Open real scene inspection controls for each other assigned evidence image.
	for spec in [["locker_find","reception","locker","evidence_1_statue.png"],["call_log","adam_office","office_terminal","evidence_2_phone.png"],["finance_memo","adam_office","office_files","evidence_3_financial_file.png"],["statue_photo","adam_office","inventory","evidence_5_office_photo.png"],["bag_fibers","reception","samples","evidence_6_fibers.png"],["mazen_threats","adam_office","office_terminal","evidence_7_threat_note.png"],["locker_access","reception","security_records","evidence_10_cabinet_log.png"],["server_logs","adam_office","office_terminal","evidence_12_server_camera_logs.png"],["layla_file","adam_office","office_files","evidence_14_brother_complaint.png"],["fraud_ledger","adam_office","office_files","evidence_15_transfer_ledger.png"]]:
		game.travel_to(spec[1])
		await settle()
		await touch(game.room._hotspots.find_child("Evidence_" + spec[0], false, false))
		check_art(spec[0], spec[3])
		await shot(spec[3].trim_suffix(".png"))
		game.close_modal()
	await touch(named_button("القضية"))
	await touch(named_button("التقارير"))
	check_art("forensic_initial", "evidence_9_forensic_report.png")
	for control in game._modal_actions.get_children():
		if control is Button: check(control.size.y <= 64, "Report navigation keeps single-row touch buttons without stretched counter")
	await shot("evidence_9_forensic_report")
	check(displayed.size() == 12, "All eleven present mapped images plus the forensic report are displayed")
	game.close_modal()
	game._start_dialogue("layla")
	game._answer_question("layla_call_question")
	game._confront_question("layla_call_question", "audio_archive")
	check(game._dialogue_portrait.texture == game.HeroPortrait.texture("accusing") and not game.room._characters.visible, "Confrontation uses accusing hero inside the speaker frame")
	await shot("hero-accusing")
	game.show_board()
	check(game._hero_portrait.is_visible_in_tree() and game._hero_portrait.size.x >= 250, "Deduction uses readable thinking portrait")
	await shot("hero-thinking")
	game.close_modal()
	game.queue_free()
	await process_frame
	print("ACTUALLY DISPLAYED: ", displayed)
	print("INVESTIGATION VISUAL REVIEW: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
