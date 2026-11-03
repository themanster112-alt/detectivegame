extends SceneTree
## Tiny format fixtures are test data only, never game artwork or catalog defaults.
const Catalog = preload("res://scripts/world/visual_catalog.gd")
const Session = preload("res://scripts/core/investigation_session.gd")
const FIXTURES := "res://.godot/asset-test-fixtures/"
var checks := 0
var failures := 0
var game: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(FIXTURES)
	var bitmap := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color(0.3, 0.4, 0.5, 0.5))
	check(bitmap.save_png(FIXTURES + "neutral.png") == OK, "PNG test fixture saved")
	bitmap.fill(Color(0.6, 0.4, 0.3, 0.5))
	check(bitmap.save_webp(FIXTURES + "concerned.webp") == OK, "Lossless WebP test fixture saved")
	var catalog := Catalog.new()
	catalog.background_files = {"office": FIXTURES + "neutral", "reception": FIXTURES + "concerned"}
	catalog.character_files = {"layla:neutral": FIXTURES + "neutral", "layla:concerned": FIXTURES + "concerned"}
	catalog.evidence_files = {"phone": FIXTURES + "neutral"}
	catalog.ui_files = {"notebook": FIXTURES + "concerned"}
	catalog.dialogue_expressions = preload("res://assets/ui/noir_visual_catalog.tres").dialogue_expressions.duplicate()
	var neutral: Texture2D = catalog.expression_texture("layla", "neutral")
	var concerned: Texture2D = catalog.expression_texture("layla", "concerned")
	check(neutral != null and neutral.get_size() == Vector2(8, 12), "PNG source loads automatically")
	check(concerned != null and concerned.get_size() == Vector2(8, 12), "WebP source loads automatically")
	check(catalog.character_texture("layla", "defensive") == neutral, "Missing expression falls back to neutral")
	check(catalog.character_texture("unknown") == null, "Missing character safely returns null")
	check(catalog.evidence_texture("missing") == null, "Missing evidence safely returns null")
	check(catalog.ui_texture("notebook") == concerned, "UI art uses the same file resolver")
	check(catalog.background_texture("reception") == concerned, "WebP background resolves")
	catalog.backgrounds["office"] = concerned
	check(catalog.background_texture("office") == concerned, "Explicit Inspector texture takes precedence")
	catalog.backgrounds.clear()
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	game.case_path = "res://data/cases/midnight_training.json"
	root.size = Vector2i(1280, 720)
	root.add_child(game)
	await process_frame
	game.begin_investigation()
	var snapshot: Dictionary = game.session._case.duplicate(true)
	var room: Control = game.room
	room.visual_catalog = catalog
	room.display_location(game.session.location_data(), game.case_data, game.collected)
	check(room._background.texture == neutral, "Location view uses catalog image")
	var card := preload("res://scenes/ui/evidence_card.tscn").instantiate()
	root.add_child(card)
	card.display(game.session.evidence_data("phone"), catalog)
	check(card.find_child("EvidenceArtwork", true, false).texture == neutral, "Evidence card displays the catalog image")
	var missing_card := preload("res://scenes/ui/evidence_card.tscn").instantiate()
	root.add_child(missing_card)
	missing_card.display(game.session.evidence_data("letter"), catalog)
	check(missing_card.find_child("EvidencePlaceholder", true, false) == null, "Missing evidence art does not create placeholder text")
	game.collect_evidence("phone")
	game.collect_evidence("coffee")
	game.show_board()
	check(game.modal_body.find_children("*", "TextureRect", true, false).any(func(item): return item.texture == neutral), "Board displays evidence artwork in visual cards")
	game.show_notebook()
	game._show_notebook_entry("e:phone")
	check(game.modal_body.find_child("EvidenceArtwork", true, false).texture == neutral, "Notebook shares catalog art")
	game.close_modal()
	game.travel_to("reception")
	check(room._background.texture == concerned, "Travel replaces backdrop")
	check(room._previous_background.visible and room._previous_background.texture == neutral, "Scene change crossfades previous backdrop")
	game._start_dialogue()
	await process_frame
	check(not game._investigation_chrome.visible and game.modal_panel.visible, "Dialogue reserves the screen for portrait and bottom Arabic panel")
	check(not room._hotspots.visible, "Dialogue does not leave world hotspots active")
	check(room.current_expression == "neutral" and room._portrait.texture == neutral, "Dialogue starts with neutral portrait")
	check(absf(game.modal_panel.get_global_rect().get_center().y - 360) < 2, "Dialogue stays centered on 1280x720")
	check(game._dialogue_frame.get_global_rect().encloses(game._dialogue_portrait.get_global_rect()), "Portrait remains inside dialogue frame")
	var framing: Rect2 = room._portrait.get_rect()
	game.dialogue_index = 1
	game._show_dialogue()
	check(room.current_expression == "concerned" and room._portrait.texture == concerned, "Dialogue cue switches expressions")
	check(room._portrait.get_rect() == framing, "Expressions preserve portrait alignment")
	check(room._previous_expression != null, "Expression change starts a crossfade")
	room.set_character_expression("layla", "defensive")
	check(room._portrait.texture == neutral and room._portrait.get_node("PlaceholderLabel").visible, "Missing pose uses neutral with explicit temporary label")
	room.set_character_expression("layla", "concerned")
	await create_timer(0.3).timeout
	check(not room._previous_background.visible, "Background transition completes")
	check(not is_instance_valid(room._previous_expression), "Old expression is released after transition")
	check(not room._portrait.get_node("PlaceholderLabel").visible, "Real pose hides temporary label")
	check(game.session._case == snapshot and game.session.collected_ids().size() == 2 and not game.witness_heard, "Presentation cannot change case or testimony progress")
	game.close_modal()
	check(game._investigation_chrome.visible and room._hotspots.visible, "Closing restores investigation UI")
	check(room.current_expression == "neutral", "Closing dialogue restores neutral expression")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 800)]:
		root.size = dimensions
		await process_frame
		room.set_dialogue_mode(true)
		await process_frame
		check(Rect2(Vector2.ZERO, room._stage.size).encloses(room._portrait.get_rect()), "Portrait framing fits stage at " + str(dimensions))
		check(is_equal_approx(room._stage.size.x / room._stage.size.y, 16.0 / 9.0), "Stage retains 16:9")
	game.travel_to("office")
	check(room._portrait == null and room._characters.get_child_count() == 0, "Travel removes previous character")
	check(not room.set_character_expression("layla", "neutral"), "No ghost character in another location")
	var missing_catalog := Catalog.new()
	missing_catalog.character_files = {}
	missing_catalog.background_files = {}
	missing_catalog.backgrounds = preload("res://assets/ui/noir_visual_catalog.tres").backgrounds.duplicate()
	room.visual_catalog = missing_catalog
	game.travel_to("reception")
	check(room._background_notice.visible, "Temporary background stays explicitly labeled")
	await process_frame
	var placeholder := room._portrait.get_node_or_null("PlaceholderLabel") as Label
	if placeholder == null:
		quit(1)
		return
	check(not placeholder.get_global_rect().intersects(room._background_notice.get_global_rect()), "Character and background notices occupy separate regions")
	game._start_dialogue()
	check(room._background_notice.visible and room._background_notice.is_visible_in_tree(), "Background placeholder label remains visible in dialogue")
	check(room._portrait.get_node("PlaceholderLabel").vertical_alignment == VERTICAL_ALIGNMENT_TOP, "Character label remains above bottom dialogue panel")
	card.queue_free()
	missing_card.queue_free()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(FIXTURES + "neutral.png")
	DirAccess.remove_absolute(FIXTURES + "concerned.webp")
	DirAccess.remove_absolute(FIXTURES)
	print("VISUAL ASSETS: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
