extends "res://tests/test_last_call_outcomes.gd"
const CaseManager = preload("res://scripts/core/case_manager.gd")
const SEQUENCE := "res://.godot/test-campaign-sequence.json"
const SAVE_FILE := "res://.godot/test-campaign-flow.json"
func make_manager():
	var manager = CaseManager.new()
	manager.story_mode = true
	manager.progression.path = SEQUENCE
	manager.save_path = SAVE_FILE
	return manager
func screenshot(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/campaign-" + name + ".png")
func run() -> void:
	var sequence := {"version":1,"popularity_awards":{"supported":10,"acquitted":-5},"cases":[{"id":"last_call","title":"المكالمة الأخيرة","path":PATH},{"id":"engine_contract","title":"قضية تقنية للاختبار فقط","path":"res://tests/fixtures/engine_contract.json"}]}
	var file := FileAccess.open(SEQUENCE,FileAccess.WRITE)
	file.store_string(JSON.stringify(sequence))
	file.close()
	for spec in [["nadine",false,"acquitted",-5],["nadine",true,"supported",10],["mazen",true,"acquitted",-5]]:
		DirAccess.remove_absolute(SAVE_FILE)
		var manager = make_manager()
		check(manager.load_progress() and manager.open_case(PATH), "First case starts in sequence")
		check(not manager.open_case("res://tests/fixtures/engine_contract.json"), "Manager rejects next case before prior completion")
		check(manager.progression.score(manager.campaign) == 0, "Popularity starts at zero")
		manager.session.begin_investigation()
		var refs: Array = []
		if spec[1]:
			complete(manager.session)
			manager.session.link_nodes(["e:locker_find","r:weapon_analysis"],"compatible")
			if spec[0] == "nadine":
				refs = ["e:door_events","q:nadine_exit","e:locker_find","r:weapon_analysis","i:weapon_link","e:locker_access","r:fiber_analysis","q:nadine_bag","e:finance_memo","r:finance_analysis","q:nadine_finance"]
			else:
				refs = ["e:mazen_threats","q:mazen_threat_admission","s:mazen_dispute","q:mazen_business","q:mazen_threat_denial","c:mazen_threat_conflict","e:call_log","q:mazen_missed"]
		var charge: Dictionary = manager.session.submit_accusation(spec[0],refs)
		var result: Dictionary = manager.finish_story_case(charge.id)
		check(result.get("status") == "completed" and result.verdict == spec[2], "Correct name needs sufficient evidence; false charges are acquitted")
		check(manager.progression.score(manager.campaign) == spec[3], "Popularity changes according to configured outcome")
		check(manager.session.phase == "closed", "One confirmation can complete the case")
		check(not str(result).contains("truth") and not result.has("explanation"), "Wrong choice never discloses actual culprit")
		check(manager.progression.next_case(manager.campaign,"last_call").unlocked, "Any completed outcome unlocks next case")
		manager.finish_story_case(charge.id)
		check(manager.progression.score(manager.campaign) == spec[3], "Repeated completion cannot farm or repeat popularity")
		var restored = make_manager()
		check(restored.load_progress() and restored.open_case(PATH), "Actual disk reload restores completed case")
		check(restored.progression.score(restored.campaign) == spec[3] and restored.story_result().verdict == spec[2], "Reload preserves popularity and public verdict exactly once")
		check(restored.open_case("res://tests/fixtures/engine_contract.json"), "Next real test case opens even after acquittal")
		check(restored.progression.score(restored.campaign) == spec[3], "Next case inherits lower or higher popularity")
	DirAccess.remove_absolute(SAVE_FILE)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	game.simplified_ui = true
	game.show_title_action = true
	root.add_child(game)
	await process_frame
	game.begin_investigation()
	complete(game.session)
	game.show_notebook()
	check(not game._modal_tabs.visible and game._card_grid.get_child_count() == 15, "Notebook is a single scrolling evidence view without tabs or pages")
	check(not game._modal_actions.get_children().any(func(control): return control is Button and control.text in ["التالي","السابق"]), "No nested evidence pagination")
	await screenshot("evidence")
	game.show_board()
	check(game._modal_tabs.get_child_count() == 3, "Board has only evidence, information and deductions")
	await screenshot("board")
	game.show_questions()
	check(not game._modal_actions.get_children().any(func(control): return control is Button and control.text in ["التالي","السابق"]), "Interrogation options use scrolling rather than pages")
	game.show_case_menu()
	check(not game._modal_tabs.visible, "Case overview drops career/archive management tabs")
	game.proof_selection.clear()
	game.choose_suspect("mazen")
	check(game._window_title.text == "نتيجة القضية" and labels().contains("تبرئة") and labels().contains("ناقص 5"), "One accusation opens readable acquittal and popularity result")
	check(not labels().contains("نادين") and not labels().contains("القاتلة"), "Acquittal does not spoil real culprit")
	check(labels().contains("قيد التجهيز"), "Second story slot is honestly marked as not authored yet")
	await screenshot("acquittal")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(SEQUENCE)
	DirAccess.remove_absolute(SAVE_FILE)
	print("CAMPAIGN FLOW: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
