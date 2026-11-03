extends SceneTree
var game: Control
var checks := 0
var failures := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func touch(control: Control) -> void:
	if control == null:
		check(false, "Required touch target exists")
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame
func action(text: String) -> Button:
	for control in game._modal_actions.get_children():
		if control is Button and control.text.begins_with(text):
			return control
	return null
func tab(text: String) -> Button:
	for control in game._modal_tabs.get_children():
		if control is Button and control.text == text:
			return control
	return null
func card(id: String) -> Button:
	for control in game._card_grid.get_children():
		if control.get_meta("item_id", "") == id:
			return control
	return null
func settle() -> void:
	await process_frame
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/ux-" + name + ".png")
func fit_window(name: String) -> void:
	var viewport := Rect2(Vector2.ZERO, root.size)
	check(viewport.encloses(game.modal_panel.get_global_rect()), name + " window stays in viewport")
	check(game.modal_body.size.x <= game._modal_scroll.size.x + 1, name + " content wraps")
	check(game._window_title.is_visible_in_tree(), name + " has a fixed visible heading")
	for button in game._modal_actions.get_children():
		if button is Button:
			check(button.size.y >= 48 and viewport.encloses(button.get_global_rect()), name + " fixed actions fit touch viewport")
	if is_instance_valid(game._card_grid) and game._card_grid.is_inside_tree():
		check(game._card_grid.get_child_count() <= 4, name + " shows at most four cards")
		for button in game._card_grid.get_children():
			check(button.get_global_rect().size.y >= 56, name + " card is a touch target")
			for label in button.find_children("*", "Label", true, false):
				check(label.size.y >= game.theme.default_font.get_height(label.get_theme_font_size("font_size")), name + " Arabic card line is not clipped vertically")

