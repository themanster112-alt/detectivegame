extends "res://tests/test_last_call_complete.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.case_path = "res://data/cases/last_call.json"
	game.persistence_enabled = false
	game.simplified_ui = true
	root.add_child(game)
	await settle()
	game.begin_investigation()
	check(game.session.can_conclude(), "Accusation remains available before evidence")
	game.show_people()
	check(visible_labels().contains("علينا جمع أدلة أكثر أولًا"), "Early people click shows detective thought")
	check(game._dialogue_portrait.texture == game.HeroPortrait.texture("thinking"), "Gate uses thinking detective portrait")
	await capture("people-before-evidence")
	game.close_modal()
	for id in ["door_events", "desk_inventory", "call_log", "finance_memo", "statue_photo", "server_logs", "mazen_threats"]: game.session.collect_evidence(id)
	game.show_people()
	check(visible_labels().contains("علينا جمع أدلة أكثر أولًا"), "Seven of fifteen clues still display guidance")
	game.close_modal()
	game.session.collect_evidence("layla_file")
	game.show_people()
	check(game._card_grid.get_child_count() == 4, "Eight of fifteen clues unlock all four people")
	await settle()
	await touch(card("nadine"))
	await settle()
	check(game._dialogue_frame.visible and game._modal_actions.get_child_count() == 3, "Photo opens suspect dialogue with three actions")
	for button in game._modal_actions.get_children():
		if not button is Button: continue
		var bounds: Rect2 = button.get_global_rect()
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBox = button.get_theme_stylebox(state)
			check(style.get_content_margin(SIDE_LEFT) == 0 and style.get_content_margin(SIDE_RIGHT) == 0, "All dialogue action states have identical zero text padding")
		var motion := InputEventMouseMotion.new()
		motion.position = bounds.get_center()
		Input.parse_input_event(motion)
		await settle()
		check(button.get_global_rect() == bounds and button.size.x >= button.get_minimum_size().x, "Hover preserves full text and action rectangle")
		check(Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(bounds), "Action fits viewport")
	await capture("dialogue-hover-fixed")
	game.show_questions()
	for option in game._card_grid.get_children():
		check(option.get_theme_stylebox("normal").get_minimum_size() == option.get_theme_stylebox("hover").get_minimum_size(), "Question hover keeps the same reserved space")
	game.queue_free()
	await process_frame
	print("PEOPLE GATE AND HOVER: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
