extends "res://tests/test_last_call_complete.gd"
func snapshot(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/noir-" + name + ".png")
func framed() -> void:
	check(game._dialogue_frame.is_visible_in_tree(), "Portrait is embedded in dialogue box")
	check(game.modal_panel.get_global_rect().encloses(game._dialogue_frame.get_global_rect()), "Portrait frame stays inside bottom box")
	check(game._dialogue_frame.get_global_rect().encloses(game._dialogue_portrait.get_global_rect()), "Portrait fits frame without face crop")
	check(game._dialogue_portrait.texture != null and game._dialogue_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Real portrait keeps its aspect ratio")
	check(not game.room._characters.is_visible_in_tree() and not game._hero_portrait.is_visible_in_tree(), "No oversized character or permanent hero outside the box")
	check(absf(game.modal_panel.get_global_rect().get_center().y - 360) < 2 and Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(game.modal_panel.get_global_rect()), "Dialogue is centered and fully visible")
	check(is_equal_approx(game._dialogue_frame.size.x, game._dialogue_frame.size.y) and game._dialogue_frame.size.x >= 280, "Portrait has a large square frame")
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	await settle()
	game.begin_investigation()
	for target in game.room._hotspots.get_children():
		check(target.text.is_empty() and target.find_children("*", "Label", true, false).is_empty(), "Hotspots have no permanent captions")
		check(target.get_theme_stylebox("normal") is StyleBoxEmpty, "Hotspots rest invisible")
		check(target.get_theme_stylebox("pressed") is StyleBoxFlat, "Touch feedback is available")
	await snapshot("prototype-office")
	game.show_people()
	await settle()
	await touch(card("mazen"))
	framed()
	check(game._window_title.text == "مازن", "Mazen name appears beside framed portrait")
	await snapshot("prototype-mazen")
	await touch(action("الاستجواب"))
	framed()
	check(game._card_grid.columns == 1 and game._card_grid.get_child_count() <= 3, "Questions are short text choices linked to the dialogue box")
	for option in game._card_grid.get_children():
		check(option.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) == 0 and option.size.y <= 64, "Dialogue option is subtle and touch sized")
	await snapshot("prototype-options")
	await touch(game._close_button)
	await touch(game.room._hotspots.find_child("Evidence_call_log", false, false))
	await touch(action("أضف إلى دفتر الأدلة"))
	check(game._window_title.text == game.session.evidence_data("call_log").name, "Collected evidence has a clear named inspection")
	var art: TextureRect = game.modal_body.find_child("KnownEvidenceArtwork", true, false)
	check(art != null and art.texture != null and art.size.y >= 220, "Evidence image really appears in inspection")
	await snapshot("prototype-evidence")
	if not OS.get_cmdline_user_args().has("--prototype"):
		game.close_modal()
		for location in ["adam_office", "reception"]:
			game.travel_to(location)
			await settle()
			var ids: Array = game.session.available_people().filter(func(person): return person.location_id == location).map(func(person): return person.id)
			for id in ids:
				game.show_people()
				await settle()
				await touch(card(id))
				framed()
				check(game._window_title.text == game.session.person_data(id).name, "Shared framed dialogue works for every person")
				await snapshot(id + "-dialogue")
				await touch(game._close_button)
	game.queue_free()
	await process_frame
	print("NOIR DIALOGUE: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
