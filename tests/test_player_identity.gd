extends SceneTree
const Title = preload("res://scripts/ui/title_screen.gd")
const Profile = preload("res://scripts/core/player_profile.gd")
const Sync = preload("res://scripts/core/investigation_sync_contract.gd")
const PROFILE_PATH := "res://.godot/identity-test-player.json"
const SAVE_PATH := "res://.godot/identity-test-cases.json"
var checks := 0
var failures := 0
var title: Control
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
func create_title() -> void:
	title = Title.new()
	title.profile_path = PROFILE_PATH
	title.save_path = SAVE_PATH
	root.add_child(title)
	await settle()
func press(button: Button) -> void:
	if is_instance_valid(title.intro) and button == title.intro.next_button:
		for step in range(30):
			if button.visible: break
			title.intro._process(10.0)
	await settle()
	check(button != null, "Touch button exists")
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
func clear_title() -> void:
	root.remove_child(title)
	title.queue_free()
	await settle()
func visible_text(node: Node) -> String:
	var result := ""
	for label in node.find_children("*", "Label", true, false):
		result += label.text + "\n"
	return result
func fit() -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(1280,720))
	check(screen.encloses(title.panel.get_global_rect()), "Title panel fits 1280x720")
	for button in title.menu_buttons.values():
		check(button.size.y >= 48 and screen.encloses(button.get_global_rect()), "Menu touch target fits: " + button.text)
func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/identity-" + name + ".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/title_screen.tscn", "Project boots at title menu")
	for path in [PROFILE_PATH, SAVE_PATH]: DirAccess.remove_absolute(path)
	check(Profile.clean_name("  ريم  ") == "ريم", "Arabic name trims whitespace")
	check(Profile.clean_name("\n\t").is_empty(), "Blank/control name rejected")
	check(Profile.clean_name("{player_name}") == "player_name", "Name cannot inject placeholder")
	check(Profile.ROLES == ["lead_detective", "assistant_detective"], "Future role metadata defined without privileges")
	await create_title()
	check(title.menu_buttons.size() == 4 and title.menu_buttons["متابعة"].disabled, "Four main menu actions; no empty continue")
	fit()
	await capture("menu")
	await press(title.menu_buttons["لعبة جديدة"])
	await press(title.menu_buttons["لعب فردي"])
	title.name_input.text = "   "
	title.submit_identity()
	check(is_instance_valid(title.name_input) and not title.message.text.is_empty(), "Empty name stays on form")
	title.name_input.text = "  ريم النجار  "
	await capture("name")
	title.submit_identity()
	await settle()
	check(title.profile.data.player_name == "ريم النجار" and title.profile.data.role == "lead_detective", "Named single-player identity saved as lead")
	check(title.intro._pages.size() == 4 and title.intro.visible, "Four-scene story starts before case")
	check(visible_text(title.intro).contains("ريم النجار") and not visible_text(title.intro).contains("ريان"), "Intro renders selected name")
	check(not str(title._story).contains("مشروع الصمت") and not str(title._story).contains("private_lore"), "Secret lore excluded from presentation data")
	await capture("intro")
	await press(title.intro.next_button)
	check(title.profile.data.intro_page == 2 and visible_text(title.intro).contains("يزن"), "Interactive scene advances and saves page")
	await clear_title()
	await create_title()
	await press(title.menu_buttons["متابعة"])
	check(title.intro.page == 2, "Interrupted phone conversation resumes its saved phase")
	await press(title.intro.skip_button)
	check(title.profile.data.intro_seen and is_instance_valid(title.game), "Skip records intro completion and opens case")
	check(not title.game.case_intro.visible and title.game.session.phase == "investigation" and title.game.case_data.title == "المكالمة الأخيرة", "First case opens directly; reports remain optional")
	check(title.game.player_name == "ريم النجار", "Identity reaches investigation presentation")
	var personalized: Label = title.game._label("مرحبًا {player_name}")
	check(personalized.text == "مرحبًا ريم النجار", "Dialogue presentation resolves player token without changing case data")
	personalized.free()
	title.game.begin_investigation()
	title.game.session.collect_evidence("door_events")
	var snapshot: Dictionary = Sync.snapshot(title.game.session, title.profile.data.player_id, 1)
	check(snapshot.protocol_version == 1 and snapshot.state.collected == ["door_events"], "Future sync envelope contains versioned progress")
	check(not snapshot.state.has("truth") and not snapshot.state.has("assessment"), "Sync contract excludes private solution")
	var assistant: Dictionary = Sync.snapshot(title.game.session, "future-second-player", 1, "assistant_detective")
	check(assistant.state == snapshot.state and assistant.role == "assistant_detective", "Role metadata does not restrict investigation access")
	check(title.game.session.case_snapshot().assistant.name.contains("يزن"), "Yazan remains an independent story character")
	title.return_to_menu()
	await settle()
	fit()
	await clear_title()
	await create_title()
	await press(title.menu_buttons["متابعة"])
	check(not is_instance_valid(title.intro) and is_instance_valid(title.game), "Continue never replays completed story")
	check(title.game.session.has_evidence("door_events") and title.game.player_name == "ريم النجار", "Name and investigation progress restore together")
	title.return_to_menu()
	title.show_settings()
	await settle()
	fit()
	await press(title.menu_buttons["حفظ وعودة"])
	await press(title.menu_buttons["القضايا"])
	check(title.menu_buttons.has("المكالمة الأخيرة"), "Case list includes first case")
	await press(title.menu_buttons["عودة"])
	await press(title.menu_buttons["لعبة جديدة"])
	await press(title.menu_buttons["لعب فردي"])
	check(visible_text(title.body).contains("سيستبدل"), "New game explains replacing old investigation")
	title.name_input.text = "سليم"
	title.submit_identity()
	await settle()
	await press(title.intro.next_button)
	for step in range(30): title.intro._process(10.0)
	check(visible_text(title.intro).contains("سليم"), "Narrative uses the new identity")
	await press(title.intro.next_button)
	check(title.profile.data.intro_seen and title.game.session.collected_ids().is_empty(), "Full story route starts a fresh case")
	await clear_title()
	var invalid := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	invalid.store_string("{broken")
	invalid.close()
	var profile := Profile.new()
	profile.path = PROFILE_PATH
	check(not profile.load_progress() and not profile.new_player("اسم"), "Corrupt identity save is not overwritten")
	check(FileAccess.get_file_as_string(PROFILE_PATH) == "{broken", "Corrupted file retained")
	for path in [PROFILE_PATH, SAVE_PATH]: DirAccess.remove_absolute(path)
	print("PLAYER IDENTITY: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