func run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	game.case_path = "res://data/cases/midnight_training.json"
	root.add_child(game)
	await settle()
	check(game.case_intro.visible and not game.overlay.visible, "Cinematic opening is separate from tool windows")
	check(game.case_intro._pages[0].kind == "opening", "Opening begins with case title and summary")
	for page in game.case_intro._pages:
		var content: String = str(page)
		check(not content.contains("سمعة") and not content.contains("أحكام سابقة"), "Intro does not include career or judgment management")
	check(game.case_intro._content.get_global_rect().position.x > 500, "Intro text stays on the dark right side under RTL")
	await touch(game.case_intro.next_button)
	check(game.case_intro.page == 1, "Real touch advances exactly one intro page")
	await touch(game.case_intro.back_button)
	check(game.case_intro.page == 0, "Real touch returns to previous intro page")
	await touch(game.case_intro.skip_button)
	check(game.session.phase == "investigation" and not game.case_intro.visible, "Direct crime-scene action works by touch")
	check(game._investigation_chrome.visible and game.room._background.texture != null, "Crime scene opens with existing artwork")
	check(game.conclusion_button.text == "توجيه اتهام" and not game.conclusion_button.disabled, "Persistent accusation action is concise and available")
	var initial: Dictionary = game.session.export_state()
	game.show_case_menu()
	await settle()
	check(game._window_title.text == "ملف التحقيق" and game._modal_tabs.get_child_count() == 3, "Case menu becomes a tabbed story window")
	check(game.modal_body.find_children("*", "Button", true, false).is_empty(), "Case overview is not a stack of management buttons")
	fit_window("case overview")
	await capture("case-overview")
	await touch(tab("الأرشيف"))
	check(game._menu_tab == "archive", "Archive tab works by touch")
	await settle()
	fit_window("archive")
	check(action("الاتهامات") != null and action("حفظ") != null, "Existing history and manual save remain accessible")
	await touch(tab("المحقق"))
	check(game._menu_tab == "career", "Career information lives in its optional tab")
	await settle()
	fit_window("career")
	game.show_reports()
	await settle()
	fit_window("reports")
	game.show_assistant()
	await settle()
	fit_window("assistant")
	game.show_locations()
	await settle()
	fit_window("locations")
	check(game.session.export_state() == initial, "Browsing informational screens does not change investigation state")
	game.close_modal()
	for id in ["phone", "coffee", "letter"]:
		game.session.collect_evidence(id)
	game.show_notebook()
	await settle()
	fit_window("notebook")
	await touch(card("e:phone"))
	check(game._window_title.text == "دليل مسجل", "Touching evidence opens full detail")
	check(game.modal_body.find_child("EvidencePlaceholder", true, false) == null, "Evidence details remain readable without temporary-art labels")
	await settle()
	fit_window("evidence detail")
	await touch(action("العودة إلى الدفتر"))
	check(game._window_title.text == "دفتر التحقيق", "Evidence detail returns to notebook")
	game.show_people()
	await settle()
	fit_window("people")
	await touch(card("layla"))
	check(game._active_person_id == "layla" and game.session.active_person == "layla", "Portrait card calls its character")
	check(not game._investigation_chrome.visible and game.room._portrait != null, "Dialogue highlights portrait over existing background")
	check(game._accusation_shortcut.visible, "Accusation remains accessible during dialogue")
	await settle()
	fit_window("dialogue")
	game.show_questions()
	await settle()
	fit_window("questions")
	game._answer_question("cup")
	await settle()
	fit_window("answer")
	await touch(action("مناقشة دليل"))
	check(game._window_title.text == "ناقش القول بدليل", "Evidence confrontation uses a compact picker")
	await settle()
	fit_window("confrontation picker")
	await touch(card("coffee"))
	check(game.session.discovered_contradictions().size() == 1, "Compact confrontation retains original gameplay")
	game.show_board()
	await settle()
	fit_window("board")
	await touch(card("e:phone"))
	await touch(card("e:coffee"))
	check(game.board_selection.size() == 2, "Board cards retain selected references")
	await touch(action("ربط المحدد"))
	check(game._window_title.text == "تفسير الربط", "Link meaning opens a focused decision window")
	check(action("تدعم عودة") != null, "Existing case-defined relation choices retained")
	await touch(action("تدعم عودة"))
	check(game.session.confirmed_inferences().size() == 1, "Linking still uses the investigation engine")
	for label in ["الأقوال", "التقارير", "الزمن", "الاستنتاجات", "الأشخاص", "الأدلة"]:
		await touch(tab(label))
		await settle()
		fit_window("board " + label)
	await capture("board-cards")
	await touch(game._accusation_shortcut)
	check(game._window_title.text == "توجيه اتهام", "Fixed shortcut opens accusation from another window")
	await settle()
	await touch(card("samer"))
	check(game._selected_suspect == "samer" and game.session.accusations().is_empty(), "Selecting a person does not submit a charge")
	await touch(action("اختيار المواد"))
	check(game._accusation_tab == "materials", "Accusation materials have their own tab")
	await settle()
	fit_window("charge materials")
	var before_page: int = game._pages.get("charge_materials", 0)
	check(action("التالي") != null, "Long material collections are paged")
	await touch(action("التالي"))
	check(game._pages.charge_materials == before_page + 1, "Material next-page button works")
	await touch(action("مراجعة"))
	check(game._accusation_tab == "review" and game.proof_selection.is_empty(), "Charge review permits a partial file without evidence")
	await settle()
	fit_window("charge review")
	await capture("charge-review")
	await touch(action("تسجيل الاتهام"))
	check(game.session.accusations().size() == 1 and game.session.accusations()[0].status == "pending", "Explicit confirmation submits exactly one pending accusation")
	check(game._window_title.text == "تم تسجيل الاتهام", "No immediate true or false feedback was added")
	game.show_accusations()
	await settle()
	fit_window("judgment archive")
	game.close_modal()
	game._load_selected_case("res://tests/fixtures/engine_contract.json")
	check(game.case_intro.visible and game.case_intro._pages.any(func(page): return page.kind == "report" and page.eyebrow == "الطب الشرعي"), "Murder intro includes existing forensic report")
	var last: int = game.case_intro._pages.size() - 1
	while game.case_intro.page < last:
		game.case_intro.advance()
	check(game.case_intro.next_button.text == "إلى موقع الجريمة", "Final next button leads naturally to crime scene")
	await touch(game.case_intro.next_button)
	check(game.session.phase == "investigation", "Final intro action starts another case")
	game.show_people()
	await settle()
	check(game._card_grid.get_child_count() == 4 and action("التالي") != null, "Variable character count stays compact")
	await touch(action("التالي"))
	check(game._card_grid.get_child_count() == 2, "Remaining characters are reachable on next page")
	await capture("people-page")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = dimensions
		await settle()
		game.show_case_menu()
		await settle()
		fit_window("resized menu " + str(dimensions))
		game.show_board()
		await settle()
		fit_window("resized board " + str(dimensions))
		game.close_modal()
		check(Rect2(Vector2.ZERO, root.size).encloses(game.conclusion_button.get_global_rect()), "HUD accusation fits resized landscape viewport")
	game.queue_free()
	await process_frame
	print("UX NAVIGATION: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
