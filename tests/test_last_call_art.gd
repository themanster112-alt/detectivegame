extends "res://tests/test_last_call_outcomes.gd"
const Catalog = preload("res://assets/ui/last_call_visual_catalog.tres")
func textures() -> Array:
	return game.modal_body.find_children("*", "TextureRect", true, false).filter(func(node): return node.texture != null)
func art_capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/last-call-art-" + name + ".png")
func run() -> void:
	for person in ["nadine", "layla", "samer", "mazen"]:
		for pose in ["neutral", "concerned", "defensive"]:
			check(Catalog.expression_texture(person, pose) != null, "Actual portrait loads: " + person + ":" + pose)
	check(Catalog.character_texture("yazan") == null, "No invented Yazan picture")
	for id in Catalog.evidence:
		check(Catalog.evidence_texture(id) != null, "All mapped evidence/report art loads: " + id)
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame
	game.begin_investigation()
	game.show_notebook()
	check(textures().is_empty(), "Notebook has no undiscovered images")
	game.show_evidence("call_log")
	check(textures().size() == 1 and not game.session.has_evidence("call_log"), "Inspection previews image without collecting")
	game.collect_evidence("call_log")
	check(textures().size() == 1 and labels().contains("الجهاز مفقود"), "Discovered call log shows explicitly illustrative missing phone")
	await art_capture("discovery")
	check(game._known_art("e:locker_find") == null and game._known_art("e:statue_photo") == null, "Weapon and old photo remain hidden")
	game.show_notebook()
	check(textures().size() == 1, "Notebook card has discovered thumbnail")
	game._show_notebook_entry("e:call_log")
	check(game.modal_body.find_child("EvidenceArtwork", true, false) != null, "Evidence details include artwork")
	await art_capture("details")
	game.session.collect_evidence("desk_inventory")
	check(game._known_art("e:desk_inventory") == Catalog.evidence_texture("desk_inventory") and game._known_art("e:statue_photo") == null, "Empty spot displays its own image without revealing undiscovered archive photo")
	game.session.collect_evidence("statue_photo")
	check(game._known_art("e:desk_inventory") == Catalog.evidence_texture("desk_inventory"), "Collected empty-spot clue displays its own newly supplied picture")
	game.session.travel_to("reception")
	game.session.collect_evidence("locker_access")
	check(game._known_art("e:locker_access") != null, "Cabinet log has its own exact assigned picture")
	for person in ["nadine", "layla", "samer", "mazen"]:
		game._start_dialogue(person)
		await process_frame
		await process_frame
		check(game.room._portrait.texture == Catalog.character_texture(person), "Dialogue displays correct person's neutral image")
		check(game.room._portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Character preserves aspect with no face crop")
		check(not game._hero_portrait.visible, "NPC reply shows only the NPC, without a tiny hero icon")
		check(game.modal_panel.get_global_rect().encloses(game._dialogue_frame.get_global_rect()), "Framed portrait is wholly inside dialogue box")
		check(not game._hero_portrait.is_visible_in_tree(), "No icon overlaps the fixed accusation button")
		await art_capture(person)
		game.show_questions()
		check(game.room._portrait.texture != null, "Portrait remains during interrogation")
		game.close_modal()
	complete(game.session)
	check(game._known_art("e:locker_access") != null, "Late CCTV illustration unlocks after supporting discoveries and analysis")
	game.travel_to("reception")
	game.show_evidence("locker_access")
	check(labels().contains("صورة توضيحية"), "Assigned cabinet log is labeled as an illustration")
	await art_capture("late-cctv")
	game.show_evidence("locker_find")
	await art_capture("weapon")
	for clue in game.session._case.evidence:
		check((game._known_art("e:" + clue.id) != null) == FileAccess.file_exists(Catalog.evidence_files.get(clue.id,"")), "Completed investigation follows exact file availability: " + clue.id)
	game._notebook_tab = "evidence"
	game.show_notebook()
	await art_capture("notebook")
	game._charge_tab("materials")
	await art_capture("accusation")
	check(textures().size() > 0, "Accusation materials display available evidence/report thumbnails")
	for art in textures():
		check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Accusation thumbnails preserve proportions")
	game._report_page = 0
	game.show_reports()
	check(textures().size() == 1, "Available forensic report has requested ninth image")
	await art_capture("report")
	game._start_dialogue("nadine")
	game._answer_question("nadine_exit")
	check(game.room._portrait.texture == Catalog.expression_texture("nadine", "defensive"), "Interrogation uses authored expression cue")
	game._confront_question("nadine_exit", "door_events")
	check(game._dialogue_portrait.texture == game.HeroPortrait.texture("accusing"), "Confrontation displays accusation hero inside frame")
	await art_capture("confrontation")
	game.queue_free()
	await process_frame
	print("LAST CALL ART: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
