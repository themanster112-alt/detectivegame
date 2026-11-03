extends SceneTree
var game: Control
var failures := 0
var checks := 0
const SAVE := "res://.godot/guidance-test.json"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
func start_game() -> void:
	game = load("res://main.tscn").instantiate()
	game.case_path = "res://data/cases/last_call.json"
	game.save_path = SAVE
	game.simplified_ui = true
	root.add_child(game)
	await settle()
	if game.session.phase == "briefing": game.begin_investigation()
	await settle()
func capture(file: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/guidance-" + file + ".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.remove_absolute(SAVE)
	await start_game()
	check(game._exploration_hint.visible, "First exploration explains touching scene objects")
	check(not game.notebook_button.text.contains("●"), "Undiscovered evidence does not create notebook notification")
	await capture("exploration")
	game.show_evidence("desk_inventory")
	check(not game._exploration_hint.visible, "First inspection dismisses tutorial")
	check(game.session.collect_evidence("desk_inventory"), "Reachable clue can be collected")
	check(game.notebook_button.text.contains("●"), "Collected clue marks notebook as new")
	var state: Dictionary = game.session.export_state().duplicate(true)
	game._show_notebook_entry("e:desk_inventory")
	check(not game.notebook_button.text.contains("●"), "Reading clue clears notebook badge immediately")
	check(game.session.export_state() == state, "Reading does not change investigation state")
	game._board_tab = "information"
	game.show_board()
	check(game._modal_tabs.get_child(1).text.contains("●"), "New information is marked on board tab")
	for node in game.session.known_nodes(): game._mark_read(node.ref)
	game.show_board()
	check(not game._modal_tabs.get_child(1).text.contains("●") and not game._board_button.text.contains("●"), "Reading all information clears both board indicators")
	game._start_dialogue("nadine")
	game.show_questions()
	var fresh: Button = game.find_child("DialogueOption_nadine_locker", true, false)
	check(fresh != null and fresh.text.contains("متاح الآن") and not fresh.disabled, "Evidence-unlocked unasked question is highlighted")
	var locked: Button = game.find_child("DialogueOption_nadine_finance", true, false)
	check(locked != null and locked.disabled and not locked.text.contains("المالي"), "Locked questions conceal their real labels")
	await capture("questions-new")
	game._answer_question("nadine_locker")
	game.show_questions()
	fresh = game.find_child("DialogueOption_nadine_locker", true, false)
	check(fresh.text.contains("سُئل سابقًا") and not fresh.text.contains("متاح الآن") and not fresh.disabled, "Asked question is marked but remains replayable")
	await capture("questions-asked")
	game.manager.save_now()
	game.queue_free()
	await settle()
	await start_game()
	check(not game._exploration_hint.visible, "Tutorial completion survives reload")
	check(not game._is_unread({"ref":"e:desk_inventory", "text":game.session.evidence_data("desk_inventory").description}), "Reading state survives reload")
	game._start_dialogue("nadine")
	game.show_questions()
	fresh = game.find_child("DialogueOption_nadine_locker", true, false)
	check(fresh.text.contains("سُئل سابقًا"), "Asked status survives reload")
	game.queue_free()
	await settle()
	DirAccess.remove_absolute(SAVE)
	print("DISCOVERY GUIDANCE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
